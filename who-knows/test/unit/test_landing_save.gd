extends GutTest

## A landed ship saves landed and loads frozen on the ground, awake or asleep
## (docs/superpowers/specs/2026-11-03-desert-world-design.md §5.3). Old saves
## without the key load flying.

var _root: Node
var _fleet: Fleet
var _starter: Ship
var _universe: Universe

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_fleet = _root.fleet
	_starter = _root.get_node("Ship")
	_universe = _root.get_node("Universe")

func _spawn(off: Vector3) -> Ship:
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + off)
	return _fleet.spawn(_root._starter_grid(), place)

## A ship landed on a hull tilted 10 degrees, `off` from the starter.
func _landed_ship(off: Vector3) -> Ship:
	var ship := _spawn(Vector3(300, 0, 0))
	ship.exterior.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)),
		_starter.exterior.global_position + off)
	ship.landing.restore_landed()
	return ship

func test_a_landed_hull_is_written_landed():
	var ship := _landed_ship(Vector3(0, 0, 200))
	assert_true(bool(ship.to_dict(_universe)["hull"]["landed"]))
	assert_false(bool(_starter.to_dict(_universe)["hull"]["landed"]), "a flying one is not")

func test_a_landed_ship_loads_landed_and_stays_put_with_no_ground():
	var ship := _landed_ship(Vector3(0, 0, 200))
	var saved := ship.to_dict(_universe)
	var was := ship.exterior.global_transform
	var other := _spawn(Vector3(-300, 0, 0))
	assert_false(other.landing.is_landed())
	_fleet.restore_hull(other, saved)
	await wait_physics_frames(120)
	assert_true(other.landing.is_landed(), "landed")
	assert_true(other.exterior.freeze, "frozen")
	assert_true(other.exterior.global_transform.is_equal_approx(was), "where and as it was")

func test_an_old_save_without_the_key_loads_flying():
	var saved := _starter.to_dict(_universe)
	(saved["hull"] as Dictionary).erase("landed")
	var other := _spawn(Vector3(-300, 0, 0))
	_fleet.restore_hull(other, saved)
	assert_false(other.landing.is_landed())
	assert_false(other.exterior.freeze)

## Ruling 9 (i): saved landed far off, it loads asleep, and wakes landed.
func test_a_landed_ship_loaded_far_off_wakes_landed():
	var ship := _landed_ship(Vector3(0, 0, 25000))
	var saved := ship.to_dict(_universe)
	var at := SaveCodec.to_upoint(saved["hull"]["at"])
	var turn := SaveCodec.to_basis(saved["hull"]["turn"])
	var other := _spawn(Vector3(-300, 0, 0))
	_fleet.restore_hull(other, saved)
	assert_true(_fleet.sleeping(other), "past SLEEP_AT: asleep")
	_fleet.wake(other)
	assert_false(_fleet.sleeping(other))
	assert_true(other.landing.is_landed(), "landed")
	assert_true(other.exterior.freeze, "frozen")
	assert_eq(other.exterior.linear_velocity, Vector3.ZERO)
	assert_eq(other.exterior.angular_velocity, Vector3.ZERO)
	assert_true(other.exterior.global_transform.is_equal_approx(
		Transform3D(turn, _universe.to_engine(at))), "unchanged transform")

## Ruling 9 (ii): put to sleep landed, a capture keeps it.
func test_a_landed_ship_put_to_sleep_is_captured_landed():
	var ship := _landed_ship(Vector3(0, 0, 200))
	_fleet.sleep(ship)
	assert_true(_fleet.sleeping(ship))
	var found := false
	for part: Dictionary in _fleet.capture(_universe):
		if part["name"] == String(ship.name):
			found = true
			assert_true(bool(part["hull"]["landed"]))
	assert_true(found)

func test_a_flying_ship_put_to_sleep_wakes_flying():
	var ship := _spawn(Vector3(0, 0, 200))
	_fleet.sleep(ship)
	_fleet.wake(ship)
	assert_false(ship.landing.is_landed())
	assert_false(ship.exterior.freeze)
