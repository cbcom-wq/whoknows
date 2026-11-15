class_name PlaceField
extends Node3D

## The named places of a system's design (PlaceDesign), made real near you: the
## oasis on its world. Each place near the focus is one node, `Place_<id>`,
## standing on the ground in the place's own frame, and its pieces are that
## node's children. Far away the node is freed; the design stays data.
##
## The floating origin (CLAUDE.md): the field sits under Outside at the
## identity and is never moved. A place's node is a member of
## Universe.EXTERIOR_SPACE (moved itself, its parent never moves); its pieces
## are children and never members. Where a place stands is a UniversePoint,
## so it survives a shift.
##
## Later pieces (items, buildings) are added in `_build`, which makes
## a place's pieces from its layout.

## A place within this far of the focus is loaded; beyond FREE_BEYOND it is
## freed (so a place at the edge does not load and free each tick), m.
const LOAD_WITHIN := 8000.0
const FREE_BEYOND := 10000.0

## How far out from a pool's centre the shore is looked for, m, and the step it
## is looked for in.
const SHORE_SEARCH := 60.0
const SHORE_STEP := 0.25
## The water disc reaches this far past the shore, m: under the ground there,
## so the disc's facets never leave a gap at the bank.
const SHORE_LAP := 0.6
## Metres between the stones of a path, and between the joints of the pump's pipe.
const STONE_STEP := 0.9
const PIPE_STEP := 1.5
## Grass keeps this far out of a garden bed's circle, the pump's and a path stone's, m.
const GRASS_MARGIN := 0.5
const PUMP_CLEAR := 1.2
const PATH_CLEAR := 1.0
## The broken wall's foot follows the ground, sampled about this often, m.
const WALL_STEP := 2.0
## A shell's footprint is sampled this often for the lowest ground under it,
## where an unstamped shell's walls start (its plinth), m.
const FOOT_STEP := 1.0

var universe: Universe
var system: SystemRecipe
var whereabouts: Whereabouts
var catalog: ItemCatalog

var _places: Array[PlaceDesign] = []
## Place id -> the UniversePoint of the place on its floor (made on first use).
var _points := {}
var _loaded := {}   # StringName id -> Node3D
## Place id -> {item id: true}: what the hands have taken from each place, and
## which is never put back (saved as the part "places").
var _taken := {}
## Item -> [place id, item id]: the items lying in a loaded place now, ours.
var _lying := {}
## Item -> the Callable its `consumed` calls.
var _hooks := {}

func setup(p_universe: Universe, p_system: SystemRecipe, p_whereabouts: Whereabouts,
		p_catalog: ItemCatalog) -> void:
	universe = p_universe
	system = p_system
	whereabouts = p_whereabouts
	catalog = p_catalog
	_places = system.places()

func _physics_process(_delta: float) -> void:
	update()

## Loads each place within LOAD_WITHIN of the focus and frees one beyond
## FREE_BEYOND.
func update() -> void:
	if universe == null or not is_instance_valid(universe.focus) or not universe.focus.is_inside_tree():
		return
	var focus := universe.to_universe(universe.focus.global_position)
	for place in _places:
		var body := system.body(place.body_id)
		if body == null or body.recipe == null:
			continue
		var far := focus.minus(_point_of(place, body)).length()
		if _loaded.has(place.id):
			if far > FREE_BEYOND:
				_free(place.id)
		elif far <= LOAD_WITHIN:
			_load(place, body)

## `id`'s node, or null when it is not loaded.
func loaded(id: StringName) -> Node3D:
	var node: Node3D = _loaded.get(id)
	return node if is_instance_valid(node) else null

func _point_of(place: PlaceDesign, body: SystemBody) -> UniversePoint:
	if not _points.has(place.id):
		_points[place.id] = ground_point(place, body, whereabouts.terrain_of(body))
	return _points[place.id]

func _load(place: PlaceDesign, body: SystemBody) -> void:
	var node := Node3D.new()
	node.name = "Place_%s" % place.id
	add_child(node)
	node.global_transform = Transform3D(place.frame(), universe.to_engine(_point_of(place, body)))
	node.add_to_group(Universe.EXTERIOR_SPACE)
	_loaded[place.id] = node
	_build(place, body, node)

func _free(id: StringName) -> void:
	var node: Node3D = _loaded[id]
	_loaded.erase(id)
	# What lies in the place goes with it; what was taken is the hand's.
	for item: Variant in _lying.keys():
		if _lying[item][0] == id:
			_forget(item)
	if is_instance_valid(node):
		node.remove_from_group(Universe.EXTERIOR_SPACE)
		node.queue_free()

## Makes the pieces of `place` (its layout, data/places/<id>.json) as children
## of `node`, in the place's frame. Add each new kind of piece here.
func _build(place: PlaceDesign, body: SystemBody, node: Node3D) -> void:
	var terrain := whereabouts.terrain_of(body)
	var layout := place.layout()
	var water_radius := 0.0
	if layout.has("pool"):
		water_radius = _build_pool(place, terrain, layout["pool"], node)
	_build_village(place, terrain, layout, node, water_radius)
	_build_tracks(place, terrain, layout, node)
	_build_outcrop(place, terrain, layout, node)
	_build_items(place, terrain, layout, node)

## The pool: its water, a flat faceted disc at its level, and the area that
## slows you in it. Returns the water's edge: how far from the pool's centre
## the ground comes up to the water level, m.
func _build_pool(place: PlaceDesign, terrain: WorldTerrain, pool: Dictionary, node: Node3D) -> float:
	var at: Array = pool.get("at", [0, 0])
	var east := float(at[0])
	var north := float(at[1])
	var level := floor_at(place, terrain, east, north).y + float(pool.get("level", -0.3))
	var ground := func(x_z: Vector2) -> float:
		return on_ground(place, terrain, x_z.x, -x_z.y).y
	var centre := Vector2(east, -north)
	var shore := 0.0
	while shore < SHORE_SEARCH and float(ground.call(centre + Vector2(shore, 0.0))) < level:
		shore += SHORE_STEP
	var holder := Node3D.new()
	holder.name = "Pool"
	node.add_child(holder)
	var kit := OasisLooks.kit_under(holder)
	OasisLooks.water(kit, Transform3D(Basis.IDENTITY, Vector3(centre.x, level, centre.y)), shore + SHORE_LAP)
	kit.commit()
	node.add_child(PoolWater.make(centre, shore + SHORE_LAP, level, ground))
	return shore

## The green and the village outside: palms (trunks solid), the grass ring,
## gardens, the pump and its pipe, the path, the brick shells (home 5 and the
## crushed hut), the broken wall, its rubble and the shade sails. Every solid
## is one kit's, every tuft one MultiMesh's, the palms' trunks one body's and
## the brick's another's, and each piece stands on the ground of its layout
## point (on_ground), never on a height of its own. Each piece's kind, id and
## lowest vertex are kept as the holder's meta `pieces` (a headless test reads
## them: a committed mesh reads back nothing without a renderer).
func _build_village(place: PlaceDesign, terrain: WorldTerrain, layout: Dictionary, node: Node3D,
		water_radius: float) -> void:
	var ground := ground_fn(place, terrain)
	var holder := Node3D.new()
	holder.name = "Village"
	node.add_child(holder)
	var kit := OasisLooks.kit_under(holder)
	kit.keep_arrays = true
	var avoid: Array[Vector3] = []
	var marks := []
	var mark := func(kind: String, id: String, from: int) -> void:
		marks.append([kind, id, from, kit.vertex_count(InteriorKit.Batch.SOLID)])
	var palms: Array = layout.get("palms", [])
	if not palms.is_empty():
		var trunks := StaticBody3D.new()
		trunks.name = "Palms"
		trunks.collision_layer = BodyProxy.LAYER
		trunks.collision_mask = 0
		node.add_child(trunks)
		for i in palms.size():
			var from := kit.vertex_count(InteriorKit.Batch.SOLID)
			var f := Transform3D(Basis.IDENTITY, ground.call(float(palms[i][0]), float(palms[i][1])))
			var variety := float((i * 37 + 13) % 100) / 100.0
			OasisLooks.palm(kit, f, variety)
			trunks.add_child(OasisLooks.palm_collider(f, variety))
			mark.call("palm", "palm_%d" % i, from)
	var gardens: Array = layout.get("gardens", [])
	for i in gardens.size():
		var g: Dictionary = gardens[i]
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var at: Array = g["at"]
		var size: Array = g.get("size", [4.0, 3.0])
		var f := Transform3D(Basis.IDENTITY, ground.call(float(at[0]), float(at[1])))
		OasisLooks.garden(kit, f, Vector2(float(size[0]), float(size[1])), bool(g.get("dried", false)),
			float(at[0] * 0.173 + at[1] * 0.291))
		avoid.append(Vector3(f.origin.x, f.origin.z, Vector2(float(size[0]), float(size[1])).length() * 0.5 + GRASS_MARGIN))
		mark.call("garden", "garden_%d" % i, from)
	if layout.has("pump"):
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var pump: Dictionary = layout["pump"]
		var at: Array = pump["at"]
		var foot: Vector3 = ground.call(float(at[0]), float(at[1]))
		OasisLooks.pump(kit, Transform3D(Basis.IDENTITY, foot))
		avoid.append(Vector3(foot.x, foot.z, PUMP_CLEAR))
		var end: Array = pump.get("pipe_to", at)
		var pipe_from := foot + Vector3(0.0, 0.2, 0.0)
		var steps := maxi(int(Vector2(float(end[0]) - float(at[0]), float(end[1]) - float(at[1])).length() / PIPE_STEP), 1)
		for k in range(1, steps + 1):
			var t := float(k) / steps
			var to: Vector3 = ground.call(lerpf(float(at[0]), float(end[0]), t), lerpf(float(at[1]), float(end[1]), t))
			to.y += 0.1
			OasisLooks.pipe(kit, pipe_from, to)
			pipe_from = to
		mark.call("pump", "pump", from)
	if layout.has("path"):
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var path: Dictionary = layout["path"]
		var stones := PackedVector3Array()
		var points: Array = path["points"]
		for k in range(points.size() - 1):
			var a := Vector2(float(points[k][0]), float(points[k][1]))
			var b := Vector2(float(points[k + 1][0]), float(points[k + 1][1]))
			var n := maxi(int(a.distance_to(b) / STONE_STEP), 1)
			for j in n:
				var p := a.lerp(b, float(j) / n)
				stones.append(ground.call(p.x, p.y))
		var last: Array = points[points.size() - 1]
		stones.append(ground.call(float(last[0]), float(last[1])))
		for stone in stones:
			avoid.append(Vector3(stone.x, stone.z, PATH_CLEAR))
		OasisLooks.path(kit, stones, float(path.get("width", 1.4)))
		mark.call("path", "path", from)
	_build_brick(place, terrain, layout, node, kit, mark, avoid)
	kit.commit()
	var positions := PackedVector3Array()
	if kit.arrays.has(InteriorKit.Batch.SOLID):
		positions = kit.arrays[InteriorKit.Batch.SOLID][Mesh.ARRAY_VERTEX]
	var pieces := []
	for m: Array in marks:
		var lowest := INF
		for v in range(m[2], mini(m[3], positions.size())):
			lowest = minf(lowest, positions[v].y)
		pieces.append({"kind": m[0], "id": m[1], "lowest": lowest})
	holder.set_meta(&"pieces", pieces)
	if layout.has("grass_ring") and layout.has("pool"):
		var ring: Dictionary = layout["grass_ring"]
		var axes: Array = ring.get("axes", [36, 26])
		var at: Array = layout["pool"].get("at", [0, 0])
		var centre: Vector3 = ground.call(float(at[0]), float(at[1]))
		var floor_of := func(x: float, z: float) -> float:
			return (ground.call(x, -z) as Vector3).y
		node.add_child(OasisLooks.grass_ring(Transform3D(Basis.IDENTITY, centre),
			Vector2(float(axes[0]), float(axes[1])), water_radius, float(ring.get("inner", 1.5)),
			hash(String(place.id)), floor_of, avoid))

## The brick: the shells, the broken wall's runs, its rubble and the shade
## sails, into the village's `kit`, their solid parts on one StaticBody3D
## "Brick" (BodyProxy.LAYER). An unstamped shell's walls start at the lowest
## ground under its footprint (its plinth: home 5, which straddles the pool
## bank's blend); a stamped one finds that ground level (the crushed hut).
## The wall's foot follows the ground point to point.
func _build_brick(place: PlaceDesign, terrain: WorldTerrain, layout: Dictionary, node: Node3D,
		kit: InteriorKit, mark: Callable, avoid: Array[Vector3]) -> void:
	var shells: Array = layout.get("shells", [])
	var wall: Dictionary = layout.get("wall", {})
	if shells.is_empty() and wall.is_empty() and not layout.has("rubble") and not layout.has("sails"):
		return
	var brick := StaticBody3D.new()
	brick.name = "Brick"
	brick.collision_layer = BodyProxy.LAYER
	brick.collision_mask = 0
	node.add_child(brick)
	var add := func(shapes: Array[CollisionShape3D]) -> void:
		for c in shapes:
			brick.add_child(c)
	for s: Dictionary in shells:
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var at: Array = s["at"]
		var east := float(at[0])
		var north := float(at[1])
		var yaw := float(s.get("yaw", 0.0))
		var variety := float(s.get("variety", 0.5))
		var centre := on_ground(place, terrain, east, north)
		var turn := Basis(Vector3.UP, -deg_to_rad(yaw))
		if str(s["kind"]) == "round":
			var radius := float(s["radius"])
			var height := float(s.get("height", 3.0))
			var foot := lowest_ground(place, terrain, east, north, Vector2(radius, radius), yaw, true)
			var f := Transform3D(turn, Vector3(centre.x, foot - BrickShell.SUNK, centre.z))
			BrickShell.round_hut(kit, f, radius, height, variety)
			add.call(BrickShell.round_hut_shapes(f, radius, height, variety))
			avoid.append(Vector3(centre.x, centre.z, radius + GRASS_MARGIN))
		else:
			var sz: Array = s["size"]
			var size := Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
			var foot := lowest_ground(place, terrain, east, north, Vector2(size.x, size.z) * 0.5, yaw, false)
			var f := Transform3D(turn, Vector3(centre.x, foot - BrickShell.SUNK, centre.z))
			if str(s["kind"]) == "crushed":
				BrickShell.crushed(kit, f, size, variety)
				add.call(BrickShell.crushed_shapes(f, size, variety))
			else:
				var openings: Array = s.get("openings", [])
				BrickShell.box(kit, f, size, openings, variety)
				add.call(BrickShell.box_shapes(f, size, openings, variety))
			avoid.append(Vector3(centre.x, centre.z, Vector2(size.x, size.z).length() * 0.5 + GRASS_MARGIN))
		mark.call("shell", str(s["id"]), from)
	var runs: Array = wall.get("runs", [])
	for k in runs.size():
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var run: Array = runs[k]
		var points := PackedVector3Array()
		for j in run.size() - 1:
			var a := Vector2(float(run[j][0]), float(run[j][1]))
			var b := Vector2(float(run[j + 1][0]), float(run[j + 1][1]))
			var n := maxi(1, roundi(a.distance_to(b) / WALL_STEP))
			for i in n:
				var p := a.lerp(b, float(i) / n)
				points.append(on_ground(place, terrain, p.x, p.y))
		var last: Array = run[run.size() - 1]
		points.append(on_ground(place, terrain, float(last[0]), float(last[1])))
		var height := float(wall.get("height", 2.6))
		var variety := 0.31 + 0.27 * k
		BrickShell.wall(kit, points, height, variety)
		add.call(BrickShell.wall_shapes(points, height, variety))
		mark.call("wall", "wall_%d" % k, from)
	var rubble: Array = layout.get("rubble", [])
	for k in rubble.size():
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var r: Dictionary = rubble[k]
		var at: Array = r["at"]
		var spread: Array = r.get("spread", [4, 4])
		var f := Transform3D(Basis.IDENTITY, on_ground(place, terrain, float(at[0]), float(at[1])))
		BrickShell.rubble(kit, f, Vector2(float(spread[0]), float(spread[1])), int(r.get("count", 30)), 0.43 + 0.1 * k,
			_floor_in(place, terrain, f))
		mark.call("rubble", "rubble_%d" % k, from)
	var sails: Array = layout.get("sails", [])
	for k in sails.size():
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var s: Dictionary = sails[k]
		var at: Array = s["at"]
		var sz: Array = s.get("size", [4.5, 3.5])
		var size := Vector2(float(sz[0]), float(sz[1]))
		var f := Transform3D(Basis(Vector3.UP, -deg_to_rad(float(s.get("yaw", 0.0)))),
			on_ground(place, terrain, float(at[0]), float(at[1])))
		BrickShell.sail(kit, f, size, 0.2 + 0.5 * k)
		avoid.append(Vector3(f.origin.x, f.origin.z, size.length() * 0.5 + GRASS_MARGIN))
		mark.call("sail", "sail_%d" % k, from)

## The beast's tracks: one mesh a set, "Tracks_<id>", on the ground's own
## triangles, in the place's frame.
func _build_tracks(place: PlaceDesign, terrain: WorldTerrain, layout: Dictionary, node: Node3D) -> void:
	var on := ground_fn(place, terrain)
	var floor_of := func(x: float, z: float) -> float:
		return (on.call(x, -z) as Vector3).y
	var sets: Array = layout.get("tracks", [])
	for k in sets.size():
		var t: Dictionary = sets[k]
		var from: Array = t["from"]
		var mesh := OasisLooks.tracks(Transform3D.IDENTITY, Vector2(float(from[0]), float(from[1])),
			float(t["bearing"]), float(t["length"]), floor_of, 0.29 + 0.31 * k, terrain.palette,
			float(t.get("fade_over", 0.0)))
		mesh.name = "Tracks_%s" % str(t.get("id", k))
		node.add_child(mesh)

## The rock outcrop, its stones on the ground under each of them.
func _build_outcrop(place: PlaceDesign, terrain: WorldTerrain, layout: Dictionary, node: Node3D) -> void:
	if not layout.has("outcrop"):
		return
	var o: Dictionary = layout["outcrop"]
	var at: Array = o["at"]
	var sz: Array = o.get("size", [50, 9, 18])
	var f := Transform3D(Basis(Vector3.UP, -deg_to_rad(float(o.get("yaw", 0.0)))),
		on_ground(place, terrain, float(at[0]), float(at[1])))
	node.add_child(OasisLooks.outcrop(f, Vector3(float(sz[0]), float(sz[1]), float(sz[2])),
		float(o.get("variety", 0.5)), _floor_in(place, terrain, f), terrain.palette))

## The things lying about (the layout's `items`: id, kind, at, yaw), each not
## yet taken: upright, the bottom centre of its box on the ground, frozen
## static, a child of the place's node (never a member of a shift group).
func _build_items(place: PlaceDesign, terrain: WorldTerrain, layout: Dictionary, node: Node3D) -> void:
	if catalog == null:
		return
	var ground := ground_fn(place, terrain)
	for entry: Dictionary in layout.get("items", []):
		var item_id := str(entry["id"])
		if is_taken(place.id, item_id):
			continue
		var def := catalog.get_def(StringName(entry["kind"]))
		if def == null:
			push_warning("PlaceField: no item called %s for %s" % [entry["kind"], item_id])
			continue
		var at: Array = entry["at"]
		var item := Item.new()
		item.setup(def, float(hash(item_id) % 100) / 100.0)
		item.set_space(true)
		item.can_sleep = false
		item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		item.freeze = true
		var foot: Vector3 = ground.call(float(at[0]), float(at[1]))
		item.transform = Transform3D(Basis(Vector3.UP, -deg_to_rad(float(entry.get("yaw", 0.0)))),
			foot + Vector3(0.0, def.size.y * 0.5, 0.0))
		node.add_child(item)
		_lying[item] = [place.id, item_id]
		_hooks[item] = take.bind(item)
		item.consumed.connect(_hooks[item])

## `item` has been taken into the hands (grasp.taken) or used up (Item.consumed):
## if it is one lying in a place, it is marked taken and is ours no more, so
## the place never makes it again. Any other item: nothing.
func take(item: Item) -> void:
	if not _lying.has(item):
		return
	var at: Array = _lying[item]
	var ids: Dictionary = _taken.get(at[0], {})
	ids[at[1]] = true
	_taken[at[0]] = ids
	_forget(item)

func _forget(item: Variant) -> void:
	var hook: Variant = _hooks.get(item)
	if is_instance_valid(item) and hook != null and item.consumed.is_connected(hook):
		item.consumed.disconnect(hook)
	_lying.erase(item)
	_hooks.erase(item)

func is_taken(place_id: StringName, item_id: String) -> bool:
	return _taken.get(place_id, {}).has(item_id)

## What is kept of the places: {"taken": {place id: [item ids, sorted]}}.
func to_dict() -> Dictionary:
	var taken := {}
	for id: Variant in _taken:
		var ids: Array = _taken[id].keys()
		ids.sort()
		taken[str(id)] = ids
	return {"taken": taken}

## Reads it back; a save with none (before phase 3) takes nothing. Places loaded
## now are made again, so what was taken is gone from them.
func from_dict(d: Dictionary) -> void:
	_taken = {}
	var taken: Dictionary = d.get("taken", {}) if d.get("taken") is Dictionary else {}
	for id: Variant in taken:
		var ids := {}
		for item_id: Variant in taken[id]:
			ids[str(item_id)] = true
		_taken[StringName(str(id))] = ids
	for id: StringName in _loaded.keys():
		_free(id)

## The ground's height under (x, z) of the frame `f` (in the place's frame),
## in f's own terms.
static func _floor_in(place: PlaceDesign, terrain: WorldTerrain, f: Transform3D) -> Callable:
	var on := ground_fn(place, terrain)
	var back := f.affine_inverse()
	return func(x: float, z: float) -> float:
		var p := f * Vector3(x, 0.0, z)
		return (back * (on.call(p.x, -p.z) as Vector3)).y

## The lowest ground under a footprint at layout `east`, `north`: `half` its
## half-size (east by north, before `yaw_deg` turns it clockwise), or a disc
## of `half.x` when `is_round`, sampled every FOOT_STEP and along its edge.
static func lowest_ground(place: PlaceDesign, terrain: WorldTerrain, east: float, north: float, half: Vector2,
		yaw_deg: float, is_round: bool) -> float:
	var on := ground_fn(place, terrain)
	var turn := deg_to_rad(yaw_deg)
	var lo := INF
	var nx := maxi(2, ceili(2.0 * half.x / FOOT_STEP))
	var ny := maxi(2, ceili(2.0 * half.y / FOOT_STEP))
	for i in nx + 1:
		for j in ny + 1:
			var e := -half.x + 2.0 * half.x * i / nx
			var n := -half.y + 2.0 * half.y * j / ny
			if is_round and Vector2(e, n).length() > half.x:
				continue
			lo = minf(lo, (on.call(east + e * cos(turn) + n * sin(turn), north - e * sin(turn) + n * cos(turn)) as Vector3).y)
	if is_round:
		for k in 48:
			var a := TAU * k / 48.0
			lo = minf(lo, (on.call(east + half.x * sin(a), north + half.x * cos(a)) as Vector3).y)
	return lo

# --- the ground, pure ---------------------------------------------------------

## The ground of the layout point `east`, `north` m from `place`, in the place's
## frame: the frame's origin is the place on its floor, and the world curves
## away from the frame's flat plane, which this follows.
static func on_ground(place: PlaceDesign, terrain: WorldTerrain, east: float, north: float) -> Vector3:
	var d := place.local_dir(east, north, terrain.radius)
	return _in_frame(place, terrain, d * (terrain.radius + terrain.height_at(d)))

## on_ground as a Callable(east, north) -> Vector3 for one place, with its frame
## and origin worked out once: the same numbers to the bit, at about half the
## cost (on_ground works the origin's height out again each call). For pieces
## that sample the ground thousands of times: the tracks, the outcrop.
static func ground_fn(place: PlaceDesign, terrain: WorldTerrain) -> Callable:
	var d := place.dir()
	var frame := place.frame()
	var inverse := frame.inverse()
	var origin := origin_of(place, terrain)
	var radius := terrain.radius
	return func(east: float, north: float) -> Vector3:
		# PlaceDesign.local_dir, written out with the frame kept.
		var offset := frame * Vector3(east, 0.0, -north)
		var metres := offset.length()
		var at := d
		if not is_zero_approx(metres):
			var angle := metres / radius
			at = (d * cos(angle) + offset / metres * sin(angle)).normalized()
		return inverse * (at * (radius + terrain.height_at(at)) - origin)

## The same point with any basin dug out of it: the level of the floor there
## (the stamps' FLATTENs), which a pool's water level is measured from.
static func floor_at(place: PlaceDesign, terrain: WorldTerrain, east: float, north: float) -> Vector3:
	var d := place.local_dir(east, north, terrain.radius)
	return _in_frame(place, terrain, d * (terrain.radius + floor_height(terrain, d)))

## The place's origin, on its floor and on the world's own axes (from the
## world's centre).
static func origin_of(place: PlaceDesign, terrain: WorldTerrain) -> Vector3:
	var d := place.dir()
	return d * (terrain.radius + floor_height(terrain, d))

## The universe point of `place` on its floor, on `body`.
static func ground_point(place: PlaceDesign, body: SystemBody, terrain: WorldTerrain) -> UniversePoint:
	return body.point.plus(origin_of(place, terrain))

## Metres over the radius at `d`: the ground with every BASIN's dig put back.
static func floor_height(terrain: WorldTerrain, d: Vector3) -> float:
	var h := terrain.height_at(d)
	for s in terrain.stamps:
		if s.kind == TerrainStamp.Kind.BASIN:
			h += s.dig(s.metres_from(d, terrain.radius))
	return h

static func _in_frame(place: PlaceDesign, terrain: WorldTerrain, from_centre: Vector3) -> Vector3:
	return place.frame().inverse() * (from_centre - origin_of(place, terrain))
