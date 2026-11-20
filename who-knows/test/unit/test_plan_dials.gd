extends GutTest

func test_the_same_seed_rolls_the_same_dials():
	var a := PlanDials.roll(42, 50000.0)
	var b := PlanDials.roll(42, 50000.0)
	for n in PlanDials.NAMES:
		assert_eq(a.get(n), b.get(n))

func test_rolls_stay_in_their_ranges():
	var no_sea := 0
	for s in 300:
		var d := PlanDials.roll(s, 50000.0)
		if d.sea == 0.0:
			no_sea += 1
		else:
			assert_between(d.sea, 0.0, 0.25)   # under 0.05 only when scaled to keep half open
		assert_between(d.seas, 1, 2)
		assert_between(d.ranges, 1, 5)
		assert_between(d.canyons, 0, 6)
		assert_between(d.oases, 2, 8)
		assert_between(d.peak, 600.0, 2000.0)   # 4% of a 50 km radius caps 2,500
		assert_true(d.open_share() >= PlanDials.OPEN_LEAST - 1e-9)
	assert_between(no_sea, 70, 130)   # about a third of 300

func test_a_pinned_dial_replaces_its_roll_and_no_other():
	var rolled := PlanDials.roll(7, 50000.0)
	var d := PlanDials.roll(7, 50000.0)
	d.pin({"sea": 0.15, "ranges": 3})
	assert_eq(d.sea, 0.15)
	assert_eq(d.ranges, 3)
	assert_eq(d.canyons, rolled.canyons)

func test_each_dial_draws_from_its_own_sub_seed():
	for s in 50:
		var d := PlanDials.roll(s, 50000.0)
		var plan_seed := WorldSeed.sub(s, &"plan")
		assert_eq(d.canyons, WorldSeed.rng(plan_seed, &"canyons").randi_range(0, 6))
		assert_eq(d.oases, WorldSeed.rng(plan_seed, &"oases").randi_range(2, 8))

func test_saves_note_the_world_generator():
	assert_eq(SaveGame.generators().get("world"), 4)

func test_the_design_file_keys_are_the_dials_plus_keep_and_pins():
	var expect: Array[String] = PlanDials.NAMES.duplicate()
	expect.append_array(["keep", "pins"])
	assert_eq(SystemDesign.PLAN_KEYS, expect)
