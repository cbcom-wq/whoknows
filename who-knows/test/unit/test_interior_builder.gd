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

	var colliders := _builder.find_children("*", "CollisionShape3D", true, false)
	assert_eq(colliders.size(), 6,
		"canopy is real glass, not a hole -- it still needs a collider")

## §7 item 5 / BLOCKER-A from Task 6b: colliders alone are not enough --
## every surface must also carry a visible mesh, and rebuild() must not
## accumulate stale nodes the way Task 13's array-only idempotency check
## originally missed.
func test_rebuild_does_not_leave_stale_nodes_in_the_tree():
	_put(Vector3i.ZERO, &"deck")
	_builder.rebuild()
	_builder.rebuild()
	_builder.rebuild()

	var bodies := _builder.find_children("*", "StaticBody3D", true, false)
	assert_eq(bodies.size(), 1, "stale physics bodies must be fully detached, not merely queued")
	for body in bodies:
		assert_eq(body.collision_layer, 2, "interior_geometry convention: collision_layer = 2")
		assert_eq(body.collision_mask, 0, "interior_geometry convention: collision_mask = 0")

	var colliders := _builder.find_children("*", "CollisionShape3D", true, false)
	assert_eq(colliders.size(), 6,
		"stale colliders must be fully detached, not merely queued (2 floor/ceiling + 4 walls)")

	var meshes := _builder.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 6,
		"stale mesh instances must be fully detached, not merely queued")
	for mesh in meshes:
		assert_eq(mesh.layers, 2, "interior visuals render on layer 2, or the exterior sun washes them out")
