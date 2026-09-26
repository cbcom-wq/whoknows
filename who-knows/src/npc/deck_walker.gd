class_name DeckWalker
extends Locomotor

## Walks an interior's floors under its felt gravity (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.5). It plans over the site's
## DeckPaths, cell centre to cell centre, rounding each corner as it nears it,
## and holds its line against the hull's shove up to its grip: past that it
## slides, like a crate. Braced, it grips harder.
##
## Its site is a ShipSite. The interior never moves, so nothing here shifts.

## How hard its wheels hold, m/s^2: a full burn is about 5.7 felt, and the
## felt shove is capped at 12 (MotionCoupling.SHOVE_CAP).
const GRIP := 8.0
const BRACED_GRIP := 10.0
## Within this of a waypoint it turns for the next one.
const CORNER := 0.8
## It slows within this of where it is going, and stops within ARRIVED.
const SLOWING := 0.5
const ARRIVED := 0.05
const TURN_RATE := 4.0

var _path: Array[Vector3i] = []
var _next := 0
var _target: Variant = null
var _version := -1

func enter(npc: Npc) -> void:
	npc.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	npc.up_direction = Vector3.UP
	npc.floor_snap_length = 0.2
	_path.clear()
	_target = null

func step(npc: Npc, intent: Intent, delta: float) -> void:
	var site := npc.site as ShipSite
	if site == null or not site.alive():
		return
	var frame := site.frame()
	npc.velocity += site.gravity(Vector3.ZERO) * delta
	var here := npc.local_position()
	var want := Vector3.ZERO
	var braced := intent.action == &"brace"
	if intent.move_to != null and not braced:
		var to: Vector3 = intent.move_to
		if _target == null or not (to as Vector3).is_equal_approx(_target) or _version != site.version:
			_plan(site, here, to)
		want = _steer(site, here, to, npc.species.top_speed * intent.speed)
	var grip := BRACED_GRIP if braced else GRIP
	var v_local := frame.basis.inverse() * npc.velocity
	var flat := Vector3(v_local.x, 0.0, v_local.z).move_toward(want, grip * delta)
	npc.velocity = frame.basis * Vector3(flat.x, v_local.y, flat.z)
	npc.move_and_slide()
	_turn(npc, intent, frame, flat, delta)

## Where it is going now, as a flat local velocity.
func _steer(site: ShipSite, here: Vector3, to: Vector3, speed: float) -> Vector3:
	if _path.is_empty():
		return Vector3.ZERO
	while _next < _path.size() - 1 and _flat(_waypoint(_next, to) - here).length() < CORNER:
		_next += 1
	var last := _next >= _path.size() - 1
	var toward := _flat(_waypoint(_next, to) - here)
	var dist := toward.length()
	if last and dist < ARRIVED:
		return Vector3.ZERO
	if last:
		speed *= clampf(dist / SLOWING, 0.15, 1.0)
	return toward / maxf(dist, 0.0001) * speed

func _waypoint(i: int, to: Vector3) -> Vector3:
	return to if i >= _path.size() - 1 else DeckPaths.floor_point(_path[i])

func _plan(site: ShipSite, here: Vector3, to: Vector3) -> void:
	_target = to
	_version = site.version
	_path = site.paths.path(DeckPaths.cell_at(here), DeckPaths.cell_at(to))
	_next = 1 if _path.size() > 1 else 0

## Turns about its up toward what it faces, or the way it goes.
func _turn(npc: Npc, intent: Intent, frame: Transform3D, flat: Vector3, delta: float) -> void:
	var look := Vector3.ZERO
	if intent.face != null:
		look = _flat((intent.face as Vector3) - npc.local_position())
	elif flat.length() > 0.1:
		look = flat
	if look.length() < 0.01:
		return
	var want_yaw := atan2(-look.x, -look.z)
	var local := frame.basis.inverse() * npc.global_basis
	var yaw := local.get_euler().y
	var turned := yaw + clampf(wrapf(want_yaw - yaw, -PI, PI), -TURN_RATE * delta, TURN_RATE * delta)
	npc.global_basis = frame.basis * Basis(Vector3.UP, turned)

## Standing on the floor.
func grounded() -> bool:
	return true

## The cells it means to walk, for tests and the overlay.
func path() -> Array[Vector3i]:
	return _path

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
