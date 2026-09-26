extends GutTest

## QuantumPlant (quantum energy spec §3.2, §8): owns the store, starts it at
## half capacity once, survives a rebuild and a capacity change without
## resetting the amount, and drives the core(s) it is bound to.

func _stats(capacity: int) -> ShipStats:
	var s := ShipStats.new()
	s.quantum_capacity = capacity
	return s

func _core() -> QuantumCore:
	var core := QuantumCore.new()
	core.setup(Transform3D.IDENTITY, InteriorKit.LAYER)
	add_child_autofree(core)
	return core

func test_the_first_bind_starts_the_store_at_half_capacity():
	var plant := QuantumPlant.new()
	add_child_autofree(plant)
	plant.bind([], [], _stats(1200))
	assert_eq(plant.store.capacity, 1200)
	assert_eq(plant.store.amount, 600)

func test_a_second_bind_keeps_the_amount_rather_than_restocking():
	var plant := QuantumPlant.new()
	add_child_autofree(plant)
	plant.bind([], [], _stats(1200))
	plant.store.spend(100, &"test")
	plant.bind([], [], _stats(1200))
	assert_eq(plant.store.amount, 500, "the same store, not restocked to half again")

func test_a_capacity_change_clamps_the_amount_not_restocking():
	var plant := QuantumPlant.new()
	add_child_autofree(plant)
	plant.bind([], [], _stats(1200))
	assert_eq(plant.store.amount, 600)
	plant.bind([], [], _stats(400))
	assert_eq(plant.store.capacity, 400)
	assert_eq(plant.store.amount, 400, "clamped down, not restocked to half of the new capacity")

func test_binding_drives_a_cores_fill_and_state():
	var core := _core()
	var plant := QuantumPlant.new()
	add_child_autofree(plant)
	plant.bind([core], [], _stats(1000))   # half of 1000 is 500: fraction 0.5
	assert_eq(core.state, &"full")
	assert_eq(core.lit_bars(), 5)

func test_spending_below_the_line_puts_the_core_in_low_power():
	var core := _core()
	var plant := QuantumPlant.new()
	add_child_autofree(plant)
	plant.bind([core], [], _stats(1000))   # line is 100
	plant.store.spend(450, &"test")   # 500 -> 50: below the line
	assert_eq(core.state, &"low_power")

func test_boost_beats_low_power_and_full_in_the_cores_state():
	var hull := RigidBody3D.new()
	add_child_autofree(hull)
	var fc := FlightComputer.new()
	fc.hull_path = NodePath("../" + hull.name)
	hull.get_parent().add_child(fc)
	autofree(fc)
	var core := _core()
	var plant := QuantumPlant.new()
	add_child_autofree(plant)
	plant.flight_computer = fc
	plant.bind([core], [], _stats(1000))
	fc.boosting = true
	plant._physics_process(1.0 / 60.0)
	assert_eq(core.state, &"boost")

func test_the_pilot_light_credits_through_the_plant():
	var plant := QuantumPlant.new()
	add_child_autofree(plant)
	plant.bind([], [], _stats(1000))
	plant.store.drain(1000, &"test")   # empty, so the pilot light has work to do
	watch_signals(plant)
	plant._physics_process(5.0)
	assert_eq(plant.store.amount, 1)
	assert_signal_emitted_with_parameters(plant, "credited", [1, &"pilot"])

func test_low_power_changed_forwards_from_the_store():
	var plant := QuantumPlant.new()
	add_child_autofree(plant)
	plant.bind([], [], _stats(1000))   # line 100, starts at 500: full power
	watch_signals(plant)
	plant.store.spend(450, &"test")   # 50: low power
	assert_signal_emitted_with_parameters(plant, "low_power_changed", [true])

# --- the machine, in the real scene (quantum energy spec §7) ------------------

const DT := 1.0 / 60.0

## The flight scene's starter, with the plant stepped by hand below.
func _ship() -> Ship:
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	ship.quantum.set_physics_process(false)
	return ship

func _step(plant: QuantumPlant, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		plant.tick(DT)

## The galley's mug, stowed where the ship stocked it.
func _mug(ship: Ship) -> Item:
	for node in ship.items.get_children():
		var item := node as Item
		if item != null and item.definition.id == &"mug":
			return item
	return null

## Into the bay, as Grasp's stow-on-drop leaves it.
func _into_bay(item: Item, bay: QuantumBay) -> void:
	item.stow_point.release()
	assert_true(bay.fits(item), "%s fits the bay" % item.definition.id)
	bay.secure(item)

func _warm() -> void:
	Synth.warm_up()
	var deadline := Time.get_ticks_msec() + 20000
	while not Synth.is_warm() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func test_each_machine_gets_a_cycle_and_its_buttons_prompt_from_it():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	assert_eq(plant.cycles.size(), 1)
	assert_true(plant.cycles[m.cell] is MachineCycle, "keyed by the machine's cell")
	plant.tick(DT)
	assert_eq(m.panel.prompt_text(), "Make Mug (6 QE)", "the bay starts empty; the list at the cheapest")
	assert_eq(m.panel.readout_text(), "MAKE · MUG\nCOST 6 QE\nSTORE 600 QE", "on the screen over the bay")
	assert_eq(m.panel.button_state(), &"go", "SIGNAL_GO")
	assert_eq(m.next_button.button_state(), &"go")
	m.next_button.interact(null)
	plant.tick(DT)
	assert_eq(m.panel.readout_text(), "MAKE · RATION TIN\nCOST 10 QE\nSTORE 600 QE")
	m.prev_button.interact(null)
	plant.tick(DT)
	m.prev_button.interact(null)
	plant.tick(DT)
	assert_eq(plant.cycles[m.cell].selected, QuantumValues.makeable(ship.item_catalog).size() - 1, "and wraps")

func test_binding_the_same_machine_twice_adds_nothing_twice():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var core: QuantumCore = ship.interior_builder.quantum_cores()[0]
	plant.bind(ship.interior_builder.quantum_cores(), ship.interior_builder.quantum_machines(), ship.stats)
	assert_eq(m.get_children().filter(func(n): return n is QuantumShow).size(), 1, "one show")
	assert_eq(m.get_children().filter(func(n): return n is AudioStreamPlayer3D).size(), 2, "the bay's and the panel's")
	assert_eq(core.get_children().filter(func(n): return n is AudioStreamPlayer3D).size(), 1, "one hum")
	for button: ReadoutPanel in [m.panel, m.prev_button, m.next_button]:
		assert_eq(button.pressed.get_connections().size(), 1, "%s wired once" % button.role)

## Style guide §2.8: a few capitalised words on the glass, never spilling off
## it. Every line the machine can show, for every kind in the catalogue and
## every state of the store, fits across its screen with a margin.
func test_every_line_the_machine_can_show_fits_its_screen():
	var ship := _ship()
	var label: Label3D = ship.interior_builder.quantum_machines()[0].panel.readout
	var font := label.font if label.font != null else ThemeDB.fallback_font
	var list := QuantumValues.makeable(ship.item_catalog)
	var widest := ""
	var widest_m := 0.0
	# Plenty; full; low power; a make would cross the line or cost too much.
	for amount in [600, 1200, 100, 125]:
		var store := QuantumStore.new(1200, amount)
		for i in list.size():
			var cycle := MachineCycle.new()
			cycle.selected = i
			cycle.step(0.0, &"", 0, store, list)
			var lines := cycle.screen()
			cycle.step(0.0, list[i].id, list[i].quantum_value, store, list)
			lines.append_array(cycle.screen())
			for line in lines:
				var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
				if w > widest_m:
					widest_m = w
					widest = line
	var glass := InteriorProps.QUANTUM_MACHINE_SCREEN_GLASS.x
	assert_lt(widest_m, glass - 0.02, "the widest, '%s', is %.3f m on %.2f m of glass" % [widest, widest_m, glass])

## Spec §7.1, §15.2's machine probe: a mug dropped in and converted is +3 on
## the store, credited when the bead arrives; the mug says it was consumed,
## once, and is gone with no orphans.
func test_converting_a_mug_credits_3_when_the_bead_arrives_and_consumes_it():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var mug := _mug(ship)
	_into_bay(mug, m.bay)
	var consumed := [0]
	mug.consumed.connect(func() -> void: consumed[0] += 1)
	watch_signals(plant)
	var before := plant.store.amount
	plant.tick(DT)
	assert_eq(m.panel.prompt_text(), "Convert Mug (+3 QE)")
	assert_eq(m.panel.readout_text(), "CONVERT · MUG\n+3 QE\nSTORE %d QE" % before)
	m.panel.interact(null)
	plant.tick(DT)
	assert_eq(m.panel.button_state(), &"cycling", "AMBER while it works")
	assert_eq(mug.state, Item.State.HELD, "the machine has it: no Take prompt mid-convert")
	assert_false(mug.can_interact(null))
	assert_true(m.bay.busy, "and the bay takes nothing else")
	_step(plant, MachineCycle.CONVERT_TIME - 0.1)
	assert_eq(plant.store.amount, before, "not before the bead arrives")
	assert_true(is_instance_valid(mug))
	_step(plant, 0.2)
	assert_eq(plant.store.amount, before + 3)
	assert_signal_emitted_with_parameters(plant, "credited", [3, &"convert"])
	assert_eq(consumed[0], 1, "consumed, once")
	assert_freed(mug, "the converted mug")
	assert_true(m.bay.is_free())
	assert_false(m.bay.busy)
	assert_no_new_orphans()

## Spec §7.5: sparkles while it works, the bead and a flash as the item
## winks out, the core flashing as the bead arrives.
func test_the_show_follows_a_convert():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var core: QuantumCore = ship.interior_builder.quantum_cores()[0]
	var show := plant.machine_show(m.cell)
	assert_not_null(show)
	assert_eq(show.get_parent(), m, "rebuilt with the machine")
	_into_bay(_mug(ship), m.bay)
	plant.tick(DT)
	assert_false(show.is_sparkling())
	m.panel.interact(null)
	plant.tick(DT)
	assert_true(show.is_sparkling())
	assert_false(show.bead_running())
	_step(plant, MachineCycle.CONVERT_TIME - MachineCycle.BEAD_TIME)
	assert_true(show.bead_running(), "the bead leaves as the item becomes a point")
	assert_true(show.flashing())
	assert_almost_eq(show.bead_position(), m.conduit_path[0], Vector3.ONE * 0.0001, "from the cabinet's top")
	_step(plant, MachineCycle.BEAD_TIME)
	assert_true(core.flaring(), "the core flashes as the credit lands")
	plant.tick(DT)
	assert_false(show.is_sparkling())

func test_the_item_shrinks_to_a_point_before_the_bead_leaves():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var mug := _mug(ship)
	_into_bay(mug, m.bay)
	plant.tick(DT)
	m.panel.interact(null)
	_step(plant, MachineCycle.CONVERT_TIME - MachineCycle.BEAD_TIME)
	var look: Node3D = mug.get_node("Look")
	assert_lt(look.scale.x, 0.01, "a point by the time the bead leaves")
	assert_almost_eq(mug.global_position, m.bay.global_position, Vector3.ONE * 0.0001, "at the bay's centre")

## Spec §7.2, §15.2: making a mug debits 6 at once and, 1.5 s later, leaves
## a mug stowed in the bay, whose own prompt takes it out.
func test_making_a_mug_debits_6_and_leaves_one_stowed_in_the_bay():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var before := plant.store.amount
	var count := ship.items.get_child_count()
	plant.tick(DT)
	m.panel.interact(null)
	plant.tick(DT)
	assert_eq(plant.store.amount, before - 6, "debited at once")
	assert_true(m.bay.busy)
	_step(plant, MachineCycle.MAKE_TIME - 0.1)
	assert_true(m.bay.is_free(), "nothing to take until it is made")
	_step(plant, 0.2)
	var made: Item = m.bay.item
	assert_not_null(made)
	assert_eq(made.definition.id, &"mug")
	assert_eq(made.state, Item.State.STOWED)
	assert_eq(made.stow_point, m.bay)
	assert_eq(made.get_parent(), ship.items, "one of the ship's items")
	assert_eq(ship.items.get_child_count(), count + 1)
	assert_eq(made.prompt_text(), "Take Mug")
	assert_almost_eq((made.get_node("Look") as Node3D).scale, Vector3.ONE, Vector3.ONE * 0.0001, "full size")
	assert_eq(plant.store.amount, before - 6, "debited once")
	assert_false(m.bay.busy)

func test_a_refused_press_changes_nothing():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	plant.store.credit(plant.store.room() - 1, &"test")   # one short of full
	var mug := _mug(ship)
	_into_bay(mug, m.bay)
	plant.tick(DT)
	assert_eq(m.panel.button_state(), &"vacuum", "CORAL: store full")
	var amount := plant.store.amount
	m.panel.interact(null)
	_step(plant, 2.0)
	assert_eq(plant.store.amount, amount)
	assert_eq(mug.state, Item.State.STOWED, "still in the bay")
	assert_eq(m.bay.item, mug)

## Spec §7.4: a rebuild never drops an item mid-conversion.
func test_a_rebuild_mid_convert_keeps_the_stage_and_the_credit():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var cell := m.cell
	var mug := _mug(ship)
	_into_bay(mug, m.bay)
	plant.tick(DT)
	m.panel.interact(null)
	_step(plant, 0.5)
	var cycle: MachineCycle = plant.cycles[cell]
	var before := plant.store.amount
	ship.set_grid(ship.grid)
	var rebuilt: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	assert_same(plant.cycles[cell], cycle, "the same cycle")
	assert_eq(cycle.stage, MachineCycle.Stage.CONVERTING, "still converting")
	assert_true(rebuilt.bay.busy)
	assert_true(is_instance_valid(mug))
	_step(plant, MachineCycle.CONVERT_TIME)
	assert_eq(plant.store.amount, before + 3)
	assert_freed(mug, "the converted mug")
	assert_eq(rebuilt.panel.readout_text(), "MAKE · MUG\nCOST 6 QE\nSTORE %d QE" % (before + 3),
		"the rebuilt screen carries on")

func test_a_rebuild_mid_make_still_makes_it():
	var ship := _ship()
	var plant := ship.quantum
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	plant.tick(DT)
	m.panel.interact(null)
	_step(plant, 0.5)
	ship.set_grid(ship.grid)
	_step(plant, MachineCycle.MAKE_TIME)
	var rebuilt: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	assert_not_null(rebuilt.bay.item)
	assert_eq(rebuilt.bay.item.definition.id, &"mug")
	assert_eq(rebuilt.bay.item.state, Item.State.STOWED)

## Spec §7.4: an idle item in the bay re-seats through the ship's own re-seat.
func test_a_stowed_item_in_the_bay_reseats_through_a_rebuild():
	var ship := _ship()
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var mug := _mug(ship)
	_into_bay(mug, m.bay)
	ship.set_grid(ship.grid)
	var rebuilt: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	assert_eq(rebuilt.bay.item, mug)
	assert_eq(mug.state, Item.State.STOWED)

## Spec §13: the core hums, positional at the core on the Ship bus, never as
## loud as the ship's air handling; converting and making sound at the bay.
func test_the_machine_and_core_sound_on_the_ship_bus():
	await _warm()
	var ship := _ship()
	var plant := ship.quantum
	var core: QuantumCore = ship.interior_builder.quantum_cores()[0]
	var m: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	plant.tick(DT)
	var hum := plant.hum(core)
	assert_not_null(hum)
	assert_eq(hum.bus, AudioBuses.SHIP)
	assert_same(hum.stream, Synth.sound(&"core_hum"))
	assert_true(hum.playing)
	assert_almost_eq(hum.global_position, core.global_transform * InteriorProps.QUANTUM_HEART,
		Vector3.ONE * 0.0001, "at the core's heart")
	var ship_hum: AudioStreamPlayer = ship.get_node("Hum")
	assert_lt(hum.max_db, ship_hum.volume_db, "never louder than the ship's hum, however close")
	var mug := _mug(ship)
	_into_bay(mug, m.bay)
	plant.tick(DT)
	m.panel.interact(null)
	plant.tick(DT)
	var bay_player := plant.player(m.cell, &"bay")
	assert_eq(bay_player.bus, AudioBuses.SHIP)
	assert_same(bay_player.stream, Synth.sound(&"convert"))
	assert_almost_eq(bay_player.global_position, m.bay.global_position, Vector3.ONE * 0.0001)
	_step(plant, 2.0)
	m.panel.interact(null)
	plant.tick(DT)
	assert_same(bay_player.stream, Synth.sound(&"materialize"))

func test_the_hum_lifts_its_pitch_while_boosting():
	var ship := _ship()
	var plant := ship.quantum
	var core: QuantumCore = ship.interior_builder.quantum_cores()[0]
	plant.tick(DT)
	assert_almost_eq(plant.hum(core).pitch_scale, 1.0, 0.0001)
	ship.flight_computer.boosting = true
	_step(plant, 2.0)
	assert_gt(plant.hum(core).pitch_scale, 1.1)
