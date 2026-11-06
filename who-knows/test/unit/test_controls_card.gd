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

func test_every_row_on_every_card_names_a_bound_action():
	for list in [ControlsCard.ROWS, ControlsCard.FOOT_ROWS, ControlsCard.SPACEWALK_ROWS]:
		for row in list:
			if row[0] is String:
				continue
			for action in row[0]:
				assert_true(InputMap.has_action(action), "%s is an action" % action)
				assert_gt(InputMap.action_get_events(action).size(), 0, "%s is bound" % action)

func test_seated_is_the_pilots_card():
	assert_eq(ControlsCard.card_for(true, Avatar.Mode.PLATING), ControlsCard.Card.SEATED)
	assert_eq(ControlsCard.rows_for(ControlsCard.Card.SEATED), ControlsCard.ROWS)

func test_on_foot_shows_no_pilot_keys():
	assert_eq(ControlsCard.card_for(false, Avatar.Mode.PLATING), ControlsCard.Card.ON_FOOT)
	assert_eq(ControlsCard.card_for(false, Avatar.Mode.FIELD), ControlsCard.Card.ON_FOOT)
	for row in ControlsCard.FOOT_ROWS:
		for a in [&"boost", &"warp", &"toggle_assist", &"speed_lock", &"pitch_up", &"weapons_orders"]:
			assert_false(a in row[0], "%s is a pilot's key" % a)

func test_a_spacewalk_has_its_own_card():
	assert_eq(ControlsCard.card_for(false, Avatar.Mode.SUIT), ControlsCard.Card.SPACEWALK)
	assert_eq(ControlsCard.rows_for(ControlsCard.Card.SPACEWALK), ControlsCard.SPACEWALK_ROWS)

func test_show_card_relabels():
	var c := _card()
	c.show_card(ControlsCard.Card.ON_FOOT)
	assert_eq(c.keys.size(), ControlsCard.FOOT_ROWS.size())
	assert_eq(c.keys[0].text, ControlsCard.keys_text(ControlsCard.FOOT_ROWS[0][0], " "))
	c.show_card(ControlsCard.Card.SEATED)
	assert_eq(c.keys.size(), ControlsCard.ROWS.size())
	assert_eq(c.get_child_count(), 1 + 2 * ControlsCard.ROWS.size(), "the old face is gone at once")

func test_show_card_before_ready_still_builds_the_face():
	var c := ControlsCard.new()
	c.show_card(ControlsCard.Card.SPACEWALK)
	add_child_autofree(c)
	assert_eq(c.keys.size(), ControlsCard.SPACEWALK_ROWS.size())

func test_the_card_shows_each_rows_keys_from_the_input_map():
	var c := _card()
	c.show_card(ControlsCard.Card.SEATED)
	assert_eq(c.keys.size(), ControlsCard.ROWS.size())
	for i in ControlsCard.ROWS.size():
		var row: Array = ControlsCard.ROWS[i]
		assert_eq(c.keys[i].text, ControlsCard.keys_text(row[0], row[2]))

func test_key_names_come_from_the_bindings():
	assert_eq(ControlsCard.key_name(&"speed_lock"), "X")
	assert_eq(ControlsCard.key_name(&"orbit_camera"), "C")
	assert_eq(ControlsCard.key_name(&"pitch_up"), "Up")
	assert_eq(ControlsCard.key_name(&"point_mode"), "RMB")
	assert_eq(ControlsCard.key_name(&"set_heading"), "LMB")
	assert_eq(ControlsCard.keys_text([&"point_mode", &"set_heading"], " + "), "RMB + LMB")
	assert_eq(ControlsCard.key_name(&"weapons_clear"), "Shift+T", "with its modifiers")

## The weapons keys are on the card, not only on the band.
func test_the_weapons_keys_are_on_the_card():
	var actions: Array = []
	for row in ControlsCard.ROWS:
		if not row[0] is String:
			actions.append_array(row[0])
	for a in [&"weapons_orders", &"weapons_mark", &"weapons_clear"]:
		assert_has(actions, a)

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

func test_h_works_on_foot():
	var c := _card()
	c.render(null)
	c.handle(_h())
	assert_false(c.shown)
	c.handle(_h())
	assert_true(c.shown)

func test_it_ignores_the_mouse():
	var c := _card()
	assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child in c.get_children():
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
