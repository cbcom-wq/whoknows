class_name VelocityPanel
extends HudElement

## Speed against the cruise ceiling, plus the two flight-mode flags.
##
## Children are built in code rather than authored in the scene. That keeps
## flight_test.tscn small -- see CLAUDE.md on the text-scene parser defect --
## and lets every assertion below run headless.

## Fraction of the ceiling at which the bar starts warning.
const AMBER_FRACTION := 0.9

const BAR_WIDTH := 150.0
const BAR_HEIGHT := 4.0

var speed_label: Label
var units_label: Label
var bar_track: ColorRect
var bar_fill: ColorRect
var mode_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 56.0)

	speed_label = Label.new()
	speed_label.text = "0"
	speed_label.add_theme_font_size_override("font_size", 30)
	speed_label.add_theme_color_override("font_color", HudPalette.READOUT)
	speed_label.position = Vector2(0.0, 0.0)
	add_child(speed_label)

	units_label = Label.new()
	units_label.text = "M/S"
	units_label.add_theme_font_size_override("font_size", 10)
	units_label.add_theme_color_override("font_color", HudPalette.DIM)
	units_label.position = Vector2(62.0, 18.0)
	add_child(units_label)

	bar_track = ColorRect.new()
	bar_track.color = Color(HudPalette.READOUT, 0.18)
	bar_track.position = Vector2(0.0, 40.0)
	bar_track.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	add_child(bar_track)

	bar_fill = ColorRect.new()
	bar_fill.color = HudPalette.READOUT
	bar_fill.position = Vector2(0.0, 40.0)
	bar_fill.size = Vector2(0.0, BAR_HEIGHT)
	add_child(bar_fill)

	mode_label = Label.new()
	mode_label.text = "ASSIST ON   BOOST OFF"
	mode_label.add_theme_font_size_override("font_size", 11)
	mode_label.add_theme_color_override("font_color", HudPalette.READOUT)
	mode_label.position = Vector2(170.0, 38.0)
	add_child(mode_label)

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null:
		return

	speed_label.text = "%d" % roundi(telemetry.speed)

	# A vehicle with no declared ceiling gets an empty bar rather than a
	# division by zero. The numeral still reads correctly.
	var fraction := 0.0
	if telemetry.cruise_limit > 0.0:
		fraction = clampf(telemetry.speed / telemetry.cruise_limit, 0.0, 1.0)
	bar_fill.size.x = bar_track.size.x * fraction

	# Assist off removes the cruise clamp entirely, so speed can sit above the
	# ceiling. The bar pins and warns instead of silently misreporting.
	var warn := telemetry.cruise_limit > 0.0 \
		and telemetry.speed >= telemetry.cruise_limit * AMBER_FRACTION
	bar_fill.color = HudPalette.WARNING if warn else HudPalette.READOUT

	mode_label.text = "ASSIST %s   BOOST %s" % [
		"ON" if telemetry.assist_enabled else "OFF",
		"ON" if telemetry.boost_active else "OFF",
	]
