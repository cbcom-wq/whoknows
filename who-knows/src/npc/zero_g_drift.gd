class_name ZeroGDrift
extends Locomotor

## Free movement in open space (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.4): straight lines, no gravity. A
## leap flies at a spot the crawler found to land on, turning feet first. A
## skitter knocked off its rock tumbles, steadies, and puffs its way back to
## the nearest surface with small jets of gas -- a few of them. Touching down
## hands back to the crawler.

const LEAP_SPEED := 6.0
## Tumbling this long before it steadies, seconds.
const TUMBLE := 0.6
## One puff: this much speed, at most this often, this many in all.
const PUFF := 0.8
const PUFF_EVERY := 1.0
const PUFFS := 6
## How far it looks for a surface to puff back to, metres.
const LOOK := 60.0
## Within this of a surface under its feet, it has landed.
const LANDED := 0.6
const TURN := 6.0

## Set by the crawler before a leap: where to land, engine space.
var leap_to: Variant = null
var puffs_left := PUFFS
var _since := 0.0
var _last_puff := -INF
var _spin := Vector3.ZERO
var _leaping := false

func enter(npc: Npc) -> void:
	npc.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_since = 0.0
	_last_puff = -INF
	_leaping = leap_to != null
	if _leaping:
		var from := npc.global_position + npc.global_basis.y * npc.species.height * 0.5
		npc.velocity = ((leap_to as Vector3) - from).normalized() * LEAP_SPEED
		_spin = Vector3.ZERO
	else:
		_spin = npc.velocity.cross(npc.global_basis.y).limit_length(3.0)
	leap_to = null

func step(npc: Npc, _intent: Intent, delta: float) -> void:
	_since += delta
	var basis := npc.global_basis.orthonormalized()
	if _leaping or _since >= TUMBLE:
		# Feet first, the way it is going.
		if npc.velocity.length() > 0.1:
			var want := -npc.velocity.normalized()
			var up := basis.y.slerp(want, minf(TURN * delta, 1.0)).normalized()
			basis = Basis(Quaternion(basis.y, up)) * basis
		if not _leaping:
			_puff_home(npc)
	else:
		if _spin.length() > 0.001:
			basis = Basis(_spin.normalized(), _spin.length() * delta) * basis
	npc.global_basis = basis.orthonormalized()
	npc.move_and_slide()

## Steadied, it puffs toward the nearest surface it can see.
func _puff_home(npc: Npc) -> void:
	if puffs_left <= 0 or _since - _last_puff < PUFF_EVERY:
		return
	var toward: Variant = nearest_surface(npc)
	if toward == null:
		return
	var dir := ((toward as Vector3) - npc.global_position).normalized()
	if npc.velocity.dot(dir) > PUFF:
		return
	npc.velocity += dir * PUFF
	puffs_left -= 1
	_last_puff = _since
	if npc.look != null and npc.look.has_method(&"act"):
		npc.look.call(&"act", &"puff")

## The nearest surface point it can see, or null.
static func nearest_surface(npc: Npc) -> Variant:
	var space := npc.get_world_3d().direct_space_state
	var o := npc.global_position
	var dirs: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var centre := npc.site.frame().origin - o
	if centre.length() > 0.01:
		dirs.append(centre.normalized())
	var best: Variant = null
	var best_d := INF
	for d in dirs:
		var q := PhysicsRayQueryParameters3D.create(o, o + d * LOOK, AsteroidBody.LAYER, [npc.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var dist := o.distance_to(hit["position"])
			if dist < best_d:
				best = hit["position"]
				best_d = dist
	return best

func handover(npc: Npc) -> StringName:
	if _since < 0.1:
		return &""
	for i in npc.get_slide_collision_count():
		if npc.get_slide_collision(i).get_collider() is AsteroidDetail \
				or npc.get_slide_collision(i).get_collider() is AsteroidBody \
				or npc.get_slide_collision(i).get_collider() is StaticBody3D:
			return _land()
	var o := npc.global_position + npc.global_basis.y * npc.species.height * 0.5
	var q := PhysicsRayQueryParameters3D.create(o, o - npc.global_basis.y * (npc.species.height * 0.5 + LANDED),
		AsteroidBody.LAYER, [npc.get_rid()])
	if not npc.get_world_3d().direct_space_state.intersect_ray(q).is_empty() and (_leaping or _since >= TUMBLE):
		return _land()
	return &""

func _land() -> StringName:
	_leaping = false
	return &"surface_crawler"

func grounded() -> bool:
	return false
