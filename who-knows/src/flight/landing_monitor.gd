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
## A hull restored landed (a save, a ship woken) that is not resting on
## anything solid -- saved on a world whose ground has changed since, as a
## world that is a desert since phase 2 -- is set down again rather than left
## frozen in the air or in the ground (desert world phase 2, Review Focus 4).
## How far it can move down before its colliders meet the solid ground (the
## world's chunks with their boulders) is measured: within RESTORE_SLACK m it
## is resting -- on the ground, on a boulder, on uneven ground -- and stays
## frozen where it is. Further, it is let fall with its hold off until it
## lands, as any landing does: from where it is up to RESTORE_FALL m, or
## brought down to RESTORE_DROP m over what is under it first. Buried, its
## stance plane more than RESTORE_SLACK under the analytic ground (which a
## physics query cannot see out of), it is lifted to RESTORE_DROP m over that.
const RESTORE_SLACK := 0.5
const RESTORE_DROP := 0.5
const RESTORE_FALL := 2.0
## The check waits until every chunk under the hull's footprint (its
## ANCHOR_RADIUS round it) is solid (WorldSurface.solid_round), then one
## physics tick more, so the broadphase has their shapes: a fixed 10 ticks
## left a woken ship's neighbouring chunks queued behind every other, and a
## foot over one not solid yet read a gap, fell and sank (final review I3).
## RESTORE_WAIT physics ticks is the most it waits before it trusts the
## analytic ground alone.
const RESTORE_WAIT := 60
## Seconds a restored hull is let fall at most before its hold is back, in
## case it never lands.
const DROP_MOST := 10.0

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
## Restored landed and not yet checked against the ground (RESTORE_SLACK),
## for how many ticks it has waited for solid ground (RESTORE_WAIT), and
## whether the ground under its footprint has been seen solid (the check runs
## the tick after).
var _check_restore := false
var _check_ticks := 0
var _footprint_seen := false
## Let go by that check: the hold stands down until it lands again, the pilot
## moves it, it bounces off into the air, or DROP_MOST has passed.
var _dropping := false
var _dropping_for := 0.0

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
	_dropping = false
	_set_state(State.LANDED)
	_check_restore = true
	_check_ticks = 0
	_footprint_seen = false

func _physics_process(delta: float) -> void:
	if hull == null or flight == null:
		return
	var up := Vector3.ZERO
	if flight.gravity != null:
		up = flight.gravity.up_at(hull.global_position)
	if up.is_zero_approx():
		# Out of a well nothing steps: a flying ship stays flying, and one
		# restored landed stays landed, with no ground to check it against.
		# (Its gravity not wired yet is not out of a well: that waits.)
		if flight.gravity != null:
			_check_restore = false
		_in_contact = false
		_publish()
		return
	if _check_restore:
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
	if _dropping:
		_dropping_for += delta
		if result.state == State.LANDED or inputs.translating or _dropping_for > DROP_MOST \
				or (int(_s.state) == State.TOUCHING and result.state == State.FLYING):
			_dropping = false
	_s = {state = result.state, held = result.held, apart = result.apart}
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

## The restore check (see RESTORE_SLACK), `up` the local up: true if the
## hull was let go to fall. One resting on something stays frozen where it is,
## `restored` and all; the check stays pending while it waits for the ground
## under its footprint (RESTORE_WAIT), and is then one cast.
func _set_down_again(up: Vector3) -> bool:
	var off := flight.keel_altitude()
	if state != State.LANDED or not hull.freeze or not is_finite(off):
		_check_restore = false
		return false
	_check_ticks += 1
	if not _footprint_seen and _check_ticks < RESTORE_WAIT:
		_footprint_seen = _footprint_solid()
		return false
	var move := 0.0
	if off < -RESTORE_SLACK:
		move = RESTORE_DROP - off
	else:
		var gap := _gap_below(up, maxf(off, 0.0) + RESTORE_FALL + RESTORE_SLACK)
		if gap < 0.0:
			# Nothing solid within reach, with the ground under it solid (or
			# the wait over): go by the analytic ground.
			gap = off
		if gap <= RESTORE_SLACK:
			_check_restore = false
			return false
		if gap > RESTORE_FALL:
			move = RESTORE_DROP - gap
	_check_restore = false
	hull.global_position += up * move
	_s = {state = State.FLYING, held = 0.0, apart = 0.0}
	_dropping = true
	_dropping_for = 0.0
	_set_state(State.FLYING)
	return true

## Whether every finest chunk under the hull's footprint (its ANCHOR_RADIUS
## round its origin) is solid on the world it is on; false off a world's
## ground, or with no surface drawn.
func _footprint_solid() -> bool:
	var surface := flight.gravity.surface_at(hull.global_position) if flight.gravity != null else null
	if surface == null:
		return false
	return surface.solid_round(surface.universe.to_universe(hull.global_position),
		float(hull.get_meta(AsteroidStream.ANCHOR_RADIUS, 1.0)))

## How far the hull can move down `up` before one of its colliders meets the
## solid ground (BodyProxy.LAYER), looking `reach` m; -1 if nothing is there.
## Already touching is 0; a collider already inside the ground is not counted
## (a cast ignores what it starts inside). Not a landing ramp's collider
## (LandingRamp.COLLIDER_META): a restored hull's ramp is down at once with
## its tip on the ground, and counted it held a hull hovering a metre up
## frozen in the air (final review I5).
func _gap_below(up: Vector3, reach: float) -> float:
	var space := hull.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.collision_mask = BodyProxy.LAYER
	q.exclude = [hull.get_rid()]
	q.motion = -up * reach
	var best := INF
	for node in hull.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		if cs.disabled or cs.shape == null or cs.has_meta(LandingRamp.COLLIDER_META):
			continue
		q.shape = cs.shape
		q.transform = cs.global_transform
		var r := space.cast_motion(q)
		if r.size() > 0 and float(r[0]) < 1.0:
			best = minf(best, float(r[0]) * reach)
	return best if best < INF else -1.0

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
		_check_restore = false
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
