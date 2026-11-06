class_name ControlsCard
extends HudElement

## The help card on the HUD (docs/superpowers/specs/2026-09-25-flight-controls-
## design.md §8.4), with three faces: the pilot's keys when seated, your feet's
## keys on foot (aboard or on a world), and the suit's on a spacewalk. The key
## names are read from the InputMap, never typed in, so the card cannot drift
## from the bindings. flight_test picks the face (`card_for`); H hides or shows
## the card anywhere, and it stays that way for the rest of the session.

enum Card { SEATED, ON_FOOT, SPACEWALK }

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
	[[&"warp"], "Warp, when charted", " "],
	[[&"point_mode", &"set_heading"], "Hold, click: set heading", " + "],
	[[&"toggle_assist"], "Assist", " "],
	[[&"lights_flood"], "Floods", " "],
	[[&"lights_forward"], "Forward lights", " "],
	[[&"weapons_orders"], "Weapons: hold or engage", " "],
	[[&"weapons_mark", &"weapons_clear"], "Mark target ahead; clear", "  "],
	[[&"cycle_camera"], "Camera", " "],
	[[&"orbit_camera"], "Hold: look around the ship", " "],
	[[&"interact"], "Stand up", " "],
	[[&"toggle_controls"], "Hide this card", " "],
]
## On foot, aboard or on a world.
const FOOT_ROWS := [
	[[&"move_forward", &"move_left", &"move_back", &"move_right"], "Walk", " "],
	[[&"sprint"], "Sprint", " "],
	[[&"crouch"], "Crouch", " "],
	[[&"jump"], "Jump, on a world", " "],
	[[&"interact"], "Use, open, sit", " "],
	[[&"use"], "Use what you hold", " "],
	[[&"drop", &"throw"], "Drop; throw", "  "],
	[[&"lights_flood"], "Suit lamp, outside", " "],
	[[&"toggle_controls"], "Hide this card", " "],
]
## In the suit, in space.
const SPACEWALK_ROWS := [
	[[&"move_forward", &"move_left", &"move_back", &"move_right"], "Thrust", " "],
	[[&"sprint", &"crouch"], "Up and down", " "],
	[[&"roll_left", &"roll_right"], "Roll", " "],
	[[&"interact"], "Use, open", " "],
	[[&"use"], "Use what you hold", " "],
	[[&"drop", &"throw"], "Let go; throw", "  "],
	[[&"lights_flood"], "Suit lamp", " "],
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

## The face on show. Standing aboard is where a game starts.
var card := Card.ON_FOOT

var keys: Array[Label] = []

## The labels and backdrop of the face on show, so a swap can drop them at once.
var _face: Array[Control] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = shown

## The rows of a face.
static func rows_for(c: Card) -> Array:
	match c:
		Card.SEATED:
			return ROWS
		Card.SPACEWALK:
			return SPACEWALK_ROWS
	return FOOT_ROWS

## The face for where you are: seated wins; else a spacewalk in the suit; else
## on foot, aboard or on a world.
static func card_for(seated: bool, mode: Avatar.Mode) -> Card:
	if seated:
		return Card.SEATED
	if mode == Avatar.Mode.SUIT:
		return Card.SPACEWALK
	return Card.ON_FOOT

## Swap to another face. Works before or after _ready.
func show_card(c: Card) -> void:
	card = c
	if is_node_ready():
		_build()

func render(_telemetry: VehicleTelemetry) -> void:
	visible = shown

func _unhandled_input(event: InputEvent) -> void:
	handle(event)

## H, anywhere. Split from _unhandled_input so tests can drive it.
func handle(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_controls"):
		shown = not shown
		visible = shown

## Drop the old face at once, then lay out the rows of `card`.
func _build() -> void:
	for old in _face:
		remove_child(old)
		old.free()
	_face.clear()
	keys.clear()
	var rows := rows_for(card)
	var back := ColorRect.new()
	back.color = HudPalette.BACKDROP
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = Vector2(PAD * 2.0 + KEY_WIDTH + TEXT_WIDTH, PAD * 2.0 + rows.size() * ROW_HEIGHT)
	add_child(back)
	_face.append(back)
	for i in rows.size():
		var row: Array = rows[i]
		var y := PAD + i * ROW_HEIGHT
		keys.append(_label(keys_text(row[0], row[2]), HudPalette.READOUT, Vector2(PAD, y)))
		_face.append(_label(row[1], HudPalette.DIM, Vector2(PAD + KEY_WIDTH, y)))
	_face.append_array(keys)

## The keys for `source`: an action list's key names joined by `joiner`, or a
## name, as it is.
static func keys_text(source: Variant, joiner: String) -> String:
	if source is String:
		return source
	var names := PackedStringArray()
	for action: StringName in source:
		names.append(key_name(action))
	return joiner.join(names)

## The name of the first key or mouse button bound to `action`, with its
## modifiers ("Shift+T").
static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code | key.get_modifiers_mask())
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
