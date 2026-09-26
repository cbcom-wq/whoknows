extends GutTest

## When the game may save (docs/superpowers/specs/2026-09-26-saving-design.md
## §4, §5).

var _why := ""

func _gate() -> SaveGate:
	var gate := SaveGate.new()
	gate.add_source(func() -> String: return _why)
	return gate

## Ticks `gate` for `seconds` in 0.1 s steps; how many saves it asked for.
func _run(gate: SaveGate, seconds: float) -> int:
	var saves := 0
	for i in roundi(seconds / 0.1):
		if gate.tick(0.1):
			saves += 1
			gate.saved()
	return saves

func before_each():
	_why = ""

func test_nothing_saves_while_settling_after_a_load():
	var gate := _gate()
	gate.since_save = SaveGate.INTERVAL
	assert_false(gate.tick(0.1))
	assert_eq(gate.reason, "settling")

func test_it_saves_every_interval_when_calm():
	var gate := _gate()
	assert_eq(_run(gate, SaveGate.INTERVAL * 3 + 1.0), 3)

func test_a_busy_source_holds_the_save_and_it_follows_the_calm():
	var gate := _gate()
	_run(gate, SaveGate.INTERVAL - 1.0)
	_why = "airlock cycling"
	assert_eq(_run(gate, 5.0), 0)
	assert_eq(gate.reason, "airlock cycling")
	_why = ""
	assert_eq(_run(gate, SaveGate.CALM_FOR - 0.2), 0, "not until calm for CALM_FOR")
	assert_eq(_run(gate, 0.5), 1)

func test_the_end_of_an_action_saves_if_the_last_save_is_old_enough():
	var gate := _gate()
	_run(gate, SaveGate.EDGE_AFTER + 1.0)
	_why = "sitting"
	_run(gate, 1.0)
	_why = ""
	assert_eq(_run(gate, SaveGate.CALM_FOR + 0.5), 1)

func test_the_end_of_an_action_soon_after_a_save_waits_for_the_interval():
	var gate := _gate()
	_run(gate, SaveGate.SETTLE + 0.5)
	gate.saved()
	_why = "sitting"
	_run(gate, 1.0)
	_why = ""
	assert_eq(_run(gate, SaveGate.CALM_FOR + 1.0), 0)

func test_calm_needs_the_whole_window():
	var gate := _gate()
	_run(gate, SaveGate.SETTLE + SaveGate.CALM_FOR + 0.2)
	assert_true(gate.is_calm())
	_why = "hull struck"
	gate.tick(0.1)
	assert_false(gate.is_calm())
	_why = ""
	gate.tick(0.1)
	assert_false(gate.is_calm())
