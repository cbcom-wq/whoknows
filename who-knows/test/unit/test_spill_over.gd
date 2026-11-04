extends GutTest

## Spill-over (hostile ships spec §8.1, decision 10): damage a section at 0
## cannot take passes to its neighbouring sections, split between those still
## standing and on outward when they are at 0 too, so HULL % reaches 0 under
## hits on one face. Components never spill.

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

## A hull block off the centre line in `section`.
func _in(section: StringName) -> Vector3i:
	for coord: Vector3i in _d.sections_of:
		if _d.sections_of[coord] == [section]:
			return coord
	fail_test("no block in %s" % section)
	return Vector3i(99, 99, 99)

func _first(id: StringName) -> Vector3i:
	for coord: Vector3i in _grid.coords():
		if _grid.get_block(coord).block_id == id:
			return coord
	return Vector3i(99, 99, 99)

func _fill(section: StringName) -> void:
	_d.section_damage[section] = _d.section_hp[section]

func test_overflow_goes_to_neighbours():
	var hp: float = _d.section_hp[&"port_bow"]
	_d.hit(_in(&"port_bow"), hp + 1000.0)
	assert_eq(_d.health(&"port_bow"), 0.0)
	assert_almost_eq(_d.section_damage[&"starboard_bow"], 500.0, 1.0)
	assert_almost_eq(_d.section_damage[&"port_mid"], 500.0, 1.0)
	for id in [&"starboard_mid", &"port_stern", &"starboard_stern"]:
		assert_eq(_d.section_damage[id], 0.0, "%s is no neighbour of the port bow" % id)

func test_overflow_skips_dead_neighbours():
	_fill(&"port_bow")
	_fill(&"starboard_bow")
	_d.hit(_in(&"port_bow"), 1000.0)
	assert_almost_eq(_d.section_damage[&"port_mid"], 1000.0, 0.01)
	assert_eq(_d.section_damage[&"starboard_mid"], 0.0)

func test_overflow_goes_on_outward_past_dead_neighbours():
	_fill(&"port_bow")
	_fill(&"starboard_bow")
	_fill(&"port_mid")
	_d.hit(_in(&"port_bow"), 1000.0)
	assert_almost_eq(_d.section_damage[&"starboard_mid"] + _d.section_damage[&"port_stern"], 1000.0, 0.01,
		"the next ones standing take it")
	assert_eq(_d.section_damage[&"starboard_stern"], 0.0)

func test_one_face_can_reach_zero():
	var total := 0.0
	for id in ShipDamage.SECTIONS:
		total += _d.section_hp[id]
	var cell := _in(&"port_bow")
	var dealt := 0.0
	while _d.hull_whole() > 0.0 and dealt < total * 2.0:
		_d.hit(cell, 50.0)
		dealt += 50.0
	assert_eq(_d.hull_whole(), 0.0)
	assert_almost_eq(dealt, total, total * 0.01, "every hit counted")
	_d.hit(cell, 1000.0)
	assert_eq(_d.hull_whole(), 0.0, "the rest is dropped when every section is at 0")

func test_components_never_spill():
	_d.hit(_first(&"quantum_core"), 5000.0)
	assert_eq(_d.component_damage[&"quantum_core"], _d.component_hp[&"quantum_core"])
	for id in ShipDamage.SECTIONS:
		assert_eq(_d.section_damage[id], 0.0, "%s untouched" % id)
	for comp: StringName in _d.component_damage:
		if comp != &"quantum_core":
			assert_eq(_d.component_damage[comp], 0.0, "%s untouched" % comp)

func test_crash_damage_spills_too():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var ship: Ship = root.get_node("Ship")
	var cell := Vector3i(99, 99, 99)
	for coord: Vector3i in ship.damage.sections_of:
		if ship.damage.sections_of[coord] == [&"port_bow"] and ship.grid.has_block(coord):
			cell = coord
			break
	assert_true(ship.grid.has_block(cell), "a port-bow block")
	var hp: float = ship.damage.section_hp[&"port_bow"]
	ship.take_damage_many({cell: hp + 800.0})
	assert_eq(ship.damage.health(&"port_bow"), 0.0)
	assert_almost_eq(ship.damage.section_damage[&"starboard_bow"] + ship.damage.section_damage[&"port_mid"],
		800.0, 0.01, "a neighbour takes the rest")
