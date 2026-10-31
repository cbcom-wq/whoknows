extends GutTest

## FightAssessment (hostile ships spec §5.2, §5.3): a pilot reads its ship and
## the target's, then picks stand-off or brawler and the range it wants.
## PilotSkill (§5.4) turns one 0..1 number into the pilot's knobs.

const STAND_OFF := FightAssessment.STAND_OFF
const BRAWLER := FightAssessment.BRAWLER

## A reading with only the numbers the choice looks at.
func _side(dps: float, hull: float, reach := 1200.0, qe := 1200.0, qe_max := 1200.0) -> Dictionary:
	return {"dps": dps, "hull": hull, "reach": reach, "whole": 1.0, "accel": 10.0,
		"qe": qe, "qe_max": qe_max, "burn": 2.0}

func _rng(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_the_stronger_up_close_brawls():
	var own := _side(60.0, 12000.0)
	var foe := _side(30.0, 12000.0)
	assert_eq(FightAssessment.brawl_score(own, foe), 2.0)
	assert_eq(FightAssessment.choose(own, foe, 1.0, FightAssessment.AUTO, _rng()), BRAWLER)
	assert_eq(FightAssessment.preferred_range(BRAWLER, own, foe), PilotValues.BRAWL_RANGE)

func test_the_longer_reach_stands_off():
	var own := _side(30.0, 12000.0, 1500.0)
	var foe := _side(60.0, 12000.0, 1200.0)
	assert_eq(FightAssessment.choose(own, foe, 1.0, FightAssessment.AUTO, _rng()), STAND_OFF)
	var stronger := _side(120.0, 24000.0, 1500.0)
	assert_eq(FightAssessment.choose(stronger, foe, 1.0, BRAWLER, _rng()), STAND_OFF,
		"it can hit from where it cannot be hit, however strong up close")
	var at := FightAssessment.preferred_range(STAND_OFF, own, foe)
	assert_almost_eq(at, maxf(PilotValues.STAND_OFF_SHARE * 1500.0, 1200.0 + PilotValues.PAST_REACH), 0.01,
		"its share of its reach, or past the foe's")
	assert_true(at >= foe["reach"] + 50.0, "past the foe's reach")

func test_a_stand_off_keeps_past_the_foes_reach_when_it_can():
	var own := _side(30.0, 12000.0, 1300.0)
	var foe := _side(30.0, 12000.0, 1200.0)
	assert_almost_eq(FightAssessment.preferred_range(STAND_OFF, own, foe), 1250.0, 0.01,
		"its share of 1300 is inside the foe's reach; 1250 is still within its own")
	var shorter := _side(30.0, 12000.0, 1200.0)
	var longer := _side(30.0, 12000.0, 1500.0)
	assert_almost_eq(FightAssessment.preferred_range(STAND_OFF, shorter, longer),
		PilotValues.STAND_OFF_SHARE * 1200.0, 0.01, "outranged, it stands off at its share of its own reach")

func test_a_losing_brawler_stands_off():
	var foe := _side(50.0, 10000.0)
	var losing := _side(40.0, 10000.0)
	assert_almost_eq(FightAssessment.brawl_score(losing, foe), 0.8, 0.0001)
	assert_eq(FightAssessment.choose(losing, foe, 1.0, BRAWLER, _rng()), STAND_OFF)
	var close := _side(45.0, 10000.0)
	assert_almost_eq(FightAssessment.brawl_score(close, foe), 0.9, 0.0001)
	assert_eq(FightAssessment.choose(close, foe, 1.0, BRAWLER, _rng()), BRAWLER,
		"inside the margin it keeps brawling")
	assert_eq(FightAssessment.choose(close, foe, 1.0, FightAssessment.AUTO, _rng()), BRAWLER,
		"fresh, from BRAWL_FROM it brawls")
	assert_eq(FightAssessment.choose(losing, foe, 1.0, FightAssessment.AUTO, _rng()), STAND_OFF,
		"fresh, under BRAWL_FROM it stands off")
	var ahead := _side(55.0, 10000.0)
	assert_eq(FightAssessment.choose(ahead, foe, 1.0, STAND_OFF, _rng()), STAND_OFF,
		"1.1 is inside the margin from stand-off")
	var well_ahead := _side(60.0, 10000.0)
	assert_eq(FightAssessment.choose(well_ahead, foe, 1.0, STAND_OFF, _rng()), BRAWLER)

func test_running_dry_stands_off():
	var own := _side(60.0, 12000.0, 1200.0, 200.0, 1200.0)
	var foe := _side(30.0, 12000.0, 1200.0, 900.0, 1200.0)
	assert_eq(FightAssessment.choose(own, foe, 1.0, BRAWLER, _rng()), STAND_OFF)
	var foe_dry := _side(30.0, 12000.0, 1200.0, 200.0, 1200.0)
	assert_eq(FightAssessment.choose(own, foe_dry, 1.0, BRAWLER, _rng()), BRAWLER,
		"both dry, the stronger keeps brawling")

func test_a_novice_misjudges_sometimes():
	var own := _side(60.0, 12000.0)
	var foe := _side(50.0, 12000.0)
	assert_almost_eq(FightAssessment.brawl_score(own, foe), 1.2, 0.0001)
	var rng := _rng(1234)
	var seen := {}
	for i in 200:
		seen[FightAssessment.choose(own, foe, 0.0, FightAssessment.AUTO, rng)] = true
	assert_true(seen.has(STAND_OFF) and seen.has(BRAWLER), "a novice reads it both ways")
	seen.clear()
	for i in 200:
		seen[FightAssessment.choose(own, foe, 1.0, FightAssessment.AUTO, rng)] = true
	assert_eq(seen.keys(), [BRAWLER], "an ace always reads it right")

func test_no_turret_keeps_away():
	var own := _side(0.0, 12000.0, 0.0)
	var foe := _side(30.0, 2000.0, 1500.0)
	assert_eq(FightAssessment.choose(own, foe, 1.0, BRAWLER, _rng()), STAND_OFF)
	assert_almost_eq(FightAssessment.preferred_range(STAND_OFF, own, foe), 1500.0 + PilotValues.KEEP_AWAY, 0.01)

func test_a_foe_with_no_turret_is_closed_on():
	var own := _side(30.0, 2000.0, 1200.0)
	var disarmed := _side(0.0, 12000.0, 0.0)
	assert_eq(FightAssessment.choose(own, disarmed, 1.0, STAND_OFF, _rng()), BRAWLER,
		"nothing to stand off from, however much hull it has")
	var longer := _side(30.0, 12000.0, 1500.0)
	assert_eq(FightAssessment.choose(longer, disarmed, 1.0, FightAssessment.AUTO, _rng()), BRAWLER,
		"a longer reach is no reason to stay out")

func test_reading_a_starter():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	await wait_process_frames(2)
	var ship: Ship = root.get_node("Ship")
	var r := FightAssessment.read(ship)
	var light := WeaponValues.spec(WeaponValues.LIGHT)
	var each: float = light["damage"] * light["burst"] / (light["burst"] * light["gap"] + light["recharge"])
	assert_almost_eq(r["dps"], 2.0 * each, 0.001, "two lights: damage × burst / (burst × gap + recharge) each")
	assert_eq(r["reach"], 1200.0)
	assert_eq(r["whole"], 1.0)
	assert_almost_eq(r["hull"], 12330.0, 50.0, "the starter's six sections' hp, whole")
	assert_gt(r["accel"], 0.0)
	assert_eq(r["qe"], float(ship.quantum.store.amount))
	assert_eq(r["qe_max"], float(ship.quantum.store.capacity))
	assert_almost_eq(r["burn"], 4.0, 0.001, "two lights: 4 bolts of 1 QE every 2 s each")

func test_a_damaged_turret_reads_slower_and_a_wrecked_one_not_at_all():
	var spec := WeaponValues.spec(WeaponValues.LIGHT)
	var burst: float = spec["damage"] * spec["burst"]
	var light := FightAssessment.turret_reading(WeaponValues.LIGHT, BlockDamage.Stage.INTACT)
	assert_almost_eq(light["dps"], burst / (0.5 + 1.5), 0.001)
	var damaged := FightAssessment.turret_reading(WeaponValues.LIGHT, BlockDamage.Stage.DAMAGED)
	assert_almost_eq(damaged["dps"], burst / (0.5 + 3.0), 0.001, "recharges twice as long")
	assert_eq(damaged["reach"], 1200.0)
	var wrecked := FightAssessment.turret_reading(WeaponValues.HEAVY, BlockDamage.Stage.WRECKED)
	assert_eq(wrecked["dps"], 0.0)
	assert_eq(wrecked["reach"], 0.0)

func test_skill_knobs_span_their_ends():
	var novice := PilotSkill.new(0.0)
	var ace := PilotSkill.new(1.0)
	assert_eq(novice.reaction, 1.0)
	assert_almost_eq(ace.reaction, 0.2, 0.0001)
	assert_almost_eq(novice.jink_share, 0.4, 0.0001)
	assert_eq(ace.jink_share, 1.0)
	assert_eq(novice.jink_every, 2.5)
	assert_almost_eq(ace.jink_every, 0.8, 0.0001)
	assert_almost_eq(novice.position_gain, 0.4, 0.0001)
	assert_eq(ace.position_gain, 1.0)
	assert_eq(novice.noise, PilotValues.NOISE_AT_ZERO)
	assert_eq(ace.noise, 0.0)
	assert_eq(novice.hold_fire_past, 1.0)
	assert_almost_eq(ace.hold_fire_past, PilotValues.HOLD_FIRE_ACE, 0.0001)
	assert_almost_eq(PilotSkill.new(0.5).reaction, 0.6, 0.0001)
	assert_eq(PilotSkill.new(2.0).reaction, ace.reaction, "skill is held to 0..1")
