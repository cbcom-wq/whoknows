extends GutTest

## ShipPilot (hostile ships spec §5): the AI pilot on every ship flies through
## the flight computer and fights through fire control, never by touching the
## hull. In the real flight scene, with a second starter spawned hostile and set
## on yours.

## A flight computer that writes down what it was asked.
class SpyFlight extends FlightComputer:
	var inputs: Array = []
	var holds: Array = []

	func set_pilot_input(translate: Vector3, rotate: Vector3, boost: bool) -> void:
		inputs.append([translate, rotate, boost])
		super(translate, rotate, boost)

	func hold_velocity(v_world: Vector3) -> void:
		holds.append(v_world)
		super(v_world)

var _root: Node
var _starter: Ship
var _hostile: Ship
var _pilot: ShipPilot

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.save_enabled = false
	add_child_autofree(_root)
	_starter = _root.get_node("Ship")

## A second starter at `off` (the starter's own axes) from yours, turned as it
## is, made hostile; its pilot not yet engaged.
func _spawn(off: Vector3) -> void:
	var b := _starter.exterior.global_basis
	var place := Transform3D(b, _starter.exterior.global_position + b * off)
	_hostile = _root.fleet.spawn(_root._starter_grid(), place)
	_hostile.side = Sides.HOSTILE
	_pilot = _hostile.ship_pilot
	await wait_process_frames(2)

func _engage() -> void:
	_pilot.engage(Weapons.ship_id(_starter))

func _range() -> float:
	return Weapons.point_of(_hostile.exterior).distance_to(Weapons.point_of(_starter.exterior))

func _spy() -> SpyFlight:
	var spy: SpyFlight = autofree(SpyFlight.new())
	_pilot.flight = spy
	return spy

func _set_computer(health: float) -> void:
	var hp: float = _hostile.damage.component_hp[&"computer"]
	_hostile.damage.component_damage[&"computer"] = hp * (1.0 - health)

func test_every_ship_has_a_pilot_off_until_engaged():
	await _spawn(Vector3(0, 0, -600))
	assert_not_null(_starter.ship_pilot, "the starter has one")
	assert_same(_starter.get_node("ShipPilot"), _starter.ship_pilot)
	assert_same(_pilot.flight, _hostile.flight_computer)
	assert_same(_pilot.fire_control, _hostile.fire_control)
	assert_false(_starter.ship_pilot.on, "off on a crew ship")
	assert_false(_pilot.on, "a side alone does not turn it on")
	_engage()
	assert_true(_pilot.on)
	assert_eq(_pilot.objective.target_id(), &"ship:Ship")

func test_drives_only_through_the_flight_computer():
	await _spawn(Vector3(0, 0, -600))
	var spy := _spy()
	_engage()
	await wait_physics_frames(30)
	assert_gt(spy.inputs.size(), 0, "it works the stick")
	assert_gt(spy.holds.size(), 0, "and holds a velocity")
	var text := FileAccess.get_file_as_string("res://src/pilot/ship_pilot.gd")
	assert_ne(text, "", "the script was read")
	for cheat in ["linear_velocity =", "angular_velocity =", "apply_central", "apply_torque",
			"apply_force", "apply_impulse", "global_transform =", ".target ="]:
		assert_false(text.contains(cheat), "the pilot never writes %s" % cheat)

func test_turns_its_best_face_to_the_target():
	await _spawn(Vector3(-800, 0, 0))   # yours is off its starboard
	_engage()
	await wait_physics_frames(480)
	var to_target := Weapons.point_of(_starter.exterior) - Weapons.point_of(_hostile.exterior)
	var face := _hostile.exterior.global_basis * _pilot.face
	assert_lt(face.angle_to(to_target), deg_to_rad(15.0), "its best face is on the target")
	var bears := false
	for t in _hostile.turrets:
		bears = bears or t.can_engage(_starter.exterior)
	assert_true(bears, "a turret can engage it")

func test_its_style_holds_steady():
	await _spawn(Vector3(0, 0, -800))
	_engage()
	var styles := []
	for i in 8:
		_pilot.tick(PilotValues.ASSESS_EVERY)
		styles.append(_pilot.style)
	for s in styles:
		assert_eq(s, styles[0], "the same read of the same fight: %s" % [styles])

func test_closes_to_brawl_and_holds_range():
	await _spawn(Vector3(0, 0, -1500))
	_pilot.style_choice = ShipPilot.Style.BRAWLER
	_engage()
	await wait_physics_frames(2400)
	assert_eq(_pilot.style, ShipPilot.Style.BRAWLER)
	assert_almost_eq(_range(), PilotValues.BRAWL_RANGE, PilotValues.BRAWL_BAND,
		"40 s on, it is in the brawl band")

func test_jinks_when_fired_on():
	await _spawn(Vector3(0, 0, -800))
	_engage()
	await wait_physics_frames(60)
	# The jinks it makes every few seconds anyway, out of the way: this one
	# must come from the bolt.
	_pilot._jink_in = 1e9
	await wait_physics_frames(int(PilotValues.TACTICS_EVERY * 60.0) + 2)
	assert_ne(_pilot.intent, &"jinking", "not jinking yet")
	var before := _hostile.flight_computer.held_velocity
	var from := Weapons.point_of(_starter.exterior)
	var dir := (Weapons.point_of(_hostile.exterior) - from).normalized()
	var ex: Array[RID] = [_starter.exterior.get_rid()]
	_root.bolt_pool.fire(WeaponValues.LIGHT, from + dir * 20.0, dir, _starter.exterior.linear_velocity,
		_starter, ex)
	var jinked := false
	var frames := int((PilotSkill.new(_pilot.skill).reaction + 0.5) * 60.0)
	for i in frames:
		await wait_physics_frames(1)
		var change := _hostile.flight_computer.held_velocity - before
		var across := change - dir * change.dot(dir)
		if _pilot.intent == &"jinking" and across.length() > 2.0:
			jinked = true
			break
	assert_true(jinked, "it jinks across the line of fire in time")

func test_marks_and_engages():
	await _spawn(Vector3(0, 0, -600))
	_engage()
	_pilot.tick(PilotValues.TACTICS_EVERY)
	assert_eq(_hostile.fire_control.list[0], &"ship:Ship")
	assert_eq(_hostile.fire_control.orders, FireControl.Orders.ENGAGE)

func test_a_wrecked_computer_stops_the_pilot_not_the_guns():
	await _spawn(Vector3(0, 0, -600))
	var spy := _spy()
	_engage()
	_pilot.tick(PilotValues.TACTICS_EVERY)
	assert_true(spy.velocity_hold)
	var inputs := spy.inputs.size()
	var holds := spy.holds.size()
	_set_computer(0.0)
	for i in 10:
		_pilot.tick(1.0 / 60.0)
	assert_eq(spy.inputs.size(), inputs, "no stick")
	assert_eq(spy.holds.size(), holds, "no hold")
	assert_false(spy.velocity_hold, "the hold it had is let go")
	assert_eq(_pilot.intent, &"no_pilot")
	assert_eq(_hostile.fire_control.orders, FireControl.Orders.ENGAGE, "the guns keep their orders")
	assert_eq(_hostile.fire_control.list[0], &"ship:Ship", "and their list")
	_hostile.repair_component(&"computer", 1e9)
	_pilot.tick(PilotValues.TACTICS_EVERY)
	assert_gt(spy.inputs.size(), inputs, "mended, it flies again")
	assert_ne(_pilot.intent, &"no_pilot")

func test_a_damaged_computer_halves_skill():
	await _spawn(Vector3(0, 0, -600))
	_pilot.skill = 0.8
	assert_almost_eq(_pilot.effective_skill(), 0.8, 0.0001)
	_set_computer(0.4)
	assert_almost_eq(_pilot.effective_skill(), 0.8 * PilotValues.COMPUTER_DAMAGED_SKILL, 0.0001)

func test_off_lets_go():
	await _spawn(Vector3(0, 0, -600))
	assert_eq(_hostile.fire_control.orders, FireControl.Orders.HOLD)
	_engage()
	_pilot.tick(PilotValues.TACTICS_EVERY)
	assert_true(_hostile.flight_computer.velocity_hold)
	assert_eq(_hostile.fire_control.orders, FireControl.Orders.ENGAGE)
	_pilot.on = false
	assert_false(_hostile.flight_computer.velocity_hold, "the hold is let go")
	assert_eq(_hostile.fire_control.orders, FireControl.Orders.HOLD, "the orders it found")
	assert_false(_hostile.fire_control.list.has(&"ship:Ship"), "and its mark gone")
	assert_eq(_pilot.intent, &"")

func test_targets_its_objectives_ship():
	await _spawn(Vector3(0, 0, -600))
	assert_false(_pilot.targets(_starter), "off, nobody")
	_engage()
	assert_true(_pilot.targets(_starter))
	assert_true(_pilot.targets(_starter.exterior), "its hull too")
	assert_false(_pilot.targets(_hostile))

func test_pilot_round_trips():
	await _spawn(Vector3(0, 0, -600))
	_pilot.skill = 0.8
	_pilot.style_choice = ShipPilot.Style.BRAWLER
	_engage()
	var d := _pilot.to_dict()
	var again: ShipPilot = autofree(ShipPilot.new())
	again.from_dict(d)
	assert_true(again.on)
	assert_almost_eq(again.skill, 0.8, 0.0001)
	assert_eq(again.style_choice, ShipPilot.Style.BRAWLER)
	assert_eq(again.objective.target_id(), &"ship:Ship")

func test_the_ship_saves_its_pilot():
	await _spawn(Vector3(0, 0, -600))
	_pilot.skill = 0.3
	_engage()
	var d := _hostile.to_dict(_root.get_node("Universe"))
	assert_true(d.has("pilot"))
	_pilot.on = false
	_pilot.skill = 0.5
	_hostile.restore_aboard(d)
	assert_true(_pilot.on)
	assert_almost_eq(_pilot.skill, 0.3, 0.0001)

func test_after_a_load_off_still_lets_go():
	await _spawn(Vector3(0, 0, -600))
	_engage()
	_pilot.tick(PilotValues.TACTICS_EVERY)
	var d := _hostile.to_dict(_root.get_node("Universe"))
	_pilot.on = false
	_hostile.restore_aboard(d)
	assert_eq(_hostile.fire_control.list, [&"ship:Ship"] as Array[StringName])
	assert_eq(_hostile.fire_control.orders, FireControl.Orders.ENGAGE)
	_pilot.on = false
	assert_eq(_hostile.fire_control.orders, FireControl.Orders.HOLD, "the orders from before it took over")
	assert_true(_hostile.fire_control.list.is_empty(), "and its mark gone")

func test_a_hostile_bolt_starts_the_clock():
	await _spawn(Vector3(0, 0, -600))
	assert_eq(_starter.since_hostile_fire, INF)
	var at := Weapons.point_of(_starter.exterior)
	var crew := Hit.make(at, Vector3.UP, Vector3.DOWN, Vector3.ZERO, _starter)
	_starter._on_hull_hit(crew)
	assert_eq(_starter.since_hostile_fire, INF, "a crew ship's bolt is not hostile fire")
	var hit := Hit.make(at, Vector3.UP, Vector3.DOWN, Vector3.ZERO, _hostile)
	_starter._on_hull_hit(hit)
	assert_eq(_starter.since_hostile_fire, 0.0)
	await wait_physics_frames(3)
	assert_gt(_starter.since_hostile_fire, 0.0, "and it runs")

func test_the_helm_stands_aside_while_the_pilot_flies():
	var spy: SpyFlight = autofree(SpyFlight.new())
	var helm := _starter.pilot
	helm._flight = spy
	helm.seated = true
	helm._process(1.0 / 60.0)
	assert_eq(spy.inputs.size(), 1, "seated, the helm writes the stick")
	_starter.ship_pilot.on = true
	helm._process(1.0 / 60.0)
	assert_eq(spy.inputs.size(), 1, "the pilot on, it writes nothing")
	_starter.ship_pilot.on = false
	helm.seated = false
