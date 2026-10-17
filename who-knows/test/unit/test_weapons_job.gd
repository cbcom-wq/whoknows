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

## A second heavy turret on the roof level of the first.
func _add_second_heavy() -> void:
	var roof_y := -(1 << 20)
	for c: Vector3i in _ship.grid.coords():
		if _ship.grid.get_block(c).block_id != WeaponValues.HEAVY:
			roof_y = maxi(roof_y, c.y)
	var heavy := BlockInstance.new()
	heavy.block_id = WeaponValues.HEAVY
	for c: Vector3i in _ship.grid.coords():
		if c.y == roof_y and not _ship.grid.has_block(c + Vector3i.UP):
			_ship.grid.set_block(c + Vector3i.UP, heavy)
			break
	await wait_process_frames(2)

func test_losing_the_only_heavy_while_manned_gives_the_seats_eye_back():
	await _sit()
	var job := _station.job as WeaponsJob
	for t in _ship.heavy_turrets():
		_ship.grid.clear_block(t.coord)
	await wait_process_frames(3)
	assert_null(job.heavy())
	assert_null(job.view_camera())
	assert_true(job.camera == null or is_instance_valid(job.camera), "no dangling camera")
	assert_true(_director.camera().current, "the seat's eye again")
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(10, 10)
	assert_false(job.handle(move), "no gun, no aim")
	assert_true(_ship.flight_computer.gunner_hold, "you still are not flying")

func test_losing_the_manned_heavy_moves_the_job_to_the_other():
	await _add_second_heavy()
	assert_eq(_ship.heavy_turrets().size(), 2)
	await _sit()
	var job := _station.job as WeaponsJob
	var gone := job.heavy().coord
	_ship.grid.clear_block(gone)
	await wait_process_frames(3)
	var now := job.heavy()
	assert_not_null(now)
	assert_ne(now.coord, gone)
	assert_true(is_instance_valid(job.camera))
	assert_eq(job.camera.get_parent(), now, "the camera is on the gun that is left")
	assert_true(job.camera.current)
	assert_true(now.manual)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	assert_true(job.handle(wheel))

func test_a_heavy_added_while_manned_with_none_gets_a_camera():
	for t in _ship.heavy_turrets():
		_ship.grid.clear_block(t.coord)
	await wait_process_frames(2)
	await _sit()
	var job := _station.job as WeaponsJob
	assert_null(job.view_camera())
	await _add_second_heavy()
	await wait_process_frames(2)
	assert_not_null(job.view_camera())
	assert_true(job.camera.current)

func test_with_the_mouse_freed_the_gun_does_not_aim_or_fire():
	await _sit()
	var job := _station.job as WeaponsJob
	var shots := []
	job.heavy().fired.connect(func(_k: StringName) -> void: shots.append(1))
	var before := job.aim
	var mode := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(100, -50)
	job._unhandled_input(move)
	var click := InputEventAction.new()
	click.action = &"use"
	click.pressed = true
	job._unhandled_input(click)
	await wait_physics_frames(2)
	Input.mouse_mode = mode
	assert_eq(job.aim, before, "Esc freed the mouse: it is not the gun's")
	assert_eq(shots.size(), 0, "and the click that takes it back does not fire")

func test_taking_a_flipped_heavy_keeps_the_camera_upright():
	var t := _ship.heavy_turrets()[0] as Turret
	t.yaw = 0.0
	t.elevation = 3.0 * PI / 4.0
	t._pose()
	await _sit()
	var job := _station.job as WeaponsJob
	assert_gte(job.aim.y, 0.0)
	assert_lte(job.aim.y, PI * 0.5 + 0.001, "the reticle is upright")
	var cam_fwd := -job.camera.global_basis.z
	assert_lt(cam_fwd.angle_to(t.barrel_dir()), deg_to_rad(1.0), "it looks where the barrels point")
	var normal := t.global_basis * Vector3.UP
	assert_gt(job.camera.global_basis.y.dot(normal), 0.0, "not rolled upside down")

func test_the_sight_fills_the_screen_so_its_cross_is_at_the_middle():
	await _sit()
	var job := _station.job as WeaponsJob
	await wait_process_frames(2)
	assert_true(job.sight.visible)
	assert_eq(job.sight.size, get_viewport().get_visible_rect().size, "a zero-size sight draws its cross in the corner")

func _list_one(node: Node3D) -> void:
	var fc := (_station.job as WeaponsJob).fire_control
	fc.entries.clear()
	fc.entries.append({"id": &"ship:Lead", "node": node, "label": "LEAD", "distance": 100.0, "bearing": false})

func test_a_listed_target_freed_since_the_last_assign_leaves_no_lead_and_raises_nothing():
	await _sit()
	var job := _station.job as WeaponsJob
	var target := Node3D.new()
	_root.add_child(target)
	_list_one(target)
	target.free()
	assert_null(job._lead(job.heavy()), "a freed target has no lead")
	job._process(0.016)
	assert_null(job.sight.lead_point)
	assert_true(job.active, "and the frame went on to the end")

func test_a_listed_target_out_of_the_tree_leaves_no_lead():
	await _sit()
	var job := _station.job as WeaponsJob
	var target := Node3D.new()
	_root.add_child(target)
	_list_one(target)
	_root.remove_child(target)
	assert_null(job._lead(job.heavy()), "a demoted target has no position to lead")
	job._process(0.016)
	assert_null(job.sight.lead_point)
	target.free()

func test_manning_the_gun_is_still_aboard_for_the_hum_the_hull_and_the_guns():
	await _sit()
	var job := _station.job as WeaponsJob
	assert_true(job.camera.current)
	assert_true(_ship._aboard(), "the gun's camera is on the hull but you are in the ship")
	assert_true(_ship.listener_aboard(), "so the guns thud through the hull")
	assert_true(_ship.rcs_show._aboard(), "and the thrusters puff")
	await wait_process_frames(2)
	assert_true(_ship._hum.playing, "and the hum goes on")
	var outside := Camera3D.new()
	_root.add_child(outside)
	outside.make_current()
	assert_false(_ship.listener_aboard(), "a camera elsewhere is outside")
	assert_false(_ship.rcs_show._aboard())
