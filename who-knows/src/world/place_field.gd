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
## Later pieces (items, buildings, palms) are added in `_build`, which makes
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

var universe: Universe
var system: SystemRecipe
var whereabouts: Whereabouts
var catalog: ItemCatalog

var _places: Array[PlaceDesign] = []
## Place id -> the UniversePoint of the place on its floor (made on first use).
var _points := {}
var _loaded := {}   # StringName id -> Node3D

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
	if is_instance_valid(node):
		node.remove_from_group(Universe.EXTERIOR_SPACE)
		node.queue_free()

## Makes the pieces of `place` (its layout, data/places/<id>.json) as children
## of `node`, in the place's frame. Add each new kind of piece here.
func _build(place: PlaceDesign, body: SystemBody, node: Node3D) -> void:
	var terrain := whereabouts.terrain_of(body)
	var layout := place.layout()
	if layout.has("pool"):
		_build_pool(place, terrain, layout["pool"], node)

## The pool: its water, a flat faceted disc at its level, and the area that
## slows you in it.
func _build_pool(place: PlaceDesign, terrain: WorldTerrain, pool: Dictionary, node: Node3D) -> void:
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

# --- the ground, pure ---------------------------------------------------------

## The ground of the layout point `east`, `north` m from `place`, in the place's
## frame: the frame's origin is the place on its floor, and the world curves
## away from the frame's flat plane, which this follows.
static func on_ground(place: PlaceDesign, terrain: WorldTerrain, east: float, north: float) -> Vector3:
	var d := place.local_dir(east, north, terrain.radius)
	return _in_frame(place, terrain, d * (terrain.radius + terrain.height_at(d)))

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
