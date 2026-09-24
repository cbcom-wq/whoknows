class_name Suit
extends RefCounted

## The spacewalk suit's thrusters (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §8.1), as one pure step: thrust along the view,
## and a suit assist that, on any axis you are not thrusting along, brings your
## velocity relative to your own ship to zero with the same thrust -- so near a
## drifting ship you hold station beside it, and a ship pulling away harder
## than the suit can push still leaves you behind. With the assist on, your
## speed relative to the ship is capped. Off, it is pure Newton.

## Thrust, m/s^2: gentle, so a spacewalk is a float, not a flight.
const ACCEL := 2.5
const ASSIST_CAP := 8.0
const ROLL_RATE := deg_to_rad(90.0)

## The new velocity after `delta` seconds. `thrust_input` is in view axes (+x
## right, +y up, +z back, each -1..1); `view` is the camera's basis; `v_ref` is
## your own ship's velocity where you are.
static func step(v: Vector3, v_ref: Vector3, thrust_input: Vector3, view: Basis, assist: bool,
		delta: float) -> Vector3:
	var push := thrust_input
	if push.length() > 1.0:
		push = push.normalized()
	v += view * push * ACCEL * delta
	if not assist:
		return v
	var local := view.inverse() * (v - v_ref)
	for axis in 3:
		if is_zero_approx(thrust_input[axis]):
			local[axis] = move_toward(local[axis], 0.0, ACCEL * delta)
	return v_ref + view * local.limit_length(ASSIST_CAP)
