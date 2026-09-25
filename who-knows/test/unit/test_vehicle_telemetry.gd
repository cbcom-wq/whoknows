extends GutTest

## A basis yawed 90 degrees about +Y. Under it, world -Z maps to local +X.
func _yawed() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(90.0))

func test_speed_is_velocity_magnitude():
	var t := VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3.ZERO,
		Vector3(3.0, 0.0, 4.0), Vector3.ZERO,
		true, false, 120.0
	)
	assert_almost_eq(t.speed, 5.0, 0.001, "3-4-5 triangle")

func test_world_velocity_is_stored_unrotated():
	var v := Vector3(0.0, 0.0, -10.0)
	var t := VehicleTelemetry.from_state(
		_yawed(), Vector3.ZERO, v, Vector3.ZERO, true, false, 120.0
	)
	assert_almost_eq(t.world_velocity.z, -10.0, 0.001, "world velocity untouched")

func test_local_velocity_is_expressed_in_hull_basis():
	# Ship yawed 90 degrees, travelling along world -Z. In its own frame that
	# is straight out the left/right beam, not out the nose.
	var t := VehicleTelemetry.from_state(
		_yawed(), Vector3.ZERO,
		Vector3(0.0, 0.0, -10.0), Vector3.ZERO,
		true, false, 120.0
	)
	assert_almost_eq(t.local_velocity.z, 0.0, 0.001, "nothing along local Z")
	assert_almost_eq(t.local_velocity.x, 10.0, 0.001, "all of it across the beam, to local +X")

func test_local_angular_velocity_is_expressed_in_hull_basis():
	# Godot reports angular_velocity in the world frame. Rolling about the
	# hull's own nose axis must land on local Z regardless of hull attitude.
	var world_spin: Vector3 = _yawed() * Vector3(0.0, 0.0, 2.0)
	var t := VehicleTelemetry.from_state(
		_yawed(), Vector3.ZERO, Vector3.ZERO, world_spin, true, false, 120.0
	)
	assert_almost_eq(t.local_angular_velocity.z, 2.0, 0.001, "roll on local Z")
	assert_almost_eq(t.local_angular_velocity.x, 0.0, 0.001, "no pitch")
	assert_almost_eq(t.local_angular_velocity.y, 0.0, 0.001, "no yaw")

func test_flags_and_limit_pass_through():
	var t := VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3(1.0, 2.0, 3.0),
		Vector3.ZERO, Vector3.ZERO,
		false, true, 99.0
	)
	assert_false(t.assist_enabled, "assist off")
	assert_true(t.boost_active, "boost on")
	assert_almost_eq(t.cruise_limit, 99.0, 0.001, "limit carried, never hardcoded downstream")
	assert_eq(t.hull_origin, Vector3(1.0, 2.0, 3.0), "origin carried for projection")

## Flight controls spec §5.5, §7: anything that holds nothing reports nothing.
func test_holds_and_the_stick_start_off():
	var t := VehicleTelemetry.from_state(Basis.IDENTITY, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
		true, false, 120.0)
	assert_false(t.heading_hold)
	assert_false(t.speed_locked)
	assert_eq(t.locked_speed, 0.0)
	assert_false(t.pointing)
	assert_eq(t.stick, Vector2.ZERO)
	assert_eq(t.pointer, Vector2.ZERO)
