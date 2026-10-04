extends GutTest

## WarpArrival (docs/superpowers/specs/2026-10-02-ship-library-design.md §6):
## where the hull goes, what it is while it arrives, and what it leaves
## behind. A bare body with one box stands in for a hull; each arrival is
## stepped by hand.

const STEP := 1.0 / 60.0

var _hull: RigidBody3D
var _spot: Transform3D

func before_each():
	_hull = _body()
	add_child_autofree(_hull)
	_spot = Transform3D(Basis(Vector3.UP, 0.4), Vector3(50, -20, 300))

func _body() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = 5
	body.collision_mask = 7
	body.gravity_scale = 0.0
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 3, 16)
	mesh.mesh = box
	body.add_child(mesh)
	return body

func _play(end_velocity := Vector3.ZERO) -> WarpArrival:
	var a := WarpArrival.play(_hull, _spot, end_velocity)
	a.set_physics_process(false)
	return a

func _run(a: WarpArrival, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001 and is_instance_valid(a):
		a._physics_process(STEP)
		t += STEP

func test_it_starts_from_back_along_the_nose():
	_play()
	assert_almost_eq(_hull.global_position, _spot.origin + _spot.basis.z * WarpArrival.FROM, Vector3.ONE * 0.01)
	assert_almost_eq(_hull.global_basis.z, _spot.basis.z, Vector3.ONE * 0.0001, "already facing its way")

func test_most_of_the_way_goes_in_the_first_third():
	assert_lt(WarpArrival.distance_at(WarpArrival.DURATION / 3.0), WarpArrival.FROM * 0.3)
	assert_eq(WarpArrival.distance_at(WarpArrival.DURATION), 0.0)

func test_it_ends_exactly_at_the_spot_moving_as_asked():
	var a := _play(Vector3(0, 0, -120))
	_run(a, WarpArrival.DURATION + 0.05)
	assert_almost_eq(_hull.global_position, _spot.origin, Vector3.ONE * 0.001)
	assert_almost_eq(_hull.global_basis.z, _spot.basis.z, Vector3.ONE * 0.0001)
	assert_eq(_hull.linear_velocity, Vector3(0, 0, -120))
	assert_eq(_hull.angular_velocity, Vector3.ZERO)

func test_its_layer_mask_and_freeze_come_back():
	var a := _play()
	_run(a, WarpArrival.DURATION + 0.05)
	assert_eq(_hull.collision_layer, 5)
	assert_eq(_hull.collision_mask, 7)
	assert_false(_hull.freeze)
	assert_eq(_hull.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)

func test_it_is_ghosted_all_the_way_in():
	var a := _play()
	while a.elapsed < WarpArrival.DURATION - STEP * 1.5:
		assert_eq(_hull.collision_layer, 0)
		assert_eq(_hull.collision_mask, 0)
		assert_true(_hull.freeze)
		assert_eq(_hull.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)
		a._physics_process(STEP)

func test_arrived_fires_once_at_the_stop():
	var a := _play()
	watch_signals(a)
	_run(a, WarpArrival.DURATION - 0.1)
	assert_signal_not_emitted(a, "arrived")
	_run(a, 0.2)
	assert_signal_emit_count(a, "arrived", 1)
	_run(a, WarpArrival.FLASH_TIME * 0.5)
	assert_signal_emit_count(a, "arrived", 1)

func test_it_counts_as_arriving_until_it_stops():
	var a := _play()
	assert_same(WarpArrival.of(_hull), a)
	_run(a, WarpArrival.DURATION + 0.05)
	assert_null(WarpArrival.of(_hull), "its flash still fades, but it has arrived")

func test_the_wake_is_long_while_fast_and_gone_at_the_stop():
	var a := _play()
	_run(a, 0.1)
	var wake := a.get_child(0) as MeshInstance3D
	assert_true(wake.visible)
	assert_gt(wake.scale.z, 100.0, "hundreds of metres long at the start")
	_run(a, WarpArrival.DURATION - 0.15)
	assert_lt(wake.scale.z, 10.0, "a few metres as it eases onto the spot")
	_run(a, 0.1)
	assert_false(wake.visible, "none once it has stopped")

func test_the_wake_and_flash_are_gone_after():
	var a := _play()
	_run(a, WarpArrival.DURATION + WarpArrival.FLASH_TIME + 0.05)
	await wait_process_frames(1)
	assert_false(is_instance_valid(a))
	assert_eq(_hull.find_children("*", "MeshInstance3D", true, false).size(), 1, "only its own box")

func test_a_shift_mid_arrival_carries_the_spot():
	var a := _play()
	_run(a, 0.5)
	# What Universe.shift does to a hull in EXTERIOR_SPACE.
	_hull.global_position -= Vector3(1000, 0, 0)
	_run(a, WarpArrival.DURATION)
	assert_almost_eq(_hull.global_position, _spot.origin - Vector3(1000, 0, 0), Vector3.ONE * 0.001)

func test_a_hull_freed_mid_arrival_takes_it_along():
	var body := _body()
	add_child(body)
	var a := WarpArrival.play(body, _spot)
	a.set_physics_process(false)
	a._physics_process(0.3)
	body.free()
	assert_false(is_instance_valid(a))
