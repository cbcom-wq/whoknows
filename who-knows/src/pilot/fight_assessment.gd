class_name FightAssessment
extends RefCounted

## The pilot's assessment layer (hostile ships spec §5.2, §5.3): it reads a
## ship as numbers, then from its own reading and the target's picks a style
## and the range it wants. Pure given a Ship; the choice is pure given two
## readings and a random number generator.

## ShipPilot.Style's values, mirrored: AUTO is "no style yet".
const AUTO := 0
const STAND_OFF := 1
const BRAWLER := 2

## A ship as the pilot sees it: `dps` hp/s of its live turrets, `reach` the
## longest live turret range (0 with none), `hull` its sections' hp left,
## `whole` its HULL %, `accel` m/s² at full forward thrust, `qe` and `qe_max`
## its store, `burn` the QE/s its turrets spend at full fire.
static func read(ship: Ship) -> Dictionary:
	var out := {"dps": 0.0, "reach": 0.0, "burn": 0.0}
	for t in ship.turrets:
		var stage := BlockDamage.Stage.INTACT
		if ship.damage != null:
			stage = ship.damage.component_stage(ShipDamage.turret_part(t.coord))
		var r := turret_reading(t.kind, stage)
		out["dps"] += r["dps"]
		out["burn"] += r["burn"]
		out["reach"] = maxf(out["reach"], r["reach"])
	var whole := ship.hull_whole()
	var hp := 0.0
	if ship.damage != null:
		for id in ShipDamage.SECTIONS:
			hp += ship.damage.section_hp[id]
	out["whole"] = whole
	out["hull"] = hp * whole
	out["accel"] = ship.stats.thrust_budget[&"forward"] / maxf(ship.stats.total_mass_kg, 1.0)
	var store := ship.quantum.store if ship.quantum != null else null
	out["qe"] = float(store.amount) if store != null else 0.0
	out["qe_max"] = float(store.capacity) if store != null else 0.0
	return out

## One turret of `kind` at `stage`: its `dps`, `burn` QE/s and `reach` m, all
## 0 once wrecked. Damaged, it recharges WeaponValues.DAMAGED_RECHARGE times
## longer, as Turret.step does.
static func turret_reading(kind: StringName, stage: int) -> Dictionary:
	if stage >= BlockDamage.Stage.WRECKED:
		return {"dps": 0.0, "burn": 0.0, "reach": 0.0}
	var spec := WeaponValues.spec(kind)
	var recharge: float = spec["recharge"]
	if stage == BlockDamage.Stage.DAMAGED:
		recharge *= WeaponValues.DAMAGED_RECHARGE
	var burst := float(spec["burst"])
	var cycle: float = burst * spec["gap"] + recharge
	return {"dps": spec["damage"] * burst / cycle, "burn": spec["qe"] * burst / cycle,
		"reach": spec["range"]}

## How much better it does up close than its foe: firepower times hull, as
## ratios. Over 1 it should win a brawl.
static func brawl_score(own: Dictionary, foe: Dictionary) -> float:
	return (own["dps"] / maxf(foe["dps"], 1.0)) * (own["hull"] / maxf(foe["hull"], 1.0))

## The style to fight in, from `current` (AUTO before the first choice).
## Judgement noise from `skill` scales the score; hysteresis keeps it from
## dithering at 1; reach and a dry store override the score.
static func choose(own: Dictionary, foe: Dictionary, skill: float, current: int,
		rng: RandomNumberGenerator) -> int:
	var noise := PilotSkill.new(skill).noise
	var score := brawl_score(own, foe) * (1.0 + rng.randf_range(-noise, noise))
	if own["reach"] <= 0.0 or own["reach"] > foe["reach"] + PilotValues.REACH_EDGE:
		return STAND_OFF
	var style := BRAWLER if score >= 1.0 else STAND_OFF
	if current == BRAWLER:
		style = STAND_OFF if score < 1.0 - PilotValues.SWITCH_MARGIN else BRAWLER
	elif current == STAND_OFF:
		style = BRAWLER if score > 1.0 + PilotValues.SWITCH_MARGIN else STAND_OFF
	if style == BRAWLER and _dry(own) and not _dry(foe):
		return STAND_OFF
	return style

## The range it wants in `style`, m: a brawler's few hundred metres; a
## stand-off near its own reach, but past the foe's when its reach allows; with
## no live turret, well past the foe's reach.
static func preferred_range(style: int, own: Dictionary, foe: Dictionary) -> float:
	if own["reach"] <= 0.0:
		return foe["reach"] + PilotValues.KEEP_AWAY
	if style == BRAWLER:
		return PilotValues.BRAWL_RANGE
	var at: float = PilotValues.STAND_OFF_SHARE * own["reach"]
	var past: float = foe["reach"] + PilotValues.PAST_REACH
	if past < own["reach"]:
		at = maxf(at, past)
	return at

static func _dry(side: Dictionary) -> bool:
	return side["qe"] < PilotValues.DRY_SHARE * side["qe_max"]
