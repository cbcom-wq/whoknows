class_name WeaponsStrip
extends HudElement

## The weapons on the console band (ship weapons spec §9.2): HOLD or ENGAGE,
## and a pip for each turret in its state's colour. Hidden on a ship with no
## turrets. Low power holding the guns reads WEAPONS · LOW POWER in WARNING;
## HOLD while a hostile is out for you reads HOSTILE · WEAPONS ON HOLD in
## WARNING, before anything else (hostile ships spec §4.3).

const PIP := 8.0
const PIP_GAP := 4.0
## The pips sit this far under the orders' last line.
const PIP_BELOW := 8.0
## The hostile warning, on two lines so it fits the band; orders_text() reads
## it as one.
const HOSTILE_HOLD := "HOSTILE\nWEAPONS ON HOLD"

var _label: Label
var _pips: Array[Color] = []

func _ready() -> void:
	if _label != null:
		return
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
	if telemetry.hostile_on_hold:
		_label.text = HOSTILE_HOLD
		_label.add_theme_color_override("font_color", HudPalette.WARNING)
	elif telemetry.weapons_low_power:
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
	return _label.text.replace("\n", " · ") if _label != null else ""

## Where the pips' top edge is: under the orders, however many lines they take.
func pip_top() -> float:
	return _label.position.y + _label.get_minimum_size().y + PIP_BELOW if _label != null else 0.0

func pip_colours() -> Array[Color]:
	return _pips

func _draw() -> void:
	for i in _pips.size():
		draw_rect(Rect2(Vector2(i * (PIP + PIP_GAP), pip_top()), Vector2(PIP, PIP)), _pips[i])
