extends GutTest

## PhaserBolt and BoltPool (ship weapons spec §6): a turret's bolt flies at
## its ship's velocity plus its own, hits what is outside, leaves a trail that
## runs up to its end, and goes back to the pool.

class Target extends StaticBody3D:
	var hits: Array = []
	func receive_hit(hit: Hit) -> void:
		hits.append(hit)

var _world: Node3D
var _pool: BoltPool

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_pool = BoltPool.new()
	_world.add_child(_pool)

func _slab(z: float, body: StaticBody3D = null) -> StaticBody3D:
	var slab := body if body != null else StaticBody3D.new()
	slab.collision_layer = 1
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	slab.add_child(shape)
	_world.add_child(slab)
	slab.global_position = Vector3(0, 0, z)
	return slab

func _fire(from := Vector3.ZERO, dir := Vector3.FORWARD, carrier := Vector3.ZERO, ex: Array[RID] = []) -> PhaserBolt:
	return _pool.fire(WeaponValues.LIGHT, from, dir, carrier, null, ex)

func test_it_flies_at_its_speed_plus_its_carrier():
	var bolt := _fire(Vector3.ZERO, Vector3.FORWARD, Vector3(10, 0, 0))
	await wait_physics_frames(30)
	var t := bolt.age
	assert_almost_eq(bolt.global_position.x, 10.0 * t, 0.2, "carried sideways with its ship")
	var speed: float = WeaponValues.spec(WeaponValues.LIGHT)["speed"]
	assert_almost_eq(bolt.global_position.z, -speed * t, 2.0, "and out at its speed")

func test_a_hit_carries_its_damage_and_kind():
	var target := _slab(-60.0, Target.new()) as Target
	await wait_physics_frames(2)
	_fire()
	await wait_physics_frames(20)
	assert_eq(target.hits.size(), 1)
	var hit: Hit = target.hits[0]
	assert_eq(hit.damage, WeaponValues.spec(WeaponValues.LIGHT)["damage"])
	assert_eq(hit.kind, &"phaser")

func test_it_ignores_what_it_excludes():
	var own := _slab(-20.0)
	var far := _slab(-80.0, Target.new()) as Target
	await wait_physics_frames(2)
	var ex: Array[RID] = [own.get_rid()]
	_fire(Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, ex)
	await wait_physics_frames(20)
	assert_eq(far.hits.size(), 1, "through its own ship to the target beyond")

func test_it_hits_a_spacewalker():
	assert_eq(PhaserBolt.RAY_MASK & 4, 4, "the avatar's layer")

func test_its_trail_grows_then_runs_up_and_it_goes_back_to_the_pool():
	_slab(-300.0)
	await wait_physics_frames(2)
	var bolt := _fire()
	await wait_physics_frames(10)
	var trail := bolt.get_node("Trail") as MeshInstance3D
	assert_gt(trail.scale.z, 1.0, "a streak behind it")
	await wait_physics_frames(40)
	assert_true(bolt.is_spent())
	await wait_seconds(WeaponValues.TRAIL_TIME + 0.2)
	assert_false(bolt.visible, "gone")
	assert_eq(_pool.live, 0)
	_fire()
	assert_eq(_pool.made, 1, "the pool reused it")

func test_every_bolt_is_shifted_by_the_origin():
	var bolt := _fire()
	assert_true(bolt.is_in_group(Universe.EXTERIOR_SPACE))
	bolt.age = bolt.lifetime - 0.01
	await wait_seconds(WeaponValues.TRAIL_TIME + 0.2)
	assert_true(bolt.is_in_group(Universe.EXTERIOR_SPACE), "pooled too: it never leaves the group")

func test_a_heavy_bolt_carries_a_light():
	var heavy := _pool.fire(WeaponValues.HEAVY, Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, null, [] as Array[RID])
	var light := heavy.get_node("Light") as OmniLight3D
	assert_true(light.visible)
	assert_eq(light.light_color, SpacePalette.PHASER)
	var small := _fire()
	assert_false((small.get_node("Light") as OmniLight3D).visible, "light bolts only glow")

func test_a_bolt_whose_ship_was_removed_in_flight_still_lands_its_damage():
	var target := _slab(-60.0, Target.new()) as Target
	await wait_physics_frames(2)
	var ship := Node3D.new()
	_world.add_child(ship)
	var bolt := _pool.fire(WeaponValues.LIGHT, Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, ship, [] as Array[RID])
	ship.free()
	await wait_physics_frames(20)
	assert_true(bolt.is_spent())
	assert_eq(target.hits.size(), 1, "the hit still arrives")
	assert_null((target.hits[0] as Hit).source, "from nobody")
	assert_eq((target.hits[0] as Hit).damage, WeaponValues.spec(WeaponValues.LIGHT)["damage"])
