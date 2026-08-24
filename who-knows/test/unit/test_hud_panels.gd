extends GutTest

func _telemetry(speed: float, limit: float, assist: bool, boost: bool) -> VehicleTelemetry:
	return VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3.ZERO,
		Vector3(0.0, 0.0, -speed), Vector3.ZERO,
		assist, boost, limit
	)

func _velocity_panel() -> VelocityPanel:
	var p := VelocityPanel.new()
	add_child_autofree(p)
	return p

func test_velocity_panel_shows_rounded_speed():
	var p := _velocity_panel()
	p.render(_telemetry(87.4, 120.0, true, false))
	assert_eq(p.speed_label.text, "87", "speed rounded to whole m/s")

func test_velocity_panel_bar_fills_proportionally():
	var p := _velocity_panel()
	p.render(_telemetry(60.0, 120.0, true, false))
	assert_almost_eq(
		p.bar_fill.size.x, p.bar_track.size.x * 0.5, 0.5,
		"half the ceiling fills half the bar"
	)

func test_velocity_panel_bar_is_cyan_below_the_amber_threshold():
	var p := _velocity_panel()
	p.render(_telemetry(100.0, 120.0, true, false))
	assert_eq(p.bar_fill.color, HudPalette.READOUT, "100 of 120 is under 90 percent")

func test_velocity_panel_bar_goes_amber_at_the_threshold():
	var p := _velocity_panel()
	p.render(_telemetry(108.0, 120.0, true, false))
	assert_eq(p.bar_fill.color, HudPalette.WARNING, "exactly 90 percent warns")

func test_velocity_panel_pins_the_bar_over_the_ceiling():
	# Assist off removes the cruise clamp, so speed can exceed the ceiling.
	var p := _velocity_panel()
	p.render(_telemetry(200.0, 120.0, false, false))
	assert_almost_eq(p.bar_fill.size.x, p.bar_track.size.x, 0.5, "bar pins full")
	assert_eq(p.bar_fill.color, HudPalette.WARNING, "and warns")

func test_velocity_panel_shows_mode_flags():
	var p := _velocity_panel()
	p.render(_telemetry(10.0, 120.0, false, true))
	assert_string_contains(p.mode_label.text, "ASSIST OFF")
	assert_string_contains(p.mode_label.text, "BOOST ON")

func test_velocity_panel_ignores_a_null_snapshot():
	var p := _velocity_panel()
	p.render(_telemetry(87.0, 120.0, true, false))
	p.render(null)
	assert_eq(p.speed_label.text, "87", "last good reading is left alone")

func test_velocity_panel_survives_a_zero_ceiling():
	# A vehicle with no cruise limit must not divide by zero.
	var p := _velocity_panel()
	p.render(_telemetry(50.0, 0.0, false, false))
	assert_almost_eq(p.bar_fill.size.x, 0.0, 0.5, "no ceiling means no meaningful fill")
