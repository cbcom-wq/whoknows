extends GutTest

## ModuleDamage (ship weapons spec §6.5): each module of a base is a section of
## its own, its hp its blocks', its stage scorched then charred, mended by share.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func _site() -> BaseSite:
	var s := BaseSite.new()
	s.add(ModuleCatalog.HUB, Vector3i.ZERO, 0, PackedFloat32Array([1, 1, 1, 1]))
	s.add(ModuleCatalog.DRILL, Vector3i(3, 0, 0), 0, PackedFloat32Array([1, 1, 1, 1]))
	return s

func test_a_module_has_its_blocks_hp():
	var s := _site()
	var total := 0.0
	for b: Array in ModuleCatalog.get_def(ModuleCatalog.DRILL).turned(0):
		total += _cat.get_def(b[1]).hp
	assert_almost_eq(ModuleDamage.hp(s, 1, _cat), total, 0.001)

func test_hits_stage_it_and_repair_mends_it():
	var s := _site()
	var hp := ModuleDamage.hp(s, 1, _cat)
	assert_false(ModuleDamage.hit(s, 1, hp * 0.3, _cat), "still intact")
	assert_true(ModuleDamage.hit(s, 1, hp * 0.3, _cat), "damaged now")
	assert_eq(ModuleDamage.stage(s, 1, _cat), BlockDamage.Stage.DAMAGED)
	ModuleDamage.hit(s, 1, hp, _cat)
	assert_eq(ModuleDamage.stage(s, 1, _cat), BlockDamage.Stage.WRECKED)
	assert_eq(ModuleDamage.wrecked(s, ModuleCatalog.DRILL, _cat), [1] as Array[int])
	ModuleDamage.repair(s, 1, 1.0, _cat)
	assert_eq(ModuleDamage.stage(s, 1, _cat), BlockDamage.Stage.INTACT)
	assert_eq(ModuleDamage.stage(s, 0, _cat), BlockDamage.Stage.INTACT, "the hub took nothing")

func test_parts_and_labels():
	var s := _site()
	assert_eq(ModuleDamage.part(1), &"module:1")
	assert_eq(ModuleDamage.index_of(&"module:1"), 1)
	assert_eq(ModuleDamage.index_of(&"port_bow"), -1)
	assert_eq(ModuleDamage.label(s, 1), "DRILL 1")

func test_the_site_saves_it():
	var s := _site()
	ModuleDamage.hit(s, 1, 50.0, _cat)
	var again := BaseSite.from_dict(s.to_dict())
	assert_almost_eq(float(again.modules[1]["damage"]), 50.0, 0.001)
