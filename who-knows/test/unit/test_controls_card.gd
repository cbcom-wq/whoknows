extends GutTest

## The controls card (flight controls spec §8.4): every seated control, with
## key names read from the InputMap.

func _card() -> ControlsCard:
	var c := ControlsCard.new()
	add_child_autofree(c)
	return c

func _h() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"toggle_controls"
	ev.pressed = true
	return ev

func test_every_row_names_a_bound_action():
	for row in ControlsCard.ROWS:
		if row[0] is String:
			continue
		for action in row[0]:
			assert_true(InputMap.has_action(action), "%s is an action" % action)
			assert_gt(InputMap.action_get_events(action).size(), 0, "%s is bound" % action)

func test_the_card_shows_each_rows_keys_from_the_input_map():
	var c := _card()
	assert_eq(c.keys.size(), ControlsCard.ROWS.size())
	for i in ControlsCard.ROWS.size():
		var row: Array = ControlsCard.ROWS[i]
		assert_eq(c.keys[i].text, ControlsCard.keys_text(row[0], row[2]))

func test_key_names_come_from_the_bindings():
	assert_eq(ControlsCard.key_name(&"speed_lock"), "C")
	assert_eq(ControlsCard.key_name(&"pitch_up"), "Up")
	assert_eq(ControlsCard.key_name(&"point_mode"), "RMB")
	assert_eq(ControlsCard.key_name(&"set_heading"), "LMB")
	assert_eq(ControlsCard.keys_text([&"point_mode", &"set_heading"], " + "), "RMB + LMB")

func test_it_is_open_the_first_time_you_sit():
	var c := _card()
	c.render(VehicleTelemetry.new())
	assert_true(c.visible)

func test_h_hides_it_and_shows_it_again():
	var c := _card()
	c.render(VehicleTelemetry.new())
	c.handle(_h())
	assert_false(c.visible)
	assert_false(c.shown, "and it stays hidden until H again")
	c.handle(_h())
	assert_true(c.visible)

func test_h_does_nothing_on_foot():
	var c := _card()
	c.render(null)
	c.handle(_h())
	assert_true(c.shown)

func test_it_ignores_the_mouse():
	var c := _card()
	assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in c.get_children():
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
