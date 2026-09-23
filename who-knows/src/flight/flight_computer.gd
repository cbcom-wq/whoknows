class_name FlightComputer
extends Node

## Assisted Newtonian control of a hull RigidBody3D.
##
## Assist on: counters lateral drift, damps residual rotation, holds a
## cruise ceiling. Assist off: raw Newtonian, input maps straight to thrust.

const CRUISE_LIMIT_MPS := 120.0
const BOOST_MULTIPLIER := 2.5
const DRIFT_AUTHORITY := 0.6   ## fraction of budget assist may spend on drift
## Turn rate full stick asks for under assist, radians per second.
const ASSIST_TURN_RATE := deg_to_rad(60.0)
## How hard the assist chases the rate it was asked for, in 1/s. Doubles as
## the damping rate when the stick is centred and the target rate is zero.
const RATE_GAIN := 4.0

@export var hull_path: NodePath

var assist_enabled: bool = true

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

func _physics_process(delta: float) -> void:
	_apply_translation(delta)
	_apply_rotation(delta)

func _apply_translation(delta: float) -> void:
	var basis := _hull.global_transform.basis
	var force := Vector3.ZERO

	var longitudinal := _translate_input.z
	if longitudinal < 0.0:
		force += basis * Vector3(0, 0, -1) * absf(longitudinal) * thrust_budget[&"forward"]
	elif longitudinal > 0.0:
		force += basis * Vector3(0, 0, 1) * longitudinal * thrust_budget[&"reverse"]

	force += basis * Vector3(_translate_input.x, 0, 0) * thrust_budget[&"lateral"]
	force += basis * Vector3(0, _translate_input.y, 0) * thrust_budget[&"vertical"]

	if _boost:
		force *= BOOST_MULTIPLIER

	if assist_enabled:
		force += _drift_correction(basis)

	_hull.apply_central_force(force)

	if assist_enabled and _hull.linear_velocity.length() > CRUISE_LIMIT_MPS:
		_hull.linear_velocity = _hull.linear_velocity.normalized() * CRUISE_LIMIT_MPS

func _drift_correction(basis: Basis) -> Vector3:
	# Cancel velocity components the pilot is not asking for.
	var local_vel := basis.inverse() * _hull.linear_velocity
	var unwanted := Vector3(
		local_vel.x if is_zero_approx(_translate_input.x) else 0.0,
		local_vel.y if is_zero_approx(_translate_input.y) else 0.0,
		local_vel.z if is_zero_approx(_translate_input.z) else 0.0,
	)
	var authority := Vector3(
		thrust_budget[&"lateral"], thrust_budget[&"vertical"], thrust_budget[&"reverse"]
	) * DRIFT_AUTHORITY
	var correction := Vector3(
		clampf(-unwanted.x * _hull.mass, -authority.x, authority.x),
		clampf(-unwanted.y * _hull.mass, -authority.y, authority.y),
		clampf(-unwanted.z * _hull.mass, -authority.z, authority.z),
	)
	return basis * correction

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
