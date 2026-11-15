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
## The ground under the green patch is gathered this far past its reach, m,
## and the patch lies on or over the ground drawn up to GREEN_COARSER levels
## coarser than the finest: what the world draws round the oasis from up to
## about 300 m over it (2.6 and 5.2 m quads), which cut under the finest's
## where the pool bank's stamp eases out.
const GREEN_MARGIN := 2.0
const GREEN_COARSER := 2
## The broken wall's foot follows the ground, sampled about this often, m.
const WALL_STEP := 2.0
## A compound's yard walls (Rework 1, round 2) are this high (m) unless the
## layout says otherwise: lower than the ring wall's 2.6, over your eye.
const YARD_HEIGHT := 1.8
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
## gardens, the pump and its pipe, the path, the brick shells (Rework 1: twelve,
## in five compounds, each on its stamp), the compounds' yard walls, the ring
## wall with its gate and breach, the rubble and the shade sails. Every solid is one kit's, every tuft one MultiMesh's,
## the palms' trunks one body's, the shells' another's and the wall's a third,
## and each piece stands on the ground of its layout point (on_ground), never
## on a height of its own. Each piece's kind, id, lowest vertex and (for a
## shell or a garden) the floor it was built for are kept as the holder's meta
## `pieces` (a headless test reads them: a committed mesh reads back nothing
## without a renderer).
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
	var mark := func(kind: String, id: String, from: int, floor_y := NAN) -> void:
		marks.append([kind, id, from, kit.vertex_count(InteriorKit.Batch.SOLID), floor_y])
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
		mark.call("garden", str(g.get("id", "garden_%d" % i)), from, f.origin.y)
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
		var piece := {"kind": m[0], "id": m[1], "lowest": lowest}
		if not is_nan(m[4]):
			piece["floor"] = m[4]
		pieces.append(piece)
	holder.set_meta(&"pieces", pieces)
	if layout.has("grass_ring") and layout.has("pool"):
		var ring: Dictionary = layout["grass_ring"]
		var axes: Array = ring.get("axes", [36, 26])
		var at: Array = layout["pool"].get("at", [0, 0])
		var centre: Vector3 = ground.call(float(at[0]), float(at[1]))
		var floor_of := func(x: float, z: float) -> float:
			return (ground.call(x, -z) as Vector3).y
		var size := Vector2(float(axes[0]), float(axes[1]))
		node.add_child(OasisLooks.grass_ring(Transform3D(Basis.IDENTITY, centre),
			size, water_radius, float(ring.get("inner", 1.5)), hash(String(place.id)), floor_of, avoid))
		_build_green(place, terrain, node, centre, size, water_radius)

## The green patch under the grass ring: its own mesh "GreenPatch", lit as the
## ground is (BodyLook's material), laid on the finest ground's own triangles
## round the pool, raised where a coarser chunk's lie higher
## (ground_triangles, GREEN_COARSER). Every vertex laid is kept as its meta
## `laid` (a headless test reads them).
func _build_green(place: PlaceDesign, terrain: WorldTerrain, node: Node3D, centre: Vector3, axes: Vector2,
		water_radius: float) -> void:
	var holder := Node3D.new()
	holder.name = "GreenPatch"
	node.add_child(holder)
	var kit := OasisLooks.kit_under(holder)
	kit.materials[InteriorKit.Batch.SOLID] = BodyLook.material(false)
	var reach := axes * (1.0 + OasisLooks.green_spill()) + Vector2.ONE * GREEN_MARGIN
	var east := centre.x
	var north := -centre.z
	var laid := OasisLooks.green_patch(kit, ground_triangles(place, terrain, east, north, reach, GREEN_COARSER),
		centre, axes, water_radius, hash(String(place.id)))
	for m in kit.commit():
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.set_meta(&"laid", laid)

## The brick: the shells, the compounds' yard walls, the ring wall, its rubble
## and the shade sails, into the village's `kit`. The shells' and yards' solid
## parts are on one StaticBody3D "Brick", the ring wall's and its gate piers'
## on another, "Wall" (both on BodyProxy.LAYER). Each shell stands on its
## compound's stamp (Rework 1, round 2: the layout's `stamp`): its walls start
## SUNK under the lowest ground under its footprint, which the stamp keeps
## level, and that ground is the floor it is built for. A box shell has a door
## (BrickShell.DOOR) in the middle of its front, which its yaw turns onto a
## lane. A wall's or a yard's foot follows the ground point to point.
func _build_brick(place: PlaceDesign, terrain: WorldTerrain, layout: Dictionary, node: Node3D,
		kit: InteriorKit, mark: Callable, avoid: Array[Vector3]) -> void:
	var shells: Array = layout.get("shells", [])
	var wall: Dictionary = layout.get("wall", {})
	if shells.is_empty() and wall.is_empty() and not layout.has("rubble") and not layout.has("sails") \
			and not layout.has("yards"):
		return
	var brick := _solid_body(node, "Brick")
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
		var foot := 0.0
		if str(s["kind"]) == "round":
			var radius := float(s["radius"])
			var height := float(s.get("height", 3.0))
			foot = lowest_ground(place, terrain, east, north, Vector2(radius, radius), yaw, true)
			var f := Transform3D(turn, Vector3(centre.x, foot - BrickShell.SUNK, centre.z))
			BrickShell.round_hut(kit, f, radius, height, variety)
			add.call(BrickShell.round_hut_shapes(f, radius, height, variety))
			avoid.append(Vector3(centre.x, centre.z, radius + GRASS_MARGIN))
		else:
			var sz: Array = s["size"]
			var size := Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
			foot = lowest_ground(place, terrain, east, north, Vector2(size.x, size.z) * 0.5, yaw, false)
			var f := Transform3D(turn, Vector3(centre.x, foot - BrickShell.SUNK, centre.z))
			if str(s["kind"]) == "crushed":
				BrickShell.crushed(kit, f, size, variety)
				add.call(BrickShell.crushed_shapes(f, size, variety))
			else:
				var openings: Array = s.get("openings", [[Vector3(0.0, BrickShell.DOOR.y * 0.5,
					-size.z * 0.5 + BrickShell.WALL * 0.5), BrickShell.DOOR.x, BrickShell.DOOR.y]])
				BrickShell.box(kit, f, size, openings, variety)
				add.call(BrickShell.box_shapes(f, size, openings, variety))
			avoid.append(Vector3(centre.x, centre.z, Vector2(size.x, size.z).length() * 0.5 + GRASS_MARGIN))
		mark.call("shell", str(s["id"]), from, foot)
	var yards: Array = layout.get("yards", [])
	for k in yards.size():
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var y: Dictionary = yards[k]
		var run := PackedVector2Array()
		for p: Array in y["points"]:
			run.append(Vector2(float(p[0]), float(p[1])))
		var points := wall_points(place, terrain, run)
		var height := float(y.get("height", YARD_HEIGHT))
		var variety := 0.17 + 0.23 * k
		BrickShell.wall(kit, points, height, variety)
		add.call(BrickShell.wall_shapes(points, height, variety))
		mark.call("yard", str(y.get("id", "yard_%d" % k)), from)
	if wall.has("ring"):
		_build_ring_wall(place, terrain, wall, node, kit, mark)
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

## The ground under a wall's line `run` ([east, north] m), in the place's
## frame, about every WALL_STEP: where its foot goes.
static func wall_points(place: PlaceDesign, terrain: WorldTerrain, run: PackedVector2Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for j in run.size() - 1:
		var n := maxi(1, roundi(run[j].distance_to(run[j + 1]) / WALL_STEP))
		for i in n:
			var p := run[j].lerp(run[j + 1], float(i) / n)
			points.append(on_ground(place, terrain, p.x, p.y))
	points.append(on_ground(place, terrain, run[run.size() - 1].x, run[run.size() - 1].y))
	return points

## A StaticBody3D `name` under `node`, on BodyProxy.LAYER, colliding with nothing.
static func _solid_body(node: Node3D, body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = BodyProxy.LAYER
	body.collision_mask = 0
	node.add_child(body)
	return body

## The ring wall (Rework 1): its runs between the gate and the breach
## (ring_wall), their foot following the ground, and the gate's two piers,
## thicker and taller, on the ground under them. All on one StaticBody3D "Wall".
func _build_ring_wall(place: PlaceDesign, terrain: WorldTerrain, wall: Dictionary, node: Node3D,
		kit: InteriorKit, mark: Callable) -> void:
	var body := _solid_body(node, "Wall")
	var ring := ring_wall(wall)
	var height := float(wall.get("height", 2.6))
	var runs: Array = ring["runs"]
	for k in runs.size():
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var points := wall_points(place, terrain, runs[k])
		var variety := 0.31 + 0.27 * k
		BrickShell.wall(kit, points, height, variety)
		for c in BrickShell.wall_shapes(points, height, variety):
			body.add_child(c)
		mark.call("wall", "wall_%d" % k, from)
	var pier: Array = wall.get("gate", {}).get("pier", [1.2, 3.4])
	var size := Vector3(float(pier[0]), float(pier[1]), float(pier[0]))
	var piers: Array = ring["piers"]
	for k in piers.size():
		var from := kit.vertex_count(InteriorKit.Batch.SOLID)
		var at: Vector2 = piers[k][0]
		var along: Vector2 = piers[k][1]
		var x := Vector3(along.x, 0.0, -along.y)
		var yaw := rad_to_deg(atan2(-along.y, along.x))
		var foot := lowest_ground(place, terrain, at.x, at.y, Vector2.ONE * size.x * 0.5, yaw, false)
		var centre := on_ground(place, terrain, at.x, at.y)
		var f := Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(centre.x, foot - BrickShell.SUNK, centre.z))
		BrickShell.pier(kit, f, size + Vector3(0.0, BrickShell.SUNK, 0.0), 0.6 + 0.2 * k)
		for c in BrickShell.pier_shapes(f, size + Vector3(0.0, BrickShell.SUNK, 0.0), 0.6 + 0.2 * k):
			body.add_child(c)
		mark.call("pier", "pier_%d" % k, from)

## The ring wall of a layout's `wall` ({"ring": [[east, north]...], "gate":
## {"at", "width", "pier": [thickness, height]}, "breach": {"at", "width"}}),
## in [east, north] m, pure: the closed polygon `ring` cut open where the gate
## and the breach lie on it (each `at` taken to its nearest point on the ring).
## The gate's cut runs to its piers' middles, so the clear way between the
## piers is its `width`; the breach's is its `width`. Returns {"runs": the
## pieces left, each a PackedVector2Array along the ring; "piers": [middle,
## unit along the ring] for each gate pier; "gate", "breach": [the run ends
## either side]}.
static func ring_wall(wall: Dictionary) -> Dictionary:
	var ring := PackedVector2Array()
	for p: Array in wall.get("ring", []):
		ring.append(Vector2(float(p[0]), float(p[1])))
	var n := ring.size()
	var out := {"runs": [], "piers": []}
	if n < 3:
		return out
	var s_at := PackedFloat64Array([0.0])
	for i in n:
		s_at.append(s_at[i] + ring[i].distance_to(ring[(i + 1) % n]))
	var total := s_at[n]
	var cuts := []
	for which in ["gate", "breach"]:
		if not wall.has(which):
			continue
		var o: Dictionary = wall[which]
		var c := Vector2(float(o["at"][0]), float(o["at"][1]))
		var best := INF
		var s := 0.0
		for i in n:
			var q := Geometry2D.get_closest_point_to_segment(c, ring[i], ring[(i + 1) % n])
			if c.distance_to(q) < best:
				best = c.distance_to(q)
				s = s_at[i] + ring[i].distance_to(q)
		var half := float(o.get("width", 4.0)) * 0.5
		if which == "gate":
			half += float(o.get("pier", [1.2, 3.4])[0]) * 0.5
			for side in [-1.0, 1.0]:
				out["piers"].append([_ring_point(ring, s_at, s + side * half), _ring_along(ring, s_at, s + side * half)])
		out[which] = [_ring_point(ring, s_at, s - half), _ring_point(ring, s_at, s + half)]
		cuts.append([s - half, s + half])
	if cuts.is_empty():
		var whole := ring.duplicate()
		whole.append(ring[0])
		out["runs"].append(whole)
		return out
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in cuts.size():
		var start: float = cuts[k][1]
		var end: float = cuts[(k + 1) % cuts.size()][0]
		while end <= start:
			end += total
		var run := PackedVector2Array([_ring_point(ring, s_at, start)])
		for lap in 3:
			for i in n:
				var si := s_at[i] + total * (lap - 1)
				if si > start + 0.01 and si < end - 0.01:
					run.append(ring[i])
		run.append(_ring_point(ring, s_at, end))
		out["runs"].append(run)
	return out

## The point `s` m round `ring` from its first corner (s_at: each corner's).
static func _ring_point(ring: PackedVector2Array, s_at: PackedFloat64Array, s: float) -> Vector2:
	var n := ring.size()
	s = fposmod(s, s_at[n])
	for i in n:
		if s <= s_at[i + 1]:
			return ring[i].lerp(ring[(i + 1) % n], (s - s_at[i]) / maxf(s_at[i + 1] - s_at[i], 1e-9))
	return ring[0]

## The unit way along `ring` at `s` m round it.
static func _ring_along(ring: PackedVector2Array, s_at: PackedFloat64Array, s: float) -> Vector2:
	var n := ring.size()
	s = fposmod(s, s_at[n])
	for i in n:
		if s <= s_at[i + 1]:
			return (ring[(i + 1) % n] - ring[i]).normalized()
	return (ring[1] - ring[0]).normalized()

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
## that sample the ground thousands of times: the tracks.
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

## The finest ground's own triangles over the rectangle `half` (east by north,
## m) either side of layout point `east`, `north`, in the place's frame: each
## a PackedVector3Array of three points, the very corners and split a finest
## chunk draws and collides with (TerrainChunkData.build: quad i00-i10-i11-
## i01, split i00-i10-i11 and i00-i11-i01). A quad is kept if any of its
## corners lies in the rectangle. With `coarser` over 0, a corner is raised
## to the ground drawn that many levels coarser where that lies higher (from
## the air the world draws a place in coarser chunks, whose quads cut under
## or over the finest's where the ground bends), so what lies on them lies
## on every one. The grid is the face's under the point; a rectangle across a
## cube face's edge is not handled (the oasis is far from one). Pure.
static func ground_triangles(place: PlaceDesign, terrain: WorldTerrain, east: float, north: float,
		half: Vector2, coarser := 0) -> Array:
	var depth := CubeSphere.depth_for(terrain.radius)
	var fuv := CubeSphere.face_uv(place.local_dir(east, north, terrain.radius))
	var face := int(fuv.x)
	var last := (1 << depth) * CubeSphere.QUADS
	var step := 2.0 / last
	var gi := floori((fuv.y + 1.0) / step)
	var gj := floori((fuv.z + 1.0) / step)
	var inverse := place.frame().inverse()
	var origin := origin_of(place, terrain)
	# The rectangle in grid steps: one step along i and along j, in east and
	# north metres, inverted at the rectangle's corners (the grid is near
	# enough even over 100 m).
	var p0 := _grid_corner(terrain, face, depth, gi, gj, inverse, origin)
	var di := _grid_corner(terrain, face, depth, gi + 1, gj, inverse, origin) - p0
	var dj := _grid_corner(terrain, face, depth, gi, gj + 1, inverse, origin) - p0
	var to_grid := Transform2D(Vector2(di.x, -di.z), Vector2(dj.x, -dj.z), Vector2.ZERO).affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := -lo
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var g := to_grid * Vector2(east + sx * half.x - p0.x, north + sy * half.y + p0.z)
			lo = lo.min(g)
			hi = hi.max(g)
	# The quads looked at, and every corner they and their coarser quads need,
	# in one flat grid (a coarser chunk's grid points are every 2nd, 4th... of
	# the finest's).
	var m_most := 1 << coarser
	var qi0 := maxi(gi + floori(lo.x) - 2, 0)
	var qj0 := maxi(gj + floori(lo.y) - 2, 0)
	var qi1 := mini(gi + ceili(hi.x) + 2, last)
	var qj1 := mini(gj + ceili(hi.y) + 2, last)
	var ci0 := floori(float(qi0) / m_most) * m_most
	var cj0 := floori(float(qj0) / m_most) * m_most
	var w := mini(ceili(float(qi1 + 1) / m_most) * m_most, last) - ci0 + 1
	var h := mini(ceili(float(qj1 + 1) / m_most) * m_most, last) - cj0 + 1
	var us := PackedFloat64Array()
	for i in w:
		us.append(_grid_uv(depth, ci0 + i))
	var vs := PackedFloat64Array()
	for j in h:
		vs.append(_grid_uv(depth, cj0 + j))
	var grid := PackedVector3Array()
	grid.resize(w * h)
	for j in h:
		for i in w:
			var d := CubeSphere.direction(face, us[i], vs[j])
			grid[j * w + i] = inverse * (d * (terrain.radius + terrain.height_at(d)) - origin)
	# Each corner raised, where it must be, onto the ground drawn up to
	# `coarser` levels coarser: a coarser quad's diagonal runs along the
	# finest's, so within a finest triangle the coarser ground is flat, and a
	# triangle whose corners lie on or over it lies on or over it all through.
	var raised := grid.duplicate()
	for level in range(1, coarser + 1):
		var m := 1 << level
		for j in h:
			for i in w:
				var a := floori(float(i) / m) * m
				var b := floori(float(j) / m) * m
				if a + m >= w or b + m >= h:
					continue
				var p := grid[j * w + i]
				var c00 := grid[b * w + a]
				var c11 := grid[(b + m) * w + a + m]
				var other := grid[b * w + a + m] if i - a >= j - b else grid[(b + m) * w + a]
				var normal := (c11 - c00).cross(other - c00)
				if absf(normal.y) > 1e-9:
					var y := c00.y - (normal.x * (p.x - c00.x) + normal.z * (p.z - c00.z)) / normal.y
					if y > raised[j * w + i].y:
						raised[j * w + i] = Vector3(p.x, y, p.z)
	var inside := PackedByteArray()
	inside.resize(w * h)
	for k in w * h:
		var c := grid[k]
		inside[k] = 1 if absf(c.x - east) <= half.x and absf(-c.z - north) <= half.y else 0
	var out := []
	for j in range(qj0 - cj0, mini(qj1 - cj0, h - 1)):
		for i in range(qi0 - ci0, mini(qi1 - ci0, w - 1)):
			var k := j * w + i
			if inside[k] + inside[k + 1] + inside[k + w] + inside[k + w + 1] > 0:
				out.append(PackedVector3Array([raised[k], raised[k + 1], raised[k + w + 1]]))
				out.append(PackedVector3Array([raised[k], raised[k + w + 1], raised[k + w]]))
	return out

## Grid point `i`, `j` (counted over the whole face) of the finest chunks of
## `face`, in a place's frame (`inverse` of its basis, `origin` its point on
## the world's axes), worked out as the chunk holding it does: its rect's
## start plus whole steps, at height_at.
static func _grid_corner(terrain: WorldTerrain, face: int, depth: int, i: int, j: int, inverse: Basis,
		origin: Vector3) -> Vector3:
	var d := CubeSphere.direction(face, _grid_uv(depth, i), _grid_uv(depth, j))
	return inverse * (d * (terrain.radius + terrain.height_at(d)) - origin)

## The face coordinate of finest grid line `i`, as its chunk works it out.
static func _grid_uv(depth: int, i: int) -> float:
	var n := CubeSphere.QUADS
	var c := clampi(floori(float(i) / n), 0, (1 << depth) - 1)
	var rect := CubeSphere.node_rect(Vector4i(0, depth, c, 0))
	return rect.x + (i - c * n) * (rect.z / n)

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
