extends GutTest

## Blocks take damage (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §4): stages by damage taken,
## removal, what is never removed, and pieces that break off.

var _catalog: BlockCatalog

func before_all():
	_catalog = BlockCatalog.load_from_dir()

func _put(grid: ShipGrid, at: Vector3i, id: StringName, damage := 0.0) -> void:
	var inst := BlockInstance.new()
	inst.block_id = id
	inst.damage = damage
	grid.set_block(at, inst)

## A core with a line of hull running +x from it: core, hull, hull, hull.
func _line() -> ShipGrid:
	var grid := ShipGrid.new()
	_put(grid, Vector3i(0, 0, 0), &"core")
	for x in range(1, 4):
		_put(grid, Vector3i(x, 0, 0), &"hull")
	return grid

func _hp(id: StringName) -> float:
	return float(_catalog.get_def(id).hp)

func test_stage_boundaries():
	var hp := 200.0
	var S := BlockDamage.Stage
	assert_eq(BlockDamage.stage_at(0.0, hp), S.INTACT)
	assert_eq(BlockDamage.stage_at(99.0, hp), S.INTACT)
	assert_eq(BlockDamage.stage_at(100.0, hp), S.DAMAGED)
	assert_eq(BlockDamage.stage_at(199.0, hp), S.DAMAGED)
	assert_eq(BlockDamage.stage_at(200.0, hp), S.WRECKED)
	assert_eq(BlockDamage.stage_at(299.0, hp), S.WRECKED)
	assert_eq(BlockDamage.stage_at(300.0, hp), S.GONE)

func test_output_by_stage():
	var S := BlockDamage.Stage
	assert_eq(BlockDamage.output_of(S.INTACT), 1.0)
	assert_eq(BlockDamage.output_of(S.DAMAGED), 0.5)
	assert_eq(BlockDamage.output_of(S.WRECKED), 0.0)
	assert_eq(BlockDamage.output_of(S.GONE), 0.0)

func test_a_hit_raises_damage_and_removes_nothing():
	var grid := _line()
	var removed := BlockDamage.apply(grid, _catalog, Vector3i(3, 0, 0), 30.0)
	assert_eq(removed, [])
	assert_eq(grid.get_block(Vector3i(3, 0, 0)).damage, 30.0)

func test_block_staged_fires_on_a_stage_change_only():
	var grid := _line()
	watch_signals(grid)
	var at := Vector3i(3, 0, 0)
	BlockDamage.apply(grid, _catalog, at, 10.0)
	assert_signal_not_emitted(grid, "block_staged")
	BlockDamage.apply(grid, _catalog, at, _hp(&"hull") * 0.5)
	assert_signal_emitted_with_parameters(grid, "block_staged", [at, BlockDamage.Stage.DAMAGED])
	BlockDamage.apply(grid, _catalog, at, 1.0)
	assert_signal_emit_count(grid, "block_staged", 1)

func test_a_hit_across_two_stages_fires_once_with_the_new_one():
	var grid := _line()
	watch_signals(grid)
	var at := Vector3i(3, 0, 0)
	BlockDamage.apply(grid, _catalog, at, _hp(&"hull") * 1.2)
	assert_signal_emit_count(grid, "block_staged", 1)
	assert_signal_emitted_with_parameters(grid, "block_staged", [at, BlockDamage.Stage.WRECKED])

func test_gone_removes_the_block_with_one_cell_changed():
	var grid := _line()
	watch_signals(grid)
	var at := Vector3i(3, 0, 0)
	var removed := BlockDamage.apply(grid, _catalog, at, _hp(&"hull") * 2.0)
	assert_eq(removed, [at])
	assert_false(grid.has_block(at))
	assert_signal_emit_count(grid, "cell_changed", 1)
	assert_signal_not_emitted(grid, "block_staged", "gone is a removal, not a stage")

func test_a_removal_that_splits_the_ship_takes_the_cut_off_piece():
	var grid := _line()
	watch_signals(grid)
	var removed := BlockDamage.apply(grid, _catalog, Vector3i(1, 0, 0), _hp(&"hull") * 2.0)
	assert_eq(removed.size(), 3)
	for x in range(1, 4):
		assert_has(removed, Vector3i(x, 0, 0))
		assert_false(grid.has_block(Vector3i(x, 0, 0)))
	assert_true(grid.has_block(Vector3i.ZERO))
	assert_signal_emit_count(grid, "cell_changed", 1, "one rebuild for the lot")

func test_kept_blocks_stop_at_wrecked():
	for id in BlockDamage.KEEP:
		var grid := _line()
		_put(grid, Vector3i(0, 1, 0), id)
		var at := Vector3i(0, 1, 0) if id != &"core" else Vector3i.ZERO
		var removed := BlockDamage.apply(grid, _catalog, at, _hp(id) * 10.0)
		assert_eq(removed, [], "%s is never removed" % id)
		assert_true(grid.has_block(at))
		assert_eq(BlockDamage.stage_of(grid.get_block(at), _catalog.get_def(id)), BlockDamage.Stage.WRECKED)

func test_a_grid_without_a_core_removes_only_the_block():
	var grid := ShipGrid.new()
	for x in 3:
		_put(grid, Vector3i(x, 0, 0), &"hull")
	var removed := BlockDamage.apply(grid, _catalog, Vector3i(1, 0, 0), _hp(&"hull") * 2.0)
	assert_eq(removed, [Vector3i(1, 0, 0)])
	assert_eq(grid.size(), 2)

func test_nothing_happens_to_an_empty_cell_or_no_damage():
	var grid := _line()
	assert_eq(BlockDamage.apply(grid, _catalog, Vector3i(9, 9, 9), 50.0), [])
	assert_eq(BlockDamage.apply(grid, _catalog, Vector3i(3, 0, 0), 0.0), [])
	assert_eq(grid.get_block(Vector3i(3, 0, 0)).damage, 0.0)

func test_repair_lowers_damage_and_returns_what_it_used():
	var grid := _line()
	var at := Vector3i(3, 0, 0)
	BlockDamage.apply(grid, _catalog, at, 50.0)
	assert_eq(BlockDamage.repair(grid, _catalog, at, 20.0), 20.0)
	assert_eq(grid.get_block(at).damage, 30.0)
	assert_eq(BlockDamage.repair(grid, _catalog, at, 100.0), 30.0, "never below 0")
	assert_eq(grid.get_block(at).damage, 0.0)
	assert_eq(BlockDamage.repair(grid, _catalog, at, 10.0), 0.0, "nothing to mend")
	assert_eq(BlockDamage.repair(grid, _catalog, Vector3i(9, 9, 9), 10.0), 0.0)

func test_repair_fires_block_staged_on_the_way_up():
	var grid := _line()
	var at := Vector3i(3, 0, 0)
	BlockDamage.apply(grid, _catalog, at, _hp(&"hull"))
	watch_signals(grid)
	BlockDamage.repair(grid, _catalog, at, _hp(&"hull") * 0.6)
	assert_signal_emitted_with_parameters(grid, "block_staged", [at, BlockDamage.Stage.INTACT])

func test_rebuild_puts_a_block_back_wrecked():
	var grid := _line()
	var at := Vector3i(4, 0, 0)
	watch_signals(grid)
	BlockDamage.rebuild(grid, _catalog, at, &"thruster", 3)
	var inst := grid.get_block(at)
	assert_eq(inst.block_id, &"thruster")
	assert_eq(inst.orientation, 3)
	assert_eq(inst.damage, _hp(&"thruster") * BlockDamage.WRECKED_AT)
	assert_eq(BlockDamage.stage_of(inst, _catalog.get_def(&"thruster")), BlockDamage.Stage.WRECKED)
	assert_signal_emit_count(grid, "cell_changed", 1)

func test_remove_many_erases_all_with_one_signal():
	var grid := _line()
	watch_signals(grid)
	grid.remove_many([Vector3i(2, 0, 0), Vector3i(3, 0, 0), Vector3i(7, 7, 7)])
	assert_eq(grid.size(), 2)
	assert_signal_emit_count(grid, "cell_changed", 1)
	grid.remove_many([Vector3i(7, 7, 7)])
	assert_signal_emit_count(grid, "cell_changed", 1, "nothing removed, nothing said")
