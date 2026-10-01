class_name WorldSurface
extends Node3D

## A world's ground at its true place and size
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5): a quadtree on
## each face of a cube-sphere, split finer where the focus is near and never
## drawn behind the horizon, each leaf one chunk of TerrainChunkData built on
## a worker thread and turned into a mesh here within a budget a tick.
##
## Nothing is ever a hole: a node stays drawn until every leaf beneath it that
## replaces it is built, and a chunk shows only while nothing drawn above it
## does. The six coarsest are built at once, so the world is whole on its
## first frame.
##
## The floating origin (CLAUDE.md): this node never moves and is not a member;
## each chunk is a member of Universe.EXTERIOR_SPACE of its own, placed from
## its UniversePoint when made.
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

var body: SystemBody
var universe: Universe
## The main thread's own; each job makes another.
var terrain: WorldTerrain
var depth_max := 0
var leaves: Array[Vector4i] = []

var _split := {}
var _bounds := {}
## key -> MeshInstance3D
var _chunks := {}
## key -> task id
var _jobs := {}
## key -> TerrainChunkData, written by the jobs under _mutex.
var _done := {}
var _mutex := Mutex.new()
var _selected_at: UniversePoint
var _local := Vector3.ZERO

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

## The six coarsest chunks, built now: whole on the first frame.
func build_roots() -> void:
	for f in CubeSphere.FACES:
		_make_chunk(TerrainChunkData.build(terrain, Vector4i(f, 0, 0, 0)))

## Chooses the leaves for `focus` if it has moved, collects finished jobs,
## asks for what is missing nearest first, applies what fits in the budget,
## and lets go of what nothing needs.
func update(focus: UniversePoint) -> void:
	_local = focus.minus(body.point)
	if _selected_at == null or focus.minus(_selected_at).length() >= RESELECT_AFTER:
		_selected_at = focus
		var sel := select(body.radius, terrain.relief, depth_max, _local, _split, _bounds, terrain.height_at)
		leaves.assign(sel[0])
		_split = sel[1]
	_collect()
	_request()
	_apply(Time.get_ticks_usec() + APPLY_BUDGET_USEC)
	_prune()

## Waits for every job and applies everything: tests and probes.
func finish() -> void:
	while not _jobs.is_empty() or _missing().size() > 0:
		for id: int in _jobs.values():
			WorkerThreadPool.wait_for_task_completion(id)
		_jobs.clear()
		_request()
		for id: int in _jobs.values():
			WorkerThreadPool.wait_for_task_completion(id)
		_jobs.clear()
		_apply(INF)
	_prune()

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

## Wanted leaves not drawn, not building and not built.
func _missing() -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	_mutex.lock()
	for k in leaves:
		if not _chunks.has(k) and not _jobs.has(k) and not _done.has(k):
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
	var missing := _missing()
	missing.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return _distance(a) < _distance(b))
	for k in missing:
		if _jobs.size() >= MAX_JOBS:
			return
		_jobs[k] = WorkerThreadPool.add_task(_job.bind(k, body.recipe), false, "world chunk")

## On a worker: its own terrain, one chunk.
func _job(key: Vector4i, recipe: WorldRecipe) -> void:
	var data := TerrainChunkData.build(WorldTerrain.new(recipe), key)
	_mutex.lock()
	_done[key] = data
	_mutex.unlock()

func _apply(deadline: float) -> void:
	_mutex.lock()
	var ready: Array = _done.keys()
	_mutex.unlock()
	ready.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return _distance(a) < _distance(b))
	var wanted := {}
	for k in leaves:
		wanted[k] = true
	for k: Vector4i in ready:
		if Time.get_ticks_usec() > deadline:
			return
		_mutex.lock()
		var data: TerrainChunkData = _done[k]
		_done.erase(k)
		_mutex.unlock()
		if wanted.has(k) and not _chunks.has(k):
			_make_chunk(data)

func _make_chunk(data: TerrainChunkData) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.positions
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := MeshInstance3D.new()
	m.name = "C%d_%d_%d_%d" % [data.key.x, data.key.y, data.key.z, data.key.w]
	m.mesh = mesh
	m.material_override = BodyLook.material(false)
	m.layers = 1
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		if CubeSphere.edge_m(body.radius, data.key.y) <= SHADOW_EDGE \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_to_group(Universe.EXTERIOR_SPACE)
	add_child(m)
	m.global_position = universe.to_engine(body.point.plus(Vector3(data.centre)))
	_chunks[data.key] = m

## Lets go of every drawn chunk nothing needs, and shows each only while
## nothing drawn above it is shown.
func _prune() -> void:
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
				covering[p] = true
	for k: Vector4i in _chunks.keys():
		if wanted.has(k) or covering.has(k) or _below_any(k, waiting):
			continue
		(_chunks[k] as Node).queue_free()
		_chunks.erase(k)
	for k: Vector4i in _chunks:
		(_chunks[k] as MeshInstance3D).visible = not _below_any(k, _chunks)

## True if an ancestor of `key` is in `set`.
static func _below_any(key: Vector4i, set: Dictionary) -> bool:
	var p := key
	while p.y > 0:
		p = CubeSphere.parent(p)
		if set.has(p):
			return true
	return false

func _distance(key: Vector4i) -> float:
	var b := bound_of(key, body.radius, terrain.relief, _bounds)
	return maxf((b[0] as Vector3).distance_to(_local) - float(b[1]), 0.0)
