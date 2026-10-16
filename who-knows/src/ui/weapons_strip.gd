class_name WeaponsStrip
extends HudElement

## The weapons on the console band (ship weapons spec §9.2): HOLD or ENGAGE,
## and a pip for each turret in its state's colour. Hidden on a ship with no
## turrets. Low power holding the guns reads WEAPONS · LOW POWER in WARNING.

const PIP := 8.0
const PIP_GAP := 4.0

var _label: Label
var _pips: Array[Color] = []

func _ready() -> void:
	custom_minimum_size = Vector2(150.0, 64.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", HudPalette.READOUT)
	_label.position = Vector2(0.0, 6.0)
	add_child(_label)

func render(telemetry: VehicleTelemetry) -> void:
	if telemetry == null or not telemetry.has_weapons:
		visible = false
		return
	visible = true
	if _label == null:
		_ready()
	if telemetry.weapons_low_power:
		_label.text = "WEAPONS · LOW POWER"
		_label.add_theme_color_override("font_color", HudPalette.WARNING)
	else:
		_label.text = "ENGAGE" if telemetry.weapons_engage else "HOLD"
		_label.add_theme_color_override("font_color", HudPalette.READOUT if telemetry.weapons_engage else HudPalette.DIM)
	_pips.clear()
	for s in telemetry.weapons_pips:
		_pips.append(HudPalette.for_pip(s))
	queue_redraw()

func orders_text() -> String:
	return _label.text if _label != null else ""

func pip_colours() -> Array[Color]:
	return _pips

func _draw() -> void:
	for i in _pips.size():
		draw_rect(Rect2(Vector2(i * (PIP + PIP_GAP), 34.0), Vector2(PIP, PIP)), _pips[i])
