extends GutTest

## MotionCoupling drives the felt-gravity field from exactly the numbers it
## shoves the avatar with (hands-and-items spec §6).

var _root: Node

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)

func test_the_interior_builder_path_survived_the_parse():
	var mc: MotionCoupling = _root.get_node("Ship/MotionCoupling")
	assert_eq(mc.interior_builder_path, NodePath("../Interior/InteriorBuilder"))

func test_felt_gravity_is_plating_plus_the_avatars_shove():
	var mc: MotionCoupling = _root.get_node("Ship/MotionCoupling")
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var builder: InteriorBuilder = _root.get_node("Ship/Interior/InteriorBuilder")
	mc.drive_felt_gravity(Vector3(0, 0, 3))
	assert_almost_eq(builder.felt_gravity.felt, Vector3.DOWN * avatar.grav_strength + Vector3(0, 0, 3),
		Vector3.ONE * 0.0001)
