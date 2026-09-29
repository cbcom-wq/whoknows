extends GutTest

## Which cell a hit lands on (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §5.1).

func _grid(cells: Dictionary) -> ShipGrid:
	var grid := ShipGrid.new()
	for at: Vector3i in cells:
		var inst := BlockInstance.new()
		inst.block_id = cells[at]
		grid.set_block(at, inst)
	return grid

func test_a_wall_hit_damages_the_block_behind_it_in_every_direction():
	for dir: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var grid := _grid({Vector3i.ZERO: &"deck", dir: &"hull"})
		# The wall's face, 0.05 m (half its thickness) inside the walkable cell.
		var p := InteriorBuilder.interior_center(Vector3i.ZERO) + Vector3(dir) * (ShipGrid.CELL_SIZE * 0.5 - 0.05)
		assert_eq(ShipCells.interior_cell(grid, p, -Vector3(dir)), dir, "wall toward %s" % dir)

func test_dressing_on_a_wall_still_finds_the_wall_behind():
	var grid := _grid({Vector3i.ZERO: &"deck", Vector3i(1, 0, 0): &"hull"})
	var p := InteriorBuilder.interior_center(Vector3i.ZERO) + Vector3(0.75, 0.3, 0.2)
	assert_eq(ShipCells.interior_cell(grid, p, Vector3(-1, 0, 0)), Vector3i(1, 0, 0))

func test_a_floor_hit_damages_the_block_under_it_or_the_deck():
	var p := Vector3(0.3, InteriorBuilder.floor_y(Vector3i.ZERO), -0.4)
	var under := _grid({Vector3i.ZERO: &"deck", Vector3i(0, -1, 0): &"hull"})
	assert_eq(ShipCells.interior_cell(under, p, Vector3.UP), Vector3i(0, -1, 0))
	var bare := _grid({Vector3i.ZERO: &"deck"})
	assert_eq(ShipCells.interior_cell(bare, p, Vector3.UP), Vector3i.ZERO)

func test_upper_storey_cells():
	var grid := _grid({Vector3i(0, 1, 0): &"deck", Vector3i(1, 1, 0): &"hull"})
	var p := InteriorBuilder.interior_center(Vector3i(0, 1, 0)) + Vector3(0.95, 0.0, 0.0)
	assert_eq(ShipCells.interior_cell(grid, p, Vector3(-1, 0, 0)), Vector3i(1, 1, 0))

func test_nothing_there_is_none():
	var grid := _grid({})
	assert_eq(ShipCells.interior_cell(grid, Vector3.ZERO, Vector3.UP), ShipCells.NONE)
	assert_eq(ShipCells.hull_cell(grid, null, -1, Vector3.ZERO, Vector3.UP), ShipCells.NONE)

func test_a_hull_hit_without_a_shape_uses_the_point():
	var grid := _grid({Vector3i(1, 0, 0): &"hull", Vector3i(2, 0, 0): &"hull"})
	var face := ShipGrid.cell_center(Vector3i(2, 0, 0)) + Vector3(1, 0.3, -0.6)
	assert_eq(ShipCells.hull_cell(grid, null, -1, face, Vector3(1, 0, 0)), Vector3i(2, 0, 0))

func test_a_hull_hit_on_a_tagged_shape_uses_its_cell():
	var grid := _grid({Vector3i(1, 0, 0): &"hull", Vector3i(2, 0, 0): &"hull"})
	var body: StaticBody3D = autofree(StaticBody3D.new())
	for x in [1, 2]:
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.set_meta(&"cell", Vector3i(x, 0, 0))
		body.add_child(shape)
	# Shape 0 is cell (1, 0, 0), whatever the point says.
	assert_eq(ShipCells.hull_cell(grid, body, 0, Vector3(99, 0, 0), Vector3.UP), Vector3i(1, 0, 0))
	assert_eq(ShipCells.hull_cell(grid, body, 1, Vector3(99, 0, 0), Vector3.UP), Vector3i(2, 0, 0))
