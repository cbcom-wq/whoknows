extends GutTest

## The starter shuttle after the interior redesign (spec §7.5): a bridge,
## a corridor and five rooms -- with exactly the flight balance it had before.

var _cat: BlockCatalog
var _grid: ShipGrid

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	_grid = bootstrap._starter_grid()
	bootstrap.free()

func test_the_cabin_has_all_five_rooms():
	var found := {}
	for coord in _grid.coords():
		found[_grid.get_block(coord).block_id] = true
	for id in InteriorLayout.ROOM_IDS:
		assert_true(found.has(id), "the starter shuttle has a %s" % id)

func test_rooms_do_not_move_the_flight_balance():
	var decked := ShipGrid.new()
	for coord in _grid.coords():
		var inst: BlockInstance = _grid.get_block(coord).duplicate_instance()
		if InteriorLayout.ROOM_IDS.has(inst.block_id):
			inst.block_id = &"deck"
		decked.set_block(coord, inst)
	var rooms := ShipStats.compute(_grid, _cat)
	var plain := ShipStats.compute(decked, _cat)
	assert_almost_eq(rooms.total_mass_kg, plain.total_mass_kg, 0.001)
	assert_almost_eq(rooms.center_of_mass, plain.center_of_mass, Vector3.ONE * 0.0001)
	assert_almost_eq(rooms.torque_imbalance, plain.torque_imbalance, Vector3.ONE * 0.01)
	assert_almost_eq(rooms.power_draw, plain.power_draw, 0.0001)

func test_the_starter_shuttle_still_launches():
	var issues := ShipValidator.validate(_grid, _cat)
	assert_eq(issues.size(), 0, "zero validation issues")
	assert_true(ShipValidator.can_launch(issues))
