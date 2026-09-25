class_name ControlsCard
extends HudElement

## Every seated control, on the HUD (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §8.4). The key names are read from the
## InputMap, never typed in, so the card cannot drift from the bindings. It is
## open the first time you sit; H hides or shows it, and it stays that way for
## the rest of the session.

## [what you press -- actions, or a name for something with no action; what it
## does; how to join several actions' keys].
const ROWS := [
	["Mouse", "Stick: pitch and yaw", " "],
	[[&"pitch_up", &"pitch_down", &"yaw_left", &"yaw_right"], "Pitch and yaw", " "],
	[[&"roll_left", &"roll_right"], "Roll", " "],
	[[&"move_forward", &"move_back"], "Thrust; let go to brake", " "],
	[[&"move_left", &"move_right"], "Strafe", " "],
	[[&"sprint", &"crouch"], "Up and down", " "],
	[[&"boost"], "Boost", " "],
	[[&"speed_lock"], "Lock speed", " "],
	[[&"point_mode", &"set_heading"], "Hold, click: set heading", " + "],
	[[&"toggle_assist"], "Assist", " "],
	[[&"cycle_camera"], "Camera", " "],
	[[&"interact"], "Stand up", " "],
	[[&"toggle_controls"], "Hide this card", " "],
]
const ROW_HEIGHT := 18.0
const KEY_WIDTH := 130.0
const TEXT_WIDTH := 170.0
const PAD := 10.0

## Open or hidden. The card lives as long as the flight scene -- the whole
## session -- so this remembers for the session. Not a static: a static var on
## this script, which flight_test.tscn loads, crashed Godot 4.5.1 on exit
## (0xC0000005) in every headless run of the scene.
var shown := true

var keys: Array[Label] = []

var _armed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.color = HudPalette.BACKDROP
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = Vector2(PAD * 2.0 + KEY_WIDTH + TEXT_WIDTH, PAD * 2.0 + ROWS.size() * ROW_HEIGHT)
	add_child(back)
	for i in ROWS.size():
		var row: Array = ROWS[i]
		var y := PAD + i * ROW_HEIGHT
		keys.append(_label(keys_text(row[0], row[2]), HudPalette.READOUT, Vector2(PAD, y)))
		_label(row[1], HudPalette.DIM, Vector2(PAD + KEY_WIDTH, y))
	visible = shown

func render(telemetry: VehicleTelemetry) -> void:
	_armed = telemetry != null
	visible = shown

func _unhandled_input(event: InputEvent) -> void:
	handle(event)

## H, while you sit. Split from _unhandled_input so tests can drive it.
func handle(event: InputEvent) -> void:
	if _armed and event.is_action_pressed(&"toggle_controls"):
		shown = not shown
		visible = shown

## The keys for `source`: an action list's key names joined by `joiner`, or a
## name, as it is.
static func keys_text(source: Variant, joiner: String) -> String:
	if source is String:
		return source
	var names := PackedStringArray()
	for action: StringName in source:
		names.append(key_name(action))
	return joiner.join(names)

## The name of the first key or mouse button bound to `action`.
static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
		var button := event as InputEventMouseButton
		if button != null:
			match button.button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
			return "Mouse %d" % button.button_index
	return "?"

func _label(text: String, colour: Color, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
