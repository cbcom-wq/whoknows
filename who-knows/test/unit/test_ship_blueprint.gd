extends GutTest

func _grid_with(cells: Array) -> ShipGrid:
	var g := ShipGrid.new()
	for cell in cells:
		var i := BlockInstance.new()
		i.block_id = cell[1]
		i.orientation = cell[2]
		i.hp_current = cell[3]
		g.set_block(cell[0], i)
	return g

func test_round_trip_preserves_every_cell():
	var original := _grid_with([
		[Vector3i(0, 0, 0), &"core", 0, 100],
		[Vector3i(1, 0, 0), &"deck", 5, 80],
		[Vector3i(0, 1, -3), &"thruster", 17, 42],
	])
	var bp := ShipBlueprint.from_grid(original, "Testbed")
	var restored := bp.to_grid()

	assert_eq(restored.size(), 3)
	for coord in original.coords():
		var a := original.get_block(coord)
		var b := restored.get_block(coord)
		assert_not_null(b, "cell %s missing after round trip" % coord)
		assert_eq(b.block_id, a.block_id)
		assert_eq(b.orientation, a.orientation)
		assert_eq(b.hp_current, a.hp_current)

func test_round_trip_preserves_name_and_version():
	var bp := ShipBlueprint.from_grid(ShipGrid.new(), "Kestrel")
	assert_eq(bp.ship_name, "Kestrel")
	assert_eq(bp.format_version, ShipBlueprint.CURRENT_FORMAT_VERSION)

func test_empty_grid_round_trips_to_empty():
	var bp := ShipBlueprint.from_grid(ShipGrid.new(), "Empty")
	assert_eq(bp.to_grid().size(), 0)

func test_coords_are_sorted_for_deterministic_diffs():
	var g := _grid_with([
		[Vector3i(5, 0, 0), &"hull", 0, 1],
		[Vector3i(0, 0, 0), &"hull", 0, 1],
		[Vector3i(0, 0, 3), &"hull", 0, 1],
	])
	var first := ShipBlueprint.from_grid(g, "A").coords
	var second := ShipBlueprint.from_grid(g, "A").coords
	assert_eq(first, second, "same grid must serialize identically")
	assert_eq(first[0], Vector3i(0, 0, 0), "sorted ascending")

func test_saves_and_loads_from_disk():
	var g := _grid_with([[Vector3i(2, -1, 4), &"reactor", 9, 55]])
	var bp := ShipBlueprint.from_grid(g, "DiskTest")
	var path := "user://test_blueprint.tres"
	assert_eq(ResourceSaver.save(bp, path), OK)

	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShipBlueprint
	assert_not_null(loaded)
	var restored := loaded.to_grid()
	assert_eq(restored.size(), 1)
	assert_eq(restored.get_block(Vector3i(2, -1, 4)).block_id, &"reactor")
	assert_eq(restored.get_block(Vector3i(2, -1, 4)).orientation, 9)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
