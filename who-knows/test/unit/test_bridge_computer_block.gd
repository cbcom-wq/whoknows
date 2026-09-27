extends GutTest

## The bridge computer's block (bridge computer spec §3.1), read back from the
## .tres at runtime: a comment in a hand-authored resource can silently drop a
## property (CLAUDE.md), so a clean load proves nothing.

func test_the_computer_is_a_light_interior_fixture():
	var d: BlockDefinition = load("res://data/blocks/computer.tres")
	assert_not_null(d, "computer.tres loads")
	assert_eq(d.id, InteriorLayout.COMPUTER_ID)
	assert_eq(d.display_name, "Bridge Computer")
	assert_eq(d.category, 2, "Interior")
	assert_eq(d.occupancy, BlockDefinition.Occupancy.MOUNT)
	assert_almost_eq(d.mass_t, 0.3, 0.0001)
	assert_eq(d.hp, 60)
	assert_almost_eq(d.power_gen, 0.0, 0.0001)
	assert_almost_eq(d.power_draw, 0.3, 0.0001)
	assert_eq(d.quantum_capacity, 0)
	assert_not_null(d.mesh, "the hull and the miniature draw its box")

func test_the_catalogue_knows_it():
	var cat := BlockCatalog.load_from_dir("res://data/blocks")
	assert_not_null(cat.get_def(InteriorLayout.COMPUTER_ID))

## Spec §3.1: a quiet fixture, so the bridge's floors, consoles and portholes
## stay as they are round it.
func test_it_is_a_quiet_fixture():
	assert_true(InteriorLayout.QUIET_FIXTURES.has(InteriorLayout.COMPUTER_ID))

## Spec §3.1: not required. A ship without a computer still validates.
func test_a_ship_without_a_computer_still_validates():
	var cat := BlockCatalog.load_from_dir("res://data/blocks")
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	var grid: ShipGrid = bootstrap._starter_grid()
	bootstrap.free()
	var deck := BlockInstance.new()
	deck.block_id = &"deck"
	grid.set_block(Vector3i(-1, 0, -1), deck)
	assert_eq(ShipValidator.validate(grid, cat).size(), 0)
