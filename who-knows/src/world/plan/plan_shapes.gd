class_name PlanShapes
extends RefCounted

## What a world plan draws on its map (docs/superpowers/specs/2026-11-19-wadis-land-design.md
## §5.1): its seas, ranges, plateaus, canyons and buttes. Plain data, written
## while the plan is built and only read after, from any thread.
##
## A cell is the map's: the quadtree's node at PlanMap.PLAN_DEPTH, numbered
## (face * CELLS + j) * CELLS + i, the order PlanMap.set_bounds takes them in.
##
## Each cell also lists the shapes whose reach touches it (near), so a height
## close up asks only those: shape i of a kind is listed as kind * SHAPES + i.

const RANGE := 0
const CANYON := 1
const PLATEAU := 2
const BUTTE := 3
## Shapes of one kind, at most.
const SHAPES := 4096

## Each sea, one connected body of cells: {"cells": PackedInt32Array, "centre":
## Vector3, the unit direction it was grown from}.
var seas: Array[Dictionary] = []
## Each mountain range: {"spine": PackedVector3Array, unit directions about
## WorldPlan.SPINE_STEP apart, end to end; "height": PackedFloat32Array, by
## spine point, metres it stands over the open ground; "half_width": float,
## metres from the spine to its flanks' foot}.
var ranges: Array[Dictionary] = []
## Each plateau region, one connected body of cells: {"cells":
## PackedInt32Array, "top": float, metres above radius its top stands at}.
var plateaus: Array[Dictionary] = []
## Each canyon: {"path": PackedVector3Array, unit directions about
## WorldPlan.CANYON_STEP apart from its head to its mouth; by path point,
## "floor": PackedFloat32Array, metres above radius of its floor, never
## climbing toward the mouth, "half_floor": PackedFloat32Array, metres from the
## centreline to the floor's edge, and "rim": PackedFloat32Array, metres its
## walls' top stands over the floor, where they end, WorldPlan.CANYON_WALL_RUN
## times that past the floor's edge; "mouth": StringName, &"beach" where it
## meets the sea or &"basin" where it ends in a dry basin}. A branch is its own
## canyon, with "mouth" &"" and "joins": its parent's index, its path ending on
## the parent's and its floor at the parent's there.
var canyons: Array[Dictionary] = []
## Each butte or small mesa on open ground (PlanButtes, §6): {"dir": Vector3, the
## unit direction of its middle; "east", "north": Vector3, unit tangents there,
## its outline's frame, east turned to its heading; "outline":
## PackedVector2Array, its flat top's corners in metres in that frame, evenly
## round by bearing, counterclockwise from east, so its first corner lies due
## east; "radius": float, the metres its top's corners stand from its middle
## before they are jittered and stretched along its heading; "height": float,
## metres it stands over its base; "top": float, metres above radius of its flat
## top (the base where it stands, its middle's S_BASE, plus its height); "face":
## float, the metres its sheer face runs out past the top's edge (butte_rise);
## "reach": float, metres from its middle to the farthest ground it changes,
## its apron, its talus and the dunes it banks; "reach_cos": float, the cosine
## of that as an angle; "mesa": bool, a small mesa (else a tall butte); "cells":
## PackedInt32Array, the cells it is listed near: every cell its reach may
## touch}. No two buttes' reaches overlap. The record the plan is built and
## tested by; butte_at reads the same values from the typed arrays below.
var buttes: Array[Dictionary] = []
## The world's radius, metres: what ridge_m and canyon_at measure in.
var radius_m := 0.0
## By cell, which kinds of shape are listed near it, a bit (1 << kind) each:
## so a height asks a cell's canyons only where it has one, by one look. Set by
## pack_near.
var kinds := PackedByteArray()

## The near lists, by cell: its entries are _near_from[cell] to
## _near_from[cell + 1] - 1, and entry e names shape _near[e] and the first
## and last segment (_near_first[e], _near_last[e]) of its spine that can be
## nearest to a point of the cell.
var _near_from := PackedInt32Array()
var _near := PackedInt32Array()
var _near_first := PackedInt32Array()
var _near_last := PackedInt32Array()
## Entries added while the plan is built, in order, until pack_near.
var _add_cell := PackedInt32Array()
var _add_shape := PackedInt32Array()
var _add_first := PackedInt32Array()
var _add_last := PackedInt32Array()
## The buttes' values butte_at reads, by butte, copied from `buttes` by
## pack_near: a Dictionary's key costs a hash a read, and butte_at runs per
## height. Float64 as a Dictionary's floats are, so a height is the same to the
## bit. Butte i's top's corners are _butte_corners[_butte_from[i]] to
## _butte_corners[_butte_from[i + 1] - 1].
var _butte_dir := PackedVector3Array()
var _butte_east := PackedVector3Array()
var _butte_north := PackedVector3Array()
var _butte_reach_cos := PackedFloat64Array()
var _butte_face := PackedFloat64Array()
var _butte_top := PackedFloat64Array()
var _butte_height := PackedFloat64Array()
var _butte_corners := PackedVector2Array()
var _butte_from := PackedInt32Array()

## The number of the cell `key` (a node at PLAN_DEPTH).
static func cell_index(key: Vector4i) -> int:
	return (key.x * PlanMap.CELLS + key.w) * PlanMap.CELLS + key.z

## The node key of cell number `index`.
static func cell_key(index: int) -> Vector4i:
	var n := PlanMap.CELLS
	return Vector4i(index / (n * n), PlanMap.PLAN_DEPTH, index % n, (index / n) % n)

## While building: lists shape `shape` (kind * SHAPES + i) as near cell number
## `cell`, segments `first` to `last` of its spine or path (for a shape that
## has them) holding whatever of it is nearest the cell's points.
func add_near(cell: int, shape: int, first := 0, last := -1) -> void:
	_add_cell.append(cell)
	_add_shape.append(shape)
	_add_first.append(first)
	_add_last.append(last)

## While building: marks 1 in `out` (a byte per cell) every cell a range has
## been listed near so far.
func mark_near_ranges(out: PackedByteArray) -> void:
	mark_near(RANGE, out)

## While building: marks 1 in `out` (a byte per cell) every cell a shape of
## `kind` has been listed near so far.
func mark_near(kind: int, out: PackedByteArray) -> void:
	for e in _add_cell.size():
		if _add_shape[e] / SHAPES == kind:
			out[_add_cell[e]] = 1

## Once every shape is added: files the entries cell by cell, each cell's in the
## order they were added, and marks each cell's kinds; and copies the buttes'
## values butte_at reads into their typed arrays.
func pack_near() -> void:
	var cells := CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS
	_near_from.resize(cells + 1)
	_near_from.fill(0)
	kinds.resize(cells)
	kinds.fill(0)
	for e in _add_cell.size():
		var c := _add_cell[e]
		_near_from[c + 1] += 1
		kinds[c] = kinds[c] | (1 << (_add_shape[e] / SHAPES))
	for c in cells:
		_near_from[c + 1] += _near_from[c]
	var count := _add_cell.size()
	_near.resize(count)
	_near_first.resize(count)
	_near_last.resize(count)
	var put := _near_from.slice(0, cells)
	for e in count:
		var c := _add_cell[e]
		var at := put[c]
		put[c] = at + 1
		_near[at] = _add_shape[e]
		_near_first[at] = _add_first[e]
		_near_last[at] = _add_last[e]
	_add_cell = PackedInt32Array()
	_add_shape = PackedInt32Array()
	_add_first = PackedInt32Array()
	_add_last = PackedInt32Array()
	var n := buttes.size()
	_butte_dir.resize(n)
	_butte_east.resize(n)
	_butte_north.resize(n)
	_butte_reach_cos.resize(n)
	_butte_face.resize(n)
	_butte_top.resize(n)
	_butte_height.resize(n)
	_butte_corners.clear()
	_butte_from.resize(n + 1)
	for i in n:
		var b := buttes[i]
		_butte_dir[i] = b.dir
		_butte_east[i] = b.east
		_butte_north[i] = b.north
		_butte_reach_cos[i] = b.reach_cos
		_butte_face[i] = b.face
		_butte_top[i] = b.top
		_butte_height[i] = b.height
		_butte_from[i] = _butte_corners.size()
		_butte_corners.append_array(b.outline)
	_butte_from[n] = _butte_corners.size()

## The shapes whose reach touches `cell`, each kind * SHAPES + i. A new array:
## a height asked per vertex uses near_count and near_at, which allocate
## nothing.
func near(cell: Vector4i) -> PackedInt32Array:
	var c := cell_index(cell)
	return _near.slice(_near_from[c], _near_from[c + 1])

func near_count(cell: Vector4i) -> int:
	var c := cell_index(cell)
	return _near_from[c + 1] - _near_from[c]

## The `k`th of near(cell), 0 to near_count(cell) - 1.
func near_at(cell: Vector4i, k: int) -> int:
	return _near[_near_from[cell_index(cell)] + k]

## Vector2(great-circle metres from `d`, a unit direction in `cell`, to the
## nearest point of the spine of any range near the cell, the spine's height
## there), or Vector2(INF, 0) with none near. From any thread; allocates
## nothing.
func ridge_m(d: Vector3, cell: Vector4i) -> Vector2:
	var c := cell_index(cell)
	var best := INF
	var height := 0.0
	for e in range(_near_from[c], _near_from[c + 1]):
		var shape := _near[e]
		if shape >= SHAPES:
			continue
		var r: Dictionary = ranges[shape]
		var spine: PackedVector3Array = r.spine
		var tall: PackedFloat32Array = r.height
		for s in range(_near_first[e], _near_last[e] + 1):
			var a := spine[s]
			var ab := spine[s + 1] - a
			var t := clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var angle := d.angle_to(a + ab * t)
			if angle < best:
				best = angle
				height = lerpf(tall[s], tall[s + 1], t)
	if best == INF:
		return Vector2(INF, 0.0)
	return Vector2(best * radius_m, height)

## The lowest floor, metres above radius, of the canyon segments listed near cell
## number `cell` (cell_index's): the least the walls can cut to in the cell. INF
## with no canyon near. From any thread; allocates nothing.
func canyon_floor_low(cell: int) -> float:
	var low := INF
	for e in range(_near_from[cell], _near_from[cell + 1]):
		var i := _near[e] - CANYON * SHAPES
		if i < 0 or i >= SHAPES:
			continue
		var bed: PackedFloat32Array = canyons[i].floor
		for s in range(_near_first[e], _near_last[e] + 2):
			low = minf(low, bed[s])
	return low

## Lowers `low` (a height by cell) to the lowest floor of any canyon listed near
## the cell, where there is one.
func lower_by_canyons(low: PackedFloat32Array) -> void:
	for c in low.size():
		if _near_from[c + 1] > _near_from[c]:
			low[c] = minf(low[c], canyon_floor_low(c))

## A canyon's walls' rise over its floor `past` metres out from the floor's edge
## (none on the floor): steps WorldPlan.CANYON_WALL_STEP metres up, each its
## riser and then its ledge (CANYON_WALL_LEDGE of the step's run), so never under
## the straight wall, past / CANYON_WALL_RUN. From any thread.
static func wall_rise(past: float) -> float:
	if past <= 0.0:
		return 0.0
	var t := past / (WorldPlan.CANYON_WALL_STEP * WorldPlan.CANYON_WALL_RUN)
	var k := floorf(t)
	return WorldPlan.CANYON_WALL_STEP * (k + minf((t - k) / (1.0 - WorldPlan.CANYON_WALL_LEDGE), 1.0))

## The canyon at `d`, a unit direction in cell number `cell` (cell_index's):
## Vector3(metres from its centreline over its floor's half-width, at most 1
## on the floor; its floor's height; its rim, metres over the floor), what
## WorldPlan.S_CANYON, S_CANYON_FLOOR and S_CANYON_RIM hold, or Vector3(INF, 0,
## 0) where no canyon's walls reach. Of each canyon near the cell, the nearest
## point of its path whose walls reach `d` (the floor's half-width and
## WorldPlan.CANYON_WALL_RUN times the rim there); where two canyons reach it,
## the one whose cut stands lowest at `d`: its floor plus its stepped walls'
## rise past the floor's edge (wall_rise), the ground the terrain lays there, so
## where canyons meet, the deeper's floor and walls cut through the other's.
## From any thread; allocates nothing.
func canyon_at(d: Vector3, cell: int) -> Vector3:
	var c := canyon_parts_at(d, cell)
	if c.x == INF:
		return Vector3(INF, 0.0, 0.0)
	return Vector3(c.x / c.y, c.z, c.w)

## The canyon canyon_at picks at `d` (a unit direction in cell number `cell`),
## in parts: Vector4(metres from its centreline, its floor's half-width there,
## its floor's height, its rim over the floor), or Vector4(INF, 0, 0, 0) where
## no canyon's walls reach. What a height close up cuts by (WorldTerrain): the
## metres past the floor's edge are x - y. From any thread; allocates nothing.
func canyon_parts_at(d: Vector3, cell: int) -> Vector4:
	var out := Vector4(INF, 0.0, 0.0, 0.0)
	var lowest := INF
	var run := WorldPlan.CANYON_WALL_RUN
	for e in range(_near_from[cell], _near_from[cell + 1]):
		var i := _near[e] - CANYON * SHAPES
		if i < 0 or i >= SHAPES:
			continue
		var c: Dictionary = canyons[i]
		var path: PackedVector3Array = c.path
		var half: PackedFloat32Array = c.half_floor
		var rim: PackedFloat32Array = c.rim
		# The nearest point within reach: nearest by its chord's square (in the
		# same order as the great circle for points this near), within reach
		# by the great circle.
		var best := INF
		var at := -1
		var at_t := 0.0
		var metres := 0.0
		for s in range(_near_first[e], _near_last[e] + 1):
			var a := path[s]
			var ab := path[s + 1] - a
			var t := clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var q := a + ab * t
			var gap := d.distance_squared_to(q)
			if gap < best:
				var m := d.angle_to(q) * radius_m
				if m <= lerpf(half[s], half[s + 1], t) + lerpf(rim[s], rim[s + 1], t) * run:
					best = gap
					at = s
					at_t = t
					metres = m
		if at < 0:
			continue
		var bed: PackedFloat32Array = c.floor
		var w := lerpf(half[at], half[at + 1], at_t)
		var f := lerpf(bed[at], bed[at + 1], at_t)
		var cut := f + wall_rise(metres - w)
		if cut < lowest:
			lowest = cut
			out = Vector4(metres, w, f, lerpf(rim[at], rim[at + 1], at_t))
	return out

## The butte at `d`, a unit direction in cell number `cell` (cell_index's):
## Vector4(metres past its top's edge, out along the bearing from its middle
## through `d`, 0 or less on its top; its face's run; its top, metres above
## radius; its height over its base), or Vector4(INF, 0, 0, 0) where no butte
## reaches. The top's edge between two corners is the straight line joining them,
## so the outline is faceted. Buttes' reaches never overlap, so one at most. What
## a height close up stands a butte by (WorldTerrain, with butte_rise). From any
## thread once pack_near has run (it reads the typed arrays); allocates nothing.
func butte_at(d: Vector3, cell: int) -> Vector4:
	for e in range(_near_from[cell], _near_from[cell + 1]):
		var i := _near[e] - BUTTE * SHAPES
		if i < 0 or i >= SHAPES:
			continue
		if d.dot(_butte_dir[i]) < _butte_reach_cos[i]:
			continue
		var p := Vector2(d.dot(_butte_east[i]), d.dot(_butte_north[i])) * radius_m
		var first := _butte_from[i]
		var n := _butte_from[i + 1] - first
		var k := mini(int(fposmod(atan2(p.y, p.x), TAU) * n / TAU), n - 1)
		var a := _butte_corners[first + k]
		var c := _butte_corners[first + (k + 1) % n]
		# How far out `d` lies along its ray from the middle, as a share of where
		# the ray crosses the edge from corner k to k + 1.
		var t := p.cross(c - a) / a.cross(c)
		var out := p.length()
		var past := out - out / t if t > 0.0 else -a.length()
		return Vector4(past, _butte_face[i], _butte_top[i], _butte_height[i])
	return Vector4(INF, 0.0, 0.0, 0.0)

## A butte's ground over its base, `past` metres past its top's edge (butte_at's
## x), for a butte `height` metres tall whose face runs `face` metres: its height
## on its top; down its sheer face to WorldPlan.BUTTE_SKIRT of its height at the
## face's foot; then down its apron, easing to nothing BUTTE_APRON of its height
## on. From any thread.
static func butte_rise(past: float, face: float, height: float) -> float:
	if past <= 0.0:
		return height
	if past < face:
		return height * (1.0 - (1.0 - WorldPlan.BUTTE_SKIRT) * past / face)
	var apron := WorldPlan.BUTTE_APRON * height
	var left := 1.0 - (past - face) / apron
	if left <= 0.0:
		return 0.0
	return WorldPlan.BUTTE_SKIRT * height * left * left

## True if no butte's reach comes within `metres` of the unit direction `d`.
## While building and after (PlanSites), not per height: it asks every butte.
func clear_of_buttes(d: Vector3, metres: float) -> bool:
	for b: Dictionary in buttes:
		if d.angle_to(b.dir) * radius_m < b.reach + metres:
			return false
	return true
