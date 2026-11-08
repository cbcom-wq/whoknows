class_name CoverField
extends Node3D

## The ground cover drawn round you (the desert world spec §5.6, §7.2; phase 2
## plan, Task 5 and call 9): boulders on every world, out to BOULDER_REACH,
## and on a desert dry grass, out to GRASS_REACH. GroundCover scatters each
## finest chunk's worth; here they are gathered into blocks BLOCK_UP levels
## coarser (16 finest chunks, 64-128 m across: 84 m on 1337's p3), so 300 m
## of boulders is some 65 blocks (about 50 near enough to draw) and two or
## three MultiMeshes each, not 700 finest chunks' worth.
##
## A block is built on a worker -- its 16 scatters, packed straight into
## MultiMesh buffers -- and put in on the main thread nearest first within
## WorldSurface's own budget a tick, at least one a tick, one buffer
## assignment a MultiMesh. Blocks the focus has left behind are let go.
## Nothing at all is wanted higher than BOULDER_REACH over the ground: at
## entry heat or in high flight this costs one distance a tick.
##
## The floating origin (CLAUDE.md): this node never moves and is not a
## member; each block is a member of Universe.EXTERIOR_SPACE of its own,
## placed from its UniversePoint (the body's point plus the block's centre in
## whole metres, as TerrainChunkData's) when made. Every number in a block is
## relative to that centre: each finest chunk's cover is relative to its own
## chunk's centre, and moved by the whole-metre step between the two.
##
## What the boulders draw is solid already: the finest chunks' collision
## holds their hulls (GroundCover.boulder_faces, WorldSurface's solid ground).

## A block is the key this many levels above the finest.
const BLOCK_UP := 2
## How far boulders are drawn, and the margin they fade over past it.
const BOULDER_REACH := 300.0
const BOULDER_FADE := 40.0
## How far grass is drawn, and its fade.
const GRASS_REACH := 70.0
const GRASS_FADE := 15.0
## Block builds in flight at once.
const MAX_JOBS := 4
## Main-thread time a tick may spend putting finished blocks in: the
## surface's own.
const APPLY_BUDGET_USEC := WorldSurface.APPLY_BUDGET_USEC
## The blocks are chosen afresh once the focus has moved this far: a quarter
## of a block, twice the surface's RESELECT_AFTER, as a choice costs about
## 0.3 ms (some 110 blocks weighed) and low flight has little to spare.
const RESELECT_AFTER := 20.0
## A focus moving at v wants the ground v x LOOKAHEAD ahead too, and first
## (as TerrainCollider.reach_for looks ahead); never more than the reach.
const LOOKAHEAD := TerrainCollider.LOOKAHEAD
## A block is let go only once its ground is this far past BOULDER_REACH, so
## one on the edge is not made and freed by turns.
const KEEP_MARGIN := 40.0
## Block bounds remembered between selections; past this many, forgotten.
const MEMO_KEPT := 4096

var body: SystemBody
var universe: Universe
## The surface's main-thread terrain; each job makes its own.
var terrain: WorldTerrain

## The blocks wanted, nearest first (ahead first when moving).
var _wanted: Array[Vector4i] = []
## key -> how far its ground lies: every block not yet to be let go.
var _kept := {}
## key -> Node3D
var _blocks := {}
## key -> task id
var _jobs := {}
## key -> BlockData, written by the jobs under _mutex.
var _done := {}
var _mutex := Mutex.new()
## blocks_near's memo: key -> [middle on the sphere, corner chord], and the
## blocks round each block near a cube edge.
var _memo := {}
var _selected_at: UniversePoint
var _selected_usec := 0
## Every wanted block is drawn and nothing is in flight: a tick then costs
## only the distance moved.
var _settled := true

static var _boulder_look: StandardMaterial3D
static var _grass_look: StandardMaterial3D

## One block's cover, packed on a worker. Per shape [count, buffer]; the
## grass the same.
class BlockData:
	extends RefCounted
	var key: Vector4i
	var centre: Vector3i
	var boulders := {}
	var grass := [0, PackedFloat32Array()]

func setup(p_body: SystemBody, p_universe: Universe, p_terrain: WorldTerrain) -> void:
	body = p_body
	universe = p_universe
	terrain = p_terrain
	name = "Cover"
	# Built here, on the main thread: workers only pack buffers.
	RockMesh.warm()
	GroundCover.grass_mesh()

## The blocks whose ground lies within `reach` of `local` (from the world's
## centre), measured along the ground, nearest first; none from higher than
## `reach` over the ground. A focus moving at `velocity` also wants the
## ground velocity x LOOKAHEAD ahead (at most `reach` ahead), and that first:
## nearest that point, those behind you after.
## `memo` optionally keeps each block's bound, and the blocks over a cube
## edge, between calls. Pure.
static func blocks_near(terrain: WorldTerrain, local: Vector3, reach: float,
		velocity := Vector3.ZERO, memo := {}) -> Array[Vector4i]:
	return _near(terrain, local, reach, velocity, memo, 0.0)[0]

## blocks_near out to `reach` + `keep`: [keys nearest first, key -> how far
## its ground lies from you or the point ahead].
static func _near(terrain: WorldTerrain, local: Vector3, reach: float, velocity: Vector3,
		memo: Dictionary, keep: float) -> Array:
	var out: Array[Vector4i] = []
	var far := {}
	if local.is_zero_approx() or terrain.altitude_of(local) > reach:
		return [out, far]
	var depth := CubeSphere.depth_for(terrain.radius) - BLOCK_UP
	var edge := CubeSphere.edge_m(terrain.radius, depth)
	var up := local.normalized()
	var here := up * terrain.radius
	var lead := ((velocity - up * velocity.dot(up)) * LOOKAHEAD).limit_length(reach)
	var ahead := (here + lead).normalized() * terrain.radius
	var mid := (here + lead * 0.5).normalized() * terrain.radius
	# Moving, a block behind you waits as if it were a lookahead farther: the
	# way ahead first.
	var way := lead.normalized()
	var behind := lead.length()
	var limit := reach + keep
	var found: Array[Vector4i] = []
	# (order, index into found): a native sort, not a lambda's.
	var order: Array[Vector2] = []
	for k in _candidates(mid, depth, edge, limit + behind * 0.5, memo):
		var b: Variant = memo.get(k)
		if b == null:
			b = _bound(k, terrain.radius)
			memo[k] = b
		var m: Vector3 = b[0]
		var to_ahead := ahead.distance_to(m)
		var d := minf(here.distance_to(m), to_ahead) - float(b[1])
		if d <= limit:
			far[k] = d
			order.append(Vector2(to_ahead + (behind if (m - here).dot(way) < 0.0 else 0.0), found.size()))
			found.append(k)
	order.sort()
	for o in order:
		out.append(found[int(o.y)])
	return [out, far]

## Every block at `depth` that might lie within `span` of `mid`: a disc of the
## face's own grid round the one under it (as TerrainCollider.keys_near), and
## where that crosses a cube edge, the other faces' blocks found by sampling
## directions a block apart there, each with its neighbours two deep. The
## crossing is worked out once per block under `mid` and kept in `memo`.
static func _candidates(mid: Vector3, depth: int, edge: float, span: float, memo := {}) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	var under := CubeSphere.key_for(mid, depth)
	# Cells are only nearly even: count them by the one under you's narrower
	# side (a cell by a cube edge is about 0.75 of `edge`).
	var r := mid.length()
	var rect := CubeSphere.node_rect(under)
	var c00 := CubeSphere.direction(under.x, rect.x, rect.y) * r
	var across := minf(c00.distance_to(CubeSphere.direction(under.x, rect.x + rect.z, rect.y) * r),
		c00.distance_to(CubeSphere.direction(under.x, rect.x, rect.y + rect.z) * r))
	var n := ceili(span / minf(across, edge)) + 1
	var cells := 1 << depth
	var inside := under.z - n >= 0 and under.w - n >= 0 and under.z + n < cells and under.w + n < cells
	var window := "%d,%d,%d,%d,%d" % [under.x, under.y, under.z, under.w, n]
	if not inside and memo.has(window):
		return memo[window]
	var seen := {}
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var x := under.z + dx
			var y := under.w + dy
			if dx * dx + dy * dy <= n * n and x >= 0 and y >= 0 and x < cells and y < cells:
				out.append(Vector4i(under.x, depth, x, y))
	if inside:
		return out
	for k in out:
		seen[k] = true
	var up := mid.normalized()
	var a := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := up.cross(a)
	var m := ceili((span + edge) / edge)
	for j in range(-m, m + 1):
		for i in range(-m, m + 1):
			var off := a * (i * edge) + b * (j * edge)
			if off.length() > span + edge or CubeSphere.face_of(mid + off) == under.x:
				continue
			var at := CubeSphere.key_for(mid + off, depth)
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var x := at.z + dx
					var y := at.w + dy
					if x >= 0 and y >= 0 and x < cells and y < cells:
						var k := Vector4i(at.x, depth, x, y)
						if not seen.has(k):
							seen[k] = true
							out.append(k)
	memo[window] = out
	return out

## A block's [middle on the sphere of `radius`, the farthest corner from it].
static func _bound(key: Vector4i, radius: float) -> Array:
	var rect := CubeSphere.node_rect(key)
	var m := CubeSphere.direction(key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5) * radius
	var chord := 0.0
	for k in 4:
		var corner := CubeSphere.direction(key.x, rect.x + rect.z * float(k & 1), rect.y + rect.z * float(k >> 1)) * radius
		chord = maxf(chord, corner.distance_to(m))
	return [m, chord]

## A block's finest keys, in the order their cover is packed.
static func finest_of(block: Vector4i) -> Array[Vector4i]:
	var out: Array[Vector4i] = [block]
	for i in BLOCK_UP:
		var next: Array[Vector4i] = []
		for k in out:
			next.append_array(CubeSphere.children(k))
		out = next
	return out

## Chooses the blocks for `focus` once it has moved, collects finished jobs,
## asks for what is missing nearest first, puts in what fits in the budget
## and lets go of what nothing needs. Settled, it costs one distance.
func update(focus: UniversePoint) -> void:
	if _selected_at == null or focus.minus(_selected_at).length() >= RESELECT_AFTER:
		_select_for(focus)
	if _settled:
		return
	_collect()
	var missing := _missing()
	_request(missing)
	var all_in := _apply(Time.get_ticks_usec() + APPLY_BUDGET_USEC)
	_settled = _jobs.is_empty() and missing.is_empty() and all_in

## Chooses the blocks for `focus`, its velocity worked out from the last
## choice (BodyProxy passes only the point), and lets go of the blocks far
## behind.
func _select_for(focus: UniversePoint) -> void:
	var now := Time.get_ticks_usec()
	var velocity := Vector3.ZERO
	if _selected_at != null and now > _selected_usec:
		velocity = focus.minus(_selected_at) / (float(now - _selected_usec) / 1e6)
	_selected_at = focus
	_selected_usec = now
	if _memo.size() > MEMO_KEPT:
		_memo.clear()
	var near := _near(terrain, focus.minus(body.point), BOULDER_REACH, velocity, _memo, KEEP_MARGIN)
	_kept = near[1]
	_wanted.clear()
	for k: Vector4i in near[0]:
		if float(_kept[k]) <= BOULDER_REACH:
			_wanted.append(k)
	for k: Vector4i in _blocks.keys():
		if not _kept.has(k):
			(_blocks[k] as Node).queue_free()
			_blocks.erase(k)
	_settled = false

## Waits for every job and puts everything in: tests and probes.
func finish() -> void:
	while not _jobs.is_empty() or not _missing().is_empty():
		wait_for_jobs()
		_request(_missing())
		wait_for_jobs()
		_apply(INF)
	_apply(INF)
	_settled = true

## Waits for every job in flight.
func wait_for_jobs() -> void:
	for id: int in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(id)
	_jobs.clear()

func block_count() -> int:
	return _blocks.size()

func block_keys() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	out.assign(_blocks.keys())
	return out

func jobs_in_flight() -> int:
	return _jobs.size()

func _exit_tree() -> void:
	# A job holds this node; never let one outlive it.
	wait_for_jobs()

## Wanted blocks not drawn, not building and not built.
func _missing() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	_mutex.lock()
	for k in _wanted:
		if not _blocks.has(k) and not _jobs.has(k) and not _done.has(k):
			out.append(k)
	_mutex.unlock()
	return out

func _collect() -> void:
	for k: Vector4i in _jobs.keys():
		var id: int = _jobs[k]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_jobs.erase(k)

## Asks for `missing` blocks, in _wanted's order: nearest (ahead) first.
func _request(missing: Array[Vector4i]) -> void:
	for k in missing:
		if _jobs.size() >= MAX_JOBS:
			return
		_jobs[k] = WorkerThreadPool.add_task(_job.bind(k, body.recipe), false, "ground cover")

## On a worker: its own terrain, one block.
func _job(key: Vector4i, recipe: WorldRecipe) -> void:
	var data := _build(key, WorldTerrain.new(recipe))
	_mutex.lock()
	_done[key] = data
	_mutex.unlock()

## Block `key`'s cover on `terrain`: its finest keys' scatters, each moved by
## the whole-metre step from its chunk's centre to the block's, packed per
## shape as MultiMesh buffers. Pure.
static func _build(key: Vector4i, terrain: WorldTerrain) -> BlockData:
	var data := BlockData.new()
	data.key = key
	data.centre = TerrainChunkData.centre_of(terrain, key)
	for k in finest_of(key):
		var cover := GroundCover.scatter(terrain, k)
		if cover.boulders.is_empty() and cover.grass.is_empty():
			continue
		var step := Vector3(TerrainChunkData.centre_of(terrain, k) - data.centre)
		for b: Array in cover.boulders:
			var shape: int = b[1]
			if not data.boulders.has(shape):
				data.boulders[shape] = [0, PackedFloat32Array()]
			var entry: Array = data.boulders[shape]
			var place: Transform3D = b[0]
			place.origin += step
			entry[0] = int(entry[0]) + 1
			entry[1] = AsteroidStream.pack(entry[1], place, b[2])
		for g: Array in cover.grass:
			var place: Transform3D = g[0]
			place.origin += step
			data.grass[0] = int(data.grass[0]) + 1
			data.grass[1] = AsteroidStream.pack(data.grass[1], place, g[1])
	return data

## Puts finished blocks in, nearest first, until `deadline`, and at least one
## a call so the cover always catches up. Results nothing wants any more go
## first, all of them. True if every wanted result went in.
func _apply(deadline: float) -> bool:
	var ready: Array[Vector4i] = []
	_mutex.lock()
	if not _done.is_empty():
		for k: Vector4i in _done.keys():
			if not _kept.has(k) or _blocks.has(k):
				_done.erase(k)
		for k in _wanted:
			if _done.has(k):
				ready.append(k)
	_mutex.unlock()
	var applied := 0
	for k in ready:
		if applied > 0 and Time.get_ticks_usec() > deadline:
			return false
		applied += 1
		_mutex.lock()
		var data: BlockData = _done[k]
		_done.erase(k)
		_mutex.unlock()
		_make_block(data)
	return true

func _make_block(data: BlockData) -> void:
	var block := Node3D.new()
	block.name = "Cover_%d_%d_%d_%d" % [data.key.x, data.key.y, data.key.z, data.key.w]
	for shape: int in data.boulders:
		var entry: Array = data.boulders[shape]
		var m := _stones("Boulders%d" % shape, RockMesh.mesh(shape, 1), entry, boulder_material())
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		m.visibility_range_end = BOULDER_REACH
		m.visibility_range_end_margin = BOULDER_FADE
		block.add_child(m)
	if int(data.grass[0]) > 0:
		var g := _stones("Grass", GroundCover.grass_mesh(), data.grass, grass_material())
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = GRASS_REACH
		g.visibility_range_end_margin = GRASS_FADE
		block.add_child(g)
	block.add_to_group(Universe.EXTERIOR_SPACE)
	add_child(block)
	block.global_position = universe.to_engine(body.point.plus(Vector3(data.centre)))
	_blocks[data.key] = block

## One MultiMesh from a buffer packed on the worker: one assignment.
static func _stones(label: String, mesh: Mesh, entry: Array, look: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = entry[0]
	mm.buffer = entry[1]
	var inst := MultiMeshInstance3D.new()
	inst.name = label
	inst.multimesh = mm
	inst.material_override = look
	inst.layers = 1
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return inst

## The boulders' look, built as the asteroids' boulders' is: vertex and
## instance colours as albedo, roughness 1. The visibility range fades them,
## not the material.
static func boulder_material() -> StandardMaterial3D:
	if _boulder_look == null:
		_boulder_look = StandardMaterial3D.new()
		_boulder_look.vertex_color_use_as_albedo = true
		_boulder_look.albedo_color = SpacePalette.UNTINTED
		_boulder_look.roughness = 1.0
	return _boulder_look

## The grass's: the same, seen from both sides (a blade is one triangle).
static func grass_material() -> StandardMaterial3D:
	if _grass_look == null:
		_grass_look = boulder_material().duplicate() as StandardMaterial3D
		_grass_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _grass_look
