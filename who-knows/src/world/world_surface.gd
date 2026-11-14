class_name WorldSurface
extends Node3D

## A world's ground at its true place and size
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5): a quadtree on
## each face of a cube-sphere, split finer where the focus is near and never
## drawn behind the horizon, each leaf one chunk of TerrainChunkData built on
## a worker thread and turned into a mesh here within a budget a tick.
##
## Nothing is a hole while it works, bar the horizon (the spec §13.9): a node
## stays drawn until every leaf beneath it that replaces it is built, and a
## chunk shows only while nothing drawn above it does. The six coarsest are
## built at once, so the world is whole on its first frame.
##
## Round every space anchor near the ground its finest chunks are solid too
## (§5.5): the one right under it built at once if it is missing, the rest
## streamed. If an anchor ever ends up more than FLOOR_SLACK under the ground
## -- a chunk late, or continuous collision missing -- it is lifted out and a
## warning logged. That should never happen; the probe counts it.
##
## The floating origin (CLAUDE.md): this node never moves and is not a member;
## each chunk is a member of Universe.EXTERIOR_SPACE of its own, placed from
## its UniversePoint when made. The boulders and grass round the focus are its
## CoverField's (a child that never moves either; its blocks are members).
##
## Choosing the leaves is pure (the statics below). A node is culled by its
## cull bound (corner chord plus half the relief: safe for the horizon) but
## split by its ground (the real ground under it, less the corner chord), so
## the relief pad never makes a far chunk look near enough to split.

## Split a node when the focus is within SPLIT times its edge of it; merge it
## again only beyond MERGE (§5.2). About 21 leaves a level at 1.5.
const SPLIT := 1.5
const MERGE := 1.8
## Chunk builds in flight at once.
const MAX_JOBS := 12
## Main-thread time a tick may spend turning finished chunks into nodes: the
## asteroids' own budget.
const APPLY_BUDGET_USEC := AsteroidStream.APPLY_BUDGET_USEC
## The leaves are chosen afresh once the focus has moved this far.
const RESELECT_AFTER := 10.0
## Chunks with an edge this short or shorter cast shadows: the sun's shadows
## reach 2 km.
const SHADOW_EDGE := 512.0
## Below the ground by more than this, an anchor is lifted out (§5.5).
const FLOOR_SLACK := 0.5
## Node bounds kept between selections. A long low flight leaves a trail of
## them, nearly one a metre; past this many only the last selection's stay.
const BOUNDS_KEPT := 20000
## In low flight a chunk is made nearly every tick, and sorting out which
## drawn chunks show and go cost most of a millisecond each time (Task 7b): so
## it is done at most once in this many ticks. A chunk made in between waits
## hidden, the chunks it replaces still drawn, so nothing is a hole.
const PRUNE_TICKS := 4

## Tests quieten the floor's warning when they set it off on purpose.
static var warn_on_floor := true

var body: SystemBody
var universe: Universe
## The main thread's own; each job makes another.
var terrain: WorldTerrain
var depth_max := 0
var leaves: Array[Vector4i] = []
## The leaves as a set: key -> true.
var _leaf_set := {}
## The boulders and grass drawn round the focus: a child that never moves.
var cover: CoverField

var _split := {}
var _bounds := {}
## key -> MeshInstance3D
var _chunks := {}
## The drawn chunks _prune hid (a drawn chunk above them): key -> true.
var _hidden := {}
## key -> task id
var _jobs := {}
## key -> TerrainChunkData, written by the jobs under _mutex.
var _done := {}
var _mutex := Mutex.new()
var _selected_at: UniversePoint
var _local := Vector3.ZERO

## How many times an anchor was lifted out from under the ground.
var floor_fired := 0
## key -> StaticBody3D
var _solid := {}
var _wanted_solid := {}
## anchor instance id -> {local, end, keys}: what keys_along last said for it.
var _solid_cache := {}
## Solid bodies let go of, kept with no shape to be used again: making a
## StaticBody3D with its shape took ~0.3 ms (a hull at 120 m/s wants ~60 a
## second), setting a kept one's shape a few microseconds (Task 7b fix
## round 2). At most SPARE_SOLIDS; the rest are freed.
var _spare: Array[StaticBody3D] = []
var _solids_made := 0
const SPARE_SOLIDS := 64
## An anchor whose lowest point is this close over the ground has the chunk
## under it made solid at once (see _touching_soon).
const ARRIVE := 10.0
## A node centre's direction -> the ground's height there: the selection asks
## the same few hundred nodes again every RESELECT_AFTER, and the ground never
## changes. Cleared with the bounds.
var _heights := {}
## Whether the leaves or the drawn chunks have changed since _prune last
## showed and freed them: it is a pure function of the two, so it runs again
## only then, not every tick.
var _prune_due := true
## Ticks since _prune last sorted the drawn chunks.
var _since_prune := PRUNE_TICKS

## The leaves to draw for a focus at `local` (from the world's centre), and
## which nodes are split: [leaves, split]. `was_split` is the last call's
## split, for hysteresis; `bounds` caches each node's bound between calls.
## `height_at` is an optional Callable(direction: Vector3) -> float that returns
## the height above the planet at a given direction; if provided, split decisions
## use the actual ground; if not, they use the sphere point at radius. The relief pad is
## only safe for horizon visibility, not for measuring proximity.
static func select(radius: float, relief: float, depth_max: int, local: Vector3,
		was_split: Dictionary, bounds: Dictionary, height_at := Callable()) -> Array:
	var leaves: Array[Vector4i] = []
	var split := {}
	var reach := horizon_reach(radius, relief, local.length())
	for f in CubeSphere.FACES:
		_walk(Vector4i(f, 0, 0, 0), radius, relief, depth_max, local, reach, was_split, bounds, leaves, split, height_at)
	return [leaves, split]

## How far from a focus `d` from the centre any ground can still be seen: to
## the horizon of the lowest ground, then on to the highest ground beyond it.
## Everywhere, from inside the lowest ground.
static func horizon_reach(radius: float, relief: float, d: float) -> float:
	var low := radius - relief * 0.5
	var high := radius + relief * 0.5
	if d <= low:
		return INF
	return sqrt(d * d - low * low) + sqrt(high * high - low * low)

## A node's [centre, cull_radius, ground, chord]. The cull_radius (corner
## chord + relief/2) is safe for horizon visibility but not for split decisions;
## the chord is the corner chord alone. The centre, cull_radius and chord are
## cached; the ground is worked out fresh each call from `height_at` (the
## sphere point at radius if none) so a cache never holds stale ground. A
## bounds dictionary belongs to one planet's radius and relief.
static func bound_of(key: Vector4i, radius: float, relief: float, bounds: Dictionary, height_at := Callable()) -> Array:
	if not bounds.has(key):
		var b := CubeSphere.node_bound(key, radius, relief)
		bounds[key] = [b[0], b[1], float(b[1]) - relief * 0.5]
	var cached: Array = bounds[key]
	var centre: Vector3 = cached[0]
	var ground := centre
	if height_at.is_valid():
		ground = centre.normalized() * (radius + height_at.call(centre.normalized()))
	return [centre, cached[1], ground, cached[2]]

static func _walk(key: Vector4i, radius: float, relief: float, depth_max: int, local: Vector3, reach: float,
		was_split: Dictionary, bounds: Dictionary, leaves: Array[Vector4i], split: Dictionary, height_at := Callable()) -> void:
	var b := bound_of(key, radius, relief, bounds, height_at)
	var centre: Vector3 = b[0]
	var cull_radius: float = b[1]
	var ground: Vector3 = b[2]
	var chord: float = b[3]
	var to := centre.distance_to(local)
	var cull_near := maxf(to - cull_radius, 0.0)
	if cull_near > reach:
		return
	var ground_near := maxf(ground.distance_to(local) - chord, 0.0)
	var factor := MERGE if was_split.has(key) else SPLIT
	if key.y < depth_max and ground_near < factor * CubeSphere.edge_m(radius, key.y):
		split[key] = true
		for c in CubeSphere.children(key):
			_walk(c, radius, relief, depth_max, local, reach, was_split, bounds, leaves, split, height_at)
	else:
		leaves.append(key)

func setup(p_body: SystemBody, p_universe: Universe) -> void:
	body = p_body
	universe = p_universe
	name = "Surface_%s" % String(body.id).replace(".", "_")
	terrain = WorldTerrain.new(body.recipe)
	depth_max = CubeSphere.depth_for(body.radius)
	# The finest chunks scatter their boulders (GroundCover) on the jobs: what
	# they read is built here first, on the main thread.
	RockMesh.warm()
	cover = CoverField.new()
	cover.setup(body, universe, terrain)
	add_child(cover)

## The six coarsest chunks, built now: whole on the first frame.
func build_roots() -> void:
	for f in CubeSphere.FACES:
		_make_chunk(TerrainChunkData.build(terrain, Vector4i(f, 0, 0, 0)))

## Chooses the leaves for `focus` if it has moved, collects finished jobs,
## asks for what is missing nearest first, applies what fits in the budget,
## and lets go of what nothing needs; then the cover does the same.
func update(focus: UniversePoint) -> void:
	_local = focus.minus(body.point)
	if _selected_at == null or focus.minus(_selected_at).length() >= RESELECT_AFTER:
		_selected_at = focus
		var sel := select(body.radius, terrain.relief, depth_max, _local, _split, _bounds, _node_height)
		leaves.assign(sel[0])
		_leaf_set.clear()
		for k in leaves:
			_leaf_set[k] = true
		_split = sel[1]
		_prune_due = true
		if _bounds.size() > BOUNDS_KEPT:
			_bounds = _bounds_of_selection()
			_heights.clear()
	_wanted_solid = _solid_wanted()
	_collect()
	_request()
	_apply(Time.get_ticks_usec() + APPLY_BUDGET_USEC)
	_prune()
	_keep_anchors_above_ground()
	cover.update(focus)

## The bounds the last selection looked at: the roots, and every child of a
## split node.
func _bounds_of_selection() -> Dictionary:
	var kept := {}
	for f in CubeSphere.FACES:
		var root := Vector4i(f, 0, 0, 0)
		kept[root] = _bounds[root]
	for k: Vector4i in _split:
		for c in CubeSphere.children(k):
			kept[c] = _bounds[c]
	return kept

## Waits for every job and applies everything: tests and probes.
func finish() -> void:
	_wanted_solid = _solid_wanted()
	while not _jobs.is_empty() or _missing().size() > 0:
		for id: int in _jobs.values():
			WorkerThreadPool.wait_for_task_completion(id)
		_jobs.clear()
		_request()
		for id: int in _jobs.values():
			WorkerThreadPool.wait_for_task_completion(id)
		_jobs.clear()
		_apply(INF)
	_prune(true)
	cover.finish()

func chunk_count() -> int:
	return _chunks.size()

func visible_chunks() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for k: Vector4i in _chunks:
		if (_chunks[k] as MeshInstance3D).visible:
			out.append(k)
	return out

func jobs_in_flight() -> int:
	return _jobs.size()

func _exit_tree() -> void:
	# A job holds this node; never let one outlive it.
	for id: int in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(id)
	_jobs.clear()
	if cover != null:
		cover.wait_for_jobs()

## The ground's height at a node centre's direction `d`, remembered (see
## _heights).
func _node_height(d: Vector3) -> float:
	var h: Variant = _heights.get(d)
	if h == null:
		h = terrain.height_at(d)
		_heights[d] = h
	return h

## Wanted leaves not drawn, not building and not built.
func _missing() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	_mutex.lock()
	for k in leaves:
		if not _chunks.has(k) and not _jobs.has(k) and not _done.has(k):
			out.append(k)
	var listed := {}
	for k in out:
		listed[k] = true
	for k: Vector4i in _wanted_solid:
		if not _solid.has(k) and not _jobs.has(k) and not _done.has(k) and not listed.has(k):
			out.append(k)
	_mutex.unlock()
	return out

func _collect() -> void:
	for k: Vector4i in _jobs.keys():
		var id: int = _jobs[k]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_jobs.erase(k)

func _request() -> void:
	if _jobs.size() >= MAX_JOBS:
		return
	var missing := _missing()
	var near := {}
	for k in missing:
		near[k] = _distance(k)
	missing.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return near[a] < near[b])
	for k in missing:
		if _jobs.size() >= MAX_JOBS:
			return
		_jobs[k] = WorkerThreadPool.add_task(_job.bind(k, body.recipe, not _leaf_set.has(k),
			_wanted_solid.has(k) and not _solid.has(k)),
			false, "world chunk")

## On a worker: its own terrain, one chunk; for collision alone if
## `solid_only` (no colours). Its collision shape, if an anchor wants it
## solid (`solid`), is made here too, off the main thread (Task 7b: in low
## flight its tree was half a solid chunk's main-thread time). A shape no
## node holds yet is the worker's own, as a threaded load's are. Not its
## mesh: a mesh made on a worker clashed with the main thread's RIDs.
func _job(key: Vector4i, recipe: WorldRecipe, solid_only: bool, solid: bool) -> void:
	var data := TerrainChunkData.build(WorldTerrain.new(recipe), key, solid_only)
	if solid:
		data.shape = shape_of(data)
	_mutex.lock()
	_done[key] = data
	_mutex.unlock()

## Turns finished chunks into nodes, nearest first, until `deadline`, and at
## least one a call so the ground always catches up. Results the focus has
## left behind go first, all of them: skimming low and fast they pile up, and
## once sorting them took the whole budget nothing was made again (a key
## waiting here is never asked for again either).
func _apply(deadline: float) -> void:
	var wanted := _leaf_set
	var near := {}
	_mutex.lock()
	for k: Vector4i in _done.keys():
		if wanted.has(k) or _wanted_solid.has(k):
			near[k] = 0.0
		else:
			_done.erase(k)
	_mutex.unlock()
	for k: Vector4i in near:
		near[k] = _distance(k)
	var ready: Array = near.keys()
	ready.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return near[a] < near[b])
	var applied := 0
	for k: Vector4i in ready:
		if applied > 0 and Time.get_ticks_usec() > deadline:
			return
		applied += 1
		_mutex.lock()
		var data: TerrainChunkData = _done[k]
		_done.erase(k)
		_mutex.unlock()
		# One built for collision alone that is now to be drawn is asked for
		# again, whole.
		if wanted.has(k) and not _chunks.has(k) and not data.solid_only:
			_make_chunk(data, false)
		if _wanted_solid.has(k) and not _solid.has(k):
			_make_solid(data)

## A drawn chunk; hidden till the next _prune shows it unless `shown` (the
## roots, whole on the first frame).
func _make_chunk(data: TerrainChunkData, shown := true) -> void:
	var m := MeshInstance3D.new()
	m.name = "C%d_%d_%d_%d" % [data.key.x, data.key.y, data.key.z, data.key.w]
	m.mesh = mesh_of(data)
	m.material_override = BodyLook.material(false)
	m.layers = 1
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		if CubeSphere.edge_m(body.radius, data.key.y) <= SHADOW_EDGE \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_to_group(Universe.EXTERIOR_SPACE)
	if not shown:
		m.visible = false
		_hidden[data.key] = true
	add_child(m)
	m.global_position = universe.to_engine(body.point.plus(Vector3(data.centre)))
	_chunks[data.key] = m
	_prune_due = true

## Lets go of every drawn chunk nothing needs, and shows each only while
## nothing drawn above it is shown (only when the leaves or the chunks have
## changed, _prune_due, and at most once in PRUNE_TICKS ticks unless `now`);
## and lets go of every solid chunk nothing needs.
func _prune(now := false) -> void:
	_since_prune += 1
	if _prune_due and (now or _since_prune >= PRUNE_TICKS):
		_prune_due = false
		_since_prune = 0
		_prune_chunks()
	for k: Vector4i in _solid.keys():
		if not _wanted_solid.has(k):
			_let_go_solid(k)

func _prune_chunks() -> void:
	var wanted := {}
	var waiting := {}
	var covering := {}
	for k in leaves:
		wanted[k] = true
		if not _chunks.has(k):
			waiting[k] = true
			var p := k
			while p.y > 0:
				p = CubeSphere.parent(p)
				if covering.has(p):
					# And so are all of its own.
					break
				covering[p] = true
	for k: Vector4i in _chunks.keys():
		if wanted.has(k) or covering.has(k) or (not waiting.is_empty() and _below_any(k, waiting)):
			continue
		(_chunks[k] as Node).queue_free()
		_chunks.erase(k)
		_hidden.erase(k)
	# Whether some ancestor is drawn, each ancestor worked out once (Task 7b:
	# walking every chunk to the root, and setting every chunk's `visible`,
	# cost a millisecond a tick in low flight, where a chunk is made nearly
	# every tick). Only a change is set.
	var above := {}
	for k: Vector4i in _chunks:
		var hide := _drawn_above(k, above)
		if hide != _hidden.has(k):
			(_chunks[k] as MeshInstance3D).visible = not hide
			if hide:
				_hidden[k] = true
			else:
				_hidden.erase(k)

## True if a drawn chunk lies above `key`; `memo` holds the answer for each
## node already asked, so siblings share their ancestors' walk.
func _drawn_above(key: Vector4i, memo: Dictionary) -> bool:
	if key.y == 0:
		return false
	var p := Vector4i(key.x, key.y - 1, key.z >> 1, key.w >> 1)
	var known: Variant = memo.get(p)
	if known != null:
		return known
	var out := _chunks.has(p) or _drawn_above(p, memo)
	memo[p] = out
	return out

func solid_keys() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	out.assign(_solid.keys())
	return out

## Every finest chunk some anchor needs solid: those with ground within
## TerrainCollider.REACH of its way over the next second (a capsule). The one
## under an anchor that is missing is built now, every tick (it is one
## key_for). The rest are worked out again only once either end of its way
## has moved half a finest edge (near a cube edge they cost milliseconds),
## so they are worked out half an edge wider than the reach.
func _solid_wanted() -> Dictionary:
	var out := {}
	var seen := {}
	var half_edge := CubeSphere.edge_m(body.radius, depth_max) * 0.5
	for node in get_tree().get_nodes_in_group(AsteroidStream.SPACE_ANCHOR):
		var a := node as Node3D
		if a == null or not a.is_inside_tree():
			continue
		var id := a.get_instance_id()
		seen[id] = true
		var local := universe.to_universe(a.global_position).minus(body.point)
		var velocity := _velocity_of(a)
		var travel := (velocity * TerrainCollider.LOOKAHEAD).limit_length(TerrainCollider.TRAVEL_MAX)
		var cached: Dictionary = _solid_cache.get(id, {})
		if cached.is_empty() \
				or TerrainCollider._to_segment(local, cached.local, cached.end) > half_edge \
				or TerrainCollider._to_segment(local + travel, cached.local, cached.end) > half_edge:
			# Kept while both ends of the way stay within half an edge of the
			# way they were worked out for (a turn of ~6 deg at 120 m/s moves
			# its end that far), so every point of it does: worked out that
			# much wider (Task 7b fix rounds 1, 2). That way runs further
			# ahead by a tenth of the way the anchor would go uncapped (at most
			# LEAD_MAX), so a fast anchor's keys last a few ticks: at 2 km/s
			# they were worked out every tick (fix round 3), and a lead taken
			# from the capped way never passed 30 m (fix round 4).
			var lead := travel.normalized() * minf(velocity.length() * TerrainCollider.LOOKAHEAD * TerrainCollider.LEAD,
				TerrainCollider.LEAD_MAX) if not travel.is_zero_approx() else Vector3.ZERO
			cached = {"local": local, "end": local + travel + lead,
				"keys": TerrainCollider.keys_along(terrain, depth_max, local, travel + lead,
					TerrainCollider.REACH + half_edge)}
			_solid_cache[id] = cached
		var keys: Array = cached.keys
		if keys.is_empty():
			continue
		for k: Vector4i in keys:
			out[k] = true
		var under := CubeSphere.key_for(local, depth_max)
		out[under] = true
		# And the one under where it will be in two ticks: the one it hits on
		# a fast slanting arrival, ~33 m a tick sideways (fix round 4).
		var soon := _soon(local, velocity)
		var ahead := CubeSphere.key_for(soon, depth_max) if not soon.is_zero_approx() else under
		out[ahead] = true
		# Built on this thread only for an anchor that could touch the ground
		# within two ticks (arriving, landing, falling): a level pass at 2 km/s
		# crosses a cell a tick, each a main-thread build (~2.5 ms; fix round
		# 3). Every other is a worker's, nearest the focus first, so another
		# anchor's would wait behind the focus's.
		if (not _solid.has(under) or not _solid.has(ahead)) and _touching_soon(a, local, velocity):
			if not _solid.has(under):
				_make_solid(TerrainChunkData.build(terrain, under, true))
			if not _solid.has(ahead):
				_make_solid(TerrainChunkData.build(terrain, ahead, true))
	for id: int in _solid_cache.keys():
		if not seen.has(id):
			_solid_cache.erase(id)
	return out

## True if `anchor`, at `local` and moving at `velocity`, has its lowest
## point within ARRIVE of the ground under it, or will within two ticks
## (falling, or skimming toward rising ground). Its lowest point is its
## ANCHOR_RADIUS under its origin: measured from the origin, a hull whose
## stance is over 10 m touched down with the chunk under it left to the
## workers, and the Warden's feet, 6 m under its origin, had 4 m to spare
## (Task 7b fix round 4).
func _touching_soon(anchor: Node, local: Vector3, velocity: Vector3) -> bool:
	var within := ARRIVE + float(anchor.get_meta(AsteroidStream.ANCHOR_RADIUS, 1.0))
	if terrain.altitude_of(local) <= within:
		return true
	var soon := _soon(local, velocity)
	return not soon.is_zero_approx() and terrain.altitude_of(soon) <= within

## Where an anchor at `local`, moving at `velocity`, will be in two ticks.
static func _soon(local: Vector3, velocity: Vector3) -> Vector3:
	return local + velocity * 2.0 / Engine.physics_ticks_per_second

## A chunk's look: its triangles, normals and colours. Pure.
static func mesh_of(data: TerrainChunkData) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.positions
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## A chunk's collision: its faces, solid from both sides. Pure; a worker
## makes it (a shape no body holds yet is the worker's own, as a threaded
## load's are). This relies on GodotPhysics3D (the project's physics
## server, run on the main thread) keeping its shapes in a thread-safe RID
## owner (`RID_PtrOwner<GodotShape3D, true>`): creating a shape and setting
## its data from a worker only touches that owner and the new shape. A
## physics server without that (another engine, or one whose shape owner
## is not thread-safe) needs the shape made on the main thread again, in
## `_make_solid`, which still makes one when `data.shape` is null.
##
## It is also given to a CollisionShape3D outside the tree, once, here: the
## first time any CollisionShape3D takes a shape costs ~0.2 ms in the
## engine's debug build (it sets the shape's debug look; the second time,
## with the look the same, costs ~0.02 ms). Done here, it is off the main
## thread (Task 7b fix round 2, measured in a scratch bench).
static func shape_of(data: TerrainChunkData) -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(data.faces)
	var holder := CollisionShape3D.new()
	holder.shape = shape
	holder.shape = null
	holder.free()
	return shape

## Chunk `data` solid: a kept body if there is one, else a new one; put in
## its place first, then given its shape.
func _make_solid(data: TerrainChunkData) -> void:
	var b: StaticBody3D = _spare.pop_back() if not _spare.is_empty() else _new_solid()
	b.global_position = universe.to_engine(body.point.plus(Vector3(data.centre)))
	(b.get_child(0) as CollisionShape3D).shape = data.shape if data.shape != null else shape_of(data)
	_solid[data.key] = b

## A solid body with no shape yet, in the tree and the exterior's group.
func _new_solid() -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Solid%d" % _solids_made
	_solids_made += 1
	b.collision_layer = BodyProxy.LAYER
	b.collision_mask = 0
	b.add_child(CollisionShape3D.new())
	b.add_to_group(Universe.EXTERIOR_SPACE)
	add_child(b)
	return b

## Chunk `key` no longer solid: its body keeps no shape and is kept for the
## next, or freed if SPARE_SOLIDS are kept already.
func _let_go_solid(key: Vector4i) -> void:
	var b: StaticBody3D = _solid[key]
	_solid.erase(key)
	(b.get_child(0) as CollisionShape3D).shape = null
	if _spare.size() < SPARE_SOLIDS:
		_spare.append(b)
	else:
		b.queue_free()

## The solid bodies kept for use again (none holds a shape).
func spare_solids() -> int:
	return _spare.size()

## The analytic floor (§5.5): an anchor more than FLOOR_SLACK under the
## ground is put back above it, clear by its own reach, moving in no more.
## Under the ground means under the analytic ground and under the ground the
## collision has (TerrainChunkData.solid_altitude_of) both: at a mesa's or a
## tower's lip the triangles sit up to ~9 m under height_at, and judged by
## height_at alone the suit standing there was lifted, fell back and was
## lifted again (final review I1). The triangle is worked out only when the
## analytic ground says under, so open ground costs what it did. Lifted, it
## goes clear of the higher of the two.
## Not a ghosted hull at warp: it passes through everything on purpose.
func _keep_anchors_above_ground() -> void:
	for node in get_tree().get_nodes_in_group(AsteroidStream.SPACE_ANCHOR):
		var a := node as CollisionObject3D
		if a == null or not a.is_inside_tree() or a.collision_mask & BodyProxy.LAYER == 0:
			continue
		var local := universe.to_universe(a.global_position).minus(body.point)
		if local.is_zero_approx() or terrain.altitude_of(local) >= -FLOOR_SLACK:
			continue
		var solid := TerrainChunkData.solid_altitude_of(terrain, local)
		if solid >= -FLOOR_SLACK:
			continue
		var up := local.normalized()
		var clear := float(a.get_meta(AsteroidStream.ANCHOR_RADIUS, 1.0))
		var ground := maxf(terrain.radius + terrain.height_at(up), local.length() - solid)
		a.global_position = universe.to_engine(body.point.plus(up * (ground + clear)))
		if a is RigidBody3D:
			var v := (a as RigidBody3D).linear_velocity
			(a as RigidBody3D).linear_velocity = v - up * minf(v.dot(up), 0.0)
		elif a is CharacterBody3D:
			var v := (a as CharacterBody3D).velocity
			(a as CharacterBody3D).velocity = v - up * minf(v.dot(up), 0.0)
		floor_fired += 1
		if warn_on_floor:
			push_warning("WorldSurface: %s was under %s's ground; lifted out" % [a.name, body.name])

static func _velocity_of(a: Node3D) -> Vector3:
	if a is RigidBody3D:
		return (a as RigidBody3D).linear_velocity
	if a is CharacterBody3D:
		return (a as CharacterBody3D).velocity
	return Vector3.ZERO

## True if an ancestor of `key` is in `set`. The parent is worked out here
## rather than by CubeSphere.parent: _prune walks every chunk to the root, and
## without the call that costs half as much.
static func _below_any(key: Vector4i, set: Dictionary) -> bool:
	var p := key
	while p.y > 0:
		p = Vector4i(p.x, p.y - 1, p.z >> 1, p.w >> 1)
		if set.has(p):
			return true
	return false

func _distance(key: Vector4i) -> float:
	var b := bound_of(key, body.radius, terrain.relief, _bounds)
	return maxf((b[0] as Vector3).distance_to(_local) - float(b[1]), 0.0)
