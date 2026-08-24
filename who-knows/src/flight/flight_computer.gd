class_name FlightComputer
extends Node

## Assisted Newtonian control of a hull RigidBody3D.
##
## Assist on: counters lateral drift, damps residual rotation, holds a
## cruise ceiling. Assist off: raw Newtonian, input maps straight to thrust.

const CRUISE_LIMIT_MPS := 120.0
const BOOST_MULTIPLIER := 2.5
const DRIFT_AUTHORITY := 0.6   ## fraction of budget assist may spend on drift
const ROTATION_DAMPING := 3.0

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
	var torque := basis * (_rotate_input * torque_budget)
	_hull.apply_torque(torque)

	if assist_enabled:
		var residual := _hull.angular_velocity
		var damping := -residual * ROTATION_DAMPING * _hull.mass
		_hull.apply_torque(damping)

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
