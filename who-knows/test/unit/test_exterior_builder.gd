extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid
var _body: RigidBody3D
var _builder: ExteriorBuilder

func before_each():
	_cat = BlockCatalog.new()
	for id in [&"hull", &"deck", &"seat"]:
		var d := BlockDefinition.new()
		d.id = id
		d.display_name = String(id)
		d.mass_t = 1.0
		d.occupancy = (
			BlockDefinition.Occupancy.DECK if id == &"deck"
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
