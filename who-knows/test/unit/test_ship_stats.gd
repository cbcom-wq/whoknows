extends GutTest

var _cat: BlockCatalog
var _grid: ShipGrid

func before_each():
	_cat = BlockCatalog.new()
	var hull := _def(&"hull")
	hull.mass_t = 1.0
	_cat.register(hull)

	var heavy := _def(&"heavy")
	heavy.mass_t = 9.0
	_cat.register(heavy)

	var thruster := _def(&"thruster")
	thruster.mass_t = 1.0
	thruster.thrust_kn = 100.0
	_cat.register(thruster)

	var reactor := _def(&"reactor")
	reactor.mass_t = 1.0
	reactor.power_gen = 8.0
	_cat.register(reactor)

	var lamp := _def(&"lamp")
	lamp.mass_t = 1.0
	lamp.power_draw = 2.0
	_cat.register(lamp)

	_grid = ShipGrid.new()

func _def(id: StringName) -> BlockDefinition:
	var d := BlockDefinition.new()
	d.id = id
	d.display_name = String(id)
	d.occupancy = BlockDefinition.Occupancy.SOLID
	return d

func _put(coord: Vector3i, id: StringName, orientation: int = 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = orientation
	_grid.set_block(coord, i)

func test_empty_grid_has_zero_mass():
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.total_mass_kg, 0.0, 0.001)

func test_mass_is_summed_in_kilograms():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.total_mass_kg, 2000.0, 0.001, "2 blocks of 1 t = 2000 kg")

func test_center_of_mass_of_symmetric_pair_is_between_them():
	_put(Vector3i(-1, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.center_of_mass, Vector3.ZERO, Vector3.ONE * 0.001)

func test_center_of_mass_shifts_toward_heavy_block():
	_put(Vector3i(0, 0, 0), &"hull")     # 1 t at z = 0
	_put(Vector3i(0, 0, -1), &"heavy")   # 9 t at z = -2 m
	var s := ShipStats.compute(_grid, _cat)
	# (1 * 0 + 9 * -2) / 10 = -1.8
	assert_almost_eq(s.center_of_mass.z, -1.8, 0.001)

func test_single_block_has_nonzero_inertia():
	_put(Vector3i.ZERO, &"hull")
	var s := ShipStats.compute(_grid, _cat)
	assert_true(s.inertia.x > 0.0, "a solid cube has inertia about its own axis")

func test_forward_thruster_fills_forward_budget():
	_put(Vector3i.ZERO, &"thruster", 0)   # orientation 0 = force along -Z
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.thrust_budget[&"forward"], 100_000.0, 1.0, "100 kN = 100000 N")
	assert_almost_eq(s.thrust_budget[&"reverse"], 0.0, 1.0)

func test_two_forward_thrusters_double_the_budget():
	_put(Vector3i(0, 0, 0), &"thruster", 0)
	_put(Vector3i(1, 0, 0), &"thruster", 0)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.thrust_budget[&"forward"], 200_000.0, 1.0)

func test_lateral_thruster_fills_only_lateral_budget():
	# orientation 8 = (o >> 2 == 2) selects Vector3.LEFT as forward;
	# roll (o & 3) doesn't affect thrust direction, only the roll about it.
	_put(Vector3i.ZERO, &"thruster", 8)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.thrust_budget[&"lateral"], 100_000.0, 1.0)
	assert_almost_eq(s.thrust_budget[&"forward"], 0.0, 1.0)
	assert_almost_eq(s.thrust_budget[&"reverse"], 0.0, 1.0)
	assert_almost_eq(s.thrust_budget[&"vertical"], 0.0, 1.0)

func test_vertical_thruster_fills_only_vertical_budget():
	# orientation 16 = (o >> 2 == 4) selects Vector3.UP as forward.
	_put(Vector3i.ZERO, &"thruster", 16)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.thrust_budget[&"vertical"], 100_000.0, 1.0)
	assert_almost_eq(s.thrust_budget[&"forward"], 0.0, 1.0)
	assert_almost_eq(s.thrust_budget[&"reverse"], 0.0, 1.0)
	assert_almost_eq(s.thrust_budget[&"lateral"], 0.0, 1.0)

func test_backward_thruster_fills_reverse_not_forward():
	# orientation 4 = (o >> 2 == 1) selects Vector3.BACK as forward.
	_put(Vector3i.ZERO, &"thruster", 4)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.thrust_budget[&"reverse"], 100_000.0, 1.0)
	assert_almost_eq(s.thrust_budget[&"forward"], 0.0, 1.0)

func test_centred_thrusters_produce_no_torque_imbalance():
	_put(Vector3i(-1, 0, 2), &"thruster", 0)
	_put(Vector3i(1, 0, 2), &"thruster", 0)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.torque_imbalance.length(), 0.0, 1.0,
		"symmetric engines cancel")

func test_offset_thruster_produces_torque_imbalance():
	_put(Vector3i(0, 0, 0), &"heavy")           # mass at the centreline
	_put(Vector3i(4, 0, 2), &"thruster", 0)     # engine far off to one side
	var s := ShipStats.compute(_grid, _cat)
	assert_true(
		s.torque_imbalance.length() > 1.0,
		"an off-centre engine must induce torque under full burn"
	)

func test_power_is_summed():
	_put(Vector3i(0, 0, 0), &"reactor")
	_put(Vector3i(1, 0, 0), &"lamp")
	_put(Vector3i(2, 0, 0), &"lamp")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.power_gen, 8.0, 0.001)
	assert_almost_eq(s.power_draw, 4.0, 0.001)

func test_quantum_capacity_is_summed_like_power():
	var cell := _def(&"cell")
	cell.mass_t = 1.0
	cell.quantum_capacity = 400
	_cat.register(cell)
	_put(Vector3i(0, 0, 0), &"cell")
	_put(Vector3i(1, 0, 0), &"cell")
	_put(Vector3i(2, 0, 0), &"hull")   # no capacity; should not contribute
	var s := ShipStats.compute(_grid, _cat)
	assert_eq(s.quantum_capacity, 800, "two 400-capacity cells sum to 800")

func test_unknown_block_ids_are_ignored():
	_put(Vector3i.ZERO, &"mystery")
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.total_mass_kg, 0.0, 0.001)

func test_torque_budget_uses_the_real_moment_arm():
	# Mass pinned at the origin, an RCS pair four cells forward of it: the
	# arm is 8 m, not the one cell the old estimate assumed.
	_put(Vector3i(0, 0, 0), &"heavy")
	_put(Vector3i(0, 0, -4), &"thruster", 16)   # UP, at the nose
	_put(Vector3i(1, 0, -4), &"thruster", 20)   # DOWN, beside it
	var s := ShipStats.compute(_grid, _cat)
	# The thrusters carry 1 t each, so the centre of mass sits at
	# z = (9*0 + 1*-8 + 1*-8) / 11 = -1.4545, leaving a 6.545 m arm.
	assert_almost_eq(s.torque_budget.x, 654_545.0, 1_000.0,
		"100 kN on a 6.5 m arm is ~654 kN*m of pitch authority")

func test_unopposed_rcs_gives_no_guaranteed_authority():
	# One nose thruster can only pitch the ship one way. Authority is what
	# the pilot can command in *either* direction, so this is zero.
	_put(Vector3i(0, 0, 0), &"heavy")
	_put(Vector3i(0, 0, -4), &"thruster", 16)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.torque_budget.x, 0.0, 1.0)

func test_main_engines_do_not_count_as_attitude_authority():
	# Forward and reverse engines are the thrust budget. They fire along the
	# axis the pilot is translating on, so they are not available to steer.
	_put(Vector3i(0, 0, 0), &"heavy")
	_put(Vector3i(0, 1, 2), &"thruster", 0)
	_put(Vector3i(0, -1, 2), &"thruster", 4)
	var s := ShipStats.compute(_grid, _cat)
	assert_almost_eq(s.torque_budget, Vector3.ZERO, Vector3.ONE * 1.0)
