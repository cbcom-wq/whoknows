class_name DrillYield
extends RefCounted

## What a drill earns (docs/superpowers/specs/2026-09-26-habitat-modules-design.md
## §6.2): 1 QE per DRILL_PERIOD seconds of play, times its rock's richness --
## seeded per rock, doubled on a veined one -- into its base's store, never
## past its capacity. For its first SURVEY seconds its gauge says only
## SURVEYING (who knows). Its state is a plain dictionary in the base's site,
## so it is saved as it is; the clock is play time, so a closed game earns
## nothing and a sleeping base earns as if you were there.

static func fresh(ore: Dictionary, now: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ore.get("seed", 0))
	var richness := rng.randf_range(HabitatValues.RICHNESS_MIN, HabitatValues.RICHNESS_MAX)
	var veined := bool(ore.get("veined", false))
	if veined:
		richness *= HabitatValues.VEIN_FACTOR
	return {"richness": richness, "veined": veined, "ran": 0.0, "credited_at": now, "owed": 0.0}

## QE a second.
static func rate(drill: Dictionary) -> float:
	return float(drill.get("richness", 1.0)) / HabitatValues.DRILL_PERIOD

static func surveyed(drill: Dictionary) -> bool:
	return float(drill.get("ran", 0.0)) >= HabitatValues.SURVEY

## *SURVEYING*, then the richness: *VEIN 1.8×* on a veined rock, *ORE 1.8×*
## on any other.
static func gauge(drill: Dictionary) -> String:
	if not surveyed(drill):
		return "SURVEYING"
	return "%s %.1f×" % ["VEIN" if drill.get("veined", false) else "ORE", float(drill.get("richness", 1.0))]

## Credits `drill` from its last credit up to `now` into `store`, in whole QE,
## carrying the fraction. What will not fit is lost, not owed: a full store
## stays full. Returns what it credited.
static func credit(drill: Dictionary, now: float, store: QuantumStore) -> int:
	var dt := maxf(now - float(drill.get("credited_at", now)), 0.0)
	drill["credited_at"] = now
	drill["ran"] = float(drill.get("ran", 0.0)) + dt
	var owed := float(drill.get("owed", 0.0)) + dt * rate(drill)
	var whole := floori(owed + 1e-6)
	var paid := mini(whole, store.room())
	if paid > 0:
		store.credit(paid, &"drill")
	drill["owed"] = maxf(owed - whole, 0.0) if paid == whole else 0.0
	return paid
