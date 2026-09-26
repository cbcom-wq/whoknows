extends GutTest

## MachineCycle (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §7.1-§7.4): the quantum machine's rules as a pure state machine -- convert
## and make, their timings and cues, the refusals, the low-power warning, the
## ◀/▶ list, and the prompts, screen lines and button colours for each state.
## The cycle reads the store and never changes it: the plant credits and
## debits on its cues (test_quantum_plant.gd).

const DT := 1.0 / 60.0

var _cat: ItemCatalog
var _list: Array

func before_all():
	_cat = ItemCatalog.load_from_dir()
	_list = QuantumValues.makeable(_cat)

func _store(amount := 600, capacity := 1200) -> QuantumStore:
	return QuantumStore.new(capacity, amount)

## Steps `cycle` DT at a time for `seconds`, returning every cue with the time
## it fired at, counting on from `t`.
func _run(cycle: MachineCycle, seconds: float, id: StringName, value: int, store: QuantumStore,
		t := 0.0) -> Array:
	var out := []
	for i in int(round(seconds / DT)):
		t += DT
		for cue in cycle.step(DT, id, value, store, _list):
			out.append([t, cue])
	return out

func _cues(timed: Array) -> Array:
	return timed.map(func(e): return e[1])

func _time_of(timed: Array, cue: StringName) -> float:
	for e in timed:
		if e[1] == cue:
			return e[0]
	return -1.0

func _index_of(id: StringName) -> int:
	for i in _list.size():
		if _list[i].id == id:
			return i
	return -1

## Presses the big button with `id` (worth `value`) in the bay and steps once,
## as the plant does: from the next step on, the machine holds the item and
## the bay reads empty. Returns the press step's cues.
func _press_convert(cycle: MachineCycle, id: StringName, value: int, store: QuantumStore) -> Array:
	cycle.step(0.0, id, value, store, _list)
	cycle.press(&"big")
	return cycle.step(DT, id, value, store, _list)

## Spec §7.1: 1.2 s, the bead the last 0.6 s of it, the credit as it arrives.
func test_a_convert_takes_1_2_s_with_the_bead_for_the_last_0_6():
	var cycle := MachineCycle.new()
	var store := _store()
	assert_eq(_press_convert(cycle, &"crate", 30, store), [&"convert_start"], "at the press")
	assert_eq(cycle.stage, MachineCycle.Stage.CONVERTING)
	var timed := _run(cycle, 2.0, &"", 0, store, DT)
	assert_eq(_cues(timed), [&"bead", &"credited"], "in order, once each")
	assert_almost_eq(_time_of(timed, &"bead"), MachineCycle.CONVERT_TIME - MachineCycle.BEAD_TIME, DT * 0.5)
	assert_almost_eq(_time_of(timed, &"credited"), MachineCycle.CONVERT_TIME, DT * 0.5)
	assert_eq(cycle.stage, MachineCycle.Stage.IDLE)

func test_the_timings_are_the_specs():
	assert_eq(MachineCycle.CONVERT_TIME, 1.2)
	assert_eq(MachineCycle.BEAD_TIME, 0.6)
	assert_eq(MachineCycle.MAKE_TIME, 1.5)

## Spec §7.1: the store is credited when the bead arrives, not before. The
## cycle says when and how much; the store itself is the plant's to change.
func test_credited_comes_as_the_bead_arrives_and_carries_the_value():
	var cycle := MachineCycle.new()
	var store := _store()
	_press_convert(cycle, &"crate", 30, store)
	var before := _run(cycle, MachineCycle.CONVERT_TIME - 3.0 * DT, &"", 0, store)
	assert_false(_cues(before).has(&"credited"), "not before")
	assert_eq(cycle.stage, MachineCycle.Stage.CONVERTING)
	assert_eq(cycle.value, 30)
	assert_eq(cycle.converting, &"crate")
	var after := _run(cycle, 3.0 * DT, &"", 0, store)
	assert_eq(_cues(after), [&"credited"])
	assert_eq(store.amount, 600, "the cycle never changes the store")

func test_a_long_step_fires_every_cue_in_order():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"mug", 3, store, _list)
	cycle.press(&"big")
	assert_eq(cycle.step(5.0, &"mug", 3, store, _list), [&"convert_start", &"bead", &"credited"])

## Spec §7.2: 1.5 s, the cost debited at the start.
func test_a_make_takes_1_5_s():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"", 0, store, _list)
	assert_eq(_list[cycle.selected].id, &"mug", "the list starts at the cheapest")
	cycle.press(&"big")
	var timed := _run(cycle, 2.0, &"", 0, store)
	assert_eq(_cues(timed), [&"make_start", &"materialized"])
	assert_almost_eq(_time_of(timed, &"make_start"), DT, 0.0001, "at the press")
	assert_almost_eq(_time_of(timed, &"materialized"), MachineCycle.MAKE_TIME, DT * 0.5)
	assert_eq(cycle.making.id, &"mug")
	assert_eq(cycle.value, 6, "the cost, twice the value")
	assert_eq(store.amount, 600, "the cycle never changes the store")
	assert_eq(cycle.stage, MachineCycle.Stage.IDLE)

## Spec §7.1: STORE FULL, with a coral button, when the value will not fit.
func test_a_convert_that_would_overflow_the_store_is_refused():
	var cycle := MachineCycle.new()
	var store := _store(1180)
	cycle.step(0.0, &"crate", 30, store, _list)
	assert_eq(cycle.screen(), PackedStringArray(["CONVERT · CRATE", "+30 QE", "STORE FULL"]))
	assert_eq(cycle.button_colour(), &"CORAL")
	assert_eq(cycle.prompt(&"big"), "Store full")
	cycle.press(&"big")
	assert_eq(cycle.step(DT, &"crate", 30, store, _list), [&"refused"])
	assert_eq(cycle.stage, MachineCycle.Stage.IDLE)

func test_a_convert_that_exactly_fills_the_store_is_allowed():
	var cycle := MachineCycle.new()
	var store := _store(1170)
	cycle.step(0.0, &"crate", 30, store, _list)
	assert_eq(cycle.button_colour(), &"SIGNAL_GO")
	cycle.press(&"big")
	assert_eq(cycle.step(DT, &"crate", 30, store, _list), [&"convert_start"])

## Spec §7.2: NOT ENOUGH QE when the cost is more than the store holds.
func test_a_make_costing_more_than_the_store_holds_is_refused():
	var cycle := MachineCycle.new()
	var store := _store(200)   # full power: the line is 120
	cycle.selected = _index_of(&"power_cell")   # costs 300
	cycle.step(0.0, &"", 0, store, _list)
	assert_eq(cycle.screen(), PackedStringArray(["MAKE · POWER CELL", "COST 300 QE", "NOT ENOUGH QE"]))
	assert_eq(cycle.button_colour(), &"CORAL")
	assert_eq(cycle.prompt(&"big"), "Not enough QE")
	cycle.press(&"big")
	assert_eq(cycle.step(DT, &"", 0, store, _list), [&"refused"])
	assert_eq(cycle.stage, MachineCycle.Stage.IDLE)

## Spec §7.2, §8.3: making is refused while the ship is in low power.
func test_making_is_refused_in_low_power():
	var cycle := MachineCycle.new()
	var store := _store(100)   # below the line, 120
	cycle.step(0.0, &"", 0, store, _list)
	assert_eq(cycle.screen(), PackedStringArray(["MAKE · LOW POWER", "STORE 100 QE", "FULL POWER 120 QE"]))
	assert_eq(cycle.button_colour(), &"CORAL")
	assert_eq(cycle.prompt(&"big"), "Low power")
	assert_eq(cycle.prompt(&"prev"), "", "the list is closed")
	assert_eq(cycle.prompt(&"next"), "")
	cycle.press(&"big")
	assert_eq(cycle.step(DT, &"", 0, store, _list), [&"refused"])
	cycle.press(&"next")
	cycle.step(DT, &"", 0, store, _list)
	assert_eq(cycle.selected, 0)

## Spec §7.2: a make that would drop the ship into low power warns, AMBER,
## and still makes -- being careful is the player's job.
func test_a_make_that_would_cross_the_line_warns_and_still_makes():
	var cycle := MachineCycle.new()
	var store := _store(125)   # the mug's 6 would leave 119, under the line of 120
	cycle.step(0.0, &"", 0, store, _list)
	assert_eq(cycle.screen(), PackedStringArray(["MAKE · MUG", "COST 6 QE", "→ LOW POWER"]))
	assert_eq(cycle.button_colour(), &"AMBER")
	assert_eq(cycle.prompt(&"big"), "Make Mug (6 QE) · low power")
	cycle.press(&"big")
	assert_eq(cycle.step(DT, &"", 0, store, _list), [&"make_start"], "pressing through the warning makes")

func test_a_make_that_lands_exactly_on_the_line_does_not_warn():
	var cycle := MachineCycle.new()
	var store := _store(126)   # 126 - 6 = 120: full power at the line
	cycle.step(0.0, &"", 0, store, _list)
	assert_eq(cycle.button_colour(), &"SIGNAL_GO")
	assert_eq(cycle.screen()[2], "STORE 126 QE")

## Global constraints: converting is unaffected by low power.
func test_converting_works_in_low_power():
	var cycle := MachineCycle.new()
	var store := _store(50)
	cycle.step(0.0, &"crate", 30, store, _list)
	assert_eq(cycle.button_colour(), &"SIGNAL_GO")
	assert_eq(cycle.prompt(&"big"), "Convert Crate (+30 QE)")
	assert_eq(_press_convert(cycle, &"crate", 30, store), [&"convert_start"])
	assert_eq(_cues(_run(cycle, 2.0, &"", 0, store)), [&"bead", &"credited"])

## Spec §7.2: ◀ and ▶ step through everything it can make, cheapest first,
## and wrap round.
func test_next_steps_through_the_list_cheapest_first_and_wraps():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"", 0, store, _list)
	var seen := []
	var last_cost := -1
	for i in _list.size():
		var def: ItemDefinition = _list[cycle.selected]
		seen.append(def.id)
		assert_eq(cycle.screen()[0], "MAKE · %s" % def.display_name.to_upper())
		assert_eq(cycle.screen()[1], "COST %d QE" % QuantumValues.make_cost(def))
		assert_true(QuantumValues.make_cost(def) >= last_cost, "sorted by cost")
		last_cost = QuantumValues.make_cost(def)
		cycle.press(&"next")
		assert_eq(cycle.step(DT, &"", 0, store, _list), [], "browsing fires no cue")
	assert_eq(seen.size(), _list.size())
	assert_eq(seen[0], &"mug")
	assert_eq(seen[-1], &"power_cell")
	assert_eq(cycle.selected, 0, "past the dearest, back to the cheapest")

func test_prev_wraps_from_the_cheapest_to_the_dearest():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"", 0, store, _list)
	cycle.press(&"prev")
	cycle.step(DT, &"", 0, store, _list)
	assert_eq(cycle.selected, _list.size() - 1)
	assert_eq(cycle.screen()[0], "MAKE · POWER CELL")
	cycle.press(&"prev")
	cycle.step(DT, &"", 0, store, _list)
	assert_eq(cycle.selected, _list.size() - 2)

func test_the_arrows_do_nothing_with_something_in_the_bay():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"mug", 3, store, _list)
	assert_eq(cycle.prompt(&"prev"), "")
	assert_eq(cycle.prompt(&"next"), "")
	cycle.press(&"next")
	cycle.step(DT, &"mug", 3, store, _list)
	assert_eq(cycle.selected, 0)

## Pressing anything while it works does nothing.
func test_presses_while_working_do_nothing():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"", 0, store, _list)
	cycle.press(&"big")
	cycle.step(DT, &"", 0, store, _list)
	assert_eq(cycle.stage, MachineCycle.Stage.MAKING)
	for button in [&"big", &"next", &"prev"]:
		assert_eq(cycle.prompt(button), "", "%s offers nothing while making" % button)
		cycle.press(button)
		assert_eq(cycle.step(DT, &"", 0, store, _list), [], "%s mid-make" % button)
	assert_eq(cycle.selected, 0)
	assert_eq(cycle.making.id, &"mug")

## Spec §7.1-§7.2, §7.4: the prompt, the three screen lines and the button
## colour in each state.
func test_ready_to_convert():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"crate", 30, store, _list)
	assert_eq(cycle.screen(), PackedStringArray(["CONVERT · CRATE", "+30 QE", "STORE 600 QE"]))
	assert_eq(cycle.prompt(&"big"), "Convert Crate (+30 QE)")
	assert_eq(cycle.button_colour(), &"SIGNAL_GO")

func test_converting():
	var cycle := MachineCycle.new()
	var store := _store()
	_press_convert(cycle, &"crate", 30, store)
	cycle.step(DT, &"", 0, store, _list)   # the machine has the crate now; the bay reads empty
	assert_eq(cycle.screen(), PackedStringArray(["CONVERT · CRATE", "+30 QE", "STORE 600 QE"]))
	assert_eq(cycle.prompt(&"big"), "")
	assert_eq(cycle.button_colour(), &"AMBER")

func test_ready_to_make():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"", 0, store, _list)
	assert_eq(cycle.screen(), PackedStringArray(["MAKE · MUG", "COST 6 QE", "STORE 600 QE"]))
	assert_eq(cycle.prompt(&"big"), "Make Mug (6 QE)")
	assert_eq(cycle.prompt(&"prev"), "Previous")
	assert_eq(cycle.prompt(&"next"), "Next")
	assert_eq(cycle.button_colour(), &"SIGNAL_GO")

func test_making():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"", 0, store, _list)
	cycle.press(&"big")
	cycle.step(DT, &"", 0, store, _list)
	store.spend(6, &"make")   # as the plant does on make_start
	assert_eq(cycle.screen(), PackedStringArray(["MAKE · MUG", "COST 6 QE", "STORE 594 QE"]))
	assert_eq(cycle.prompt(&"big"), "")
	assert_eq(cycle.button_colour(), &"AMBER")

func test_nothing_to_make_leaves_the_button_dark():
	var cycle := MachineCycle.new()
	var store := _store()
	cycle.step(0.0, &"", 0, store, [])
	assert_eq(cycle.screen(), PackedStringArray(["NOTHING TO MAKE", "", "STORE 600 QE"]))
	assert_eq(cycle.prompt(&"big"), "")
	assert_eq(cycle.button_colour(), &"")
	cycle.press(&"big")
	assert_eq(cycle.step(DT, &"", 0, store, []), [])

func test_before_its_first_step_it_shows_nothing():
	var cycle := MachineCycle.new()
	assert_eq(cycle.screen(), PackedStringArray())
	assert_eq(cycle.prompt(&"big"), "")
	assert_eq(cycle.button_colour(), &"")
