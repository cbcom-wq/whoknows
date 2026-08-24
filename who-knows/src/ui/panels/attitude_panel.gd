class_name AttitudePanel
extends HudElement

## Rotation rate about each of the hull's own axes, as three centre-zero
## tracks, plus a settled indicator.
##
## This is what tells the pilot whether the flight computer's rotation
## damping has actually finished before they commit to a burn -- a ship that
## still has residual spin will curve away from wherever they aimed it.

## Rate that pins a pip to the end of its track, radians/sec.
##
## Deliberately set for a ship that turns properly, not for the one that
## exists today. SLICE-1-STATUS.md records peak yaw acceleration at
## 3.83 deg/s^2 with assist damping exceeding control authority by 1.66x, so
## until torque_budget is reworked the pips will sit closer to centre than
## this constant implies. Tuning it down to flatter the current defect would
## only mean retuning it once that defect is fixed.
const DISPLAY_MAX_RAD := 1.5
## Total rotation magnitude below which the ship counts as settled.
const SETTLED_RAD := 0.05

const TRACK_WIDTH := 84.0
const TRACK_HEIGHT := 3.0
const PIP_WIDTH := 3.0
const PIP_HEIGHT := 7.0
const ROW_SPACING := 14.0

var track_width: float = TRACK_WIDTH
var pitch_pip: ColorRect
var yaw_pip: ColorRect
var roll_pip: ColorRect
var settled_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(150.0, 56.0)
	pitch_pip = _build_row("PITCH", 0)
	yaw_pip = _build_row("YAW", 1)
	roll_pip = _build_row("ROLL", 2)

	settled_label = Label.new()
	settled_label.text = "SETTLED"
	settled_label.add_theme_font_size_override("font_size", 9)
	settled_label.add_theme_color_override("font_color", HudPalette.DIM)
	settled_label.position = Vector2(0.0, ROW_SPACING * 3.0)
	settled_label.visible = false
	add_child(settled_label)

## Builds one labelled track and returns its pip.
func _build_row(caption: String, row: int) -> ColorRect:
	var y := row * ROW_SPACING

	var name_label := Label.new()
	name_label.text = caption
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", HudPalette.DIM)
	name_label.position = Vector2(0.0, y - 2.0)
	add_child(name_label)

	var track := ColorRect.new()
	track.color = Color(HudPalette.READOUT, 0.18)
	track.position = Vector2(40.0, y + 3.0)
	track.size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	add_child(track)

	# The zero rule. Reading a pip against the centre is the whole point, so
	# the centre has to be visible when the pip is elsewhere.
	var zero := ColorRect.new()
	zero.color = Color(HudPalette.READOUT, 0.35)
	zero.position = Vector2(40.0 + TRACK_WIDTH * 0.5, y + 1.0)
	zero.size = Vector2(1.0, PIP_HEIGHT)
	add_child(zero)

	var pip := ColorRect.new()
	pip.color = HudPalette.READOUT
	pip.size = Vector2(PIP_WIDTH, PIP_HEIGHT)
	# Parented to the track, so this position is relative to it: centred
	# horizontally, and lifted so the taller pip straddles the thin track.
	pip.position = Vector2(
		TRACK_WIDTH * 0.5 - PIP_WIDTH * 0.5,
		(TRACK_HEIGHT - PIP_HEIGHT) * 0.5
	)
	track.add_child(pip)
	return pip

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null:
		return
	var rates := telemetry.local_angular_velocity
	_place(pitch_pip, rates.x)
	_place(yaw_pip, rates.y)
	_place(roll_pip, rates.z)
	settled_label.visible = rates.length() < SETTLED_RAD

## Maps a rate onto its track, clamped, and centres the pip on that point.
func _place(pip: ColorRect, rate: float) -> void:
	var fraction := clampf(rate / DISPLAY_MAX_RAD, -1.0, 1.0)
	var centre := TRACK_WIDTH * 0.5
	pip.position.x = centre + centre * fraction - PIP_WIDTH * 0.5
