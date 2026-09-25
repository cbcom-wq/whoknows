extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid

func before_each():
	_cat = BlockCatalog.new()
	_cat.register(_def(&"core", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(&"hull", BlockDefinition.Occupancy.SOLID))
	_cat.register(_def(&"deck", BlockDefinition.Occupancy.DECK))
	_cat.register(_def(&"pilot_seat", BlockDefinition.Occupancy.MOUNT))
	_cat.register(_def(&"ladder", BlockDefinition.Occupancy.MOUNT))
	var reactor := _def(&"reactor", BlockDefinition.Occupancy.SOLID)
	reactor.power_gen = 10.0
	_cat.register(reactor)
	var lamp := _def(&"lamp", BlockDefinition.Occupancy.SOLID)
	lamp.power_draw = 50.0
	_cat.register(lamp)
	_cat.register(_def(&"quantum_core", BlockDefinition.Occupancy.MOUNT))
	_cat.register(_def(&"quantum_machine", BlockDefinition.Occupancy.MOUNT))
	var cell := _def(&"quantum_cell", BlockDefinition.Occupancy.SOLID)
	cell.quantum_capacity = 400
	_cat.register(cell)
	_grid = ShipGrid.new()

func _def(id: StringName, occ: BlockDefinition.Occupancy) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = occ
	return d

func _put(coord: Vector3i, id: StringName) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	_grid.set_block(coord, i)

func _codes(issues: Array) -> Array:
	var out: Array = []
	for issue in issues:
		out.append(issue.code)
	return out

## A minimal ship that passes every rule: core, one deck, a seat beside it,
## and -- spec §5.2's Rule 7 -- a quantum core, machine and cell too, each
## face-connected and the two MOUNTs walkable from the seat, so every other
## test here still isolates its own rule.
func _build_valid_ship() -> void:
	_put(Vector3i(0, 0, 0), &"core")
	_put(Vector3i(1, 0, 0), &"deck")
	_put(Vector3i(2, 0, 0), &"pilot_seat")
	_put(Vector3i(3, 0, 0), &"reactor")
	_put(Vector3i(2, 0, -1), &"quantum_core")
	_put(Vector3i(2, 0, -2), &"quantum_machine")
	_put(Vector3i(1, 0, -1), &"quantum_cell")

func test_valid_ship_has_no_issues():
	_build_valid_ship()
	var issues := ShipValidator.validate(_grid, _cat)
	assert_eq(_codes(issues), [], "minimal valid ship should be clean")
	assert_true(ShipValidator.can_launch(issues))

func test_missing_core_is_an_error():
	_put(Vector3i(0, 0, 0), &"deck")
	_put(Vector3i(1, 0, 0), &"pilot_seat")
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"SINGLE_CORE"))
	assert_false(ShipValidator.can_launch(issues))

func test_two_cores_is_an_error():
	_build_valid_ship()
	_put(Vector3i(4, 0, 0), &"core")
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"SINGLE_CORE"))

func test_disconnected_block_is_an_error():
	_build_valid_ship()
	_put(Vector3i(20, 0, 0), &"hull")
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"ALL_CONNECTED"))

func test_missing_pilot_seat_is_an_error():
	_put(Vector3i(0, 0, 0), &"core")
	_put(Vector3i(1, 0, 0), &"deck")
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"HAS_PILOT_SEAT"))

## The nasty one: a mount walled off behind sealed structure. It is
## physically attached to the hull, so rule 2 passes — but you cannot
## walk to it, so rule 4 must catch it.
func test_mount_sealed_behind_bulkhead_is_unreachable():
	_build_valid_ship()
	_put(Vector3i(4, 0, 0), &"hull")     # a wall
	_put(Vector3i(5, 0, 0), &"ladder")   # a MOUNT stranded on the far side
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(
		_codes(issues).has(&"MOUNTS_REACHABLE"),
		"a mount you cannot walk to must fail rule 4"
	)
	assert_false(ShipValidator.can_launch(issues))

func test_mount_on_a_second_deck_with_a_ladder_is_reachable():
	_build_valid_ship()
	_put(Vector3i(2, 1, 0), &"ladder")
	_put(Vector3i(3, 1, 0), &"deck")
	# The seat at (2,0,0) is a MOUNT; the ladder above it links the storeys.
	var issues := ShipValidator.validate(_grid, _cat)
	assert_false(_codes(issues).has(&"MOUNTS_REACHABLE"))

func test_power_deficit_is_a_warning_not_an_error():
	_build_valid_ship()
	_put(Vector3i(4, 0, 0), &"lamp")   # draws 50 MW against 10 MW generated
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"POWER_MARGIN"))
	assert_true(
		ShipValidator.can_launch(issues),
		"brownouts are a mechanic, not a build error"
	)

func test_empty_grid_reports_missing_core_and_seat():
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"SINGLE_CORE"))
	assert_true(_codes(issues).has(&"HAS_PILOT_SEAT"))

func test_an_airlock_with_one_face_onto_space_is_fine():
	_build_valid_ship()
	_cat.register(_def(&"airlock", BlockDefinition.Occupancy.DECK))
	_put(Vector3i(1, 0, 1), &"airlock")   # open aft; the deck at -z, hull either side
	_put(Vector3i(0, 0, 1), &"hull")
	_put(Vector3i(2, 0, 1), &"hull")
	assert_false(_codes(ShipValidator.validate(_grid, _cat)).has(&"AIRLOCK_HATCH"))

func test_an_airlock_with_no_single_face_onto_space_is_a_warning():
	_build_valid_ship()
	_cat.register(_def(&"airlock", BlockDefinition.Occupancy.DECK))
	_put(Vector3i(1, 0, 1), &"airlock")   # open aft and on both sides
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"AIRLOCK_HATCH"))
	assert_true(ShipValidator.can_launch(issues), "a warning, not an error")

## Rule 7 (spec §5.2): a ship needs at least one quantum core, one quantum
## machine and one quantum cell -- no power, no way to gain QE, or nowhere to
## keep it, as fatal as having no pilot seat.
func test_missing_quantum_core_is_an_error():
	_build_valid_ship()
	_grid.clear_block(Vector3i(2, 0, -1))
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"QUANTUM"))
	assert_false(ShipValidator.can_launch(issues))

func test_missing_quantum_machine_is_an_error():
	_build_valid_ship()
	_grid.clear_block(Vector3i(2, 0, -2))
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"QUANTUM"))
	assert_false(ShipValidator.can_launch(issues))

func test_missing_quantum_cell_is_an_error():
	_build_valid_ship()
	_grid.clear_block(Vector3i(1, 0, -1))
	var issues := ShipValidator.validate(_grid, _cat)
	assert_true(_codes(issues).has(&"QUANTUM"))
	assert_false(ShipValidator.can_launch(issues))

func test_missing_all_three_quantum_blocks_is_three_errors():
	_build_valid_ship()
	_grid.clear_block(Vector3i(2, 0, -1))
	_grid.clear_block(Vector3i(2, 0, -2))
	_grid.clear_block(Vector3i(1, 0, -1))
	var issues := ShipValidator.validate(_grid, _cat)
	var quantum_issues := issues.filter(func(i): return i.code == &"QUANTUM")
	assert_eq(quantum_issues.size(), 3, "no core, no machine and no cell each report")
	assert_false(ShipValidator.can_launch(issues))

func test_ship_with_all_three_quantum_blocks_has_no_quantum_issue():
	_build_valid_ship()
	var issues := ShipValidator.validate(_grid, _cat)
	assert_false(_codes(issues).has(&"QUANTUM"))
