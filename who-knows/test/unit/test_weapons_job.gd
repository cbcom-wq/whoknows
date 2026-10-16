extends GutTest

## Manning the heavy turret (ship weapons spec §7): sitting holds the ship and
## puts you behind the gun's camera; the mouse aims, the trigger fires, the
## wheel zooms, T marks; standing gives the gun back to fire control.

var _root: Node
var _ship: Ship
var _director: CameraDirector
var _station: WeaponsStation

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.starter_ship = "res://test/fixtures/bridge/bridge.json"
	add_child_autofree(_root)
	await wait_process_frames(2)
	_ship = _root.aboard
	_director = _root.get_node("CameraDirector")
	var grid := ShipLibrary.read("res://test/fixtures/bridge/bridge.json")["grid"] as ShipGrid
	for c: Vector3i in grid.coords():
		if grid.get_block(c).block_id == &"crew_station":
			grid.get_block(c).block_id = WeaponValues.STATION
			break
	var heavy := BlockInstance.new()
	heavy.block_id = WeaponValues.HEAVY
	grid.set_block(_free_roof(grid), heavy)
	_ship.launch_blueprint = null
	_ship.set_grid(grid)
	for s in _ship.seats():
		if s is WeaponsStation:
			_station = s

## A cell on top of the fixture's roof with space above it.
func _free_roof(grid: ShipGrid) -> Vector3i:
	var top := -(1 << 20)
	for c: Vector3i in grid.coords():
		top = maxi(top, c.y)
	for c: Vector3i in grid.coords():
		if c.y == top and not grid.has_block(c + Vector3i.UP):
			return c + Vector3i.UP
	return Vector3i(0, top + 1, 0)

func _sit() -> void:
	_director.sit(_station)
	await wait_for_signal(_director.transition_finished, 3)

func test_sitting_takes_the_gun_and_holds_the_ship():
	await _sit()
	var job := _station.job as WeaponsJob
	assert_not_null(job)
	assert_true(job.active)
	assert_true(_ship.flight_computer.gunner_hold)
	assert_true(job.heavy().manual)
	assert_true(job.camera.current, "you look down the gun")

func test_the_trigger_fires_and_standing_gives_it_back():
	await _sit()
	var job := _station.job as WeaponsJob
	var shots := []
	job.heavy().fired.connect(func(_k: StringName) -> void: shots.append(1))
	var click := InputEventAction.new()
	click.action = &"use"
	click.pressed = true
	job.handle(click)
	await wait_physics_frames(2)
	assert_eq(shots.size(), 1)
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)
	assert_false(job.heavy().manual, "fire control has it again")
	assert_false(_ship.flight_computer.gunner_hold, "the helm flies it again")
	assert_false(job.camera.current)

func test_the_mouse_aims_and_the_wheel_zooms():
	await _sit()
	var job := _station.job as WeaponsJob
	var before := job.aim
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(100, -50)
	job.handle(move)
	assert_gt(job.aim.x, before.x, "to the right")
	assert_gt(job.aim.y, before.y, "and up")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	job.handle(wheel)
	assert_almost_eq(job.camera.fov, WeaponsJob.ZOOMS[1], 0.01)

func test_without_a_heavy_turret_it_is_a_board():
	for t in _ship.heavy_turrets():
		_ship.grid.clear_block(t.coord)
	await wait_process_frames(2)
	await _sit()
	var job := _station.job as WeaponsJob
	assert_null(job.view_camera())
	assert_true(_ship.flight_computer.gunner_hold, "you still are not flying")

func test_a_loaded_game_seated_at_the_station_looks_down_the_gun():
	_director.sit_now(_station)
	var job := _station.job as WeaponsJob
	assert_true(job.camera.current, "sat takes the gun camera even with no glide")
	assert_false(_director.camera().current)
