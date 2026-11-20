class_name WorldPlan
extends RefCounted

## A desert world's plan: where its seas, ranges, plateaus and canyons lie
## (docs/superpowers/specs/2026-11-19-wadis-land-design.md §5). Built once from
## a recipe, on any thread, the same on every one, and never written after:
## its dials, a map (PlanMap) of fields that sample() reads anywhere, and the
## shapes drawn on it (PlanShapes). So far the map holds the open ground, dune
## seas and gravel plains on a gentle roll, and the seas sunk into it; the
## ranges, plateaus, canyons and kept discs come later.

enum Land { SEA, DUNES, PLAINS, PLATEAU, MOUNTAINS }

## Metres above radius where a sea's water stands: under Wadoo's lowest
## ground, -31 m.
const SEA_LEVEL := -40.0

# What sample() writes, by index (indices are added at the end, never
# reordered). Heights are metres above radius.

## The base height.
const S_BASE := 0
## Signed metres to the coast: negative at sea, INF with no sea.
const S_SHORE := 1
## The share of open ground that is dune sea, 0 to 1.
const S_DUNES := 2
## Plateau country's weight, 0 to 1, and that region's top.
const S_PLATEAU := 3
const S_PLATEAU_TOP := 4
## Mountains' weight, 0 to 1, and metres from the nearest spine (INF with
## none).
const S_MOUNTAIN := 5
const S_RIDGE := 6
## Metres from the nearest canyon's centreline over its floor's half-width (at
## most 1 on the floor, INF with none); the floor's height; the walls' top
## over the floor, metres.
const S_CANYON := 7
const S_CANYON_FLOOR := 8
const S_CANYON_RIM := 9
## A kept disc's weight, 0 to 1.
const S_KEEP := 10
const S_SIZE := 11

## The open ground's base rolls this many metres either way of the radius, in
## swells about BASE_WAVE metres across: the open desert, never as low as a
## sea.
const BASE_ROLL := 25.0
const BASE_WAVE := 24000.0
## Dune seas and gravel plains lie in patches about DUNES_WAVE metres across:
## S_DUNES is 0.5 plus DUNES_CONTRAST times a noise, so most ground is plainly
## one or the other. Open ground is dune sea where S_DUNES is DUNES_FROM or
## more.
const DUNES_WAVE := 30000.0
const DUNES_CONTRAST := 1.5
const DUNES_FROM := 0.5

## The seas (§5.4 step 2, §7). Each grows over the map's cells from a seeded
## centre, nearest first, to its share of the surface (the `sea` dial split
## between `seas` seas), the nearness pushed in and out by a noise SHORE_WAVE
## metres across, up to SHORE_ROUGH times a round sea's radius: its bays and
## headlands.
const SHORE_WAVE := 15000.0
const SHORE_ROUGH := 0.5
## Seeded centres tried for each sea before its pin is given up on.
const SEA_TRIES := 16
## A grown sea is tidied (_tidy) at most this many times over, and must still
## cover SEA_FULL of its share.
const TIDY_PASSES := 8
const SEA_FULL := 0.97
## From the water's edge the seabed falls SHELF_DEPTH metres over SHELF_WIDTH
## (the shelf), then to the deep floor, SEA_DEEP under sea level, over
## SLOPE_WIDTH more.
const SHELF_DEPTH := 20.0
const SHELF_WIDTH := 1500.0
const SEA_DEEP := 300.0
const SLOPE_WIDTH := 6000.0
## Out of the water, land rises from sea level at the water's edge to the open
## ground over BEACH_WIDTH metres: a beach. Past it, open ground's base is
## never under sea level + LAND_ABOVE.
const BEACH_WIDTH := 1500.0
const LAND_ABOVE := 6.0
## Ground under sea level lies within this many metres of a shore: at sea, or
## at a beach's foot where the ground's detail dips. Never a puddle inland.
const PUDDLE_FROM := 2000.0

var dials: PlanDials
## Metres above radius of the sea's water: SEA_LEVEL, or -INF with no sea.
var sea_level := -INF
var map: PlanMap
var shapes: PlanShapes

static func build(recipe: WorldRecipe) -> WorldPlan:
	var p := WorldPlan.new()
	p.dials = PlanDials.roll(recipe.seed, recipe.radius_m)
	p.dials.pin(recipe.plan_pins)
	p.sea_level = SEA_LEVEL if p.dials.sea > 0.0 else -INF
	p.map = PlanMap.new(S_SIZE)
	p.shapes = PlanShapes.new()
	var dirs := p._corner_dirs()
	var shore := p._seas(recipe, dirs)
	p._open_ground(recipe, dirs, shore)
	var low := PackedFloat32Array()
	var high := PackedFloat32Array()
	p.map.cell_range(S_BASE, low, high)
	p.map.set_bounds(low, high)
	return p

## Every field at `d` into `out` (S_SIZE long, the caller's own): allocates
## nothing.
func sample(d: Vector3, out: PackedFloat64Array) -> void:
	map.sample(d, out)

## SEA at or past the water's edge; else what the open ground is.
func land_at(d: Vector3) -> Land:
	if map.at(S_SHORE, d) <= 0.0:
		return Land.SEA
	return Land.DUNES if map.at(S_DUNES, d) >= DUNES_FROM else Land.PLAINS

## Great-circle metres from `d` to the nearest shore: negative at sea, INF on a
## world with no sea.
func nearest_shore_m(d: Vector3) -> float:
	return map.at(S_SHORE, d)

## Vector2(least, most) height of the ground under the quadtree node `key`.
func bounds_of(key: Vector4i) -> Vector2:
	return map.bounds_of(key)

## Every corner's direction, by k as PlanMap numbers them.
func _corner_dirs() -> PackedVector3Array:
	var dirs := PackedVector3Array()
	dirs.resize(CubeSphere.FACES * PlanMap.SIDE * PlanMap.SIDE)
	var k := 0
	for face in CubeSphere.FACES:
		for j in PlanMap.SIDE:
			for i in PlanMap.SIDE:
				dirs[k] = map.corner_dir(face, i, j)
				k += 1
	return dirs

## Fills the map with the open ground, sunk into its seas: the base's roll
## and the dunes' patches, from noises of the plan's own that live only while
## it is built, and the coast (_coast) by `shore`, each corner's metres to the
## nearest shore (by k). The fields with nothing in them yet hold their none:
## INF to a spine and a canyon, and no weight.
func _open_ground(recipe: WorldRecipe, dirs: PackedVector3Array, shore: PackedFloat32Array) -> void:
	var roll := _noise(recipe, &"plan_base", BASE_WAVE, 3)
	var dunes := _noise(recipe, &"plan_dunes", DUNES_WAVE, 2)
	var sea := sea_level > -INF
	if not sea:
		map.fill(S_SHORE, INF)
	map.fill(S_RIDGE, INF)
	map.fill(S_CANYON, INF)
	var k := 0
	for face in CubeSphere.FACES:
		for j in PlanMap.SIDE:
			for i in PlanMap.SIDE:
				var d := dirs[k]
				var base := BASE_ROLL * clampf(roll.get_noise_3dv(d), -1.0, 1.0)
				if sea:
					var s := shore[k]
					# Past the beach, as _coast gives it, without the call.
					base = _coast(base, s) if s < BEACH_WIDTH else maxf(base, sea_level + LAND_ABOVE)
					map.set_corner(S_SHORE, face, i, j, s)
				map.set_corner(S_BASE, face, i, j, base)
				map.set_corner(S_DUNES, face, i, j, clampf(0.5 + DUNES_CONTRAST * dunes.get_noise_3dv(d), 0.0, 1.0))
				k += 1

## The base `shore` metres from the coast (negative at sea) where the open
## ground's would be `open`: sea level at the water's edge, rising over a beach
## to the open ground (never under LAND_ABOVE over the water), or falling
## through the shelf and the slope to the deep floor.
func _coast(open: float, shore: float) -> float:
	if shore >= 0.0:
		return lerpf(sea_level, maxf(open, sea_level + LAND_ABOVE), smoothstep(0.0, BEACH_WIDTH, shore))
	var out := -shore
	return sea_level - SHELF_DEPTH * minf(out / SHELF_WIDTH, 1.0) \
		- (SEA_DEEP - SHELF_DEPTH) * smoothstep(SHELF_WIDTH, SHELF_WIDTH + SLOPE_WIDTH, out)

## Grows the dials' seas into shapes.seas (§5.4 step 2) and gives back each
## corner's signed metres to the nearest shore, by k: INF everywhere on a world
## with no sea (and sea_level -INF if no sea found room). Each sea grows from
## the first of a seeded run of centres whose sea fills its share clear of
## every kept disc and of the other seas and, for a world whose design pins the
## shore (`pins.sea_shore`), puts the first sea's nearest shore within the
## pin's reach of the pinned place (any other only no nearer). If none does,
## that is an error, and the nearest miss is kept.
func _seas(recipe: WorldRecipe, dirs: PackedVector3Array) -> PackedFloat32Array:
	var shore := PackedFloat32Array()
	shore.resize(dirs.size())
	shore.fill(INF)
	if dials.sea <= 0.0:
		return shore
	var radius := recipe.radius_m
	var share := dials.sea / dials.seas
	var area := 4.0 * PI * share
	# A round sea of that share reaches this far from its centre, metres.
	var reach := acos(1.0 - 2.0 * share) * radius
	var rough := SHORE_ROUGH * reach
	var noise := _noise(recipe, &"plan_shore", SHORE_WAVE, 3)
	var rng := WorldSeed.rng(recipe.seed, &"plan_seas")
	var pin := _shore_pin(recipe)
	var pin_cell := PlanShapes.cell_index(map.cell_of(pin.dir)) if pin else -1
	var step := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH) / 8.0
	var taken := PackedByteArray()
	taken.resize(CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS)
	taken.fill(0)
	# By k: the k standing for a corner and all its copies, and by that k how
	# many cells meet there (4, or 3 at a cube's corner).
	var copies := _corner_copies(dirs)
	var canon := PackedInt32Array(range(dirs.size()))
	var full := PackedByteArray()
	full.resize(dirs.size())
	full.fill(4)
	for k: int in copies:
		var group: PackedInt32Array = copies[k]
		canon[k] = group[0]
		if group.size() == 3:
			full[group[0]] = 3
	for s in dials.seas:
		# The first sea is aimed at the pin; any other only keeps off it.
		var aimed := pin and s == 0
		var aim: float = (pin.within.x + pin.within.y) * 0.5 + reach if aimed else 0.0
		var best := {}
		var best_miss := INF
		for attempt in SEA_TRIES:
			var centre := _toward(pin.dir, aim / radius, rng.randf() * TAU) if aimed else _anywhere(rng)
			var priority := func(c: int) -> float:
				var mid := _cell_centre(c, dirs)
				if not _clear_of_keeps(recipe, mid):
					return INF
				return mid.angle_to(centre) * radius + rough * (1.0 + clampf(noise.get_noise_3dv(mid), -1.0, 1.0))
			var start := PlanShapes.cell_index(map.cell_of(centre))
			if taken[start] != 0 or priority.call(start) == INF:
				continue
			var grown := _grow(start, area, priority, step, taken, dirs)
			var cells := _tidy(grown.cells, priority, taken, canon, full)
			var got := 0.0
			for c in cells:
				got += _cell_area(c, dirs)
			var miss := 0.0 if got >= area * SEA_FULL else 1e9
			if pin:
				var near := _shore_from(pin.dir, pin_cell, cells, dirs) * radius
				miss += maxf(pin.within.x - near, 0.0)
				if aimed:
					miss += maxf(near - pin.within.y, 0.0)
					aim += (pin.within.x + pin.within.y) * 0.5 - near
			if miss < best_miss:
				best = {"cells": cells, "centre": centre}
				best_miss = miss
			if miss == 0.0:
				break
		if best_miss > 0.0:
			push_error("WorldPlan: no centre for sea %d of %s fills its share clear of its kept discs%s; kept the nearest miss" % [
				s + 1, recipe.name, " and of its sea_shore pin" if pin else ""])
		if best.is_empty():
			continue
		shapes.seas.append(best)
		_take(best.cells, taken)
	if shapes.seas.is_empty():
		sea_level = -INF
		return shore
	return _shore_field(dirs, copies, canon, full, radius)

## The design's pin on the sea's shore (§5.3): {"place", "dir", "within":
## Vector2(least, most) metres from the place to the nearest shore}, or {} if
## it pins none (or names no place on this world).
static func _shore_pin(recipe: WorldRecipe) -> Dictionary:
	var pins: Variant = recipe.plan_pins.get("pins", {})
	var pin: Variant = pins.get("sea_shore") if pins is Dictionary else null
	if not pin is Dictionary:
		return {}
	var place := StringName(str(pin.get("place", "")))
	var within: Variant = pin.get("within", [])
	if not recipe.pin_places.has(place) or not within is Array or within.size() != 2:
		return {}
	return {"place": place, "dir": recipe.pin_places[place], "within": Vector2(float(within[0]), float(within[1]))}

## Grows one body of cells from cell `start` until it covers `area` (of the
## unit sphere) or can grow no further. Of the free cells (taken 0) beside it,
## the one with the lowest priority(cell), to within `step`, joins next; one
## whose priority is INF never does. So it is one connected body by
## construction. Gives back {"cells": PackedInt32Array, "area": float}.
func _grow(start: int, area: float, priority: Callable, step: float, taken: PackedByteArray,
		dirs: PackedVector3Array) -> Dictionary:
	var seen := PackedByteArray()
	seen.resize(taken.size())
	seen.fill(0)
	seen[start] = 1
	var queue := Buckets.new(step)
	queue.push(start, priority.call(start))
	var cells := PackedInt32Array()
	var got := 0.0
	var near := PackedInt32Array()
	near.resize(4)
	while got < area:
		var c := queue.pop()
		if c < 0:
			break
		cells.append(c)
		got += _cell_area(c, dirs)
		_cell_neighbours(c, near)
		for o in near:
			if seen[o] == 0 and taken[o] == 0:
				seen[o] = 1
				var key: float = priority.call(o)
				if key < INF:
					queue.push(o, key)
	return {"cells": cells, "area": got}

## Tidies the grown body `cells` so a field held at the map's corners can show
## it, and gives back its cells. A cell none of whose corners is all sea (a
## one-cell arm or tip) would be water with no depth, so it goes; a free cell
## with three or more sides in the body (a one-cell notch or spit) would read
## as sea, so it joins if priority(cell) lets it. Over again, up to
## TIDY_PASSES times, until nothing changes; then, if a cell that went could
## have parted the body, only its largest connected part is kept. Dropping a
## part makes no cell thin, since a corner is all sea only where its cells are
## joined. `canon` and `full` are by corner k: the k that stands for its
## copies, and how many cells meet there.
func _tidy(cells: PackedInt32Array, priority: Callable, taken: PackedByteArray, canon: PackedInt32Array,
		full: PackedByteArray) -> PackedInt32Array:
	var member := PackedByteArray()
	member.resize(taken.size())
	member.fill(0)
	# By canon k: how many of the body's cells meet at the corner.
	var wet := PackedByteArray()
	wet.resize(canon.size())
	wet.fill(0)
	for c in cells:
		member[c] = 1
		_touch(c, wet, canon, 1)
	var near := PackedInt32Array()
	near.resize(4)
	var beside := PackedInt32Array()
	beside.resize(4)
	var split := false
	for turn in TIDY_PASSES:
		var changed := false
		var kept := PackedInt32Array()
		# The kept cells with some corner not all sea: the only ones with a
		# free cell beside them.
		var coast := PackedInt32Array()
		for c in cells:
			var all_sea := _sea_corners(c, wet, canon, full)
			if all_sea == 0:
				member[c] = 0
				_touch(c, wet, canon, -1)
				changed = true
				_cell_neighbours(c, near)
				split = split or member[near[0]] + member[near[1]] + member[near[2]] + member[near[3]] >= 2
			else:
				kept.append(c)
				if all_sea < 4:
					coast.append(c)
		for c in coast:
			_cell_neighbours(c, near)
			for o in near:
				if member[o] == 1 or taken[o] != 0:
					continue
				_cell_neighbours(o, beside)
				if member[beside[0]] + member[beside[1]] + member[beside[2]] + member[beside[3]] >= 3 \
						and priority.call(o) < INF:
					member[o] = 1
					_touch(o, wet, canon, 1)
					kept.append(o)
					changed = true
		cells = kept
		if not changed:
			break
	return _largest_body(cells, member) if split else cells

## Adds `by` to `wet` at each corner of cell `c`, by canon k.
static func _touch(c: int, wet: PackedByteArray, canon: PackedInt32Array, by: int) -> void:
	var k := _first_corner(c)
	var up := PlanMap.SIDE
	wet[canon[k]] += by
	wet[canon[k + 1]] += by
	wet[canon[k + up]] += by
	wet[canon[k + up + 1]] += by

## How many of cell `c`'s corners have only body cells round them (`wet` the
## count of body cells there, `full` of all): 0 for a cell one cell thin, 4
## for one inside the body.
static func _sea_corners(c: int, wet: PackedByteArray, canon: PackedInt32Array, full: PackedByteArray) -> int:
	var k := _first_corner(c)
	var up := PlanMap.SIDE
	var a := canon[k]
	var b := canon[k + 1]
	var e := canon[k + up]
	var f := canon[k + up + 1]
	return int(wet[a] == full[a]) + int(wet[b] == full[b]) + int(wet[e] == full[e]) + int(wet[f] == full[f])

## The largest connected part of `cells` (those marked 1 in `member`); the
## others are unmarked.
func _largest_body(cells: PackedInt32Array, member: PackedByteArray) -> PackedInt32Array:
	var part := PackedInt32Array()
	part.resize(member.size())
	part.fill(-1)
	var near := PackedInt32Array()
	near.resize(4)
	var parts: Array[PackedInt32Array] = []
	for c in cells:
		if member[c] == 0 or part[c] >= 0:
			continue
		var body := PackedInt32Array([c])
		part[c] = parts.size()
		var at := 0
		while at < body.size():
			_cell_neighbours(body[at], near)
			at += 1
			for o in near:
				if member[o] == 1 and part[o] < 0:
					part[o] = parts.size()
					body.append(o)
		parts.append(body)
	var largest := 0
	for p in parts.size():
		if parts[p].size() > parts[largest].size():
			largest = p
	for p in parts.size():
		if p != largest:
			for c in parts[p]:
				member[c] = 0
	return parts[largest] if parts else PackedInt32Array()

## Great-circle radians from `place` (in cell `place_cell`) to the nearest
## corner of the outline of the body `cells`: negative if it lies in the body.
func _shore_from(place: Vector3, place_cell: int, cells: PackedInt32Array, dirs: PackedVector3Array) -> float:
	var member := PackedByteArray()
	member.resize(CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS)
	member.fill(0)
	for c in cells:
		member[c] = 1
	var near := INF
	for k in _outline(cells, member):
		near = minf(near, place.angle_to(dirs[k]))
	return -near if member[place_cell] == 1 else near

## Marks `cells` a sea's (1), and every cell within two of them too near for
## another sea (2), so two seas never meet, even at a corner.
func _take(cells: PackedInt32Array, taken: PackedByteArray) -> void:
	for c in cells:
		taken[c] = 1
	var near := PackedInt32Array()
	near.resize(4)
	var ring := cells
	for r in 2:
		var next := PackedInt32Array()
		for c in ring:
			_cell_neighbours(c, near)
			for o in near:
				if taken[o] == 0:
					taken[o] = 2
					next.append(o)
		ring = next

## Each corner's signed great-circle metres to the nearest shore, by k. The
## seas are shapes.seas. Their outline's corners (where sea cells and land
## cells meet) are 0, and a front spreads from them over the corners, nearest
## first, each corner carrying the outline corner it was reached from, so its
## distance is to a true point of the outline. Negative where only sea cells
## meet. `copies` are each face-edge corner's copies; `canon` and `full` are
## by k the k standing for them all and how many cells meet there.
func _shore_field(dirs: PackedVector3Array, copies: Dictionary, canon: PackedInt32Array,
		full: PackedByteArray, radius: float) -> PackedFloat32Array:
	var count := dirs.size()
	var up := PlanMap.SIDE
	# By canon k: how many sea cells meet at the corner.
	var wet := PackedByteArray()
	wet.resize(count)
	wet.fill(0)
	for sea: Dictionary in shapes.seas:
		for c: int in sea.cells:
			_touch(c, wet, canon, 1)
	var outline := PackedInt32Array()
	for k in count:
		var at := canon[k]
		if wet[at] > 0 and wet[at] < full[at]:
			outline.append(k)
	# The chord to the outline corner each corner was reached from: as the
	# great circle, but cheaper, and in the same order.
	var chord := PackedFloat32Array()
	chord.resize(count)
	chord.fill(INF)
	var from := PackedVector3Array()
	from.resize(count)
	var done := PackedByteArray()
	done.resize(count)
	done.fill(0)
	# The front's queue: Buckets by chord, written out here (head, item, after
	# and low are its _head, _item, _next and _low), since this runs once a
	# corner and the calls cost a quarter of it.
	var step := CubeSphere.edge_m(1.0, PlanMap.PLAN_DEPTH) / 32.0
	var head := PackedInt32Array()
	head.resize(int(2.0 / step) + 2)
	head.fill(-1)
	var item := PackedInt32Array()
	var after := PackedInt32Array()
	for k in outline:
		chord[k] = 0.0
		from[k] = dirs[k]
		item.append(k)
		after.append(head[0])
		head[0] = item.size() - 1
	var near := PackedInt32Array()
	near.resize(11)
	var low := 0
	while low < head.size():
		var entry := head[low]
		if entry < 0:
			low += 1
			continue
		head[low] = after[entry]
		var k := item[entry]
		if done[k] == 1:
			continue
		done[k] = 1
		var src := from[k]
		var i := k % PlanMap.SIDE
		var j := (k / PlanMap.SIDE) % PlanMap.SIDE
		var m := 0
		var left := i > 0
		var right := i < PlanMap.CELLS
		var down := j > 0
		var top := j < PlanMap.CELLS
		if left:
			near[m] = k - 1
			m += 1
		if right:
			near[m] = k + 1
			m += 1
		if down:
			near[m] = k - up
			m += 1
			if left:
				near[m] = k - up - 1
				m += 1
			if right:
				near[m] = k - up + 1
				m += 1
		if top:
			near[m] = k + up
			m += 1
			if left:
				near[m] = k + up - 1
				m += 1
			if right:
				near[m] = k + up + 1
				m += 1
		if m < 8:
			# On a face's edge: each copy is reached too, and goes on over its face.
			for c: int in copies[k]:
				near[m] = c
				m += 1
		for e in m:
			var o := near[e]
			if done[o] == 0:
				var to := dirs[o].distance_to(src)
				if to < chord[o]:
					chord[o] = to
					from[o] = src
					var b := int(to / step)
					item.append(o)
					after.append(head[b])
					head[b] = item.size() - 1
					low = mini(low, b)
	var shore := PackedFloat32Array()
	shore.resize(count)
	for k in count:
		var at := canon[k]
		var metres := 2.0 * asin(minf(chord[k] * 0.5, 1.0)) * radius
		shore[k] = metres if wet[at] == 0 else (-metres if wet[at] == full[at] else 0.0)
	return shore

## The corners (by k) at the ends of every edge between a cell of `cells` and
## a cell not marked 1 in `member`: the body's outline. A corner may come more
## than once.
func _outline(cells: PackedInt32Array, member: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	var near := PackedInt32Array()
	near.resize(4)
	var up := PlanMap.SIDE
	for c in cells:
		_cell_neighbours(c, near)
		var k := _first_corner(c)
		if member[near[0]] != 1:
			out.append(k + 1)
			out.append(k + up + 1)
		if member[near[1]] != 1:
			out.append(k)
			out.append(k + up)
		if member[near[2]] != 1:
			out.append(k + up)
			out.append(k + up + 1)
		if member[near[3]] != 1:
			out.append(k)
			out.append(k + 1)
	return out

## The four cells that share an edge with cell `c`, into `out`: across its +u,
## -u, +v and -v edges, in that order, as PlanMap.neighbours gives them.
func _cell_neighbours(c: int, out: PackedInt32Array) -> void:
	var n := PlanMap.CELLS
	var i := c % n
	var j := (c / n) % n
	if i > 0 and j > 0 and i < n - 1 and j < n - 1:
		out[0] = c + 1
		out[1] = c - 1
		out[2] = c + n
		out[3] = c - n
		return
	var near := map.neighbours(PlanShapes.cell_key(c))
	for e in 4:
		out[e] = PlanShapes.cell_index(near[e])

## True if no point of the cell centred on `mid` lies within a kept disc's
## radius and blend. Every point of a cell is within one cell edge of its
## centre (0.77 of one, at most).
static func _clear_of_keeps(recipe: WorldRecipe, mid: Vector3) -> bool:
	var reach := CubeSphere.edge_m(recipe.radius_m, PlanMap.PLAN_DEPTH)
	for keep: Dictionary in recipe.keeps:
		if mid.angle_to(keep.dir) * recipe.radius_m - reach < keep.radius + keep.blend:
			return false
	return true

## For each corner on a face's edge, by k: every k that is a copy of it (one
## direction, PlanMap's corner rule), itself among them.
static func _corner_copies(dirs: PackedVector3Array) -> Dictionary:
	var groups := {}
	var n := PlanMap.CELLS
	for face in CubeSphere.FACES:
		for t in PlanMap.SIDE:
			for at: Vector2i in [Vector2i(t, 0), Vector2i(t, n), Vector2i(0, t), Vector2i(n, t)]:
				var k := (face * PlanMap.SIDE + at.y) * PlanMap.SIDE + at.x
				var d := dirs[k]
				if not groups.has(d):
					groups[d] = PackedInt32Array()
				if not groups[d].has(k):
					groups[d].append(k)
	var copies := {}
	for d: Vector3 in groups:
		for k: int in groups[d]:
			copies[k] = groups[d]
	return copies

## The k of cell `c`'s first corner, (i, j); the others are k + 1, k + SIDE and
## k + SIDE + 1.
static func _first_corner(c: int) -> int:
	var n := PlanMap.CELLS
	return ((c / (n * n)) * PlanMap.SIDE + (c / n) % n) * PlanMap.SIDE + c % n

## The direction of cell `c`'s middle: its corners', averaged.
static func _cell_centre(c: int, dirs: PackedVector3Array) -> Vector3:
	var k := _first_corner(c)
	return (dirs[k] + dirs[k + 1] + dirs[k + PlanMap.SIDE] + dirs[k + PlanMap.SIDE + 1]).normalized()

## Cell `c`'s share of the unit sphere, as the flat quad of its corners.
static func _cell_area(c: int, dirs: PackedVector3Array) -> float:
	var k := _first_corner(c)
	var up := PlanMap.SIDE
	return 0.5 * (dirs[k + up + 1] - dirs[k]).cross(dirs[k + up] - dirs[k + 1]).length()

## The direction `angle` radians from `from`, on the bearing `bearing`.
static func _toward(from: Vector3, angle: float, bearing: float) -> Vector3:
	var east := from.cross(Vector3.UP)
	if east.length_squared() < 1e-6:
		east = from.cross(Vector3.RIGHT)
	east = east.normalized()
	var north := from.cross(east)
	return (from * cos(angle) + (east * cos(bearing) + north * sin(bearing)) * sin(angle)).normalized()

## A direction drawn evenly over the sphere.
static func _anywhere(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), r * sin(a), z)

## A smooth noise for `concern`, its features about `wave` metres across on
## this world, read at unit directions.
static func _noise(recipe: WorldRecipe, concern: StringName, wave: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, concern))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = recipe.radius_m / wave
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n

## A queue that gives back its items lowest key first, to within `step` (keys
## 0 or more), and in a fixed order among keys that close, so whatever grows or
## spreads by it does so the same on every machine: Dial's buckets, each a
## list threaded through flat arrays. An item pushed again is in it twice; the
## caller skips what it has done.
class Buckets:
	var step: float
	## By bucket, its last entry, -1 when empty.
	var _head := PackedInt32Array()
	## By entry, its item and the bucket's entry before it.
	var _item := PackedInt32Array()
	var _next := PackedInt32Array()
	## No bucket under this holds an entry.
	var _low := 0

	func _init(p_step: float) -> void:
		step = p_step

	func push(item: int, key: float) -> void:
		var b := int(key / step)
		if b >= _head.size():
			var was := _head.size()
			_head.resize(b + 256)
			for x in range(was, _head.size()):
				_head[x] = -1
		_item.append(item)
		_next.append(_head[b])
		_head[b] = _item.size() - 1
		_low = mini(_low, b)

	## The item with the lowest key, or -1 when none is left.
	func pop() -> int:
		while _low < _head.size():
			var e := _head[_low]
			if e >= 0:
				_head[_low] = _next[e]
				return _item[e]
			_low += 1
		return -1
