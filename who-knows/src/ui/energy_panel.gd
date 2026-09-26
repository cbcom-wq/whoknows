class_name EnergyPanel
extends HudElement

## The ship's store, seated (quantum energy spec §12): *QE 600*, a bar with
## a notch at the low-power line, and a status line beneath it for whatever
## the vehicle needs to add -- the ship's running boost cost, or (once the
## suit is wired, Task 7) the hose's paid-out length.
##
## Children are built in code rather than authored in the scene, exactly
## like VelocityPanel and AttitudePanel -- see CLAUDE.md on the text-scene
## parser defect.

const BAR_WIDTH := 150.0
const BAR_HEIGHT := 4.0
const NOTCH_WIDTH := 2.0
const NOTCH_HEIGHT := 8.0

var energy_label: Label
var bar_track: ColorRect
var bar_fill: ColorRect
var notch: ColorRect
var status_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(220.0, 64.0)

	energy_label = Label.new()
	energy_label.text = "QE 0"
	energy_label.add_theme_font_size_override("font_size", 30)
	energy_label.add_theme_color_override("font_color", HudPalette.READOUT)
	energy_label.position = Vector2(0.0, 0.0)
	add_child(energy_label)

	bar_track = ColorRect.new()
	bar_track.color = Color(HudPalette.READOUT, 0.18)
	bar_track.position = Vector2(0.0, 40.0)
	bar_track.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	# ColorRect defaults to MOUSE_FILTER_STOP and mouse_filter is not
	# inherited from a parent Control: without this the bar would eat clicks
	# meant for the world behind it, even while the HUD is faded fully
	# transparent, since alpha does not affect hit-testing.
	bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_track)

	bar_fill = ColorRect.new()
	bar_fill.color = HudPalette.READOUT
	bar_fill.position = Vector2(0.0, 40.0)
	bar_fill.size = Vector2(0.0, BAR_HEIGHT)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_fill)

	# The low-power line: always there, over the bar, wherever the line falls.
	notch = ColorRect.new()
	notch.color = HudPalette.WARNING
	notch.position = Vector2(0.0, 40.0 - (NOTCH_HEIGHT - BAR_HEIGHT) * 0.5)
	notch.size = Vector2(NOTCH_WIDTH, NOTCH_HEIGHT)
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notch)

	# Below the bar, not beside the numeral: "BOOST · LOW POWER" is too wide
	# to sit at (170, ...) the way VelocityPanel's mode line does, and this
	# panel's numeral runs right up to the bar's own row.
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", HudPalette.READOUT)
	status_label.position = Vector2(0.0, 40.0 + BAR_HEIGHT + 4.0)
	add_child(status_label)

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null or not telemetry.has_energy:
		visible = false
		return
	visible = true

	energy_label.text = "%s %d" % [telemetry.energy_label, telemetry.energy]

	var low := telemetry.energy_state == &"low_power"
	var colour := HudPalette.WARNING if low else HudPalette.READOUT
	energy_label.add_theme_color_override("font_color", colour)
	status_label.add_theme_color_override("font_color", colour)
	bar_fill.color = colour

	var fraction := 0.0
	var line_fraction := 0.0
	if telemetry.energy_capacity > 0:
		fraction = clampf(float(telemetry.energy) / float(telemetry.energy_capacity), 0.0, 1.0)
		line_fraction = clampf(float(telemetry.energy_line) / float(telemetry.energy_capacity), 0.0, 1.0)
	bar_fill.size.x = bar_track.size.x * fraction
	notch.position.x = bar_track.position.x + bar_track.size.x * line_fraction - NOTCH_WIDTH * 0.5

	if telemetry.boost_refused:
		status_label.text = "BOOST · LOW POWER"
	elif low:
		status_label.text = "LOW POWER"
	else:
		status_label.text = telemetry.tool_text
