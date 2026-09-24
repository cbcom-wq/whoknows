extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid
var _builder: InteriorBuilder

func before_each():
	_cat = BlockCatalog.new()
	_cat.register(_def(&"hull", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(&"deck", BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"seat", BlockDefinition.Occupancy.MOUNT))
	var grav := _def(&"grav", BlockDefinition.Occupancy.SOLID)
	grav.grav_radius = 5.0
	_cat.register(grav)

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

func _put(coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	_grid.set_block(coord, i)

## Structure colliders only: the dressing's props carry their own, and the
## felt-gravity field's boxes are not structure.
func _structure_colliders() -> Array:
	return _builder.find_children("*", "CollisionShape3D", true, false).filter(
		func(c): return not c.is_in_group(InteriorKit.GROUP) and not (c.get_parent() is FeltGravity))

func _structure_meshes() -> Array:
	var body: StaticBody3D = _builder.find_children("*", "StaticBody3D", true, false)[0]
	return body.get_children().filter(func(n): return n is MeshInstance3D)

func test_solid_only_ship_has_no_interior():
	_put(Vector3i.ZERO, &"hull")
	_builder.rebuild()
	assert_eq(_builder.walkable_coords().size(), 0)

func test_deck_and_mount_cells_become_walkable_floor():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"seat")
	_put(Vector3i(2, 0, 0), &"hull")
	_builder.rebuild()
	var walkable := _builder.walkable_coords()
	assert_eq(walkable.size(), 2)
	assert_true(walkable.has(Vector3i(0, 0, 0)))
	assert_true(walkable.has(Vector3i(1, 0, 0)))
	assert_false(walkable.has(Vector3i(2, 0, 0)))

func test_wall_is_built_where_deck_meets_solid():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_builder.rebuild()
	assert_true(_builder.wall_count() > 0, "a deck beside solid needs a bulkhead")

func test_no_wall_between_two_adjacent_decks():
	_put(Vector3i(0, 0, 0), &"deck")
	_builder.rebuild()
	var single := _builder.wall_count()

	_put(Vector3i(1, 0, 0), &"deck")
	_builder.rebuild()
	var pair := _builder.wall_count()

	assert_eq(single, 4, "an isolated deck cell is walled on all four sides")
	assert_eq(pair, 6, "adjacent decks share one open face, not two walls")

func test_rebuild_is_idempotent():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var once := _builder.wall_count()
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_builder.wall_count(), once, "rebuild must not accumulate walls")

func test_grav_plating_confers_gravity_within_radius():
	_put(Vector3i(0, 0, 0), &"grav")
	_put(Vector3i(1, 0, 0), &"deck")    # 2 m away, inside radius 5
	_builder.rebuild()
	assert_true(_builder.gravity_at(Vector3i(1, 0, 0)) > 0.0)

func test_cells_beyond_grav_radius_are_weightless():
	_put(Vector3i(0, 0, 0), &"grav")
	_put(Vector3i(10, 0, 0), &"deck")   # 20 m away, outside radius 5
	_builder.rebuild()
	assert_almost_eq(_builder.gravity_at(Vector3i(10, 0, 0)), 0.0, 0.001,
		"an unplated compartment is a room you chose not to furnish")

## Parity: the interior's walkable set must equal the grid's walkable set,
## under churn, forever.
func test_parity_survives_random_mutation():
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260822
	var ids := [&"hull", &"deck", &"seat"]
	for step in 300:
		var coord := Vector3i(
			rng.randi_range(-3, 3), rng.randi_range(-1, 1), rng.randi_range(-5, 5)
		)
		if rng.randf() < 0.7:
			_put(coord, ids[rng.randi_range(0, 2)])
		else:
			_grid.clear_block(coord)
	_builder.rebuild()

	# Derive the expectation straight from the grid rather than from
	# DeckGraph, so this test is genuinely independent of the code path
	# the builder uses internally.
	var expected: Array = []
	for coord in _grid.coords():
		var def := _cat.get_def(_grid.get_block(coord).block_id)
		if def != null and def.is_walkable():
			expected.append(coord)

	var built := _builder.walkable_coords()
	assert_eq(built.size(), expected.size(), "interior drifted from grid")
	for coord in expected:
		assert_true(built.has(coord), "walkable cell %s has no interior floor" % coord)
	for coord in built:
		assert_true(expected.has(coord), "interior floor %s is not walkable in grid" % coord)

## Art direction §7 item 4: a walkable cell whose face touches a `canopy`
## cell gets a canopy surface instead of a wall there. Generalises the
## hand-built Window node in flight_test.tscn.
func test_walkable_cell_facing_canopy_gets_canopy_surface_not_wall():
	_cat.register(_def(&"canopy", BlockDefinition.Occupancy.SOLID))
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"canopy")
	_builder.rebuild()
	assert_eq(_builder.wall_count(), 3, "the canopy face replaces a wall, not adds to one")
	assert_eq(_builder.canopy_face_count(), 1)

	var colliders := _structure_colliders()
	assert_eq(colliders.size(), 6,
		"canopy is real glass, not a hole -- it still needs a collider")

## §7 item 5 / BLOCKER-A from Task 6b: colliders alone are not enough --
## every surface must also carry a visible mesh, and rebuild() must not
## accumulate stale nodes the way Task 13's array-only idempotency check
## originally missed.
func test_rebuild_does_not_leave_stale_nodes_in_the_tree():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var meshes_once := _structure_meshes().size()
	_builder.rebuild()
	_builder.rebuild()

	var bodies := _builder.find_children("*", "StaticBody3D", true, false)
	assert_eq(bodies.size(), 1, "stale physics bodies must be fully detached, not merely queued")
	for body in bodies:
		assert_eq(body.collision_layer, 2, "interior_geometry convention: collision_layer = 2")
		assert_eq(body.collision_mask, 0, "interior_geometry convention: collision_mask = 0")

	assert_eq(_structure_colliders().size(), 6,
		"stale colliders must be fully detached, not merely queued (2 floor/ceiling + 4 walls)")

	var meshes := _structure_meshes()
	assert_eq(meshes.size(), meshes_once, "stale mesh instances must be fully detached, not merely queued")
	for mesh in meshes:
		assert_eq(mesh.layers, 2, "interior visuals render on layer 2, or the exterior sun washes them out")

## Art direction §3: a MOUNT block is a fixture that occupies its own cell --
## a seat, a console, a ladder. The interior has to draw it, or the player
## walks up to an invisible collider and has to guess it is there.
func test_mount_block_with_a_mesh_is_drawn_as_a_fixture():
	var seat_def := _cat.get_def(&"seat")
	seat_def.mesh = BoxMesh.new()
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"seat")
	_builder.rebuild()
	assert_eq(_builder.fixture_count(), 1, "the seat is drawn, the deck is not")

func test_fixture_sits_at_its_own_cell_centre():
	var seat_def := _cat.get_def(&"seat")
	seat_def.mesh = BoxMesh.new()
	_put(Vector3i(2, 0, -3), &"seat")
	_builder.rebuild()
	assert_almost_eq(
		_builder.fixture_positions()[0], ShipGrid.cell_center(Vector3i(2, 0, -3)),
		Vector3.ONE * 0.001
	)

func test_mount_block_without_a_mesh_draws_nothing():
	_put(Vector3i(0, 0, 0), &"seat")
	_builder.rebuild()
	assert_eq(_builder.fixture_count(), 0)

func test_fixtures_are_cleared_on_rebuild():
	_cat.get_def(&"seat").mesh = BoxMesh.new()
	_put(Vector3i(0, 0, 0), &"seat")
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_builder.fixture_count(), 1, "rebuilding must not stack fixtures")

## A porthole is glass, not a way out: the picture has a hole, the collider
## does not.
func test_porthole_wall_keeps_a_whole_collider_and_draws_four_boxes():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")   # flank, vacuum beyond: a porthole
	_builder.rebuild()
	var wall_at := InteriorBuilder.interior_center(Vector3i.ZERO) + Vector3(ShipGrid.CELL_SIZE * 0.5, 0, 0)
	var colliders := _structure_colliders().filter(func(c): return c.position.is_equal_approx(wall_at))
	assert_eq(colliders.size(), 1)
	assert_almost_eq((colliders[0].shape as BoxShape3D).size,
		Vector3(InteriorBuilder.FLOOR_THICKNESS, InteriorBuilder.STOREY_HEIGHT, ShipGrid.CELL_SIZE),
		Vector3.ONE * 0.001, "a whole wall, the full storey high")
	var pieces := _structure_meshes().filter(
		func(m): return absf(m.position.x - wall_at.x) < 0.001)
	assert_eq(pieces.size(), 4, "four boxes round a square opening")

func test_floor_takes_its_zone_colour():
	_put(Vector3i(0, 0, 0), &"seat")
	_put(Vector3i(0, 0, 2), &"deck")
	_put(Vector3i(0, 0, 1), &"deck")
	_builder.rebuild()
	var floor_y := -ShipGrid.CELL_SIZE * 0.5
	for m in _structure_meshes():
		if not is_equal_approx(m.position.y, floor_y):
			continue
		var expected := InteriorPalette.FLOOR if is_equal_approx(m.position.z, 4.0) else InteriorPalette.FLOOR_BRIDGE
		assert_eq((m.material_override as StandardMaterial3D).albedo_color, expected)

## The canopy is the dressing's rounded nose now; the builder keeps only the
## collider, so the avatar still stops at the windshield plane.
func test_canopy_face_has_a_collider_and_no_box():
	_cat.register(_def(&"canopy", BlockDefinition.Occupancy.SOLID))
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"canopy")
	_builder.rebuild()
	var plane := InteriorBuilder.interior_center(Vector3i.ZERO) + Vector3(ShipGrid.CELL_SIZE * 0.5, 0, 0)
	assert_eq(_structure_colliders().filter(func(c): return c.position.is_equal_approx(plane)).size(), 1)
	assert_eq(_structure_meshes().filter(func(m): return m.position.is_equal_approx(plane)).size(), 0)

func _register_rooms() -> void:
	for id in InteriorLayout.ROOM_IDS:
		_cat.register(_def(id, BlockDefinition.Occupancy.DECK))

func test_a_partition_is_built_once():
	_register_rooms()
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_put(Vector3i(1, 0, 1), &"galley")
	_builder.rebuild()
	# The doorway takes the forward face (z = 0); the aft one is a plain partition.
	var between := InteriorBuilder.interior_center(Vector3i(0, 0, 1)) + Vector3(ShipGrid.CELL_SIZE * 0.5, 0, 0)
	var here := _structure_colliders().filter(func(c): return c.position.is_equal_approx(between))
	assert_eq(here.size(), 1, "one wall between the corridor and the galley, not two")

## A doorway is two jambs and a lintel round an opening DOOR_WIDTH wide and
## DOOR_HEIGHT high. Nothing solid may stand in that opening.
func test_a_doorway_leaves_a_clear_opening():
	_register_rooms()
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"galley")
	_builder.rebuild()
	assert_eq(_builder.doorway_count(), 1)
	var plane_x := ShipGrid.CELL_SIZE * 0.5
	var at_plane := _structure_colliders().filter(func(c): return is_equal_approx(c.position.x, plane_x))
	assert_eq(at_plane.size(), 3, "two jambs and a lintel")
	var door_top := InteriorBuilder.floor_y(Vector3i.ZERO) + InteriorProps.DOOR_HEIGHT
	for c in at_plane:
		var half: Vector3 = (c.shape as BoxShape3D).size * 0.5
		var beside: bool = absf(c.position.z) - half.z >= InteriorProps.DOOR_WIDTH * 0.5 - 0.001
		var above: bool = c.position.y - half.y >= door_top - 0.001
		assert_true(beside or above, "nothing solid in the opening")
	assert_gte(InteriorProps.DOOR_HEIGHT, 2.0, "the 1.8 m avatar walks through upright")

func test_room_floors_take_the_room_colour():
	_register_rooms()
	_put(Vector3i(0, 0, 0), &"bathroom")
	_builder.rebuild()
	var floor_y := -ShipGrid.CELL_SIZE * 0.5
	var floors := _structure_meshes().filter(func(m): return is_equal_approx(m.position.y, floor_y))
	assert_eq((floors[0].material_override as StandardMaterial3D).albedo_color,
		InteriorPalette.ROOM_FLOOR[&"bathroom"])

## The interior is taller than a grid cell: grid cells stay 2 m, but a storey
## gives 2.5 m of clear headroom so nobody's head is at the lights.
func test_clear_headroom_is_the_storey_less_the_slabs():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var slabs := _structure_colliders().filter(func(c): return (c.shape as BoxShape3D).size.y < 0.5)
	var ys := slabs.map(func(c): return c.position.y)
	ys.sort()
	var headroom: float = (ys[1] - InteriorBuilder.FLOOR_THICKNESS * 0.5) - (ys[0] + InteriorBuilder.FLOOR_THICKNESS * 0.5)
	assert_almost_eq(headroom, InteriorBuilder.STOREY_HEIGHT - InteriorBuilder.FLOOR_THICKNESS, 0.001)
	assert_gte(headroom, 2.4, "room over a 1.6 m eye line")

## The floor stays where the hull puts it: only the ceiling rises. That keeps
## the pilot's eye -- and so the canopy camera -- exactly where it was.
func test_floor_is_anchored_to_the_grid():
	assert_almost_eq(InteriorBuilder.floor_y(Vector3i.ZERO),
		-ShipGrid.CELL_SIZE * 0.5 + InteriorBuilder.FLOOR_THICKNESS * 0.5, 0.0001)
	assert_almost_eq(InteriorBuilder.floor_y(Vector3i(0, 1, 0)) - InteriorBuilder.floor_y(Vector3i.ZERO),
		InteriorBuilder.STOREY_HEIGHT, 0.0001, "storeys stack at storey height")

func test_the_felt_gravity_covers_every_walkable_cell_at_storey_height():
	_put(Vector3i.ZERO, &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	_builder.rebuild()
	var field := _builder.felt_gravity
	assert_not_null(field)
	assert_eq(field.cell_count(), 2)
	var centres := []
	for shape in field.get_children().filter(func(n): return n is CollisionShape3D):
		assert_eq((shape.shape as BoxShape3D).size,
			Vector3(ShipGrid.CELL_SIZE, InteriorBuilder.STOREY_HEIGHT, ShipGrid.CELL_SIZE))
		centres.append(shape.position)
	assert_has(centres, InteriorBuilder.interior_center(Vector3i.ZERO))
	assert_has(centres, InteriorBuilder.interior_center(Vector3i(1, 0, 0)))

func test_the_felt_gravity_survives_rebuilds():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	var field := _builder.felt_gravity
	_builder.rebuild()
	_builder.rebuild()
	assert_same(_builder.felt_gravity, field)
	assert_eq(field.cell_count(), 1)
	assert_eq(_builder.get_children().filter(func(n): return n is FeltGravity).size(), 1)

func test_the_felt_gravity_starts_at_plating_gravity():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	assert_almost_eq(_builder.felt_gravity.felt, Vector3.DOWN * InteriorBuilder.DEFAULT_GRAVITY,
		Vector3.ONE * 0.0001)

## Cockpit pod spec §4: the pod's mouth is open -- the pod prop brings its own
## colliders -- while the canopy faces beside it still stop the avatar.
func test_a_pod_face_has_no_collider():
	_cat.register(_def(&"canopy", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(InteriorLayout.HELM_ID, BlockDefinition.Occupancy.MOUNT))
	for x in [0, 1]:
		_put(Vector3i(x, 0, -1), &"canopy")
	_put(Vector3i(0, 0, 0), InteriorLayout.HELM_ID)   # orientation 0 faces -z, into the glass
	_put(Vector3i(1, 0, 0), &"deck")
	_builder.rebuild()
	var ahead := Vector3(0, 0, -ShipGrid.CELL_SIZE * 0.5)
	var pod := InteriorBuilder.interior_center(Vector3i(0, 0, 0)) + ahead
	var beside := InteriorBuilder.interior_center(Vector3i(1, 0, 0)) + ahead
	assert_eq(_structure_colliders().filter(func(c): return c.position.is_equal_approx(pod)).size(), 0)
	assert_eq(_structure_colliders().filter(func(c): return c.position.is_equal_approx(beside)).size(), 1)

## Cockpit pod spec §5: the helm is the dressing's captain's chair now; any
## other MOUNT block is still drawn from its own mesh.
func test_the_helm_is_not_drawn_from_its_block_mesh():
	var helm := _def(InteriorLayout.HELM_ID, BlockDefinition.Occupancy.MOUNT)
	helm.mesh = BoxMesh.new()
	_cat.register(helm)
	_cat.get_def(&"seat").mesh = BoxMesh.new()
	_put(Vector3i(0, 0, 0), InteriorLayout.HELM_ID)
	_put(Vector3i(1, 0, 0), &"seat")
	_builder.rebuild()
	assert_eq(_builder.fixture_count(), 1, "only the other mount")
	assert_almost_eq(_builder.fixture_positions()[0].x, ShipGrid.cell_center(Vector3i(1, 0, 0)).x, 0.001)

func _airlock_fixture() -> void:
	_cat.register(_def(&"airlock", BlockDefinition.Occupancy.DECK))
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 0, 1), &"airlock")   # aft face onto open space
	_put(Vector3i(-1, 0, 1), &"hull")
	_put(Vector3i(1, 0, 1), &"hull")

func _meshes_at(x: float, z: float) -> Array:
	return _structure_meshes().filter(
		func(m): return absf(m.position.x - x) < 0.001 and absf(m.position.z - z) < 0.001)

## Airlock spec §3.2: the airlock's ceiling is where the hull cell's is, so its
## copy on the hull can match it exactly.
func test_the_airlock_ceiling_is_the_hull_cells():
	_airlock_fixture()
	_builder.rebuild()
	var fl := InteriorBuilder.floor_y(Vector3i(0, 0, 1))
	var slabs := _meshes_at(0.0, 2.0).filter(func(m): return m.position.y > fl)
	assert_eq(slabs.size(), 1, "one ceiling slab over the airlock")
	var underside: float = slabs[0].position.y - (slabs[0].mesh as BoxMesh).size.y * 0.5
	assert_almost_eq(underside, fl + InteriorProps.AIRLOCK_CLEAR, 0.001)
	assert_almost_eq(InteriorBuilder.ceiling_y(Vector3i(0, 0, 1), InteriorLayout.AIRLOCK_ZONE), underside, 0.001)
	var deck_slabs := _meshes_at(0.0, 0.0).filter(func(m): return m.position.y > fl)
	var deck_underside: float = deck_slabs[0].position.y - (deck_slabs[0].mesh as BoxMesh).size.y * 0.5
	assert_almost_eq(deck_underside, fl + InteriorProps.HEADROOM, 0.001, "the corridor keeps its full height")

func test_a_hatch_doorway_is_hatch_high():
	_airlock_fixture()
	_builder.rebuild()
	var fl := InteriorBuilder.floor_y(Vector3i(0, 0, 1))
	var lintels := _meshes_at(0.0, 1.0).filter(
		func(m): return is_equal_approx((m.mesh as BoxMesh).size.x, InteriorProps.DOOR_WIDTH))
	assert_eq(lintels.size(), 1)
	var bottom: float = lintels[0].position.y - (lintels[0].mesh as BoxMesh).size.y * 0.5
	assert_almost_eq(bottom, fl + InteriorProps.HATCH_HEIGHT, 0.001)
	assert_eq(_builder.doorway_count(), 1)

func test_storey_offset_is_zero_on_the_ground_storey():
	assert_eq(InteriorBuilder.storey_offset(0), 0.0)
	assert_almost_eq(InteriorBuilder.storey_offset(2),
		2.0 * (InteriorBuilder.STOREY_HEIGHT - ShipGrid.CELL_SIZE), 0.0001)
