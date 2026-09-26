extends GutTest

## The item catalogue (hands-and-items spec §4.1, §4.2): every kind on disk
## loads and is complete enough to build.

var _cat: ItemCatalog

func before_all():
	_cat = ItemCatalog.load_from_dir()

func test_the_starter_set_is_on_disk():
	for id in [&"plasma_pistol", &"mug", &"canister", &"crate"]:
		assert_true(_cat.has(id), "data/items has %s" % id)

func test_every_definition_is_complete():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		assert_eq(def.id, id)
		assert_ne(def.display_name, "", "%s has a name" % id)
		assert_gt(def.mass_kg, 0.0, "%s has mass" % id)
		assert_true(def.size.x > 0.0 and def.size.y > 0.0 and def.size.z > 0.0, "%s has a size" % id)
		assert_ne(def.stow_class, &"", "%s has a stow class" % id)
		assert_true(ItemLooks.has_look(def.look), "%s has a look ItemLooks can draw" % id)

func test_the_starter_grips_match_the_spec():
	assert_eq(_cat.get_def(&"plasma_pistol").grip, ItemDefinition.Grip.WIELD)
	assert_eq(_cat.get_def(&"mug").grip, ItemDefinition.Grip.WIELD)
	assert_eq(_cat.get_def(&"canister").grip, ItemDefinition.Grip.WIELD, "held like a bottle")
	assert_eq(_cat.get_def(&"crate").grip, ItemDefinition.Grip.CARRY)

func test_a_hand_built_catalog_needs_no_disk():
	var cat := ItemCatalog.new()
	var def := ItemDefinition.new()
	def.id = &"thing"
	cat.register(def)
	assert_true(cat.has(&"thing"))
	assert_eq(cat.get_def(&"thing"), def)
	assert_null(cat.get_def(&"missing"))

func test_the_pistol_fires_plasma():
	var def := _cat.get_def(&"plasma_pistol")
	assert_not_null(def.use, "the use survived the .tres parse")
	var use = autofree(def.use.new())
	assert_true(use is PlasmaEmitter)

## The ship and space set (hands-and-items spec §4.2, as amended 2026-09-24):
## each id, how it is held, and where it can be stowed.
const SHIP_AND_SPACE := {
	&"toolbox": [ItemDefinition.Grip.CARRY, &"crate"],
	&"spare_helmet": [ItemDefinition.Grip.CARRY, &"crate"],
	&"power_cell": [ItemDefinition.Grip.WIELD, &"small"],
	&"o2_tank": [ItemDefinition.Grip.WIELD, &"small"],
	&"spanner": [ItemDefinition.Grip.WIELD, &"tool"],
	&"spare_module": [ItemDefinition.Grip.WIELD, &"tool"],
	&"medkit": [ItemDefinition.Grip.WIELD, &"tool"],
	&"ration_tin": [ItemDefinition.Grip.WIELD, &"small"],
	&"rock_sample": [ItemDefinition.Grip.WIELD, &"small"],
	&"hand_lamp": [ItemDefinition.Grip.WIELD, &"tool"],
	&"flare": [ItemDefinition.Grip.WIELD, &"tool"],
	&"datapad": [ItemDefinition.Grip.WIELD, &"tool"],
}

func test_the_ship_and_space_set_is_on_disk():
	for id in SHIP_AND_SPACE:
		assert_true(_cat.has(id), "data/items has %s" % id)
		if not _cat.has(id):
			continue
		var def := _cat.get_def(id)
		assert_eq(def.grip, SHIP_AND_SPACE[id][0], "%s is held as designed" % id)
		assert_eq(def.stow_class, SHIP_AND_SPACE[id][1], "%s stows where it fits" % id)
		assert_lte(def.mass_kg, Item.LIFT_LIMIT_KG)

func test_the_lamp_flare_and_datapad_do_something():
	var uses := {&"hand_lamp": "HandLamp", &"flare": "Flare", &"datapad": "Datapad"}
	for id in uses:
		var def := _cat.get_def(id)
		assert_not_null(def.use, "%s has a use that survived the .tres parse" % id)
		var use = autofree(def.use.new())
		assert_eq(use.get_script().get_global_name(), StringName(uses[id]))

func test_the_datapad_is_held_tilted_toward_you():
	assert_gt(_cat.get_def(&"datapad").hold_rotation.x, 0.0)

## Quantum values (quantum energy spec §4.2): every starter item is worth
## something, and matches the spec's table exactly.
const QUANTUM_VALUES := {
	&"mug": 3,
	&"ration_tin": 5,
	&"spanner": 8,
	&"rock_sample": 9,
	&"flare": 10,
	&"canister": 14,
	&"o2_tank": 25,
	&"hand_lamp": 25,
	&"crate": 30,
	&"spare_helmet": 35,
	&"toolbox": 40,
	&"medkit": 40,
	&"datapad": 50,
	&"spare_module": 60,
	&"plasma_pistol": 120,
	&"power_cell": 150,
}

func test_every_item_has_a_quantum_value_unless_it_is_an_eva_tool():
	for id in _cat.ids():
		var def := _cat.get_def(id)
		if def.eva_tool:
			continue
		assert_gt(def.quantum_value, 0, "%s has a quantum value" % id)

func test_quantum_values_match_the_spec_table():
	for id in QUANTUM_VALUES:
		assert_true(_cat.has(id), "data/items has %s" % id)
		if not _cat.has(id):
			continue
		assert_eq(
			_cat.get_def(id).quantum_value, QUANTUM_VALUES[id],
			"%s's quantum value matches spec §4.2" % id
		)

## Salvage (quantum energy spec §4.2, §10.5): six new kinds, each with its
## mass, size, value and grip -- all wielded but the plate, which is carried.
const SALVAGE := {
	&"rock_chunk": [4.0, Vector3(0.20, 0.16, 0.18), 10, ItemDefinition.Grip.WIELD, "Rock chunk"],
	&"ice_chunk": [3.0, Vector3(0.20, 0.18, 0.20), 12, ItemDefinition.Grip.WIELD, "Ice chunk"],
	&"scrap_plate": [6.0, Vector3(0.50, 0.04, 0.35), 18, ItemDefinition.Grip.CARRY, "Scrap plate"],
	&"wire_coil": [1.5, Vector3(0.20, 0.08, 0.20), 20, ItemDefinition.Grip.WIELD, "Wire coil"],
	&"broken_module": [2.0, Vector3(0.25, 0.06, 0.18), 45, ItemDefinition.Grip.WIELD, "Broken module"],
	&"quantum_shard": [0.8, Vector3(0.08, 0.20, 0.08), 250, ItemDefinition.Grip.WIELD, "Quantum shard"],
}

func test_the_salvage_set_is_on_disk_as_the_spec_gives_it():
	for id in SALVAGE:
		assert_true(_cat.has(id), "data/items has %s" % id)
		if not _cat.has(id):
			continue
		var def := _cat.get_def(id)
		var want: Array = SALVAGE[id]
		assert_eq(def.id, id)
		assert_eq(def.look, id, "%s draws its own look" % id)
		assert_almost_eq(def.mass_kg, want[0], 0.0001, "%s's mass" % id)
		assert_almost_eq(def.size, want[1], Vector3.ONE * 0.0001, "%s's size" % id)
		assert_eq(def.quantum_value, want[2], "%s's value (spec §4.2)" % id)
		assert_eq(def.grip, want[3], "%s is held as the spec says" % id)
		assert_eq(def.display_name, want[4])
		assert_false(def.eva_tool)
		assert_null(def.use, "salvage does nothing when used")

## Where each salvage kind stows, where the palm closes on it and how it is
## turned in the hand, read back from the .tres files (CLAUDE.md).
const SALVAGE_HANDLING := {
	&"rock_chunk": [&"small", Vector3(0.09, 0, 0), Vector3.ZERO],
	&"ice_chunk": [&"small", Vector3(0.09, 0, 0), Vector3.ZERO],
	&"scrap_plate": [&"crate", Vector3.ZERO, Vector3.ZERO],
	&"wire_coil": [&"small", Vector3(0.063, 0, 0), Vector3.ZERO],
	&"broken_module": [&"tool", Vector3(0.1, 0, 0.03), Vector3(30, 0, 0)],
	&"quantum_shard": [&"small", Vector3(0, -0.04, 0), Vector3.ZERO],
}

func test_the_salvage_set_stows_and_sits_in_the_hand_as_authored():
	for id in SALVAGE_HANDLING:
		if not _cat.has(id):
			fail_test("data/items has %s" % id)
			continue
		var def := _cat.get_def(id)
		var want: Array = SALVAGE_HANDLING[id]
		assert_eq(def.stow_class, want[0], "%s's stow class" % id)
		assert_almost_eq(def.grip_point, want[1], Vector3.ONE * 0.0001, "%s's grip point" % id)
		assert_almost_eq(def.hold_rotation, want[2], Vector3.ONE * 0.0001, "%s's hold rotation" % id)

## The sixteen aboard and the six salvage kinds (ruling R4: the hose nozzle
## makes it 23).
func test_the_catalogue_has_22_kinds():
	assert_eq(_cat.ids().size(), 22)

func test_no_starter_item_is_an_eva_tool():
	for id in _cat.ids():
		assert_false(_cat.get_def(id).eva_tool, "%s is not an EVA tool" % id)
