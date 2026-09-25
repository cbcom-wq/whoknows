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
## Fraction of the budget assist may spend on velocity nobody asked for: all
## of it, so after a turn your travel swings onto the nose in seconds (spec
## §5.4). At 0.6 the shuttle slid the old way for half a minute after a turn.
const DRIFT_AUTHORITY := 1.0
## Turn rate full stick asks for under assist, radians per second.
const ASSIST_TURN_RATE := deg_to_rad(60.0)
## How hard the assist chases the rate it was asked for, in 1/s. Doubles as
## the damping rate when the stick is centred and the target rate is zero.
const RATE_GAIN := 4.0

@export var hull_path: NodePath

## Turning assist off drops everything that needs it.
var assist_enabled: bool = true:
	set(on):
		assist_enabled = on
		if not on:
			speed_locked = false

## The speed lock (spec §5.3): a forward speed, m/s, that assist holds while W
## and S are released. Signed, so a backward drift locks backward.
var speed_locked := false
var locked_speed := 0.0
## This tick's push, after boost and assist, in the hull's own axes, newtons.
## RcsShow reads it to show which thrusters are doing it.
var commanded_force_local := Vector3.ZERO

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

func set_pilot_input(translate: Vector3, rotate: Vector3, boost: bool) -> void:
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
	if speed_locked:
		speed_locked = false
	elif assist_enabled:
		speed_locked = true
		locked_speed = forward_speed()

## Speed out of the nose, m/s: negative when drifting backward.
func forward_speed() -> float:
	return -(_hull.global_transform.basis.inverse() * _hull.linear_velocity).z

func _physics_process(delta: float) -> void:
	_apply_translation(delta)
	_apply_rotation(delta)

func _apply_translation(_delta: float) -> void:
	var basis := _hull.global_transform.basis
	var local_velocity := basis.inverse() * _hull.linear_velocity
	# While locked, W or S moves the lock: letting go holds the new speed.
	if speed_locked and not is_zero_approx(_translate_input.z):
		locked_speed = clampf(-local_velocity.z, -CRUISE_LIMIT_MPS, CRUISE_LIMIT_MPS)
	commanded_force_local = translation_force(local_velocity, _translate_input, _hull.mass,
		thrust_budget, _boost, assist_enabled, speed_locked, locked_speed)
	_hull.apply_central_force(basis * commanded_force_local)

	if assist_enabled and _hull.linear_velocity.length() > CRUISE_LIMIT_MPS:
		_hull.linear_velocity = _hull.linear_velocity.normalized() * CRUISE_LIMIT_MPS

## The push along the hull's own axes, newtons (spec §5.3, §5.4). Pure, so
## drift and the speed lock are tested without physics.
##
## The pilot's input spends the budget along each axis, boosted if asked. With
## assist on, every axis the pilot is not pushing on also cancels velocity
## nobody asked for -- toward the locked speed fore and aft, when locked --
## at up to DRIFT_AUTHORITY of that axis's budget. Fore and aft, a push forward
## (-z) is the main engines' and a push aft the retros', each clamped by its
## own budget.
static func translation_force(local_velocity: Vector3, input: Vector3, mass: float,
		budget: Dictionary, boost: bool, assist: bool, locked: bool,
		locked_speed: float) -> Vector3:
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
	var target_z := -locked_speed if locked else 0.0
	var wanted := Vector3(
		-local_velocity.x if is_zero_approx(input.x) else 0.0,
		-local_velocity.y if is_zero_approx(input.y) else 0.0,
		target_z - local_velocity.z if is_zero_approx(input.z) else 0.0,
	) * mass
	return force + Vector3(
		clampf(wanted.x, -lateral * DRIFT_AUTHORITY, lateral * DRIFT_AUTHORITY),
		clampf(wanted.y, -vertical * DRIFT_AUTHORITY, vertical * DRIFT_AUTHORITY),
		clampf(wanted.z, -forward * DRIFT_AUTHORITY, reverse * DRIFT_AUTHORITY),
	)

func _apply_rotation(_delta: float) -> void:
	var basis := _hull.global_transform.basis
	var local_spin := basis.inverse() * _hull.angular_velocity
	_hull.apply_torque(basis * attitude_torque(_rotate_input, local_spin))

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
	if not assist_enabled:
		return rotate_input * torque_budget
	var rate_error := rotate_input * ASSIST_TURN_RATE - local_angular_velocity
	var wanted := rate_error * RATE_GAIN * inertia
	return Vector3(
		clampf(wanted.x, -torque_budget.x, torque_budget.x),
		clampf(wanted.y, -torque_budget.y, torque_budget.y),
		clampf(wanted.z, -torque_budget.z, torque_budget.z)
	)

## The vehicle-facing half of the HUD contract. Any node with this method is
## a telemetry source as far as HudRoot is concerned -- there is no interface
## type and no base class to inherit, which is what lets a future ground
## vehicle or turret station light the same HUD.
func build_telemetry() -> VehicleTelemetry:
	return VehicleTelemetry.from_state(
		_hull.global_transform.basis,
		_hull.global_position,
		_hull.linear_velocity,
		_hull.angular_velocity,
		assist_enabled,
		_boost,
		CRUISE_LIMIT_MPS
	)
