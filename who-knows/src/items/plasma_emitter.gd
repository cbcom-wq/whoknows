class_name PlasmaEmitter
extends ItemUse

## The plasma pistol's use (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §9.1). A bolt leaves the muzzle but
## heads for wherever the eye's ray lands, so it hits what the reticle is on
## although the muzzle is off to one side. If something stands between the eye
## and the muzzle -- you are pressed against a wall -- the shot strikes it at
## once.

const COOLDOWN := 0.25
const AIM_RANGE := 100.0
const MAX_BOLTS := 8
## interior_geometry | items.
const RAY_MASK := 2 | 32

var _cooldown := 0.0
var _bolts: Array[PlasmaBolt] = []

func use(item: Item, aim: Transform3D, world: Node3D, holder: CollisionObject3D) -> bool:
	if _cooldown > 0.0 or world == null:
		return false
	_cooldown = COOLDOWN
	var exclude: Array[RID] = [item.get_rid()]
	if holder != null:
		exclude.append(holder.get_rid())
	var space := item.get_world_3d().direct_space_state
	var muzzle := item.global_transform * item.definition.use_point
	var bolt := PlasmaBolt.new()
	bolt.exclude = exclude
	bolt.source = holder
	world.add_child(bolt)
	var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin, muzzle, RAY_MASK, exclude))
	if not blocked.is_empty():
		bolt.launch(aim.origin, muzzle - aim.origin)
		bolt.impact(blocked)
		return true
	var far := aim.origin - aim.basis.z * AIM_RANGE
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin, far, RAY_MASK, exclude))
	var target: Vector3 = hit["position"] if not hit.is_empty() else far
	bolt.launch(muzzle, target - muzzle)
	_track(bolt)
	ImpactFlash.spawn(world, muzzle, bolt.direction, ImpactFlash.Kind.MUZZLE)
	return true

## The bolts this pistol has in flight, oldest first.
func bolts() -> Array[PlasmaBolt]:
	_bolts = _bolts.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())
	return _bolts

func cooldown_left() -> float:
	return _cooldown

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

func _track(bolt: PlasmaBolt) -> void:
	var flying := bolts()
	while flying.size() >= MAX_BOLTS:
		var oldest: PlasmaBolt = flying.pop_front()
		oldest.get_parent().remove_child(oldest)
		oldest.free()
	flying.append(bolt)
