extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid

func before_each():
	_cat = BlockCatalog.new()
	_cat.register(_def(&"hull", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(&"deck", BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"seat", BlockDefinition.Occupancy.MOUNT))
	_cat.register(_def(&"ladder", BlockDefinition.Occupancy.MOUNT))
	_grid = ShipGrid.new()

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

func test_solid_cells_are_not_walkable():
	_put(Vector3i.ZERO, &"hull")
	var g := DeckGraph.build(_grid, _cat)
	assert_false(g.is_walkable(Vector3i.ZERO))
	assert_eq(g.component_of(Vector3i.ZERO), -1)

func test_deck_and_mount_cells_are_walkable():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"seat")
	var g := DeckGraph.build(_grid, _cat)
	assert_true(g.is_walkable(Vector3i(0, 0, 0)))
	assert_true(g.is_walkable(Vector3i(1, 0, 0)))

func test_horizontally_adjacent_decks_share_a_component():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(1, 0, 1), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 1)
	assert_eq(g.component_of(Vector3i(0, 0, 0)), g.component_of(Vector3i(1, 0, 1)))

func test_separated_decks_are_different_components():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(5, 0, 0), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 2)
	assert_ne(g.component_of(Vector3i(0, 0, 0)), g.component_of(Vector3i(5, 0, 0)))

func test_vertically_stacked_decks_do_not_connect_without_a_ladder():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 1, 0), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 2, "a stacked deck is a second storey, not a ramp")

func test_ladder_connects_vertically():
	_put(Vector3i(0, 0, 0), &"ladder")
	_put(Vector3i(0, 1, 0), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 1)
	assert_eq(g.component_of(Vector3i(0, 0, 0)), g.component_of(Vector3i(0, 1, 0)))

func test_ladder_above_also_connects():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(0, 1, 0), &"ladder")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 1)

func test_empty_cells_break_connectivity():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(2, 0, 0), &"deck")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.component_count(), 2, "vacuum is not a corridor")

func test_unknown_block_id_is_not_walkable():
	_put(Vector3i.ZERO, &"mystery")
	var g := DeckGraph.build(_grid, _cat)
	assert_false(g.is_walkable(Vector3i.ZERO))

func test_walkable_coords_lists_only_walkable_cells():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	var g := DeckGraph.build(_grid, _cat)
	assert_eq(g.walkable_coords().size(), 1)
	assert_true(g.walkable_coords().has(Vector3i(0, 0, 0)))
