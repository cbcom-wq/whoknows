extends GutTest

## A ship builds a Turret for every turret block and one FireControl (ship
## weapons spec §5.1), keeps them across rebuilds, and saves its orders.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

## The starter with exactly one light turret, at (0, 2, 0): any turret blocks
## the starter already has are cleared first, so this holds whatever it carries.
func _armed() -> ShipGrid:
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	for coord: Vector3i in grid.coords():
		if WeaponValues.is_turret(grid.get_block(coord).block_id):
			grid.clear_block(coord)
	var top := BlockInstance.new()
	top.block_id = WeaponValues.LIGHT
	grid.set_block(Vector3i(0, 2, 0), top)
	return grid

func test_a_turret_block_makes_a_turret():
	_ship.launch_blueprint = null
	_ship.set_grid(_armed())
	await wait_process_frames(2)
	assert_eq(_ship.turrets.size(), 1)
	var t: Turret = _ship.turrets[0]
	assert_eq(t.coord, Vector3i(0, 2, 0))
	assert_same(t.get_parent(), _ship.exterior, "on the hull, so the origin carries it")
	assert_eq(_ship.fire_control.turrets, _ship.turrets)
	assert_same(t.store, _ship.quantum.store)

func test_a_rebuild_keeps_the_same_turret():
	_ship.launch_blueprint = null
	_ship.set_grid(_armed())
	await wait_process_frames(2)
	var t: Turret = _ship.turrets[0]
	_ship._rebuild_everything()
	assert_same(_ship.turrets[0], t)

func test_hitting_it_hurts_the_turret():
	_ship.launch_blueprint = null
	_ship.set_grid(_armed())
	_ship.take_damage(Vector3i(0, 2, 0), 150.0)
	assert_eq(_ship.damage.component_stage(ShipDamage.turret_part(Vector3i(0, 2, 0))), BlockDamage.Stage.DAMAGED)

func test_the_turrets_are_in_the_boards_order_bow_first():
	var grid := _armed()
	for at: Vector3i in [Vector3i(0, 2, -1), Vector3i(-1, 2, 0)]:
		var more := BlockInstance.new()
		more.block_id = WeaponValues.HEAVY if at.x == 0 else WeaponValues.LIGHT
		grid.set_block(at, more)
	_ship.launch_blueprint = null
	_ship.set_grid(grid)
	await wait_process_frames(2)
	assert_eq(_ship.turrets.size(), 3)
	var coords: Array[Vector3i] = []
	for i in _ship.turrets.size():
		var t: Turret = _ship.turrets[i]
		coords.append(t.coord)
		assert_eq(_ship.damage.turret_labels[ShipDamage.turret_part(t.coord)], "TURRET %d" % (i + 1),
			"%s is TURRET %d on the board" % [t.coord, i + 1])
	assert_eq(coords, [Vector3i(0, 2, -1), Vector3i(-1, 2, 0), Vector3i(0, 2, 0)] as Array[Vector3i])
	assert_eq(_ship.heavy_turrets()[0].coord, Vector3i(0, 2, -1), "the bow's heavy first")

func test_the_orders_are_saved():
	_ship.fire_control.mark(&"ship:Ship2")
	_ship.fire_control.set_orders(FireControl.Orders.ENGAGE)
	var d := _ship.to_dict(_root.get_node("Universe"))
	assert_eq(d["weapons"]["orders"], "engage")
	_ship.fire_control.clear()
	_ship.restore_aboard(d)
	assert_eq(_ship.fire_control.list, [&"ship:Ship2"] as Array[StringName])

func test_a_turret_takes_the_sky_the_ship_built_for_it_and_builds_none_of_its_own():
	var bare := _armed()
	bare.clear_block(Vector3i(0, 2, 0))
	_ship.launch_blueprint = null
	_ship.set_grid(bare)
	await wait_process_frames(2)
	assert_eq(_ship.turrets.size(), 0, "none kept over from the starter")
	_ship.launch_blueprint = null
	_ship.set_grid(_armed())
	await wait_process_frames(2)
	var t: Turret = _ship.turrets[0]
	assert_same(t.sky, _ship._skies[Vector3i(0, 2, 0)], "the cached map, not a second build")
