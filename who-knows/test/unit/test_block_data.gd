extends GutTest

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func test_all_sixteen_blocks_load():
	assert_eq(_cat.ids().size(), 16, "art direction spec §7 adds canopy: 16 blocks")

func test_required_ids_exist():
	for id in [&"hull", &"hull_wedge", &"armour", &"core", &"reactor",
			&"thruster", &"rcs", &"battery", &"grav_plating", &"deck",
			&"bulkhead", &"door", &"pilot_seat", &"ladder", &"airlock", &"canopy"]:
		assert_true(_cat.has(id), "missing block definition: %s" % id)

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
	var expected := [&"airlock", &"deck", &"door", &"ladder", &"pilot_seat"]
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
