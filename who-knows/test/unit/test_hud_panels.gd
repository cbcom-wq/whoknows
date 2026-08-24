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

func test_velocity_panel_rects_ignore_the_mouse():
	# ColorRect defaults to MOUSE_FILTER_STOP and does not inherit its
	# parent's mouse_filter, so a code-built rect left at the default would
	# eat clicks meant for the world behind it -- even while fully faded out.
	var p := _velocity_panel()
	assert_eq(p.bar_track.mouse_filter, Control.MOUSE_FILTER_IGNORE, "bar track ignores the mouse")
	assert_eq(p.bar_fill.mouse_filter, Control.MOUSE_FILTER_IGNORE, "bar fill ignores the mouse")

func _spinning(pitch: float, yaw: float, roll: float) -> VehicleTelemetry:
	return VehicleTelemetry.from_state(
		Basis.IDENTITY, Vector3.ZERO,
		Vector3.ZERO, Vector3(pitch, yaw, roll),
		true, false, 120.0
	)

func _attitude_panel() -> AttitudePanel:
	var p := AttitudePanel.new()
	add_child_autofree(p)
	return p

func test_attitude_pips_centre_when_not_rotating():
	var p := _attitude_panel()
	p.render(_spinning(0.0, 0.0, 0.0))
	var centre := AttitudePanel.TRACK_WIDTH * 0.5 - p.pitch_pip.size.x * 0.5
	assert_almost_eq(p.pitch_pip.position.x, centre, 0.5, "pitch centred")
	assert_almost_eq(p.yaw_pip.position.x, centre, 0.5, "yaw centred")
	assert_almost_eq(p.roll_pip.position.x, centre, 0.5, "roll centred")

func test_attitude_pip_travels_right_at_full_positive_rate():
	var p := _attitude_panel()
	p.render(_spinning(AttitudePanel.DISPLAY_MAX_RAD, 0.0, 0.0))
	assert_almost_eq(
		p.pitch_pip.position.x, AttitudePanel.TRACK_WIDTH - p.pitch_pip.size.x * 0.5, 0.5,
		"full positive pitch pins right"
	)

func test_attitude_pip_travels_left_at_full_negative_rate():
	var p := _attitude_panel()
	p.render(_spinning(0.0, -AttitudePanel.DISPLAY_MAX_RAD, 0.0))
	assert_almost_eq(
		p.yaw_pip.position.x, -p.yaw_pip.size.x * 0.5, 0.5,
		"full negative yaw pins left"
	)

func test_attitude_pip_clamps_beyond_the_display_maximum():
	var p := _attitude_panel()
	p.render(_spinning(0.0, 0.0, AttitudePanel.DISPLAY_MAX_RAD * 10.0))
	assert_almost_eq(
		p.roll_pip.position.x, AttitudePanel.TRACK_WIDTH - p.roll_pip.size.x * 0.5, 0.5,
		"a wild tumble pins rather than leaving the panel"
	)

func test_attitude_reports_settled_when_rotation_is_negligible():
	var p := _attitude_panel()
	p.render(_spinning(0.001, 0.001, 0.001))
	assert_true(p.settled_label.visible, "settled shown")

func test_attitude_hides_settled_while_still_turning():
	var p := _attitude_panel()
	p.render(_spinning(0.5, 0.0, 0.0))
	assert_false(p.settled_label.visible, "not settled while pitching")

func test_attitude_ignores_a_null_snapshot():
	var p := _attitude_panel()
	p.render(_spinning(AttitudePanel.DISPLAY_MAX_RAD, 0.0, 0.0))
	var before := p.pitch_pip.position.x
	p.render(null)
	assert_almost_eq(p.pitch_pip.position.x, before, 0.5, "last good reading left alone")

func test_attitude_panel_rects_ignore_the_mouse():
	# Same defect as the velocity panel's bar: ColorRect defaults to
	# MOUSE_FILTER_STOP and mouse_filter is not inherited, so every track,
	# zero rule, and pip built in code needs it set explicitly.
	var p := _attitude_panel()
	for pip in [p.pitch_pip, p.yaw_pip, p.roll_pip]:
		assert_eq(pip.mouse_filter, Control.MOUSE_FILTER_IGNORE, "pip ignores the mouse")
		var track: ColorRect = pip.get_parent()
		assert_eq(track.mouse_filter, Control.MOUSE_FILTER_IGNORE, "track ignores the mouse")
