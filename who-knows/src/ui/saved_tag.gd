class_name SavedTag
extends Label

## The one sign that the game saved (docs/superpowers/specs/
## 2026-09-26-saving-design.md §4): a small, dim SAVED at the bottom-right
## that fades in and out over FADE. A save this game may not overwrite, from
## a newer version, says so instead, and stays.

const FADE := 1.0
const TEXT := "SAVED"
const LOCKED_TEXT := "SAVE LOCKED: NEWER VERSION"
const MARGIN := 16.0

var _shown_for := -1.0
var _fade := FADE

func _ready() -> void:
	text = TEXT
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", HudPalette.DIM)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	modulate.a = 0.0

## A save was written: fade SAVED in and out.
func flash() -> void:
	say(TEXT, FADE)

## Fades `note` in and out over `seconds`, in place of SAVED.
func say(note: String, seconds: float) -> void:
	text = note
	_fade = seconds
	_shown_for = 0.0

## The save on disk is from a newer game and will not be written over.
func show_locked() -> void:
	text = LOCKED_TEXT
	add_theme_color_override("font_color", HudPalette.WARNING)
	_shown_for = -1.0
	modulate.a = 1.0

func _process(delta: float) -> void:
	if _shown_for < 0.0:
		return
	_shown_for += delta
	modulate.a = sin(clampf(_shown_for / _fade, 0.0, 1.0) * PI)
	if _shown_for >= _fade:
		_shown_for = -1.0
		modulate.a = 0.0
