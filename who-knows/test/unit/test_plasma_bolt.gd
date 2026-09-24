extends GutTest

## PlasmaBolt (hands-and-items spec §9.2, §9.3): a swept ray each tick, so it
## can never tunnel; a push and a flash where it lands.

class Target extends StaticBody3D:
	var hits: Array = []
	func receive_hit(hit: Hit) -> void:
		hits.append(hit)

var _world: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)

func _slab(z: float, body: StaticBody3D = null) -> StaticBody3D:
	var slab := body if body != null else StaticBody3D.new()
	slab.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	slab.add_child(shape)
	_world.add_child(slab)
	slab.global_position = Vector3(0, 0, z)
	return slab

func _bolt(from: Vector3, dir := Vector3.FORWARD) -> PlasmaBolt:
	var bolt := PlasmaBolt.new()
	_world.add_child(bolt)
	bolt.launch(from, dir)
	return bolt

func _loose(at: Vector3, mass := 1.0) -> Item:
	var d := ItemDefinition.new()
	d.id = &"mug"
	d.display_name = "Mug"
	d.mass_kg = mass
	d.size = Vector3(0.3, 0.3, 0.3)
	d.look = &"mug"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_loose()
	return item

func test_a_bolt_cannot_tunnel_through_a_thin_wall():
	_slab(-3.0)
	await wait_physics_frames(2)
	for start in [0.0, 0.2, 0.37, 0.55, 0.71]:
		var hits: Array = []
		var bolt := _bolt(Vector3(0, 0, -start))
		bolt.struck.connect(func(point: Vector3, _c: Object) -> void: hits.append(point))
		await wait_physics_frames(10)
		assert_eq(hits.size(), 1, "starting %.2f m in, it struck" % start)
		if hits.size() == 1:
			assert_almost_eq(hits[0].z, -2.95, 0.01, "on the near face")

func test_a_bolt_ignores_its_shooter():
	var shooter := _slab(-1.0)
	_slab(-3.0)
	await wait_physics_frames(2)
	var hits: Array = []
	var bolt := _bolt(Vector3.ZERO)
	bolt.exclude = [shooter.get_rid()]
	bolt.struck.connect(func(point: Vector3, _c: Object) -> void: hits.append(point))
	await wait_physics_frames(10)
	assert_eq(hits.size(), 1)
	assert_almost_eq(hits[0].z, -2.95, 0.01)

func test_a_bolt_pushes_what_it_hits():
	var item := _loose(Vector3(0, 0, -2))
	await wait_physics_frames(2)
	_bolt(Vector3.ZERO)
	await wait_physics_frames(6)
	assert_almost_eq(item.linear_velocity.z, -PlasmaBolt.PUSH / item.mass, 0.5)

func test_a_stowed_item_stays_put():
	var item := _loose(Vector3(0, 0, -2))
	item.set_stowed(null)
	await wait_physics_frames(2)
	_bolt(Vector3.ZERO)
	await wait_physics_frames(6)
	assert_almost_eq(item.global_position, Vector3(0, 0, -2), Vector3.ONE * 0.0001)

func test_receive_hit_is_called_with_the_hit():
	var target := _slab(-2.0, Target.new()) as Target
	await wait_physics_frames(2)
	_bolt(Vector3.ZERO)
	await wait_physics_frames(6)
	assert_eq(target.hits.size(), 1)
	var hit: Hit = target.hits[0]
	assert_almost_eq(hit.position.z, -1.95, 0.01)
	assert_almost_eq(hit.normal, Vector3.BACK, Vector3.ONE * 0.001)
	assert_almost_eq(hit.impulse, Vector3.FORWARD * PlasmaBolt.PUSH, Vector3.ONE * 0.001)

func test_a_bolt_expires():
	var bolt := _bolt(Vector3.ZERO)
	bolt.age = PlasmaBolt.LIFETIME - 0.01
	await wait_physics_frames(3)
	assert_false(is_instance_valid(bolt))

func test_an_impact_leaves_a_flash_that_frees_itself():
	_slab(-2.0)
	await wait_physics_frames(2)
	_bolt(Vector3.ZERO)
	await wait_physics_frames(6)
	var flashes := _world.get_children().filter(func(n): return n is ImpactFlash)
	assert_eq(flashes.size(), 1)
	await wait_seconds(0.3)
	assert_eq(_world.get_children().filter(func(n): return n is ImpactFlash).size(), 0)

func test_bolts_light_warm_on_the_interior_layer():
	var bolt := _bolt(Vector3.ZERO)
	var lights := bolt.find_children("*", "OmniLight3D", true, false)
	assert_eq(lights.size(), 1)
	var light: OmniLight3D = lights[0]
	assert_eq(light.light_color, InteriorPalette.LIGHT_WARM)
	assert_eq(light.light_cull_mask, 2)
	assert_false(light.shadow_enabled)
	for mi in bolt.find_children("*", "MeshInstance3D", true, false):
		assert_eq(mi.layers, 2)
