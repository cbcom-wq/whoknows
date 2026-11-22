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
		assert_between(d.buttes, 1.0, 6.0)
		assert_true(d.open_share() >= PlanDials.OPEN_LEAST - 1e-9)
	assert_between(no_sea, 70, 130)   # about a third of 300

func test_a_pinned_dial_replaces_its_roll_and_no_other():
	var rolled := PlanDials.roll(7, 50000.0)
	var d := PlanDials.roll(7, 50000.0)
	d.pin({"sea": 0.15, "ranges": 3, "buttes": 3.5})
	assert_eq(d.sea, 0.15)
	assert_eq(d.ranges, 3)
	assert_eq(d.buttes, 3.5)
	assert_eq(d.canyons, rolled.canyons)

func test_each_dial_draws_from_its_own_sub_seed():
	for s in 50:
		var d := PlanDials.roll(s, 50000.0)
		var plan_seed := WorldSeed.sub(s, &"plan")
		assert_eq(d.canyons, WorldSeed.rng(plan_seed, &"canyons").randi_range(0, 6))
		assert_eq(d.oases, WorldSeed.rng(plan_seed, &"oases").randi_range(2, 8))
		assert_eq(d.buttes, WorldSeed.rng(plan_seed, &"buttes").randf_range(1.0, 6.0))

## Every dial of these seeds as it was rolled before the buttes dial was added
## (Checkpoint 1), in PlanDials.NAMES's order, the shares and the peak printed to
## 17 digits: a dial added later reshuffles none of the others.
const BEFORE_BUTTES := {
	1: [0.19587351637369224, 1, 0.07583222805261054, 3, 0.22829425557369723, 1, 889.81805419921875, 7],
	2: [0.08252886682748795, 1, 0.10929049551486969, 5, 0.2146424800157547, 5, 1027.515625, 8],
	3: [0.15854792296886444, 2, 0.0535757914185524, 4, 0.18916600942611694, 6, 2000.0, 4],
	42: [0.0, 1, 0.08561236411333084, 3, 0.13321205973625183, 5, 1535.12548828125, 3],
	1234: [0.06957229971885681, 2, 0.136063352227211, 2, 0.25053447484970093, 2, 2000.0, 7],
}

func test_the_buttes_dial_reshuffles_no_other():
	for s: int in BEFORE_BUTTES:
		var d := PlanDials.roll(s, 50000.0)
		var was: Array = BEFORE_BUTTES[s]
		for k in was.size():
			var n := PlanDials.NAMES[k]
			if was[k] is int:
				assert_eq(d.get(n), was[k], "seed %d's %s" % [s, n])
			else:
				assert_almost_eq(d.get(n), was[k], 1e-12 * maxf(1.0, absf(was[k])), "seed %d's %s" % [s, n])
	assert_eq(PlanDials.NAMES.find("buttes"), BEFORE_BUTTES[1].size(), "buttes comes after the dials there were")

func test_saves_note_the_world_generator():
	assert_eq(SaveGame.generators().get("world"), 4)

func test_the_design_file_keys_are_the_dials_plus_keep_and_pins():
	var expect: Array[String] = PlanDials.NAMES.duplicate()
	expect.append_array(["keep", "pins"])
	assert_eq(SystemDesign.PLAN_KEYS, expect)
