class_name PlanDials
extends RefCounted

## The few numbers that say what a desert world's plan holds: how much of it is
## sea, mountain and plateau, how many seas, ranges, canyons and oases, and how
## thickly buttes stand on its open desert
## (docs/superpowers/specs/2026-11-19-wadis-land-design.md §5.2). Rolled from the
## world's seed, one sub-seed per dial so a dial added later never reshuffles the
## rest; a system design may pin any of them. Shares are of the sphere's surface.

## A dial added later goes on the end (`buttes`, at Checkpoint 1).
const NAMES: Array[String] = ["sea", "seas", "mountains", "ranges", "plateaus", "canyons", "peak", "oases",
	"buttes"]
## Open desert is never less than this share of the world: sea, mountains and
## plateaus are scaled together to leave it.
const OPEN_LEAST := 0.5
## A world with no sea at all, one roll in this many.
const NO_SEA_CHANCE := 1.0 / 3.0
## The highest peak may reach this share of the radius.
const PEAK_RADIUS_SHARE := 0.04

var sea := 0.0
var seas := 1
var mountains := 0.0
var ranges := 1
var plateaus := 0.0
var canyons := 0
## Metres: the tallest a range stands over the open ground.
var peak := 600.0
var oases := 2
## Lone buttes and small mesas per 1,000 km² of open desert (open_share() of the
## sphere): PlanButtes stands them (§6, Checkpoint 1).
var buttes := 1.0

static func roll(world_seed: int, radius_m: float) -> PlanDials:
	var plan_seed := WorldSeed.sub(world_seed, &"plan")
	var d := PlanDials.new()
	var sea_rng := WorldSeed.rng(plan_seed, &"sea")
	d.sea = 0.0 if sea_rng.randf() < NO_SEA_CHANCE else sea_rng.randf_range(0.05, 0.25)
	d.seas = WorldSeed.rng(plan_seed, &"seas").randi_range(1, 2)
	d.mountains = WorldSeed.rng(plan_seed, &"mountains").randf_range(0.03, 0.15)
	d.ranges = WorldSeed.rng(plan_seed, &"ranges").randi_range(1, 5)
	d.plateaus = WorldSeed.rng(plan_seed, &"plateaus").randf_range(0.10, 0.30)
	d.canyons = WorldSeed.rng(plan_seed, &"canyons").randi_range(0, 6)
	d.peak = minf(WorldSeed.rng(plan_seed, &"peak").randf_range(600.0, 2500.0), PEAK_RADIUS_SHARE * radius_m)
	d.oases = WorldSeed.rng(plan_seed, &"oases").randi_range(2, 8)
	d.buttes = WorldSeed.rng(plan_seed, &"buttes").randf_range(1.0, 6.0)
	d._normalise()
	return d

## Sets each dial `values` names (a design file's numbers; keys that are not
## dials are ignored), then keeps the open share as the rolls do, by scaling
## the shares it did not pin first.
func pin(values: Dictionary) -> void:
	var held: Array[String] = []
	for key: Variant in values:
		var n := str(key)
		if not NAMES.has(n):
			continue
		var v: Variant = values[key]
		if not (v is float or v is int):
			continue
		if typeof(get(n)) == TYPE_INT:
			set(n, int(v))
		else:
			set(n, float(v))
		held.append(n)
	_normalise(held)

## What is left for open desert: 1 - sea - mountains - plateaus.
func open_share() -> float:
	return 1.0 - sea - mountains - plateaus

## Scales sea, mountains and plateaus by one factor until open_share() is
## OPEN_LEAST. The dials in `held` (pinned by a design) are left as written
## while the others can make room; only when they alone take too much are
## they scaled too.
func _normalise(held: Array[String] = []) -> void:
	var limit := 1.0 - OPEN_LEAST
	if sea + mountains + plateaus <= limit:
		return
	var shares: Array[String] = ["sea", "mountains", "plateaus"]
	var fixed := 0.0
	var loose := 0.0
	for n in shares:
		if held.has(n):
			fixed += get(n)
		else:
			loose += get(n)
	if fixed < limit and loose > 0.0:
		for n in shares:
			if not held.has(n):
				set(n, get(n) * (limit - fixed) / loose)
	else:
		for n in shares:
			set(n, get(n) * limit / (fixed + loose))
