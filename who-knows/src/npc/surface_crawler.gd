class_name SurfaceCrawler
extends Locomotor

## Walks on any surface, any way up (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.3): what a rock in zero g needs.
## Two short rays down its own body -- under its middle and ahead of it --
## find the ground; its up turns smoothly to the ground's normal; while it grips it moves
## only along the surface, pressed gently onto it, which stands in for gravity. Over a convex edge it wraps round by looking
## down and back from ahead of its feet; into a concave corner it climbs. With
## no ground under it, or knocked off, it hands over to ZeroGDrift.

## While it grips, it moves only along the surface, pressed onto it at this
## speed, m/s: speed toward or away from the surface never builds up, so it
## follows a face round an edge instead of flying off it.
const STICK := 0.6
## How fast its up follows the ground: settled in about three of these.
const SETTLE := 0.05
## How much more the surface ahead counts than the ground under it, where
## the two differ.
const LEAD := 6.0
## How fast its speed along the surface changes, m/s^2.
const ACCEL := 10.0
## It turns about its up this fast, rad/s.
const TURN_RATE := 5.0
## Herd mates closer than this push it away.
const PERSONAL := 1.2
const SEPARATION := 1.5
## With no ground this long, it lets go.
const LOST_AFTER := 0.2
## A shove carrying it off the surface faster than this knocks it off, m/s.
const KNOCKED_OFF := 1.5
## Footing moving faster than this is lost, m/s.
const SLIPPERY := 3.0
## It stands this far off the ground it settles on, and stops this far short
## of a wall ahead, metres.
const LIFT := 0.01
const WALL_GAP := 0.45
## Slower than this, m/s, it is standing still.
const STILL := 0.25
## At rest, it looks at the ground again every this many ticks.
const RECHECK := 30
## A leap reaches at most this far, metres.
const LEAP_REACH := 30.0
const ARRIVED := 0.15

var gripping := true
## Herd mates' positions (site-local), from the last think.
var mates: Array[Vector3] = []
var _lost_for := 0.0
var _let_go := false
var _leap_to: Variant = null
var _leapt: Intent = null
var _rest_ticks := 0
## The ground under it when it last settled, and where it was then.
var _settled := {}
var _settled_at := Vector3.INF
## Standing on something that does not move.
var _on_rock := false

func enter(npc: Npc) -> void:
	npc.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	gripping = true
	_lost_for = 0.0
	_let_go = false
	_leap_to = null

func step(npc: Npc, intent: Intent, delta: float) -> void:
	if _resting(npc, intent):
		return
	var space := npc.get_world_3d().direct_space_state
	var basis := npc.global_basis.orthonormalized()
	var up := basis.y
	var fwd := -basis.z
	var o := npc.global_position
	var length := npc.species.size
	var height := npc.species.height
	var exclude: Array[RID] = [npc.get_rid()]
	# The ground found when it last settled is the ground under it now.
	var centre: Dictionary = _settled if _settled_at.is_equal_approx(o) and not _settled.is_empty() \
		else _ray(space, o + up * height * 0.75, o - up * height * 1.5, exclude)
	var fore := _ray(space, o + fwd * length * 0.5 + up * height * 0.75, o + fwd * length * 0.5 - up * height * 1.5, exclude)
	var target := Vector3.ZERO
	var hits := 0
	if not centre.is_empty():
		target += centre["normal"] * 2.0
		hits += 1
	# The ground ahead leads: where the surface turns, it turns with it, rather
	# than settling halfway between the two faces.
	var ahead := _ray(space, o + up * height * 0.5, o + up * height * 0.5 + fwd * length * 0.8, exclude)
	if not ahead.is_empty():
		# A concave corner: a wall to climb.
		target += ahead["normal"] * LEAD
		hits += 1
	elif not fore.is_empty():
		target += fore["normal"]
		hits += 1
	else:
		# A convex edge ahead: look down and back from beyond its feet.
		var wrap := _ray(space, o + fwd * length * 0.8 - up * height * 0.8, o - up * height * 0.8, exclude)
		if wrap.is_empty():
			wrap = _ray(space, o + fwd * length * 0.5 - up * height * 1.6, o - fwd * length * 0.3 - up * height * 1.6, exclude)
		if not wrap.is_empty():
			target += wrap["normal"] * LEAD
			hits += 1
	gripping = hits > 0 and not _let_go
	_lost_for = 0.0 if hits > 0 else _lost_for + delta
	if hits > 0:
		target = target.normalized()
		var new_up := up.slerp(target, 1.0 - exp(-delta / SETTLE)).normalized()
		basis = Basis(Quaternion(up, new_up)) * basis
		up = new_up
	# Its feet on moving footing (a shoved piece of rubble) move with it.
	var footing := Vector3.ZERO
	_on_rock = not centre.is_empty() and not (centre["collider"] is RigidBody3D)
	if not centre.is_empty() and centre["collider"] is RigidBody3D:
		var body := centre["collider"] as RigidBody3D
		footing = body.linear_velocity + body.angular_velocity.cross(o - body.global_position)
		if footing.length() > SLIPPERY:
			_let_go = true
	# Along the surface: toward where it is going, apart from its mates.
	var want := Vector3.ZERO
	var frame := npc.site.frame()
	if intent.move_to != null:
		var to: Vector3 = frame * (intent.move_to as Vector3) - o
		to -= up * to.dot(up)
		var dist := to.length()
		if dist > ARRIVED:
			want = to / dist * npc.species.top_speed * intent.speed * clampf(dist / 0.5, 0.2, 1.0)
	for m in mates:
		var away: Vector3 = o - frame * m
		away -= up * away.dot(up)
		var d := away.length()
		if d > 0.01 and d < PERSONAL:
			want += away / d * SEPARATION * (1.0 - d / PERSONAL)
	var normal_v := up * npc.velocity.dot(up)
	var along := npc.velocity - normal_v - footing
	along -= up * along.dot(up)
	along = along.move_toward(want, ACCEL * delta)
	# Face the way it goes, or what it looks at.
	var look := want
	if intent.face != null:
		look = frame * (intent.face as Vector3) - o
	look -= up * look.dot(up)
	if look.length() > 0.05:
		var angle := (-basis.z).signed_angle_to(look.normalized(), up)
		basis = Basis(up, clampf(angle, -TURN_RATE * delta, TURN_RATE * delta)) * basis
	npc.global_basis = basis.orthonormalized()
	npc.up_direction = up
	if gripping:
		_walk(npc, space, exclude, along, footing, ahead, fwd, up, delta)
	else:
		npc.velocity = along + normal_v + footing
		npc.move_and_slide()
	if intent.action == &"leap" and intent != _leapt and intent.leap_to != null:
		_leapt = intent
		_leap_to = aim_leap(npc, frame * (intent.leap_to as Vector3))

## Gripping, it steps along the surface and settles onto the ground found by a
## ray under its new place, rather than sliding its body against the rock:
## the rock's collision is thousands of triangles, and a slide against it
## costs three times all its rays together. It stops short of a wall ahead,
## which the ground ahead will have it climb.
func _walk(npc: Npc, space: PhysicsDirectSpaceState3D, exclude: Array[RID], along: Vector3, footing: Vector3,
		ahead: Dictionary, fwd: Vector3, up: Vector3, delta: float) -> void:
	var move := (along + footing) * delta
	if not ahead.is_empty():
		var gap := ((ahead["position"] as Vector3) - npc.global_position).dot(fwd) - WALL_GAP
		var into := move.dot(fwd)
		if into > gap:
			move -= fwd * (into - maxf(gap, 0.0))
	var p := npc.global_position + move
	var height := npc.species.height
	var ground := _ray(space, p + up * height * 0.75, p - up * height * 1.5, exclude)
	if not ground.is_empty():
		p = (ground["position"] as Vector3) + up * LIFT
	else:
		p -= up * STICK * delta
	npc.global_position = p
	npc.velocity = along + footing
	_settled = ground
	_settled_at = npc.global_position

## Standing still on solid rock with nowhere to go, it does nothing at all: no
## rays, no sliding. Most skitters are grazing or keeping still most of the
## time, so this is most of what they cost. It looks again every RECHECK
## ticks, and at once if anything moves it.
func _resting(npc: Npc, intent: Intent) -> bool:
	var going := intent.move_to != null and npc.global_position.distance_to(npc.site.frame() * (intent.move_to as Vector3)) > ARRIVED
	var leaping := intent.action == &"leap" and intent != _leapt
	var turning := intent.face != null
	if going or leaping or turning or not gripping or _let_go or not _on_rock \
			or _along(npc).length() > STILL or not mates.is_empty() and _crowded(npc):
		_rest_ticks = 0
		return false
	_rest_ticks += 1
	if _rest_ticks % RECHECK == 0:
		return false
	return true

## Its speed along the surface, not counting the press onto it.
static func _along(npc: Npc) -> Vector3:
	var up := npc.global_basis.y
	return npc.velocity - up * npc.velocity.dot(up)

## A herd mate close enough to push it aside.
func _crowded(npc: Npc) -> bool:
	var frame := npc.site.frame()
	for m in mates:
		if npc.global_position.distance_to(frame * m) < PERSONAL * 0.8:
			return true
	return false

## Where a leap toward `toward` (engine space) would land, or null: nothing to
## land on within reach, and it does not jump.
func aim_leap(npc: Npc, toward: Vector3) -> Variant:
	var o := npc.global_position + npc.global_basis.y * npc.species.height * 0.5
	var dir := (toward - o).normalized()
	var hit := _ray(npc.get_world_3d().direct_space_state, o + dir * 0.6, o + dir * LEAP_REACH, [npc.get_rid()])
	return hit["position"] if not hit.is_empty() else null

func handover(npc: Npc) -> StringName:
	if _leap_to != null:
		var drift := npc.locomotors.get(&"zero_g_drift") as ZeroGDrift
		if drift != null:
			drift.leap_to = _leap_to
		_leap_to = null
		return &"zero_g_drift"
	if _let_go or _lost_for >= LOST_AFTER:
		return &"zero_g_drift"
	return &""

func grounded() -> bool:
	return gripping

## A shove: away from the surface faster than KNOCKED_OFF, and it lets go.
func shoved(npc: Npc, dv: Vector3) -> void:
	npc.velocity += dv
	if dv.dot(npc.global_basis.y) > KNOCKED_OFF:
		_let_go = true

static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, AsteroidBody.LAYER, exclude)
	return space.intersect_ray(q)
