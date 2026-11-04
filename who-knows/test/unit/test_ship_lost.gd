extends GutTest

## Losing your ship (hostile ships spec §8.3, §8.4): aboard a ship that is
## destroyed, the screen goes white, then black, SHIP LOST, and the game goes
## back to the last save; on a spacewalk you live, until you are downed with
## nowhere to wake: SUIT LOST. And no save is written while a hostile is out
## for you, or for ENGAGED_CALM after it last hit you.

var _root: Node
var _starter: Ship
var _fleet: Fleet
var _reloads := 0

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_starter = _root.get_node("Ship")
	_fleet = _root.fleet
	_reloads = 0
	# Never the real reload in a test: it would load the scene over GUT's.
	_root.reload = func() -> void: _reloads += 1
	await wait_process_frames(2)

func _spawn(off: Vector3) -> Ship:
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + off)
	return _fleet.spawn(_root._starter_grid(), place)

func _hostile() -> Ship:
	var said: String = _root.spawn_hostile(&"starter")
	assert_true(said.begins_with("HOSTILE "), said)
	var ships := _fleet.ships()
	return ships[ships.size() - 1]

## Past every section's hp in one hit: spill-over takes HULL % to 0.
func _wreck(ship: Ship) -> void:
	var cell: Vector3i = ship.damage.sections_of.keys()[0]
	ship.take_damage_many({cell: 1e9})

## The gate past its settling spell, so busy() says what is busy now.
func _settled() -> void:
	_root.save_gate.tick(SaveGate.SETTLE + 0.1)

## A hostile bolt hit the ship you are aboard `ago` seconds ago.
func _hit(ship: Ship, ago := 0.0) -> void:
	ship.since_hostile_fire = ago
	_root.since_fired_on = ago

func test_your_ship_destroyed_loses_the_game():
	_root.save_enabled = true
	_root.save_path = "user://test_ship_lost/never.json"
	var ship := _spawn(Vector3(300, 0, 0))
	_root.board_at_helm(ship)
	assert_true(_root.you_aboard(ship), "seated at its helm")
	assert_false(_root.you_aboard(_starter))
	watch_signals(_root)
	_wreck(ship)
	assert_signal_emit_count(_root, "lost", 1)
	assert_eq(get_signal_parameters(_root, "lost"), ["SHIP LOST"])
	assert_false(_root.save_enabled, "no save after a death")
	assert_false(_root.save_now(), "none written")
	var screen: LostScreen = _root.lost_screen
	assert_not_null(screen)
	assert_true(screen.playing, "the white, the black, SHIP LOST")
	assert_eq(screen.text, "SHIP LOST")
	await wait_process_frames(3)
	assert_true(is_instance_valid(_root._avatar), "you are never freed with the ship")
	_root.lose("SHIP LOST")
	assert_signal_emit_count(_root, "lost", 1, "once")
	assert_eq(_reloads, 0, "not before the screen is done")
	await wait_seconds(LostScreen.TOTAL + 0.3)
	assert_eq(_reloads, 1, "back to the last save")
	assert_false(FileAccess.file_exists(_root.save_path), "nothing was written")

func test_the_screen_goes_white_then_black_then_says_so():
	var screen := LostScreen.new()
	add_child_autofree(screen)
	watch_signals(screen)
	screen.play("SHIP LOST")
	screen.advance(LostScreen.WHITE_IN)
	assert_eq(screen.color, SpacePalette.WARP, "white, in the core's flash")
	assert_false(screen.label.visible)
	screen.advance(LostScreen.TO_BLACK)
	assert_eq(screen.color, HudPalette.BLACKOUT, "then black")
	assert_true(screen.label.visible, "SHIP LOST")
	assert_eq(screen.label.text, "SHIP LOST")
	assert_signal_emit_count(screen, "finished", 0)
	screen.advance(LostScreen.TEXT_FOR)
	assert_signal_emit_count(screen, "finished", 1)
	assert_almost_eq(LostScreen.WHITE_IN + LostScreen.TO_BLACK + LostScreen.TEXT_FOR, LostScreen.TOTAL, 1e-6)

func test_a_spacewalk_survives_your_ship_but_not_nowhere_to_wake():
	# Your ship far from the starter, and you 400 m beyond it: no other ship is
	# near enough for your suit to belong to.
	var ship := _spawn(Vector3(0, 0, -3000))
	_root.board(ship, true)
	var avatar: Avatar = _root._avatar
	var out := ship.exterior.global_transform.translated(Vector3(0, 0, -400))
	avatar.enter_suit(ship.outside, out, Vector3.ZERO, ship.exterior)
	assert_false(_root.you_aboard(ship), "outside it")
	watch_signals(_root)
	_wreck(ship)
	await wait_process_frames(3)
	assert_false(is_instance_valid(ship), "your ship is gone")
	assert_signal_emit_count(_root, "lost", 0, "you live")
	assert_true(is_instance_valid(_root.aboard), "aboard is never a freed ship")
	assert_null(_root.home, "nowhere to wake")
	assert_eq(avatar.health.current, Avatar.MAX_HEALTH, "the blast never reached 400 m")
	avatar.health.take(999)
	await wait_physics_frames(2)
	assert_not_null(avatar.downed, "downed")
	avatar.downed.tick(Downed.FADE + 0.01, false)
	assert_signal_emit_count(_root, "lost", 0, "not while blacking out")
	avatar.downed.tick(Downed.BLACK_AT_MOST + 0.01, false)
	assert_eq(avatar.downed.step, Downed.Step.WAKING)
	assert_signal_emit_count(_root, "lost", 1)
	assert_eq(get_signal_parameters(_root, "lost"), ["SUIT LOST"])
	assert_eq(avatar.mode, Avatar.Mode.SUIT, "never put aboard anywhere")

func test_a_destroyed_starter_is_nowhere_to_wake():
	var avatar: Avatar = _root._avatar
	var out := _starter.exterior.global_transform.translated(Vector3(0, 0, -400))
	avatar.enter_suit(_starter.outside, out, Vector3.ZERO, _starter.exterior)
	watch_signals(_root)
	_wreck(_starter)
	await wait_process_frames(3)
	assert_signal_emit_count(_root, "lost", 0, "you live")
	avatar.health.take(999)
	await wait_physics_frames(2)
	avatar.downed.tick(Downed.FADE + 0.01, false)
	avatar.downed.tick(Downed.BLACK_AT_MOST + 0.01, false)
	assert_eq(get_signal_parameters(_root, "lost"), ["SUIT LOST"])

func test_no_save_while_adrift_with_nowhere_to_wake():
	var ship := _spawn(Vector3(0, 0, -3000))
	_root.board(ship, true)
	var avatar: Avatar = _root._avatar
	avatar.enter_suit(ship.outside, ship.exterior.global_transform.translated(Vector3(0, 0, -400)),
		Vector3.ZERO, ship.exterior)
	_wreck(ship)
	await wait_process_frames(3)
	_settled()
	assert_eq(_root.save_gate.busy(), "nowhere to wake", "a save there would come back to the same end")

func test_no_save_under_attack():
	var hostile := _hostile()
	_settled()
	assert_eq(_root._under_attack(), "under attack", "engaging")
	assert_eq(_root.save_gate.busy(), "under attack")
	# Out of contact: it pursues where it last saw you.
	var pilot := hostile.ship_pilot
	var far := hostile.exterior.global_position + (hostile.exterior.global_position
		- _starter.exterior.global_position).normalized() * 6000.0
	pilot.objective.step(far, get_tree(), 1.0)
	assert_true(pilot.objective.pursuing(), "pursuing")
	assert_eq(_root._under_attack(), "under attack", "still, while it pursues")
	_hit(_starter)
	pilot.objective.step(far, get_tree(), PilotValues.PURSUE_FOR + 1.0)
	assert_true(pilot.objective.done(), "it gave up")
	assert_eq(_root._under_attack(), "under attack", "its last hit is not ENGAGED_CALM old")
	_hit(_starter, PilotValues.ENGAGED_CALM + 0.1)
	assert_eq(_root._under_attack(), "", "escaping is a way out of a fight")
	_settled()
	assert_ne(_root.save_gate.busy(), "under attack")

func test_engaged_follows_you_between_ships():
	var hostile := _hostile()
	var pilot := hostile.ship_pilot
	assert_true(pilot.targets(_starter))
	_hit(_starter)
	await wait_physics_frames(2)
	var other := _spawn(Vector3(200, 0, 0))
	_root.board_at_helm(other)
	assert_same(_root.aboard, other)
	assert_true(pilot.targets(_starter), "it keeps your ship as its target")
	assert_eq(_root._under_attack(), "under attack", "the ship it is out for is 200 m from you")
	# The ship it is out for, 6 km off you and out of its contact: it pursues.
	_starter.exterior.global_position += _starter.exterior.global_basis.z * 6000.0
	var from := hostile.exterior.global_position
	assert_gt(from.distance_to(_starter.exterior.global_position), WeaponValues.CONTACT_RANGE)
	assert_gt(other.exterior.global_position.distance_to(_starter.exterior.global_position), WeaponValues.CONTACT_RANGE)
	pilot.objective.step(from, get_tree(), 1.0)
	assert_true(pilot.objective.pursuing())
	assert_eq(_root._under_attack(), "under attack", "it hit you aboard the other less than ENGAGED_CALM ago")
	_hit(_starter, PilotValues.ENGAGED_CALM + 0.1)
	assert_eq(_root._under_attack(), "", "pursuing a ship out of contact of you, the calm passed")

func test_engaged_on_a_spacewalk():
	var hostile := _hostile()
	var avatar: Avatar = _root._avatar
	avatar.enter_suit(_starter.outside, _starter.exterior.global_transform.translated(Vector3(0, 0, 30)),
		Vector3.ZERO, _starter.exterior)
	hostile.ship_pilot.engage(Weapons.YOU)
	assert_true(hostile.ship_pilot.targets(avatar))
	assert_eq(_root._under_attack(), "under attack", "out for you")

func test_winning_lets_saving_resume():
	var hostile := _hostile()
	_hit(_starter)
	_wreck(hostile)
	await wait_process_frames(3)
	assert_false(is_instance_valid(hostile), "the only hostile is gone")
	assert_eq(_root._under_attack(), "under attack", "not before the calm")
	_hit(_starter, PilotValues.ENGAGED_CALM + 0.1)
	assert_eq(_root._under_attack(), "")

func test_a_crew_ship_is_never_an_attack():
	var ship := _spawn(Vector3(300, 0, 0))
	ship.ship_pilot.engage(Weapons.ship_id(_starter))
	assert_eq(_root._under_attack(), "", "only a hostile's pilot counts")

func test_the_calm_after_a_hit_carries_across_boarding():
	_hit(_starter)
	await wait_physics_frames(2)
	var other := _spawn(Vector3(200, 0, 0))
	_root.board_at_helm(other)
	assert_eq(_root._under_attack(), "under attack")
	await wait_physics_frames(2)
	assert_lt(_root.since_fired_on, 1.0, "the clock runs on, never reset by boarding")
	assert_eq(other.since_hostile_fire, INF)
