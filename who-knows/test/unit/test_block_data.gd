extends GutTest

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func test_all_twenty_one_blocks_load():
	assert_eq(_cat.ids().size(), 21, "16, plus the five room blocks of the interior redesign")

func test_required_ids_exist():
	for id in [&"hull", &"hull_wedge", &"armour", &"core", &"reactor",
			&"thruster", &"rcs", &"battery", &"grav_plating", &"deck",
			&"bulkhead", &"door", &"pilot_seat", &"ladder", &"airlock", &"canopy",
			&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room"]:
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
	var expected := [&"airlock", &"deck", &"door", &"ladder", &"pilot_seat",
		&"bunk_room", &"galley", &"bathroom", &"closet", &"weapon_room"]
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

## Every thruster on a ship shares one MultiMesh and so one bell material; the
## bell glows per engine only because that material reads each instance's
## throttle (thruster_bell.gdshader). Read back at runtime: a hand-edited
## .tres can load clean and still have lost the line (CLAUDE.md).
func test_the_thruster_bell_glows_by_throttle():
	var mesh := _cat.get_def(&"thruster").mesh
	assert_eq(mesh.get_surface_count(), 2, "pod body, then bell")
	assert_true(mesh.surface_get_material(0) is StandardMaterial3D, "the pod body is plain paint")
	var bell := mesh.surface_get_material(1) as ShaderMaterial
	assert_not_null(bell, "the bell must be the per-instance glow material")
	assert_eq(bell.shader.resource_path, "res://data/materials/thruster_bell.gdshader")
	assert_gt(bell.get_shader_parameter(&"full_energy"), bell.get_shader_parameter(&"idle_energy"),
		"full throttle glows brighter than idle")

## The flame leaves from the bell: a point inside the thruster's own mesh, at
## the aft end. Read back at runtime, like the bell above.
func test_the_main_thruster_has_a_nozzle_in_its_bell():
	var def := _cat.get_def(&"thruster")
	assert_almost_eq(def.nozzle_radius, 0.7, 0.0001)
	assert_almost_eq(def.nozzle_position, Vector3(0, 0, 1.15), Vector3.ONE * 0.0001)
	assert_true(def.mesh.get_aabb().has_point(def.nozzle_position), "inside the bell")
	assert_gt(def.nozzle_position.z, ShipGrid.CELL_SIZE * 0.5, "aft of the block's own cell")

func test_only_blocks_that_thrust_have_nozzles():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		if def.nozzle_radius > 0.0:
			assert_true(def.thrust_kn > 0.0, "%s has a nozzle but no thrust" % id)
	assert_eq(_cat.get_def(&"rcs").nozzle_radius, 0.0, "the RCS box has no bell to fire from")
