extends GutTest

## The starter shuttle's Airlock, in the real scene, stepped by hand
## (docs/superpowers/specs/2026-09-24-airlock-design.md §4).

const DT := 1.0 / 60.0

var _root: Node
var _ship: Ship
var _airlock: Airlock
var _avatar: Avatar

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_airlock = _ship.airlocks.get(Vector3i(0, 0, 3))
	_avatar = _root.get_node("Ship/Interior/Avatar")
	# A charged suit, so the room panel lets you out (quantum energy spec §9);
	# the refusal's own tests empty it.
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	if _airlock != null:
		_airlock.set_physics_process(false)   # stepped by hand below

func _step(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_airlock.tick(DT)

func _stand(at: Vector3) -> void:
	_avatar.position = at

func _open_inner() -> void:
	_airlock.room.corridor_panel.interact(null)
	_step(AirlockCycle.OPEN_TIME + 0.1)

func test_the_starter_has_one_airlock_driving_its_room():
	assert_eq(_ship.airlocks.size(), 1)
	assert_not_null(_airlock)
	assert_eq(_airlock.room.name, "Airlock_0_0_3")
	assert_eq(_airlock.panels().size(), 3, "the room, corridor and hull panels")
	assert_not_null(_airlock.alcove, "and its copy on the hull")

func test_the_panels_prompt_from_the_cycle():
	assert_eq(_airlock.room.corridor_panel.prompt_text(), "Open hatch")
	assert_eq(_airlock.room.room_panel.prompt_text(), "Depressurize")

func test_the_corridor_panel_opens_the_inner_hatch():
	_open_inner()
	assert_eq(_airlock.room.inner_hatch.open_amount, 1.0)
	assert_true(_airlock.room.inner_hatch.collider.disabled, "you can walk through")
	assert_false(_airlock.room.outer_hatch.collider.disabled)

func test_a_cycle_out_opens_the_outer_hatch_onto_vacuum():
	_open_inner()
	_stand(_airlock.room.room_frame.origin)
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	assert_eq(_airlock.room.outer_hatch.open_amount, 1.0)
	assert_eq(_airlock.room.inner_hatch.open_amount, 0.0)
	var readout := _airlock.room.room_panel.readout_text()
	assert_true(readout.begins_with("PRESSURE 0 kPa"), readout)
	assert_true(readout.contains("VACUUM"), readout)
	assert_eq(_airlock.room.outer_hatch.visible_strips(), [&"go"], "the outer hatch may open")
	assert_eq(_airlock.room.inner_hatch.visible_strips(), [&"vacuum"], "vacuum behind the inner hatch")

func test_a_hatch_waits_for_its_doorway_to_clear():
	_open_inner()
	_stand(_airlock.room.inner_frame.origin)
	_airlock.room.room_panel.interact(null)
	_step(1.0)
	assert_eq(_airlock.room.inner_hatch.open_amount, 1.0)
	assert_true(_airlock.room.room_panel.readout_text().contains("CLEAR THE HATCH"))

func test_a_rebuild_keeps_the_airlocks_state():
	_open_inner()
	_stand(_airlock.room.room_frame.origin)
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	var old_room := _airlock.room
	_ship.set_grid(_ship.grid)
	assert_same(_ship.airlocks[Vector3i(0, 0, 3)], _airlock, "the same Airlock")
	assert_ne(_airlock.room, old_room, "driving the rebuilt room")
	assert_eq(_airlock.room.outer_hatch.open_amount, 1.0, "which shows the same state")
	assert_almost_eq(_airlock.cycle.pressure, 0.0, 0.001)

func test_the_motion_warning_reaches_the_panels():
	_ship.exterior.linear_velocity = Vector3(0, 0, 5)
	_step(DT)
	assert_true(_airlock.room.room_panel.readout_text().contains("SHIP MOVING · 5.0 M/S"))
	assert_true(_airlock.room.outer_hatch.warning_shown())

# --- the suit's charge (quantum energy spec §9) ------------------------------

## The room panel will not depressurize while your suit holds under 10 QE: the
## airlock's first refusal in open space.
func test_the_room_panel_refuses_to_let_an_empty_suit_out():
	_avatar.suit_cell.charge = 9.9
	_open_inner()
	_stand(_airlock.room.room_frame.origin)
	_step(DT)
	var panel := _airlock.room.room_panel
	assert_eq(panel.prompt_text(), "Charge suit first")
	assert_eq(panel.readout_text(), "PRESSURE 101 kPa\nCHARGE SUIT")
	assert_eq(panel.button_state(), &"vacuum", "CORAL, as a refusal is")
	assert_true(_airlock.room.corridor_panel.readout_text().contains("CHARGE SUIT"), "on every panel")
	panel.interact(null)
	_step(5.0)
	assert_eq(_airlock.cycle.stage, AirlockCycle.Stage.IDLE, "nothing happens")
	assert_almost_eq(_airlock.cycle.pressure, AirlockCycle.ATMOSPHERE, 0.001, "still pressurized")
	assert_eq(_airlock.room.inner_hatch.open_amount, 1.0)
	assert_eq(_airlock.room.outer_hatch.open_amount, 0.0)

func test_at_10_it_lets_you_out():
	_avatar.suit_cell.charge = SuitCell.GO_OUT_MIN
	_open_inner()
	_stand(_airlock.room.room_frame.origin)
	_step(DT)
	assert_eq(_airlock.room.room_panel.prompt_text(), "Depressurize")
	assert_true(_airlock.room.room_panel.readout_text().contains("READY"))
	assert_eq(_airlock.room.room_panel.button_state(), &"go")
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	assert_eq(_airlock.room.outer_hatch.open_amount, 1.0, "out you go")

## Only going out is refused: an empty suit can always come home.
func test_coming_in_is_never_refused():
	_open_inner()
	_stand(_airlock.room.room_frame.origin)
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	_avatar.suit_cell.charge = 0.0
	_step(DT)
	assert_eq(_airlock.room.room_panel.prompt_text(), "Pressurize")
	assert_true(_airlock.room.room_panel.readout_text().contains("VACUUM"))
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	assert_almost_eq(_airlock.cycle.pressure, AirlockCycle.ATMOSPHERE, 0.001)
	assert_eq(_airlock.room.inner_hatch.open_amount, 1.0)

func test_the_refusal_sounds_the_warning():
	await _warm()
	_avatar.suit_cell.charge = 0.0
	_airlock.room.room_panel.interact(null)
	assert_same(_airlock.player(&"panel").stream, Synth.sound(&"warning_chime"))
	assert_almost_eq(_airlock.player(&"panel").global_position, _airlock.room.room_panel.global_position,
		Vector3.ONE * 0.0001, "at the panel")

## A dry suit (spec §9) is brought to a point 1.5 m outside the outer hatch,
## at its middle -- and, once the hatch is opening, just inside it, so the
## emergency cell floats you in; a closing hatch sends you back out.
func test_a_dry_suits_home_is_1_5_m_outside_the_outer_hatch():
	var hatch := _airlock.alcove.outer_hatch.global_transform
	var outside := Vector3(0, InteriorProps.HATCH_HEIGHT * 0.5, -1.5)
	var inside := Vector3(0, InteriorProps.HATCH_HEIGHT * 0.5, Airlock.ENTRY_DEPTH)
	assert_almost_eq(hatch.affine_inverse() * _airlock.home(), outside, Vector3.ONE * 0.0001)
	_airlock.room.room_panel.interact(null)
	_step(AirlockCycle.CYCLE_TIME - 0.2)
	assert_almost_eq(hatch.affine_inverse() * _airlock.home(), outside, Vector3.ONE * 0.0001, "held while it cycles")
	_step(0.4)
	assert_eq(_airlock.cycle.stage, AirlockCycle.Stage.OPENING)
	assert_almost_eq(hatch.affine_inverse() * _airlock.home(), inside, Vector3.ONE * 0.0001, "in as the bolts draw")
	_step(AirlockCycle.OPEN_TIME)
	assert_almost_eq(hatch.affine_inverse() * _airlock.home(), inside, Vector3.ONE * 0.0001, "in through the open hatch")
	_step(AirlockCycle.AUTO_CLOSE + 0.2)
	assert_eq(_airlock.cycle.stage, AirlockCycle.Stage.SEALING, "nobody came: it closes itself")
	assert_almost_eq(hatch.affine_inverse() * _airlock.home(), outside, Vector3.ONE * 0.0001, "back out, clear of the leaves")

## Going out, the suit learns where home is.
func test_crossing_out_gives_the_suit_its_way_home():
	_open_inner()
	_stand(_airlock.room.room_frame.origin)
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	_stand(_airlock.room.outer_frame * Vector3(0, 0, -0.1))
	_step(DT)
	assert_eq(_avatar.mode, Avatar.Mode.SUIT, "out on a spacewalk")
	assert_true(_avatar.home_source.is_valid())
	assert_almost_eq(_avatar.home_source.call(), _airlock.home(), Vector3.ONE * 0.0001)

func after_each():
	AudioBuses.set_air(1.0)

func _warm() -> void:
	Synth.warm_up()
	var deadline := Time.get_ticks_msec() + 20000
	while not Synth.is_warm() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

## Airlock spec §6: its sounds are positional, on the Ship bus.
func test_the_airlock_sounds_its_cycle_on_the_ship_bus():
	await _warm()
	_airlock.room.room_panel.interact(null)
	_step(0.1)
	var room_player := _airlock.player(&"room")
	assert_not_null(room_player)
	assert_eq(room_player.bus, AudioBuses.SHIP)
	assert_same(room_player.stream, Synth.sound(&"hiss_out"), "the air hisses out")
	assert_same(_airlock.player(&"panel").stream, Synth.sound(&"panel_beep"))

func test_air_carries_sound_only_as_well_as_the_room_pressure():
	_stand(_airlock.room.room_frame.origin)
	_airlock.room.room_panel.interact(null)
	_step(5.0)
	var bus := AudioServer.get_bus_index(AudioBuses.SHIP)
	var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	assert_almost_eq(filter.cutoff_hz, AudioBuses.VACUUM_CUTOFF, 1.0, "at vacuum, muffled almost to nothing")

