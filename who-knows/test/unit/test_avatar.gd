extends GutTest

## The avatar with hands (hands-and-items spec §7, §12): it owns a Grasp,
## collides with items, nudges loose ones, and a click that re-captures the
## mouse goes no further.

var _world: Node3D
var _avatar: Avatar

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	var floor := StaticBody3D.new()
	floor.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0, -0.1, 0)
	floor.add_child(shape)
	_world.add_child(floor)
	_avatar = load("res://scenes/avatar.tscn").instantiate()
	_world.add_child(_avatar)
	_avatar.grasp.world_root = _world

func after_each():
	Input.action_release(&"move_forward")

func _crate(at: Vector3) -> Item:
	var d := ItemDefinition.new()
	d.id = &"crate"
	d.display_name = "Crate"
	d.mass_kg = 12.0
	d.size = Vector3(0.45, 0.35, 0.35)
	d.look = &"crate"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_loose()
	return item

func test_the_avatar_owns_a_grasp():
	assert_not_null(_avatar.grasp)
	assert_eq(_avatar.grasp.get_parent(), _avatar)

func test_the_avatar_collides_with_items():
	assert_eq(_avatar.collision_mask, 2 | 32)

func test_plating_gravity_is_unchanged():
	assert_eq(_avatar.grav_strength, 9.8)

func test_taking_goes_through_the_grasp():
	var item := _crate(Vector3(0, 1.2, -1))
	assert_true(_avatar.can_take_item(item))
	_avatar.take_item(item)
	assert_eq(_avatar.grasp.item, item)
	assert_false(_avatar.can_take_item(_crate(Vector3(2, 1.2, -1))), "hands full")

func test_disabling_control_sets_down_a_carried_item():
	var item := _crate(Vector3(0, 1.2, -1))
	_avatar.take_item(item)
	_avatar.set_control_enabled(false)
	assert_eq(item.state, Item.State.LOOSE)

func test_walking_into_a_loose_crate_nudges_it():
	var crate := _crate(Vector3(0, 0.18, -0.9))
	await wait_physics_frames(10)
	Input.action_press(&"move_forward")
	await wait_physics_frames(40)
	Input.action_release(&"move_forward")
	assert_lt(crate.global_position.z, -1.0, "pushed ahead")

func test_the_click_that_recaptures_the_mouse_goes_no_further():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_avatar._unhandled_input(click)
	assert_true(get_viewport().is_input_handled())
