extends GutTest

var _grid: ShipGrid
var _changes: Array[Vector3i]

func before_each():
	_grid = ShipGrid.new()
	_changes = []
	_grid.cell_changed.connect(func(c: Vector3i): _changes.append(c))

func _inst(id: StringName = &"hull", orientation: int = 0) -> BlockInstance:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = orientation
	return i

func test_new_grid_is_empty():
	assert_eq(_grid.size(), 0)
	assert_false(_grid.has_block(Vector3i.ZERO))
	assert_null(_grid.get_block(Vector3i.ZERO))

func test_set_block_stores_and_emits():
	_grid.set_block(Vector3i(1, 2, 3), _inst(&"reactor"))
	assert_eq(_grid.size(), 1)
	assert_eq(_grid.get_block(Vector3i(1, 2, 3)).block_id, &"reactor")
	assert_eq(_changes, [Vector3i(1, 2, 3)] as Array[Vector3i])

func test_set_block_overwrites_and_emits_again():
	_grid.set_block(Vector3i.ZERO, _inst(&"hull"))
	_grid.set_block(Vector3i.ZERO, _inst(&"armour"))
	assert_eq(_grid.size(), 1)
	assert_eq(_grid.get_block(Vector3i.ZERO).block_id, &"armour")
	assert_eq(_changes.size(), 2)

func test_clear_block_removes_and_emits():
	_grid.set_block(Vector3i.ZERO, _inst())
	_changes.clear()
	_grid.clear_block(Vector3i.ZERO)
	assert_eq(_grid.size(), 0)
	assert_eq(_changes, [Vector3i.ZERO] as Array[Vector3i])

func test_clearing_empty_cell_does_not_emit():
	_grid.clear_block(Vector3i(9, 9, 9))
	assert_eq(_changes.size(), 0, "no change means no signal")

func test_orientation_round_trips():
	_grid.set_block(Vector3i.ZERO, _inst(&"thruster", 17))
	assert_eq(_grid.get_block(Vector3i.ZERO).orientation, 17)

func test_neighbours_returns_six_face_adjacent_coords():
	var n := _grid.neighbours(Vector3i.ZERO)
	assert_eq(n.size(), 6)
	for expected in [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]:
		assert_true(n.has(expected), "missing neighbour %s" % expected)

func test_cell_center_scales_by_cell_size():
	assert_eq(ShipGrid.CELL_SIZE, 2.0)
	assert_almost_eq(
		ShipGrid.cell_center(Vector3i(1, 0, -2)),
		Vector3(2.0, 0.0, -4.0),
		Vector3.ONE * 0.001
	)

func test_coords_returns_every_occupied_cell():
	_grid.set_block(Vector3i(0, 0, 0), _inst())
	_grid.set_block(Vector3i(0, 0, 1), _inst())
	var c := _grid.coords()
	assert_eq(c.size(), 2)
	assert_true(c.has(Vector3i(0, 0, 1)))
