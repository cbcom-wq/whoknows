class_name LostScreen
extends ColorRect

## The end of a life (docs/superpowers/specs/2026-10-24-hostile-ships-design.md
## §8.3): over everything, the view whites out in the core's flash, fades to
## black, and a line says what was lost -- SHIP LOST, SUIT LOST -- in the
## HUD's font; then `finished`, and the flight scene goes back to the last
## save. Hidden until play().

signal finished

## White to full, s.
const WHITE_IN := 0.15
## White to black, s.
const TO_BLACK := 1.5
## The line on the black, s.
const TEXT_FOR := 2.0
const TOTAL := WHITE_IN + TO_BLACK + TEXT_FOR
const FONT_SIZE := 28

var label: Label
## What it says, from play().
var text := ""
var playing := false
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	label = Label.new()
	label.name = "Line"
	label.add_theme_color_override("font_color", HudPalette.READOUT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	add_child(label)

## From clear, through white and black, to `what` on the black.
func play(what: String) -> void:
	text = what
	label.text = what
	playing = true
	visible = true
	_t = 0.0
	_show()

func _process(delta: float) -> void:
	if playing:
		advance(delta)

## Moves the screen on by `delta` seconds.
func advance(delta: float) -> void:
	if not playing:
		return
	_t += delta
	_show()
	if _t >= TOTAL - 1e-6:
		playing = false
		finished.emit()

func _show() -> void:
	var white := SpacePalette.WARP
	if _t < WHITE_IN:
		white.a = clampf(_t / WHITE_IN, 0.0, 1.0)
		color = white
	else:
		var dark := clampf((_t - WHITE_IN) / TO_BLACK, 0.0, 1.0)
		color = HudPalette.BLACKOUT if dark >= 1.0 else white.lerp(HudPalette.BLACKOUT, dark)
	label.visible = _t >= WHITE_IN + TO_BLACK - 1e-6
