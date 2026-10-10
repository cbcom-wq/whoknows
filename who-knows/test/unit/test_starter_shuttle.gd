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
## helm, but InteriorLayout.QUIET_FIXTURES keeps them from reshaping the
## bridge -- a zone is a floor colour, and neither fixture repaints its own
## cell's floor or any neighbour's, or turns a neighbour into a console.
## Pins "today's bridge" by comparing against a copy with both swapped for
## plain deck, cell by cell and face by face, rather than hand-copying a
## table -- the only things that differ are the machine's own wall to the
## galley, which its (unfiltered) MOUNT rule always keeps plain, same as the
## helm's own walls (spec §6.1, "a fixture's own cell keeps plain walls"), and
## the bridge computer's port wall in the front corner, whose console it hands
## to the port wall of the back corner (bridge computer spec §3.2, as amended
## 2026-09-27).
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
		elif f["coord"] == Vector3i(-1, 0, -3) and f["normal"] == Vector3i(-1, 0, 0):
			assert_eq(was["variant"], InteriorLayout.WallVariant.CONSOLE, "a console by the helm")
			assert_eq(f["variant"], InteriorLayout.WallVariant.PORTHOLE, "the computer's own skin wall")
		elif f["coord"] == Vector3i(-1, 0, -1) and f["normal"] == Vector3i(-1, 0, 0):
			assert_eq(f["variant"], InteriorLayout.WallVariant.CONSOLE, "the console, handed to the back corner")
		else:
			assert_eq(f["variant"], was["variant"], "variant at %s unchanged" % key)
	assert_eq(checked, today.faces().size(), "no face went missing")

func test_the_starter_shuttle_still_launches():
	var issues := ShipValidator.validate(_grid, _cat)
	assert_eq(issues.size(), 0, "zero validation issues")
	assert_true(ShipValidator.can_launch(issues))

## The starter's figures with the quantum core, the machine and the bridge
## computer aboard, and the reactors replaced by quantum cells (quantum energy
## spec §5.4; bridge computer spec §3.2). Pinned from ShipStats itself --
## Godot is the truth -- rather than hand-derived. The computer's table
## replaced a deck cell, which weighed 0.4 t and drew 0.1 MW: net, 100 kg
## lighter and 0.2 MW more drawn. The 26 fairings of the reshape (ship exterior
## spec §8) then added 7.8 t of unpowered mass above and below the cabin: the
## centre of mass rose 9 cm, and pitch imbalance went from 0.4% to 4.9% of
## authority, inside the 5% rule.
func test_the_starter_shuttle_is_pinned_with_the_quantum_core_machine_and_computer():
	assert_eq(_grid.coords().size(), 110, "110 blocks")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.total_mass_kg, 104_700.0, 1.0)
	assert_almost_eq(s.center_of_mass, Vector3(0.004, 1.301, 0.160), Vector3.ONE * 0.001)
	assert_almost_eq(s.torque_imbalance, Vector3(151289, -5731, 0), Vector3.ONE * 1.0)
	assert_almost_eq(s.torque_budget, Vector3(3_080_229, 2_040_115, 2_174_785), Vector3.ONE * 1.0)
	assert_almost_eq(s.power_gen, 36.0, 0.05)
	assert_almost_eq(s.power_draw, 31.3, 0.05)
	assert_eq(s.quantum_capacity, 1200)
	var issues := ShipValidator.validate(_grid, _cat)
	assert_eq(issues.size(), 0, "zero issues")

## Bridge computer spec §3.2, as amended 2026-09-27: the table in the
## bridge's port front corner, beside the helm, facing aft toward where you
## stand to use it, so you look forward over it out of the window.
func test_the_computer_stands_in_the_port_front_corner():
	var inst := _grid.get_block(Vector3i(-1, 0, -3))
	assert_not_null(inst)
	assert_eq(inst.block_id, InteriorLayout.COMPUTER_ID)
	assert_eq(InteriorLayout.facing(inst.orientation), Vector3i(0, 0, 1))
	assert_eq(_grid.get_block(Vector3i(-1, 0, -2)).block_id, &"deck", "where you stand to use it")
	assert_eq(_grid.get_block(Vector3i(-4 + 3, 0, -4)).block_id, &"canopy", "glass ahead of it")

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

## The crate's place went to a pile of three scrap plates for the repair torch
## (health and damage spec §8.1, the owner's choice on 2026-10-02).
func test_the_closet_has_canisters_and_a_pile_of_scrap_plates():
	var stock := _stock(_built())
	assert_gt(stock.get(&"canister", 0), 0)
	assert_eq(stock.get(&"scrap_plate", 0), 3)
	assert_eq(stock.get(&"crate", 0), 0)

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


const FAIRINGS := [&"fairing_slope", &"fairing_slope_long_low", &"fairing_slope_long_high",
	&"fairing_corner_out", &"fairing_corner_in", &"fairing_half"]

## Ship exterior spec §8: the shape is fairings, all outside the cabin row.
func test_the_shape_is_fairings_outside_the_cabin():
	var n := 0
	var mass := 0.0
	for coord: Vector3i in _grid.coords():
		var id := _grid.get_block(coord).block_id
		if FAIRINGS.has(id):
			n += 1
			mass += _cat.get_def(id).mass_t
			assert_ne(coord.y, 0, "no fairing in the cabin row: %s" % coord)
	assert_eq(n, 26)
	assert_almost_eq(mass, 7.8, 0.0001)

## The building-a-ship reference's test for a new ship (reference.md).
func test_the_reshaped_starter_flies():
	var s := ShipStats.compute(_grid, _cat)
	assert_eq(ShipValidator.validate(_grid, _cat).size(), 0, "zero issues, warnings included")
	assert_gt(s.power_gen, s.power_draw * 1.1, "power with margin")
	assert_gt(s.thrust_budget[&"reverse"], 0.0, "it can brake")
	for axis in 3:
		assert_gt(s.torque_budget[axis], 0.0, "authority both ways on axis %d" % axis)
		assert_lt(absf(s.torque_imbalance[axis]), s.torque_budget[axis] * 0.05, "no fight under burn on axis %d" % axis)

## The reshape must not block any RCS exhaust: today only the down-firing
## pair's faces are open (building-a-ship skill), and they must stay open.
func test_the_reshape_keeps_the_open_rcs_open():
	var open := 0
	for coord: Vector3i in _grid.coords():
		var inst := _grid.get_block(coord)
		if inst.block_id != &"rcs":
			continue
		var out := BlockOrientation.basis_for(inst.orientation) * Vector3.BACK
		if not _grid.has_block(coord + Vector3i(out.round())):
			open += 1
	assert_eq(open, 2)

## The starter is a file now (ship library spec §3.3), and this pins it:
## changing the starter means changing these on purpose, with the reason in
## data/ships/starter.md.
func test_the_starter_file_is_pinned():
	assert_eq(_grid.size(), 110)
	assert_eq(ShipLibrary.rows_text(_grid).sha256_text(), "9305c583800ce1b438f5fffc6b1cb468fa3b18c360298cc15abd0f9f32dfe27f")
