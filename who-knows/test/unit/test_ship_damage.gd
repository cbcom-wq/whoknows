extends GutTest

## Hits and crashes reach the real ship's blocks (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §4, §5).

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _hit(at: Vector3, normal: Vector3, damage: float) -> Hit:
	var hit := Hit.make(at, normal, -normal, Vector3.ZERO, null)
	hit.damage = damage
	return hit

## A hull block with open space on +x, and not a kept one.
func _outer_hull() -> Vector3i:
	for coord: Vector3i in _ship.grid.coords():
		var id := _ship.grid.get_block(coord).block_id
		if id == &"hull" and not _ship.grid.has_block(coord + Vector3i(1, 0, 0)):
			return coord
	fail_test("no outer hull block on +x")
	return Vector3i.ZERO

func test_the_ship_is_not_crippled_as_built():
	assert_false(_ship.stats.crippled, _ship.stats.crippled_reason)
	assert_gt(_ship.stats.intact_forward, 0.0)

func test_a_hit_on_the_hull_damages_the_cell_it_lands_on():
	var cell := _outer_hull()
	var local := ShipGrid.cell_center(cell) + Vector3(1.0, 0.2, -0.3)
	var hit := _hit(_ship.exterior.to_global(local), _ship.exterior.global_basis * Vector3(1, 0, 0), 10.0)
	Hit.deliver(_ship.exterior, hit)
	assert_eq(_ship.grid.get_block(cell).damage, 10.0)
	assert_eq(_ship.damage_log.busy(), "took damage")
	assert_eq(_ship.busy(), "took damage")

func test_a_hit_on_an_interior_wall_damages_the_block_behind_it():
	var layout: InteriorLayout = _ship.interior_builder.layout()
	for face in layout.faces():
		if face["kind"] != InteriorLayout.Kind.WALL or not face["owner"]:
			continue
		var coord: Vector3i = face["coord"]
		var normal: Vector3i = face["normal"]
		var behind := coord + normal
		if normal.y != 0 or not _ship.grid.has_block(behind):
			continue
		var local := InteriorBuilder.interior_center(coord) + Vector3(normal) * 0.95
		var hit := _hit(_ship.interior.to_global(local), -Vector3(normal), 10.0)
		Hit.deliver(_ship.interior_builder.geometry_body(), hit)
		assert_eq(_ship.grid.get_block(behind).damage, 10.0, "the wall at %s toward %s" % [coord, normal])
		return
	fail_test("no interior wall with a block behind it")

func test_crash_damage_curve():
	assert_eq(Ship.crash_damage(1.0), 0.0)
	assert_eq(Ship.crash_damage(Ship.CRASH_FROM), 0.0, "docking bumps are free")
	assert_almost_eq(Ship.crash_damage(5.0), 108.0, 0.001)
	assert_almost_eq(Ship.crash_damage(8.0), 432.0, 0.001)

func test_a_crash_lands_on_the_cell_and_half_on_its_neighbours():
	var cell := _outer_hull()
	_ship._deal_crash(cell, 40.0)
	assert_eq(_ship.grid.get_block(cell).damage, 40.0)
	for n in _ship.grid.neighbours(cell):
		if _ship.grid.has_block(n):
			assert_eq(_ship.grid.get_block(n).damage, 20.0, "neighbour %s" % n)

func test_a_gone_block_leaves_and_the_ship_is_rebuilt_lighter():
	var cell := _outer_hull()
	var mass := _ship.stats.total_mass_kg
	watch_signals(_ship)
	var removed := _ship.take_damage(cell, 10_000.0)
	assert_has(removed, cell)
	assert_false(_ship.grid.has_block(cell))
	assert_lt(_ship.stats.total_mass_kg, mass)
	assert_signal_emitted(_ship, "blocks_lost")

func test_a_wrecked_thruster_takes_its_thrust_away_without_a_rebuild():
	var thruster := Vector3i.ZERO
	var found := false
	for coord: Vector3i in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"thruster":
			thruster = coord
			found = true
			break
	assert_true(found, "the starter ship has a main engine")
	var forward: float = _ship.flight_computer.thrust_budget[&"forward"]
	var body := _ship.interior_builder.geometry_body()
	_ship.take_damage(thruster, float(_ship.catalog.get_def(&"thruster").hp) * 1.1)
	assert_lt(_ship.flight_computer.thrust_budget[&"forward"], forward)
	assert_same(_ship.interior_builder.geometry_body(), body, "no rebuild for a stage")

func test_nothing_happens_to_an_empty_cell():
	assert_eq(_ship.take_damage(ShipCells.NONE, 50.0), [])
	assert_eq(_ship.take_damage(Vector3i(99, 99, 99), 50.0), [])
	assert_eq(_ship.damage_log.busy(), "")
