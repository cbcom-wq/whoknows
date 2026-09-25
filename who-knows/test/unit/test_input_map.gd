extends GutTest

## Guards the input map itself. Godot accepts a malformed `events` array in
## project.godot without complaint and simply registers the action with no
## bindings -- the game then launches, renders, and responds to the mouse
## while every key silently does nothing.

const REQUIRED_ACTIONS := [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint", &"crouch", &"interact",
	&"roll_left", &"roll_right", &"boost",
	&"toggle_assist", &"cycle_camera",
	&"use", &"throw", &"drop",
	&"pitch_up", &"pitch_down", &"yaw_left", &"yaw_right",
	&"point_mode", &"set_heading", &"speed_lock", &"toggle_controls",
]

func test_every_gameplay_action_is_registered():
	for action in REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "action not registered: %s" % action)

func test_every_gameplay_action_has_at_least_one_binding():
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events := InputMap.action_get_events(action)
		assert_gt(
			events.size(), 0,
			"action '%s' is registered but has no bound events" % action
		)

func test_every_binding_is_a_real_input_event():
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			assert_true(
				event is InputEvent,
				"action '%s' has a binding that is not an InputEvent" % action
			)

func test_movement_keys_are_bound_to_the_expected_physical_keys():
	var expected := {
		&"move_forward": KEY_W,
		&"move_back": KEY_S,
		&"move_left": KEY_A,
		&"move_right": KEY_D,
		&"interact": KEY_F,
	}
	for action in expected:
		var wanted: Key = expected[action]
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == wanted:
				found = true
				break
		assert_true(found, "action '%s' is not bound to its expected key" % action)

## Hands and items (hands-and-items spec §7.1): use and throw on the mouse
## buttons, drop on G.
func test_hand_actions_are_bound_to_the_mouse_and_g():
	var use_ev: InputEventMouseButton = InputMap.action_get_events(&"use")[0]
	assert_eq(use_ev.button_index, MOUSE_BUTTON_LEFT)
	var throw_ev: InputEventMouseButton = InputMap.action_get_events(&"throw")[0]
	assert_eq(throw_ev.button_index, MOUSE_BUTTON_RIGHT)
	var drop_ev: InputEventKey = InputMap.action_get_events(&"drop")[0]
	assert_eq(drop_ev.physical_keycode, KEY_G)

## Flight controls spec §4: arrows turn, RMB points, LMB sets the heading, C
## locks the speed, H shows the controls card.
func test_flight_controls_are_bound_where_the_card_says():
	var keys := {
		&"pitch_up": KEY_UP, &"pitch_down": KEY_DOWN,
		&"yaw_left": KEY_LEFT, &"yaw_right": KEY_RIGHT,
		&"speed_lock": KEY_C, &"toggle_controls": KEY_H,
	}
	for action in keys:
		var ev: InputEventKey = InputMap.action_get_events(action)[0]
		assert_eq(ev.physical_keycode, keys[action], String(action))
	var point: InputEventMouseButton = InputMap.action_get_events(&"point_mode")[0]
	assert_eq(point.button_index, MOUSE_BUTTON_RIGHT)
	var click: InputEventMouseButton = InputMap.action_get_events(&"set_heading")[0]
	assert_eq(click.button_index, MOUSE_BUTTON_LEFT)

## A stray block of dictionary-style duplicates once sat at the end of [input].
## Its first line starts with "[", which opens a new section, so any action
## written after it silently lost its bindings.
func test_the_input_section_has_no_dictionary_style_bindings():
	var text := FileAccess.get_file_as_string("res://project.godot")
	assert_false(text.contains("\"type\":\"InputEventKey\""))
