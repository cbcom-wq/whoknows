class_name ShipPilot
extends Node

## The AI pilot on a ship's computer (hostile ships spec §5), one on every
## ship beside its FlightComputer and FireControl: off on a crew ship until you
## hand it over, on for a hostile from `engage`. It never cheats (§5.1): it
## flies only through the flight computer (the stick, a velocity hold, the
## heading let go) and fights only through fire control (its mark and orders).
## What it knows is its own ship, its target while in contact, and the bolts in
## flight; what it remembers is directions, ids and a UniversePoint, never an
## engine position, so the floating origin cannot catch it.
##
## Three layers (§5.2): every PilotValues.ASSESS_EVERY it reads the fight and
## picks a style and a range; every TACTICS_EVERY it picks the velocity to hold,
## the face to show, when to jink and whether to fire; every physics tick it
## turns that face with the stick.

## How it fights (§5.3). FightAssessment mirrors STAND_OFF and BRAWLER.
enum Style { AUTO, STAND_OFF, BRAWLER }

## Seconds it means to close the gap to the range it wants in, at full
## positioning: the wanted speed along the line of sight is the gap over this.
const CLOSE_TIME := 2.0
## A jink's change of velocity is this many seconds of lateral thrust, and is
## held this long.
const JINK_PUSH := 1.5
## Jinks at intervals come every jink_every, give or take this share.
const JINK_JITTER := 0.3
## A bolt is inbound when it passes within INBOUND_MISS m of the hull within
## INBOUND_HORIZON s.
const INBOUND_MISS := 60.0
const INBOUND_HORIZON := 3.0
## The turn's gain, 1/s, at full positioning (Broadside.rotate_input).
const TURN_GAIN := 2.0
## A brawler boosts while it is more than this many BRAWL_BANDs off its range.
const BOOST_BANDS := 2.0
## A turret counts toward a face only if it still bears this far off it, every
## way: a face on the very edge of a sky (the starter's nose, on the rim of both
## its turrets' half-skies) bears for neither once the muzzles' height shows.
const FACE_MARGIN := deg_to_rad(10.0)

var ship: Ship
var flight: FlightComputer
var fire_control: FireControl
## Off lets go: the hold released, the stick centred, the orders it found put
## back and its mark taken off.
var on := false:
	set(value):
		if value == on:
			return
		on = value
		if on:
			_start()
		else:
			_let_go()
var skill := 0.5
var style_choice := Style.AUTO
## The style in use: style_choice, or the one the assessment picked.
var style := Style.STAND_OFF
var objective: PilotObjective
## What it is doing, for the readout: &"closing", &"holding_range",
## &"jinking", &"boosting", &"holding_fire", &"pursuing", &"holding_station" or
## &"no_pilot"; &"" while off.
var intent: StringName = &""
## {own, foe: FightAssessment readings, score: the brawl score, preferred: the
## range it wants}, for the readout.
var last_reading := {}
## The hull-local face it shows its target: where most live turrets bear.
var face := Vector3.FORWARD

var _preferred := 0.0
var _chosen := false
var _since_assess := 0.0
var _since_tactics := 0.0
var _knobs := PilotSkill.new()
var _desired := Basis.IDENTITY
var _boost := false
## The orders fire control had when it took over, and the id it marked
## (`_added`: it listed it, so it unlists it).
var _orders_before := FireControl.Orders.HOLD
var _marked: StringName = &""
var _added := false
## The jink running now: a velocity across the line of sight, for _jink_left s;
## the next at intervals in _jink_in s; bolts seen inbound for _seen_for s (<0:
## none).
var _jink := Vector3.ZERO
var _jink_left := 0.0
var _jink_in := 0.0
var _seen_for := -1.0
## The turret stages the face was worked out for.
var _stages: Array = []
var _rng := RandomNumberGenerator.new()
## Its misjudgement of a foe, drawn the same for the same foe each time: a
## steady read, which hysteresis holds, not a fresh one every second.
var _judge := RandomNumberGenerator.new()

func _ready() -> void:
	# Before the flight computer's tick, so what it asks is flown this tick.
	process_physics_priority = -1

func _physics_process(delta: float) -> void:
	tick(delta)

## Fight the ship (or you) called `id` until it is destroyed (§5.5).
func engage(id: StringName) -> void:
	objective = DestroyObjective.new(id)
	_bind_universe()
	on = true

## Whether it is out for `node` (a ship, its hull, or you): its objective's
## target, fighting or pursuing.
func targets(node: Node) -> bool:
	if not on or objective == null or objective.done() or node == null:
		return false
	var id := Weapons.ship_id(node) if node is Ship else Weapons.id_of(node)
	return id != &"" and id == objective.target_id()

## Its skill as the computer lets it be (§5.6): COMPUTER_DAMAGED_SKILL of it
## with the computer damaged, nothing with it wrecked.
func effective_skill() -> float:
	match _computer():
		BlockDamage.Stage.DAMAGED:
			return skill * PilotValues.COMPUTER_DAMAGED_SKILL
		BlockDamage.Stage.WRECKED:
			return 0.0
	return skill

func tick(delta: float) -> void:
	if not on or ship == null or flight == null or not ship.is_inside_tree():
		return
	if ship.is_in_group(Fleet.ASLEEP):
		return
	if _computer() >= BlockDamage.Stage.WRECKED:
		# The pilot is gone (§5.6): it lets go once, and the guns keep the
		# orders and the list they had.
		if intent != &"no_pilot":
			intent = &"no_pilot"
			_boost = false
			flight.release_velocity()
			flight.clear_pilot_input()
		return
	if intent == &"no_pilot":
		# Mended: it looks again at once.
		_since_assess = PilotValues.ASSESS_EVERY
		_since_tactics = PilotValues.TACTICS_EVERY
	_since_assess += delta
	_since_tactics += delta
	if _since_tactics >= PilotValues.TACTICS_EVERY:
		_think(_since_tactics)
		_since_tactics = 0.0
	_fly()

func to_dict() -> Dictionary:
	return {
		"on": on,
		"skill": skill,
		"style_choice": int(style_choice),
		"style": int(style),
		"objective": objective.to_dict() if objective != null else {},
		"orders_before": "engage" if _orders_before == FireControl.Orders.ENGAGE else "hold",
		"marked": String(_marked) if _added else "",
	}

func from_dict(d: Dictionary) -> void:
	skill = clampf(float(d.get("skill", 0.5)), 0.0, 1.0)
	style_choice = _style(d.get("style_choice", Style.AUTO))
	style = _style(d.get("style", Style.STAND_OFF))
	if style == Style.AUTO:
		style = Style.STAND_OFF
	objective = PilotObjective.from_dict(d.get("objective"))
	_bind_universe()
	on = bool(d.get("on", false))
	_orders_before = FireControl.Orders.ENGAGE if str(d.get("orders_before", "hold")) == "engage" \
		else FireControl.Orders.HOLD
	# The mark it made, still in fire control's restored list: its to take off.
	var marked := StringName(str(d.get("marked", "")))
	if on and marked != &"":
		_marked = marked
		_added = true

static func _style(value) -> Style:
	var i := int(value) if value is int or value is float else 0
	return (clampi(i, Style.AUTO, Style.BRAWLER)) as Style

# --- taking over and letting go ------------------------------------------------

func _start() -> void:
	if fire_control != null:
		_orders_before = fire_control.orders
	_since_assess = PilotValues.ASSESS_EVERY
	_since_tactics = PilotValues.TACTICS_EVERY
	_chosen = false
	_marked = &""
	_added = false
	_jink_left = 0.0
	_jink_in = PilotSkill.new(skill).jink_every
	_seen_for = -1.0
	_stages = []
	intent = &""
	if ship != null:
		_rng.seed = hash(ship.name)
		if ship.exterior != null:
			_desired = ship.exterior.global_basis.orthonormalized()

func _let_go() -> void:
	_boost = false
	intent = &""
	if flight != null:
		flight.release_velocity()
		flight.set_pilot_input(Vector3.ZERO, Vector3.ZERO, false)
	if fire_control != null:
		if _added:
			fire_control.unmark(_marked)
		if fire_control.orders != _orders_before:
			fire_control.set_orders(_orders_before)
	_marked = &""
	_added = false

# --- tactics: every TACTICS_EVERY ------------------------------------------------

func _think(elapsed: float) -> void:
	_knobs = PilotSkill.new(effective_skill())
	if objective == null:
		_hold_station()
		return
	_bind_universe()
	var from := Weapons.point_of(ship.exterior)
	var tree := ship.get_tree()
	objective.step(from, tree, elapsed)
	_keep_mark()
	if objective.done():
		_hold_station()
		return
	if objective.pursuing():
		_pursue()
		return
	var node := objective.target(tree, from)
	if node == null:
		_hold_station()
		return
	if _since_assess >= PilotValues.ASSESS_EVERY:
		_assess(node)
		_since_assess = 0.0
	_fight(node, from, elapsed)

## Its mark on fire control follows the objective's target: the old one off
## (if it listed it), the new one marked once, at the top.
func _keep_mark() -> void:
	var id: StringName = objective.target_id() if not objective.done() else &""
	if id == _marked or fire_control == null:
		return
	if _added:
		fire_control.unmark(_marked)
	_marked = id
	_added = false
	if id != &"":
		var listed := fire_control.list.has(id)
		_added = fire_control.mark(id) and not listed

func _assess(node: Node3D) -> void:
	var own := FightAssessment.read(ship)
	var foe := _reading_of(node)
	if style_choice != Style.AUTO:
		style = style_choice
	else:
		var current: int = style if _chosen else FightAssessment.AUTO
		_judge.seed = hash(String(ship.name) + String(objective.target_id()))
		style = FightAssessment.choose(own, foe, effective_skill(), current, _judge) as Style
	_chosen = true
	_preferred = FightAssessment.preferred_range(style, own, foe)
	last_reading = {"own": own, "foe": foe, "score": FightAssessment.brawl_score(own, foe),
		"preferred": _preferred}

## A target's reading: its ship's, or nothing to fear (you on a spacewalk).
static func _reading_of(node: Node3D) -> Dictionary:
	var other := node.get_meta(&"ship") as Ship if node.has_meta(&"ship") else null
	if other != null:
		return FightAssessment.read(other)
	return {"dps": 0.0, "reach": 0.0, "burn": 0.0, "whole": 1.0, "hull": 1.0, "accel": 0.0,
		"qe": 0.0, "qe_max": 0.0}

func _fight(node: Node3D, from: Vector3, elapsed: float) -> void:
	var to := Weapons.point_of(node) - from
	var dist := to.length()
	var los := to / maxf(dist, 0.001)
	var gap := dist - _preferred
	var band := PilotValues.BRAWL_BAND if style == Style.BRAWLER else PilotValues.STAND_OFF_BAND
	var wanted := Weapons.velocity_of(node) + los * _knobs.position_gain * gap / CLOSE_TIME
	intent = &"closing" if absf(gap) > band else &"holding_range"
	if _fire(dist):
		intent = &"holding_fire"
	_boost = style == Style.BRAWLER and absf(gap) > BOOST_BANDS * PilotValues.BRAWL_BAND
	if _boost:
		intent = &"boosting"
	if _jinking(from, los, dist, elapsed):
		wanted += _jink
		intent = &"jinking"
	_hold(wanted)
	_refresh_face()
	_desired = Broadside.desired_basis(ship.exterior.global_basis.orthonormalized(), face, los)

## Fire control's orders: engage, but hold while it is far past where its
## shots land and its store is low (fire discipline, §5.4). True when holding.
func _fire(dist: float) -> bool:
	var reach := float(last_reading.get("own", {}).get("reach", 0.0))
	var store := ship.quantum.store if ship.quantum != null else null
	var low := store != null and store.amount < PilotValues.HOLD_FIRE_QE * store.capacity
	var hold := low and dist > _knobs.hold_fire_past * reach
	_set_orders(FireControl.Orders.HOLD if hold else FireControl.Orders.ENGAGE)
	return hold

## Whether a jink runs now, starting one when it is due: reaction s after
## bolts are seen inbound, or every jink_every while in the target's reach.
func _jinking(from: Vector3, los: Vector3, dist: float, elapsed: float) -> bool:
	_jink_left -= elapsed
	_jink_in -= elapsed
	var pool := BoltPool.find(ship.get_tree())
	var bolts: Array = pool.flying() if pool != null else []
	var coming := Broadside.inbound(bolts, ship, from, ship.exterior.linear_velocity, INBOUND_MISS,
		INBOUND_HORIZON)
	if coming <= 0:
		_seen_for = -1.0
	elif _seen_for < 0.0:
		_seen_for = 0.0
	else:
		_seen_for += elapsed
	if _jink_left > 0.0:
		return true
	var dodge := _seen_for >= _knobs.reaction - 0.0001
	var foe_reach := float(last_reading.get("foe", {}).get("reach", 0.0))
	var due := _jink_in <= 0.0 and dist <= foe_reach
	if not dodge and not due:
		return false
	if dodge:
		_seen_for = 0.0
	_jink_in = _knobs.jink_every * (1.0 + _rng.randf_range(-JINK_JITTER, JINK_JITTER))
	_jink_left = JINK_PUSH
	var lateral: float = ship.stats.thrust_budget[&"lateral"] if ship.stats != null else 0.0
	var mass := maxf(ship.stats.total_mass_kg if ship.stats != null else 1.0, 1.0)
	var side := los.cross(Vector3.UP if absf(los.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	_jink = side.rotated(los, _rng.randf() * TAU) * _knobs.jink_share * lateral / mass * JINK_PUSH
	return true

## Out of contact: at its best speed the way it last saw the target, nose first,
## guns held (§5.5).
func _pursue() -> void:
	var seen := objective.last_seen()
	var dir: Vector3 = seen.get("dir", Vector3.ZERO)
	_boost = false
	_jink_left = 0.0
	intent = &"pursuing"
	_set_orders(FireControl.Orders.HOLD)
	_hold(dir * flight.current_limit)
	if not dir.is_zero_approx():
		_desired = Broadside.desired_basis(ship.exterior.global_basis.orthonormalized(), Vector3.FORWARD, dir)

## Nothing to fight: it stops where it is, and stops turning.
func _hold_station() -> void:
	_boost = false
	_jink_left = 0.0
	intent = &"holding_station"
	flight.hold_velocity(Vector3.ZERO)
	_desired = ship.exterior.global_basis.orthonormalized()

## Holds `wanted`, steered round rocks, under the limit.
func _hold(wanted: Vector3) -> void:
	var hull := ship.exterior
	var exclude: Array[RID] = [hull.get_rid()]
	var radius := float(hull.get_meta(AsteroidStream.ANCHOR_RADIUS, 10.0))
	wanted += RockAvoid.steer(hull.get_world_3d().direct_space_state, hull.global_position,
		hull.linear_velocity, radius, exclude)
	flight.hold_velocity(wanted.limit_length(flight.current_limit))

func _set_orders(o: FireControl.Orders) -> void:
	if fire_control != null and fire_control.orders != o:
		fire_control.set_orders(o)

## The face, worked out again when a turret's stage changed.
func _refresh_face() -> void:
	var stages: Array = []
	var skies: Array = []
	var live: Array = []
	for t in ship.turrets:
		var stage := BlockDamage.Stage.INTACT
		if ship.damage != null:
			stage = ship.damage.component_stage(ShipDamage.turret_part(t.coord))
		stages.append(stage)
		skies.append(t.sky)
		live.append(stage < BlockDamage.Stage.WRECKED)
	if stages == _stages:
		return
	_stages = stages
	face = sure_face(skies, live)

## Broadside.best_face, counting a turret only where it bears FACE_MARGIN off
## the face every way; best_face itself when no turret bears that surely.
static func sure_face(skies: Array, live: Array) -> Vector3:
	var best := Vector3.FORWARD
	var best_count := 0
	var best_nose := -INF
	for dir: Vector3 in Broadside.SAMPLES:
		var count := 0
		for i in skies.size():
			if i < live.size() and live[i] and _bears_round(skies[i] as SkyMap, dir):
				count += 1
		var nose := dir.dot(Vector3.FORWARD)
		if count > best_count or (count == best_count and nose > best_nose):
			best = dir
			best_count = count
			best_nose = nose
	return best if best_count > 0 else Broadside.best_face(skies, live)

static func _bears_round(sky: SkyMap, dir: Vector3) -> bool:
	if sky == null or not sky.can_bear(dir):
		return false
	var a := dir.cross(Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var b := dir.cross(a)
	for off: Vector3 in [a, -a, b, -b]:
		if not sky.can_bear(dir * cos(FACE_MARGIN) + off * sin(FACE_MARGIN)):
			return false
	return true

# --- flying: every physics tick ---------------------------------------------------

## The stick that turns the face it wants; translation is all the hold's.
func _fly() -> void:
	var hull := ship.exterior
	var basis := hull.global_basis.orthonormalized()
	var spin := basis.inverse() * hull.angular_velocity
	var rotate := Broadside.rotate_input(basis, _desired, spin, TURN_GAIN * _knobs.position_gain)
	flight.set_pilot_input(Vector3.ZERO, rotate, _boost)
	flight.clear_heading()

func _computer() -> int:
	if ship == null or ship.damage == null:
		return BlockDamage.Stage.INTACT
	return ship.damage.component_stage(&"computer")

func _bind_universe() -> void:
	if objective == null or objective.to_universe.is_valid() or ship == null:
		return
	if ship.sensors != null and ship.sensors.universe != null:
		objective.to_universe = ship.sensors.universe.to_universe
