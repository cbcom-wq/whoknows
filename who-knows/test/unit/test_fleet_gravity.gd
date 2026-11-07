extends GutTest

## Every ship in a world's well feels it, however it got there: spawned into
## the fleet, or woken from sleep (desert world plan, phase 0, task 11). With
## the assist on and the stick centred it hovers; it was never wired per path.

const HEIGHT := 300.0
const SETTLE := 180
const HOVER_FRAMES := 180
const DRIFT := 2.0

var _root: Node
var _fleet: Fleet
var _universe: Universe
var _centre: Vector3
var _out: Vector3
var _ground: float

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_fleet = _root.fleet
	_universe = _root.get_node("Universe")
	await wait_physics_frames(3)
	_root.reload = func() -> void: pass

## The first planet, 3 km off by the hop, its ground drawn: where a ship is
## to be spawned `HEIGHT` above.
func _go_to_a_world() -> void:
	var system: SystemRecipe = _root.system
	var planet: SystemBody = system.planets()[0]
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface, "3 km off: its ground is drawn")
	var starter: Ship = _root.get_node("Ship")
	_centre = _universe.to_engine(planet.point)
	_out = (starter.exterior.global_position - _centre).normalized()
	_ground = planet.radius + surface.terrain.height_at(_out)

func _spawn_above() -> Ship:
	var along := _out.cross(Vector3.UP).normalized()
	var basis := Basis(along, _out, along.cross(_out).normalized())
	var place := Transform3D(basis, _centre + _out * (_ground + HEIGHT))
	var ship: Ship = _fleet.spawn(_root._starter_grid(), place)
	ship.flight_computer.assist_enabled = true
	return ship

func _altitude(ship: Ship) -> float:
	return _root.world_gravity.altitude_at(ship.exterior.global_position)

func _assert_hovers(ship: Ship, what: String) -> void:
	await wait_physics_frames(SETTLE)
	var before := _altitude(ship)
	var keel_before := ship.flight_computer.keel_altitude()
	await wait_physics_frames(HOVER_FRAMES)
	assert_almost_eq(_altitude(ship), before, DRIFT, "%s: it hovers (hull altitude)" % what)
	assert_almost_eq(ship.flight_computer.keel_altitude(), keel_before, DRIFT, "%s: it hovers (keel altitude)" % what)
	assert_gt(_altitude(ship), 100.0, "%s: and has not fallen" % what)

func test_a_spawned_ship_is_wired_and_hovers():
	await _go_to_a_world()
	var ship := _spawn_above()
	assert_same(ship.flight_computer.gravity, _root.world_gravity, "the scene's one gravity")
	assert_gt(ship.flight_computer.keel_depth, 0.0, "its keel is measured")
	assert_not_null(ship.landing, "its landing monitor")
	assert_false(ship.landing.is_landed())
	assert_almost_eq(_altitude(ship), HEIGHT, 5.0, "it is where it was put")
	await _assert_hovers(ship, "spawned")

func test_a_ship_put_to_sleep_and_woken_still_hovers():
	await _go_to_a_world()
	var ship := _spawn_above()
	await _assert_hovers(ship, "spawned")
	_fleet.sleep(ship)
	assert_true(_fleet.sleeping(ship))
	await wait_physics_frames(30)
	_fleet.wake(ship)
	assert_false(_fleet.sleeping(ship))
	assert_same(ship.flight_computer.gravity, _root.world_gravity, "still the one gravity")
	assert_gt(ship.flight_computer.keel_depth, 0.0)
	assert_false(ship.landing.is_landed(), "it was not landed")
	assert_false(ship.exterior.freeze, "and is not frozen")
	await _assert_hovers(ship, "woken")
