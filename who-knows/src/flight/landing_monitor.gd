class_name LandingMonitor
extends Node

## The hull's relationship with a world's ground (Planetfall §9; desert-world
## spec §5.3). FLYING touches down, settles, and is LANDED: frozen in place, so
## it cannot creep or jitter and the airlock's step-out point cannot move. Only
## the pilot's translation lifts it off again -- or, handed to its AI pilot, a
## velocity hold that climbs (translating()).
##
## The transition table is a static pure function, `step`, tested headless (the
## VelocityMarker state-policy pattern); the node only gathers inputs and
## applies the result. It reads the hull and the flight computer, never the
## starter's numbers, so every ship can land.
##
## Hard landings (over HARD_LANDING m/s closing) are a warning and a thud, with
## no damage yet (desert-world spec §5.2): Ship gives terrain its own crash
## threshold, TERRAIN_CRASH_FROM, above any landing.

enum State { FLYING, TOUCHING, LANDED }

## Closing speed over which a touchdown is hard, m/s.
const HARD_LANDING := 4.0
## Seconds held still on the ground before the hull is landed.
const SETTLE_TIME := 1.0
## Slower than this, m/s, counts as still.
const SETTLE_SPEED := 0.5
## Slower than this, rad/s, counts as not turning.
const SETTLE_SPIN := 0.1
## Tilted past this from the local up, the ship may rest but never lands.
const MAX_TILT := deg_to_rad(25.0)
## Seconds without ground contact before TOUCHING gives up and flies.
const LIFT_GRACE := 0.25
## A velocity hold climbing faster than this, m/s along up, is translating:
## your ship handed to its pilot flies on the hold with the stick centred, and
## must lift off as the stick would (final review M1).
const HOLD_LIFTS := 0.5
## A hull restored landed (a save, a ship woken) whose stance plane is more
## than RESTORE_SLACK m off the ground under it -- saved on a world whose ground
## has changed since, as a world that is a desert since phase 2 -- is set down
## again rather than left frozen in the air or in the ground: lifted to
## RESTORE_DROP m over the ground if buried, or brought down to it if more than
## RESTORE_FALL m up, then let fall with its hold off until it touches, and it
## settles and lands as any landing does (desert world phase 2, Review Focus 4).
## Between the two it falls where it is: a ship saved standing on a boulder
## only settles back onto it.
const RESTORE_SLACK := 0.5
const RESTORE_DROP := 0.5
const RESTORE_FALL := 2.0

signal state_changed(state: State)
signal hard_landing(speed: float)

var hull: RigidBody3D
var flight: FlightComputer

var state: State = State.FLYING
## True while LANDED by restore_landed() -- a save loaded, a ship woken --
## rather than by settling: what shows the ship landed (the landing ramp, Task
## 14) is there at once, with no animation. False again once it leaves LANDED.
var restored := false
var _s := {state = State.FLYING, held = 0.0, apart = 0.0}
var _tilt := 0.0
## Whether the hull is in contact with terrain this tick.
var _in_contact := false
## The hull's velocity at the previous tick: the contact is reported after the
## step that took the speed off, so the closing speed is read from before it.
var _last_velocity := Vector3.ZERO
## Restored landed and not yet checked against the ground (RESTORE_SLACK).
var _check_restore := false
## Let go by that check: the hold stands down until it lands again, or the
## pilot moves it.
var _dropping := false

## One tick of the table (Planetfall §9). `s` has `state`, `held` (seconds
## settled) and `apart` (seconds without contact); `i` has `touching`,
## `closing` (m/s into the ground), `speed`, `spin`, `tilt` (radians) and
## `translating`. Returns the new `s` and `hard`: the closing speed if this
## step was a hard touchdown, else 0. Pure.
static func step(s: Dictionary, i: Dictionary, delta: float) -> Dictionary:
	var out := {state = s.state, held = s.held, apart = s.apart, hard = 0.0}
	match int(s.state):
		State.FLYING:
			if i.touching:
				out.state = State.TOUCHING
				out.held = 0.0
				out.apart = 0.0
				if i.closing > HARD_LANDING:
					out.hard = i.closing
		State.TOUCHING:
			if i.touching:
				out.apart = 0.0
				var still: bool = i.speed < SETTLE_SPEED and i.spin < SETTLE_SPIN \
					and i.tilt < MAX_TILT and not i.translating
				out.held = s.held + delta if still else 0.0
				if out.held >= SETTLE_TIME:
					out.state = State.LANDED
			else:
				out.held = 0.0
				out.apart = s.apart + delta
				if out.apart >= LIFT_GRACE:
					out.state = State.FLYING
					out.apart = 0.0
		State.LANDED:
			# A frozen static hull may stop reporting contacts: only the pilot
			# lifts it off.
			if i.translating:
				out.state = State.FLYING
				out.held = 0.0
				out.apart = 0.0
	return out

func is_landed() -> bool:
	return state == State.LANDED

## Radians between the hull's up and the local up, as of the last tick.
func tilt() -> float:
	return _tilt

## Why the airlock will not cycle: "" when landed.
func refusal() -> String:
	if state == State.LANDED:
		return ""
	if _uneven():
		return "Uneven ground · tilt %d°" % _tilt_degrees()
	return "Not landed"

## The HUD's word for the ground under the ship, or "".
func ground_status() -> String:
	if state == State.LANDED:
		return "LANDED"
	if _uneven():
		return "UNEVEN GROUND · TILT %d°" % _tilt_degrees()
	if flight != null and flight.lift_margin() < 1.0:
		return "TOO HEAVY FOR THIS WORLD"
	return ""

## A saved landed ship loads frozen on the ground (spec §5.3).
func restore_landed() -> void:
	_s = {state = State.LANDED, held = SETTLE_TIME, apart = 0.0}
	restored = true
	_check_restore = true
	_dropping = false
	_set_state(State.LANDED)

func _physics_process(delta: float) -> void:
	if hull == null or flight == null:
		return
	var up := Vector3.ZERO
	if flight.gravity != null:
		up = flight.gravity.up_at(hull.global_position)
	if up.is_zero_approx():
		# Out of a well nothing steps: a flying ship stays flying, and one
		# restored landed stays landed.
		_in_contact = false
		_publish()
		return
	if _check_restore:
		_check_restore = false
		if _set_down_again(up):
			# Its contacts are from where it was: read them next tick.
			_last_velocity = Vector3.ZERO
			_publish()
			return
	var velocity := hull.linear_velocity
	_tilt = (hull.global_transform.basis * Vector3.UP).angle_to(up)
	_in_contact = _touching_ground()
	var inputs := {
		touching = _in_contact,
		closing = -_last_velocity.dot(up),
		speed = velocity.length(),
		spin = hull.angular_velocity.length(),
		tilt = _tilt,
		translating = translating(flight, up),
	}
	_last_velocity = velocity
	var result := step(_s, inputs, delta)
	_s = {state = result.state, held = result.held, apart = result.apart}
	if _dropping and (result.state == State.LANDED or inputs.translating):
		_dropping = false
	_set_state(result.state)
	_publish()
	if result.hard > 0.0:
		hard_landing.emit(result.hard)

## Whether `fc` is asked to move the hull, with `up` the local up: the pilot's
## translation, or a velocity hold climbing over HOLD_LIFTS (the AI pilot's, a
## stick centred). Only this lifts a landed ship off.
static func translating(fc: FlightComputer, up: Vector3) -> bool:
	if not fc.translation_input().is_zero_approx():
		return true
	return fc.velocity_hold and fc.held_velocity.dot(up) > HOLD_LIFTS

## A restored landed hull more than RESTORE_SLACK off the ground under it,
## `up` the local up: put within reach of the ground and let fall (see
## RESTORE_SLACK); true if it was. One on the ground stays frozen where it is.
func _set_down_again(up: Vector3) -> bool:
	var off := flight.keel_altitude()
	if not is_finite(off) or absf(off) <= RESTORE_SLACK:
		return false
	if off < 0.0 or off > RESTORE_FALL:
		hull.global_position += up * (RESTORE_DROP - off)
	_s = {state = State.FLYING, held = 0.0, apart = 0.0}
	_dropping = true
	_set_state(State.FLYING)
	return true

## Whether the hull reports a contact with the ground this tick.
func _touching_ground() -> bool:
	for body in hull.get_colliding_bodies():
		if is_ground(body):
			return true
	return false

## A body that is a world's ground: on the terrain layer (not rocks, hulls or
## NPCs). Pure.
static func is_ground(body: Object) -> bool:
	return body is CollisionObject3D and ((body as CollisionObject3D).collision_layer & BodyProxy.LAYER) != 0

## The one place `on_ground` is set (Ruling 7a): landed, or touching and in
## contact this tick, or let fall by a restore's check until it lands.
## Through the grace with no contact the hold and the levelling are back at
## once.
func _publish() -> void:
	if flight != null:
		flight.on_ground = state == State.LANDED or (state == State.TOUCHING and _in_contact) \
			or (state != State.LANDED and _dropping)

## Over MAX_TILT while touching: the ship rests but will not land.
func _uneven() -> bool:
	return state == State.TOUCHING and _tilt > MAX_TILT

func _tilt_degrees() -> int:
	return roundi(rad_to_deg(_tilt))

func _set_state(next: State) -> void:
	if next == state and (next != State.LANDED or (hull == null or hull.freeze)):
		return
	var was := state
	state = next
	if next != State.LANDED:
		restored = false
	if hull != null:
		if next == State.LANDED:
			hull.linear_velocity = Vector3.ZERO
			hull.angular_velocity = Vector3.ZERO
			hull.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			hull.freeze = true
		elif was == State.LANDED:
			hull.freeze = false
	_publish()
	if next != was:
		state_changed.emit(next)
