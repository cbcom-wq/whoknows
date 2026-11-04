class_name LandingMonitor
extends Node

## The hull's relationship with a world's ground (Planetfall §9; desert-world
## spec §5.3). FLYING touches down, settles, and is LANDED: frozen in place, so
## it cannot creep or jitter and the airlock's step-out point cannot move. Only
## the pilot's translation lifts it off again.
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

signal state_changed(state: State)
signal hard_landing(speed: float)

var hull: RigidBody3D
var flight: FlightComputer

var state: State = State.FLYING
var _s := {state = State.FLYING, held = 0.0, apart = 0.0}
var _tilt := 0.0
## Whether the hull is in contact with terrain this tick.
var _in_contact := false
## The hull's velocity at the previous tick: the contact is reported after the
## step that took the speed off, so the closing speed is read from before it.
var _last_velocity := Vector3.ZERO

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
	var velocity := hull.linear_velocity
	_tilt = (hull.global_transform.basis * Vector3.UP).angle_to(up)
	_in_contact = _touching_ground()
	var inputs := {
		touching = _in_contact,
		closing = -_last_velocity.dot(up),
		speed = velocity.length(),
		spin = hull.angular_velocity.length(),
		tilt = _tilt,
		translating = not flight.translation_input().is_zero_approx(),
	}
	_last_velocity = velocity
	var result := step(_s, inputs, delta)
	_s = {state = result.state, held = result.held, apart = result.apart}
	_set_state(result.state)
	_publish()
	if result.hard > 0.0:
		hard_landing.emit(result.hard)

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
## contact this tick. Through the grace with no contact the hold and the
## levelling are back at once.
func _publish() -> void:
	if flight != null:
		flight.on_ground = state == State.LANDED or (state == State.TOUCHING and _in_contact)

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
