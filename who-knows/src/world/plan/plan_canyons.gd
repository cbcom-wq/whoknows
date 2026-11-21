class_name PlanCanyons
extends RefCounted

## What WorldPlan._canyons works with while it draws a plan's canyons (§5.4 step
## 6 of docs/superpowers/specs/2026-11-19-wadis-land-design.md): their routes
## down the cells, the curves drawn through them, and which cells a canyon may
## set out from or cross. Lives only while the plan is built.

var plan: WorldPlan
var recipe: WorldRecipe
## Every corner's direction, by k.
var dirs: PackedVector3Array
var radius: float
var edge: float
var rng: RandomNumberGenerator
var wander: FastNoiseLite
var wind: FastNoiseLite
var width: FastNoiseLite
## By cell, 1 for a sea's.
var wet := PackedByteArray()
## By cell, 1 + the index of the first canyon whose path crosses it or a
## cell beside it; 0 for none.
var owner := PackedInt32Array()
## By cell: the height a canyon steps down by (the base at its middle and
## the wander), INF too near a kept disc; and its middle's metres to the
## coast. NAN until first asked.
var _lie := PackedFloat32Array()
var _coast := PackedFloat32Array()
## The fields _over samples into, and WorldPlan.DETAIL_REACH by Land.
var _fields := PackedFloat64Array()
var _reach := PackedFloat64Array()
## By canyon index, once asked (toward): by cell, the steps from the cells
## its path crosses.
var _toward := {}

func _init(p_plan: WorldPlan, p_recipe: WorldRecipe, p_dirs: PackedVector3Array) -> void:
	plan = p_plan
	recipe = p_recipe
	dirs = p_dirs
	radius = recipe.radius_m
	edge = CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	rng = WorldSeed.rng(recipe.seed, &"plan_canyons")
	wander = WorldPlan._noise(recipe, &"plan_canyon_wander", WorldPlan.CANYON_WANDER_WAVE, 2)
	wind = WorldPlan._noise(recipe, &"plan_canyon_wind", WorldPlan.CANYON_WIND_WAVE, 2)
	width = WorldPlan._noise(recipe, &"plan_canyon_width", WorldPlan.CANYON_WIDTH_WAVE, 2)
	var cells := CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS
	wet.resize(cells)
	wet.fill(0)
	for sea: Dictionary in plan.shapes.seas:
		for c: int in sea.cells:
			wet[c] = 1
	owner.resize(cells)
	owner.fill(0)
	_lie.resize(cells)
	_lie.fill(NAN)
	_coast.resize(cells)
	_coast.fill(NAN)
	_fields.resize(WorldPlan.LAND_FIELDS)
	_reach.resize(WorldPlan.Land.size())
	for land: int in WorldPlan.DETAIL_REACH:
		_reach[land] = WorldPlan.DETAIL_REACH[land]

## The next canyon, `n` of the dials': of WorldPlan.CANYON_TRIES seeded heads, the
## first whose route down (pulled toward the coast) keeps clear of the kept
## discs and the other canyons, reaches the sea and is WorldPlan.CANYON_LENGTH.x long;
## else the nearest miss, by those three in that order, with an error if it
## is not clear (one that ends in a dry basin, or short, is only less
## liked). {} if no head was found.
func canyon(n: int) -> Dictionary:
	var sea := plan.sea_level > -INF
	var pull := func(c: int) -> float: return WorldPlan.CANYON_PULL * coast(c) if sea else 0.0
	var goal := func(c: int) -> bool: return wet[c] != 0
	var best := {}
	var best_rank := Vector3(INF, INF, INF)
	for attempt in WorldPlan.CANYON_TRIES:
		var start := head()
		if start < 0:
			continue
		var route := descend(start, goal, pull)
		var cells: PackedInt32Array = route.cells
		if cells.size() < 2:
			continue
		var rank := Vector3(cell_miss(cells, -1), 0.0 if route.reached or not sea else 1.0, 0.0)
		if not (rank < best_rank):
			continue
		var shape := shape_of(cells, route.reached, rng.randf_range(WorldPlan.CANYON_DEPTH.x, WorldPlan.CANYON_DEPTH.y), -1)
		rank.x += miss(shape)
		rank.z = short(shape)
		if rank < best_rank:
			best = shape
			best_rank = rank
		if rank == Vector3.ZERO:
			break
	if best_rank.x > 0.0 and not best.is_empty():
		push_error("WorldPlan: no head for canyon %d of %s gives one clear of its kept discs and the other canyons; kept the nearest miss" % [
			n + 1, recipe.name])
	return best

## A branch of one of the first `mains` canyons: of WorldPlan.CANYON_TRIES seeded
## heads, each WorldPlan.CANYON_BRANCH_FROM from a point of its parent's path and at
## least WorldPlan.CANYON_BRANCH_FROM.x from all of it, the first whose route down
## (pulled toward the parent's path) reaches it, falls at least
## WorldPlan.CANYON_DEPTH.x to the parent's floor where they meet, and keeps clear of
## the kept discs and the other canyons; else the nearest miss to reach it,
## with an error. Its depth is drawn, or as far as its head stands over the
## parent's floor where they meet, if less. {} if none reached it.
func branch(mains: int) -> Dictionary:
	var best := {}
	var best_miss := INF
	var least := ceili(WorldPlan.CANYON_BRANCH_FROM.x / edge)
	for attempt in WorldPlan.CANYON_TRIES:
		var p := rng.randi() % mains
		var parent: Dictionary = plan.shapes.canyons[p]
		var on: PackedVector3Array = parent.path
		var steps := toward(p)
		var start := -1
		for draw in WorldPlan.CANYON_TRIES:
			var c := plan.map.cell_number(WorldPlan._toward(on[rng.randi() % on.size()],
				rng.randf_range(WorldPlan.CANYON_BRANCH_FROM.x, WorldPlan.CANYON_BRANCH_FROM.y) / radius, rng.randf() * TAU))
			if steps[c] >= least and is_head(c):
				start = c
				break
		if start < 0:
			continue
		var route := descend(start, func(c: int) -> bool: return steps[c] == 0,
			func(c: int) -> float: return WorldPlan.CANYON_PULL * edge * steps[c] if steps[c] >= 0 else INF)
		if not route.reached:
			continue
		var cells: PackedInt32Array = route.cells
		var meet := _nearest(on, WorldPlan._cell_centre(cells[-1], dirs))
		var fall: float = plan._cell_mean(WorldPlan.S_BASE, start) - parent.floor[meet]
		var depth := minf(rng.randf_range(WorldPlan.CANYON_DEPTH.x, WorldPlan.CANYON_DEPTH.y), fall)
		var missed := cell_miss(cells, p) + maxf(0.0, WorldPlan.CANYON_DEPTH.x - depth)
		if missed >= best_miss:
			continue
		var shape := shape_of(cells, true, maxf(depth, WorldPlan.CANYON_DEPTH.x), p, meet)
		missed += miss(shape)
		if missed < best_miss:
			best = shape
			best_miss = missed
		if missed == 0.0:
			break
	if best_miss > 0.0 and not best.is_empty():
		push_error("WorldPlan: no branch of %s's canyons falls to its parent's floor clear of its kept discs and the other canyons; kept the nearest miss" % recipe.name)
	return best

## Routes a canyon to a beach: a land cell beside the sea with no range's
## flank or plateau in it or the land cells beside it, clear of the kept
## discs. Of the canyons drawn so far and the beaches, the nearest pairs
## first (WorldPlan.CANYON_TRIES of them, at most), the first canyon that, kept as it
## is down to its point nearest the beach and from there stepped down over
## the land to the beach (pulled toward it, WorldPlan.CANYON_BEACH_PULL) and into the
## sea beside it,
## meets the sea on a beach (_on_beach) and keeps every rule takes its
## place.
func to_beach() -> void:
	var beaches := PackedInt32Array()
	var near := PackedInt32Array()
	near.resize(4)
	var beside := PackedInt32Array()
	beside.resize(4)
	var seen := PackedByteArray()
	seen.resize(wet.size())
	seen.fill(0)
	for sea: Dictionary in plan.shapes.seas:
		for c: int in sea.cells:
			plan._cell_neighbours(c, near)
			for o in near:
				if wet[o] != 0 or seen[o] != 0:
					continue
				seen[o] = 1
				var open := lie(o) < INF and _open(o)
				plan._cell_neighbours(o, beside)
				for b in beside:
					open = open and (wet[b] != 0 or _open(b))
				if open:
					beaches.append(o)
	var canyons := plan.shapes.canyons
	# Each pair as Vector3(radians from the canyon's path to the beach, the
	# canyon, the beach), and by pair the path's point nearest the beach.
	var pairs: Array[Vector3] = []
	var points := {}
	for i in canyons.size():
		var path: PackedVector3Array = canyons[i].path
		for b in beaches.size():
			var at := WorldPlan._cell_centre(beaches[b], dirs)
			var best := Vector2(INF, 0)
			for k in range(0, path.size(), 6):
				var a := path[k].angle_to(at)
				if a < best.x:
					best = Vector2(a, k)
			pairs.append(Vector3(best.x, i, b))
			points[Vector2i(i, b)] = int(best.y)
	pairs.sort()
	for pair in pairs.slice(0, WorldPlan.CANYON_TRIES):
		var i := int(pair.y)
		var to := beaches[int(pair.z)]
		var at := WorldPlan._cell_centre(to, dirs)
		var path: PackedVector3Array = canyons[i].path
		var cells := PackedInt32Array()
		for k in points[Vector2i(i, int(pair.z))] + 1:
			var c := plan.map.cell_number(path[k])
			if cells.is_empty() or cells[-1] != c:
				cells.append(c)
		var rest := descend(cells[-1], func(c: int) -> bool: return c == to,
			func(c: int) -> float: return INF if wet[c] != 0 else WorldPlan.CANYON_BEACH_PULL * WorldPlan._cell_centre(c, dirs).angle_to(at) * radius)
		if not rest.reached:
			continue
		cells.append_array(rest.cells.slice(1))
		plan._cell_neighbours(to, near)
		for o in near:
			if wet[o] != 0:
				cells.append(o)
				break
		if cell_miss(cells, i) > 0.0:
			continue
		var shape := shape_of(cells, true, rng.randf_range(WorldPlan.CANYON_DEPTH.x, WorldPlan.CANYON_DEPTH.y), -1)
		if miss(shape) > 0.0 or not plan._on_beach(shape):
			continue
		keep(i, shape)
		owner.fill(0)
		for k in canyons.size():
			mark(k)
		return

## True if no range's flank and no plateau reaches into cell `c`.
func _open(c: int) -> bool:
	return plan._cell_mean(WorldPlan.S_MOUNTAIN, c) == 0.0 and plan._cell_mean(WorldPlan.S_PLATEAU, c) == 0.0

## Adds canyon `c` to the plan's (keep), and marks the cells its path crosses,
## and the cells beside them, its own.
func take(c: Dictionary) -> void:
	plan.shapes.canyons.append({})
	keep(plan.shapes.canyons.size() - 1, c)
	mark(plan.shapes.canyons.size() - 1)

## Puts canyon `c` in the plan's as canyon `i`, with an error if its rim has not
## settled somewhere (shape_of's "unsettled", taken out here).
func keep(i: int, c: Dictionary) -> void:
	var unsettled: int = c.get("unsettled", 0)
	c.erase("unsettled")
	plan.shapes.canyons[i] = c
	if unsettled > 0:
		push_error("WorldPlan: canyon %d of %s has a rim that does not settle at %d of its points within %d looks (CANYON_RIM_LOOKS): the ground there rises about as fast as its walls" % [
			i, recipe.name, unsettled, WorldPlan.CANYON_RIM_LOOKS])

## The height the walls must stand over at `d` where they end: the base and the
## DETAIL_REACH of the land there, from one sample of the fields that tell it.
func _over(d: Vector3) -> float:
	plan.map.sample(d, _fields, WorldPlan.LAND_FIELDS)
	return _fields[WorldPlan.S_BASE] + _reach[WorldPlan.land_in(_fields)]

## Marks the cells canyon `i`'s path crosses, and the cells beside them,
## its own, where no canyon has them yet.
func mark(i: int) -> void:
	var near := PackedInt32Array()
	near.resize(4)
	var last := -1
	for d: Vector3 in plan.shapes.canyons[i].path:
		var c := plan.map.cell_number(d)
		if c == last:
			continue
		last = c
		if owner[c] == 0:
			owner[c] = i + 1
		plan._cell_neighbours(c, near)
		for o in near:
			if owner[o] == 0:
				owner[o] = i + 1

## A seeded head for a canyon (is_head), drawn from a plateau region's
## cells or, WorldPlan.CANYON_FROM_RANGE of the time, about a range's lower flank; -1
## if WorldPlan.CANYON_TRIES draws find none.
func head() -> int:
	var ranges := plan.shapes.ranges
	var plateaus := plan.shapes.plateaus
	if ranges.is_empty() and plateaus.is_empty():
		return -1
	for draw in WorldPlan.CANYON_TRIES:
		var c: int
		if plateaus.is_empty() or (not ranges.is_empty() and rng.randf() < WorldPlan.CANYON_FROM_RANGE):
			var r: Dictionary = ranges[rng.randi() % ranges.size()]
			var spine: PackedVector3Array = r.spine
			var out: float = (1.0 - rng.randf_range(WorldPlan.CANYON_FLANK.x, WorldPlan.CANYON_FLANK.y)) * r.half_width
			c = plan.map.cell_number(WorldPlan._toward(spine[rng.randi() % spine.size()], out / radius, rng.randf() * TAU))
		else:
			var region: PackedInt32Array = plateaus[rng.randi() % plateaus.size()].cells
			c = region[rng.randi() % region.size()]
		if is_head(c):
			return c
	return -1

## True if a canyon may set out from cell `c`: on a plateau region's flat
## top, or where a range's flanks' weight is WorldPlan.CANYON_FLANK; on land, clear of
## the kept discs and of every canyon so far.
func is_head(c: int) -> bool:
	if owner[c] != 0 or wet[c] != 0 or lie(c) == INF:
		return false
	if plan._cell_mean(WorldPlan.S_PLATEAU, c) >= 1.0:
		return true
	var w := plan._cell_mean(WorldPlan.S_MOUNTAIN, c)
	return w >= WorldPlan.CANYON_FLANK.x and w <= WorldPlan.CANYON_FLANK.y

## The cells from `start` down, each the neighbour lowest by its lie plus
## pull(cell) metres, to the first that goal(cell) holds for:
## {"cells": PackedInt32Array, start first; "reached": bool}. It stops short,
## unreached, where no neighbour is lower or once it is WorldPlan.CANYON_LENGTH.y long.
func descend(start: int, goal: Callable, pull: Callable) -> Dictionary:
	var cells := PackedInt32Array([start])
	var here := start
	var height: float = lie(start) + pull.call(start)
	var most := ceili(WorldPlan.CANYON_LENGTH.y / edge)
	var near := PackedInt32Array()
	near.resize(4)
	while not goal.call(here):
		if cells.size() > most:
			return {"cells": cells, "reached": false}
		plan._cell_neighbours(here, near)
		var next := -1
		for o in near:
			var h := lie(o)
			if h < INF:
				h += pull.call(o)
				if h < height:
					height = h
					next = o
		if next < 0:
			return {"cells": cells, "reached": false}
		cells.append(next)
		here = next
	return {"cells": cells, "reached": true}

## The canyon `depth` deep (WorldPlan.CANYON_DEPTH) down `cells`, start first:
## its path a smooth curve through their middles (_curve), cut off at the water
## if it `reached` the sea or, for a branch of canyon `joins`, ending on point
## `meet` of its parent's path; its floor (WorldPlan.CANYON_GRADE,
## WorldPlan.CANYON_LAND_FLOOR), the floor's half-widths and the walls' rims
## (WorldPlan.CANYON_WALL_RUN, WorldPlan.DETAIL_REACH, WorldPlan.CANYON_RIM_LOOKS,
## WorldPlan.CANYON_RIM_SPARE). A rim that has not settled within
## CANYON_RIM_LOOKS is counted in "unsettled", which keep() takes out. Draws
## nothing from rng.
func shape_of(cells: PackedInt32Array, reached: bool, depth: float, joins: int, meet := -1) -> Dictionary:
	var points := PackedVector3Array()
	for c in cells:
		points.append(WorldPlan._cell_centre(c, dirs))
	var meets := -INF
	if joins >= 0:
		var parent: Dictionary = plan.shapes.canyons[joins]
		points[points.size() - 1] = parent.path[meet]
		meets = parent.floor[meet]
	var path := _curve(points)
	var mouth := &""
	if joins < 0:
		mouth = &"basin"
		if reached:
			for i in range(1, path.size()):
				if plan.nearest_shore_m(path[i]) <= 0.0:
					path = path.slice(0, i + 1)
					mouth = &"beach"
					break
	var n := path.size()
	var along := PackedFloat32Array()
	along.resize(n)
	along[0] = 0.0
	for i in range(1, n):
		along[i] = along[i - 1] + path[i - 1].angle_to(path[i]) * radius
	# The base along it, and what the walls must stand over there (_over).
	var base := PackedFloat32Array()
	base.resize(n)
	var over := PackedFloat64Array()
	over.resize(n)
	for i in n:
		over[i] = _over(path[i])
		base[i] = _fields[WorldPlan.S_BASE]
	# The floor: the running minimum, held over the sea until the mouth,
	# then from the mouth up never steeper than WorldPlan.CANYON_GRADE.
	var bed := PackedFloat32Array()
	bed.resize(n)
	var low := INF
	var land := WorldPlan.SEA_LEVEL + WorldPlan.CANYON_LAND_FLOOR
	for i in n:
		low = minf(low, base[i] - depth)
		bed[i] = maxf(maxf(low, land), meets)
	if mouth == &"beach":
		bed[n - 1] = plan.sea_level
	elif joins >= 0:
		bed[n - 1] = meets
	for i in range(n - 2, -1, -1):
		bed[i] = minf(bed[i], bed[i + 1] + WorldPlan.CANYON_GRADE * (along[i + 1] - along[i]))
	var half := PackedFloat32Array()
	half.resize(n)
	for i in n:
		var w := lerpf(WorldPlan.CANYON_FLOOR_WIDTH.x, WorldPlan.CANYON_FLOOR_WIDTH.y, clampf(0.5 + width.get_noise_3dv(path[i]), 0.0, 1.0))
		if mouth == &"basin":
			w = lerpf(w, WorldPlan.CANYON_FLOOR_WIDTH.y, smoothstep(along[n - 1] - WorldPlan.CANYON_BASIN, along[n - 1], along[i]))
		half[i] = 0.5 * w
	# The rim: over the ground and its detail where the walls end on either
	# side, found by looking out to where they would end and, while the
	# ground there stands higher, out again (a little past it, so it settles
	# soon on rising ground), until it settles.
	var rim := PackedFloat32Array()
	rim.resize(n)
	var unsettled := 0
	for i in n:
		var across := path[i].cross(path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var top := over[i]
		var settled := false
		for look in WorldPlan.CANYON_RIM_LOOKS:
			var out := (half[i] + (top - bed[i]) * WorldPlan.CANYON_WALL_RUN) / radius
			var mid := path[i] * cos(out)
			var side := across * sin(out)
			var higher := maxf(_over(mid + side), _over(mid - side))
			if higher <= top:
				settled = true
				break
			top = higher + WorldPlan.CANYON_RIM_SPARE
		if not settled:
			unsettled += 1
		rim[i] = top - bed[i]
	var shape := {"path": path, "floor": bed, "half_floor": half, "rim": rim, "mouth": mouth}
	if unsettled > 0:
		shape["unsettled"] = unsettled
	if joins >= 0:
		shape["joins"] = joins
	return shape

## A smooth curve through `points` (unit directions) from the first to the
## last: their corners cut twice over (Chaikin's), then a point every
## WorldPlan.CANYON_STEP metres or so along it, each moved across it by the winding,
## less within half a WorldPlan.CANYON_WIND_WAVE of its ends, so they stay put.
func _curve(points: PackedVector3Array) -> PackedVector3Array:
	var p := points
	for turn in 2:
		if p.size() < 3:
			break
		var cut := PackedVector3Array([p[0]])
		for i in p.size() - 1:
			cut.append((p[i] * 0.75 + p[i + 1] * 0.25).normalized())
			cut.append((p[i] * 0.25 + p[i + 1] * 0.75).normalized())
		cut.append(p[-1])
		p = cut
	var along := PackedFloat64Array()
	along.resize(p.size())
	along[0] = 0.0
	for i in range(1, p.size()):
		along[i] = along[i - 1] + p[i - 1].angle_to(p[i])
	var total := along[-1] * radius
	var n := maxi(1, roundi(total / WorldPlan.CANYON_STEP))
	var even := PackedVector3Array()
	even.resize(n + 1)
	var s := 0
	for k in n + 1:
		var want := along[-1] * k / n
		while s < p.size() - 2 and along[s + 1] < want:
			s += 1
		var span := along[s + 1] - along[s]
		even[k] = p[s].lerp(p[s + 1], (want - along[s]) / span if span > 0.0 else 0.0).normalized()
	even[0] = p[0]
	even[n] = p[-1]
	var out := even.duplicate()
	var ends := WorldPlan.CANYON_WIND_WAVE * 0.5
	for k in range(1, n):
		var across := even[k].cross(even[k + 1] - even[k - 1]).normalized()
		var off := WorldPlan.CANYON_WIND * clampf(wind.get_noise_3dv(even[k]), -1.0, 1.0) \
			* smoothstep(0.0, ends, mini(k, n - k) * total / n)
		out[k] = (even[k] + across * (off / radius)).normalized()
	return out

## Metres canyon `c`'s walls reach within a kept disc's radius and blend.
func miss(c: Dictionary) -> float:
	var path: PackedVector3Array = c.path
	var half: PackedFloat32Array = c.half_floor
	var rim: PackedFloat32Array = c.rim
	var out := 0.0
	for keep: Dictionary in recipe.keeps:
		var near := INF
		for s in path.size() - 1:
			var reach := maxf(half[s] + rim[s] * WorldPlan.CANYON_WALL_RUN, half[s + 1] + rim[s + 1] * WorldPlan.CANYON_WALL_RUN)
			near = minf(near, WorldPlan._segment_angle(path, s, keep.dir) * radius - reach)
		out += maxf(0.0, keep.radius + keep.blend - near)
	return out

## Metres canyon `c` is short of WorldPlan.CANYON_LENGTH.x.
func short(c: Dictionary) -> float:
	var path: PackedVector3Array = c.path
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].angle_to(path[i]) * radius
	return maxf(0.0, WorldPlan.CANYON_LENGTH.x - length)

## Metres of `cells` that are another canyon's, or beside one: any but
## canyon `own`'s.
func cell_miss(cells: PackedInt32Array, own: int) -> float:
	var out := 0.0
	for c in cells:
		if owner[c] != 0 and owner[c] != own + 1:
			out += edge
	return out

## The height a canyon steps down by in cell `c`, INF too near a kept disc.
func lie(c: int) -> float:
	var h := _lie[c]
	if is_nan(h):
		var mid := WorldPlan._cell_centre(c, dirs)
		h = plan._cell_mean(WorldPlan.S_BASE, c) + WorldPlan.CANYON_WANDER * clampf(wander.get_noise_3dv(mid), -1.0, 1.0)
		for keep: Dictionary in recipe.keeps:
			if mid.angle_to(keep.dir) * radius < keep.radius + keep.blend + WorldPlan.CANYON_KEEP_CLEAR:
				h = INF
		_lie[c] = h
	return h

## Metres from cell `c`'s middle to the coast.
func coast(c: int) -> float:
	var s := _coast[c]
	if is_nan(s):
		s = plan._cell_mean(WorldPlan.S_SHORE, c)
		_coast[c] = s
	return s

## By cell, the steps to it from the cells canyon `p`'s path crosses (0 for
## those), out to a cell past WorldPlan.CANYON_BRANCH_FROM.y; -1 beyond.
func toward(p: int) -> PackedInt32Array:
	if _toward.has(p):
		return _toward[p]
	var steps := PackedInt32Array()
	steps.resize(wet.size())
	steps.fill(-1)
	var ring := PackedInt32Array()
	for d: Vector3 in plan.shapes.canyons[p].path:
		var c := plan.map.cell_number(d)
		if steps[c] < 0:
			steps[c] = 0
			ring.append(c)
	var near := PackedInt32Array()
	near.resize(4)
	for r in ceili(WorldPlan.CANYON_BRANCH_FROM.y / edge) + 1:
		var next := PackedInt32Array()
		for c in ring:
			plan._cell_neighbours(c, near)
			for o in near:
				if steps[o] < 0:
					steps[o] = r + 1
					next.append(o)
		ring = next
	_toward[p] = steps
	return steps

## The index of the point of `path`, short of its last, nearest `d`.
static func _nearest(path: PackedVector3Array, d: Vector3) -> int:
	var best := 0
	for i in path.size() - 1:
		if path[i].angle_to(d) < path[best].angle_to(d):
			best = i
	return best
