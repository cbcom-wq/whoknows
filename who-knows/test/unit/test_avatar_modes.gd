extends GutTest

## The avatar aboard and on a spacewalk (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §7.4, §8), in the real scene.

const DT := 1.0 / 60.0

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _outside: Node3D

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_outside = _root.get_node("Outside")

func _layers_of_hands() -> Array:
	var out := []
	for g in _avatar.hands.find_children("*", "GeometryInstance3D", true, false):
		out.append(g.layers)
	return out

func _out() -> void:
	_avatar.enter_suit(_outside, Transform3D(Basis(Vector3.UP, 0.3), Vector3(5, 2, 10)), Vector3(1, 0, 0), _ship.exterior)

func test_aboard_you_walk_the_ship():
	assert_eq(_avatar.mode, Avatar.Mode.PLATING)
	assert_eq(_avatar.get_parent(), _ship.interior)
	assert_eq(_avatar.motion_mode, CharacterBody3D.MOTION_MODE_GROUNDED)
	assert_eq(_avatar.collision_mask, Avatar.COLLISION_MASK)

func test_the_suit_takes_you_outside():
	_out()
	assert_eq(_avatar.mode, Avatar.Mode.SUIT)
	assert_eq(_avatar.get_parent(), _outside)
	assert_true(_avatar.global_transform.is_equal_approx(Transform3D(Basis(Vector3.UP, 0.3), Vector3(5, 2, 10))))
	assert_eq(_avatar.velocity, Vector3(1, 0, 0))
	assert_eq(_avatar.motion_mode, CharacterBody3D.MOTION_MODE_FLOATING)
	assert_eq(_avatar.collision_mask, Avatar.SUIT_MASK, "your own hull, and items")
	assert_eq(_avatar.interactor.collision_mask, Interactor.SUIT_MASK, "the hull panel")
	assert_null(_avatar.camera.environment, "the world's look")
	assert_true(_avatar.camera.current, "still your view")
	assert_true(_avatar.grasp.suspended, "hands idle, but still holding")
	for layer in _layers_of_hands():
		assert_eq(layer, 1, "lit by the sun, not the cabin")

func test_coming_back_puts_everything_back():
	var mood := _avatar.camera.environment
	_out()
	var pose := Transform3D(Basis.IDENTITY, _ship.interior.to_global(Vector3(0, -0.95, 6)))
	var tilt := Quaternion(Vector3.FORWARD, 0.5)
	_avatar.enter_plating(_ship.interior, pose, 0.2, Vector3(0, 0, -1), tilt)
	assert_eq(_avatar.mode, Avatar.Mode.PLATING)
	assert_eq(_avatar.get_parent(), _ship.interior)
	assert_eq(_avatar.motion_mode, CharacterBody3D.MOTION_MODE_GROUNDED)
	assert_eq(_avatar.collision_mask, Avatar.COLLISION_MASK)
	assert_eq(_avatar.interactor.collision_mask, Interactor.MASK)
	assert_same(_avatar.camera.environment, mood, "the cabin's mood again")
	assert_false(_avatar.grasp.suspended)
	assert_almost_eq(_avatar.head.rotation.x, 0.2, 0.0001)
	for layer in _layers_of_hands():
		assert_eq(layer, InteriorKit.LAYER)
	assert_true(_avatar.camera.quaternion.is_equal_approx(tilt), "the view starts where it was")
	_avatar.tick_righting(Avatar.RIGHTING_TIME + 0.05)
	assert_true(_avatar.camera.quaternion.is_equal_approx(Quaternion.IDENTITY), "and rights itself")

func test_the_suit_moves_you_by_thrust_not_gravity():
	_out()
	_avatar.velocity = Vector3.ZERO
	_ship.exterior.linear_velocity = Vector3.ZERO
	_avatar.suit_assist = false
	_avatar.suit_step(DT, Vector3.ZERO)
	assert_eq(_avatar.velocity, Vector3.ZERO, "no gravity out here")
	_avatar.suit_step(DT, Vector3(0, 0, -1))
	var forward := -_avatar.head.global_basis.z
	assert_almost_eq(_avatar.velocity, forward * Suit.ACCEL * DT, Vector3.ONE * 0.0001)
	assert_true(_avatar.thrusting)

func test_the_suit_assist_holds_you_to_your_drifting_ship():
	_out()
	_ship.exterior.linear_velocity = Vector3(2, 0, 0)
	_ship.exterior.angular_velocity = Vector3.ZERO
	_avatar.velocity = Vector3.ZERO
	for i in 90:
		_avatar.suit_step(DT, Vector3.ZERO)
	assert_almost_eq(_avatar.velocity, Vector3(2, 0, 0), Vector3.ONE * 0.001)

func test_you_cannot_take_the_seat_from_outside():
	_out()
	var director: CameraDirector = _root.get_node("Ship/CameraDirector")
	director.sit(_root.get_node("Ship/Interior/PilotSeat"))
	assert_false(director.is_seated)

func test_the_ship_does_not_shove_a_spacewalker():
	_out()
	_avatar.external_accel = Vector3.ZERO
	var coupling: MotionCoupling = _root.get_node("Ship/MotionCoupling")
	_ship.exterior.linear_velocity = Vector3(0, 0, -30)
	coupling._physics_process(DT)
	assert_eq(_avatar.external_accel, Vector3.ZERO)

## Floating in tilted, your body lands clear of the frame, but your view
## starts exactly where your eye was and eases to your head.
func test_coming_back_the_view_eases_from_where_your_eye_was():
	_out()
	var pose := Transform3D(Basis.IDENTITY, _ship.interior.to_global(Vector3(0, -0.95, 6.5)))
	var eye := _ship.interior.to_global(Vector3(0.6, 0.3, 6.95))
	_avatar.enter_plating(_ship.interior, pose, 0.0, Vector3.ZERO, Quaternion.IDENTITY, eye)
	assert_almost_eq(_avatar.camera.global_position, eye, Vector3.ONE * 0.001, "no jump")
	_avatar.tick_righting(Avatar.RIGHTING_TIME + 0.05)
	assert_almost_eq(_avatar.camera.global_position, _avatar.head.global_position, Vector3.ONE * 0.001,
		"and home at your head")

