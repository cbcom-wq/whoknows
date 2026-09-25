class_name StickCursor
extends HudElement

## The virtual stick and the point-mode pointer (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §8). A small ring where the stick sits,
## a faint line back to the centre and a faint circle at full deflection,
## hidden inside the dead zone. In point mode, the pointer and a hint instead.
## Everything it needs comes in the telemetry, so it knows nothing of flight.

const HINT := "CLICK: SET HEADING   ·   RELEASE RMB: BACK TO STICK"
const RING := 7.0
const POINTER_ARM := 9.0
const LINE_WIDTH := 1.5
## Where the hint sits, as a fraction of the screen's height.
const HINT_HEIGHT := 0.72

var armed := false
var pointing := false
var show_stick := false
## Screen positions, for _draw and the tests.
var stick_at := Vector2.ZERO
var pointer_at := Vector2.ZERO
var hint: Label

var _radius_px := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint = Label.new()
	hint.text = HINT
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", HudPalette.READOUT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	add_child(hint)

func render(telemetry: VehicleTelemetry) -> void:
	armed = telemetry != null
	pointing = armed and telemetry.pointing
	show_stick = armed and not pointing and telemetry.stick.length() > telemetry.stick_deadzone
	if armed:
		var centre := size * 0.5
		stick_at = centre + telemetry.stick * size.y
		pointer_at = centre + telemetry.pointer * size.y
		_radius_px = telemetry.stick_radius * size.y
	hint.visible = pointing
	if pointing:
		hint.position = Vector2(size.x * 0.5 - hint.get_minimum_size().x * 0.5, size.y * HINT_HEIGHT)
	queue_redraw()

func _draw() -> void:
	if pointing:
		var c := HudPalette.READOUT
		draw_line(pointer_at + Vector2(-POINTER_ARM, 0.0), pointer_at + Vector2(POINTER_ARM, 0.0), c, LINE_WIDTH)
		draw_line(pointer_at + Vector2(0.0, -POINTER_ARM), pointer_at + Vector2(0.0, POINTER_ARM), c, LINE_WIDTH)
		draw_arc(pointer_at, POINTER_ARM * 0.5, 0.0, TAU, 16, c, LINE_WIDTH)
		return
	if not show_stick:
		return
	var centre := size * 0.5
	draw_arc(centre, _radius_px, 0.0, TAU, 48, Color(HudPalette.READOUT, 0.15), 1.0)
	draw_line(centre, stick_at, Color(HudPalette.READOUT, 0.3), 1.0)
	draw_arc(stick_at, RING, 0.0, TAU, 20, HudPalette.READOUT, LINE_WIDTH)
