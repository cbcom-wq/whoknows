class_name HurtEdge
extends Control

## How hurt you are, the only way it is shown (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §7.1, §7.2): a warm red edge that
## flashes when you are hit and fades, and stays faintly while you are low;
## the fade to black when you black out; and a line when you wake.

const FLASH := 0.35
const FLASH_FADE := 0.6
const LOW := 0.12
## The edge's depth, as a share of the shorter side, drawn in BANDS steps.
const DEPTH := 0.18
const BANDS := 10
const WOKE_FOR := 4.0
const WOKE_TEXT := "YOU BLACKED OUT · %d QE"

var avatar: Avatar
var _flash := 0.0
var _woke_left := 0.0
var _label: Label

func bind(p_avatar: Avatar) -> void:
	avatar = p_avatar
	avatar.hurt.connect(func(_amount: float, _from: Vector3) -> void: _flash = FLASH)
	avatar.downed_changed.connect(func(is_down: bool) -> void:
		if not is_down:
			_woke_left = WOKE_FOR)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.add_theme_color_override("font_color", HudPalette.WARNING)
	_label.add_theme_font_size_override("font_size", 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)

## The edge's strength now, 0 to 1.
func edge() -> float:
	var low := LOW if avatar != null and avatar.is_low() else 0.0
	return maxf(_flash, low)

## How dark the view is, 0 to 1.
func darkness() -> float:
	return avatar.downed.darkness() if avatar != null and avatar.downed != null else 0.0

func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * FLASH / FLASH_FADE, 0.0)
	_woke_left = maxf(_woke_left - delta, 0.0)
	if _label != null:
		var paid := Avatar.RESCUE_COST
		_label.text = WOKE_TEXT % paid
		_label.visible = _woke_left > 0.0 or (avatar != null and avatar.downed != null
			and avatar.downed.step == Downed.Step.WAKING)
	queue_redraw()

func _draw() -> void:
	var dark := darkness()
	if dark > 0.0:
		var black := HudPalette.BLACKOUT
		black.a = dark
		draw_rect(Rect2(Vector2.ZERO, size), black)
	var strength := edge()
	if strength <= 0.0:
		return
	var depth := minf(size.x, size.y) * DEPTH
	var step := depth / BANDS
	for i in BANDS:
		var c := HudPalette.HURT
		c.a = strength * (1.0 - float(i) / BANDS) / BANDS * 2.0
		var d := step * i
		draw_rect(Rect2(d, d, size.x - d * 2.0, step), c)
		draw_rect(Rect2(d, size.y - d - step, size.x - d * 2.0, step), c)
		draw_rect(Rect2(d, d + step, step, size.y - d * 2.0 - step * 2.0), c)
		draw_rect(Rect2(size.x - d - step, d + step, step, size.y - d * 2.0 - step * 2.0), c)
