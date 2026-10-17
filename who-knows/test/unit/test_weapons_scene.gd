extends GutTest

## The weapons in the real flight scene (ship weapons spec §9): T marks the
## ship ahead, B engages, the brackets and the strip show it, bolts fly and
## follow the origin, and the list survives a save.

const PATH := "user://test_weapons_scene/game.json"

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func after_each():
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

func _arm_and_spawn(ahead := 400.0) -> Ship:
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	var top := BlockInstance.new()
	top.block_id = WeaponValues.LIGHT
	grid.set_block(Vector3i(0, 2, 0), top)
	_ship.launch_blueprint = null
	_ship.set_grid(grid)
	var place := Transform3D(_ship.exterior.global_basis,
		_ship.exterior.global_position - _ship.exterior.global_basis.z * ahead + _ship.exterior.global_basis.y * 20.0)
	var other: Ship = _root.fleet.spawn(ShipLibrary.read("res://data/ships/starter.json")["grid"], place)
	return other

func _key(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	_ship.pilot.handle(e)

func test_t_marks_the_ship_ahead_and_b_engages():
	var other := _arm_and_spawn()
	await wait_physics_frames(3)
	_ship.pilot.seated = true
	_key(&"weapons_mark")
	assert_eq(_ship.fire_control.list, [Weapons.ship_id(other)] as Array[StringName])
	_key(&"weapons_orders")
	assert_eq(_ship.fire_control.orders, FireControl.Orders.ENGAGE)
	_key(&"weapons_clear")
	assert_eq(_ship.fire_control.list.size(), 0)

func _key_event(code: Key, shift: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	return e

func test_the_real_t_key_marks_and_shift_t_clears():
	var other := _arm_and_spawn()
	await wait_physics_frames(3)
	_ship.pilot.seated = true
	_ship.pilot.handle(_key_event(KEY_T, false))
	assert_eq(_ship.fire_control.list, [Weapons.ship_id(other)] as Array[StringName], "T marks and does not clear")
	_ship.pilot.handle(_key_event(KEY_T, true))
	assert_eq(_ship.fire_control.list.size(), 0, "Shift+T clears and does not mark")

func test_the_real_b_key_toggles_orders_and_shift_b_does_not():
	_arm_and_spawn()
	await wait_physics_frames(3)
	_ship.pilot.seated = true
	_ship.pilot.handle(_key_event(KEY_B, true))
	assert_eq(_ship.fire_control.orders, FireControl.Orders.HOLD, "Shift+B is not B")
	_ship.pilot.handle(_key_event(KEY_B, false))
	assert_eq(_ship.fire_control.orders, FireControl.Orders.ENGAGE, "B engages")

func test_boarding_another_ship_rebinds_the_brackets_and_the_strip_follows():
	_arm_and_spawn()
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	var top := BlockInstance.new()
	top.block_id = WeaponValues.LIGHT
	grid.set_block(Vector3i(0, 2, 0), top)
	var place := Transform3D(_ship.exterior.global_basis, _ship.exterior.global_position + Vector3(300.0, 0.0, 0.0))
	var armed: Ship = _root.fleet.spawn(grid, place)
	await wait_physics_frames(3)
	_root.board_at_helm(armed)
	assert_eq(_root.target_brackets.size(), 3, "one per view")
	for b: TargetBrackets in _root.target_brackets:
		assert_same(b.fire_control, armed.fire_control)
	await wait_process_frames(3)
	assert_false(armed.fire_control.turrets.is_empty(), "the spawned ship is armed")
	assert_true(_root.weapons_strip.visible, "the strip shows at an armed ship's helm")

func test_the_turret_fires_on_a_marked_ship():
	var other := _arm_and_spawn()
	await wait_physics_frames(3)
	_ship.fire_control.mark(Weapons.ship_id(other))
	_ship.fire_control.set_orders(FireControl.Orders.ENGAGE)
	var before := _ship.quantum.store.amount
	await wait_seconds(4.0)
	assert_lt(_ship.quantum.store.amount, before, "it paid for bolts")
	var taken := 0.0
	for v in other.damage.section_damage.values():
		taken += v
	for v in other.damage.component_damage.values():
		taken += v
	assert_gt(taken, 0.0, "the other ship took some")

func test_bolts_shift_with_the_origin():
	var pool: BoltPool = _root.bolt_pool
	var ex: Array[RID] = []
	var bolt := pool.fire(WeaponValues.LIGHT, _ship.exterior.global_position + Vector3(0, 50, 0), Vector3.UP,
		Vector3.ZERO, null, ex)
	var at := bolt.global_position
	var universe: Universe = _root.get_node("Universe")
	universe.shift(Vector3(1000, 0, 0))
	assert_almost_eq(bolt.global_position, at - Vector3(1000, 0, 0), Vector3.ONE * 0.01)

func test_the_list_survives_a_save():
	_root.queue_free()
	await wait_process_frames(2)
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.save_enabled = true
	_root.save_path = PATH
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.get_node("Ship")
	var other := _arm_and_spawn()
	await wait_physics_frames(3)
	_ship.fire_control.mark(Weapons.ship_id(other))
	_ship.fire_control.mark(&"item:12345")
	_ship.fire_control.set_orders(FireControl.Orders.ENGAGE)
	assert_true(_root.save_now())
	var other_name := other.name
	_root.queue_free()
	await wait_process_frames(2)
	var again: Node = load("res://scenes/flight_test.tscn").instantiate()
	again.save_enabled = true
	again.save_path = PATH
	add_child_autofree(again)
	await wait_seconds(WeaponValues.MISSING_GRACE + 0.5)
	var ship: Ship = again.get_node("Ship")
	assert_eq(ship.fire_control.orders, FireControl.Orders.ENGAGE)
	assert_eq(ship.fire_control.list, [StringName("ship:%s" % other_name)] as Array[StringName], "the ship kept, the item gone")
