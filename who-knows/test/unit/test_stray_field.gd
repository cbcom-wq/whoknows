extends GutTest

## What you drop on a world falls, comes to rest and stays (desert world spec
## §5.5; plan task 9). Off a world -- a ring, deep space -- nothing pulls it.

class FakeGravity extends WorldGravity:
	var g := Vector3(0, -5.0, 0)
	var world := true
	func at(_p: Vector3) -> Vector3:
		return g
	func on_world_at(_p: Vector3) -> bool:
		return world

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

func test_a_stray_at_rest_on_a_world_ends_frozen():
	var item := _stray()
	for i in int((StrayField.REST_TIME + 0.2) * 60.0):
		_field.pull(1.0 / 60.0)
	assert_true(item.freeze, "frozen")
	assert_eq(item.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)

func test_a_moving_stray_is_not_frozen():
	var item := _stray(Vector3(0, 100, 0), Vector3(0, 5, 0))
	for i in 60:
		_field.pull(1.0 / 60.0)
		item.linear_velocity = Vector3(0, 5, 0)
	assert_false(item.freeze)

func test_a_stray_loaded_on_a_world_loads_frozen():
	var item := _stray()
	var id := _field.ledger.entries.keys()[0] as int
	_field._unload(id)
	_field._load(id)
	assert_true(_field.live(id).freeze, "frozen on load")

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
	var item := _stray()
	for i in int((StrayField.REST_TIME + 0.2) * 60.0):
		_field.pull(1.0 / 60.0)
	assert_true(item.freeze)
	item.set_held()
	_field.let_go(item)
	item.set_loose()
	for i in 60:
		_field.pull(1.0 / 60.0)
	assert_false(item.freeze)
