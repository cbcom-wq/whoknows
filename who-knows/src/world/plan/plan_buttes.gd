class_name PlanButtes
extends RefCounted

## Stands a world plan's buttes and small mesas on its open ground
## (docs/superpowers/specs/2026-11-19-wadis-land-design.md §6, Checkpoint 1; the
## `buttes` dial, §5.2) into PlanShapes.buttes, and lists each near every cell its
## reach may touch. Run once while the plan is built (WorldPlan.build), after its
## canyons and before its near lists are packed, its sites and its bounds; the
## constants it uses are WorldPlan's (BUTTE_* and MESA_RADIUS).

var plan: WorldPlan
## By cell: 0 not yet looked at, 1 open ground a butte may reach, 2 not
## (_open_cell).
var _open := PackedByteArray()
## By cell: 1 where a canyon is listed near.
var _canyon_near := PackedByteArray()

func _init(p_plan: WorldPlan) -> void:
	plan = p_plan

## Stands the dial's buttes: its count per 1,000 km² of open desert (the dials'
## open share of the sphere), rounded to a whole one. Groups are centred on seeded
## points even over the sphere, and each member is drawn (_draw) and kept if it
## fits its ground (_fits), until that many stand or BUTTE_TRIES groups for each
## have been tried. `dirs` are the map's corners' directions and `cv` its corners'
## values (PlanBounds.corner_values).
func stand(recipe: WorldRecipe, dirs: PackedVector3Array, cv: Array[PackedFloat32Array]) -> void:
	var radius := recipe.radius_m
	var open_km2 := plan.dials.open_share() * 4.0 * PI * radius * radius / 1e6
	var want := roundi(plan.dials.buttes * open_km2 / 1000.0)
	if want <= 0:
		return
	var cells := CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS
	_open.resize(cells)
	_open.fill(0)
	_canyon_near.resize(cells)
	_canyon_near.fill(0)
	plan.shapes.mark_near(PlanShapes.CANYON, _canyon_near)
	var buttes := plan.shapes.buttes
	var rng := WorldSeed.rng(recipe.seed, &"plan_buttes")
	var tries := 0
	while buttes.size() < want and tries < want * WorldPlan.BUTTE_TRIES:
		tries += 1
		var first := WorldPlan._anywhere(rng)
		if not _apart(first, radius):
			continue
		var members := 1
		if rng.randf() >= WorldPlan.BUTTE_LONE:
			members = rng.randi_range(WorldPlan.BUTTE_GROUP.x, WorldPlan.BUTTE_GROUP.y)
		for m in members:
			if buttes.size() >= want:
				break
			var at := first
			if m > 0:
				at = WorldPlan._toward(first, rng.randf_range(WorldPlan.BUTTE_SPREAD.x, WorldPlan.BUTTE_SPREAD.y) / radius,
					rng.randf() * TAU)
			var b := _draw(at, rng, radius)
			if not _fits(b, recipe, dirs, cv):
				if m == 0:
					break
				continue
			var shape := PlanShapes.BUTTE * PlanShapes.SHAPES + buttes.size()
			buttes.append(b)
			for c: int in b.cells:
				plan.shapes.add_near(c, shape)

## True if the unit direction `at`, on a world of `radius`, is BUTTE_APART
## metres or more from every butte's middle: where a group may start.
func _apart(at: Vector3, radius: float) -> bool:
	var least := cos(WorldPlan.BUTTE_APART / radius)
	for b: Dictionary in plan.shapes.buttes:
		if at.dot(b.dir) > least:
			return false
	return true

## A butte or small mesa at the unit direction `at` on a world of `radius`, drawn
## from `rng` (the same draws whether it fits or not), as PlanShapes.buttes holds
## it but for its cells (_fits lists them). Its top's corners lie on an ellipse
## of its radius's area, stretched along its heading, each jittered in or out.
func _draw(at: Vector3, rng: RandomNumberGenerator, radius: float) -> Dictionary:
	var tall := rng.randf() < WorldPlan.BUTTE_TALL
	var height := rng.randf_range(WorldPlan.BUTTE_HEIGHT.x, WorldPlan.BUTTE_HEIGHT.y)
	var spread := WorldPlan.BUTTE_RADIUS if tall else WorldPlan.MESA_RADIUS
	var middle := height * rng.randf_range(spread.x, spread.y)
	var sides := rng.randi_range(WorldPlan.BUTTE_SIDES.x, WorldPlan.BUTTE_SIDES.y)
	var stretch := rng.randf_range(1.0, WorldPlan.BUTTE_STRETCH)
	var heading := rng.randf() * TAU
	var along := middle * sqrt(stretch)
	var across := middle / sqrt(stretch)
	var outline := PackedVector2Array()
	outline.resize(sides)
	var widest := 0.0
	for k in sides:
		var bearing := k * TAU / sides
		var c := cos(bearing)
		var s := sin(bearing)
		var r := along * across / sqrt(across * across * c * c + along * along * s * s) \
			* (1.0 + rng.randf_range(-WorldPlan.BUTTE_JITTER, WorldPlan.BUTTE_JITTER))
		outline[k] = Vector2(c, s) * r
		widest = maxf(widest, r)
	var east := WorldPlan._tangent(at, heading)
	var face := WorldPlan.BUTTE_FACE * height
	# Its reach is measured round the sphere and its outline across the tangent
	# plane, a hair shorter: a little spare.
	var reach := (widest + face + maxf(WorldPlan.BUTTE_SAND, maxf(WorldPlan.BUTTE_APRON, WorldPlan.BUTTE_TALUS) * height)) \
		* 1.01 + 1.0
	return {"dir": at, "east": east, "north": at.cross(east), "outline": outline, "radius": middle,
		"height": height, "top": plan.map.at(WorldPlan.S_BASE, at) + height, "face": face, "reach": reach,
		"reach_cos": cos(reach / radius), "mesa": not tall, "cells": PackedInt32Array()}

## True, and its cells listed in `b`'s "cells", if butte `b` fits where it stands:
## its reach clear of every other's and, by BUTTE_CLEAR past every kept disc's
## radius and blend; and every cell within BUTTE_CLEAR past its reach open ground
## (_open_cell). The cells are found by a flood from its middle's: a cell may come
## within so many metres when its middle does less the farthest of its corners.
## Of them, those its reach may touch are its cells.
func _fits(b: Dictionary, recipe: WorldRecipe, dirs: PackedVector3Array, cv: Array[PackedFloat32Array]) -> bool:
	var radius := recipe.radius_m
	var at: Vector3 = b.dir
	var reach: float = b.reach
	for keep: Dictionary in recipe.keeps:
		if at.angle_to(keep.dir) * radius < keep.radius + keep.blend + WorldPlan.BUTTE_CLEAR + reach:
			return false
	for other: Dictionary in plan.shapes.buttes:
		if at.angle_to(other.dir) * radius < other.reach + reach:
			return false
	var up := PlanMap.SIDE
	var start := plan.map.cell_number(at)
	var todo := PackedInt32Array([start])
	var seen := {start: true}
	var near := PackedInt32Array()
	near.resize(4)
	var cells := PackedInt32Array()
	var next := 0
	while next < todo.size():
		var c := todo[next]
		next += 1
		var mid := WorldPlan._cell_centre(c, dirs)
		var k := WorldPlan._first_corner(c)
		var span := 1.01 * maxf(maxf(mid.angle_to(dirs[k]), mid.angle_to(dirs[k + 1])),
			maxf(mid.angle_to(dirs[k + up]), mid.angle_to(dirs[k + up + 1])))
		var gap := (at.angle_to(mid) - span) * radius
		if gap > reach + WorldPlan.BUTTE_CLEAR:
			continue
		if not _open_cell(c, cv):
			return false
		if gap <= reach:
			cells.append(c)
		plan._cell_neighbours(c, near)
		for o in near:
			if not seen.has(o):
				seen[o] = true
				todo.append(o)
	b.cells = cells
	return true

## True if a butte may reach into cell `c`: no canyon is listed near it, and at
## each of its corners (by `cv`, the map's corner values) there is no range's or
## plateau's weight and the water is BUTTE_SHORE metres or more away. So its
## ground is open, dunes or plains past any beach, with nothing on it but a
## butte. Worked out once a cell.
func _open_cell(c: int, cv: Array[PackedFloat32Array]) -> bool:
	if _open[c] == 0:
		var mountain := cv[WorldPlan.S_MOUNTAIN]
		var plateau := cv[WorldPlan.S_PLATEAU]
		var shore := cv[WorldPlan.S_SHORE]
		var k := WorldPlan._first_corner(c)
		var up := PlanMap.SIDE
		var open := _canyon_near[c] == 0
		for corner in [k, k + 1, k + up, k + up + 1]:
			open = open and mountain[corner] == 0.0 and plateau[corner] == 0.0 and shore[corner] >= WorldPlan.BUTTE_SHORE
		_open[c] = 1 if open else 2
	return _open[c] == 1
