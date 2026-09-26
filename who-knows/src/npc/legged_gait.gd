class_name LeggedGait
extends RefCounted

## Six feet, three at a time (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.4): a tripod gait any legged NPC can
## use. Each foot stays planted where it is until its home under the body has
## moved more than STRIDE away, then steps there -- but only when its tripod's
## turn has come, so three feet are always down. Near a camera each foot's
## home is found by a short ray to the ground, so it steps over scree and up
## ledges; farther off the legs play a canned cycle and cast nothing.

const LEGS := 6
## Legs 0, 3, 4 step together, then 1, 2, 5.
const TRIPODS: Array[int] = [0, 1, 1, 0, 0, 1]
const STRIDE := 0.25
const LIFT := 0.08
## A step takes between these, seconds: quicker the faster it goes.
const STEP_FAST := 0.1
const STEP_SLOW := 0.3
## Beyond this from a camera, metres, no rays.
const NEAR := 60.0

## Where each foot rests under the body, in the body's frame.
var homes: Array[Vector3] = []
## Where each foot is, engine space.
var feet: Array[Vector3] = []
## Rays cast, for tests.
var rays := 0
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _t: Array[float] = []
var _turn := 0
var _phase := 0.0
var _started := false
var _started_moving := false
var _last := Vector3.ZERO

func _init(p_homes: Array[Vector3]) -> void:
	homes = p_homes
	for i in homes.size():
		feet.append(Vector3.ZERO)
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
		_t.append(-1.0)

## Moves the feet for `delta` seconds with the body at `body`, going `speed`.
## `space` is null far from any camera. Returns the feet, engine space.
func update(body: Transform3D, speed: float, delta: float, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID], mask: int) -> Array[Vector3]:
	var up := body.basis.y.normalized()
	if not _started:
		for i in homes.size():
			feet[i] = body * homes[i]
		_started = true
	if space == null:
		_phase += delta * maxf(speed, 0.0) * 6.0
		for i in homes.size():
			var bob := maxf(sin(_phase + PI * TRIPODS[i]), 0.0) * LIFT if speed > 0.05 else 0.0
			feet[i] = body * homes[i] + up * bob
			_t[i] = -1.0
		return feet
	# Quicker steps the faster it goes, each landing a little ahead of where
	# the body is going, so no foot trails far behind.
	var step_time := clampf(STRIDE / maxf(speed, 0.01) * 0.4, STEP_FAST, STEP_SLOW)
	var moved := (body.origin - _last) / maxf(delta, 0.0001) if _started_moving else Vector3.ZERO
	_last = body.origin
	_started_moving = true
	var lead := moved * step_time
	var stepping := false
	for i in homes.size():
		if _t[i] >= 0.0:
			_t[i] += delta / step_time
			if _t[i] >= 1.0:
				_t[i] = -1.0
				feet[i] = _to[i]
			else:
				feet[i] = _from[i].lerp(_to[i], _t[i]) + up * sin(PI * _t[i]) * LIFT
				stepping = true
	if not stepping:
		# The tripod whose feet lag most goes next.
		var lag := [0.0, 0.0]
		for i in homes.size():
			lag[TRIPODS[i]] = maxf(lag[TRIPODS[i]], feet[i].distance_to(body * homes[i]))
		_turn = 0 if lag[0] >= lag[1] else 1
		if lag[_turn] > STRIDE:
			for i in homes.size():
				if TRIPODS[i] == _turn:
					_from[i] = feet[i]
					_to[i] = _ground(body.translated(lead), homes[i], up, space, exclude, mask)
					_t[i] = 0.0
	return feet

func _ground(body: Transform3D, home: Vector3, up: Vector3, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID], mask: int) -> Vector3:
	var over := body * home
	rays += 1
	var q := PhysicsRayQueryParameters3D.create(over + up * 0.3, over - up * 0.5, mask, exclude)
	var hit := space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else over

## True while any foot is in the air.
func stepping() -> bool:
	for t in _t:
		if t >= 0.0:
			return true
	return false

## Which feet are in the air.
func lifted() -> Array[int]:
	var out: Array[int] = []
	for i in _t.size():
		if _t[i] >= 0.0:
			out.append(i)
	return out
