class_name VehicleTelemetry
extends RefCounted

## One frame's worth of a vehicle's state, as the HUD needs to read it.
##
## Built fresh each frame. Treat it as immutable once returned from
## from_state() -- nothing here enforces that, and a caller that mutates a
## shared instance after handing it out would create an order-dependent bug
## that is miserable to trace back to its cause. Deliberately holds no node
## references: an element that receives this cannot reach back into the
## vehicle, which is what keeps src/ui free of vehicle-specific types.

## Speed, m/s.
var speed: float = 0.0
## The vehicle's own cruise ceiling, so no readout hardcodes 120.
var cruise_limit: float = 0.0
## World frame. The velocity marker projects `hull_origin + world_velocity`.
var world_velocity: Vector3 = Vector3.ZERO
## Velocity in the hull's frame. X is drift across the beam, Y is vertical,
## -Z is out the nose. Reserved for the drift readout the design doc
## describes but that has not been built yet -- currently computed every
## frame and read by nothing but this file's own test.
var local_velocity: Vector3 = Vector3.ZERO
## Rotation about the hull's own axes as (pitch, yaw, roll), radians/sec.
var local_angular_velocity: Vector3 = Vector3.ZERO
var assist_enabled: bool = false
var boost_active: bool = false
var hull_origin: Vector3 = Vector3.ZERO
## A point to steer home to, when the vehicle has one: a spacewalker's airlock
## (airlock spec §8.3). Set after from_state(); the ship has none.
var has_beacon: bool = false
var beacon: Vector3 = Vector3.ZERO
## What the flight computer is holding (flight controls spec §5.5). Set after
## from_state(); off for anything that holds nothing, like the suit.
var heading_hold: bool = false
## World direction, unit length.
var heading: Vector3 = Vector3.FORWARD
var speed_locked: bool = false
var locked_speed: float = 0.0
## The pilot's hands (spec §7), set by PilotControls. The virtual stick's
## offset from the centre of view, and the point-mode pointer's, both in
## fractions of the viewport's height, +y down; the stick's full-deflection
## radius and dead zone in the same units.
var stick: Vector2 = Vector2.ZERO
var stick_radius: float = 0.0
var stick_deadzone: float = 0.0
var pointing: bool = false
var pointer: Vector2 = Vector2.ZERO

## Takes plain values rather than a body on purpose: it is the seam that lets
## every derivation here be tested headless, with no nodes and no physics
## steps. Callers holding a physics body adapt in one line; see the vehicle's
## own telemetry adapter.
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
