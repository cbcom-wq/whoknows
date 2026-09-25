extends GutTest

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func test_all_twenty_two_blocks_load():
	assert_eq(_cat.ids().size(), 22,
		"21 minus retired reactor and battery, plus the three quantum blocks")

func test_required_ids_exist():
	for id in [&"hull", &"hull_wedge", &"armour", &"core",
			&"thruster", &"rcs", &"grav_plating", &"deck",
			&"bulkhead", &"door", &"pilot_seat", &"ladder", &"airlock", &"canopy",
			&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room",
			&"quantum_core", &"quantum_machine", &"quantum_cell"]:
		assert_true(_cat.has(id), "missing block definition: %s" % id)

func test_reactor_and_battery_are_retired():
	assert_false(_cat.has(&"reactor"),
		"the quantum core generates the ship's power now (spec §5.1)")
	assert_false(_cat.has(&"battery"),
		"quantum cells store QE now; battery had no function (spec §5.1)")

func test_every_block_has_positive_mass_and_hp():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		assert_true(def.mass_t > 0.0, "%s has non-positive mass" % id)
		assert_true(def.hp > 0, "%s has non-positive hp" % id)

func test_every_block_has_a_mesh_and_display_name():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		assert_not_null(def.mesh, "%s has no mesh" % id)
		assert_ne(def.display_name, "", "%s has no display name" % id)

func test_only_thrusters_produce_thrust():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		if id in [&"thruster", &"rcs"]:
			assert_true(def.thrust_kn > 0.0, "%s should produce thrust" % id)
		else:
			assert_almost_eq(def.thrust_kn, 0.0, 0.001, "%s should not thrust" % id)

func test_only_grav_plating_confers_gravity():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		if id == &"grav_plating":
			assert_true(def.grav_radius > 0.0)
		else:
			assert_almost_eq(def.grav_radius, 0.0, 0.001, "%s should not plate" % id)

func test_walkable_blocks_are_exactly_the_interior_traversables():
	var walkable: Array = []
	for id in _cat.ids():
		if _cat.get_def(id).is_walkable():
			walkable.append(id)
	walkable.sort()
	var expected := [&"airlock", &"deck", &"door", &"ladder", &"pilot_seat",
		&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room",
		&"quantum_core", &"quantum_machine"]
	expected.sort()
	assert_eq(walkable, expected)

func test_canopy_is_a_solid_structure_block_with_no_systems():
	var def := _cat.get_def(&"canopy")
	assert_eq(def.category, BlockDefinition.Category.STRUCTURE)
	assert_eq(def.occupancy, BlockDefinition.Occupancy.SOLID)
	assert_almost_eq(def.mass_t, 0.5, 0.001)
	assert_eq(def.hp, 60)
	assert_almost_eq(def.power_gen, 0.0, 0.001)
	assert_almost_eq(def.power_draw, 0.0, 0.001)

## The blocks spec §5.1 adds: the engine at the bridge's centre, the machine
## against its back wall, and the cell that replaces the reactor's storage.
func test_quantum_core_fields():
	var def := _cat.get_def(&"quantum_core")
	assert_eq(def.category, BlockDefinition.Category.INTERIOR)
	assert_eq(def.occupancy, BlockDefinition.Occupancy.MOUNT)
	assert_almost_eq(def.mass_t, 5.0, 0.001)
	assert_eq(def.hp, 250)
	assert_almost_eq(def.power_gen, 36.0, 0.001)
	assert_almost_eq(def.power_draw, 0.0, 0.001)
	assert_eq(def.quantum_capacity, 0)

func test_quantum_machine_fields():
	var def := _cat.get_def(&"quantum_machine")
	assert_eq(def.category, BlockDefinition.Category.INTERIOR)
	assert_eq(def.occupancy, BlockDefinition.Occupancy.MOUNT)
	assert_almost_eq(def.mass_t, 0.5, 0.001)
	assert_eq(def.hp, 100)
	assert_almost_eq(def.power_draw, 0.5, 0.001)
	assert_almost_eq(def.power_gen, 0.0, 0.001)
	assert_eq(def.quantum_capacity, 0)

func test_quantum_cell_fields():
	var def := _cat.get_def(&"quantum_cell")
	assert_eq(def.category, BlockDefinition.Category.SYSTEMS)
	assert_eq(def.occupancy, BlockDefinition.Occupancy.SOLID)
	assert_almost_eq(def.mass_t, 5.0, 0.001)
	assert_eq(def.hp, 250)
	assert_almost_eq(def.power_gen, 0.0, 0.001)
	assert_almost_eq(def.power_draw, 0.0, 0.001)
	assert_eq(def.quantum_capacity, 400)

func test_only_the_quantum_cell_stores_qe():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		if id == &"quantum_cell":
			assert_eq(def.quantum_capacity, 400)
		else:
			assert_eq(def.quantum_capacity, 0, "%s should not store QE" % id)

## Rooms are walkable floor that says what the room is for. They weigh and
## draw exactly what deck does, so turning deck cells into rooms can never
## move a ship's centre of mass or power budget (interior redesign spec §7.1).
func test_room_blocks_are_deck_with_a_purpose():
	var deck := _cat.get_def(&"deck")
	for id in [&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room"]:
		var def := _cat.get_def(id)
		assert_eq(def.occupancy, BlockDefinition.Occupancy.DECK, "%s is walkable floor" % id)
		assert_eq(def.category, BlockDefinition.Category.INTERIOR)
		assert_eq(def.mass_t, deck.mass_t, "%s weighs what deck weighs" % id)
		assert_eq(def.power_draw, deck.power_draw, "%s draws what deck draws" % id)
