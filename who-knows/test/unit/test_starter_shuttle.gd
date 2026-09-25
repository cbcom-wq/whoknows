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

## Quantum energy spec §6.1: the core and the machine are fixtures like the
## helm, but InteriorLayout.QUIET_FIXTURES keeps them from spreading bridge
## zone, consoles or portholes to their neighbours the way an ordinary MOUNT
## does. Pins "today's bridge" by comparing against a copy with both swapped
## for plain deck, cell by cell and face by face, rather than hand-copying a
## table -- the only two things that differ are on the machine's own cell,
## which (like the helm's) counts as a MOUNT for itself no matter how quiet
## it is (spec §6.1, "a fixture's own cell keeps plain walls"): its zone is
## bridge, not common, and its wall to the galley goes plain.
func test_the_quantum_fixtures_do_not_reshape_the_bridge():
	var quiet := ShipGrid.new()
	for coord in _grid.coords():
		var inst: BlockInstance = _grid.get_block(coord).duplicate_instance()
		if InteriorLayout.QUIET_FIXTURES.has(inst.block_id):
			inst.block_id = &"deck"
		quiet.set_block(coord, inst)
	var today := InteriorLayout.plan(quiet, _cat, DeckGraph.build(quiet, _cat).walkable_coords())
	var now := InteriorLayout.plan(_grid, _cat, DeckGraph.build(_grid, _cat).walkable_coords())
	for coord in today.walkable_coords():
		if coord == Vector3i(1, 0, -1):
			assert_eq(now.zone_at(coord), InteriorLayout.ZONE_BRIDGE,
				"the machine's own cell is bridge, like any fixture's")
			continue
		assert_eq(now.zone_at(coord), today.zone_at(coord), "zone at %s" % coord)
	var today_by_key := {}
	for f in today.faces():
		today_by_key["%s|%s" % [f["coord"], f["normal"]]] = f
	var checked := 0
	for f in now.faces():
		var key := "%s|%s" % [f["coord"], f["normal"]]
		assert_true(today_by_key.has(key), "face %s exists in today's bridge too" % key)
		if not today_by_key.has(key):
			continue
		checked += 1
		var was: Dictionary = today_by_key[key]
		if f["coord"] == Vector3i(1, 0, -1) and f["normal"] == Vector3i(0, 0, 1):
			assert_eq(f["variant"], InteriorLayout.WallVariant.PANEL,
				"the machine's own wall to the galley goes plain")
		else:
			assert_eq(f["variant"], was["variant"], "variant at %s unchanged" % key)
	assert_eq(checked, today.faces().size(), "no face went missing")

func test_the_starter_shuttle_still_launches():
	var issues := ShipValidator.validate(_grid, _cat)
	assert_eq(issues.size(), 0, "zero validation issues")
	assert_true(ShipValidator.can_launch(issues))

## The starter's figures with the quantum core and machine aboard and the
## reactors replaced by quantum cells (quantum energy spec §5.4). Pinned from
## ShipStats itself -- Godot is the truth -- rather than hand-derived.
func test_the_starter_shuttle_is_pinned_with_the_quantum_core_and_machine():
	assert_eq(_grid.coords().size(), 84, "84 blocks")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.total_mass_kg, 97_000.0, 1.0)
	assert_almost_eq(s.center_of_mass, Vector3(0.002, 1.206, 0.118), Vector3.ONE * 0.001)
	assert_almost_eq(s.torque_imbalance, Vector3(9278, -3093, 0), Vector3.ONE * 1.0)
	assert_almost_eq(s.torque_budget, Vector3(3_058_763, 2_029_381, 2_198_454), Vector3.ONE * 1.0)
	assert_almost_eq(s.power_gen, 36.0, 0.05)
	assert_almost_eq(s.power_draw, 31.1, 0.05)
	assert_eq(s.quantum_capacity, 1200)
	var issues := ShipValidator.validate(_grid, _cat)
	assert_eq(issues.size(), 0, "zero issues")

func _built() -> InteriorBuilder:
	var b := InteriorBuilder.new()
	add_child_autofree(b)
	b.bind(_grid, _cat)
	b.rebuild()
	return b

func _stock(b: InteriorBuilder) -> Dictionary:
	var out := {}
	for p in b.stow_points():
		if p.stock != &"":
			out[p.stock] = out.get(p.stock, 0) + 1
	return out

func test_the_weapon_rack_is_stocked_with_two_pistols():
	assert_eq(_stock(_built()).get(&"plasma_pistol", 0), 2)

func test_the_galley_counter_has_two_mugs():
	assert_eq(_stock(_built()).get(&"mug", 0), 2)

func test_the_closet_has_canisters_and_a_crate():
	var stock := _stock(_built())
	assert_gt(stock.get(&"canister", 0), 0)
	assert_eq(stock.get(&"crate", 0), 1)

func test_every_stow_point_takes_what_it_is_stocked_with():
	var items := ItemCatalog.load_from_dir()
	for p in _built().stow_points():
		if p.stock != &"":
			assert_eq(items.get_def(p.stock).stow_class, p.accepts, "%s fits its own point" % p.stock)

func test_the_ship_and_space_set_is_stocked_aboard():
	var stock := _stock(_built())
	for id in [&"toolbox", &"spare_helmet", &"power_cell", &"o2_tank", &"spanner", &"spare_module",
			&"medkit", &"ration_tin", &"rock_sample", &"hand_lamp", &"flare", &"datapad"]:
		assert_gt(stock.get(id, 0), 0, "%s is somewhere aboard" % id)

func test_the_old_stock_is_where_it_was():
	var stock := _stock(_built())
	assert_eq(stock.get(&"plasma_pistol", 0), 2)
	assert_eq(stock.get(&"mug", 0), 2)
	assert_eq(stock.get(&"crate", 0), 1)
