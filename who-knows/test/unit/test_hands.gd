extends GutTest

## The first-person hands (hands-and-items spec §8, as amended 2026-09-24):
## worn under the avatar's camera, holding what Grasp holds, swiping it in when
## taken, tucked away from walls, kicked by recoil.

var _world: Node3D
var _avatar: Avatar

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_avatar = load("res://scenes/avatar.tscn").instantiate()
	_world.add_child(_avatar)
	_avatar.grasp.world_root = _world
	_avatar.set_physics_process(false)

func _item(grip: ItemDefinition.Grip, use: Script = null) -> Item:
	var d := ItemDefinition.new()
	d.id = &"thing"
	d.display_name = "Thing"
	d.size = Vector3(0.3, 0.2, 0.2)
	d.grip = grip
	d.look = &"crate"
	d.use = use
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = Vector3(0, 1.3, -1)
	item.set_loose()
	return item

func test_the_avatar_wears_hands_under_its_camera():
	assert_not_null(_avatar.hands)
	assert_eq(_avatar.hands.get_parent(), _avatar.camera)

func test_wielded_things_go_into_the_hands():
	assert_eq(_avatar.grasp.wield_socket, _avatar.hands.wield_socket)

func test_carried_things_go_between_the_hands():
	assert_eq(_avatar.grasp.carry_socket, _avatar.hands.carry_socket)
	assert_almost_eq(_avatar.hands.carry_socket.position, HandPose.CARRY_SOCKET, Vector3.ONE * 0.0001)

func test_hiding_the_hands_hides_what_they_hold():
	var item := _item(ItemDefinition.Grip.WIELD)
	_avatar.take_item(item)
	_avatar.hands.shown = false
	assert_false(item.is_visible_in_tree())
	_avatar.hands.shown = true
	assert_true(item.is_visible_in_tree())

func test_empty_hands_relax():
	assert_eq(_avatar.hands.target_poses()[0].curl, HandPose.relaxed().curl)

func _after_the_swipe() -> void:
	await wait_seconds(Hands.GRAB_TIME + 0.05)

func test_a_trigger_grip_for_a_usable_item():
	_avatar.take_item(_item(ItemDefinition.Grip.WIELD, load("res://src/items/item_use.gd")))
	await _after_the_swipe()
	assert_eq(_avatar.hands.target_poses()[0].curl, HandPose.grip(true).curl)

func test_a_full_grip_for_a_plain_one():
	_avatar.take_item(_item(ItemDefinition.Grip.WIELD))
	await _after_the_swipe()
	assert_eq(_avatar.hands.target_poses()[0].curl, HandPose.grip(false).curl)

func test_both_hands_carry():
	_avatar.take_item(_item(ItemDefinition.Grip.CARRY))
	await _after_the_swipe()
	var poses := _avatar.hands.target_poses()
	assert_eq(poses[0].curl, HandPose.carry(0.3, 0.2).curl)
	assert_almost_eq(poses[1].wrist.origin.x, -poses[0].wrist.origin.x, 0.0001, "the left mirrors the right")

func test_tuck_retracts_in_front_of_a_wall_and_not_in_open_space():
	await wait_physics_frames(2)
	assert_eq(_avatar.hands.tuck_amount(), 0.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.global_position = _avatar.camera.global_position + Vector3(0, 0, -0.4)
	await wait_physics_frames(2)
	assert_gt(_avatar.hands.tuck_amount(), 0.5)

func test_a_shot_kicks_the_right_hand_back():
	var item := _item(ItemDefinition.Grip.WIELD)
	_avatar.take_item(item)
	await _after_the_swipe()
	_avatar.grasp.used.emit(item)
	assert_eq(_avatar.hands.recoil, 1.0)
	await wait_process_frames(2)
	assert_gt(_avatar.hands.get_node("Root/RightMount").position.z, 0.0)

func test_a_grab_swipes_the_item_into_the_hand():
	var item := _item(ItemDefinition.Grip.WIELD)
	item.global_position = _avatar.camera.global_position + Vector3(0.5, -0.6, -1.2)
	var start := item.global_position
	_avatar.take_item(item)
	# Where Grasp puts a one-handed item: its grip point on the socket.
	var rest := Transform3D(Basis.IDENTITY, -item.definition.grip_point)
	await wait_seconds(Hands.GRAB_TIME * 0.4)
	assert_true(_avatar.hands.grabbing(), "mid-swipe")
	var rest_global: Vector3 = (item.get_parent() as Node3D).global_transform * rest.origin
	assert_gt(item.global_position.distance_to(start), 0.001, "it has left its spot")
	assert_gt(item.global_position.distance_to(rest_global), 0.02, "and is not in the hand yet")
	await _after_the_swipe()
	assert_false(_avatar.hands.grabbing())
	assert_true(item.transform.is_equal_approx(rest), "settled in the hand")

func test_the_hand_reaches_out_during_the_swipe():
	var item := _item(ItemDefinition.Grip.WIELD)
	item.global_position = _avatar.camera.global_position + Vector3(0.3, -0.3, -1.5)
	_avatar.take_item(item)
	await wait_seconds(Hands.GRAB_TIME * 0.4)
	assert_gt(_avatar.hands.get_node("Root/RightMount").position.length(), 0.05, "reaching")
	await _after_the_swipe()
	assert_almost_eq(_avatar.hands.get_node("Root/RightMount").position, Vector3.ZERO, Vector3.ONE * 0.001)

func test_dropping_mid_swipe_leaves_the_item_alone():
	var item := _item(ItemDefinition.Grip.WIELD)
	_avatar.take_item(item)
	await wait_process_frames(2)
	_avatar.grasp.drop()
	var dropped_at := item.global_position
	await wait_process_frames(3)
	assert_false(_avatar.hands.grabbing())
	assert_almost_eq(item.global_position, dropped_at, Vector3.ONE * 0.05, "the swipe let go of it")
