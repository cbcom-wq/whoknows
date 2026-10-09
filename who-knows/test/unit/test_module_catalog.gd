extends GutTest

## Modules as block prefabs (habitat modules spec §6, §9.1).

var _blocks: BlockCatalog

func before_all():
	_blocks = BlockCatalog.load_from_dir("res://data/blocks")

func _grid(def: ModuleDefinition, turns := 0) -> ShipGrid:
	var g := ShipGrid.new()
	for b: Array in def.turned(turns):
		var inst := BlockInstance.new()
		inst.block_id = b[1]
		inst.orientation = b[2]
		g.set_block(b[0], inst)
	return g

func test_every_module_s_blocks_lie_in_its_footprint_however_turned():
	for kind in ModuleCatalog.kinds():
		var def := ModuleCatalog.get_def(kind)
		for turns in 4:
			var size := def.turned_size(turns)
			var seen := {}
			for b: Array in def.turned(turns):
				var c: Vector3i = b[0]
				assert_true(c.x >= 0 and c.x < size.x and c.y >= 0 and c.y < size.y and c.z >= 0 and c.z < size.z,
					"%s turned %d: %s inside %s" % [kind, turns, c, size])
				assert_false(seen.has(c), "no two blocks in one cell")
				seen[c] = true
			assert_eq(seen.size(), def.blocks.size())

func test_every_block_id_exists():
	for kind in ModuleCatalog.kinds():
		for b: Array in ModuleCatalog.get_def(kind).blocks:
			assert_not_null(_blocks.get_def(b[1]), "%s: %s" % [kind, b[1]])

func test_four_turns_are_none():
	for o in 24:
		assert_eq(ModuleDefinition.turn_orientation(o, 4), o)
	var def := ModuleCatalog.get_def(ModuleCatalog.HUB)
	assert_eq(def.turned(4), def.turned(0))

func test_a_turn_is_a_quarter_turn_about_up():
	# The block's facing turns with its cell: +90 deg about +y maps -z to -x.
	var o := ModuleDefinition.turn_orientation(0, 1)
	var facing := -(BlockOrientation.basis_for(o).z)
	assert_almost_eq(facing, Vector3(-1, 0, 0), Vector3.ONE * 0.001)

func test_the_hub_has_one_airlock_that_cycles_however_turned():
	var def := ModuleCatalog.get_def(ModuleCatalog.HUB)
	for turns in 4:
		var g := _grid(def, turns)
		var locks := 0
		for c in g.coords():
			if g.get_block(c).block_id == AirlockSite.AIRLOCK_ID:
				locks += 1
				assert_ne(AirlockSite.hatch_normal(g, c), Vector3i.ZERO, "turned %d" % turns)
		assert_eq(locks, 1)

func test_capacities():
	assert_eq(ShipStats.compute(_grid(ModuleCatalog.get_def(ModuleCatalog.HUB)), _blocks).quantum_capacity,
		HabitatValues.HUB_STORE)
	assert_eq(ShipStats.compute(_grid(ModuleCatalog.get_def(ModuleCatalog.STORE)), _blocks).quantum_capacity,
		HabitatValues.STORE_ADDS)
	assert_eq(_blocks.get_def(&"quantum_tank").quantum_capacity, 1000, "read back from the .tres")

func test_every_module_has_gravity_over_its_floor():
	for kind in ModuleCatalog.kinds():
		var g := _grid(ModuleCatalog.get_def(kind))
		var b := InteriorBuilder.new()
		add_child_autofree(b)
		b.bind(g, _blocks)
		b.rebuild()
		for c in b.walkable_coords():
			assert_gt(b.gravity_at(c), 0.0, "%s %s" % [kind, c])
