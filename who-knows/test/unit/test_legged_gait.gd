extends GutTest

## The tripod gait (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §13.4): three feet down at all times, feet never far from home, no rays
## far from a camera.

var _floor: StaticBody3D

func before_each():
	_floor = StaticBody3D.new()
	_floor.collision_layer = AsteroidBody.LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	cs.shape = box
	_floor.add_child(cs)
	add_child_autofree(_floor)
	_floor.global_position = Vector3(0, -0.5, 0)

func test_the_tripods_take_turns_and_three_feet_stay_down():
	await wait_physics_frames(2)
	var gait := LeggedGait.new(SkitterLook.FEET)
	var space := _floor.get_world_3d().direct_space_state
	var body := Transform3D.IDENTITY
	var turns := {}
	for i in 240:
		body.origin += Vector3(0, 0, -1.2 / 60.0)
		gait.update(body, 1.2, 1.0 / 60.0, space, [], AsteroidBody.LAYER)
		var up := gait.lifted()
		assert_true(up.size() <= 3, "at most three feet up")
		if not up.is_empty():
			var tripod := LeggedGait.TRIPODS[up[0]]
			for leg in up:
				assert_eq(LeggedGait.TRIPODS[leg], tripod, "only one tripod steps at a time")
			turns[tripod] = true
		for leg in SkitterLook.FEET.size():
			assert_lt(gait.feet[leg].distance_to(body * SkitterLook.FEET[leg]), 0.45, "foot %d stays near home" % leg)
	assert_eq(turns.size(), 2, "both tripods stepped")

func test_far_from_a_camera_it_casts_no_rays():
	var gait := LeggedGait.new(SkitterLook.FEET)
	var body := Transform3D.IDENTITY
	for i in 60:
		body.origin += Vector3(0, 0, -0.02)
		gait.update(body, 1.2, 1.0 / 60.0, null, [], AsteroidBody.LAYER)
	assert_eq(gait.rays, 0)
