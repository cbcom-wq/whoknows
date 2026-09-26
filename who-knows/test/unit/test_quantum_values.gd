extends GutTest

## QuantumValues (quantum energy spec §4.2, §4.3): make cost, and the list of
## everything the machine can make.

var _cat: ItemCatalog

func before_all():
	_cat = ItemCatalog.load_from_dir()

func test_make_cost_is_twice_the_value():
	assert_eq(QuantumValues.make_cost(_cat.get_def(&"mug")), 6)
	assert_eq(QuantumValues.make_cost(_cat.get_def(&"plasma_pistol")), 240)
	assert_eq(QuantumValues.make_cost(_cat.get_def(&"power_cell")), 300)

func test_makeable_lists_every_item_in_the_catalogue_cheapest_first():
	var list := QuantumValues.makeable(_cat)
	assert_eq(list.size(), _cat.ids().size(), "all 16 starter items have a value")
	assert_eq(list[0].id, &"mug", "the cheapest thing to make")
	assert_eq(list[-1].id, &"power_cell", "the dearest thing to make")
	for i in range(1, list.size()):
		assert_true(
			QuantumValues.make_cost(list[i - 1]) <= QuantumValues.make_cost(list[i]),
			"cheapest first"
		)

func test_makeable_leaves_out_eva_tools():
	var cat := ItemCatalog.new()
	var nozzle := ItemDefinition.new()
	nozzle.id = &"hose_nozzle"
	nozzle.quantum_value = 999
	nozzle.eva_tool = true
	cat.register(nozzle)
	var mug := ItemDefinition.new()
	mug.id = &"mug"
	mug.quantum_value = 3
	cat.register(mug)

	var list := QuantumValues.makeable(cat)

	assert_eq(list.size(), 1)
	assert_eq(list[0].id, &"mug")

func test_makeable_leaves_out_items_with_no_value():
	var cat := ItemCatalog.new()
	var valueless := ItemDefinition.new()
	valueless.id = &"thing"
	cat.register(valueless)

	assert_eq(QuantumValues.makeable(cat).size(), 0, "quantum_value 0 means not makeable")
