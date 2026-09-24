extends GutTest

## The airlock cycle (docs/superpowers/specs/2026-09-24-airlock-design.md §4),
## headless: a pure state machine stepped by hand.

const DT := 1.0 / 60.0

var _c: AirlockCycle
var _cues: Array[StringName] = []

func before_each():
	_c = AirlockCycle.new()
	_cues.clear()

## Steps for `seconds`, collecting cues.
func _run(seconds: float, clear_inner := true, clear_outer := true, room_empty := false) -> void:
	var steps := int(round(seconds / DT))
	for i in steps:
		_cues.append_array(_c.step(DT, clear_inner, clear_outer, room_empty))

## Opens the inner hatch from the corridor and lets it finish.
func _inner_open() -> void:
	_c.press(&"inner")
	_run(AirlockCycle.OPEN_TIME + 0.1)
	_cues.clear()

## Goes out all the way, so the outer hatch stands open at vacuum.
func _outer_open() -> void:
	_inner_open()
	_c.press(&"room")
	_run(5.0)
	_cues.clear()

func test_it_starts_pressurized_with_both_hatches_shut():
	assert_eq(_c.stage, AirlockCycle.Stage.IDLE)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE, 0.001)
	assert_eq(_c.inner_open, 0.0)
	assert_eq(_c.outer_open, 0.0)
	assert_eq(_c.status(), "READY")

func test_the_corridor_panel_opens_the_inner_hatch_without_a_cycle():
	_c.press(&"inner")
	_run(AirlockCycle.OPEN_TIME + 0.05)
	assert_eq(_c.inner_open, 1.0)
	assert_eq(_c.inner_bolts, 1.0)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE, 0.001, "no cycle")
	assert_eq(_c.stage, AirlockCycle.Stage.IDLE)

func test_going_out_takes_four_point_seven_seconds():
	_inner_open()
	_c.press(&"room")
	var t := 0.0
	var sealed_at := -1.0
	var cycled_at := -1.0
	while _c.outer_open < 1.0 and t < 10.0:
		_c.step(DT, true, true, false)
		t += DT
		if sealed_at < 0.0 and _c.stage == AirlockCycle.Stage.CYCLING:
			sealed_at = t
		if cycled_at < 0.0 and _c.stage == AirlockCycle.Stage.OPENING:
			cycled_at = t
	assert_almost_eq(sealed_at, AirlockCycle.SEAL_TIME, 0.05, "sealed after 0.7 s")
	assert_almost_eq(cycled_at, AirlockCycle.SEAL_TIME + AirlockCycle.CYCLE_TIME, 0.06, "cycled after 3.5 s")
	assert_almost_eq(t, 4.7, 0.08, "the far hatch is open at 4.7 s")
	assert_almost_eq(_c.pressure, 0.0, 0.001)
	assert_eq(_c.stage, AirlockCycle.Stage.IDLE)
	assert_eq(_c.status(), "VACUUM")

func test_going_out_cues_in_order():
	_inner_open()
	_c.press(&"room")
	_run(5.0)
	assert_eq(_cues, [&"leaves_closing", &"leaves_shut", &"bolts_home", &"cycle_start", &"bolts_out",
		&"leaves_opening", &"leaves_open"])

func test_pressure_falls_fast_then_eases_going_out():
	_inner_open()
	_c.press(&"room")
	_run(AirlockCycle.SEAL_TIME + AirlockCycle.CYCLE_TIME * 0.5)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE * 0.25, 1.0, "p = 101 (1 - u)^2 at u = 0.5")

func test_coming_in_fires_the_steam_and_opens_the_inner_hatch():
	_outer_open()
	_c.press(&"room")
	_run(AirlockCycle.SEAL_TIME + AirlockCycle.CYCLE_TIME * 0.5)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE * 0.75, 1.0, "p = 101 (1 - (1 - u)^2) at u = 0.5")
	_run(3.0)
	assert_has(_cues, &"steam_jets")
	assert_eq(_c.inner_open, 1.0)
	assert_eq(_c.outer_open, 0.0)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE, 0.001)

func test_the_hull_panel_opens_the_outer_hatch_at_vacuum():
	_outer_open()
	_c.press(&"outer")   # close it from outside
	_run(1.0)
	assert_eq(_c.outer_open, 0.0)
	_c.press(&"outer")   # and open it again: no cycle needed
	_run(AirlockCycle.OPEN_TIME + 0.05)
	assert_eq(_c.outer_open, 1.0)
	assert_almost_eq(_c.pressure, 0.0, 0.001)

func test_an_outside_panel_calls_the_room_to_its_side():
	_c.press(&"outer")   # pressurized, both shut: cycle out, then open
	_run(AirlockCycle.CYCLE_TIME + AirlockCycle.OPEN_TIME + 0.1)
	assert_eq(_c.outer_open, 1.0)
	assert_almost_eq(_c.pressure, 0.0, 0.001)
	_c.press(&"outer")
	_run(1.0)
	_c.press(&"inner")   # vacuum, both shut: cycle in, then open the inner hatch
	_run(AirlockCycle.CYCLE_TIME + AirlockCycle.OPEN_TIME + 0.1)
	assert_eq(_c.inner_open, 1.0)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE, 0.001)

func test_pressing_mid_cycle_reverses_it():
	_inner_open()
	_c.press(&"room")
	_run(AirlockCycle.SEAL_TIME + 1.0)
	var low := _c.pressure
	assert_lt(low, AirlockCycle.ATMOSPHERE * 0.6)
	_c.press(&"room")
	_run(0.05)
	assert_has(_cues, &"reversed")
	_run(1.0 + AirlockCycle.OPEN_TIME + 0.1)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE, 0.001, "back where it started")
	assert_eq(_c.inner_open, 1.0, "the hatch you came through reopens")
	assert_eq(_c.outer_open, 0.0)

func test_pressing_while_sealing_reopens_the_hatch():
	_inner_open()
	_c.press(&"room")
	_run(0.3)
	_c.press(&"room")
	_run(1.5)
	assert_eq(_c.inner_open, 1.0)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE, 0.001)

func test_a_hatch_never_closes_on_anyone():
	_inner_open()
	_c.press(&"room")
	_run(1.0, false)
	assert_eq(_c.inner_open, 1.0, "the doorway is not clear")
	assert_eq(_c.status(), "CLEAR THE HATCH")
	assert_eq(_cues.count(&"blocked"), 1, "said once")
	_run(AirlockCycle.SEAL_TIME + 0.05)
	assert_eq(_c.stage, AirlockCycle.Stage.CYCLING, "carries on once it is clear")

func test_an_open_hatch_closes_itself_once_everyone_has_gone():
	_inner_open()
	_run(3.0, true, true, false)
	assert_eq(_c.inner_open, 1.0, "someone is still in the room")
	_run(AirlockCycle.AUTO_CLOSE - 0.1, true, true, true)
	assert_eq(_c.inner_open, 1.0, "not before 2 s")
	_run(1.0, true, true, true)
	assert_has(_cues, &"auto_close")
	assert_eq(_c.inner_open, 0.0)
	assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE, 0.001, "the room keeps its pressure")

func test_the_panels_prompt_for_what_they_would_do():
	assert_eq(_c.prompt(&"room"), "Depressurize")
	assert_eq(_c.prompt(&"inner"), "Open hatch")
	assert_eq(_c.prompt(&"outer"), "Depressurize")
	_inner_open()
	assert_eq(_c.prompt(&"inner"), "Close hatch")
	_c.press(&"room")
	_run(1.0)
	assert_eq(_c.prompt(&"room"), "Reverse")
	assert_eq(_c.prompt(&"inner"), "")
	_run(5.0)
	assert_eq(_c.prompt(&"room"), "Pressurize")
	assert_eq(_c.prompt(&"outer"), "Close hatch")
	assert_eq(_c.prompt(&"inner"), "Pressurize")

## Whatever is pressed, whenever: never both hatches open, and an open hatch
## always has its own side's pressure behind it.
func test_the_invariants_hold_under_random_presses():
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var panels := [&"room", &"inner", &"outer"]
	for i in 3000:
		if rng.randf() < 0.02:
			_c.press(panels[rng.randi_range(0, 2)])
		_c.step(DT, rng.randf() < 0.9, rng.randf() < 0.9, rng.randf() < 0.5)
		assert_false(_c.inner_open > 0.0 and _c.outer_open > 0.0, "never both open")
		if _c.inner_open > 0.0:
			assert_almost_eq(_c.pressure, AirlockCycle.ATMOSPHERE, 0.01, "inner open means pressurized")
		if _c.outer_open > 0.0:
			assert_almost_eq(_c.pressure, 0.0, 0.01, "outer open means vacuum")
		if _c.inner_open > 0.0 and _c.inner_bolts < 1.0:
			fail_test("a hatch never moves with its bolts home")

func test_the_motion_warning():
	assert_eq(AirlockCycle.motion_warning(0.2, 1.0)["level"], 0)
	var moving := AirlockCycle.motion_warning(3.2, 0.0)
	assert_eq(moving["level"], 2)
	assert_eq(moving["text"], "SHIP MOVING · 3.2 M/S")
	var turning := AirlockCycle.motion_warning(0.1, 4.0)
	assert_eq(turning["level"], 1)
	assert_eq(turning["text"], "SHIP TURNING · 4°/S")
