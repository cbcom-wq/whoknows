extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid
var _builder: InteriorBuilder

func before_each():
	_cat = BlockCatalog.new()
	for id in [&"hull", &"canopy"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.SOLID))
	for id in [&"deck", &"airlock"]:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"seat", BlockDefinition.Occupancy.MOUNT))
	_grid = ShipGrid.new()
	_builder = InteriorBuilder.new()
	add_child_autofree(_builder)
	_builder.bind(_grid, _cat)

func _def(id: StringName, occ: BlockDefinition.Occupancy) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = occ
	return d

func _put(coord: Vector3i, id: StringName, orientation := 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = orientation
	_grid.set_block(coord, i)

func _dressing() -> Node3D:
	return _builder.find_child("Dressing", true, false)

func _lights(role: StringName = &"") -> Array:
	return _builder.find_children("*", "OmniLight3D", true, false).filter(
		func(l): return role == &"" or l.get_meta(&"role", &"") == role)

func _dressing_colliders() -> Array:
	return _builder.find_children("*", "CollisionShape3D", true, false).filter(
		func(c): return c.is_in_group(InteriorKit.GROUP))

func test_rebuilds_leave_exactly_one_dressing():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_builder.find_children("Dressing", "Node3D", true, false).size(), 1)

func test_lights_do_not_accumulate_across_rebuilds():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var once := _lights().size()
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_lights().size(), once)

func test_every_walkable_cell_gets_one_ceiling_light():
	for x in 3:
		_put(Vector3i(x, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"seat")
	_builder.rebuild()
	assert_eq(_lights(&"ceiling").size(), 4)

func test_every_console_brings_a_collider():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")
	_builder.rebuild()
	var consoles := 0
	for f in _builder.layout().faces():
		if f["variant"] == InteriorLayout.WallVariant.CONSOLE:
			consoles += 1
	assert_gt(consoles, 0, "the fixture exercises consoles")
	assert_eq(_dressing_colliders().size(), consoles)

func test_dressing_colliders_sit_on_the_interior_body():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, -1), &"canopy")
	_put(Vector3i(1, 0, 0), &"hull")
	_builder.rebuild()
	for c in _dressing_colliders():
		var body := c.get_parent() as StaticBody3D
		assert_not_null(body, "a shape registers only as the body's direct child")
		assert_eq(body.collision_layer, 2)

func test_meshes_are_merged_by_material():
	for z in 4:
		for x in 3:
			_put(Vector3i(x, 0, z), &"deck")
	_builder.rebuild()
	var batches := _dressing().get_children().filter(
		func(n): return n is MeshInstance3D and String(n.name).begins_with("Dressing"))
	assert_between(batches.size(), 1, InteriorKit.BATCH_NAMES.size(),
		"one merged mesh per material, not one per piece")

func test_dressing_stays_on_the_interior_layer_under_churn():
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923
	var ids := [&"hull", &"deck", &"seat", &"canopy", &"airlock"]
	for step in 300:
		var coord := Vector3i(rng.randi_range(-3, 3), rng.randi_range(-1, 1), rng.randi_range(-5, 5))
		if rng.randf() < 0.7:
			_put(coord, ids[rng.randi_range(0, ids.size() - 1)])
		else:
			_grid.clear_block(coord)
	_builder.rebuild()
	for mesh in _dressing().find_children("*", "MeshInstance3D", true, false):
		assert_eq(mesh.layers, 2)
	for light in _lights():
		assert_eq(light.light_cull_mask, 2)
		assert_false(light.shadow_enabled)

func test_wall_frame_sits_on_the_inner_surface_facing_the_room():
	var f := InteriorDressing.wall_frame(Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	assert_almost_eq(f.origin, Vector3(0.95, -0.95, 0.0), Vector3.ONE * 0.0001)
	assert_almost_eq(f.basis.z, Vector3(-1, 0, 0), Vector3.ONE * 0.0001, "+z points into the room")
	assert_almost_eq(f.basis.y, Vector3.UP, Vector3.ONE * 0.0001)

func _noses() -> Array:
	return _builder.find_children("NoseShell*", "MeshInstance3D", true, false)

func test_a_windshield_gets_one_nose():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, 0), &"deck")
		_put(Vector3i(x, 0, -1), &"canopy")
	_builder.rebuild()
	assert_eq(_noses().size(), 1)

func test_no_windshield_no_nose():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	assert_eq(_noses().size(), 0)

func test_nose_spans_its_windshield_and_sits_beyond_it():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, 0), &"deck")
		_put(Vector3i(x, 0, -1), &"canopy")
	_builder.rebuild()
	var shell: MeshInstance3D = _noses()[0]
	var box := shell.mesh.get_aabb()
	assert_almost_eq(box.size.x, 6.0, 0.01)
	assert_lt(box.end.z, -0.99, "the whole shell is forward of the canopy plane (z = -1)")

func _doors() -> Array:
	return _builder.find_children("*", "Node3D", true, false).filter(func(n): return n is SlidingDoor)

func _register_rooms() -> void:
	for id in InteriorLayout.ROOM_IDS:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))

func test_every_doorway_gets_one_sliding_door():
	_register_rooms()
	for z in [0, 1, 2]:
		_put(Vector3i(0, 0, z), &"deck")
	_put(Vector3i(-1, 0, 0), &"bunk_room")
	_put(Vector3i(-1, 0, 1), &"bunk_room")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(1, 0, 2), &"closet")
	_builder.rebuild()
	assert_eq(_doors().size(), _builder.layout().rooms().size())
	assert_eq(_doors().size(), 3)

func test_room_furniture_is_solid_where_it_should_be():
	_register_rooms()
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(2, 0, 0), &"hull")
	_builder.rebuild()
	assert_gt(_dressing_colliders().size(), 0, "a counter or a fridge you cannot walk through")

func test_rooms_survive_churn():
	_register_rooms()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ids := [&"hull", &"deck", &"seat", &"canopy", &"airlock"] + Array(InteriorLayout.ROOM_IDS)
	for step in 300:
		var coord := Vector3i(rng.randi_range(-3, 3), 0, rng.randi_range(-5, 5))
		if rng.randf() < 0.75:
			_put(coord, ids[rng.randi_range(0, ids.size() - 1)])
		else:
			_grid.clear_block(coord)
	_builder.rebuild()
	var sliding := 0
	for f in _builder.layout().faces():
		if f["kind"] == InteriorLayout.Kind.DOORWAY and f["owner"] and not f["hatch"]:
			sliding += 1
	assert_eq(_doors().size(), sliding, "a sliding door for every doorway but an airlock's, however tangled")

## A helm at (0, 0, 0) facing -z, into a three-wide windshield.
func _helm_behind_a_windshield() -> void:
	_cat.register(_def(InteriorLayout.HELM_ID, BlockDefinition.Occupancy.MOUNT))
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, -1), &"canopy")
	_put(Vector3i(-1, 0, 0), &"deck")
	_put(Vector3i(0, 0, 0), InteriorLayout.HELM_ID)
	_put(Vector3i(1, 0, 0), &"deck")

func _pods() -> Array:
	return _builder.find_children("CockpitPod", "Node3D", true, false)

## Cockpit pod spec §4.
func test_a_helm_behind_a_windshield_gets_a_pod_not_a_nose():
	_helm_behind_a_windshield()
	_builder.rebuild()
	assert_eq(_noses().size(), 0)
	assert_eq(_pods().size(), 1)
	assert_true(_pods()[0].global_transform.is_equal_approx(
		InteriorDressing.pod_frame(Vector3i.ZERO, Vector3i(0, 0, -1))), "the marker is the pod's frame")

func test_shoulders_flank_the_pod_each_with_a_console_desk():
	_helm_behind_a_windshield()
	_builder.rebuild()
	var consoles := _builder.layout().faces().filter(
		func(f): return f["variant"] == InteriorLayout.WallVariant.CONSOLE).size()
	assert_eq(_lights(&"console").size(), consoles + 2)

func test_the_helm_gets_its_chair_and_console():
	_helm_behind_a_windshield()
	_builder.rebuild()
	assert_eq(_lights(&"helm").size(), 1)

func test_pod_frame_sits_on_the_canopy_plane_at_floor_level():
	var f := InteriorDressing.pod_frame(Vector3i.ZERO, Vector3i(0, 0, -1))
	assert_almost_eq(f.origin, Vector3(0, -0.95, -1), Vector3.ONE * 0.0001)
	assert_almost_eq(f.basis * Vector3.FORWARD, Vector3(0, 0, -1), Vector3.ONE * 0.0001, "-z runs out into the pod")
	var g := InteriorDressing.pod_frame(Vector3i.ZERO, Vector3i(1, 0, 0))
	assert_almost_eq(g.origin, Vector3(1, -0.95, 0), Vector3.ONE * 0.0001)
	assert_almost_eq(g.basis * Vector3.FORWARD, Vector3(1, 0, 0), Vector3.ONE * 0.0001)
	assert_almost_eq(g.basis.y, Vector3.UP, Vector3.ONE * 0.0001)

## Cockpit pod spec §5: in a pod, the chair stands POD_SEAT_DEPTH beyond the
## canopy plane, facing out through it.
func test_the_helm_sits_in_its_pod():
	_helm_behind_a_windshield()
	_builder.rebuild()
	var f := InteriorDressing.fixture_frame(_builder.layout(), Vector3i.ZERO)
	assert_almost_eq(f.origin, Vector3(0, -0.95, -1.0 - InteriorProps.POD_SEAT_DEPTH), Vector3.ONE * 0.0001)
	assert_almost_eq(f.basis * Vector3.FORWARD, Vector3(0, 0, -1), Vector3.ONE * 0.0001)

func test_a_fixture_without_a_pod_sits_at_its_cell_floor_centre():
	_cat.register(_def(InteriorLayout.HELM_ID, BlockDefinition.Occupancy.MOUNT))
	_put(Vector3i(2, 0, 3), InteriorLayout.HELM_ID, 12)   # facing +x
	_builder.rebuild()
	var f := InteriorDressing.fixture_frame(_builder.layout(), Vector3i(2, 0, 3))
	assert_almost_eq(f.origin, Vector3(4, -0.95, 6), Vector3.ONE * 0.0001)
	assert_almost_eq(f.basis * Vector3.FORWARD, Vector3(1, 0, 0), Vector3.ONE * 0.0001)
	assert_almost_eq(f.basis.y, Vector3.UP, Vector3.ONE * 0.0001)

func test_the_dressing_draws_the_helm():
	assert_true(InteriorDressing.draws_fixture(InteriorLayout.HELM_ID))
	assert_false(InteriorDressing.draws_fixture(&"seat"))

## Airlock spec §3: the airlock room, its two hatches and its panels.
func _airlock_off_a_corridor() -> void:
	_cat.register(_def(&"airlock", BlockDefinition.Occupancy.DECK))
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"airlock")   # aft face onto open space
	_put(Vector3i(-1, 0, 1), &"hull")
	_put(Vector3i(1, 0, 1), &"hull")

func _rooms() -> Array:
	return _builder.find_children("*", "Node3D", true, false).filter(func(n): return n is AirlockRoom)

func test_an_airlock_gets_its_room_hatches_and_panels():
	_airlock_off_a_corridor()
	_builder.rebuild()
	var rooms := _rooms()
	assert_eq(rooms.size(), 1)
	var room: AirlockRoom = rooms[0]
	assert_eq(room.name, "Airlock_0_0_1")
	assert_eq(room.coord, Vector3i(0, 0, 1))
	assert_true(room.inner_hatch is AirlockHatch)
	assert_true(room.outer_hatch is AirlockHatch)
	assert_true(room.room_panel is AirlockPanel)
	assert_true(room.corridor_panel is AirlockPanel)
	assert_eq(room.nozzles.size(), 2 * InteriorProps.NOZZLES_PER_WALL, "two side walls of nozzles")
	assert_eq(_doors().size(), 0, "a hatch, never a sliding door")

func test_the_hatches_sit_on_their_walls_facing_into_the_room():
	_airlock_off_a_corridor()
	_builder.rebuild()
	var room: AirlockRoom = _rooms()[0]
	var fl := InteriorBuilder.floor_y(Vector3i(0, 0, 1))
	assert_almost_eq(room.outer_hatch.global_position, Vector3(0, fl, 3.0), Vector3.ONE * 0.001, "on the aft face's mid-plane")
	assert_almost_eq(room.outer_hatch.global_basis.z, Vector3(0, 0, -1), Vector3.ONE * 0.001, "+z faces into the room")
	assert_almost_eq(room.inner_hatch.global_position, Vector3(0, fl, 1.0), Vector3.ONE * 0.001)
	assert_almost_eq(room.inner_hatch.global_basis.z, Vector3(0, 0, 1), Vector3.ONE * 0.001)
	assert_true(room.outer_frame.is_equal_approx(room.outer_hatch.transform))

func test_the_airlock_takes_no_cabin_trim_or_ring_light():
	_airlock_off_a_corridor()
	_builder.rebuild()
	assert_eq(_lights(&"airlock").size(), 1, "the airlock's own flush light")
	assert_eq(_lights(&"ceiling").size(), 1, "only the corridor cell has a ring light")
