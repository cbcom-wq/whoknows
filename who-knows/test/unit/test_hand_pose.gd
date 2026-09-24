extends GutTest

## Hand poses and the glove (hands-and-items spec §8.2, §8.3).

func test_blend_is_exact_at_the_ends():
	var a := HandPose.relaxed()
	var b := HandPose.grip(true)
	var start := HandPose.blend(a, b, 0.0)
	var end := HandPose.blend(a, b, 1.0)
	assert_eq(start.curl, a.curl)
	assert_eq(end.curl, b.curl)
	assert_true(start.wrist.is_equal_approx(a.wrist))
	assert_true(end.wrist.is_equal_approx(b.wrist))

func test_blend_is_linear_between():
	var a := HandPose.make([0, 0, 0, 0], 0.0, 0.0, Transform3D.IDENTITY)
	var b := HandPose.make([1, 1, 1, 1], 1.0, 1.0, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1)))
	var mid := HandPose.blend(a, b, 0.5)
	assert_almost_eq(mid.curl[2], 0.5, 0.0001)
	assert_almost_eq(mid.thumb, 0.5, 0.0001)
	assert_almost_eq(mid.spread, 0.5, 0.0001)
	assert_almost_eq(mid.wrist.origin, Vector3(0, 0, -0.5), Vector3.ONE * 0.0001)

func test_mirroring_reflects_the_wrist_and_stays_a_rotation():
	var p := HandPose.relaxed()
	var m := p.mirrored()
	assert_almost_eq(m.wrist.origin, Vector3(-p.wrist.origin.x, p.wrist.origin.y, p.wrist.origin.z),
		Vector3.ONE * 0.0001)
	assert_almost_eq(m.wrist.basis.determinant(), 1.0, 0.0001)
	assert_true(m.mirrored().wrist.is_equal_approx(p.wrist))

func test_the_grip_puts_the_palm_on_the_socket():
	var pose := HandPose.grip(true)
	assert_almost_eq(pose.wrist * HandPose.PALM, HandPose.WIELD_SOCKET, Vector3.ONE * 0.0001)

func test_a_trigger_grip_leaves_the_index_finger_out():
	assert_lt(HandPose.grip(true).curl[0], HandPose.grip(false).curl[0])

func test_a_glove_has_ten_joints():
	var glove: Glove = autofree(Glove.new(1.0))
	assert_eq(glove.joint_count(), 10, "four two-joint fingers and a two-joint thumb")

func test_curling_bends_the_fingers_toward_the_palm():
	var glove := Glove.new(1.0)
	add_child_autofree(glove)
	glove.apply(HandPose.make([0, 0, 0, 0], 0.0, 0.0, Transform3D.IDENTITY))
	var tip_straight: Vector3 = glove.find_child("Joint1", true, false).global_position
	glove.apply(HandPose.make([1, 1, 1, 1], 0.0, 0.0, Transform3D.IDENTITY))
	var tip_curled: Vector3 = glove.find_child("Joint1", true, false).global_position
	assert_lt(tip_curled.y, tip_straight.y - 0.02, "palm side is -y")

func test_the_left_glove_mirrors_the_right():
	var right := Glove.new(1.0)
	var left := Glove.new(-1.0)
	add_child_autofree(right)
	add_child_autofree(left)
	var pose := HandPose.reach()
	right.apply(pose)
	left.apply(pose.mirrored())
	var r: Array = right.find_children("Joint*", "Node3D", true, false)
	var l: Array = left.find_children("Joint*", "Node3D", true, false)
	assert_eq(r.size(), l.size())
	for i in r.size():
		var a: Vector3 = r[i].global_position
		var b: Vector3 = l[i].global_position
		assert_almost_eq(b, Vector3(-a.x, a.y, a.z), Vector3.ONE * 0.0001)

func test_gloves_draw_on_the_interior_layer():
	var glove: Glove = autofree(Glove.new(1.0))
	var meshes := glove.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 10)
	for mi in meshes:
		assert_eq(mi.layers, 2)
