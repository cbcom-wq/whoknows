extends GutTest

## What you drop on a world falls, comes to rest and stays (desert world spec
## §5.5; plan task 9). Off a world -- a ring, deep space -- nothing pulls it.
## It is frozen only lying on the ground, never on a hull or a ramp, which may
## leave (final review I3, M5, T9a).

## A flat world: the pull straight down, the analytic ground the plane y = 0.
class FakeGravity extends WorldGravity:
	var g := Vector3(0, -5.0, 0)
	var world := true
	var air := 0.0
	func air_at(_p: Vector3) -> float:
		return air
	func at(_p: Vector3) -> Vector3:
		return g
	func on_world_at(_p: Vector3) -> bool:
		return world
	func up_at(_p: Vector3) -> Vector3:
		return Vector3.UP
	func altitude_at(p: Vector3) -> float:
		return p.y
	## The ground the collision has: `solid` m under the analytic ground, as
	## at a mesa's lip (final review I1); level with it by default.
	var solid := 0.0
	func solid_altitude_at(p: Vector3) -> float:
		return p.y + solid

var _universe: Universe
var _field: StrayField
var _gravity: FakeGravity
var _catalog: ItemCatalog

func before_each():
	_catalog = ItemCatalog.load_from_dir()
	_universe = Universe.new()
	add_child_autofree(_universe)
	_universe.set_physics_process(false)
	var focus := Node3D.new()
	add_child_autofree(focus)
	_universe.focus = focus
	_field = StrayField.new()
	add_child_autofree(_field)
	_field.set_physics_process(false)
	_field.setup(_universe, _catalog)
	_gravity = FakeGravity.new()
	_field.gravity = _gravity

func _stray(at := Vector3(0, 100, 0), v := Vector3.ZERO) -> Item:
	var item := Item.new()
	item.setup(_catalog.get_def(&"mug"))
	item.set_space(true)
	item.set_loose()
	add_child(item)
	item.global_position = at
	item.linear_velocity = v
	_field.adopt(item)
	return item

## A static slab on `layer` whose top is at height `top`: the ground's
## collider (BodyProxy.LAYER), or a landed hull's (layer 1, frozen static).
func _slab(layer: int, top: float, size := Vector3(40, 1, 40)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector3(0, top - size.y * 0.5, 0)
	return body

## Steps the pull and the physics for `seconds`.
func _settle(seconds: float) -> void:
	for i in int(seconds * 60.0):
		_field.pull(1.0 / 60.0)
		await wait_physics_frames(1)

## How far `item`'s underside is over the plane y = 0: 0 lying on the ground.
static func _gap(item: Item) -> float:
	var b := item.global_basis.orthonormalized()
	var h := item.definition.size * 0.5
	var half := absf(b.x.y) * h.x + absf(b.y.y) * h.y + absf(b.z.y) * h.z
	return item.global_position.y - half

func test_a_stray_on_a_world_falls():
	var item := _stray()
	for i in 30:
		_field.pull(1.0 / 60.0)
		await wait_physics_frames(1)
	assert_lt(item.linear_velocity.y, -1.0, "it gained downward speed")

func test_a_stray_off_a_world_keeps_its_velocity():
	_gravity.world = false
	var v := Vector3(1, 0, 0)
	var item := _stray(Vector3(0, 100, 0), v)
	for i in 30:
		_field.pull(1.0 / 60.0)
		await wait_physics_frames(1)
	assert_almost_eq(item.linear_velocity, v, Vector3.ONE * 0.001)

func test_a_stray_at_rest_on_the_ground_ends_frozen():
	_slab(BodyProxy.LAYER, 0.0)
	await wait_physics_frames(1)
	var item := _stray(Vector3(0, 0.4, 0))
	await _settle(StrayField.REST_TIME + 1.5)
	assert_true(item.freeze, "frozen")
	assert_eq(item.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
	assert_almost_eq(_gap(item), 0.0, 0.05, "lying on the ground")

func test_a_moving_stray_is_not_frozen():
	var item := _stray(Vector3(0, 100, 0), Vector3(0, 5, 0))
	for i in 60:
		_field.pull(1.0 / 60.0)
		item.linear_velocity = Vector3(0, 5, 0)
	assert_false(item.freeze)

## Final review I3: still in mid-air -- nothing under it -- is not at rest on
## the ground: it is never frozen there.
func test_a_still_stray_in_mid_air_is_not_frozen():
	var item := _stray()
	for i in int((StrayField.REST_TIME + 0.2) * 60.0):
		_field.pull(1.0 / 60.0)
	assert_false(item.freeze, "nothing holds it up: it is not lying on the ground")

## Final review I3: a stray resting on a landed hull or its ramp is live, not
## frozen, so once the hull leaves it falls to the ground and rests there.
func test_a_stray_resting_on_a_landed_hull_stays_live_and_falls_after_liftoff():
	_slab(BodyProxy.LAYER, 0.0)
	var hull := _slab(1, 2.0, Vector3(4, 0.2, 4))
	await wait_physics_frames(1)
	var item := _stray(Vector3(0, 2.4, 0))
	await _settle(StrayField.REST_TIME + 1.5)
	assert_lt(item.linear_velocity.length(), 0.1, "at rest")
	assert_almost_eq(_gap(item), 2.0, 0.05, "on the hull")
	assert_false(item.freeze, "resting on a hull, not the ground: live")
	hull.global_position += Vector3(0, 300, 0)
	await _settle(StrayField.REST_TIME + 2.0)
	assert_true(item.freeze, "at rest on the ground at last")
	assert_almost_eq(_gap(item), 0.0, 0.05, "on the ground, not hanging where the hull was")

## Final review M5: ground is solid only near anchors, so a stray falling far
## from one passes under the ground: found there, it is put on it and frozen.
func test_a_stray_below_the_ground_is_lifted_onto_it():
	var item := _stray(Vector3(0, -3.0, 0), Vector3(0, -8, 0))
	_field.pull(1.0 / 60.0)
	assert_true(item.freeze, "frozen")
	assert_almost_eq(_gap(item), 0.0, 0.001, "lying on the ground")
	assert_eq(item.linear_velocity, Vector3.ZERO)

## Task 15 N2: on a crest the ground's collider is a chord under the analytic
## ground (WorldSurface.FLOOR_SLACK covers it), so a thin stray lying on it has
## its middle a few centimetres under altitude 0. It is lying on the ground,
## not under it: it rests and freezes there, not lifted 8 cm proud of it.
func test_a_thin_stray_on_a_crest_rests_on_the_collider_not_over_it():
	_slab(BodyProxy.LAYER, -0.08)
	await wait_physics_frames(1)
	var item := Item.new()
	item.setup(_catalog.get_def(&"scrap_plate"))
	item.set_space(true)
	item.set_loose()
	add_child(item)
	item.global_position = Vector3(0, -0.08 + item.definition.size.y * 0.5 + 0.005, 0)
	_field.adopt(item)
	assert_lt(_gap(item), 0.0, "its underside under the analytic ground, on the collider")
	await _settle(StrayField.REST_TIME + 1.5)
	assert_true(item.freeze, "frozen, lying on the ground")
	assert_almost_eq(_gap(item), -0.08, 0.02, "on the collider (%.3f m), not lifted onto the analytic ground" % _gap(item))
	assert_almost_eq(StrayField.ON_GROUND, 0.25, 0.001)

## Final review T9a: a stray saved mid-fall loads where it was, falls, and
## comes to rest on the ground -- never frozen in mid-air. No ground collider
## here, as on a load far from every anchor: it ends on the analytic ground.
func test_a_stray_saved_mid_air_loads_and_ends_on_the_ground():
	_stray(Vector3(0, 3.0, 0), Vector3(0, -2, 0))
	var id := _field.ledger.entries.keys()[0] as int
	_field._unload(id)
	_field._load(id)
	var item := _field.live(id)
	assert_false(item.freeze, "not frozen in mid-air on load")
	await _settle(2.0)
	assert_true(item.freeze, "frozen")
	assert_almost_eq(_gap(item), 0.0, 0.001, "on the ground")

## ...and one saved lying on the ground loads frozen there.
func test_a_stray_loaded_on_the_ground_loads_frozen_on_it():
	_stray(Vector3(0, 0.1, 0))
	var id := _field.ledger.entries.keys()[0] as int
	_field._unload(id)
	_field._load(id)
	var loaded := _field.live(id)
	assert_true(loaded.freeze, "frozen on load")
	assert_almost_eq(_gap(loaded), 0.0, 0.001, "lying on the ground")

## ...and one saved below it loads lifted onto it.
func test_a_stray_loaded_below_the_ground_loads_on_it():
	_stray(Vector3(0, -2.0, 0))
	var id := _field.ledger.entries.keys()[0] as int
	_field._unload(id)
	_field._load(id)
	var loaded := _field.live(id)
	assert_true(loaded.freeze)
	assert_almost_eq(_gap(loaded), 0.0, 0.001)

func test_a_stray_loaded_off_a_world_loads_free():
	var item := _stray()
	var id := _field.ledger.entries.keys()[0] as int
	_gravity.world = false
	_field._unload(id)
	_field._load(id)
	assert_false(_field.live(id).freeze)

func test_a_stray_let_go_is_not_left_frozen():
	var item := _stray()
	_field.let_go(item)
	for i in int((StrayField.REST_TIME + 0.2) * 60.0):
		_field.pull(1.0 / 60.0)
	assert_false(item.freeze, "no longer the field's to freeze")

func test_a_frozen_stray_can_be_taken_and_let_go():
	_slab(BodyProxy.LAYER, 0.0)
	await wait_physics_frames(1)
	var item := _stray(Vector3(0, 0.4, 0))
	await _settle(StrayField.REST_TIME + 1.5)
	assert_true(item.freeze)
	item.set_held()
	_field.let_go(item)
	item.set_loose()
	for i in 60:
		_field.pull(1.0 / 60.0)
	assert_false(item.freeze)

func test_a_stray_in_air_slows():
	_gravity.g = Vector3.ZERO
	_gravity.air = 1.0
	var item := _stray(Vector3(0, 100, 0), Vector3(50, 0, 0))
	for i in 30:
		_field.pull(1.0 / 60.0)
		await wait_physics_frames(1)
	assert_lt(item.linear_velocity.length(), 50.0 - 0.5)

## Final review I1: at a mesa's lip the ground the collision has (the
## triangles) sits metres under the analytic ground. A stray lying on it there
## is on the ground: it rests and freezes on the collider, never lifted onto
## the analytic ground and frozen in mid-air; and it loads there again.
func test_a_stray_at_a_lip_rests_on_the_triangles_under_the_analytic_ground():
	_gravity.solid = 3.0
	_slab(BodyProxy.LAYER, -3.0)
	await wait_physics_frames(1)
	var item := _stray(Vector3(0, -3.0 + 0.3, 0))
	await _settle(StrayField.REST_TIME + 1.5)
	assert_true(item.freeze, "frozen, lying on the ground")
	assert_almost_eq(_gap(item), -3.0, 0.02, "on the collider (%.2f m), not lifted onto the analytic ground" % _gap(item))
	var id := _field.ledger.entries.keys()[0] as int
	_field._unload(id)
	_field._load(id)
	var loaded := _field.live(id)
	assert_true(loaded.freeze, "frozen on load")
	assert_almost_eq(_gap(loaded), -3.0, 0.02, "loaded on the collider (%.2f m)" % _gap(loaded))
	# Under the collider there it is still put on it: on it, not on the
	# analytic ground over it.
	var under := _stray(Vector3(0, -4.0, 0), Vector3(0, -8, 0))
	_field.pull(1.0 / 60.0)
	assert_true(under.freeze, "frozen")
	assert_almost_eq(_gap(under), -3.0, 0.001, "put on the collider")

## Final review M3: a stray come to rest on a boulder 2 m over the ground is
## frozen there. Unloaded and loaded again far from every anchor -- no
## collider under it any more -- it is frozen where it lay, not let fall
## through the stone and put on the ground inside it; through a save too.
func test_a_stray_frozen_on_a_boulder_loads_frozen_where_it_lay():
	var stone := _slab(BodyProxy.LAYER, 2.0, Vector3(3, 1, 3))
	await wait_physics_frames(1)
	var item := _stray(Vector3(0, 2.4, 0))
	await _settle(StrayField.REST_TIME + 1.5)
	assert_true(item.freeze, "frozen on the stone")
	var lay := item.global_position
	var id := _field.ledger.entries.keys()[0] as int
	_field.sync()   # as tick() does before it unloads
	_field._unload(id)
	stone.free()
	_field._load(id)
	var loaded := _field.live(id)
	assert_true(loaded.freeze, "frozen on load")
	assert_almost_eq(loaded.global_position, lay, Vector3.ONE * 0.001, "where it lay")
	_field.from_dict(_field.to_dict())
	var saved := _field.live(_field.ledger.entries.keys()[0] as int)
	assert_true(saved.freeze, "through a save: frozen")
	assert_almost_eq(saved.global_position, lay, Vector3.ONE * 0.001, "where it lay")
