class_name FlightComputer
extends Node

## Assisted Newtonian control of a hull RigidBody3D.
##
## Assist on: counters drift, damps residual rotation, holds a cruise ceiling,
## and can lock a speed or hold a heading (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §5). Assist off: raw Newtonian, input
## maps straight to thrust.

const CRUISE_LIMIT_MPS := 120.0
const BOOST_MULTIPLIER := 2.5
## Inside a well the limit climbs with altitude (the world scale spec §6): 1 m/s
## more for every 40 m up, to LIMIT_CAP, easing back to CRUISE_LIMIT_MPS over
## the top LIMIT_EASE of the well so you leave it at the speed the rocks
## outside stream for. At full speed you are always about 40 s from the ground.
const LIMIT_PER_M := 1.0 / 40.0
const LIMIT_CAP := 1500.0
const LIMIT_EASE := 0.1
## Fraction of the budget assist may spend on velocity nobody asked for: all
## of it, so after a turn your travel swings onto the nose in seconds (spec
## §5.4). At 0.6 the shuttle slid the old way for half a minute after a turn.
const DRIFT_AUTHORITY := 1.0
## Turn rate full stick asks for under assist, radians per second.
const ASSIST_TURN_RATE := deg_to_rad(60.0)
## How hard the assist chases the rate it was asked for, in 1/s. Doubles as
## the damping rate when the stick is centred and the target rate is zero.
const RATE_GAIN := 4.0
## Heading hold (spec §5.2): the share of the weaker turning axis's angular
## acceleration it plans to brake with, leaving the rate loop some spare.
const HOLD_BRAKE_SHARE := 0.6
## Heading hold's turn rate per radian of error near the target, 1/s. It keeps
## the braking curve from chattering at the end. Simulated on the shuttle, 3
## overshot a 120 deg swing by 2.0 deg; 2 overshoots by at most 1.2 deg.
const HOLD_GAIN := 2.0

@export var hull_path: NodePath

## With the assist refused, the share of RATE_GAIN a centred axis still damps
## its spin with, so a ship knocked spinning with a wrecked cockpit settles.
const WRECKED_DAMPING := 0.5

## The share of RATE_GAIN the assist chases its rate with: half with a damaged
## cockpit (ship damage sections spec §2.2), so turns start and stop sluggishly.
var assist_strength := 1.0
## False with the cockpit wrecked: the assist is off and refused. Mending it
## brings back whatever the pilot last chose.
var assist_allowed := true:
	set(on):
		assist_allowed = on
		assist_enabled = assist_wanted

## The pilot's own choice, kept while the assist is refused (and saved).
var assist_wanted := true

## Turning assist off drops everything that needs it. Refused, the toggle does
## nothing.
var assist_enabled: bool = true:
	set(on):
		if assist_allowed:
			assist_wanted = on
		assist_enabled = assist_wanted and assist_allowed
		if not assist_enabled:
			speed_locked = false
			heading_hold = false
			velocity_hold = false

## The speed lock (spec §5.3): a forward speed, m/s, that assist holds while W
## and S are released. Signed, so a backward drift locks backward.
var speed_locked := false
var locked_speed := 0.0
## This tick's push, after boost and assist, in the hull's own axes, newtons.
## RcsShow reads it to show which thrusters are doing it.
var commanded_force_local := Vector3.ZERO
## This tick's gravity hold alone, in hull axes (within the budget, as it sits
## in commanded_force_local); zero without one. RcsShow leaves it unpuffed.
var hold_force_local := Vector3.ZERO
## Heading hold (spec §5.2): the world direction the nose is swung onto and
## held on. A direction, not a position, so the floating origin never moves it.
var heading_hold := false
var heading := Vector3.FORWARD
## The velocity hold (hostile ships spec §5.1): a world velocity, m/s, the
## assist cancels toward on every axis with no input, in place of rest (or the
## locked speed). Asked for by a pilot that is not you; never saved.
var velocity_hold := false
var held_velocity := Vector3.ZERO
## This tick's twist, after clamping, in the hull's own axes, newton-metres.
## RcsShow reads it.
var commanded_torque_local := Vector3.ZERO
## The ship's quantum store (quantum energy spec §8), or null. Null means
## free boost and full power, as in every test above that never sets it --
## a ship whose plant has not bound one yet flies exactly as before the
## quantum system existed.
var quantum: QuantumStore = null
## The hull's state for the band (health and damage spec §11): returns
## [how whole it is, 0..1; why it is crippled, or ""]. Given by Ship.
var hull_status: Callable
## Whether a hostile is out for this ship or its crew (hostile ships spec
## §4.3), set by the flight scene: with the orders at HOLD the HUD warns.
var hostile_engaging: Callable
## The ship's warp drive, or null. While it travels it flies the hull, and
## this ignores the pilot (the warp spec §5.2).
var warp: WarpDrive = null
## The ship's fire control, or null: its weapons show in the telemetry.
var fire_control: FireControl = null
## Where you are, for the limit; null means the cruise ceiling everywhere, as
## in every test that never sets it.
var whereabouts: Whereabouts = null
## What pulls here (desert-world spec §5.2), set by the flight scene; null means
## deep space, as in every test that never sets it. Every ship flies through this
## script, so every ship feels a world's pull and holds against it.
var gravity: WorldGravity = null

## Metres from the hull's origin down to the plane it stands on, landed: its
## landing legs' feet, at least 0.4 m under the bottom of its lowest cell and
## 0.1 m under its lowest hanging look (LandingLegs.stance_for), or that
## bottom with no legs (Ship.stance_depth; desert-world spec §5.2, phase 0
## Task 15). The ship sets it from its grid; keel_altitude and the levelling
## measure from it.
var keel_depth := 0.0

## True while the hull is landed, or touching and in contact with terrain this
## tick (not through the grace after contact is lost). With the
## stick's translation centred, the gravity hold and the levelling then stand
## down, so the ship's weight reaches the ground and it can settle; any
## translation input restores both at once (desert-world spec §5.3). Set by
## LandingMonitor every tick; false while flying, so always false in deep space.
var on_ground := false

## On the ground and not asked to move: the hold and the levelling stand
## down. LandingMonitor.translating is the one home of "asked to move" (the
## stick's translation, or a velocity hold climbing over HOLD_LIFTS), so an AI
## pilot's climbing hold gets its gravity hold back on the ground and rises
## off (Task 15, N1).
func _resting_on_ground() -> bool:
	if not on_ground:
		return false
	var up := gravity.up_at(_hull.global_position) if gravity != null else Vector3.ZERO
	return not LandingMonitor.translating(self, up)

## What the landing monitor says of the ground, for the telemetry; null in
## deep space and in tests that never set it.
var landing: LandingMonitor = null

## Levelling begins this high above the keel, fully on by LEVEL_FULL, turning
## the hull toward up at LEVEL_GAIN per second per radian of error.
const LEVEL_FROM := 150.0
const LEVEL_FULL := 100.0
const LEVEL_GAIN := 1.5
## This tick's limit with the assist on, m/s.
var current_limit := CRUISE_LIMIT_MPS
## True while boost is actually applying this tick: held, with translation
## input, at full power (spec §8.2). QuantumPlant polls this exactly as
## RcsShow polls commanded_force_local, to run the core's ring speed.
var boosting: bool = false
## True while boost is held but refused because the store is in low power.
## Goes to telemetry so the HUD can read *BOOST · LOW POWER*.
var boost_refused: bool = false

## Newtons available along each axis. Overwritten from ShipStats in Task 15.
var thrust_budget: Dictionary = {
	&"forward": 900_000.0,
	&"reverse": 300_000.0,
	&"lateral": 250_000.0,
	&"vertical": 250_000.0,
}
## Newton-metres available about each local axis (pitch, yaw, roll).
var torque_budget: Vector3 = Vector3(4_000_000.0, 4_000_000.0, 2_500_000.0)
## Moment of inertia about each local axis, kg*m². Overwritten from
## ShipStats alongside the budgets above; the default is a placeholder for
## a FlightComputer built without a Ship, as the tests do.
var inertia: Vector3 = Vector3(2_000_000.0, 2_000_000.0, 1_000_000.0)

var _translate_input: Vector3 = Vector3.ZERO
var _rotate_input: Vector3 = Vector3.ZERO
var _boost: bool = false

@onready var _hull: RigidBody3D = get_node(hull_path)

## Someone at the weapons station (ship weapons spec §7.1): the stick and the
## keys are centred and, with the assist on, the forward speed it had is
## locked, so it keeps its course while drift and spin are damped. Off, the
## helm flies it again. Letting go unlocks the speed only if the hold locked it:
## a lock the pilot had before is theirs.
var gunner_hold := false:
	set(on):
		if on == gunner_hold:
			return
		gunner_hold = on
		if on:
			_translate_input = Vector3.ZERO
			_rotate_input = Vector3.ZERO
			_boost = false
			if assist_enabled and not speed_locked:
				speed_locked = true
				locked_speed = forward_speed() if _hull != null else 0.0
				_hold_locked = true
		elif _hold_locked:
			_hold_locked = false
			speed_locked = false

## The speed lock was set by the hold, so the hold clears it.
var _hold_locked := false

func set_pilot_input(translate: Vector3, rotate: Vector3, boost: bool) -> void:
	if gunner_hold:
		return
	_translate_input = translate
	_rotate_input = rotate
	_boost = boost

func clear_pilot_input() -> void:
	# Called when the pilot stands up. Translation input latches at its last
	# value (the burn continues), rotation input does not (the ship stops
	# turning). This is what makes leaving the seat mid-burn interesting.
	_rotate_input = Vector3.ZERO

## Locks the hull's forward speed as it is now, or unlocks. Needs assist.
func toggle_speed_lock() -> void:
	_hold_locked = false   # a lock chosen by hand is the pilot's
	if speed_locked:
		speed_locked = false
	elif assist_enabled:
		speed_locked = true
		locked_speed = forward_speed()

## Speed out of the nose, m/s: negative when drifting backward.
func forward_speed() -> float:
	return -(_hull.global_transform.basis.inverse() * _hull.linear_velocity).z

## The assist's limit `altitude` over the ground of a well whose edge is
## `well_top` over it (§6). Pure. The cruise ceiling outside a well, on or
## under the ground, and above the well's edge.
static func speed_limit(altitude: float, well_top: float) -> float:
	if is_inf(altitude) or well_top <= 0.0 or altitude >= well_top:
		return CRUISE_LIMIT_MPS
	var a := maxf(altitude, 0.0)
	var climb := minf(CRUISE_LIMIT_MPS + a * LIMIT_PER_M, LIMIT_CAP)
	var fade := clampf((well_top - a) / (LIMIT_EASE * well_top), 0.0, 1.0)
	return lerpf(CRUISE_LIMIT_MPS, climb, fade)

## Entry heat (desert-world spec 6.5): speed from HEAT_FROM of the limit up
## to it, in air thicker than HEAT_AIR (full at HEAT_AIR_FULL). 0..1. It only
## draws a glow and a light buffet; it never hurts the hull.
const HEAT_FROM := 0.8
const HEAT_AIR := 0.05
const HEAT_AIR_FULL := 0.15

static func heat(speed: float, limit: float, air: float) -> float:
	var fast := clampf((speed / limit - HEAT_FROM) / (1.0 - HEAT_FROM), 0.0, 1.0)
	return fast * clampf((air - HEAT_AIR) / (HEAT_AIR_FULL - HEAT_AIR), 0.0, 1.0)

## This hull's heat now, by its own place and its own limit (never
## current_limit, which is the focus's). 0 with no gravity, frozen, or in warp.
## The limit is never under cruise, so a hull slower than HEAT_FROM of cruise
## has none: it answers before asking the world (every ship, every tick).
func entry_heat() -> float:
	if gravity == null or _hull == null or _hull.freeze:
		return 0.0
	if _hull.linear_velocity.length() < HEAT_FROM * CRUISE_LIMIT_MPS:
		return 0.0
	if (warp != null and warp.travelling()) or WarpArrival.of(_hull) != null:
		return 0.0
	var p := _hull.global_position
	var b := gravity.body_at(p)
	if b == null:
		return 0.0
	var limit := speed_limit(gravity.altitude_at(p), b.well_radius - b.radius)
	return heat(_hull.linear_velocity.length(), limit, gravity.air_at(p))

## The limit where the focus is now.
func speed_limit_now() -> float:
	if whereabouts == null:
		return CRUISE_LIMIT_MPS
	var b := whereabouts.well()
	if b == null:
		return CRUISE_LIMIT_MPS
	return speed_limit(whereabouts.altitude(), b.well_radius - b.radius)

## Swings the nose onto `direction` (world) and holds it there. Needs assist.
func set_heading(direction: Vector3) -> void:
	if not assist_enabled or direction.is_zero_approx():
		return
	heading = direction.normalized()
	heading_hold = true

## Hands pitch and yaw back to the pilot.
func clear_heading() -> void:
	heading_hold = false

## Holds the hull at `v_world` (world, m/s) on every axis nobody pushes on.
## Needs assist. The speed lock is left as it was; the hold overrides its
## target while it lasts.
func hold_velocity(v_world: Vector3) -> void:
	if not assist_enabled:
		return
	held_velocity = v_world
	velocity_hold = true

## Hands the quiet axes back to the assist's own targets.
func release_velocity() -> void:
	velocity_hold = false

## What a save keeps (docs/superpowers/specs/2026-09-26-saving-design.md §3):
## assist, the speed lock, heading hold, and a burn latched when the pilot
## stood up (clear_pilot_input). Seated, the stick overwrites the burn on the
## next frame.
func to_dict() -> Dictionary:
	return {
		"assist": assist_wanted,
		"speed_locked": speed_locked,
		"locked_speed": locked_speed,
		"heading_hold": heading_hold,
		"heading": SaveCodec.vec3(heading),
		"burn": SaveCodec.vec3(_translate_input),
		"boost": _boost,
	}

func from_dict(d: Dictionary) -> void:
	# Assist first: turning it off drops the locks. The pilot's choice even if
	# the cockpit is wrecked, so mending it after loading brings it back.
	assist_wanted = bool(d.get("assist", true))
	assist_enabled = assist_wanted
	speed_locked = bool(d.get("speed_locked", false)) and assist_enabled
	locked_speed = float(d.get("locked_speed", 0.0))
	heading = SaveCodec.to_vec3(d.get("heading"), Vector3.FORWARD)
	if heading.is_zero_approx():
		heading = Vector3.FORWARD
	heading = heading.normalized()
	heading_hold = bool(d.get("heading_hold", false)) and assist_enabled
	_translate_input = SaveCodec.to_vec3(d.get("burn")).clampf(-1.0, 1.0)
	_rotate_input = Vector3.ZERO
	_boost = bool(d.get("boost", false))

func _physics_process(delta: float) -> void:
	if (warp != null and warp.travelling()) or WarpArrival.of(_hull) != null:
		# Nothing fires: stale commands would keep the RCS puffing, and its
		# particles holding back the origin's shift, the whole way. Arriving
		# out of warp too (ship library spec §6.3): its puffs left a dotted
		# trail along its line.
		boosting = false
		boost_refused = false
		commanded_force_local = Vector3.ZERO
		hold_force_local = Vector3.ZERO
		commanded_torque_local = Vector3.ZERO
		return
	if _hull.freeze:
		# A frozen hull (parked, asleep) feels nothing and commands nothing.
		boosting = false
		boost_refused = false
		commanded_force_local = Vector3.ZERO
		hold_force_local = Vector3.ZERO
		commanded_torque_local = Vector3.ZERO
		return
	if gravity != null:
		# The pull itself (spec §5.2; Planetfall §8.2): an acceleration, so a
		# force of g x mass, at the hull's centre, in the world frame.
		_hull.apply_central_force(gravity.at(_hull.global_position) * _hull.mass)
		# Air drags on it (spec §6.5), by the air at the hull itself.
		_hull.apply_central_force(
				gravity.drag_at(_hull.global_position, _hull.linear_velocity) * _hull.mass)
	_apply_translation(delta)
	_apply_rotation(delta)

func _apply_translation(delta: float) -> void:
	current_limit = speed_limit_now()
	# A lock set high in a well must not outlive it: the assist would keep
	# driving toward a speed the clamp below refuses, and the readout would lie.
	locked_speed = clampf(locked_speed, -current_limit, current_limit)
	var basis := _hull.global_transform.basis
	var local_velocity := basis.inverse() * _hull.linear_velocity
	# While locked, W or S moves the lock: letting go holds the new speed.
	if speed_locked and not is_zero_approx(_translate_input.z):
		locked_speed = clampf(-local_velocity.z, -current_limit, current_limit)
	var full_power := quantum == null or not quantum.is_low_power()
	# "Boost with translation input" (spec §8.2): held, and asking for some
	# thrust -- holding it with the stick centred costs nothing, because the
	# multiplier below would have nothing to multiply anyway.
	var held: Variant = basis.inverse() * held_velocity if velocity_hold else null
	# A held velocity is pushed toward like input (hostile ships spec §5.3: a
	# brawler boosts in), but only while the hold is short of thrust.
	var wants_boost := _boost and (not is_zero_approx(_translate_input.length())
		or (held != null and hold_short(local_velocity, _translate_input, _hull.mass,
			_authority_budget(thrust_budget), held)))
	boosting = wants_boost and full_power
	boost_refused = wants_boost and not full_power
	if boosting and quantum != null:
		quantum.spend_continuous(QuantumValues.BOOST_COST * delta, &"boost")
	var pilot_force := translation_force(local_velocity, _translate_input, _hull.mass,
		_authority_budget(thrust_budget), boosting, assist_enabled, speed_locked, locked_speed,
		held)
	# The gravity hold (spec §5.2): with the assist on, the engines first cancel
	# the pull, from the *unscaled* budget -- low power halves only the pilot's
	# command and drift correction, never the hold (Planetfall §8.2).
	var hold := Vector3.ZERO
	if assist_enabled and gravity != null and not _resting_on_ground():
		var g_local := basis.inverse() * gravity.at(_hull.global_position)
		if not g_local.is_zero_approx():
			hold = gravity_hold(g_local, _hull.mass, thrust_budget)
	# Boost raises the ceiling only on the axes it boosts (plan constraint: that
	# direction's cap rises 2.5x, and the sum never exceeds the budget): an axis
	# with pilot input, or every axis under a velocity hold, which
	# translation_force boosts too. A forward boost must not let the vertical
	# thrusters fire past their budget against a hold plus drift.
	var total := hold + pilot_force
	var plain := within_budget(total, thrust_budget)
	hold_force_local = hold
	if boosting:
		var boosted := within_budget(total, thrust_budget, BOOST_MULTIPLIER)
		commanded_force_local = Vector3(
			boosted.x if held != null or not is_zero_approx(_translate_input.x) else plain.x,
			boosted.y if held != null or not is_zero_approx(_translate_input.y) else plain.y,
			boosted.z if held != null or not is_zero_approx(_translate_input.z) else plain.z)
	else:
		commanded_force_local = plain
	_hull.apply_central_force(basis * commanded_force_local)

	if assist_enabled and _hull.linear_velocity.length() > current_limit:
		_hull.linear_velocity = _hull.linear_velocity.normalized() * current_limit

## The force, in hull axes, that cancels a pull of `g_local` (m/s², hull axes)
## on `mass`, clamped to what the engines have: lateral and vertical either way,
## and fore (-z) and aft (+z) by their own budgets (spec §5.2). Pure.
static func gravity_hold(g_local: Vector3, mass: float, budget: Dictionary) -> Vector3:
	return within_budget(-g_local * mass, budget)

## `force` (hull axes) clamped to the budget times `scale`: the one ceiling the
## sum of hold and pilot command never exceeds. Pure.
static func within_budget(force: Vector3, budget: Dictionary, scale := 1.0) -> Vector3:
	var lateral: float = budget[&"lateral"] * scale
	var vertical: float = budget[&"vertical"] * scale
	var forward: float = budget[&"forward"] * scale
	var reverse: float = budget[&"reverse"] * scale
	return Vector3(
		clampf(force.x, -lateral, lateral),
		clampf(force.y, -vertical, vertical),
		clampf(force.z, -forward, reverse),
	)

## Height of the plane its feet stand on (keel_depth) over the ground under
## the hull: 0 landed on flat ground; INF outside a well.
func keel_altitude() -> float:
	if gravity == null:
		return INF
	return gravity.altitude_at(_hull.global_position) - keel_depth

## Pitch and roll rates (rad/s, hull axes) that swing the hull's up onto `up`
## (desert-world spec §5.2): LEVEL_GAIN times the angle between them, clamped
## to ASSIST_TURN_RATE and faded in from 0 at LEVEL_FROM to full at LEVEL_FULL.
## An axis the pilot is deflecting (`input` non-zero) is left alone; yaw never
## levels. Pure.
static func level_rates(hull_basis: Basis, up: Vector3, altitude: float, input: Vector3) -> Vector3:
	var fade := clampf((LEVEL_FROM - altitude) / (LEVEL_FROM - LEVEL_FULL), 0.0, 1.0)
	if fade <= 0.0 or up.is_zero_approx():
		return Vector3.ZERO
	var up_local := (hull_basis.inverse() * up).normalized()
	var angle := Vector3.UP.angle_to(up_local)
	var axis := Vector3.UP.cross(up_local)
	if axis.length() < 0.0001:
		# Level, or exactly inverted: upside down there is no axis, so roll.
		if angle < PI / 2.0:
			return Vector3.ZERO
		axis = Vector3.BACK
	axis = axis.normalized()
	var rate := minf(LEVEL_GAIN * angle, ASSIST_TURN_RATE) * fade
	return Vector3(
		0.0 if not is_zero_approx(input.x) else axis.x * rate,
		0.0,
		0.0 if not is_zero_approx(input.z) else axis.z * rate)

## How many times over the engines can lift the hull against the pull here:
## vertical thrust over weight; INF outside a world's well (spec §5.2).
func lift_margin() -> float:
	if gravity == null:
		return INF
	var g := gravity.surface_gravity_at(_hull.global_position)
	if g <= 0.0:
		return INF
	return float(thrust_budget[&"vertical"]) / (_hull.mass * g)

## The pilot's latched translation input, each axis in -1..1 (hull axes).
func translation_input() -> Vector3:
	return _translate_input

## The share of the RCS's rated force or torque the core still delivers
## right now: half in low power, all of it otherwise (spec §8.3). A null
## store is free full power, as every pre-quantum test assumes.
func _authority() -> float:
	return QuantumValues.LOW_POWER_AUTHORITY if (quantum != null and quantum.is_low_power()) else 1.0

func _authority_budget(budget: Dictionary) -> Dictionary:
	var authority := _authority()
	if authority >= 1.0:
		return budget
	var scaled := {}
	for key in budget:
		scaled[key] = budget[key] * authority
	return scaled

## The push along the hull's own axes, newtons (spec §5.3, §5.4). Pure, so
## drift and the speed lock are tested without physics.
##
## The pilot's input spends the budget along each axis, boosted if asked. With
## assist on, every axis the pilot is not pushing on also cancels velocity
## nobody asked for -- toward the locked speed fore and aft, when locked --
## at up to DRIFT_AUTHORITY of that axis's budget. Fore and aft, a push forward
## (-z) is the main engines' and a push aft the retros', each clamped by its
## own budget.
##
## `held`, a velocity in hull axes or null, is the velocity hold's target: the
## quiet axes cancel toward it instead, at the same budgets -- boosted, at
## BOOST_MULTIPLIER of them, as input is.
static func translation_force(local_velocity: Vector3, input: Vector3, mass: float,
		budget: Dictionary, boost: bool, assist: bool, locked: bool,
		locked_speed: float, held: Variant = null) -> Vector3:
	var forward: float = budget[&"forward"]
	var reverse: float = budget[&"reverse"]
	var lateral: float = budget[&"lateral"]
	var vertical: float = budget[&"vertical"]
	var force := Vector3(
		input.x * lateral,
		input.y * vertical,
		input.z * (forward if input.z < 0.0 else reverse),
	)
	if boost:
		force *= BOOST_MULTIPLIER
	if not assist:
		return force
	var target := Vector3(0.0, 0.0, -locked_speed if locked else 0.0)
	if held != null:
		target = held
	var wanted := Vector3(
		target.x - local_velocity.x if is_zero_approx(input.x) else 0.0,
		target.y - local_velocity.y if is_zero_approx(input.y) else 0.0,
		target.z - local_velocity.z if is_zero_approx(input.z) else 0.0,
	) * mass
	var share := DRIFT_AUTHORITY * (BOOST_MULTIPLIER if boost and held != null else 1.0)
	return force + Vector3(
		clampf(wanted.x, -lateral * share, lateral * share),
		clampf(wanted.y, -vertical * share, vertical * share),
		clampf(wanted.z, -forward * share, reverse * share),
	)

## Whether the velocity hold (`held`, hull axes) wants more than the assist's
## unboosted budget on some quiet axis: the only time a boost buys it anything.
static func hold_short(local_velocity: Vector3, input: Vector3, mass: float, budget: Dictionary,
		held: Vector3) -> bool:
	var want := (held - local_velocity) * mass
	var cap := Vector3(budget[&"lateral"], budget[&"vertical"],
		budget[&"forward"] if want.z < 0.0 else budget[&"reverse"]) * DRIFT_AUTHORITY
	for i in 3:
		if is_zero_approx(input[i]) and absf(want[i]) > cap[i]:
			return true
	return false

func _apply_rotation(_delta: float) -> void:
	var basis := _hull.global_transform.basis
	var local_spin := basis.inverse() * _hull.angular_velocity
	var rotate := _rotate_input
	if heading_hold:
		# The hold flies pitch and yaw as a stick would; roll stays the pilot's.
		# Low power limps the hold too (spec §8.3), so it still reaches its
		# target rate, just more slowly.
		var rate := heading_rate(basis.inverse() * heading, torque_budget * _authority(), inertia)
		rotate = Vector3(rate.x / ASSIST_TURN_RATE, rate.y / ASSIST_TURN_RATE, _rotate_input.z)
	var height := keel_altitude() if assist_enabled else INF
	if height < LEVEL_FROM and not _resting_on_ground():
		# Near the ground the assist levels pitch and roll to the local up. The
		# heading hold owns pitch, so it levels roll only; the stick wins its axes.
		var stick := Vector3(1.0 if heading_hold else _rotate_input.x, 0.0, _rotate_input.z)
		var level := level_rates(basis, gravity.up_at(_hull.global_position), height, stick)
		rotate += level / ASSIST_TURN_RATE
	commanded_torque_local = attitude_torque(rotate, local_spin)
	_hull.apply_torque(basis * commanded_torque_local)

## Torque about the hull's own axes, in newton-metres.
##
## Assist off: the stick is a throttle on the RCS. Full deflection spends
## the whole budget, and nothing stops the spin but the pilot.
##
## Assist on: the stick commands a *rate*, and the assist spends whatever
## torque that needs -- up to the budget the RCS actually provides. This is
## what makes ships of different sizes handle alike: a heavy ship takes
## longer to reach the commanded rate, but it reaches the same rate, and a
## centred stick means a commanded rate of zero, which is the damping term.
##
## Both branches scale by inertia, never by mass. A rate error is an angular
## acceleration, and torque = inertia * angular acceleration; the earlier
## mass-scaled damping was dimensionally wrong and, on the 95 t starter
## shuttle, swamped its own RCS authority several times over -- the assist
## fought every turn the pilot asked for.
func attitude_torque(rotate_input: Vector3, local_angular_velocity: Vector3) -> Vector3:
	# Low power halves the RCS's authority here too (spec §8.3): the ship
	# still turns and brakes, just at half the rate.
	var budget := torque_budget * _authority()
	if not assist_allowed:
		# Refused (a wrecked cockpit): each deflected axis is the stick's, raw,
		# and each centred one still damps, at WRECKED_DAMPING of the gain.
		var damp := -local_angular_velocity * RATE_GAIN * WRECKED_DAMPING * inertia
		var raw := rotate_input * budget
		return Vector3(
			raw.x if not is_zero_approx(rotate_input.x) else clampf(damp.x, -budget.x, budget.x),
			raw.y if not is_zero_approx(rotate_input.y) else clampf(damp.y, -budget.y, budget.y),
			raw.z if not is_zero_approx(rotate_input.z) else clampf(damp.z, -budget.z, budget.z)
		)
	if not assist_enabled:
		return rotate_input * budget
	var rate_error := rotate_input * ASSIST_TURN_RATE - local_angular_velocity
	var wanted := rate_error * RATE_GAIN * assist_strength * inertia
	return Vector3(
		clampf(wanted.x, -budget.x, budget.x),
		clampf(wanted.y, -budget.y, budget.y),
		clampf(wanted.z, -budget.z, budget.z)
	)

## The (pitch, yaw) turn rate, rad/s, that swings the nose (-Z) onto
## `target_local`, a direction in the hull's own axes (spec §5.2). Pure.
##
## The turn is about (-Z) x target, which never has a roll part, by the angle
## between them. The rate is the fastest the RCS can still brake from in time
## -- sqrt(2 * share * alpha * angle), alpha being the weaker of pitch and
## yaw's torque over inertia -- capped at the ordinary turn rate, and linear
## near the end so it settles instead of chattering. Dead astern, it pitches.
static func heading_rate(target_local: Vector3, budget: Vector3, moment: Vector3) -> Vector3:
	var target := target_local.normalized()
	var angle := Vector3.FORWARD.angle_to(target)
	if angle < 0.0001:
		return Vector3.ZERO
	var axis := Vector3.FORWARD.cross(target)
	if axis.length() < 0.0001:
		axis = Vector3.RIGHT
	axis = Vector3(axis.x, axis.y, 0.0).normalized()
	var alpha := minf(budget.x / maxf(moment.x, 1.0), budget.y / maxf(moment.y, 1.0))
	var rate := minf(ASSIST_TURN_RATE,
		minf(sqrt(2.0 * HOLD_BRAKE_SHARE * alpha * angle), HOLD_GAIN * angle))
	return axis * rate

## The vehicle-facing half of the HUD contract. Any node with this method is
## a telemetry source as far as HudRoot is concerned -- there is no interface
## type and no base class to inherit, which is what lets a future ground
## vehicle or turret station light the same HUD.
func build_telemetry() -> VehicleTelemetry:
	# boost_active must mean "boost is applying this tick", not merely "the
	# pilot is holding it" -- otherwise VelocityPanel's BOOST ON contradicts
	# EnergyPanel's BOOST · LOW POWER off the same tick. `boosting` is the
	# same gated flag that multiplies the force in _apply_translation(); the
	# raw `_boost` (held, regardless of whether it applies) stays internal.
	var t := VehicleTelemetry.from_state(
		_hull.global_transform.basis,
		_hull.global_position,
		warp.velocity() if warp != null and warp.travelling() else _hull.linear_velocity,
		_hull.angular_velocity,
		assist_enabled,
		boosting,
		current_limit
	)
	t.heading_hold = heading_hold
	t.heading = heading
	t.speed_locked = speed_locked
	t.locked_speed = locked_speed
	t.limit_raised = current_limit > CRUISE_LIMIT_MPS + 0.5
	t.has_energy = true
	t.energy_label = &"QE"
	if quantum != null:
		t.energy = quantum.amount
		t.energy_capacity = quantum.capacity
		t.energy_line = quantum.line()
		t.energy_state = &"low_power" if quantum.is_low_power() else &"full"
	else:
		t.energy_state = &"full"
	t.boost_refused = boost_refused
	t.lift_margin = lift_margin()
	t.ground_status = landing.ground_status() if landing != null else ""
	if hull_status.is_valid():
		var status: Array = hull_status.call()
		t.has_hull = true
		t.hull = status[0]
		t.crippled_reason = status[1]
		t.hud_flicker = status.size() > 2 and bool(status[2])
		t.cockpit_cracks = int(status[3]) if status.size() > 3 else 0
	t.tool_text = "BOOST −%d/S" % roundi(QuantumValues.BOOST_COST) if boosting else ""
	if fire_control != null and not fire_control.turrets.is_empty():
		t.has_weapons = true
		t.weapons_engage = fire_control.orders == FireControl.Orders.ENGAGE
		t.weapons_pips = fire_control.pips()
		t.weapons_low_power = t.weapons_engage and quantum != null and quantum.is_low_power()
		t.hostile_on_hold = not t.weapons_engage and hostile_engaging.is_valid() and bool(hostile_engaging.call())
	return t
