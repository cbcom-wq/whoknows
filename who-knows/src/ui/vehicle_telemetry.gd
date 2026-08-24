class_name VehicleTelemetry
extends RefCounted

## One frame's worth of a vehicle's state, as the HUD needs to read it.
##
## Built fresh each frame and never mutated afterwards. Deliberately holds
## no node references: an element that receives this cannot reach back into
## the ship, which is what keeps src/ui free of vehicle-specific types.

var speed: float = 0.0
## The vehicle's own cruise ceiling, so no readout hardcodes 120.
var cruise_limit: float = 0.0
## World frame. The velocity marker projects `hull_origin + world_velocity`.
var world_velocity: Vector3 = Vector3.ZERO
## Velocity in the hull's frame. X is drift across the beam, Y is vertical,
## -Z is out the nose. This is the drift readout.
var local_velocity: Vector3 = Vector3.ZERO
## Rotation about the hull's own axes as (pitch, yaw, roll), radians/sec.
var local_angular_velocity: Vector3 = Vector3.ZERO
var assist_enabled: bool = false
var boost_active: bool = false
var hull_origin: Vector3 = Vector3.ZERO

## Takes plain values rather than a body on purpose: it is the seam that lets
## every derivation here be tested headless, with no nodes and no physics
## steps. Callers holding a RigidBody3D adapt in one line -- see
## FlightComputer.build_telemetry().
static func from_state(
	basis: Basis,
	origin: Vector3,
	linear_velocity: Vector3,
	angular_velocity: Vector3,
	assist: bool,
	boost: bool,
	limit: float
) -> VehicleTelemetry:
	var t := VehicleTelemetry.new()
	# One inverse, reused. Godot reports both velocities in the world frame.
	var inv := basis.inverse()
	t.world_velocity = linear_velocity
	t.local_velocity = inv * linear_velocity
	t.local_angular_velocity = inv * angular_velocity
	t.speed = linear_velocity.length()
	t.hull_origin = origin
	t.assist_enabled = assist
	t.boost_active = boost
	t.cruise_limit = limit
	return t
