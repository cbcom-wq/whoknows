extends GutTest

var _door: SlidingDoor

func before_each():
	_door = SlidingDoor.new()
	_door.setup(1.0, 1.9)
	add_child_autofree(_door)

func _body() -> Node3D:
	return autofree(Node3D.new())

func test_setup_builds_two_leaves_and_a_trigger():
	var trigger := _door.get_node_or_null("Trigger") as Area3D
	assert_not_null(trigger)
	assert_eq(trigger.collision_layer, 0, "the trigger is detected by nothing")
	assert_eq(trigger.collision_mask, SlidingDoor.AVATAR_MASK, "and detects the avatar")
	assert_eq(_door.leaf_positions().size(), 2)

func test_closed_leaves_meet_in_the_middle():
	assert_false(_door.is_open)
	var p := _door.leaf_positions()
	assert_almost_eq(p[0].x, -0.25, 0.001)
	assert_almost_eq(p[1].x, 0.25, 0.001)

func test_open_leaves_are_inside_the_jambs():
	_door.set_open(true, false)
	var p := _door.leaf_positions()
	assert_almost_eq(p[0].x, -0.75, 0.001, "a 0.5 m leaf centred 0.75 m out spans 0.5 to 1.0")
	assert_almost_eq(p[1].x, 0.75, 0.001)

func test_opens_when_someone_walks_up():
	_door._on_body_entered(_body())
	assert_true(_door.is_open)

func test_stays_open_until_the_last_one_leaves():
	var a := _body()
	var b := _body()
	_door._on_body_entered(a)
	_door._on_body_entered(b)
	_door._on_body_exited(a)
	assert_true(_door.is_open, "someone is still in the doorway")
	_door._on_body_exited(b)
	assert_false(_door.is_open)

func test_the_door_itself_is_never_solid():
	var shapes := _door.find_children("*", "CollisionShape3D", true, false)
	assert_eq(shapes.size(), 1, "only the trigger's shape")
	assert_true(shapes[0].get_parent() is Area3D)
