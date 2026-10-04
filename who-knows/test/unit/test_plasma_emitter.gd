extends GutTest

## The plasma pistol (hands-and-items spec §9.1): bolts leave the muzzle for
## wherever the eye is looking, at most four a second and eight in flight.

var _world: Node3D
var _pistol: Item

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_pistol = Item.new()
	_pistol.setup(ItemCatalog.load_from_dir().get_def(&"plasma_pistol"))
	_world.add_child(_pistol)
	_pistol.global_position = Vector3(0.2, -0.2, -0.4)
	_pistol.set_held()

func _slab(z: float) -> void:
	var slab := StaticBody3D.new()
	slab.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	slab.add_child(shape)
	_world.add_child(slab)
	slab.global_position = Vector3(0, 0, z)

func _bolts() -> Array:
	return _world.get_children().filter(func(n): return n is PlasmaBolt and not n.is_queued_for_deletion())

func test_the_pistol_is_a_plasma_emitter():
	assert_true(_pistol.use_node is PlasmaEmitter)

func test_a_bolt_leaves_the_muzzle_for_where_you_look():
	_slab(-10.0)
	await wait_physics_frames(2)
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))
	var bolts := _bolts()
	assert_eq(bolts.size(), 1)
	var bolt: PlasmaBolt = bolts[0]
	var muzzle := _pistol.global_transform * _pistol.definition.use_point
	assert_almost_eq(bolt.global_position, muzzle, Vector3.ONE * 0.0001)
	assert_almost_eq(bolt.direction, (Vector3(0, 0, -9.95) - muzzle).normalized(), Vector3.ONE * 0.001)

func test_firing_is_rate_limited():
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))
	assert_false(_pistol.use(Transform3D.IDENTITY, _world, null), "cooling down")
	await wait_physics_frames(18)
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))

func test_at_most_eight_bolts_fly():
	var emitter: PlasmaEmitter = _pistol.use_node
	for i in 10:
		emitter._cooldown = 0.0
		_pistol.use(Transform3D.IDENTITY, _world, null)
	assert_eq(emitter.bolts().size(), PlasmaEmitter.MAX_BOLTS)
	assert_eq(_bolts().size(), PlasmaEmitter.MAX_BOLTS)

func test_point_blank_strikes_at_once():
	_slab(-0.2)
	await wait_physics_frames(2)
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))
	assert_eq(_bolts().size(), 0, "no bolt left flying")
	var impacts := _world.get_children().filter(
		func(n): return n is ImpactFlash and n.kind == ImpactFlash.Kind.IMPACT)
	assert_eq(impacts.size(), 1)
	assert_almost_eq(impacts[0].global_position.z, -0.14, 0.02)

func test_each_shot_flashes_at_the_muzzle():
	_pistol.use(Transform3D.IDENTITY, _world, null)
	var muzzles := _world.get_children().filter(
		func(n): return n is ImpactFlash and n.kind == ImpactFlash.Kind.MUZZLE)
	assert_eq(muzzles.size(), 1)

## Outside (health and damage spec §8.3): the bolt and its flashes are drawn
## for outside and move with the floating origin.
func test_outside_a_shot_is_drawn_for_outside_and_shifts():
	_pistol.set_space(true)
	assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))
	var bolt: PlasmaBolt = _bolts()[0]
	var muzzle: ImpactFlash = _world.get_children().filter(func(n): return n is ImpactFlash)[0]
	for node: Node3D in [bolt, muzzle]:
		assert_true(node.is_in_group(Universe.EXTERIOR_SPACE), "%s shifts" % node)
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			assert_eq(mesh.layers, Item.SPACE_LAYER, "%s drawn outside" % node)
		for light: OmniLight3D in node.find_children("*", "OmniLight3D", true, false):
			assert_eq(light.light_cull_mask, 1 | ExteriorBuilder.OWN_HULL_LAYER, "%s lights outside" % node)

func test_aboard_a_shot_stays_aboard():
	_pistol.use(Transform3D.IDENTITY, _world, null)
	var bolt: PlasmaBolt = _bolts()[0]
	assert_false(bolt.is_in_group(Universe.EXTERIOR_SPACE))
	for mesh: MeshInstance3D in bolt.find_children("*", "MeshInstance3D", true, false):
		assert_eq(mesh.layers, InteriorKit.LAYER)

func _hull(z: float, layer: int) -> void:
	_slab(z)
	(_world.get_children().back() as StaticBody3D).collision_layer = layer

func test_outside_a_bolt_strikes_the_hull_and_rocks():
	for layer in [1, AsteroidBody.LAYER]:
		var emitter: PlasmaEmitter = _pistol.use_node
		emitter._cooldown = 0.0
		for n in _world.get_children():
			if n is StaticBody3D:
				n.free()
		_hull(-3.0, layer)
		_pistol.set_space(true)
		await wait_physics_frames(2)
		assert_true(_pistol.use(Transform3D.IDENTITY, _world, null))
		var hits := []
		(_bolts().back() as PlasmaBolt).struck.connect(func(_p, c): hits.append(c))
		await wait_physics_frames(10)
		assert_eq(hits.size(), 1, "layer %d stops a bolt" % layer)
