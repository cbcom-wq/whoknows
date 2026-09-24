extends GutTest

## Grasp (hands-and-items spec §7, as amended 2026-09-24), with real bodies
## stepped through physics frames: taking into the hands, throwing, dropping
## and stowing.

class CountingUse extends ItemUse:
	var count := 0
	func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
		count += 1
		return true

var _world: Node3D
var _body: CharacterBody3D
var _head: Node3D
var _grasp: Grasp

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_add_box(Vector3(0, -0.1, 0), Vector3(20, 0.2, 20))
	_body = CharacterBody3D.new()
	_body.collision_layer = 4
	_body.collision_mask = 2 | 32
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	_body.add_child(shape)
	_world.add_child(_body)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.6, 0)
	_body.add_child(_head)
	_grasp = Grasp.new()
	_body.add_child(_grasp)
	_grasp.bind(_body, _head)
	_grasp.world_root = _world

func _add_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	body.position = at
	_world.add_child(body)
	return body

func _item(grip := ItemDefinition.Grip.CARRY, mass := 4.0, at := Vector3(0, 1.3, -0.9)) -> Item:
	var d := ItemDefinition.new()
	d.id = &"thing"
	d.display_name = "Thing"
	d.mass_kg = mass
	d.size = Vector3(0.2, 0.2, 0.3)
	d.grip = grip
	d.stow_class = &"small"
	d.look = &"crate"
	d.grip_point = Vector3(0, -0.05, 0.05)
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_loose()
	return item

func _point_at(at: Vector3) -> StowPoint:
	var point := StowPoint.new()
	point.accepts = &"small"
	_world.add_child(point)
	point.global_position = at
	return point

func test_takes_a_one_handed_item_into_the_right_hand():
	var item := _item(ItemDefinition.Grip.WIELD)
	assert_true(_grasp.take(item))
	assert_eq(_grasp.mode, Grasp.Mode.WIELDING)
	assert_eq(item.get_parent(), _grasp.wield_socket)
	assert_eq(item.state, Item.State.HELD)
	assert_almost_eq(item.position, -item.definition.grip_point, Vector3.ONE * 0.0001)

func test_takes_a_two_handed_item_into_both_hands():
	var item := _item()
	assert_true(_grasp.take(item))
	assert_eq(_grasp.mode, Grasp.Mode.CARRYING)
	assert_eq(item.get_parent(), _grasp.carry_socket, "attached, not floating on a physics hold")
	assert_eq(item.state, Item.State.HELD)
	assert_true(item.freeze)
	assert_eq(item.collision_layer, 0)
	assert_almost_eq(item.position, Vector3(0, 0, -0.15), Vector3.ONE * 0.0001, "its near face on the socket")
	assert_true(item.basis.is_equal_approx(Basis.IDENTITY), "upright, facing the way you look")

func test_a_carried_item_moves_and_turns_with_the_view():
	var item := _item()
	_grasp.take(item)
	var before := item.global_position
	_head.rotation.y = PI * 0.5
	assert_almost_eq(item.global_basis.z, _head.global_basis.z, Vector3.ONE * 0.0001)
	assert_ne(item.global_position, before)

func test_taking_announces_where_the_item_came_from():
	var item := _item(ItemDefinition.Grip.WIELD, 1.0, Vector3(0.4, 0.9, -1.2))
	var from := item.global_transform
	watch_signals(_grasp)
	_grasp.take(item)
	assert_signal_emitted_with_parameters(_grasp, "taken", [item, from])

func test_hands_must_be_empty():
	_grasp.take(_item())
	var other := _item(ItemDefinition.Grip.CARRY, 4.0, Vector3(1, 1.3, -0.9))
	assert_false(_grasp.can_take(other))
	assert_false(_grasp.take(other))

func test_refuses_what_is_too_heavy():
	assert_false(_grasp.take(_item(ItemDefinition.Grip.CARRY, 60.0)))
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)

func test_taking_a_stowed_item_frees_its_point():
	var point := _point_at(Vector3(2, 0.5, 0))
	var item := _item()
	point.secure(item)
	assert_true(_grasp.take(item))
	assert_true(point.is_free())

func test_holding_ignores_the_holder():
	var item := _item()
	_grasp.take(item)
	assert_has(item.get_collision_exceptions(), _body)
	assert_has(_body.get_collision_exceptions(), item)

func test_drop_puts_either_kind_back_in_the_world():
	for grip in [ItemDefinition.Grip.WIELD, ItemDefinition.Grip.CARRY]:
		var item := _item(grip)
		_grasp.take(item)
		_grasp.drop()
		assert_eq(item.get_parent(), _world)
		assert_eq(item.state, Item.State.LOOSE)
		assert_eq(item.collision_layer, Item.LAYER)
		assert_eq(_grasp.mode, Grasp.Mode.EMPTY)

func test_the_exception_outlasts_the_drop_until_they_part():
	var item := _item()
	_grasp.take(item)
	_grasp.drop()
	item.global_position = _body.global_position + Vector3(0, 0.9, 0)
	await wait_physics_frames(5)
	assert_has(item.get_collision_exceptions(), _body, "still overlapping: no pop")
	item.global_position = Vector3(3, 1, 0)
	await wait_physics_frames(3)
	assert_does_not_have(item.get_collision_exceptions(), _body, "apart: solid again")

func test_the_exception_gives_up_after_a_second():
	var item := _item()
	_grasp.take(item)
	_grasp.drop()
	item.global_position = _body.global_position + Vector3(0, 0.9, 0)
	item.freeze = true
	await wait_physics_frames(70)
	assert_does_not_have(item.get_collision_exceptions(), _body)

func test_throw_speed_scales_with_charge_and_mass():
	assert_almost_eq(Grasp.throw_speed(0.3, 1.0), 12.0, 0.001)
	assert_almost_eq(Grasp.throw_speed(12.0, 1.0), 12.0 * sqrt(5.0 / 12.0), 0.001)
	assert_almost_eq(Grasp.throw_speed(60.0, 1.0), 12.0 * 0.35, 0.001)
	assert_almost_eq(Grasp.throw_speed(1.0, 0.0), 3.0, 0.001)
	assert_almost_eq(Grasp.throw_speed(1.0, 0.5), 7.5, 0.001)

func test_a_throw_goes_where_you_look():
	_head.rotation.y = PI * 0.5
	var item := _item()
	_grasp.take(item)
	_grasp.throw(1.0)
	assert_eq(item.state, Item.State.LOOSE)
	assert_almost_eq(item.linear_velocity, Vector3(-12, 0, 0), Vector3.ONE * 0.01)

func test_winding_up_charges_over_time():
	_grasp.take(_item())
	_grasp.begin_throw()
	await wait_physics_frames(24)
	assert_almost_eq(_grasp.charge, 0.5, 0.1)
	_grasp.finish_throw()
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)
	assert_eq(_grasp.charge, -1.0)

func test_third_person_refuses_use_and_throw():
	var item := _item(ItemDefinition.Grip.WIELD)
	_grasp.take(item)
	_grasp.first_person = false
	_grasp.begin_throw()
	assert_eq(_grasp.charge, -1.0)
	assert_false(_grasp.use())

func test_dropping_while_aiming_at_a_fitting_point_stows_either_kind():
	_add_box(Vector3(0, 1.6, -1.55), Vector3(4, 4, 0.1))
	await wait_physics_frames(2)
	for grip in [ItemDefinition.Grip.WIELD, ItemDefinition.Grip.CARRY]:
		var item := _item(grip)
		_grasp.take(item)
		var point := _point_at(Vector3(0, 1.5, -1.45))
		_grasp.drop()
		assert_eq(item.state, Item.State.STOWED)
		assert_eq(point.item, item)
		assert_does_not_have(item.get_collision_exceptions(), _body)
		point.release()
		point.free()

func test_dropping_far_from_a_point_just_drops():
	var item := _item()
	_grasp.take(item)
	_point_at(Vector3(5, 0, 5))
	_grasp.drop()
	assert_eq(item.state, Item.State.LOOSE)

func test_a_stow_prompt_appears_when_aiming_at_a_point():
	_add_box(Vector3(0, 1.6, -1.55), Vector3(4, 4, 0.1))
	_grasp.take(_item())
	await wait_physics_frames(2)
	watch_signals(_grasp)
	_point_at(Vector3(0, 1.5, -1.45))
	await wait_physics_frames(2)
	assert_signal_emitted_with_parameters(_grasp, "prompt_changed", [Grasp.STOW_PROMPT])

func test_disabling_sets_down_a_carried_item():
	var item := _item()
	_grasp.take(item)
	_grasp.set_enabled(false)
	assert_eq(_grasp.mode, Grasp.Mode.EMPTY)
	assert_eq(item.state, Item.State.LOOSE)

func test_disabling_keeps_a_wielded_item_but_will_not_use_it():
	var item := _item(ItemDefinition.Grip.WIELD)
	_grasp.take(item)
	_grasp.set_enabled(false)
	assert_eq(_grasp.mode, Grasp.Mode.WIELDING)
	assert_false(_grasp.use())

func test_either_kind_is_released_clear_of_a_wall():
	_add_box(Vector3(0, 1.6, -0.3), Vector3(2, 2, 0.05))
	await wait_physics_frames(2)
	for grip in [ItemDefinition.Grip.WIELD, ItemDefinition.Grip.CARRY]:
		var item := _item(grip, 1.0, Vector3(0, 1.3, 0.9))
		_grasp.take(item)
		_grasp.drop()
		assert_gt(item.global_position.z, -0.3, "on the near side of the wall")

func test_use_calls_the_items_use_and_announces_it():
	var item := _item(ItemDefinition.Grip.WIELD)
	var use := CountingUse.new()
	item.use_node = use
	item.add_child(use)
	_grasp.take(item)
	watch_signals(_grasp)
	assert_true(_grasp.use())
	assert_eq(use.count, 1)
	assert_signal_emitted(_grasp, "used")
