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
	assert_eq(_cat.get_def(&"canister").grip, ItemDefinition.Grip.CARRY)
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
