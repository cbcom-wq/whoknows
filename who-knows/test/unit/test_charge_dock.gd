extends GutTest

## The quantum machine's charge plate (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §7.3, §9): ChargeDock on its own, then
## the plant charging the avatar's suit from the ship's store through it, in
## the real scene -- 50 QE a second, one for one, while you stay within 1.2 m.

const DT := 1.0 / 60.0

# --- the plate on its own ----------------------------------------------------------

func _dock() -> ChargeDock:
	var dock := ChargeDock.new()
	dock.setup(0.11, InteriorKit.LAYER)
	add_child_autofree(dock)
	return dock

func test_it_prompts_from_its_source_and_is_offered_only_with_a_prompt():
	var dock := _dock()
	assert_eq(dock.prompt_text(), "")
	assert_false(dock.can_interact(null))
	dock.prompt_source = func() -> String: return "Charge suit (+100 QE)"
	assert_eq(dock.prompt_text(), "Charge suit (+100 QE)")
	assert_true(dock.can_interact(null))

func test_pressing_it_says_who_pressed():
	var dock := _dock()
	var who := Node3D.new()
	add_child_autofree(who)
	watch_signals(dock)
	dock.interact(who)
	assert_signal_emitted_with_parameters(dock, "pressed", [who])

## While a charge runs the plate glows: a brighter disc swells from its centre
## to its rim as the suit fills.
func test_its_readout_fills_the_plate_as_the_suit_fills():
	var dock := _dock()
	var fill: MeshInstance3D = dock.get_node("PlateFill")
	assert_eq(dock.readout_percent(), -1, "no charge running")
	assert_false(fill.visible)
	dock.set_readout(64)
	assert_eq(dock.readout_percent(), 64)
	assert_true(fill.visible)
	assert_almost_eq(fill.scale, Vector3(0.64, 0.64, 1.0), Vector3.ONE * 0.0001)
	dock.set_readout(100)
	assert_almost_eq(fill.scale, Vector3.ONE, Vector3.ONE * 0.0001, "the whole plate at full")
	dock.set_readout(-1)
	assert_false(fill.visible)
	assert_eq(fill.layers, InteriorKit.LAYER, "on the interior's layer")

## Spec §7.3: within 1.2 m of the plate, measured from your head -- your hand
## is at your shoulder, whatever your height.
func test_its_reach_is_1_2_m():
	var dock := _dock()
	var who := Node3D.new()
	add_child_autofree(who)
	who.global_position = dock.global_transform * Vector3(0, 0, 1.15)
	assert_true(dock.within_reach(who))
	who.global_position = dock.global_transform * Vector3(0, 0, 1.25)
	assert_false(dock.within_reach(who))
	assert_eq(ChargeDock.REACH, 1.2)

# --- charging, in the real scene ------------------------------------------------

## The flight scene's starter, with the plant stepped by hand below.
func _ship() -> Ship:
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	ship.quantum.set_physics_process(false)
	return ship

func _avatar(ship: Ship) -> Avatar:
	return ship.get_node("Interior/Avatar")

func _machine(ship: Ship) -> QuantumMachine:
	return ship.interior_builder.quantum_machines()[0]

func _step(plant: QuantumPlant, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		plant.tick(DT)

## Stands the avatar on the deck `away` metres out from the plate: its head
## 0.4 m above the plate, which is 1.2 m up.
func _stand(ship: Ship, away: float) -> void:
	var plate := _machine(ship).plate
	var at := plate.global_transform * Vector3(0, 0, away)
	at.y = plate.global_position.y - 1.2 + 0.02
	_avatar(ship).global_position = at

## Stands at the plate and presses it.
func _press(ship: Ship) -> void:
	_stand(ship, 0.5)
	_machine(ship).plate.interact(_avatar(ship))

func test_the_plate_offers_to_charge_an_empty_suit():
	var ship := _ship()
	var plate := _machine(ship).plate
	ship.quantum.tick(DT)
	assert_eq(_avatar(ship).suit_cell.charge, 0.0, "the suit starts empty")
	assert_eq(plate.prompt_text(), "Charge suit (+100 QE)")
	assert_true(plate.is_lit(), "lit: ready to charge")
	_avatar(ship).suit_cell.charge = 13.6
	assert_eq(plate.prompt_text(), "Charge suit (+86 QE)")

func test_it_charges_at_50_a_second_from_the_store():
	var ship := _ship()
	var plant := ship.quantum
	var suit := _avatar(ship).suit_cell
	var before := plant.store.amount
	_press(ship)
	_step(plant, 1.0)
	assert_almost_eq(suit.charge, 50.0, 0.9)
	assert_almost_eq(float(before - plant.store.amount), suit.charge, 1.0, "one for one")

func test_it_stops_at_100():
	var ship := _ship()
	var plant := ship.quantum
	var suit := _avatar(ship).suit_cell
	var plate := _machine(ship).plate
	var before := plant.store.amount
	_press(ship)
	_step(plant, 3.0)
	assert_eq(suit.charge, SuitCell.CAPACITY)
	assert_eq(plant.store.amount, before - 100, "100 QE, and no more")
	assert_eq(plate.prompt_text(), "Suit charged")
	assert_false(plate.is_lit(), "nothing more to give")
	assert_eq(plate.readout_percent(), -1, "the charge is over")

func test_it_stops_when_the_store_reaches_0():
	var ship := _ship()
	var plant := ship.quantum
	var suit := _avatar(ship).suit_cell
	var plate := _machine(ship).plate
	plant.store.drain(plant.store.amount - 30, &"test")
	_press(ship)
	_step(plant, 2.0)
	assert_eq(plant.store.amount, 0, "down to 0: there is no reserve")
	assert_almost_eq(suit.charge, 30.0, 0.0001, "every QE the store had, and not a fraction more")
	assert_eq(plate.readout_percent(), -1, "the charge is over")
	assert_eq(plate.prompt_text(), "Store empty")
	assert_false(plate.is_lit())

func test_it_stops_when_you_walk_away():
	var ship := _ship()
	var plant := ship.quantum
	var suit := _avatar(ship).suit_cell
	_press(ship)
	_step(plant, 0.5)
	var charged := suit.charge
	_stand(ship, 1.5)
	_step(plant, 1.0)
	assert_eq(suit.charge, charged, "out of reach, the charge stops")
	_stand(ship, 0.5)
	_step(plant, 1.0)
	assert_eq(suit.charge, charged, "and coming back does not restart it: press again")

## Spec §3.2: a suit charge is allowed in low power.
func test_it_charges_in_low_power():
	var ship := _ship()
	var plant := ship.quantum
	plant.store.drain(plant.store.amount - 100, &"test")
	assert_true(plant.store.is_low_power())
	_press(ship)
	_step(plant, 1.0)
	assert_almost_eq(_avatar(ship).suit_cell.charge, 50.0, 0.9)

## Spec §7.3: a charge may take the store to 0; the pilot light then brings
## it back to 25.
func test_after_a_charge_empties_the_store_the_pilot_light_brings_it_back_to_25():
	var ship := _ship()
	var plant := ship.quantum
	plant.store.drain(plant.store.amount - 40, &"test")
	_press(ship)
	_step(plant, 1.0)
	assert_eq(plant.store.amount, 0)
	for i in 300:   # 150 s
		plant.tick(0.5)
	assert_eq(plant.store.amount, QuantumStore.PILOT_CAP)

## Spec §7.3: while charging, the machine's screen counts up and the plate
## glows with the suit's charge.
func test_the_screen_counts_up_while_charging():
	var ship := _ship()
	var plant := ship.quantum
	var m := _machine(ship)
	var before := plant.store.amount
	_press(ship)
	_step(plant, 0.5)
	var percent := floori(_avatar(ship).suit_cell.charge)
	assert_eq(m.panel.readout_text(), "CHARGE · SUIT\nSUIT %d%%\nSTORE %d QE" % [percent, plant.store.amount])
	assert_eq(m.plate.readout_percent(), percent)
	assert_true(m.plate.is_lit())
	_step(plant, 2.0)
	assert_eq(m.panel.readout_text(), "MAKE · MUG\nCOST 6 QE\nSTORE %d QE" % (before - 100), "and back when it is done")

## Every line the charge puts on the machine's screen fits its glass.
func test_the_charge_lines_fit_the_screen():
	var ship := _ship()
	var label: Label3D = _machine(ship).panel.readout
	var font := label.font if label.font != null else ThemeDB.fallback_font
	for line in QuantumPlant.charge_screen(100, 1200):
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
		assert_lt(w, InteriorProps.QUANTUM_MACHINE_SCREEN_GLASS.x - 0.02, line)

## A charge is one for one (spec §3.2): the store pays in whole QE for exactly
## what the suit takes, a fraction owed at most, over charge after charge.
func test_charge_after_charge_is_one_for_one():
	var ship := _ship()
	var plant := ship.quantum
	var suit := _avatar(ship).suit_cell
	var before := plant.store.amount
	var taken := 0.0
	for spent in [0.0, 13.37, 40.2, 7.77]:
		suit.spend_dv(spent)
		var from := suit.charge
		_press(ship)
		_step(plant, 3.0)
		taken += suit.charge - from
	var paid := before - plant.store.amount
	assert_true(taken - paid >= 0.0 and taken - paid < 1.0, "paid %d for %.3f" % [paid, taken])

## Whoever was charging is gone (freed): the charge ends quietly.
func test_a_wearer_gone_mid_charge_ends_it():
	var ship := _ship()
	var plant := ship.quantum
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar suit_cell := SuitCell.new()\n"
	script.reload()
	var wearer: Node3D = script.new()
	ship.interior.add_child(wearer)
	wearer.global_position = _machine(ship).plate.global_transform * Vector3(0, 0, 0.5)
	_machine(ship).plate.interact(wearer)
	_step(plant, 0.2)
	var charge: float = wearer.suit_cell.charge
	assert_gt(charge, 0.0, "it charges anyone with a suit")
	var amount := plant.store.amount
	wearer.free()
	_step(plant, 0.5)
	assert_eq(_machine(ship).plate.readout_percent(), -1, "the charge is over")
	assert_eq(plant.store.amount, amount, "and nothing more leaves the store")

## A rebuild mid-charge carries on at the rebuilt plate.
func test_a_rebuild_mid_charge_carries_on():
	var ship := _ship()
	var plant := ship.quantum
	var suit := _avatar(ship).suit_cell
	_press(ship)
	_step(plant, 0.5)
	ship.set_grid(ship.grid)
	_step(plant, 2.0)
	assert_eq(suit.charge, SuitCell.CAPACITY)

func _warm() -> void:
	Synth.warm_up()
	var deadline := Time.get_ticks_msec() + 20000
	while not Synth.is_warm() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

## Spec §7.3, §13: a tone at the plate, rising as the suit fills, and a small
## chime when it is full.
func test_the_tone_rises_while_charging_and_chimes_when_full():
	await _warm()
	var ship := _ship()
	var plant := ship.quantum
	var m := _machine(ship)
	_press(ship)
	_step(plant, 0.2)
	var tone := plant.player(m.cell, &"plate")
	assert_not_null(tone)
	assert_eq(tone.bus, AudioBuses.SHIP)
	assert_almost_eq(tone.global_position, m.plate.global_position, Vector3.ONE * 0.0001, "at the plate")
	assert_same(tone.stream, Synth.sound(&"charge"))
	assert_true(tone.playing)
	var low := tone.pitch_scale
	_step(plant, 1.0)
	assert_gt(tone.pitch_scale, low, "the tone rises")
	_step(plant, 1.5)
	assert_same(tone.stream, Synth.sound(&"panel_beep"), "a small chime at full")
