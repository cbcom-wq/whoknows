extends GutTest

## A hostile from the spawn panel, in the real flight scene (hostile ships spec
## §10, §4.3): Shift + a number brings a library ship 3 km off, facing you and
## out for you; its bracket shows whether listed or not, with its HULL %; HOLD
## warns while it is out for you; F8 will not board it; F2 reads out its pilot.

var _root: Node
var _starter: Ship
var _fleet: Fleet

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_starter = _root.get_node("Ship")
	_fleet = _root.fleet
	await wait_process_frames(2)

func _newest() -> Ship:
	var ships := _fleet.ships()
	return ships[ships.size() - 1]

func _spawn() -> Ship:
	var said: String = _root.spawn_hostile(&"starter")
	assert_true(said.begins_with("HOSTILE "), said)
	return _newest()

func _key(node: Node, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	node._unhandled_key_input(ev)

func test_a_hostile_spawns_three_km_off_facing_you():
	var ship := _spawn()
	assert_ne(ship, _starter, "a new ship")
	assert_eq(_fleet.ships().size(), 2)
	assert_eq(ship.side, Sides.HOSTILE)
	var to_you := _starter.exterior.global_position - ship.exterior.global_position
	assert_almost_eq(to_you.length(), PilotValues.SPAWN_RANGE, 50.0)
	assert_gt((-ship.exterior.global_basis.z).dot(to_you.normalized()), 0.95, "facing you")
	assert_eq(ship.exterior.linear_velocity, Vector3.ZERO, "at rest")
	assert_false(_fleet.arriving(ship), "already there: no warp arrival")
	assert_true(ship.ship_pilot.on)
	assert_between(ship.ship_pilot.skill, PilotValues.SPAWN_SKILL.x, PilotValues.SPAWN_SKILL.y)
	assert_eq(ship.ship_pilot.style_choice, ShipPilot.Style.AUTO)
	assert_eq(ship.ship_pilot.objective.target_id(), &"ship:Ship")

func test_the_panel_line_says_what_came():
	var said: String = _root.spawn_hostile(&"starter")
	var ship := _newest()
	assert_eq(said, "HOSTILE STARTER SHUTTLE · SKILL %.1f · AUTO" % ship.ship_pilot.skill)

func test_hostiles_come_from_alternate_sides():
	var first := _spawn()
	var second := _spawn()
	var view := _starter.exterior.global_transform
	var side_of := func(s: Ship) -> float:
		return (view.affine_inverse() * s.exterior.global_position).x
	assert_lt(float(side_of.call(first)) * float(side_of.call(second)), 0.0, "one each side of your nose")
	for s: Ship in [first, second]:
		var dir := (s.exterior.global_position - view.origin).normalized()
		assert_almost_eq(rad_to_deg(dir.angle_to(-view.basis.z)), 30.0, 1.0, "30° off your nose")

func test_unknown_ship_is_refused():
	assert_eq(_root.spawn_hostile(&"nothing"), "NO SHIP CALLED nothing")
	assert_eq(_fleet.ships().size(), 1)

func test_brackets_show_an_unlisted_hostile_with_its_hull():
	var ship := _spawn()
	assert_false(_starter.fire_control.list.has(Weapons.ship_id(ship)), "not listed")
	var t := _starter.pilot.build_telemetry()
	var found := {}
	for b: TargetBrackets in _root.target_brackets:
		b.render(t)
		for m in b.marks:
			if m["hostile"]:
				found = m
	assert_false(found.is_empty(), "a hostile bracket is drawn")
	assert_eq(found.get("index"), 0, "unnumbered")
	assert_string_contains(str(found.get("text")), "HULL 100%")

func test_hold_with_a_hostile_warns():
	var ship := _spawn()
	_starter.fire_control.set_orders(FireControl.Orders.HOLD)
	var t := _starter.pilot.build_telemetry()
	assert_true(t.hostile_on_hold)
	_root.weapons_strip.render(t)
	assert_eq(_root.weapons_strip.orders_text(), "HOSTILE · WEAPONS ON HOLD")
	_starter.fire_control.set_orders(FireControl.Orders.ENGAGE)
	assert_false(_starter.pilot.build_telemetry().hostile_on_hold, "engaged: no warning")
	_starter.fire_control.set_orders(FireControl.Orders.HOLD)
	ship.ship_pilot.on = false
	assert_false(_starter.pilot.build_telemetry().hostile_on_hold, "a hostile not out for you: no warning")

func test_f8_refuses_a_hostile():
	_spawn()
	assert_false(_root.board_nearest())
	assert_same(_root.aboard, _starter)
	assert_eq(_root.warp_panel.toast_label.text, "HOSTILE SHIP")

func test_f2_reads_out_the_hostile():
	var ship := _spawn()
	var readout: PilotReadout = _root.pilot_readout
	assert_false(readout.visible)
	_key(readout, PilotReadout.KEY)
	assert_true(readout.visible)
	readout.refresh()
	assert_string_contains(readout.text, "STARTER SHUTTLE")
	assert_string_contains(readout.text, "HOSTILE")
	assert_string_contains(readout.text, "HULL 100%")
	assert_string_contains(readout.text, "skill %.1f" % ship.ship_pilot.skill)
	assert_eq(readout.anchor_left, 1.0, "on the right, clear of the controls card")
	assert_eq(readout.grow_horizontal, Control.GROW_DIRECTION_BEGIN, "growing in from the edge")
	_key(_root.spawn_panel, SpawnPanel.KEY)
	assert_false(readout.visible, "another dev panel shuts it")

func test_the_readout_keys_set_style_skill_and_side():
	var ship := _spawn()
	var readout: PilotReadout = _root.pilot_readout
	_key(readout, PilotReadout.KEY)
	readout.refresh()
	var skill := ship.ship_pilot.skill
	_key(readout, KEY_EQUAL)
	assert_almost_eq(ship.ship_pilot.skill, minf(skill + 0.1, 1.0), 0.0001)
	_key(readout, KEY_MINUS)
	_key(readout, KEY_MINUS)
	assert_almost_eq(ship.ship_pilot.skill, maxf(skill - 0.1, 0.0), 0.0001)
	_key(readout, KEY_S)
	assert_eq(ship.ship_pilot.style_choice, ShipPilot.Style.STAND_OFF)
	_key(readout, KEY_H)
	assert_eq(ship.side, Sides.CREW)
	assert_false(ship.ship_pilot.on, "a crew ship's pilot lets go")
	_key(readout, KEY_H)
	assert_eq(ship.side, Sides.HOSTILE)
	assert_true(ship.ship_pilot.on)
	assert_eq(ship.ship_pilot.objective.target_id(), &"ship:Ship", "hostile again, it engages you")
