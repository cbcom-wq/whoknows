class_name GroundWalker
extends Locomotor

## Walks a person over open ground (docs/superpowers/specs/2026-11-16-wadoo-design.md
## §12): along its site's route, turning at TURN_RATE and going on only as fast as it
## faces the way (so it turns before it walks off), its feet on the site's ground and
## upright along the site's up. Kinematic: it sets the transform and never slides
## against colliders, as the route keeps to open ground, so a town of people costs
## little. It keeps PERSONAL from others by a push the site's open ground allows; a
## shove slides it a little and dies away.
##
## Points are [east, north] m in the site's frame (x = east, z = -north). Its site
## answers route(from, to) -> PackedVector2Array, ground(p) -> Vector3 (site-local),
## up_at(local) -> Vector3, neighbours(npc) -> PackedVector2Array and open(p) -> bool.

const TURN_RATE := 5.0
## Within this of a corner of its route it heads for the next.
const CORNER := 0.35
## It slows within this of the end, and stops within ARRIVED.
const SLOWING := 0.8
const ARRIVED := 0.15
## The room it keeps from others, m, and how hard it moves apart at full overlap, m/s.
const PERSONAL := 0.6
const PUSH := 1.2
## How fast a shove dies away, 1/s.
const SLIDE_DECAY := 4.0
const SLIDE_STOPS := 0.03
## Others are asked for every this many steps.
const NEIGHBOURS_EVERY := 4

var _path := PackedVector2Array()
var _next := 0
var _target: Variant = null
var _heading := Vector2(0.0, 1.0)
var _slide := Vector2.ZERO
var _push := Vector2.ZERO
var _ask := 0
var _replan := false

func enter(npc: Npc) -> void:
	npc.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_path = PackedVector2Array()
	_target = null
	_slide = Vector2.ZERO
	_push = Vector2.ZERO
	_ask = 0
	var fwd := -npc.local_transform().basis.z
	if Vector2(fwd.x, -fwd.z).length() > 0.01:
		_heading = Vector2(fwd.x, -fwd.z).normalized()

func step(npc: Npc, intent: Intent, delta: float) -> void:
	# a person's site (WadooSite) answers more than NpcSite does: asked untyped
	var site: Variant = npc.site
	if site == null or not site.alive() or delta <= 0.0:
		return
	var here3 := npc.local_position()
	var here := Vector2(here3.x, -here3.z)
	var want := Vector2.ZERO
	if intent.move_to != null:
		var to3: Vector3 = intent.move_to
		var to := Vector2(to3.x, -to3.z)
		if _replan or _target == null or (_target as Vector2).distance_to(to) > 0.01:
			_plan(site, here, to)
		want = _steer(here, npc.species.top_speed * intent.speed, delta)
	else:
		_target = null
		_path = PackedVector2Array()
	var turned := _turn(npc, intent, here, want, delta)
	if want != Vector2.ZERO:
		# only as fast as it faces the way
		want *= clampf(_heading.dot(want.normalized()), 0.0, 1.0)
	_ask -= 1
	if _ask <= 0:
		_ask = NEIGHBOURS_EVERY
		_push = _apart(site, npc, here)
	if _slide != Vector2.ZERO:
		_slide *= exp(-SLIDE_DECAY * delta)
		if _slide.length() < SLIDE_STOPS:
			_slide = Vector2.ZERO
	var next := here + want * delta
	var extra := (_push + _slide) * delta
	if extra != Vector2.ZERO:
		if site.open(next + extra):
			next += extra
		else:
			_slide = Vector2.ZERO
	if next == here and not turned:
		npc.velocity = Vector3.ZERO
		return
	var feet := here3 if next == here else site.ground(next) as Vector3
	var up: Vector3 = site.up_at(feet)
	var fwd := Vector3(_heading.x, 0.0, -_heading.y)
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var frame: Transform3D = site.frame()
	npc.global_transform = frame * Transform3D(Basis.looking_at(fwd, up), feet)
	npc.velocity = frame.basis * ((feet - here3) / delta)

func _plan(site: Variant, here: Vector2, to: Vector2) -> void:
	_target = to
	_replan = false
	_path = site.route(here, to)
	_next = 1 if _path.size() > 1 else 0

## Where it heads now, m/s, never past the end of its route in one step.
func _steer(here: Vector2, speed: float, delta: float) -> Vector2:
	if _path.size() < 2:
		return Vector2.ZERO
	while _next < _path.size() - 1 and here.distance_to(_path[_next]) < CORNER:
		_next += 1
	var last := _next >= _path.size() - 1
	var toward := _path[_next] - here
	var dist := toward.length()
	if last and dist < ARRIVED:
		return Vector2.ZERO
	if last:
		speed = minf(speed * clampf(dist / SLOWING, 0.2, 1.0), dist / delta)
	return toward / dist * speed

## Turns its heading toward the way it goes, or, standing, toward what it faces.
## True if it turned.
func _turn(npc: Npc, intent: Intent, here: Vector2, want: Vector2, delta: float) -> bool:
	var look := Vector2.ZERO
	if want.length() > 0.01:
		look = want
	elif intent.face != null:
		var f: Vector3 = intent.face
		look = Vector2(f.x, -f.z) - here
	if look.length() < 0.01:
		return false
	var err := _heading.angle_to(look)
	if absf(err) < 0.001:
		return false
	_heading = _heading.rotated(clampf(err, -TURN_RATE * delta, TURN_RATE * delta))
	return true

## The push away from others too near, m/s.
func _apart(site: Variant, npc: Npc, here: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for p: Vector2 in site.neighbours(npc):
		var away := here - p
		var d := away.length()
		if d >= PERSONAL:
			continue
		var dir := away / d if d > 0.001 else Vector2(_heading.y, -_heading.x)
		push += dir * PUSH * (1.0 - d / PERSONAL)
	return push

## Standing on the ground.
func grounded() -> bool:
	return true

## A shove slides it over the ground (never into a wall) and dies away; it plans
## again from where it ends up.
func shoved(npc: Npc, dv: Vector3) -> void:
	var local := npc.site.frame().basis.inverse() * dv if npc.site != null else dv
	_slide += Vector2(local.x, -local.z)
	_replan = true

## The points it means to walk, for tests and probes.
func path() -> PackedVector2Array:
	return _path
