extends GutTest

## WeaponAim (ship weapons spec §5.2): where to fire so a bolt carried at the
## shooter's velocity meets a target holding its own.

func _meets(shooter: Vector3, shooter_v: Vector3, speed: float, target: Vector3, target_v: Vector3) -> void:
	var s := WeaponAim.intercept(shooter, shooter_v, speed, target, target_v)
	assert_false(s.is_empty(), "a solution")
	if s.is_empty():
		return
	var t: float = s["time"]
	var bolt := shooter + (shooter_v + (s["dir"] as Vector3) * speed) * t
	assert_almost_eq(bolt, target + target_v * t, Vector3.ONE * 0.01, "the bolt is where the target is")

func test_a_still_target_dead_ahead():
	var s := WeaponAim.intercept(Vector3.ZERO, Vector3.ZERO, 100.0, Vector3(0, 0, -500), Vector3.ZERO)
	assert_almost_eq(s["dir"], Vector3.FORWARD, Vector3.ONE * 0.0001)
	assert_almost_eq(s["time"], 5.0, 0.0001)

func test_a_crossing_target_is_led():
	var s := WeaponAim.intercept(Vector3.ZERO, Vector3.ZERO, 600.0, Vector3(0, 0, -600), Vector3(30, 0, 0))
	assert_gt((s["dir"] as Vector3).x, 0.0, "aimed ahead of it, to its right")
	_meets(Vector3.ZERO, Vector3.ZERO, 600.0, Vector3(0, 0, -600), Vector3(30, 0, 0))

func test_the_shooters_velocity_is_carried():
	var s := WeaponAim.intercept(Vector3.ZERO, Vector3(50, 0, 0), 600.0, Vector3(0, 0, -600), Vector3(50, 0, 0))
	assert_almost_eq(s["dir"], Vector3.FORWARD, Vector3.ONE * 0.0001, "flying alongside, aim straight at it")
	_meets(Vector3(10, 5, 0), Vector3(-20, 3, 1), 450.0, Vector3(200, -40, -900), Vector3(15, 10, -30))

func test_a_target_outrunning_the_bolt_has_no_solution():
	assert_eq(WeaponAim.intercept(Vector3.ZERO, Vector3.ZERO, 600.0, Vector3(0, 0, -100), Vector3(0, 0, -700)), {})

func test_a_target_at_the_muzzle_has_no_solution():
	assert_eq(WeaponAim.intercept(Vector3.ONE, Vector3.ZERO, 600.0, Vector3.ONE, Vector3.ZERO), {})

func test_every_turret_kind_has_every_number():
	for kind in WeaponValues.TURRET_IDS:
		var s := WeaponValues.spec(kind)
		for key in ["slew", "burst", "gap", "recharge", "speed", "damage", "life", "push", "range",
				"manned_range", "spread", "qe", "length", "thickness", "flash", "barrel"]:
			assert_true(s.has(key), "%s has %s" % [kind, key])
		assert_gt(float(s["speed"]) * float(s["life"]), float(s["manned_range"]), "%s's bolts reach its manned range" % kind)
