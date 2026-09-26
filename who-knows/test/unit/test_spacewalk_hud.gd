extends GutTest

## The spacewalk's HUD and sounds (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §6, §8.3), in the real scene.

const DT := 1.0 / 60.0

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _hud: HudRoot

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_hud = _root.get_node("HudRoot")

## Out on a spacewalk with a full suit, unless `charge` says otherwise.
func _out(charge := SuitCell.CAPACITY) -> void:
	_avatar.suit_cell.charge = charge
	_avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis.IDENTITY, Vector3(0, 0, 12)), Vector3.ZERO,
		_ship.exterior)

func test_on_a_spacewalk_the_hud_is_the_suits():
	assert_false(_hud.is_armed())
	_out()
	assert_true(_hud.is_armed(), "the suit is the active vehicle")
	_avatar.enter_plating(_ship.interior, Transform3D(Basis.IDENTITY, _ship.interior.to_global(Vector3(0, -0.95, 6))),
		0.0, Vector3.ZERO, Quaternion.IDENTITY)
	assert_false(_hud.is_armed(), "and dark again aboard")

func test_the_suit_reports_speed_relative_to_your_ship():
	_out()
	_ship.exterior.linear_velocity = Vector3(2, 0, 0)
	_ship.exterior.angular_velocity = Vector3.ZERO
	_avatar.velocity = Vector3(3, 0, 0)
	var t := _avatar.build_telemetry()
	assert_almost_eq(t.speed, 1.0, 0.001)
	assert_eq(t.assist_enabled, _avatar.suit_assist)

func test_the_suit_knows_the_way_home():
	_out()
	var home := Vector3(1, 2, 3)
	_avatar.beacon_source = func() -> Vector3: return home
	var t := _avatar.build_telemetry()
	assert_true(t.has_beacon)
	assert_eq(t.beacon, home)

## Quantum energy spec §12: the suit reports its cell as the HUD's energy --
## SUIT, the charge out of 100, no low-power line, and its level.
func test_the_suit_reports_its_charge():
	_out(64.7)
	var t := _avatar.build_telemetry()
	assert_true(t.has_energy)
	assert_eq(t.energy_label, &"SUIT")
	assert_eq(t.energy, 64, "whole QE, never rounded up past what is there")
	assert_eq(t.energy_capacity, 100)
	assert_eq(t.energy_line, 0)
	assert_eq(t.energy_state, &"ok")
	_avatar.suit_cell.charge = 9.5
	assert_eq(_avatar.build_telemetry().energy_state, &"critical")
	_avatar.suit_cell.charge = 0.0
	assert_eq(_avatar.build_telemetry().energy_state, &"dry")

func test_the_band_shows_the_suit_on_a_spacewalk():
	_out(20.0)
	var panel: EnergyPanel = _root.get_node("HudRoot/Screen/Band/Row/EnergyPanel")
	panel.render(_avatar.build_telemetry())
	assert_eq(panel.energy_label.text, "SUIT 20%")
	assert_eq(panel.status_label.text, "SUIT LOW")

func test_the_marker_is_on_the_hud():
	var marker := _root.get_node_or_null("HudRoot/Screen/AirlockMarker")
	assert_true(marker is AirlockMarker, "AirlockMarker survived the parse")

func _warm() -> void:
	Synth.warm_up()
	var deadline := Time.get_ticks_msec() + 20000
	while not Synth.is_warm() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func test_outside_you_hear_your_breathing_and_your_thrusters():
	await _warm()
	var sounds: SuitSounds = _avatar.get_node("SuitSounds")
	sounds.tick()
	assert_false(sounds.breathing(), "aboard, no helmet sounds")
	_out()
	sounds.tick()
	assert_true(sounds.breathing())
	assert_false(sounds.thrusting())
	_avatar.suit_step(DT, Vector3(0, 0, -1))
	sounds.tick()
	assert_true(sounds.thrusting())
	for p in sounds.get_children():
		assert_eq((p as AudioStreamPlayer).bus, AudioBuses.SUIT)

## Quantum energy spec §9: the suit's warning chime as the cell falls below 25,
## and again below 10 -- once each, not every frame.
func test_the_suit_chimes_at_25_and_at_10():
	await _warm()
	var sounds: SuitSounds = _avatar.get_node("SuitSounds")
	_ship.exterior.linear_velocity = Vector3.ZERO
	_ship.exterior.angular_velocity = Vector3.ZERO
	_out(26.0)
	var chime: AudioStreamPlayer = sounds.get_node("Chime")
	sounds.tick()
	assert_false(chime.playing, "not above 25")
	_avatar.suit_cell.charge = 24.9
	sounds.tick()
	assert_true(chime.playing, "below 25")
	assert_same(chime.stream, Synth.sound(&"warning_chime"))
	chime.stop()
	sounds.tick()
	assert_false(chime.playing, "once")
	_avatar.suit_cell.charge = 9.9
	sounds.tick()
	assert_true(chime.playing, "below 10")
	chime.stop()
	_avatar.suit_cell.charge = 0.0
	sounds.tick()
	assert_false(chime.playing, "dry is quiet: the emergency cell is already bringing you home")
