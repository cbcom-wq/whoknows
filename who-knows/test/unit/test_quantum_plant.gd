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
