class_name WarpPlan
extends RefCounted

## Can I warp from here to there, and what will it cost
## (docs/superpowers/specs/2026-09-28-warp-design.md §4.2, §6)? Pure: the drive
## asks every tick, the map for each target, and the HUD shows text().
##
## The checks go in the order a pilot would want to hear them: nothing
## charted, crew outside or an airlock cycling, too close to warp, still
## inside a limit, the line blocked by the star or a planet, low power, too
## little QE, the nose off the line; else ready. Where you are comes from
## Whereabouts (`inside`), never worked out here.

enum Status { NONE, CREW, AIRLOCK, INSIDE, CLOSE, BLOCKED, LOW_POWER, NO_QE, ALIGN, READY }

const WARP_BASE := 40
const WARP_PER_KM := 4.0
## The nose within this of the line is lined up.
const ALIGN := deg_to_rad(5.0)
## Less travel than this, and you fly.
const MIN_TRAVEL := 5000.0
## The drop-out point steps back this far at a time, at most this many times,
## until it is this clear of every rock, per tier (§4.2): rubble's thin
## sprinkle leaves hardly a point 300 m clear of it.
const CLEAR_STEP := 100.0
const CLEAR_STEPS := 60
const ROCK_CLEAR: Array[float] = [30.0, 300.0, 300.0]

var status: Status = Status.NONE
var target: WarpTarget
## INSIDE: the limit you are in. BLOCKED: the one on the line.
var blocker: WarpTarget
## Travel, metres: from you to the drop-out point.
var distance := 0.0
var to_centre := 0.0
var cost := 0
## Travel only, seconds; the spool is the drive's.
var duration := 0.0
var drop: UniversePoint
## From you towards the target, unit.
var direction := Vector3.ZERO
var off_line := 0.0
var into_low_power := false
## INSIDE: metres until you are clear of `blocker`'s limit.
var clear_in := 0.0

static func cost_of(travel: float) -> int:
	return WARP_BASE + ceili(WARP_PER_KM * maxf(travel, 0.0) / 1000.0)

static func check(from: UniversePoint, nose: Vector3, p_target: WarpTarget, targets: Array[WarpTarget],
		inside: Array[StringName], store: QuantumStore, busy: StringName = &"") -> WarpPlan:
	var p := WarpPlan.new()
	p.target = p_target
	if p_target == null or from == null:
		return p
	var line := p_target.point.minus(from)
	p.to_centre = line.length()
	p.direction = line / maxf(p.to_centre, 0.001)
	p.distance = p.to_centre - p_target.limit
	p.drop = from.plus(p.direction * maxf(p.distance, 0.0))
	p.cost = cost_of(p.distance)
	p.duration = WarpProfile.new(maxf(p.distance, 0.0)).duration
	p.off_line = nose.angle_to(line) if not nose.is_zero_approx() else PI
	if busy == &"crew":
		p.status = Status.CREW
		return p
	if busy == &"airlock":
		p.status = Status.AIRLOCK
		return p
	if inside.has(p_target.id) or p.distance < MIN_TRAVEL:
		p.status = Status.CLOSE
		return p
	for id in inside:
		for t in targets:
			if t.id == id:
				p.status = Status.INSIDE
				p.blocker = t
				p.clear_in = t.limit - from.minus(t.point).length()
				return p
	var nearest := INF
	for t in targets:
		if t == p_target or t.kind == WarpTarget.Kind.CLUSTER:
			continue
		var rel := t.point.minus(from)
		var along := clampf(rel.dot(p.direction), 0.0, p.distance)
		if (rel - p.direction * along).length() < t.limit and along < nearest:
			nearest = along
			p.blocker = t
	if p.blocker != null:
		p.status = Status.BLOCKED
		return p
	if store != null and store.is_low_power():
		p.status = Status.LOW_POWER
		return p
	if store != null and p.cost > store.amount:
		p.status = Status.NO_QE
		return p
	if p.off_line > ALIGN:
		p.status = Status.ALIGN
		return p
	p.status = Status.READY
	p.into_low_power = store != null and store.amount - p.cost < store.line()
	return p

## What the HUD says (§4.2).
func text() -> String:
	match status:
		Status.CREW:
			return "WARP · CREW OUTSIDE"
		Status.AIRLOCK:
			return "WARP · AIRLOCK CYCLING"
		Status.INSIDE:
			return "CLEAR OF %s IN %.1f KM" % [blocker.name, clear_in / 1000.0]
		Status.CLOSE:
			return "FLY · %.1f KM TO %s" % [maxf(to_centre - target.edge, 0.0) / 1000.0, target.name]
		Status.BLOCKED:
			return "BLOCKED BY %s" % blocker.name
		Status.LOW_POWER:
			return "WARP · LOW POWER"
		Status.NO_QE:
			return "WARP · NEED %d QE" % cost
		Status.ALIGN:
			return "ALIGN · %d°" % roundi(rad_to_deg(off_line))
		Status.READY:
			return "WARP READY · J · → LOW POWER" if into_low_power else "WARP READY · J"
	return ""

## True if any rock `recipe` places lies within ROCK_CLEAR of `u`, per tier.
static func rock_near(recipe: AsteroidRecipe, u: UniversePoint) -> bool:
	for tier in AsteroidRecipe.TIERS:
		var clear: float = ROCK_CLEAR[tier]
		var reach := clear + AsteroidRecipe.BOUND * AsteroidRecipe.D_MAX[tier] * AsteroidRecipe.STRETCH_MAX
		var lo := AsteroidRecipe.cell_of(tier, u.plus(-Vector3.ONE * reach))
		var hi := AsteroidRecipe.cell_of(tier, u.plus(Vector3.ONE * reach))
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var cell := Vector3i(x, y, z)
					var corner := AsteroidRecipe.cell_corner(tier, cell)
					for rock in recipe.cell_rocks(tier, cell):
						if corner.plus(rock.local).minus(u).length() < clear + rock.radius:
							return true
	return false

## `drop`, stepped back against `direction` until no rock is near (§4.2), or
## as far as CLEAR_STEPS takes it.
static func stepped_clear(recipe: AsteroidRecipe, drop: UniversePoint, p_direction: Vector3) -> UniversePoint:
	var at := drop
	for i in CLEAR_STEPS:
		if not rock_near(recipe, at):
			return at
		at = at.plus(-p_direction * CLEAR_STEP)
	return at
