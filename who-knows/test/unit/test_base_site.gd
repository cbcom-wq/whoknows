extends GutTest

## A base as data (habitat modules spec §9.1, §11.1) and its rules.

var _blocks: BlockCatalog

func before_all():
	_blocks = BlockCatalog.load_from_dir("res://data/blocks")

func _site() -> BaseSite:
	var s := BaseSite.new()
	s.id = &"Base1"
	s.system = 7
	s.at = UniversePoint.at(1000, -2000, 3000).plus(Vector3(1.5, 2.5, -0.5))
	s.turn = Basis(Vector3.UP, 0.3)
	s.rock = Vector4i(1, 2, 3, 2004)
	s.site_id = &"rock:1_2_3_2004"
	s.add(ModuleCatalog.HUB, Vector3i.ZERO, 0, PackedFloat32Array([0.7, 0.8, 0.9, 1.0]))
	return s

func test_a_module_lands_at_its_cells_turned():
	var s := _site()
	var i := s.add(ModuleCatalog.DRILL, Vector3i(5, 0, 0), 1, PackedFloat32Array([1, 1, 1, 1]))
	var cells := s.cells_of(i)
	var def := ModuleCatalog.get_def(ModuleCatalog.DRILL)
	assert_eq(cells.size(), def.blocks.size())
	for b: Array in def.turned(1):
		assert_true(cells.has(Vector3i(5, 0, 0) + b[0]))
	var g := s.grid()
	assert_eq(g.size(), ModuleCatalog.get_def(ModuleCatalog.HUB).blocks.size() + def.blocks.size())

func test_removing_a_module_removes_exactly_its_cells():
	var s := _site()
	var before := s.grid().coords().duplicate()
	var i := s.add(ModuleCatalog.STORE, Vector3i(-3, 0, 0), 0, PackedFloat32Array([1, 1, 1, 1]))
	s.remove(i)
	var after := s.grid().coords()
	before.sort()
	after.sort()
	assert_eq(after, before)

func test_the_same_site_gives_the_same_grid():
	var a := _site().grid()
	var b := _site().grid()
	for c in a.coords():
		assert_eq(b.get_block(c).block_id, a.get_block(c).block_id)
		assert_eq(b.get_block(c).orientation, a.get_block(c).orientation)

func test_it_round_trips_through_a_save():
	var s := _site()
	s.add(ModuleCatalog.DRILL, Vector3i(5, 0, 0), 1, PackedFloat32Array([1, 2, 1, 2]))
	s.modules[1]["drill"] = {"richness": 1.8, "veined": true, "ran": 75.0, "credited_at": 900.0}
	s.store = 123
	s.items = [{"kind": "mug"}]
	s.airlocks = {"1,0,1": {"pressure": 1.0, "open": ""}}
	var back := BaseSite.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.id, s.id)
	assert_eq(back.system, 7)
	assert_true(back.at.is_equal_approx(s.at))
	assert_true(back.turn.is_equal_approx(s.turn))
	assert_eq(back.rock, s.rock)
	assert_eq(back.site_id, s.site_id)
	assert_eq(back.modules.size(), 2)
	assert_eq(back.modules[1]["cell"], Vector3i(5, 0, 0))
	assert_eq(back.modules[1]["turns"], 1)
	assert_almost_eq(float(back.modules[1]["drill"]["richness"]), 1.8, 0.001)
	assert_eq(back.modules[0]["legs"].size(), 4)
	assert_eq(back.store, 123)
	assert_eq(back.items.size(), 1)
	assert_eq(back.airlocks.size(), 1)

func test_a_hub_alone_is_valid():
	assert_true(BaseValidator.ok(BaseValidator.validate(_site(), _blocks)))

func test_rules():
	var none := BaseSite.new()
	assert_true(_codes(BaseValidator.validate(none, _blocks)).has(&"HAS_HUB"))
	var s := _site()
	s.add(ModuleCatalog.DRILL, Vector3i(3, 0, 0), 0, PackedFloat32Array([1, 1, 1, 1]))
	assert_true(_codes(BaseValidator.validate(s, _blocks)).has(&"APART"), "a drill face to face with the hub")
	var apart := _site()
	apart.add(ModuleCatalog.DRILL, Vector3i(4, 0, 0), 0, PackedFloat32Array([1, 1, 1, 1]))
	assert_true(BaseValidator.ok(BaseValidator.validate(apart, _blocks)), "one cell apart is fine")

func _codes(issues: Array) -> Array:
	return issues.map(func(i: ShipValidator.Issue) -> StringName: return i.code)
