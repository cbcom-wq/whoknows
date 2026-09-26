class_name Suit
extends RefCounted

## The spacewalk suit's thrusters (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §8.1), as one pure step: thrust along the view,
## and a suit assist that, on any axis you are not thrusting along, brings your
## velocity relative to your own ship to zero with the same thrust -- so near a
## drifting ship you hold station beside it, and a ship pulling away harder
## than the suit can push still leaves you behind. With the assist on, your
## speed relative to the ship is capped. Off, it is pure Newton.
##
## When the suit's cell runs dry (quantum energy spec §9) the thrusters stop
## and home_step takes over: the emergency cell steers you home.

## Thrust, m/s^2: gentle, so a spacewalk is a float, not a flight.
const ACCEL := 2.5
const ASSIST_CAP := 8.0
const ROLL_RATE := deg_to_rad(90.0)
## The emergency cell (spec §9): home at 1.5 m/s relative to your ship,
## chasing that at a gentler 1 m/s^2 than the thrusters.
const HOME_SPEED := 1.5
const HOME_ACCEL := 1.0
## How the last stretch closes: m/s of speed per metre still to go. Slow
## enough that HOME_ACCEL can always follow it down (0.6 x 1.5 m/s is
## 0.9 m/s^2), so you settle on the point instead of overshooting it.
const HOME_GAIN := 0.6

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

## The new velocity after `delta` seconds on the emergency cell, homing on a
## point `to_target` away (world axes): it chases your ship's velocity `v_ref`
## plus HOME_SPEED toward the point, at HOME_ACCEL, easing off as the point
## nears so that you stop there and stay within 0.2 m of it. With nowhere to
## go (`to_target` zero) it holds station beside the ship.
static func home_step(v: Vector3, v_ref: Vector3, to_target: Vector3, delta: float) -> Vector3:
	var want := v_ref
	var dist := to_target.length()
	if dist > 0.0:
		want += to_target / dist * minf(HOME_SPEED, dist * HOME_GAIN)
	return v.move_toward(want, HOME_ACCEL * delta)
