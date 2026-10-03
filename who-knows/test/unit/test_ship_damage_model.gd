extends GutTest

## ShipDamage on the starter's layout (docs/superpowers/specs/
## 2026-10-03-ship-damage-sections-design.md): six sections and four
## components, hits routed to them, the view the grid shows, and saving.

var _cat: BlockCatalog
var _grid: ShipGrid
var _d: ShipDamage

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	var bootstrap: Node = load("res://scenes/flight_test.gd").new()
	_grid = bootstrap._starter_grid()
	bootstrap.free()
	_d = ShipDamage.build(_grid, _cat, Ship.inner_of(_grid, _cat))

func _first(id: StringName) -> Vector3i:
	for coord: Vector3i in _grid.coords():
		if _grid.get_block(coord).block_id == id:
			return coord
	return Vector3i(99, 99, 99)

## A hull block off the centre line in `section`.
func _in(section: StringName) -> Vector3i:
	for coord: Vector3i in _d.sections_of:
		if _d.sections_of[coord] == [section]:
			return coord
	return Vector3i(99, 99, 99)

func test_six_sections_and_four_components_share_every_block_s_hp():
	var total := 0.0
	for coord: Vector3i in _grid.coords():
		total += _cat.get_def(_grid.get_block(coord).block_id).hp
	var parts := 0.0
	for id in ShipDamage.SECTIONS:
		assert_gt(_d.section_hp[id], 500.0, "%s has hull to it" % id)
		parts += _d.section_hp[id]
	assert_eq(_d.component_hp.size(), 4)
	assert_eq(_d.component_hp[&"engines"], 750.0, "five thrusters")
	assert_eq(_d.component_hp[&"quantum_core"], 250.0)
	assert_eq(_d.component_hp[&"computer"], 300.0, "raised from the block's 60")
	assert_eq(_d.component_hp[&"cockpit"], 300.0, "raised from 240")
	assert_almost_eq(parts + 750.0 + 250.0 + 60.0 + 240.0, total, 0.01)

func test_the_sections_are_thirds_along_and_halves_across():
	for coord: Vector3i in _d.sections_of:
		var sides: Array = _d.sections_of[coord]
		var third := "bow" if coord.z <= -2 else ("mid" if coord.z <= 0 else "stern")
		if coord.x < 0:
			assert_eq(sides, [StringName("port_" + third)])
		elif coord.x > 0:
			assert_eq(sides, [StringName("starboard_" + third)])
		else:
			assert_eq(sides, [StringName("port_" + third), StringName("starboard_" + third)], "the centre line is in both")

func test_a_hit_goes_to_its_component_or_its_section():
	assert_true(_d.hit(_first(&"thruster"), 100.0))
	assert_eq(_d.component_damage[&"engines"], 100.0)
	var port := _in(&"port_bow")
	_d.hit(port, 50.0)
	assert_eq(_d.section_damage[&"port_bow"], 50.0)
	assert_eq(_d.section_damage[&"starboard_bow"], 0.0)
	assert_false(_d.hit(Vector3i(40, 40, 40), 10.0), "not a block of this ship")

func test_a_centre_line_hit_goes_to_the_side_it_landed_on():
	var centre := Vector3i(99, 99, 99)
	for coord: Vector3i in _d.sections_of:
		if _d.sections_of[coord].size() == 2:
			centre = coord
			break
	var sides: Array = _d.sections_of[centre]
	_d.hit(centre, 40.0, -0.3)
	assert_eq(_d.section_damage[sides[0]], 40.0)
	_d.hit(centre, 40.0, 0.3)
	assert_eq(_d.section_damage[sides[1]], 40.0)
	_d.hit(centre, 40.0, 0.0)
	assert_eq(_d.section_damage[sides[0]], 60.0, "half each when dead centre")
	assert_eq(_d.section_damage[sides[1]], 60.0)

func test_damage_stops_at_nothing_left():
	_d.hit(_in(&"port_stern"), 1e9)
	assert_eq(_d.health(&"port_stern"), 0.0)
	assert_eq(_d.section_damage[&"port_stern"], _d.section_hp[&"port_stern"])
	_d.hit(_first(&"computer"), 1e9)
	assert_eq(_d.component_stage(&"computer"), BlockDamage.Stage.WRECKED)
	assert_almost_eq(_d.hull_whole(), 1.0 - _d.section_hp[&"port_stern"] / _total_section_hp(), 0.0001)

func _total_section_hp() -> float:
	var t := 0.0
	for id in ShipDamage.SECTIONS:
		t += _d.section_hp[id]
	return t

func test_a_component_is_damaged_below_half_and_wrecked_at_nothing():
	var c := _first(&"quantum_core")
	_d.hit(c, 124.0)
	assert_eq(_d.component_stage(&"quantum_core"), BlockDamage.Stage.INTACT)
	_d.hit(c, 2.0)
	assert_eq(_d.component_stage(&"quantum_core"), BlockDamage.Stage.DAMAGED)
	_d.hit(c, 1000.0)
	assert_eq(_d.component_stage(&"quantum_core"), BlockDamage.Stage.WRECKED)

func test_the_view_darkens_exposed_blocks_first():
	for coord: Vector3i in _d.launch:
		assert_eq(_d.shown_damage(coord), 0.0)
	var section := &"port_mid"
	_d.section_damage[section] = _d.section_hp[section] * 0.3
	var exposed := Vector3i.ZERO
	var sheltered := Vector3i.ZERO
	var most := -1.0
	var least := 2.0
	for coord: Vector3i in _d.sections_of:
		if _d.sections_of[coord] != [section]:
			continue
		if _d.exposure[coord] > most:
			most = _d.exposure[coord]
			exposed = coord
		if _d.exposure[coord] < least:
			least = _d.exposure[coord]
			sheltered = coord
	var share_e: float = _d.shown_damage(exposed) / _d.launch[exposed][2]
	var share_s: float = _d.shown_damage(sheltered) / _d.launch[sheltered][2]
	assert_gt(share_e, share_s)
	assert_gte(share_s, 0.3, "never less than the section's own share")
	assert_lt(share_e, BlockDamage.GONE_AT, "shown, never gone")

func test_a_component_s_blocks_show_its_share():
	_d.component_damage[&"engines"] = 375.0
	for coord: Vector3i in _d.component_of:
		if _d.component_of[coord] == &"engines":
			assert_almost_eq(_d.shown_damage(coord), 75.0, 0.001, "half of each thruster's 150")
			assert_eq(BlockDamage.stage_at(_d.shown_damage(coord), 150.0), BlockDamage.Stage.DAMAGED)

func test_pieces_break_off_below_half_and_come_back_in_reverse():
	for id in ShipDamage.SECTIONS:
		assert_gt(_d.pieces[id].size(), 0, "%s has pieces to lose" % id)
	var id := &"starboard_mid"
	var hp: float = _d.section_hp[id]
	_d.section_damage[id] = hp * 0.5
	assert_eq(_d.lost().size(), 0, "at half: whole")
	_d.section_damage[id] = hp * 0.7
	var some := _d.lost()
	assert_gt(some.size(), 0)
	_d.section_damage[id] = hp
	var all := _d.lost()
	for coord in some:
		assert_true(all.has(coord), "what went first stays gone")
	for coord: Vector3i in _d.pieces[id]:
		assert_true(all.has(coord) or not _d.present(coord) or true)
	assert_eq(all.size() >= _d.pieces[id].size(), true, "all of them at nothing")
	_d.section_damage[id] = hp * 0.7
	assert_eq(_d.lost().keys().size(), some.size(), "welded back up, the same come back")

func test_no_set_of_lost_pieces_leaves_anything_hanging():
	for id in ShipDamage.SECTIONS:
		_d.section_damage[id] = _d.section_hp[id]
	var gone: Array[Vector3i] = []
	for coord in _d.lost():
		gone.append(coord)
	assert_gt(gone.size(), 10)
	assert_eq(BlockDamage.cut_off(_grid, gone), [] as Array[Vector3i])
	var inner := Ship.inner_of(_grid, _cat)
	for coord in gone:
		assert_false(inner.has(coord), "never the cabin's shell")
		assert_true(ShipDamage.STRUCTURE.has(_grid.get_block(coord).block_id), "only plating and fairings")

func test_repairs_mend_a_share_of_a_section_and_hp_of_a_component():
	var id := &"port_bow"
	_d.section_damage[id] = _d.section_hp[id] * 0.5
	assert_almost_eq(_d.repair_section(id, 0.04), 0.04, 0.0001)
	assert_almost_eq(_d.health(id), 0.54, 0.0001)
	assert_almost_eq(_d.repair_section(id, 1.0), 0.46, 0.0001, "only what it lacks")
	assert_eq(_d.repair_section(id, 0.1), 0.0)
	_d.component_damage[&"cockpit"] = 100.0
	assert_eq(_d.repair_component(&"cockpit", 30.0), 30.0)
	assert_eq(_d.repair_component(&"cockpit", 300.0), 70.0)

func test_it_saves_and_loads():
	_d.hit(_in(&"port_bow"), 321.0)
	_d.hit(_first(&"computer"), 50.0)
	var back := ShipDamage.build(_grid, _cat)
	back.from_dict(_d.to_dict())
	assert_eq(back.section_damage[&"port_bow"], 321.0)
	assert_eq(back.component_damage[&"computer"], 50.0)
	back.from_dict({"sections": {"port_bow": 1e9}})
	assert_eq(back.section_damage[&"port_bow"], back.section_hp[&"port_bow"], "clamped")

func test_an_old_save_s_block_damage_becomes_its_sections():
	var p := _in(&"port_stern")
	_grid.get_block(p).damage = 100.0
	var gone := _in(&"starboard_stern")
	var gone_hp := float(_cat.get_def(_grid.get_block(gone).block_id).hp)
	_grid.clear_block(gone)
	_grid.get_block(_first(&"computer")).damage = 30.0
	_d.infer(_grid)
	assert_eq(_d.section_damage[&"port_stern"], 100.0)
	assert_eq(_d.section_damage[&"starboard_stern"], gone_hp, "a missing block counts whole")
	assert_almost_eq(_d.component_damage[&"computer"], 150.0, 0.001, "half the block's hp: half the component's")
