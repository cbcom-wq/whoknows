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
	assert_eq(_airlock.panels().size(), 2, "room and corridor panels; the hull's comes with the alcove")

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

