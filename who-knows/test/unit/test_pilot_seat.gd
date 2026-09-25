extends GutTest

## Getting up out of the pilot seat (cockpit pod spec §5), in the real scene:
## you stand up where your body fits, with room to walk away -- never wedged
## between the chair and the glass.

var _root: Node
var _interior: Node3D
var _avatar: Avatar
var _seat: PilotSeat
var _director: CameraDirector

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_interior = _root.get_node("Ship/Interior")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_seat = _root.get_node("Ship/Interior/PilotSeat")
	_director = _root.get_node("Ship/CameraDirector")
	# Let the scene run a frame or two, as it has by the time you reach the chair.
	await wait_process_frames(2)
	await wait_physics_frames(2)

func after_each():
	Input.action_release("move_back")

func _sit() -> void:
	_director.sit(_seat)
	await wait_for_signal(_director.transition_finished, 3)

func _stand() -> void:
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)

## Whatever your body is inside of, lifted clear of the floor it stands on.
func _overlaps() -> Array:
	var collider: CollisionShape3D = _avatar.get_node("Collider")
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = collider.shape
	q.transform = collider.global_transform.translated(Vector3.UP * 0.02)
	q.collision_mask = _avatar.collision_mask
	q.exclude = [_avatar.get_rid()]
	var out := []
	for hit in _avatar.get_world_3d().direct_space_state.intersect_shape(q, 8):
		out.append((hit["collider"] as Node).get_path())
	return out

## A solid block at one of the seat's stand-up spots.
func _block(spot: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 1.6, 0.5)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	body.add_child(shape)
	_interior.add_child(body)
	body.global_transform = _seat.global_transform * Transform3D(Basis.IDENTITY, spot)

func _in_seat_frame(p: Vector3) -> Vector3:
	return _seat.global_transform.affine_inverse() * p

func test_you_step_back_out_of_the_chair_and_can_walk_away():
	await _sit()
	await _stand()
	assert_eq(_overlaps(), [], "nothing in your way where you stand")
	assert_almost_eq(_in_seat_frame(_avatar.global_position), PilotSeat.STAND_SPOTS[0], Vector3.ONE * 0.01,
		"the room behind the chair is clear, so you step straight back")
	assert_gt((-_avatar.global_basis.z).dot(-_seat.global_basis.z), 0.99, "facing the way the chair does")
	var from := _avatar.global_position
	Input.action_press("move_back")
	await wait_physics_frames(30)
	Input.action_release("move_back")
	assert_gt(from.distance_to(_avatar.global_position), 1.0, "you walk away into the cabin")

func test_with_the_step_back_blocked_you_stand_somewhere_else_clear():
	_block(PilotSeat.STAND_SPOTS[0])
	await wait_physics_frames(2)
	await _sit()
	await _stand()
	assert_eq(_overlaps(), [], "nothing in your way where you stand")
	assert_gt(_in_seat_frame(_avatar.global_position).distance_to(PilotSeat.STAND_SPOTS[0]), 0.5)

func test_with_nowhere_clear_by_the_chair_you_stand_where_you_sat_from():
	for spot in PilotSeat.STAND_SPOTS:
		_block(spot)
	await wait_physics_frames(2)
	await _sit()
	var sat_from := _avatar.global_position
	await _stand()
	assert_almost_eq(_avatar.global_position, sat_from, Vector3.ONE * 0.01)
	assert_eq(_overlaps(), [], "nothing in your way where you stand")
