extends GutTest

func _make_def(id: StringName, occ: BlockDefinition.Occupancy) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = occ
	d.mass_t = 1.0
	d.hp = 100
	return d

func test_registered_definition_is_retrievable():
	var cat := BlockCatalog.new()
	cat.register(_make_def(&"hull", BlockDefinition.Occupancy.SOLID))
	assert_true(cat.has(&"hull"))
	assert_eq(cat.get_def(&"hull").display_name, "hull")

func test_unknown_id_returns_null():
	var cat := BlockCatalog.new()
	assert_null(cat.get_def(&"nope"))
	assert_false(cat.has(&"nope"))

func test_registering_same_id_twice_overwrites():
	var cat := BlockCatalog.new()
	cat.register(_make_def(&"hull", BlockDefinition.Occupancy.SOLID))
	var second := _make_def(&"hull", BlockDefinition.Occupancy.DECK)
	cat.register(second)
	assert_eq(cat.get_def(&"hull").occupancy, BlockDefinition.Occupancy.DECK)

func test_block_instance_defaults_to_orientation_zero():
	var inst := BlockInstance.new()
	inst.block_id = &"hull"
	assert_eq(inst.orientation, 0)
