class_name WorldPlan
extends RefCounted

## A desert world's plan: where its seas, ranges, plateaus and canyons lie
## (docs/superpowers/specs/2026-11-19-wadis-land-design.md §5). Built once from
## a recipe, on any thread, the same on every one, and never written after:
## its dials, a map (PlanMap) of fields that sample() reads anywhere, and the
## shapes drawn on it (PlanShapes). So far the map holds the open ground, dune
## seas and gravel plains on a gentle roll, the seas sunk into it and the
## mountain ranges and plateau country raised on it, and the canyons are drawn
## through it. Its sites (oases, shores, kept discs), the kept discs' weight and
## the bounds the streaming culls by come last.

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
## The fields land_in reads are among the first this many, S_BASE to
## S_MOUNTAIN, so a sample of only these is enough for it.
const LAND_FIELDS := S_MOUNTAIN + 1

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
## Low ground leans to dunes and high to gravel: S_DUNES is moved by up to this
## much, down at the roll's top and up at its bottom.
const DUNES_LOW_LEAN := 0.25

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

## The ranges (§5.4 step 3, §6). Each is a spine RANGE_LENGTH metres long, a
## smooth curve, with flanks RANGE_HALF_WIDTH metres either side of it; their
## sizes are drawn so their flanks cover about the `mountains` share between
## them.
const RANGE_LENGTH := Vector2(20000, 60000)
const RANGE_HALF_WIDTH := Vector2(4000, 8000)
## Metres between a spine's points, about.
const SPINE_STEP := 1000.0
## A spine turns at most RANGE_BEND radians a metre, never tighter than a circle
## 40 km in radius, as a noise RANGE_BEND_WAVE metres across bends it.
const RANGE_BEND := 1.0 / 40000.0
const RANGE_BEND_WAVE := 20000.0
## Along its spine a range stands tallest at one point and falls toward its
## ends, to RANGE_END of that; its summits and saddles rise and fall SUMMITS of
## it more, in a noise SUMMIT_WAVE metres across.
const RANGE_END := 0.3
const SUMMITS := 0.25
const SUMMIT_WAVE := 8000.0
## The first range stands the `peak` dial tall; each other RANGE_TOP_LEAST to 1
## of it.
const RANGE_TOP_LEAST := 0.6
## A range's flanks keep this many cells clear of a kept disc's blend, so no
## corner of a cell reaching into the disc has any of a range's weight.
const KEEP_CLEAR_CELLS := 2.0
## Seeded spines tried for each range before its rules are given up on.
const RANGE_TRIES := 32
## The plateau country (§5.4 step 4, §6). The `plateaus` dial's share is split
## between PLATEAU_REGIONS regions (how many, seeded), each grown over the
## cells (as a sea is) from a seeded centre, and each standing at its own top
## drawn from PLATEAU_TOP, metres over the radius. A region keeps off the sea's
## cells, the ranges' flanks and the kept discs, though it may reach the coast,
## where it ends in a cliff. Its centre starts at least PLATEAU_INLAND_CELLS
## cells inland, and its outline is pushed in and out by a noise PLATEAU_WAVE
## metres across, up to PLATEAU_ROUGH times a round region's radius.
const PLATEAU_TOP := Vector2(100.0, 400.0)
const PLATEAU_REGIONS := Vector2i(3, 6)
const PLATEAU_WAVE := 12000.0
const PLATEAU_ROUGH := 0.4
const PLATEAU_INLAND_CELLS := 3.0
## Seeded centres tried for each region; the first to fill PLATEAU_FULL of its
## share is kept, else the fullest.
const PLATEAU_TRIES := 8
const PLATEAU_FULL := 0.9
## A region is grown this much over its share: the outer half of its edge band
## is under PLATEAU_FROM, so the plateau country itself is less than its cells.
const PLATEAU_GROW := 1.2
## S_PLATEAU rises from 0 on a region's outline to 1 this many cells in (a
## smoothstep): the edge band, where terraces and towers are laid. _lay_plateaus
## knows only the two cells it is.
const PLATEAU_EDGE_CELLS := 2
## Plateau country is where S_PLATEAU is this or more.
const PLATEAU_FROM := 0.5

## Mountains are where S_MOUNTAIN is this or more (their flanks' foothills are
## open ground).
const MOUNTAINS_FROM := 0.5

## By Land, the most height, metres, the close-up detail (Task 10) may add over
## the plan's base on that kind of land. Task 8's bounds (bounds_of) count on it,
## and Task 10's bounds test proves the detail stays within it. Where a
## canyon's walls end, they stand at least this far over the base, so they top
## the ground there, detail and all.
const DETAIL_REACH := {Land.DUNES: 45.0, Land.PLAINS: 12.0, Land.PLATEAU: 60.0, Land.MOUNTAINS: 300.0, Land.SEA: 10.0}

## The canyons (§5.4 step 6, §6). Each of the `canyons` dial's sets out in
## plateau country (a cell of a region's flat top) or, CANYON_FROM_RANGE of the
## time, on a range's lower flank (a cell whose S_MOUNTAIN is CANYON_FLANK, so
## its floor sets out gently), and steps from cell to cell downhill to the sea:
## to the neighbour lowest by its base, plus CANYON_PULL metres a metre from the
## coast (which carries it over the open ground's roll, where it would
## otherwise stop in the first hollow), plus a seeded wander, up to
## CANYON_WANDER metres in a noise CANYON_WANDER_WAVE across. One that finds no
## lower neighbour, or is CANYON_LENGTH.y long (the cap), or is on a world with
## no sea, ends where it is, in a dry basin it digs. Of its tries, one
## CANYON_LENGTH.x long or more is liked better.
const CANYON_FLOOR_WIDTH := Vector2(150.0, 600.0)
const CANYON_DEPTH := Vector2(100.0, 400.0)
## A floor stays this far over sea level until its mouth.
const CANYON_LAND_FLOOR := 1.0
const CANYON_LENGTH := Vector2(8000.0, 60000.0)
const CANYON_FROM_RANGE := 0.3
const CANYON_FLANK := Vector2(0.1, 0.3)
const CANYON_PULL := 0.03
const CANYON_WANDER := 20.0
const CANYON_WANDER_WAVE := 15000.0
## A canyon's path is a smooth curve through its cells' middles, a point every
## CANYON_STEP metres or so, winding up to CANYON_WIND metres either side in a
## noise CANYON_WIND_WAVE across (less within half a wave of its ends, which
## stay where its cells put them). Its floor's width wanders within
## CANYON_FLOOR_WIDTH in a noise CANYON_WIDTH_WAVE across, widening to the
## widest over the last CANYON_BASIN metres of one that ends in a basin.
const CANYON_STEP := 300.0
const CANYON_WIND := 300.0
const CANYON_WIND_WAVE := 4000.0
const CANYON_WIDTH_WAVE := 8000.0
const CANYON_BASIN := 1500.0
## Its floor is the running minimum of the base less its depth (drawn from
## CANYON_DEPTH), so it never climbs toward its mouth, and stays
## CANYON_LAND_FLOOR over sea level until its mouth, where it comes down to the
## water: a beach of its own. It falls at most CANYON_GRADE a metre, so it can
## be landed on: where the base falls faster, the floor above is lowered to
## meet it, which also brings a branch down to its parent's floor.
const CANYON_GRADE := 0.1
## Its walls rise from the floor's edge, CANYON_WALL_RUN metres out for each
## metre up, to its rim: where they end, on either side, over the base and the
## DETAIL_REACH of the land there, so they stand over the ground, its detail and
## all, and leaving a canyon makes no seam. Since taller walls end farther out,
## the rim is found by looking out to where they would end and, while the
## ground there stands higher, out again, at most CANYON_RIM_LOOKS times; a
## canyon kept whose rim has not settled by then is an error (the ground there
## rises faster than the walls can). Each time, the rim is raised
## CANYON_RIM_SPARE metres past the ground it found, so on rising ground it
## settles in a few looks instead of creeping up on it.
const CANYON_WALL_RUN := 1.5
const CANYON_RIM_LOOKS := 32
const CANYON_RIM_SPARE := 1.0
## A canyon's cells keep this many metres more than a kept disc's radius and
## blend from its place: room for its walls and its winding. Its walls are
## measured against the disc once it is drawn.
const CANYON_KEEP_CLEAR := 4000.0
## Seeded heads tried for each canyon (and branch, and canyon-and-beach pairs
## for to_beach); the first whose canyon keeps clear of the kept discs and the
## other canyons, reaches the sea and is long enough is kept, else the nearest
## miss.
const CANYON_TRIES := 24
## Where no canyon opens on a beach (a shore with no range's flank or plateau
## in it), the nearest is rerouted from its path to one: stepped down over the
## land with this many metres a metre from the beach added to each cell, enough
## to carry it over any ground between (its floor stays the running minimum, so
## where the ground rises it only cuts deeper).
const CANYON_BEACH_PULL := 1.0
## How many branches a world's canyons have, seeded. Each sets out, as a canyon
## does, CANYON_BRANCH_FROM metres from a point of its parent's path, and steps
## down to it.
const CANYON_BRANCHES := Vector2i(1, 2)
const CANYON_BRANCH_FROM := Vector2(4000.0, 12000.0)
## A canyon's path is listed near the cells in runs of this many segments
## (_list_canyon).
const LIST_RUN := 8

## The kept discs (§5.6): a disc's weight (keep_weight) is 1 within its radius
## and eases to 0 over its blend, and the ground inside it stays as it always
## was, so its bounds are today's desert's range, KEPT_LOW to KEPT_HIGH metres.
## The weight is exactly 1 and exactly 0 within KEEP_SNAP metres of the disc's
## radius and of its blend's end (where a smoothstep is flat), so rounding in a
## great-circle distance never leaves a hair of weight.
const KEEP_SNAP := 0.001
const KEPT_LOW := -60.0
const KEPT_HIGH := 300.0

## The sites (§5.5). Each kind is listed best first (PlanSite.rank). An oasis
## site is a cell's middle on dune or gravel ground at least OASIS_SHORE_MIN
## metres from the water, no steeper than OASIS_LEVEL_MAX, at least
## OASIS_SPACING metres from any other.
## A site's `level` is the base's rise from its middle to the farthest of eight
## points SITE_RADIUS metres round, over SITE_RADIUS, over SITE_ROUGH_SLOPE.
## A candidate is favoured (rank less by OASIS_FAVOUR for each) beside a canyon,
## at a range's foot (some mountain weight but not mountains), within
## OASIS_COAST metres of the shore, or, among dunes, in a hollow (the cell's
## base OASIS_HOLLOW metres or more under the mean of the cells beside it). A
## low base ranks better by up to OASIS_LOW_RANK, over the roll's whole height.
const SITE_RADIUS := 500.0
const SITE_ROUGH_SLOPE := 0.1
const OASIS_SPACING := 4000.0
const OASIS_SHORE_MIN := 300.0
const OASIS_LEVEL_MAX := 0.25
## An oasis site is looked for among every SITE_STRIDEth cell each way; the
## `oases` dial's count and OASIS_EXTRA more are listed.
const SITE_STRIDE := 2
const OASIS_EXTRA := 4
const OASIS_FAVOUR := 0.15
const OASIS_COAST := 4000.0
const OASIS_HOLLOW := 1.0
const OASIS_LOW_RANK := 0.4
## A shore site is a cell's middle 0 to SHORE_SITE_REACH metres from the water,
## no rougher than SHORE_LEVEL_MAX, at least SHORE_SPACING metres from any
## other, at most SHORE_MAX of them.
const SHORE_SITE_REACH := 400.0
const SHORE_LEVEL_MAX := 0.6
const SHORE_SPACING := 2000.0
const SHORE_MAX := 32

var dials: PlanDials
## Metres above radius of the sea's water: SEA_LEVEL, or -INF with no sea.
var sea_level := -INF
var map: PlanMap
var shapes: PlanShapes
## The places set aside, by kind, best first within each (PlanSite).
var sites: Array[PlanSite] = []
## The kept discs, by keep: its direction, radius and blend.
var _keep_dirs := PackedVector3Array()
var _keep_radius := PackedFloat64Array()
var _keep_blend := PackedFloat64Array()

static func build(recipe: WorldRecipe) -> WorldPlan:
	var p := WorldPlan.new()
	p.dials = PlanDials.roll(recipe.seed, recipe.radius_m)
	p.dials.pin(recipe.plan_pins)
	p.sea_level = SEA_LEVEL if p.dials.sea > 0.0 else -INF
	p.map = PlanMap.new(S_SIZE)
	p.shapes = PlanShapes.new()
	p.shapes.radius_m = recipe.radius_m
	var dirs := p._corner_dirs()
	var copies := _corner_copies(dirs)
	var shore := p._seas(recipe, dirs, copies)
	p._open_ground(recipe, dirs, shore)
	p._ranges(recipe, dirs, shore, copies)
	p._plateaus(recipe, dirs, shore, copies)
	p._canyons(recipe, dirs)
	p.shapes.pack_near()
	for keep: Dictionary in recipe.keeps:
		p._keep_dirs.append(keep.dir)
		p._keep_radius.append(keep.radius)
		p._keep_blend.append(keep.blend)
	var values := p._corner_values()
	p._sites(recipe, dirs, values)
	p._bounds(recipe, dirs, values)
	return p

## Every field at `d` into `out` (S_SIZE long, the caller's own): allocates
## nothing. The map holds all but the canyon's, which are worked out here
## (PlanShapes.canyon_at): a floor a few hundred metres wide is too fine for the
## map's corners. The kept discs' weight is worked out here too (keep_weight),
## exactly, not read from the map.
func sample(d: Vector3, out: PackedFloat64Array) -> void:
	var u := d.normalized()
	var canyon := shapes.canyon_at(u, map.sample(u, out))
	out[S_CANYON] = canyon.x
	out[S_CANYON_FLOOR] = canyon.y
	out[S_CANYON_RIM] = canyon.z
	out[S_KEEP] = keep_weight(u)

## The most any kept disc weighs at `d`: 1 within its radius, easing (a
## smoothstep) to 0 over its blend by great-circle metres from its place, 0
## beyond. Exact, from any thread; allocates nothing.
func keep_weight(d: Vector3) -> float:
	var best := 0.0
	for n in _keep_dirs.size():
		var metres := d.angle_to(_keep_dirs[n]) * shapes.radius_m
		var radius := _keep_radius[n]
		if metres <= radius + KEEP_SNAP:
			return 1.0
		var edge := radius + _keep_blend[n]
		if metres < edge - KEEP_SNAP:
			best = maxf(best, 1.0 - smoothstep(radius, edge, metres))
	return best

## SEA at or past the water's edge; MOUNTAINS on a range's upper flanks;
## PLATEAU on a plateau's body; else what the open ground is.
func land_at(d: Vector3) -> Land:
	var f := PackedFloat64Array()
	f.resize(LAND_FIELDS)
	map.sample(d, f, LAND_FIELDS)
	return land_in(f)

## What land_at gives, from `f`, a sample's fields (its first LAND_FIELDS at
## least).
static func land_in(f: PackedFloat64Array) -> Land:
	if f[S_SHORE] <= 0.0:
		return Land.SEA
	if f[S_MOUNTAIN] >= MOUNTAINS_FROM:
		return Land.MOUNTAINS
	if f[S_PLATEAU] >= PLATEAU_FROM:
		return Land.PLATEAU
	return Land.DUNES if f[S_DUNES] >= DUNES_FROM else Land.PLAINS

## Great-circle metres from `d` to the nearest shore: negative at sea, INF on a
## world with no sea.
func nearest_shore_m(d: Vector3) -> float:
	return map.at(S_SHORE, d)

## Vector2(least, most) height of the ground under the quadtree node `key`.
func bounds_of(key: Vector4i) -> Vector2:
	return map.bounds_of(key)

## Lists the plan's sites (§5.4 step 7). `cv` is the map's base, shore, dunes,
## mountain and plateau fields by corner (_corner_values). Candidates are cells,
## weighed from their corners alone: oases among every SITE_STRIDEth cell each
## way (sites lie thousands of metres apart), shore sites among the land cells
## beside a sea's. A candidate is ranked (see OASIS_FAVOUR and the constants
## round it), then the best first are looked at closely (_site_at) one at a
## time and kept if they pass and keep their distance from those kept: the
## cells' worth is weighed once, the exact work done for a few. Each kind is
## listed best first by its rank, its exact level in it. A KEPT site is added for
## each kept disc, and each oasis is given a seeded heading.
func _sites(recipe: WorldRecipe, dirs: PackedVector3Array, cv: Array[PackedFloat32Array]) -> void:
	var radius := recipe.radius_m
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	var base := cv[S_BASE]
	var shore := cv[S_SHORE]
	var dunes := cv[S_DUNES]
	var mountain := cv[S_MOUNTAIN]
	var up := PlanMap.SIDE
	var cells := CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS
	assert(cells <= 32768, "_sort_key holds a cell number in 15 bits")
	# By cell, what ranking the candidates found: its rank and its cell-wide level.
	var rank := PackedFloat32Array()
	rank.resize(cells)
	var wide := PackedFloat32Array()
	wide.resize(cells)
	var oases := PackedFloat64Array()
	var shores := PackedFloat64Array()
	# The rise across a cell that is a level of 1.
	var steep := SITE_ROUGH_SLOPE * edge
	var c := -1
	for face in CubeSphere.FACES:
		for j in PlanMap.CELLS:
			var row := (face * up + j) * up
			for i in PlanMap.CELLS:
				c += 1
				if j % SITE_STRIDE != 0 or i % SITE_STRIDE != 0:
					continue
				var k := row + i
				var s := 0.25 * (shore[k] + shore[k + 1] + shore[k + up] + shore[k + up + 1])
				if s < OASIS_SHORE_MIN:
					continue
				var a := base[k]
				var b := base[k + 1]
				var d := base[k + up]
				var e := base[k + up + 1]
				var spread := maxf(maxf(a, b), maxf(d, e)) - minf(minf(a, b), minf(d, e))
				if spread > steep * OASIS_LEVEL_MAX:
					continue
				var m := maxf(maxf(mountain[k], mountain[k + 1]), maxf(mountain[k + up], mountain[k + up + 1]))
				var favours := int(m > 0.0) + int(s <= OASIS_COAST) + int(shapes.canyon_floor_low(c) < INF)
				var mean := 0.25 * (a + b + d + e)
				var dune := 0.25 * (dunes[k] + dunes[k + 1] + dunes[k + up] + dunes[k + up + 1])
				if dune >= DUNES_FROM and i >= 3 and j >= 3 and i < PlanMap.CELLS - 3 and j < PlanMap.CELLS - 3:
					var around := 0.25 * (base[k - 3] + base[k + 3] + base[k - 3 * up] + base[k + 3 * up])
					favours += int(mean <= around - OASIS_HOLLOW)
				wide[c] = spread / steep
				rank[c] = wide[c] + OASIS_LOW_RANK * clampf((mean + BASE_ROLL) / (2.0 * BASE_ROLL), 0.0, 1.0) \
					- OASIS_FAVOUR * favours
				oases.append(_sort_key(rank[c], c))
	if sea_level > -INF:
		var near := PackedInt32Array()
		near.resize(4)
		# 2 for a sea's cells, 1 for any other looked at.
		var listed := PackedByteArray()
		listed.resize(cells)
		listed.fill(0)
		for sea: Dictionary in shapes.seas:
			for w: int in sea.cells:
				listed[w] = 2
		for sea: Dictionary in shapes.seas:
			for w: int in sea.cells:
				_cell_neighbours(w, near)
				for o in near:
					if listed[o] != 0:
						continue
					listed[o] = 1
					var k := _first_corner(o)
					var s := 0.25 * (shore[k] + shore[k + 1] + shore[k + up] + shore[k + up + 1])
					if s <= 0.0 or s > SHORE_SITE_REACH * 1.5:
						continue
					var spread := maxf(maxf(base[k], base[k + 1]), maxf(base[k + up], base[k + up + 1])) \
						- minf(minf(base[k], base[k + 1]), minf(base[k + up], base[k + up + 1]))
					if spread > steep * SHORE_LEVEL_MAX:
						continue
					wide[o] = spread / steep
					rank[o] = wide[o]
					shores.append(_sort_key(rank[o], o))
	var rng := WorldSeed.rng(recipe.seed, &"plan_sites")
	for site: PlanSite in _pick(oases, rank, wide, dirs, PlanSite.Kind.OASIS, OASIS_SPACING, dials.oases + OASIS_EXTRA, radius):
		site.heading = rng.randf_range(0.0, 360.0)
		sites.append(site)
	for site: PlanSite in _pick(shores, rank, wide, dirs, PlanSite.Kind.SHORE, SHORE_SPACING, SHORE_MAX, radius):
		site.heading = _facing_sea(site.dir, radius)
		sites.append(site)
	for keep: Dictionary in recipe.keeps:
		var site := PlanSite.new()
		site.kind = PlanSite.Kind.KEPT
		site.dir = keep.dir
		site.radius = keep.radius
		site.heading = float(keep.get("heading", 0.0))
		sites.append(site)

## A sort key for candidate cell `c` of rank `rank`: ascending is rank order,
## ties by cell (_cell_of_key undoes it). Exact in a double.
static func _sort_key(rank: float, c: int) -> float:
	return floorf((rank + 4.0) * 10000.0) * 32768.0 + c

static func _cell_of_key(key: float) -> int:
	return int(key) % 32768

## The sites of `kind` among the candidates `keys` (_sort_key), at most `cap`,
## at least `spacing` metres apart: the best candidate that passes a close look
## (_site_at), then the best that does and is clear of it, and so on. Listed
## best first by rank, with the exact level in place of the cell-wide `wide`.
func _pick(keys: PackedFloat64Array, rank: PackedFloat32Array, wide: PackedFloat32Array, dirs: PackedVector3Array,
		kind: PlanSite.Kind, spacing: float, cap: int, radius: float) -> Array[PlanSite]:
	keys.sort()
	# Past this cosine two directions are nearer than `spacing` (a hair more).
	var near := cos(minf(spacing * 1.001 / radius, PI))
	var out: Array[PlanSite] = []
	var fields := PackedFloat64Array()
	fields.resize(LAND_FIELDS)
	for key in keys:
		if out.size() >= cap:
			break
		var c := _cell_of_key(key)
		var mid := _cell_centre(c, dirs)
		var clear := true
		for other in out:
			if mid.dot(other.dir) > near:
				clear = false
				break
		if not clear:
			continue
		var level := _site_at(mid, c, kind, radius, fields)
		if level < 0.0:
			continue
		var site := PlanSite.new()
		site.kind = kind
		site.dir = mid
		site.radius = SITE_RADIUS
		site.level = level
		site.rank = rank[c] - wide[c] + level
		out.append(site)
	out.sort_custom(func(a: PlanSite, b: PlanSite) -> bool: return a.rank < b.rank)
	return out

## The level of a site of `kind` at `mid`, the middle of cell number `c`, or -1
## if there can be none there: the ground is not what that kind needs (OASIS:
## dune or gravel ground OASIS_SHORE_MIN or more from the water; SHORE: land 0
## to SHORE_SITE_REACH from it), a kept disc is within SITE_RADIUS, a canyon's
## walls reach it or the ring of points SITE_RADIUS round it, or its level is
## over the kind's most. `fields` is scratch, LAND_FIELDS long.
func _site_at(mid: Vector3, c: int, kind: PlanSite.Kind, radius: float, fields: PackedFloat64Array) -> float:
	map.sample(mid, fields, LAND_FIELDS)
	var metres := fields[S_SHORE]
	var land := land_in(fields)
	var most: float
	if kind == PlanSite.Kind.OASIS:
		if (land != Land.DUNES and land != Land.PLAINS) or metres < OASIS_SHORE_MIN:
			return -1.0
		most = OASIS_LEVEL_MAX
	else:
		if metres <= 0.0 or metres > SHORE_SITE_REACH:
			return -1.0
		most = SHORE_LEVEL_MAX
	if not _clear_of_sites(mid, SITE_RADIUS, radius) or shapes.canyon_at(mid, c).x < INF:
		return -1.0
	var angle := SITE_RADIUS / radius
	var near_canyon := shapes.canyon_floor_low(c) < INF
	var base := fields[S_BASE]
	var worst := 0.0
	for n in 8:
		var d := _toward(mid, angle, n * TAU / 8.0)
		if near_canyon and shapes.canyon_at(d, map.cell_number(d)).x < INF:
			return -1.0
		worst = maxf(worst, absf(map.at(S_BASE, d) - base))
	var level := minf(worst / SITE_RADIUS / SITE_ROUGH_SLOPE, 1.0)
	return level if level <= most else -1.0

## True if `d`, and a disc of `margin` metres round it, is clear of every kept
## disc's radius and blend.
func _clear_of_sites(d: Vector3, margin: float, radius: float) -> bool:
	for n in _keep_dirs.size():
		if d.angle_to(_keep_dirs[n]) * radius - margin < _keep_radius[n] + _keep_blend[n]:
			return false
	return true

## The heading, degrees clockwise from north (as PlaceDesign.heading), toward the
## sea from `at`: the way the shore's metres fall off most steeply over 300 m
## either way.
func _facing_sea(at: Vector3, radius: float) -> float:
	var frame := SystemDesign.frame_at(at, 0.0)
	var east := frame.x
	var north := -frame.z
	var angle := 300.0 / radius
	var e := nearest_shore_m((at * cos(angle) - east * sin(angle)).normalized()) \
		- nearest_shore_m((at * cos(angle) + east * sin(angle)).normalized())
	var n := nearest_shore_m((at * cos(angle) - north * sin(angle)).normalized()) \
		- nearest_shore_m((at * cos(angle) + north * sin(angle)).normalized())
	return fposmod(rad_to_deg(atan2(e, n)), 360.0)

## The map's base, shore, dunes, mountain and plateau fields by corner (by k),
## indexed by field; the others are empty.
func _corner_values() -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	out.resize(S_SIZE)
	for field in [S_BASE, S_SHORE, S_DUNES, S_MOUNTAIN, S_PLATEAU]:
		out[field] = map.values_of(field)
	return out

## Sets the map's bounds (§5.4 step 8, §8.3): by cell, the base's corners' least
## less, and most plus, the most DETAIL_REACH of every land a corner's fields
## allow (a sea corner, or a mountain's, counts the open ground too); under it,
## the lowest floor of any canyon listed near the cell; up to sea level in every
## cell with a corner under it (the water is drawn there); and over every cell within a kept
## disc's radius and blend, today's desert's range, KEPT_LOW to KEPT_HIGH.
## `cv` is _corner_values'.
func _bounds(recipe: WorldRecipe, dirs: PackedVector3Array, cv: Array[PackedFloat32Array]) -> void:
	var shore := cv[S_SHORE]
	var dunes := cv[S_DUNES]
	var mountain := cv[S_MOUNTAIN]
	var plateau := cv[S_PLATEAU]
	var sea_reach: float = DETAIL_REACH[Land.SEA]
	var dunes_reach: float = DETAIL_REACH[Land.DUNES]
	var plains_reach: float = DETAIL_REACH[Land.PLAINS]
	var plateau_reach: float = DETAIL_REACH[Land.PLATEAU]
	var mountain_reach: float = DETAIL_REACH[Land.MOUNTAINS]
	var reach := PackedFloat32Array()
	reach.resize(shore.size())
	for k in reach.size():
		var r := dunes_reach if dunes[k] >= DUNES_FROM else plains_reach
		if shore[k] <= 0.0:
			r = maxf(r, sea_reach)
		if mountain[k] >= MOUNTAINS_FROM:
			r = maxf(r, mountain_reach)
		if plateau[k] >= PLATEAU_FROM:
			r = maxf(r, plateau_reach)
		reach[k] = r
	var low := PackedFloat32Array()
	var high := PackedFloat32Array()
	map.cell_range(S_BASE, low, high, reach)
	shapes.lower_by_canyons(low)
	if sea_level > -INF:
		var wet := PackedFloat32Array()
		var spare := PackedFloat32Array()
		map.cell_range(S_SHORE, wet, spare)
		for c in wet.size():
			if wet[c] < 0.0:
				high[c] = maxf(high[c], sea_level)
	for keep: Dictionary in recipe.keeps:
		_widen_to_kept(keep, dirs, low, high)
	map.set_bounds(low, high)

## Widens the bounds of every cell within `keep`'s radius and blend (those
## _clear_of_keeps says are not clear), found by a flood from its place, to
## KEPT_LOW and KEPT_HIGH.
func _widen_to_kept(keep: Dictionary, dirs: PackedVector3Array, low: PackedFloat32Array,
		high: PackedFloat32Array) -> void:
	var radius := shapes.radius_m
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	var inside: float = keep.radius + keep.blend
	var dir: Vector3 = keep.dir
	var reach := inside + 2.0 * edge
	var seen := PackedByteArray()
	seen.resize(low.size())
	seen.fill(0)
	var start := map.cell_number(dir)
	var todo := PackedInt32Array([start])
	seen[start] = 1
	var near := PackedInt32Array()
	near.resize(4)
	var at := 0
	while at < todo.size():
		var c := todo[at]
		at += 1
		var metres := _cell_centre(c, dirs).angle_to(dir) * radius
		if metres > reach:
			continue
		if metres - edge < inside:
			low[c] = minf(low[c], KEPT_LOW)
			high[c] = maxf(high[c], KEPT_HIGH)
		_cell_neighbours(c, near)
		for o in near:
			if seen[o] == 0:
				seen[o] = 1
				todo.append(o)

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
				var rolled := clampf(roll.get_noise_3dv(d), -1.0, 1.0)
				var base := BASE_ROLL * rolled
				if sea:
					var s := shore[k]
					# Past the beach, as _coast gives it, without the call.
					base = _coast(base, s) if s < BEACH_WIDTH else maxf(base, sea_level + LAND_ABOVE)
					map.set_corner(S_SHORE, face, i, j, s)
				map.set_corner(S_BASE, face, i, j, base)
				map.set_corner(S_DUNES, face, i, j, clampf(
					0.5 + DUNES_CONTRAST * dunes.get_noise_3dv(d) - DUNES_LOW_LEAN * rolled, 0.0, 1.0))
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
## that is an error, and the nearest miss is kept. `copies` are each face-edge
## corner's copies (_corner_copies).
func _seas(recipe: WorldRecipe, dirs: PackedVector3Array, copies: Dictionary) -> PackedFloat32Array:
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
	var canon := _canon(copies, dirs.size())
	var full := PackedByteArray()
	full.resize(dirs.size())
	full.fill(4)
	for k: int in copies:
		var group: PackedInt32Array = copies[k]
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

## Draws the dials' ranges into shapes.ranges (§5.4 step 3) and lays them on
## the map (_lay_ranges). Each range's spine is the first of a seeded run of
## candidates that keeps off the sea, keeps its flanks off every kept disc
## (_clearance) and off the flanks of the ranges before it. On a world whose
## design pins a range (`pins.range`) the first range passes within the pin's
## reach of its place, its middle aimed halfway between that and the place's
## kept disc; on a world with a sea one range runs inland from the coast, its
## first point within a cell of the shore. If no candidate keeps every rule,
## that is an error, and the nearest miss is kept. `shore` is each corner's
## metres to the nearest shore, by k; `copies` are each face-edge corner's
## copies (_corner_copies).
func _ranges(recipe: WorldRecipe, dirs: PackedVector3Array, shore: PackedFloat32Array, copies: Dictionary) -> void:
	if dials.ranges <= 0 or dials.mountains <= 0.0:
		return
	var radius := recipe.radius_m
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	var rng := WorldSeed.rng(recipe.seed, &"plan_ranges")
	var bend := _noise(recipe, &"plan_range_bend", RANGE_BEND_WAVE, 2)
	var summits := _noise(recipe, &"plan_summits", SUMMIT_WAVE, 2)
	var canon := _canon(copies, dirs.size())
	var pin := _range_pin(recipe)
	# Where a range may set out inland from: corners on land within a cell of
	# the water.
	var coast := PackedInt32Array()
	if sea_level > -INF:
		for k in dirs.size():
			var s := shore[k]
			if s > 0.0 and s <= edge and canon[k] == k:
				coast.append(k)
	var coastal := -1
	if not coast.is_empty():
		coastal = 1 if pin and dials.ranges > 1 else 0
	# Each range's flanks' share of the sphere, square metres.
	var area := dials.mountains * 4.0 * PI * radius * radius / dials.ranges
	for n in dials.ranges:
		var size := _range_size(area, rng)
		var top := dials.peak if n == 0 else dials.peak * rng.randf_range(RANGE_TOP_LEAST, 1.0)
		var aimed := pin and n == 0
		var to_coast := n == coastal
		var aim := 0.0
		if aimed:
			for keep: Dictionary in recipe.keeps:
				if keep.place == pin.place:
					aim = maxf(aim, _clearance(keep, size.y, edge))
			aim = (aim + pin.within) * 0.5
		var best := {}
		var best_miss := INF
		for attempt in RANGE_TRIES:
			# A range with both rules is drawn each way by turns.
			var inland := to_coast and not (aimed and attempt % 2 == 0)
			var spine: PackedVector3Array
			if inland:
				var at := dirs[coast[rng.randi() % coast.size()]]
				var heading := _rotated(_inland(at, 0.5 * edge / radius), at, rng.randf_range(-0.25 * PI, 0.25 * PI))
				spine = _march(at, heading, size.x, radius, bend, 1.0)
			elif aimed:
				var mid := _toward(pin.dir, aim / radius, rng.randf() * TAU)
				var toward: Vector3 = (pin.dir - mid * mid.dot(pin.dir)).normalized()
				spine = _spine_through(mid, mid.cross(toward), size.x, radius, bend)
			else:
				var mid := _anywhere(rng)
				spine = _spine_through(mid, _tangent(mid, rng.randf() * TAU), size.x, radius, bend)
			var miss := _range_miss(recipe, spine, size, pin if aimed else {}, edge if to_coast else 0.0)
			if miss < best_miss:
				best = {"spine": spine, "height": PackedFloat32Array(), "half_width": size.y}
				best_miss = miss
			if miss == 0.0:
				break
		if best_miss > 0.0:
			push_error("WorldPlan: no spine for range %d of %s keeps off the sea, its kept discs and the other ranges%s%s; kept the nearest miss" % [
				n + 1, recipe.name, " and meets its range pin" if aimed else "", " and runs to the coast" if to_coast else ""])
		best.height = _spine_heights(best.spine, top, rng, summits)
		shapes.ranges.append(best)
	_lay_ranges(dirs, canon, edge)

## The design's pin on a range (§5.3): {"place", "dir", "within": metres from
## the place to the nearest spine, at most}, or {} if it pins none (or names no
## place on this world).
static func _range_pin(recipe: WorldRecipe) -> Dictionary:
	var pins: Variant = recipe.plan_pins.get("pins", {})
	var pin: Variant = pins.get("range") if pins is Dictionary else null
	if not pin is Dictionary:
		return {}
	var place := StringName(str(pin.get("place", "")))
	var within: Variant = pin.get("within")
	if not recipe.pin_places.has(place) or not (within is float or within is int):
		return {}
	return {"place": place, "dir": recipe.pin_places[place], "within": float(within)}

## Vector2(length, half-width) of a range whose flanks cover `area` square
## metres (2 * length * half-width either side, and round its ends): a
## half-width drawn from RANGE_HALF_WIDTH, the length to suit within
## RANGE_LENGTH, then the half-width to suit that length, within its own.
static func _range_size(area: float, rng: RandomNumberGenerator) -> Vector2:
	var half := rng.randf_range(RANGE_HALF_WIDTH.x, RANGE_HALF_WIDTH.y)
	var length := clampf(area / (2.0 * half) - PI * half * 0.5, RANGE_LENGTH.x, RANGE_LENGTH.y)
	half = clampf((sqrt(length * length + PI * area) - length) / PI, RANGE_HALF_WIDTH.x, RANGE_HALF_WIDTH.y)
	return Vector2(length, half)

## The metres a range's spine keeps from `keep`'s place, its flanks
## `half_width` wide: the disc's radius and blend, the flanks, and
## KEEP_CLEAR_CELLS cells more.
static func _clearance(keep: Dictionary, half_width: float, edge: float) -> float:
	return keep.radius + keep.blend + half_width + KEEP_CLEAR_CELLS * edge

## How far `spine`, of a range `size` (Vector2(length, half-width)), misses its
## rules, in metres; 0 when it keeps them all. No point at sea or on the
## water's edge; clear of every kept disc (_clearance); its flanks clear of the
## ranges already drawn; with a `pin`, within its reach of its place; with
## `coast` over 0, an end within `coast` metres of the shore.
func _range_miss(recipe: WorldRecipe, spine: PackedVector3Array, size: Vector2, pin: Dictionary, coast: float) -> float:
	var radius := recipe.radius_m
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	var miss := 0.0
	if sea_level > -INF:
		for d in spine:
			var s := nearest_shore_m(d)
			if s <= 0.0:
				miss += 1.0 - s
	for keep: Dictionary in recipe.keeps:
		miss += maxf(0.0, _clearance(keep, size.y, edge) - _spine_angle(spine, keep.dir) * radius)
	var mid := spine[spine.size() / 2]
	for r: Dictionary in shapes.ranges:
		var other: PackedVector3Array = r.spine
		var apart: float = size.y + r.half_width
		# Every point of a spine lies within half its length of its middle.
		if mid.angle_to(other[other.size() / 2]) * radius > (size.x + _spine_length(other, radius)) * 0.5 + apart:
			continue
		var near := INF
		for d in spine:
			near = minf(near, _spine_angle(other, d))
		miss += maxf(0.0, apart - near * radius)
	if pin:
		miss += maxf(0.0, _spine_angle(spine, pin.dir) * radius - pin.within)
	if coast > 0.0:
		miss += maxf(0.0, minf(absf(nearest_shore_m(spine[0])), absf(nearest_shore_m(spine[-1]))) - coast)
	return miss

## `length` metres of spine from `from`, setting out along `heading` (a unit
## tangent there): a point every SPINE_STEP or so, the heading turned between
## them as `bend` says there (`turn` -1 turns it the other way, for a spine
## marched backward). Gives back the points, `from` first.
static func _march(from: Vector3, heading: Vector3, length: float, radius: float, bend: FastNoiseLite,
		turn: float) -> PackedVector3Array:
	var steps := maxi(1, roundi(length / SPINE_STEP))
	var step := length / steps
	var angle := step / radius
	var out := PackedVector3Array()
	out.resize(steps + 1)
	out[0] = from
	var p := from
	var t := heading
	for n in steps:
		t = _rotated(t, p, turn * RANGE_BEND * step * clampf(bend.get_noise_3dv(p), -1.0, 1.0))
		var q := (p * cos(angle) + t * sin(angle)).normalized()
		t = t * cos(angle) - p * sin(angle)
		p = q
		t = (t - p * p.dot(t)).normalized()
		out[n + 1] = p
	return out

## A spine `length` metres long whose middle is `mid`, running along `heading`
## (a unit tangent there): _march both ways from it, end to end.
static func _spine_through(mid: Vector3, heading: Vector3, length: float, radius: float,
		bend: FastNoiseLite) -> PackedVector3Array:
	var ahead := _march(mid, heading, length * 0.5, radius, bend, 1.0)
	var behind := _march(mid, -heading, length * 0.5, radius, bend, -1.0)
	behind.reverse()
	behind.append_array(ahead.slice(1))
	return behind

## The unit tangent at `at` that leads most steeply away from the sea, by the
## shore's metres `angle` radians either way.
func _inland(at: Vector3, angle: float) -> Vector3:
	var east := _tangent(at, 0.0)
	var north := _tangent(at, 0.5 * PI)
	var away := east * (nearest_shore_m(_toward(at, angle, 0.0)) - nearest_shore_m(_toward(at, angle, PI))) \
		+ north * (nearest_shore_m(_toward(at, angle, 0.5 * PI)) - nearest_shore_m(_toward(at, angle, 1.5 * PI)))
	return away.normalized() if away.length_squared() > 0.0 else east

## By point of `spine`, the metres it stands over the open ground: `top` at the
## tallest, about a crest drawn from `rng` a quarter to three quarters along it
## and falling toward each end to RANGE_END of the crest, its summits and
## saddles from `summits`.
static func _spine_heights(spine: PackedVector3Array, top: float, rng: RandomNumberGenerator,
		summits: FastNoiseLite) -> PackedFloat32Array:
	var n := spine.size()
	var crest := rng.randf_range(0.25, 0.75)
	var raw := PackedFloat64Array()
	raw.resize(n)
	var most := 0.0
	for i in n:
		var t := float(i) / float(n - 1)
		var u := (t - crest) / (crest if t < crest else 1.0 - crest)
		raw[i] = lerpf(RANGE_END, 1.0, 1.0 - u * u) * (1.0 + SUMMITS * clampf(summits.get_noise_3dv(spine[i]), -1.0, 1.0))
		most = maxf(most, raw[i])
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i] / most * top
	return out

## Lays shapes.ranges on the map. For each range a front over the cells, from
## those its spine crosses, finds every cell whose centre lies within its
## half-width and a cell of the spine, and lists the range near it with the
## segments that may hold the spine's nearest point to any point of the cell
## (those as near its centre as the nearest and two cells more: a point of a
## cell is within 0.77 of a cell of its centre). At those cells' corners:
## S_RIDGE, metres to the nearest spine of any range; S_MOUNTAIN, 1 at a spine
## falling evenly to 0 at its half-width, the most of any range; and the base
## raised by the spine's height there times that weight squared, the most of
## any range. Neither weight nor rise on the water's edge or at sea: a range
## ends at the coast, and its shore is a cliff. `canon` is by k the k standing
## for a corner's copies.
func _lay_ranges(dirs: PackedVector3Array, canon: PackedInt32Array, edge: float) -> void:
	var radius := shapes.radius_m
	var count := dirs.size()
	var up := PlanMap.SIDE
	var ridge := PackedFloat32Array()
	ridge.resize(count)
	ridge.fill(INF)
	var weight := PackedFloat32Array()
	weight.resize(count)
	weight.fill(0.0)
	var lift := PackedFloat32Array()
	lift.resize(count)
	lift.fill(0.0)
	# By cell, and by canon k: the last range to reach it.
	var seen := PackedInt32Array()
	seen.resize(CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS)
	seen.fill(-1)
	var done := PackedInt32Array()
	done.resize(count)
	done.fill(-1)
	var near := PackedInt32Array()
	near.resize(4)
	var span := 2.0 * edge / radius
	for r in shapes.ranges.size():
		var shape: Dictionary = shapes.ranges[r]
		var spine: PackedVector3Array = shape.spine
		var tall: PackedFloat32Array = shape.height
		var half: float = shape.half_width
		var end := spine.size() - 2
		var reach := (half + edge) / radius
		# The front: cells to visit, and by each where to start looking, the
		# nearest segment and the window of the cell it was reached from.
		var todo := PackedInt32Array()
		var hint := PackedVector3Array()
		for s in spine.size():
			var c := PlanShapes.cell_index(map.cell_of(spine[s]))
			if seen[c] != r:
				seen[c] = r
				todo.append(c)
				var h := mini(s, end)
				hint.append(Vector3(h, h, h))
		var at := 0
		while at < todo.size():
			var c := todo[at]
			var from := Vector3i(hint[at])
			at += 1
			var mid := _cell_centre(c, dirs)
			# The segment nearest the centre: down or up the spine from the
			# hint while it nears.
			var h := from.x
			var best := _segment_angle(spine, h, mid)
			while h > 0:
				var a := _segment_angle(spine, h - 1, mid)
				if a >= best:
					break
				best = a
				h -= 1
			while h < end:
				var a := _segment_angle(spine, h + 1, mid)
				if a >= best:
					break
				best = a
				h += 1
			if best > reach:
				continue
			# The window: every segment about h within `bound`, its ends moved
			# from the last cell's, out while within it or in while not.
			var bound := best + span
			var first := mini(from.y, h)
			if first > 0 and _segment_angle(spine, first - 1, mid) <= bound:
				first -= 1
				while first > 0 and _segment_angle(spine, first - 1, mid) <= bound:
					first -= 1
			else:
				while first < h and _segment_angle(spine, first, mid) > bound:
					first += 1
			var last := maxi(from.z, h)
			if last < end and _segment_angle(spine, last + 1, mid) <= bound:
				last += 1
				while last < end and _segment_angle(spine, last + 1, mid) <= bound:
					last += 1
			else:
				while last > h and _segment_angle(spine, last, mid) > bound:
					last -= 1
			shapes.add_near(c, PlanShapes.RANGE * PlanShapes.SHAPES + r, first, last)
			var k0 := _first_corner(c)
			for e in 4:
				var k := canon[k0 + (e & 1) + (e >> 1) * up]
				if done[k] == r:
					continue
				done[k] = r
				var d := dirs[k]
				var angle := INF
				var height := 0.0
				for s in range(first, last + 1):
					var a := spine[s]
					var ab := spine[s + 1] - a
					var t := clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					var by := d.angle_to(a + ab * t)
					if by < angle:
						angle = by
						height = lerpf(tall[s], tall[s + 1], t)
				var metres := angle * radius
				ridge[k] = minf(ridge[k], metres)
				if _corner_at(S_SHORE, k) > 0.0:
					var w := 1.0 - minf(metres / half, 1.0)
					weight[k] = maxf(weight[k], w)
					lift[k] = maxf(lift[k], height * w * w)
			_cell_neighbours(c, near)
			for o in near:
				if seen[o] != r:
					seen[o] = r
					todo.append(o)
					hint.append(Vector3(h, first, last))
	for k in count:
		if canon[k] != k or ridge[k] == INF:
			continue
		var face := k / (up * up)
		var i := k % up
		var j := (k / up) % up
		map.set_corner(S_RIDGE, face, i, j, ridge[k])
		map.set_corner(S_MOUNTAIN, face, i, j, weight[k])
		if lift[k] > 0.0:
			map.set_corner(S_BASE, face, i, j, map.corner(S_BASE, face, i, j) + lift[k])

## Draws the dials' plateau regions into shapes.plateaus (§5.4 step 4) and lays
## them on the map (_lay_plateaus). The `plateaus` share is split evenly between
## a seeded number of regions, each the first of a seeded run of centres,
## inland of the sea, whose region grows (_grow, then _tidy) to its share clear
## of the sea's cells, of the ranges' flanks (a cell with a corner of any
## weight), of the kept discs and of the regions before it. A region is as full
## as the room lets it be: one that finds little is small, never an error.
## `shore` is each corner's metres to the nearest shore, by k; `copies` are each
## face-edge corner's copies (_corner_copies).
func _plateaus(recipe: WorldRecipe, dirs: PackedVector3Array, shore: PackedFloat32Array, copies: Dictionary) -> void:
	if dials.plateaus <= 0.0:
		return
	var radius := recipe.radius_m
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	var rng := WorldSeed.rng(recipe.seed, &"plan_plateaus")
	var noise := _noise(recipe, &"plan_plateau_edge", PLATEAU_WAVE, 2)
	var canon := _canon(copies, dirs.size())
	var full := PackedByteArray()
	full.resize(dirs.size())
	full.fill(4)
	for k: int in copies:
		var group: PackedInt32Array = copies[k]
		if group.size() == 3:
			full[group[0]] = 3
	var count := rng.randi_range(PLATEAU_REGIONS.x, PLATEAU_REGIONS.y)
	var share := dials.plateaus / count
	var area := 4.0 * PI * share * PLATEAU_GROW
	var reach := acos(1.0 - 2.0 * share) * radius
	var rough := PLATEAU_ROUGH * reach
	var step := edge / 8.0
	# 1 for each cell of the sea, and then of each region and the two cells
	# round it, so no two regions share even a corner.
	var taken := PackedByteArray()
	taken.resize(CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS)
	taken.fill(0)
	for sea: Dictionary in shapes.seas:
		for c: int in sea.cells:
			taken[c] = 1
	# Cells with a corner on a range's flanks are not for plateaus: the cells
	# the ranges are listed near, which reach as far as any of their weight.
	var blocked := PackedByteArray()
	blocked.resize(taken.size())
	blocked.fill(0)
	shapes.mark_near_ranges(blocked)
	# Each kept disc as Vector4(direction, the cosine of the angle within
	# which a cell is in it or its blend).
	var discs: Array[Vector4] = []
	for keep: Dictionary in recipe.keeps:
		var angle: float = (keep.radius + keep.blend + edge) / radius
		var dir: Vector3 = keep.dir
		discs.append(Vector4(dir.x, dir.y, dir.z, cos(angle)))
	var inland := PLATEAU_INLAND_CELLS * edge
	for n in count:
		var top := rng.randf_range(PLATEAU_TOP.x, PLATEAU_TOP.y)
		var best := PackedInt32Array()
		var best_got := -1.0
		for attempt in PLATEAU_TRIES:
			var centre := _anywhere(rng)
			var start := PlanShapes.cell_index(map.cell_of(centre))
			var mid := _cell_centre(start, dirs)
			if taken[start] != 0 or blocked[start] != 0 or _in_discs(mid, discs) or shore[_first_corner(start)] < inland:
				continue
			var priority := func(c: int) -> float:
				if blocked[c] != 0:
					return INF
				var at := _cell_centre(c, dirs)
				if _in_discs(at, discs):
					return INF
				return acos(minf(at.dot(mid), 1.0)) * radius + rough * (1.0 + clampf(noise.get_noise_3dv(at), -1.0, 1.0))
			var grown := _grow(start, area, priority, step, taken, dirs)
			var cells := _tidy(grown.cells, priority, taken, canon, full)
			# Tidying moves a few cells: the grown area is near enough.
			var got: float = grown.area
			if got > best_got:
				best = cells
				best_got = got
			if got >= area * PLATEAU_FULL:
				break
		if best.is_empty():
			continue
		shapes.plateaus.append({"cells": best, "top": top})
		_take(best, taken)
	_lay_plateaus(canon, full)

## True if `d` is within any of `discs` (Vector4 of a direction and the cosine
## of an angle, as _plateaus makes them).
static func _in_discs(d: Vector3, discs: Array[Vector4]) -> bool:
	for disc in discs:
		if d.x * disc.x + d.y * disc.y + d.z * disc.z > disc.w:
			return true
	return false

## Lays shapes.plateaus on the map, and lists each region near its cells and
## the cells beside them. A cell is on its region's edge if a cell beside it is
## not in the region (depth 1), else inside (depth 2: the edge band is two cells
## deep); a corner with every cell round it in a region is as deep as the
## shallowest of them, any other (on the outline) is 0 deep. At every corner a
## region's cells touch, S_PLATEAU_TOP is its top; S_PLATEAU is smoothstep(0,
## 1, depth over PLATEAU_EDGE_CELLS); and the base is lerped toward the top by
## it. `canon` and `full` are by k the k standing for a corner's copies and how
## many cells meet there. Regions share no corner (_take), so a corner has one
## owner.
func _lay_plateaus(canon: PackedInt32Array, full: PackedByteArray) -> void:
	if shapes.plateaus.is_empty():
		return
	var up := PlanMap.SIDE
	var cells := CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS
	# By cell, the region it is in plus one (0 for none).
	var region := PackedInt32Array()
	region.resize(cells)
	region.fill(0)
	for r in shapes.plateaus.size():
		for c: int in shapes.plateaus[r].cells:
			region[c] = r + 1
	# By cell, the last region listed near it.
	var listed := PackedInt32Array()
	listed.resize(cells)
	listed.fill(-1)
	# By canon k: the shallowest cell there, how many cells meet, and whose.
	var shallow := PackedByteArray()
	shallow.resize(canon.size())
	shallow.fill(255)
	var meet := PackedByteArray()
	meet.resize(canon.size())
	meet.fill(0)
	var owner := PackedInt32Array()
	owner.resize(canon.size())
	owner.fill(0)
	var touched := PackedInt32Array()
	var near := PackedInt32Array()
	near.resize(4)
	for r in shapes.plateaus.size():
		var shape := PlanShapes.PLATEAU * PlanShapes.SHAPES + r
		for c: int in shapes.plateaus[r].cells:
			_cell_neighbours(c, near)
			var depth := 2
			for e in 4:
				var o := near[e]
				if region[o] != r + 1:
					depth = 1
				if listed[o] != r:
					listed[o] = r
					shapes.add_near(o, shape)
			if listed[c] != r:
				listed[c] = r
				shapes.add_near(c, shape)
			var k := _first_corner(c)
			for e in 4:
				var at := canon[k + (e & 1) + (e >> 1) * up]
				if meet[at] == 0:
					touched.append(at)
				shallow[at] = mini(shallow[at], depth)
				meet[at] += 1
				owner[at] = r + 1
	for k in touched:
		var face := k / (up * up)
		var i := k % up
		var j := (k / up) % up
		var top: float = shapes.plateaus[owner[k] - 1].top
		var w := 0.0
		if meet[k] == full[k]:
			w = smoothstep(0.0, 1.0, float(shallow[k]) / PLATEAU_EDGE_CELLS)
		map.set_corner(S_PLATEAU_TOP, face, i, j, top)
		map.set_corner(S_PLATEAU, face, i, j, w)
		if w > 0.0:
			map.set_corner(S_BASE, face, i, j, lerpf(map.corner(S_BASE, face, i, j), top, w))

## Draws the dials' canyons into shapes.canyons (§5.4 step 6), then their
## branches, and lists each near every cell its walls can reach
## (_list_canyon). On a world with a sea, if no canyon's mouth opens on a beach
## (_on_beach), the canyon nearest such a shore is routed to it instead; if none
## can be, that is an error. PlanCanyons draws each.
func _canyons(recipe: WorldRecipe, dirs: PackedVector3Array) -> void:
	if dials.canyons <= 0:
		return
	var draw := PlanCanyons.new(self, recipe, dirs)
	for n in dials.canyons:
		var c := draw.canyon(n)
		if c.is_empty():
			push_error("WorldPlan: no head for canyon %d of %s in plateau country or on a range's flank" % [n + 1, recipe.name])
			continue
		draw.take(c)
	var mains := shapes.canyons.size()
	if sea_level > -INF and mains > 0 and not shapes.canyons.any(_on_beach):
		draw.to_beach()
		if not shapes.canyons.any(_on_beach):
			push_error("WorldPlan: no canyon of %s opens on a beach" % recipe.name)
	if mains > 0:
		for n in draw.rng.randi_range(CANYON_BRANCHES.x, CANYON_BRANCHES.y):
			var b := draw.branch(mains)
			if b.is_empty():
				push_error("WorldPlan: no branch %d for %s's canyons" % [n + 1, recipe.name])
				continue
			draw.take(b)
	var seen := PackedInt32Array()
	seen.resize(CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS)
	seen.fill(-1)
	for i in shapes.canyons.size():
		_list_canyon(i, dirs, seen)

## True if canyon `c` meets the sea on open ground: no range's flank and no
## plateau over the last BEACH_WIDTH of its path.
func _on_beach(c: Dictionary) -> bool:
	if c.mouth != &"beach":
		return false
	var path: PackedVector3Array = c.path
	var back := 0.0
	for i in range(path.size() - 1, -1, -1):
		if map.at(S_MOUNTAIN, path[i]) > 0.0 or map.at(S_PLATEAU, path[i]) > 0.0:
			return false
		if i > 0:
			back += path[i].angle_to(path[i - 1]) * shapes.radius_m
			if back > BEACH_WIDTH:
				return true
	return true

## Lists canyon `i` near every cell its walls can reach, with the segments of
## its path from the first to the last that can be nearest a point of the cell:
## every segment within the canyon's widest reach and the cell's own (its middle
## to its farthest corner) of the cell's middle. The path is looked through in
## runs of LIST_RUN segments, each skipped whole where it lies too far, so every
## segment that may count is found even where the path winds back on itself.
## The cells are found by a front from those the path crosses, through the cells
## listed and a ring of cells past them. `seen` is by cell the last canyon to
## reach it.
func _list_canyon(i: int, dirs: PackedVector3Array, seen: PackedInt32Array) -> void:
	var c: Dictionary = shapes.canyons[i]
	var path: PackedVector3Array = c.path
	var half: PackedFloat32Array = c.half_floor
	var rim: PackedFloat32Array = c.rim
	var widest := 0.0
	for k in path.size():
		widest = maxf(widest, half[k] + rim[k] * CANYON_WALL_RUN)
	widest /= shapes.radius_m
	var segments := path.size() - 1
	# Each run's middle, and the radians within which its points lie of it.
	var runs := ceili(float(segments) / LIST_RUN)
	var middles := PackedVector3Array()
	middles.resize(runs)
	var spans := PackedFloat32Array()
	spans.resize(runs)
	for r in runs:
		var last := mini((r + 1) * LIST_RUN, segments)
		var m := Vector3.ZERO
		for k in range(r * LIST_RUN, last + 1):
			m += path[k]
		m = m.normalized()
		var span := 0.0
		for k in range(r * LIST_RUN, last + 1):
			span = maxf(span, m.angle_to(path[k]))
		middles[r] = m
		spans[r] = span
	var shape := PlanShapes.CANYON * PlanShapes.SHAPES + i
	var up := PlanMap.SIDE
	# The front, and by each cell whether the cell it was reached from was
	# listed (1) or not (0).
	var todo := PackedInt32Array()
	var after := PackedByteArray()
	for d in path:
		var cell := map.cell_number(d)
		if seen[cell] != i:
			seen[cell] = i
			todo.append(cell)
			after.append(1)
	var near := PackedInt32Array()
	near.resize(4)
	var at := 0
	while at < todo.size():
		var cell := todo[at]
		var from_listed := after[at] == 1
		at += 1
		var mid := _cell_centre(cell, dirs)
		var k := _first_corner(cell)
		var bound := widest + 1.01 * maxf(maxf(mid.angle_to(dirs[k]), mid.angle_to(dirs[k + 1])),
			maxf(mid.angle_to(dirs[k + up]), mid.angle_to(dirs[k + up + 1])))
		var first := segments
		var last := -1
		for r in runs:
			if mid.dot(middles[r]) < cos(minf(spans[r] + bound, PI)):
				continue
			for s in range(r * LIST_RUN, mini((r + 1) * LIST_RUN, segments)):
				if _segment_angle(path, s, mid) <= bound:
					first = mini(first, s)
					last = maxi(last, s)
		var listed := last >= 0
		if listed:
			shapes.add_near(cell, shape, first, last)
		elif not from_listed:
			continue
		_cell_neighbours(cell, near)
		for o in near:
			if seen[o] != i:
				seen[o] = i
				todo.append(o)
				after.append(1 if listed else 0)

## `field` averaged over cell `c`'s four corners: what it is at the cell's
## middle, read bilinearly.
func _cell_mean(field: int, c: int) -> float:
	var k := _first_corner(c)
	var up := PlanMap.SIDE
	return 0.25 * (_corner_at(field, k) + _corner_at(field, k + 1) + _corner_at(field, k + up) + _corner_at(field, k + up + 1))

## Radians from `d` to the nearest point of segment `s` of `spine` (from point
## s to point s + 1): to the nearest point of its chord, seen from the centre.
static func _segment_angle(spine: PackedVector3Array, s: int, d: Vector3) -> float:
	var a := spine[s]
	var ab := spine[s + 1] - a
	return d.angle_to(a + ab * clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0))

## Radians from `d` to the nearest point of `spine`.
static func _spine_angle(spine: PackedVector3Array, d: Vector3) -> float:
	var near := INF
	for s in spine.size() - 1:
		near = minf(near, _segment_angle(spine, s, d))
	return near

## Metres along `spine`, end to end, on a world of `radius`.
static func _spine_length(spine: PackedVector3Array, radius: float) -> float:
	return (spine.size() - 1) * spine[0].angle_to(spine[1]) * radius

## `field` at corner k.
func _corner_at(field: int, k: int) -> float:
	var up := PlanMap.SIDE
	return map.corner(field, k / (up * up), k % up, (k / up) % up)

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

## By k, the k standing for a corner and all its copies: the first of them, by
## `copies` (_corner_copies), of `count` corners.
static func _canon(copies: Dictionary, count: int) -> PackedInt32Array:
	var canon := PackedInt32Array(range(count))
	for k: int in copies:
		var group: PackedInt32Array = copies[k]
		canon[k] = group[0]
	return canon

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
	return (from * cos(angle) + _tangent(from, bearing) * sin(angle)).normalized()

## The unit tangent at `at` on the bearing `bearing`.
static func _tangent(at: Vector3, bearing: float) -> Vector3:
	var east := at.cross(Vector3.UP)
	if east.length_squared() < 1e-6:
		east = at.cross(Vector3.RIGHT)
	east = east.normalized()
	var north := at.cross(east)
	return east * cos(bearing) + north * sin(bearing)

## `v`, a tangent at `at`, turned `angle` radians about it.
static func _rotated(v: Vector3, at: Vector3, angle: float) -> Vector3:
	return v * cos(angle) + at.cross(v) * sin(angle)

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
