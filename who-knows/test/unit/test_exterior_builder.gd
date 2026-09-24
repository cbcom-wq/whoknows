extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid
var _body: RigidBody3D
var _builder: ExteriorBuilder

func before_each():
	_cat = BlockCatalog.new()
	for id in [&"hull", &"deck", &"seat", &"airlock"]:
		var d := BlockDefinition.new()
		d.id = id
		d.display_name = String(id)
		d.mass_t = 1.0
		d.occupancy = (
			BlockDefinition.Occupancy.DECK if id == &"deck" or id == &"airlock"
			else BlockDefinition.Occupancy.MOUNT if id == &"seat"
			else BlockDefinition.Occupancy.SOLID
		)
		d.mesh = BoxMesh.new()
		_cat.register(d)

	_grid = ShipGrid.new()
	_body = RigidBody3D.new()
	_builder = ExteriorBuilder.new()
	add_child_autofree(_body)
	_body.add_child(_builder)
	_builder.body_path = _builder.get_path_to(_body)
	_builder.bind(_grid, _cat)

func _put(coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	_grid.set_block(coord, i)

func test_empty_grid_produces_no_colliders():
	_builder.rebuild()
	assert_eq(_builder.collider_coords().size(), 0)

func test_every_occupied_cell_gets_a_collider():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(2, 0, 0), &"seat")
	_builder.rebuild()
	assert_eq(_builder.collider_coords().size(), 3,
		"deck and mount cells are still hull volume from outside")

func test_collider_coords_match_grid_exactly():
	for coord in [Vector3i(0, 0, 0), Vector3i(3, -1, 2), Vector3i(-4, 5, 0)]:
		_put(coord, &"hull")
	_builder.rebuild()
	var built := _builder.collider_coords()
	assert_eq(built.size(), _grid.size())
	for coord in _grid.coords():
		assert_true(built.has(coord), "missing exterior collider at %s" % coord)

func test_rebuild_is_idempotent():
	_put(Vector3i.ZERO, &"hull")
	_builder.rebuild()
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_builder.collider_coords().size(), 1, "rebuild must not accumulate")

## The bookkeeping array above (collider_coords) clears itself unconditionally
## regardless of node-tree timing, so it cannot catch a stale-node leak. This
## asserts on what the body actually carries: a burst of rebuild() calls with
## no yield -- structurally identical to several cell_changed signals firing
## in the same frame from the shipyard editor -- must not leave old
## CollisionShape3D/MultiMeshInstance3D nodes still parented (and, for
## colliders, still physics-registered) alongside the freshly built ones.
func test_rebuild_does_not_leave_stale_nodes_in_the_tree():
	_put(Vector3i.ZERO, &"hull")
	_builder.rebuild()
	_builder.rebuild()
	_builder.rebuild()

	var colliders_under_body := 0
	for child in _body.get_children():
		if child is CollisionShape3D:
			colliders_under_body += 1
	assert_eq(colliders_under_body, 1,
		"stale colliders must be fully detached, not merely queued")

	var meshes_under_builder := 0
	for child in _builder.get_children():
		if child is MultiMeshInstance3D:
			meshes_under_builder += 1
	assert_eq(meshes_under_builder, 1,
		"stale mesh instances must be fully detached, not merely queued")

func test_clearing_a_block_removes_its_collider():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	_builder.rebuild()
	_grid.clear_block(Vector3i(1, 0, 0))
	_builder.rebuild()
	var remaining := _builder.collider_coords()
	assert_eq(remaining.size(), 1)
	assert_true(remaining.has(Vector3i(0, 0, 0)))

## The regression test for the one failure mode that can rot the
## architecture: exterior and grid drifting apart under churn.
func test_parity_survives_random_mutation():
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260821
	for step in 300:
		var coord := Vector3i(
			rng.randi_range(-4, 4), rng.randi_range(-2, 2), rng.randi_range(-6, 6)
		)
		if rng.randf() < 0.65:
			_put(coord, &"hull")
		else:
			_grid.clear_block(coord)
	_builder.rebuild()

	var built := _builder.collider_coords()
	assert_eq(built.size(), _grid.size(), "collider count drifted from grid")
	for coord in _grid.coords():
		assert_true(built.has(coord), "grid cell %s has no collider" % coord)
	for coord in built:
		assert_true(_grid.has_block(coord), "collider %s has no grid cell" % coord)

## The canopy camera looks out from the pilot's eye, which is inside the
## hull. Own-hull meshes therefore need a render layer of their own so that
## camera can exclude them; without it the windshield renders the inside of
## the ship's own blocks.
func test_hull_meshes_are_drawn_on_the_own_hull_layer():
	_put(Vector3i.ZERO, &"hull")
	_builder.rebuild()
	var drawn := 0
	for child in _builder.get_children():
		if child is MultiMeshInstance3D:
			drawn += 1
			assert_eq(child.layers, ExteriorBuilder.OWN_HULL_LAYER)
	assert_eq(drawn, 1, "one MultiMesh for the one block type")

## Airlock spec §7.2: an airlock that can cycle is an open alcove on the hull,
## a copy of the room inside, instead of a solid block.
func _airlock_off_a_deck() -> void:
	_put(Vector3i(0, 0, 0), &"airlock")   # aft (+z) onto open space
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")

func _box_at(cell: Vector3i) -> Array:
	var out := []
	for c in _body.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D and c.position.is_equal_approx(ShipGrid.cell_center(cell)) 				and (c.shape as BoxShape3D).size.is_equal_approx(Vector3.ONE * ShipGrid.CELL_SIZE):
			out.append(c)
	return out

func _shapes() -> int:
	return _body.get_children().filter(func(c): return c is CollisionShape3D).size()

func test_an_airlock_is_an_open_alcove():
	_airlock_off_a_deck()
	_builder.rebuild()
	assert_eq(_box_at(Vector3i.ZERO).size(), 0, "no solid block where the airlock is")
	assert_true(_builder.alcoves().has(Vector3i.ZERO))
	var alcove: AirlockAlcove = _builder.alcoves()[Vector3i.ZERO]
	assert_gt(alcove.colliders.size(), 4, "a floor, a ceiling, walls and the hatch's jambs")
	for c in alcove.colliders:
		assert_eq(c.get_parent(), _body, "on the hull body")
	assert_true(_builder.collider_coords().has(Vector3i.ZERO), "the cell still has collision: parity holds")
	var airlock_drawn := false
	for child in _builder.get_children():
		if child is MultiMeshInstance3D and child.multimesh.mesh == _cat.get_def(&"airlock").mesh:
			airlock_drawn = true
	assert_false(airlock_drawn, "the block's own mesh is not drawn over the alcove")

func test_an_inert_airlock_stays_a_solid_block():
	_put(Vector3i(0, 0, 0), &"airlock")   # open on three sides: inert
	_put(Vector3i(0, 0, -1), &"deck")
	_builder.rebuild()
	assert_eq(_box_at(Vector3i.ZERO).size(), 1)
	assert_true(_builder.alcoves().is_empty())

func test_the_alcove_has_the_outer_hatch_and_the_hull_panel():
	_airlock_off_a_deck()
	_builder.rebuild()
	var alcove: AirlockAlcove = _builder.alcoves()[Vector3i.ZERO]
	assert_true(alcove.outer_hatch is AirlockHatch)
	assert_true(alcove.hull_panel is AirlockPanel)
	assert_eq(alcove.hull_panel.role, &"outer")
	assert_eq(alcove.hull_panel.collision_layer, 16, "exterior_props: what a spacewalker's interactor finds")
	assert_almost_eq(alcove.outer_hatch.position, Vector3(0, -0.95, 1.0), Vector3.ONE * 0.001, "on the hatch face")

func test_the_alcove_draws_on_the_own_hull_layer():
	_airlock_off_a_deck()
	_builder.rebuild()
	var alcove: AirlockAlcove = _builder.alcoves()[Vector3i.ZERO]
	var drawn := alcove.find_children("*", "GeometryInstance3D", true, false)
	assert_gt(drawn.size(), 0)
	for g in drawn:
		assert_eq(g.layers, ExteriorBuilder.OWN_HULL_LAYER, "%s" % g.name)

func test_rebuilds_leave_one_alcove():
	_airlock_off_a_deck()
	_builder.rebuild()
	var once := _shapes()
	var alcove: AirlockAlcove = _builder.alcoves()[Vector3i.ZERO]
	assert_not_null(alcove.inner_hatch, "the inner hatch, shown shut")
	assert_true(alcove.colliders.has(alcove.inner_hatch.collider))
	assert_true(alcove.colliders.has(alcove.outer_hatch.collider))
	_builder.rebuild()
	_builder.rebuild()
	assert_eq(_builder.find_children("*", "Node3D", true, false).filter(func(n): return n is AirlockAlcove).size(), 1)
	assert_eq(_shapes(), once, "stale alcove colliders are freed")
