class_name CoverField
extends Node3D

## The ground cover drawn round you (the desert world spec §5.6, §7.2; phase 2
## plan, Task 5 and call 9): boulders on every world, out to BOULDER_REACH,
## and on a desert dry grass, out to GRASS_REACH. GroundCover scatters each
## finest chunk's worth; here they are gathered into blocks BLOCK_UP levels
## coarser (16 finest chunks, 64-128 m across: 84 m on 1337's p3), so 200 m
## of boulders is some 45 blocks and two MultiMeshes each (drawn twice: with
## shadows near, without past BOULDER_SHADOW_REACH), not 300 finest chunks'
## worth. BOULDER_REACH was 300 m until Task 7's frame rate seated among grass
## and in low flight over a talus band (2.2 million triangles there, half of
## them stones, each drawn again into the sun's shadow splits).
##
## A block is built on a worker -- its 16 scatters, packed straight into
## MultiMesh buffers -- and put in on the main thread nearest first within
## WorldSurface's own budget a tick, at least one a tick, one buffer
## assignment a MultiMesh. Blocks the focus has left behind are let go.
## Nothing at all is wanted higher than BOULDER_REACH over the ground, and
## higher up less of it (the reach along the ground is what the height leaves
## of BOULDER_REACH): at entry heat or in high flight this costs one distance
## a tick.
##
## Visibility ranges are judged from a node's middle, so they fade a whole
## node at once. A block's boulders reach to BOULDER_REACH plus half its
## diagonal: every block whose ground lies within BOULDER_REACH is drawn, and
## none is built that never could be. Grass is drawn a finest chunk at a time
## (one MultiMesh each, about 21 m across), so it fades out by distance and
## not a block at a time; those nodes are made only for blocks within
## GRASS_ZONE.
##
## The floating origin (CLAUDE.md): this node never moves and is not a
## member; each block is a member of Universe.EXTERIOR_SPACE of its own,
## placed from its UniversePoint (the body's point plus the block's centre in
## whole metres, as TerrainChunkData's) when made. Every number in a block is
## relative to that centre: each finest chunk's boulders are relative to its
## own chunk's centre, and moved by the whole-metre step between the two; its
## grass node sits at that step, its tufts as scattered.
##
## What the boulders draw is solid already: the finest chunks' collision
## holds their hulls (GroundCover.boulder_faces, WorldSurface's solid ground).

## A block is the key this many levels above the finest.
const BLOCK_UP := 2
## How far boulders are drawn, and the margin they fade over past it.
const BOULDER_REACH := 200.0
const BOULDER_FADE := 40.0
## Boulders cast shadows only in blocks whose ground lies within this: the
## sun's shadows reach 2 km (AsteroidStream.SHADOW_REACH), so every stone drawn
## was drawn again into each shadow split. Past it a block's stones are a
## second instance of the same MultiMesh, "Far<shape>", with no shadow; the
## two meet at the block's middle BOULDER_SHADOW_REACH plus half its diagonal
## off, overlapping by SHADOW_OVERLAP so no frame draws neither (Task 7's
## third cut).
const BOULDER_SHADOW_REACH := 100.0
const SHADOW_OVERLAP := 1.0
## How far grass is drawn, and its fade.
const GRASS_REACH := 70.0
const GRASS_FADE := 15.0
## Block builds in flight at once.
const MAX_JOBS := 4
## Main-thread time a tick may spend putting finished blocks in: the
## surface's own.
const APPLY_BUDGET_USEC := WorldSurface.APPLY_BUDGET_USEC
## The blocks are chosen afresh once the focus has moved this far: a quarter
## of a block, twice the surface's RESELECT_AFTER, as a choice costs a few
## tenths of a millisecond and low flight has little to spare.
const RESELECT_AFTER := 20.0
## A focus moving at v wants the ground v x LOOKAHEAD ahead too, and first
## (as TerrainCollider.reach_for looks ahead); never more than the reach.
const LOOKAHEAD := TerrainCollider.LOOKAHEAD
## A step between choices faster than this, or one under a physics tick, is a
## jump (boarding, a load, a warp's arrival), not flight: no velocity. Phase
## 1's fastest dive was 2.1 km/s.
const FLIGHT_MAX := 3000.0
## A block is let go only once its ground is this far past BOULDER_REACH (in
## the slant, as the reach), so one on the edge is not made and freed by
## turns.
const KEEP_MARGIN := 40.0
## A block's grass nodes are made while its ground lies within this of you
## (along the ground, less what the height takes): the grass's reach and
## fade, and the most the focus moves before the next choice. They go again
## past GRASS_ZONE + RESELECT_AFTER.
const GRASS_ZONE := GRASS_REACH + GRASS_FADE + RESELECT_AFTER
## A cell more skewed than this (the sine of its corner's angle; 0.866 at a
## cube's corner) is counted as a square of narrower cells, not a disc.
const SKEW := 0.97
## Block bounds remembered between choices; past this many, only the last
## choice's are kept.
const MEMO_KEPT := 4096

var body: SystemBody
var universe: Universe
## The surface's main-thread terrain; each job makes its own.
var terrain: WorldTerrain

## The blocks wanted, nearest first (ahead first when moving).
var _wanted: Array[Vector4i] = []
## key -> how far its ground lies along the ground: every block not yet to
## be let go.
var _kept := {}
## key -> Node3D
var _blocks := {}
## key -> task id
var _jobs := {}
## key -> BlockData, written by the jobs under _mutex.
var _done := {}
var _mutex := Mutex.new()
## key -> the block's grass, per finest chunk [step, count, buffer], while
## the block is drawn.
var _grass := {}
## key -> its "Grass" node, for the blocks within GRASS_ZONE.
var _grass_on := {}
## How far along the ground grass nodes are wanted, and kept: from the last
## choice.
var _grass_want := -INF
var _grass_keep := -INF
## blocks_near's memo: key -> [middle on the sphere, corner chord].
var _memo := {}
var _selected_at: UniversePoint
var _selected_usec := 0
## Every wanted block is drawn with its grass, and nothing is in flight: a
## tick then costs only the distance moved.
var _settled := true

static var _boulder_look: StandardMaterial3D
static var _grass_look: StandardMaterial3D

## One block's cover, packed on a worker. Boulders per shape [count,
## buffer], relative to the block's centre; grass per finest chunk that has
## any [step from the block's centre, count, buffer], relative to that
## chunk's centre. `reach` is how far its boulders are drawn.
class BlockData:
	extends RefCounted
	var key: Vector4i
	var centre: Vector3i
	var reach := BOULDER_REACH
	var boulders := {}
	var grass: Array = []

func setup(p_body: SystemBody, p_universe: Universe, p_terrain: WorldTerrain) -> void:
	body = p_body
	universe = p_universe
	terrain = p_terrain
	name = "Cover"
	# Built here, on the main thread: workers only pack buffers.
	RockMesh.warm()
	GroundCover.grass_mesh()

## The blocks whose ground lies within `reach` of `local` (from the world's
## centre), nearest first: within sqrt(reach^2 - h^2) along the ground, h
## being the height over the ground, so none from higher than `reach`. A
## focus moving at `velocity` also wants the ground velocity x LOOKAHEAD
## ahead (at most `reach` ahead), and that first: nearest that point, those
## behind you after. `memo` optionally keeps each block's bound between
## calls. Pure.
static func blocks_near(terrain: WorldTerrain, local: Vector3, reach: float,
		velocity := Vector3.ZERO, memo := {}) -> Array[Vector4i]:
	return _near(terrain, local, reach, velocity, memo, 0.0)[0]

## blocks_near out to `reach` + `keep` (in the slant): [keys nearest first,
## key -> how far its ground lies along the ground, how far along the ground
## `reach` itself goes (-INF: nowhere), the height over the ground].
static func _near(terrain: WorldTerrain, local: Vector3, reach: float, velocity: Vector3,
		memo: Dictionary, keep: float) -> Array:
	var out: Array[Vector4i] = []
	var far := {}
	if local.is_zero_approx():
		return [out, far, -INF, INF]
	var h := maxf(terrain.altitude_of(local), 0.0)
	var limit := reach + keep
	if h > limit:
		return [out, far, -INF, h]
	var want := sqrt(reach * reach - h * h) if h <= reach else -INF
	var lateral := sqrt(limit * limit - h * h)
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
	var found: Array[Vector4i] = []
	# (order, index into found): a native sort, not a lambda's.
	var order: Array[Vector2] = []
	var candidates := _candidates(mid, depth, edge, lateral + behind * 0.5)
	for k in candidates:
		var b: Variant = memo.get(k)
		if b == null:
			b = _bound(k, terrain.radius)
			memo[k] = b
		var m: Vector3 = b[0]
		var to_ahead := ahead.distance_to(m)
		var d := minf(here.distance_to(m), to_ahead) - float(b[1])
		if d <= lateral:
			far[k] = d
			order.append(Vector2(to_ahead + (behind if (m - here).dot(way) < 0.0 else 0.0), found.size()))
			found.append(k)
	order.sort()
	for o in order:
		var k := found[int(o.y)]
		if keep > 0.0 or float(far[k]) <= want:
			out.append(k)
	if memo.size() > MEMO_KEPT:
		var kept := {}
		for k in candidates:
			kept[k] = memo[k]
		memo.clear()
		memo.merge(kept)
	return [out, far, want, h]

## Every block at `depth` that might lie within `span` of `mid` (on the
## sphere): a disc of the face's own grid round the one under it (as
## TerrainCollider.keys_near; a square of narrower cells where they are skewed
## toward a cube's corner), and for each cube edge within `span`, a strip of
## the next face's grid along it, as long as the disc's chord there and as
## deep as the disc reaches past the edge. One key_for per edge crossed; no
## memo, so nothing to miss when the speed (and so the span) changes.
static func _candidates(mid: Vector3, depth: int, edge: float, span: float) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	var fuv := CubeSphere.face_uv(mid)
	var face := int(fuv.x)
	var cells := 1 << depth
	var under := Vector4i(face, depth, clampi(floori((fuv.y + 1.0) * 0.5 * cells), 0, cells - 1),
		clampi(floori((fuv.z + 1.0) * 0.5 * cells), 0, cells - 1))
	# Cells are only nearly even: count them by the one under you's narrower
	# side (a cell by a cube edge is about 0.75 of `edge`).
	var r := mid.length()
	var rect := CubeSphere.node_rect(under)
	var c00 := CubeSphere.direction(face, rect.x, rect.y) * r
	var side_u := CubeSphere.direction(face, rect.x + rect.z, rect.y) * r - c00
	var side_v := CubeSphere.direction(face, rect.x, rect.y + rect.z) * r - c00
	var cell := minf(edge, minf(side_u.length(), side_v.length()))
	var n := ceili(span / cell) + 1
	if under.z - n >= 0 and under.w - n >= 0 and under.z + n < cells and under.w + n < cells:
		for dy in range(-n, n + 1):
			for dx in range(-n, n + 1):
				if dx * dx + dy * dy <= n * n:
					out.append(Vector4i(face, depth, under.z + dx, under.w + dy))
		return out
	# Toward a cube's corner cells are skewed (60 degrees at the corner), so a
	# distance spans more of them: there, a square, and a step of the cell's
	# width across its skew.
	var skew := side_u.cross(side_v).length() / (side_u.length() * side_v.length())
	var square := skew < SKEW
	if square:
		cell *= minf(skew, 1.0) * 0.95
		n = ceili(span / cell) + 1
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var x := under.z + dx
			var y := under.w + dy
			if (square or dx * dx + dy * dy <= n * n) and x >= 0 and y >= 0 and x < cells and y < cells:
				out.append(Vector4i(face, depth, x, y))
	var seen := {}
	for k in out:
		seen[k] = true
	# Each edge of this face: x 0 for a u edge, 1 for a v edge; y its end.
	for e: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 1)]:
		var on_u := e.x == 0
		var at_edge := Vector2(float(e.y), fuv.z) if on_u else Vector2(fuv.y, float(e.y))
		var d0 := mid.distance_to(CubeSphere.direction(face, at_edge.x, at_edge.y) * r)
		if d0 > span:
			continue
		# A cell's width past the edge lies on the next face.
		var out_dir := Vector2(float(e.y), 0.0) if on_u else Vector2(0.0, float(e.y))
		var past := at_edge + out_dir * rect.z
		var across := CubeSphere.key_for(CubeSphere.direction(face, past.x, past.y), depth)
		if across.x == face:
			continue
		var along_n := ceili(sqrt(maxf(span * span - d0 * d0, 0.0)) / cell) + 2
		var deep_n := ceili((span - d0) / cell) + 2
		# Which side of the next face meets this one: an end of its z or w.
		for side: Vector2i in [Vector2i(0, 0), Vector2i(0, cells - 1), Vector2i(1, 0), Vector2i(1, cells - 1)]:
			var index := across.z if side.x == 0 else across.w
			if absi(index - side.y) > 1:
				continue
			var inward := 1 if side.y == 0 else -1
			var mid_along := across.w if side.x == 0 else across.z
			for a in range(-along_n, along_n + 1):
				var along := mid_along + a
				if along < 0 or along >= cells:
					continue
				for dd in deep_n:
					var into := side.y + inward * dd
					if into < 0 or into >= cells:
						break
					var k := Vector4i(across.x, depth, into, along) if side.x == 0 \
						else Vector4i(across.x, depth, along, into)
					if not seen.has(k):
						seen[k] = true
						out.append(k)
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
## (blocks, then grass) and lets go of what nothing needs. Settled, it costs
## one distance.
func update(focus: UniversePoint) -> void:
	if _selected_at == null or focus.minus(_selected_at).length() >= RESELECT_AFTER:
		_select_for(focus)
	if _settled:
		return
	_collect()
	var missing := _missing()
	_request(missing)
	var deadline := Time.get_ticks_usec() + APPLY_BUDGET_USEC
	var blocks_in := _apply(deadline)
	# With blocks still to put in, the grass gets only its one.
	var grass_in := _grass_step(deadline if blocks_in else -INF)
	_settled = _jobs.is_empty() and missing.is_empty() and blocks_in and grass_in

## Chooses the blocks for `focus`, its velocity worked out from the last
## choice (BodyProxy passes only the point; a jump has none), and lets go of
## the blocks far behind.
func _select_for(focus: UniversePoint) -> void:
	var now := Time.get_ticks_usec()
	var velocity := Vector3.ZERO
	if _selected_at != null:
		var dt := float(now - _selected_usec) / 1e6
		var step := focus.minus(_selected_at)
		if dt >= 1.0 / Engine.physics_ticks_per_second and step.length() <= FLIGHT_MAX * dt:
			velocity = step / dt
	_selected_at = focus
	_selected_usec = now
	var near := _near(terrain, focus.minus(body.point), BOULDER_REACH, velocity, _memo, KEEP_MARGIN)
	_kept = near[1]
	var want: float = near[2]
	var h: float = near[3]
	_wanted.clear()
	for k: Vector4i in near[0]:
		if float(_kept[k]) <= want:
			_wanted.append(k)
	_grass_want = sqrt(GRASS_ZONE * GRASS_ZONE - h * h) if h <= GRASS_ZONE else -INF
	var keep := GRASS_ZONE + RESELECT_AFTER
	_grass_keep = sqrt(keep * keep - h * h) if h <= keep else -INF
	for k: Vector4i in _blocks.keys():
		if not _kept.has(k):
			(_blocks[k] as Node).queue_free()
			_blocks.erase(k)
			_grass.erase(k)
			_grass_on.erase(k)
	_settled = false

## Waits for every job and puts everything in: tests and probes.
func finish() -> void:
	while not _jobs.is_empty() or not _missing().is_empty():
		wait_for_jobs()
		_request(_missing())
		wait_for_jobs()
		_apply(INF)
	_apply(INF)
	_grass_step(INF)
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

## Block `key`'s cover on `terrain`: its finest keys' scatters, packed as
## MultiMesh buffers, each sized once. Boulders per shape, each moved by the
## whole-metre step from its chunk's centre to the block's; grass per finest
## chunk, as scattered. Pure.
static func _build(key: Vector4i, terrain: WorldTerrain) -> BlockData:
	var data := BlockData.new()
	data.key = key
	data.centre = TerrainChunkData.centre_of(terrain, key)
	data.reach = BOULDER_REACH + float(_bound(key, terrain.radius)[1])
	var covers: Array[GroundCover] = []
	var steps: Array[Vector3] = []
	var counts := {}
	for k in finest_of(key):
		var cover := GroundCover.scatter(terrain, k)
		if cover.boulders.is_empty() and cover.grass.is_empty():
			continue
		var step := Vector3(TerrainChunkData.centre_of(terrain, k) - data.centre)
		covers.append(cover)
		steps.append(step)
		for b: Array in cover.boulders:
			counts[b[1]] = int(counts.get(b[1], 0)) + 1
		if not cover.grass.is_empty():
			var buf := PackedFloat32Array()
			buf.resize(cover.grass.size() * 16)
			for i in cover.grass.size():
				_put(buf, i, cover.grass[i][0], cover.grass[i][1])
			data.grass.append([step, cover.grass.size(), buf])
	for shape: int in counts:
		var buf := PackedFloat32Array()
		buf.resize(int(counts[shape]) * 16)
		var slot := 0
		for i in covers.size():
			for b: Array in covers[i].boulders:
				if int(b[1]) != shape:
					continue
				var place: Transform3D = b[0]
				place.origin += steps[i]
				_put(buf, slot, place, b[2])
				slot += 1
		data.boulders[shape] = [slot, buf]
	return data

## One instance into a sized MultiMesh buffer at `slot`, laid out as
## AsteroidStream.pack lays it: the transform's rows, then the colour.
static func _put(buf: PackedFloat32Array, slot: int, t: Transform3D, c: Color) -> void:
	var i := slot * 16
	buf[i] = t.basis.x.x
	buf[i + 1] = t.basis.y.x
	buf[i + 2] = t.basis.z.x
	buf[i + 3] = t.origin.x
	buf[i + 4] = t.basis.x.y
	buf[i + 5] = t.basis.y.y
	buf[i + 6] = t.basis.z.y
	buf[i + 7] = t.origin.y
	buf[i + 8] = t.basis.x.z
	buf[i + 9] = t.basis.y.z
	buf[i + 10] = t.basis.z.z
	buf[i + 11] = t.origin.z
	buf[i + 12] = c.r
	buf[i + 13] = c.g
	buf[i + 14] = c.b
	buf[i + 15] = c.a

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

## Lets go of the grass of blocks past _grass_keep, and makes it for drawn
## blocks within _grass_want, nearest first, until `deadline` (at least one
## block's a call). True if none is left to make.
func _grass_step(deadline: float) -> bool:
	for k: Vector4i in _grass_on.keys():
		if float(_kept.get(k, INF)) > _grass_keep:
			(_grass_on[k] as Node).queue_free()
			_grass_on.erase(k)
	var made := 0
	for k in _wanted:
		if float(_kept[k]) > _grass_want or _grass_on.has(k) or not _grass.has(k):
			continue
		if made > 0 and Time.get_ticks_usec() > deadline:
			return false
		made += 1
		_make_grass(k)
	return true

func _make_block(data: BlockData) -> void:
	var block := Node3D.new()
	block.name = "Cover_%d_%d_%d_%d" % [data.key.x, data.key.y, data.key.z, data.key.w]
	var near := data.reach - BOULDER_REACH + BOULDER_SHADOW_REACH
	for shape: int in data.boulders:
		var entry: Array = data.boulders[shape]
		var m := _stones("Boulders%d" % shape, RockMesh.mesh(shape, 1), entry[0], entry[1], boulder_material())
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		m.visibility_range_end = near
		m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		block.add_child(m)
		var far := MultiMeshInstance3D.new()
		far.name = "Far%d" % shape
		far.multimesh = m.multimesh
		far.material_override = m.material_override
		far.layers = m.layers
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		far.visibility_range_begin = near - SHADOW_OVERLAP
		far.visibility_range_end = data.reach
		far.visibility_range_end_margin = BOULDER_FADE
		far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		block.add_child(far)
	block.add_to_group(Universe.EXTERIOR_SPACE)
	add_child(block)
	block.global_position = universe.to_engine(body.point.plus(Vector3(data.centre)))
	_blocks[data.key] = block
	if not data.grass.is_empty():
		_grass[data.key] = data.grass

## Block `key`'s grass: a node "Grass" holding one MultiMesh per finest chunk
## with tufts, each at its chunk's centre, so each is judged by its own
## distance.
func _make_grass(key: Vector4i) -> void:
	var holder := Node3D.new()
	holder.name = "Grass"
	for entry: Array in _grass[key]:
		var g := _stones("Tufts", GroundCover.grass_mesh(), entry[1], entry[2], grass_material())
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = GRASS_REACH
		g.visibility_range_end_margin = GRASS_FADE
		g.position = entry[0]
		holder.add_child(g, true)
	(_blocks[key] as Node3D).add_child(holder)
	_grass_on[key] = holder

## One MultiMesh from a buffer packed on the worker: one assignment.
static func _stones(label: String, mesh: Mesh, count: int, buffer: PackedFloat32Array,
		look: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.buffer = buffer
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
