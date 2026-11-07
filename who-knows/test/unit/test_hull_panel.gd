extends GutTest

## The hull in the band (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §11), from made-up telemetry.

var _panel: HullPanel

func before_each():
	_panel = HullPanel.new()
	add_child_autofree(_panel)

func _t(hull: float, reason := "") -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	t.has_hull = true
	t.hull = hull
	t.crippled_reason = reason
	return t

func test_it_shows_how_whole_the_hull_is():
	_panel.render(_t(0.874))
	assert_true(_panel.visible)
	assert_eq(_panel.hull_label.text, "HULL 87%")
	assert_eq(_panel.status_label.text, "")

func test_crippled_it_says_why_in_the_warning_colour():
	_panel.render(_t(0.4, "no thrust"))
	assert_eq(_panel.status_label.text, "CRIPPLED · NO THRUST")
	assert_eq(_panel.hull_label.get_theme_color("font_color"), HudPalette.WARNING)

func test_no_hull_no_panel():
	_panel.render(VehicleTelemetry.new())
	assert_false(_panel.visible)
	_panel.render(null)
	assert_false(_panel.visible)

func test_the_ground_status_shows_when_not_crippled():
	var t := _t(1.0)
	t.ground_status = "LANDED"
	_panel.render(t)
	assert_eq(_panel.status_label.text, "LANDED")

func test_crippled_outranks_the_ground_status():
	var t := _t(0.4, "no thrust")
	t.ground_status = "LANDED"
	_panel.render(t)
	assert_eq(_panel.status_label.text, "CRIPPLED · NO THRUST")

func test_landed_is_readout_and_uneven_ground_is_warning():
	var t := _t(1.0)
	t.ground_status = "LANDED"
	_panel.render(t)
	assert_eq(_panel.status_label.get_theme_color("font_color"), HudPalette.READOUT)
	t.ground_status = "UNEVEN GROUND · TILT 31°"
	_panel.render(t)
	assert_eq(_panel.status_label.get_theme_color("font_color"), HudPalette.WARNING)
