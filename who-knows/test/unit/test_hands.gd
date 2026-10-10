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
	var item := _item(ItemDefinition.Grip.WIELD, load("res://src/items/plasma_emitter.gd"))
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

func test_using_something_that_does_not_kick_leaves_the_hand_still():
	var item := _item(ItemDefinition.Grip.WIELD, load("res://src/items/item_use.gd"))
	_avatar.take_item(item)
	await _after_the_swipe()
	_avatar.grasp.used.emit(item)
	assert_eq(_avatar.hands.recoil, 0.0)

## --- the swipe's frame -------------------------------------------------------
## What a swipe starts from is where the item sat. Outside, that is on a hull
## that drifts and in a world that the floating origin shifts (CLAUDE.md), so
## it is kept relative to you, who are moved by both; aboard, the interior never
## moves and it is the world's own place.

var _universe: Universe
var _hull: Node3D

func _nozzle_def() -> ItemDefinition:
	var d := ItemDefinition.new()
	d.id = &"test_nozzle"
	d.display_name = "Nozzle"
	d.mass_kg = 1.0
	d.size = Vector3(0.1, 0.1, 0.3)
	d.grip = ItemDefinition.Grip.WIELD
	d.stow_class = &"hose"
	d.look = &"spanner"
	d.eva_tool = true
	return d

## Out on a spacewalk beside a reel on a hull (a floating-origin member), its
## nozzle a metre or so ahead of the eye and below it: on a spacewalk an EVA
## tool may be taken and nothing else.
func _go_out_beside_a_reel() -> HoseReel:
	_universe = Universe.new()
	add_child_autofree(_universe)
	_universe.set_physics_process(false)
	_hull = Node3D.new()
	_hull.add_to_group(Universe.EXTERIOR_SPACE)
	_world.add_child(_hull)
	_avatar.enter_suit(_world, Transform3D.IDENTITY, Vector3.ZERO, null)
	var reel := HoseReel.new()
	_hull.add_child(reel)
	reel.global_position = _avatar.camera.global_position + Vector3(0.5, -0.65, -1.2)
	reel.stock_nozzle(_nozzle_def())
	return reel

## Takes the nozzle off the reel and runs the grab swipe by hand, 60 steps a
## second, you and the hull both drifting by `drift` (m/s, engine frame) and,
## from step `shift_at` (never if negative), a floating-origin shift of 2 km.
## Returns how much farther than where it began the nozzle ever was from where
## it settles in the hand: a swipe only ever closes on the hand, so 0 or less.
func _swipe_on_a_spacewalk(drift: Vector3, shift_at := -1) -> float:
	var nozzle := _go_out_beside_a_reel().item
	assert_true(_avatar.grasp.take(nozzle), "an EVA tool may be taken on a spacewalk")
	var socket := _avatar.hands.wield_socket
	var rest := -nozzle.definition.grip_point
	var began := nozzle.global_position.distance_to(socket.global_transform * rest)
	var worst := 0.0
	var step := 0
	while _avatar.hands.grabbing() and step < 40:
		_hull.global_position += drift / 60.0
		_avatar.global_position += drift / 60.0
		if step == shift_at:
			_universe.shift(Vector3(2000, 0, 0))
		simulate(_avatar.hands, 1, 1.0 / 60.0)
		worst = maxf(worst, nozzle.global_position.distance_to(socket.global_transform * rest))
		step += 1
	assert_false(_avatar.hands.grabbing(), "the swipe ended")
	assert_eq(nozzle.get_parent(), socket)
	assert_true(nozzle.transform.is_equal_approx(Transform3D(Basis.IDENTITY, rest)), "settled in the hand")
	return worst - began

func test_the_grab_swipe_keeps_its_frame_across_a_shift_and_a_drift():
	var excess := _swipe_on_a_spacewalk(Vector3(0, 0, 10), 9)
	assert_lt(excess, 0.05, "the nozzle strayed %.2f m past where it began" % excess)

func test_the_grab_swipe_keeps_its_frame_on_a_drifting_hull():
	var excess := _swipe_on_a_spacewalk(Vector3(0, 0, 10))
	assert_lt(excess, 0.05, "the nozzle strayed %.2f m past where it began" % excess)

func test_the_grab_swipe_keeps_its_frame_across_a_shift():
	var excess := _swipe_on_a_spacewalk(Vector3.ZERO, 9)
	assert_lt(excess, 0.05, "the nozzle strayed %.2f m past where it began" % excess)

## Aboard, the swipe is as it always was: it starts where the item sat, and a
## walk (3 m here) does not carry that spot with you.
func test_aboard_the_swipe_still_starts_where_the_item_sat_even_if_you_walk():
	var item := _item(ItemDefinition.Grip.WIELD)
	item.global_position = _avatar.camera.global_position + Vector3(0.5, -0.6, -1.2)
	var sat := item.global_position
	_avatar.take_item(item)
	_avatar.global_position += Vector3(0, 0, 3)
	simulate(_avatar.hands, 1, 1.0 / 60.0)
	assert_true(_avatar.hands.grabbing())
	assert_lt(item.global_position.distance_to(sat), 0.2, "one step in, still about where it sat")
