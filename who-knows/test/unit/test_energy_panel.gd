extends GutTest

## EnergyPanel (quantum energy spec §12): the ship's store, seated -- the
## numeral, the bar with its low-power notch, and the status line beneath
## for whatever the vehicle needs to add.

var _panel: EnergyPanel

func before_each():
	_panel = EnergyPanel.new()
	add_child_autofree(_panel)

func _telemetry(energy: int, capacity: int, line: int, state: StringName,
		tool_text := "", boost_refused := false) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	t.has_energy = true
	t.energy = energy
	t.energy_capacity = capacity
	t.energy_line = line
	t.energy_label = &"QE"
	t.energy_state = state
	t.tool_text = tool_text
	t.boost_refused = boost_refused
	return t

func test_hidden_with_no_telemetry():
	_panel.render(null)
	assert_false(_panel.visible)

func test_hidden_when_the_vehicle_has_no_energy_readout():
	# The default VehicleTelemetry, as an unwired vehicle would report.
	_panel.render(VehicleTelemetry.new())
	assert_false(_panel.visible)

func test_shows_the_store_and_a_half_full_bar():
	_panel.render(_telemetry(600, 1200, 120, &"full"))
	assert_true(_panel.visible)
	assert_eq(_panel.energy_label.text, "QE 600")
	assert_almost_eq(_panel.bar_fill.size.x, _panel.bar_track.size.x * 0.5, 0.01)
	assert_eq(_panel.energy_label.get_theme_color("font_color"), HudPalette.READOUT)
	assert_eq(_panel.status_label.text, "", "nothing to add at full power")

func test_the_notch_sits_at_the_low_power_line():
	_panel.render(_telemetry(600, 1200, 120, &"full"))
	var expected := _panel.bar_track.position.x + _panel.bar_track.size.x * 0.1 - EnergyPanel.NOTCH_WIDTH * 0.5
	assert_almost_eq(_panel.notch.position.x, expected, 0.01)

func test_shows_the_boost_cost_while_boosting():
	_panel.render(_telemetry(600, 1200, 120, &"full", "BOOST −5/S"))
	assert_eq(_panel.status_label.text, "BOOST −5/S")

func test_low_power_reads_low_power_in_warning():
	_panel.render(_telemetry(50, 1200, 120, &"low_power"))
	assert_eq(_panel.status_label.text, "LOW POWER")
	assert_eq(_panel.energy_label.get_theme_color("font_color"), HudPalette.WARNING)
	assert_eq(_panel.bar_fill.color, HudPalette.WARNING)

func test_boost_refused_reads_boost_dot_low_power():
	_panel.render(_telemetry(50, 1200, 120, &"low_power", "", true))
	assert_eq(_panel.status_label.text, "BOOST · LOW POWER")

# --- on a spacewalk, the suit (spec §9, §12) ------------------------------------

func _suit(charge: int, state: StringName, tool_text := "") -> VehicleTelemetry:
	var t := _telemetry(charge, 100, 0, state, tool_text)
	t.energy_label = &"SUIT"
	return t

func test_the_suit_reads_as_a_percentage_with_no_notch():
	_panel.render(_suit(64, &"ok"))
	assert_true(_panel.visible)
	assert_eq(_panel.energy_label.text, "SUIT 64%")
	assert_almost_eq(_panel.bar_fill.size.x, _panel.bar_track.size.x * 0.64, 0.01)
	assert_false(_panel.notch.visible, "the suit has no low-power line")
	assert_eq(_panel.energy_label.get_theme_color("font_color"), HudPalette.READOUT)
	assert_eq(_panel.status_label.text, "")

func test_the_ship_keeps_its_notch():
	_panel.render(_suit(64, &"ok"))
	_panel.render(_telemetry(600, 1200, 120, &"full"))
	assert_true(_panel.notch.visible)

func test_a_low_suit_warns_at_25():
	_panel.render(_suit(24, &"low"))
	assert_eq(_panel.status_label.text, "SUIT LOW")
	assert_eq(_panel.energy_label.get_theme_color("font_color"), HudPalette.WARNING)
	assert_eq(_panel.bar_fill.color, HudPalette.WARNING)

func test_a_critical_suit_warns_at_10():
	_panel.render(_suit(9, &"critical"))
	assert_eq(_panel.status_label.text, "SUIT CRITICAL")
	assert_eq(_panel.energy_label.get_theme_color("font_color"), HudPalette.WARNING)

func test_a_dry_suit_reads_returning():
	_panel.render(_suit(0, &"dry"))
	assert_eq(_panel.energy_label.text, "SUIT 0%")
	assert_eq(_panel.status_label.text, "SUIT DRY · RETURNING")
	assert_eq(_panel.energy_label.get_theme_color("font_color"), HudPalette.WARNING)

func test_the_suits_tool_shows_beside_its_warning():
	_panel.render(_suit(64, &"ok", "HOSE 12 M"))
	assert_eq(_panel.status_label.text, "HOSE 12 M")
	_panel.render(_suit(20, &"low", "HOSE 12 M"))
	assert_eq(_panel.status_label.text, "SUIT LOW · HOSE 12 M")
