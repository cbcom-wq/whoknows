extends GutTest

## The drill's yield (habitat modules spec §6.2), by the play-time clock.

func _drill(richness := 1.0) -> Dictionary:
	var d := DrillYield.fresh({"seed": 42, "veined": false}, 100.0)
	d["richness"] = richness
	return d

func test_richness_is_seeded_per_rock_and_in_range():
	for s in 50:
		var d := DrillYield.fresh({"seed": s, "veined": false}, 0.0)
		assert_between(float(d["richness"]), HabitatValues.RICHNESS_MIN, HabitatValues.RICHNESS_MAX)
		assert_eq(d["richness"], DrillYield.fresh({"seed": s, "veined": false}, 9.0)["richness"], "same rock, same ore")

func test_a_veined_rock_doubles():
	var plain := DrillYield.fresh({"seed": 7, "veined": false}, 0.0)
	var veined := DrillYield.fresh({"seed": 7, "veined": true}, 0.0)
	assert_almost_eq(float(veined["richness"]), float(plain["richness"]) * HabitatValues.VEIN_FACTOR, 0.0001)

func test_it_surveys_for_its_first_minute():
	var d := _drill(1.8)
	var store := QuantumStore.new(400, 0)
	DrillYield.credit(d, 100.0 + 59.0, store)
	assert_false(DrillYield.surveyed(d))
	assert_eq(DrillYield.gauge(d), "SURVEYING")
	DrillYield.credit(d, 100.0 + 61.0, store)
	assert_true(DrillYield.surveyed(d))
	assert_eq(DrillYield.gauge(d), "ORE 1.8×")

func test_it_earns_one_qe_per_ten_seconds_times_richness():
	var d := _drill(1.0)
	var store := QuantumStore.new(400, 0)
	assert_eq(DrillYield.credit(d, 100.0 + 60.0, store), 6)
	assert_eq(store.amount, 6)
	var rich := _drill(2.5)
	var other := QuantumStore.new(400, 0)
	assert_eq(DrillYield.credit(rich, 100.0 + 60.0, other), 15)

func test_fractions_carry_over():
	var d := _drill(1.0)
	var store := QuantumStore.new(400, 0)
	for i in 10:
		DrillYield.credit(d, 100.0 + (i + 1) * 3.0, store)
	assert_eq(store.amount, 3, "30 s of 3 s steps is 3 QE, not 0")

func test_a_long_sleep_fills_to_capacity_and_never_pays_twice():
	var d := _drill(3.0)
	var store := QuantumStore.new(400, 350)
	assert_eq(DrillYield.credit(d, 100.0 + 3600.0, store), 50, "capped at the store's room")
	assert_eq(store.amount, 400)
	assert_eq(float(d["credited_at"]), 3700.0, "the clock moved on")
	store.drain(100, &"test")
	assert_eq(DrillYield.credit(d, 3700.0, store), 0, "no second payment for the same time")
