extends GutTest

## Handing your ship to its pilot (hostile ships spec §9): P at the helm hands
## it over and takes it back, and so does any stick or translation input; it
## fights the hostile listed first, or the nearest, and holds station with
## none; it puts back the orders it found; the weapons station does not hold a
## ship the pilot flies; the computer's PILOT page switches it and picks its
## style. In the real flight scene.

var _root: Node
var _ship: Ship
var _controls: PilotControls
var _pilot: ShipPilot
var _hostile: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.save_enabled = false

func after_each():
	for action in [&"move_forward", &"pitch_up"]:
		Input.action_release(action)

## The starter, you seated at its helm.
func _start() -> void:
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.aboard
	_controls = _ship.get_node("PilotControls")
	_pilot = _ship.ship_pilot
	_controls.set_seated(true)

## A second starter `off` ahead (your axes), hostile; its own pilot left off.
func _spawn_hostile(off := Vector3(0, 0, -800)) -> void:
	var b := _ship.exterior.global_basis
	var place := Transform3D(b, _ship.exterior.global_position + b * off)
	_hostile = _root.fleet.spawn(_root._starter_grid(), place)
	_hostile.side = Sides.HOSTILE
	await wait_process_frames(2)

func _key_p() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_P
	ev.pressed = true
	return ev

func _motion(relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	return ev

func test_p_hands_over_and_hands_back():
	await _start()
	await _spawn_hostile()
	watch_signals(_pilot)
	_controls.handle(_key_p())
	assert_true(_pilot.on, "P hands it over")
	assert_not_null(_pilot.objective)
	assert_eq(_pilot.objective.target_id(), Weapons.ship_id(_hostile), "out for the hostile")
	assert_eq(_pilot.skill, PilotValues.YOUR_SKILL)
	assert_eq(_controls.build_telemetry().ai_pilot, "AI PILOT · AUTO")
	_controls.handle(_key_p())
	assert_false(_pilot.on, "P again takes it back")
	assert_signal_emitted(_pilot, "handed_back")
	assert_eq(_controls.build_telemetry().ai_pilot, "")

func test_the_hud_names_the_style():
	await _start()
	_pilot.style_choice = ShipPilot.Style.BRAWLER
	_pilot.fight_for_you()
	assert_eq(_controls.build_telemetry().ai_pilot, "AI PILOT · BRAWLER")
	var panel := VelocityPanel.new()
	add_child_autofree(panel)
	panel.render(_controls.build_telemetry())
	assert_true(panel.hold_label.text.contains("AI PILOT · BRAWLER"), "on the band: %s" % panel.hold_label.text)

func test_stick_releases_the_held_velocity():
	await _start()
	_pilot.fight_for_you()
	assert_true(_ship.flight_computer.velocity_hold, "the pilot holds a velocity")
	_controls.handle(_motion(Vector2(0.0, -40.0)))
	assert_false(_pilot.on, "the stick takes it back")
	assert_false(_ship.flight_computer.velocity_hold, "the same frame, the hold is let go")
	await wait_process_frames(1)
	assert_false(_pilot.on, "and the stick flies it")

func test_a_translation_key_takes_it_back():
	await _start()
	_pilot.fight_for_you()
	Input.action_press(&"move_forward")
	await wait_process_frames(1)
	assert_false(_pilot.on, "W takes it back")
	assert_false(_ship.flight_computer.velocity_hold)

func test_a_still_stick_leaves_it_flying():
	await _start()
	_pilot.fight_for_you()
	await wait_process_frames(3)
	assert_true(_pilot.on, "no input, no takeback")

func test_orders_come_back():
	await _start()
	await _spawn_hostile()
	_ship.fire_control.set_orders(FireControl.Orders.HOLD)
	_pilot.fight_for_you()
	_pilot.tick(PilotValues.TACTICS_EVERY)
	assert_eq(_ship.fire_control.orders, FireControl.Orders.ENGAGE, "it fights")
	_pilot.on = false
	assert_eq(_ship.fire_control.orders, FireControl.Orders.HOLD, "and leaves them as it found them")

func test_the_first_listed_hostile_comes_first():
	await _start()
	await _spawn_hostile(Vector3(0, 0, -600))
	var near := _hostile
	await _spawn_hostile(Vector3(0, 0, -1500))
	var listed := _hostile
	_ship.fire_control.mark(Weapons.ship_id(listed))
	_pilot.fight_for_you()
	assert_eq(_pilot.objective.target_id(), Weapons.ship_id(listed), "the one listed, not the nearer")
	_pilot.on = false
	_ship.fire_control.clear()
	_pilot.fight_for_you()
	assert_eq(_pilot.objective.target_id(), Weapons.ship_id(near), "none listed: the nearest")

func test_a_crew_ship_is_not_a_foe():
	await _start()
	await _spawn_hostile()
	_hostile.side = Sides.CREW
	_pilot.fight_for_you()
	assert_eq(_pilot.intent, &"holding_station", "a ship of your own side is not fought")

func test_no_hostile_holds_station():
	await _start()
	_pilot.fight_for_you()
	assert_true(_pilot.on)
	assert_true(_ship.flight_computer.velocity_hold)
	assert_eq(_ship.flight_computer.held_velocity, Vector3.ZERO, "it stops where it is")
	assert_eq(_pilot.intent, &"holding_station")
	await _spawn_hostile()
	_pilot.tick(PilotValues.ASSESS_EVERY)
	assert_not_null(_pilot.objective, "it looks again")
	assert_eq(_pilot.objective.target_id(), Weapons.ship_id(_hostile), "and takes the hostile that came")

func test_your_pilot_does_not_follow():
	await _start()
	await _spawn_hostile()
	_pilot.fight_for_you()
	_pilot.tick(PilotValues.TACTICS_EVERY)
	var b := _ship.exterior.global_basis
	_hostile.exterior.global_position = _ship.exterior.global_position + b * Vector3(0, 0, -6000)
	await wait_physics_frames(2)
	_pilot.tick(PilotValues.TACTICS_EVERY)
	assert_eq(_pilot.intent, &"holding_station", "out of contact, it does not pursue")
	assert_eq(_ship.flight_computer.held_velocity, Vector3.ZERO)

func test_the_station_without_the_hold():
	_root.starter_ship = "warden"
	await _start()
	var station: WeaponsStation
	for s in _ship.seats():
		if s is WeaponsStation:
			station = s
	assert_not_null(station, "the Warden has a weapons station")
	var director: CameraDirector = _root.get_node("CameraDirector")
	_pilot.fight_for_you()
	director.sit(station)
	await wait_for_signal(director.transition_finished, 3)
	var fc := _ship.flight_computer
	assert_false(fc.gunner_hold, "the pilot flies on while you aim")
	assert_true(_pilot.on)
	await wait_physics_frames(2)
	assert_true(fc.velocity_hold, "and it still writes")
	_pilot.on = false
	assert_true(fc.gunner_hold, "pilot off, the station holds the ship")
	_pilot.fight_for_you()
	assert_false(fc.gunner_hold, "on again while sat, the hold drops")

func test_the_pilot_page():
	await _start()
	var page := PilotPage.new()
	var ctx := ComputerContext.new()
	ctx.ship_pilot = _pilot
	assert_eq(page.title(), "PILOT")
	assert_eq(page.lit(ctx), [&"prev", &"big", &"next"] as Array[StringName])
	assert_eq(page.lit(ComputerContext.new()), [] as Array[StringName], "no pilot, all dark")
	assert_eq(page.lines(ctx)[0], "PILOT · OFF")
	page.press(&"big", ctx)
	assert_true(_pilot.on, "big hands it over")
	assert_eq(page.lines(ctx)[0], "PILOT · ON")
	assert_eq(page.big_colour(ctx), &"go")
	page.press(&"big", ctx)
	assert_false(_pilot.on, "and takes it back")
	assert_eq(page.lines(ctx)[1], "STYLE · AUTO")
	for want in [ShipPilot.Style.STAND_OFF, ShipPilot.Style.BRAWLER, ShipPilot.Style.AUTO]:
		page.press(&"next", ctx)
		assert_eq(_pilot.style_choice, want)
	page.press(&"prev", ctx)
	assert_eq(_pilot.style_choice, ShipPilot.Style.BRAWLER)
	assert_eq(page.lines(ctx)[1], "STYLE · BRAWLER")
	for line in page.lines(ctx):
		assert_lte(line.length(), WeaponsPage.PAGE_COLUMNS, "fits the table's screen: %s" % line)

func test_the_armed_ships_table_has_the_pilot_page():
	await _start()
	var tables: Array = _ship.interior_builder.computers()
	assert_gt(tables.size(), 0)
	var c: ShipComputer = tables[0]
	var found: PilotPage
	for p in c.pages:
		if p is PilotPage:
			found = p
	assert_not_null(found, "beside WEAPONS")
	assert_same(c.ctx.ship_pilot, _pilot)
