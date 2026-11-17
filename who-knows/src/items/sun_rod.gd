class_name SunRod
extends ItemUse

## The queen's sun-rod (docs/superpowers/specs/2026-11-16-wadoo-design.md §8): a short
## sunstaff for one hand, her gift when you take up the hunt. It throws a bolt of
## sun (SunBolt): slower to fire than the pistol and stronger, from a store of
## CHARGES that fills again in daylight, one each RECHARGE seconds while it is out
## of doors. The rod with the water-stone charm (`sun_rod_charmed`, given for all
## three of Wadoo's tasks) throws brighter bolts. Like the pistol's, a bolt leaves
## the head but flies at whatever the eye's ray meets.

const COOLDOWN := 0.9
## hp a bolt takes (the pistol's is 10, a Sunguard's 12).
const DAMAGE := 25.0
const CHARGES := 6
const RECHARGE := 5.0
const AIM_RANGE := 100.0
const CHARMED_ID := &"sun_rod_charmed"

var charges := CHARGES
var _cooldown := 0.0
var _refill := 0.0

func recoil() -> float:
	return 0.6

func use(item: Item, aim: Transform3D, world: Node3D, holder: CollisionObject3D) -> bool:
	if _cooldown > 0.0 or world == null or charges <= 0:
		return false
	_cooldown = COOLDOWN
	charges -= 1
	var exclude: Array[RID] = [item.get_rid()]
	if holder != null:
		exclude.append(holder.get_rid())
	var space := item.get_world_3d().direct_space_state
	var head := item.global_transform * item.definition.use_point
	var outside := item.in_space
	var mask := PlasmaBolt.mask(outside)
	var bolt := SunBolt.new()
	bolt.exclude = exclude
	bolt.source = holder
	bolt.outside = outside
	bolt.damage = DAMAGE
	bolt.bright = SunBolt.CHARMED if charmed(item) else 1.0
	world.add_child(bolt)
	var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin, head, mask, exclude))
	if not blocked.is_empty():
		bolt.launch(aim.origin, head - aim.origin)
		bolt.impact(blocked)
		return true
	var far := aim.origin - aim.basis.z * AIM_RANGE
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin, far, mask, exclude))
	var target: Vector3 = hit["position"] if not hit.is_empty() else far
	bolt.launch(head, target - head)
	ImpactFlash.spawn(world, head, bolt.direction, ImpactFlash.Kind.MUZZLE, outside, 1.0, bolt.bright)
	return true

## The rod with the water stone: brighter bolts.
static func charmed(item: Item) -> bool:
	return item != null and item.definition != null and item.definition.id == CHARMED_ID

## "4 of 6": the bolts it holds.
func status() -> String:
	return "%d of %d" % [charges, CHARGES]

func cooldown_left() -> float:
	return _cooldown

func save() -> Dictionary:
	return {"charges": charges} if charges < CHARGES else {}

func restore(state: Dictionary) -> void:
	charges = clampi(int(state.get("charges", CHARGES)), 0, CHARGES)

func _physics_process(delta: float) -> void:
	tick(delta, (get_parent() as Item).in_space if get_parent() is Item else false)

## `delta` seconds go by, in daylight (out of doors) or not: the cooldown runs
## out, and in daylight a spent bolt comes back every RECHARGE.
func tick(delta: float, daylight: bool) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if charges >= CHARGES or not daylight:
		_refill = 0.0
		return
	_refill += delta
	while _refill >= RECHARGE and charges < CHARGES:
		_refill -= RECHARGE
		charges += 1
