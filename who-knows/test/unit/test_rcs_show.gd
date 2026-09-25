extends GutTest

## The RCS thrusters you see and hear (flight controls spec §6), on the
## starter shuttle.

var _cat: BlockCatalog
var _grid: ShipGrid
var _stats: ShipStats
var _blocks: Array

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	_grid = bootstrap._starter_grid()
	bootstrap.free()
	_stats = ShipStats.compute(_grid, _cat)
	_blocks = RcsShow.gather(_grid, _cat, _stats.center_of_mass)

func _fire(torque: Vector3, force := Vector3.ZERO) -> PackedFloat32Array:
	return RcsShow.firing_for(_blocks, torque, force, _stats.torque_budget, _stats.thrust_budget)

## The cells of the blocks that show for this command, sorted.
func _lit(torque: Vector3, force := Vector3.ZERO) -> Array:
	var fire := _fire(torque, force)
	var out := []
	for i in _blocks.size():
		if fire[i] >= RcsShow.SHOW_AT:
			out.append(_blocks[i]["coord"])
	out.sort()
	return out

func _sorted(cells: Array) -> Array:
	var out := cells.duplicate()
	out.sort()
	return out

func _amount(torque: Vector3, coord: Vector3i) -> float:
	var fire := _fire(torque)
	for i in _blocks.size():
		if _blocks[i]["coord"] == coord:
			return fire[i]
	return -1.0

func test_the_shuttle_has_eight_rcs_blocks():
	assert_eq(_blocks.size(), 8)

func test_pitch_up_fires_the_two_nose_up_thrusters():
	assert_eq(_lit(Vector3(_stats.torque_budget.x, 0, 0)),
		_sorted([Vector3i(-2, 1, -3), Vector3i(2, 1, -3)]))

func test_pitch_down_fires_the_two_nose_down_thrusters():
	assert_eq(_lit(Vector3(-_stats.torque_budget.x, 0, 0)),
		_sorted([Vector3i(-2, 1, -4), Vector3i(2, 1, -4)]))

func test_yaw_fires_the_one_nose_thruster_pushing_the_right_way():
	assert_eq(_lit(Vector3(0, _stats.torque_budget.y, 0)), [Vector3i(1, 1, -4)])
	assert_eq(_lit(Vector3(0, -_stats.torque_budget.y, 0)), [Vector3i(-1, 1, -4)])

func test_roll_fires_one_sides_up_with_the_other_sides_down():
	assert_eq(_lit(Vector3(0, 0, _stats.torque_budget.z)),
		_sorted([Vector3i(2, 1, -3), Vector3i(-2, 1, -4)]))
	assert_eq(_lit(Vector3(0, 0, -_stats.torque_budget.z)),
		_sorted([Vector3i(-2, 1, -3), Vector3i(2, 1, -4)]))

func test_braking_fires_the_retros_and_nothing_fires_for_the_main_engines():
	assert_eq(_lit(Vector3.ZERO, Vector3(0, 0, _stats.thrust_budget[&"reverse"])),
		_sorted([Vector3i(-2, 1, -2), Vector3i(2, 1, -2)]))
	assert_eq(_lit(Vector3.ZERO, Vector3(0, 0, -_stats.thrust_budget[&"forward"])), [])

func test_strafing_fires_the_thruster_pushing_that_way():
	assert_eq(_lit(Vector3.ZERO, Vector3(_stats.thrust_budget[&"lateral"], 0, 0)),
		[Vector3i(-1, 1, -4)])

func test_a_settled_ship_fires_nothing():
	assert_eq(_lit(Vector3.ZERO), [])

func test_half_a_command_fires_half_as_hard():
	assert_almost_eq(_amount(Vector3(_stats.torque_budget.x * 0.5, 0, 0), Vector3i(-2, 1, -3)),
		0.5, 0.01)

func test_the_exhaust_leaves_the_face_opposite_the_push():
	for b in _blocks:
		var centre := ShipGrid.cell_center(b["coord"])
		var push: Vector3 = (b["force"] as Vector3).normalized()
		assert_almost_eq(b["nozzle"], centre - push * ShipGrid.CELL_SIZE * 0.5, Vector3.ONE * 0.001)

func test_a_block_puffs_once_as_it_starts_firing():
	assert_eq(RcsShow.puff_step(0.5, true, 1.0), [true, false])

func test_a_held_firing_does_not_puff_again():
	assert_eq(RcsShow.puff_step(0.5, false, 1.0), [false, false])

func test_it_rearms_once_the_firing_falls_away():
	assert_eq(RcsShow.puff_step(0.02, false, 1.0), [false, true])

func test_a_faint_firing_never_puffs():
	assert_eq(RcsShow.puff_step(0.1, true, 1.0), [false, true])

func test_puffs_are_never_closer_than_the_gap():
	assert_eq(RcsShow.puff_step(0.5, true, RcsShow.PUFF_GAP * 0.5), [false, true])

func _built() -> Array:
	var interior := Node3D.new()
	add_child_autofree(interior)
	var show := RcsShow.new()
	add_child_autofree(show)
	show.setup(null, interior)
	show.rebuild(_grid, _cat, _stats.center_of_mass)
	return [show, interior]

func test_every_block_gets_a_world_space_emitter_on_the_world_layer():
	var show: RcsShow = _built()[0]
	assert_eq(show.emitters.size(), 8)
	for e in show.emitters:
		assert_false(e.local_coords, "puffs hang where they left")
		assert_eq(e.layers, 1, "on the world layer, so the canopy shows them")
		assert_true(e.is_in_group(Universe.HOLDS_SHIFT), "world-space puffs hold the origin's shift")
		assert_false(e.emitting)

func test_each_emitter_blows_out_of_its_nozzle():
	var show: RcsShow = _built()[0]
	for i in show.blocks.size():
		var e := show.emitters[i]
		var push: Vector3 = (show.blocks[i]["force"] as Vector3).normalized()
		assert_almost_eq(e.position, show.blocks[i]["nozzle"], Vector3.ONE * 0.001)
		assert_almost_eq(-e.transform.basis.z, -push, Vector3.ONE * 0.001)

func test_puffs_follow_the_firing():
	var show: RcsShow = _built()[0]
	var amounts := PackedFloat32Array()
	amounts.resize(8)
	amounts[0] = 0.6
	amounts[1] = 0.02
	show.apply(amounts)
	assert_true(show.emitters[0].emitting)
	assert_almost_eq(show.emitters[0].amount_ratio, 0.6, 0.001)
	assert_false(show.emitters[1].emitting, "too faint to show")

func test_each_block_is_heard_where_it_sits_aboard():
	var built := _built()
	var show: RcsShow = built[0]
	assert_eq(show.players.size(), 8)
	for i in show.blocks.size():
		var p := show.players[i]
		var coord: Vector3i = show.blocks[i]["coord"]
		assert_same(p.get_parent(), built[1])
		assert_eq(p.bus, AudioBuses.SHIP)
		assert_almost_eq(p.position,
			ShipGrid.cell_center(coord) + Vector3(0.0, InteriorBuilder.storey_offset(coord.y), 0.0),
			Vector3.ONE * 0.001)

func test_a_rebuild_replaces_rather_than_adds():
	var built := _built()
	var show: RcsShow = built[0]
	show.rebuild(_grid, _cat, _stats.center_of_mass)
	assert_eq(show.emitters.size(), 8)
	assert_eq(show.get_child_count(), 8)
	assert_eq((built[1] as Node).get_child_count(), 8)

func test_the_flight_scene_shows_the_shuttles_rcs():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var show: RcsShow = root.get_node_or_null("Ship/Exterior/RcsShow")
	assert_not_null(show, "on the hull, so the floating origin carries it")
	assert_eq(show.emitters.size(), 8)
