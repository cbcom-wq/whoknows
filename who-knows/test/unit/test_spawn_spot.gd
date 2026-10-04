extends GutTest

## SpawnSpot (docs/superpowers/specs/2026-10-02-ship-library-design.md §5):
## straight ahead when clear, the next step round you when not, farther out
## after that, never into a rock or a ship, and always facing you.

var _from: Transform3D
var _no_rocks := func(_p: Vector3) -> bool: return false
var _no_ships: Array[Vector3] = []

func before_each():
	_from = Transform3D(Basis(Vector3.UP, 0.7), Vector3(10, 5, -30))

func _ahead() -> Vector3:
	return -_from.basis.z

func _angle_off_ahead(spot: Transform3D) -> float:
	return rad_to_deg((spot.origin - _from.origin).angle_to(_ahead()))

func test_clear_it_is_straight_ahead():
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, _no_rocks)
	assert_almost_eq(spot.origin, _from.origin + _ahead() * SpawnSpot.AHEAD, Vector3.ONE * 0.001)

func test_it_faces_you_upright():
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, _no_rocks)
	assert_almost_eq((-spot.basis.z).dot((_from.origin - spot.origin).normalized()), 1.0, 0.0001)
	assert_almost_eq(spot.basis.y.dot(_from.basis.y), 1.0, 0.0001)

func test_a_rock_ahead_moves_it_one_step_round():
	var blocked := _from.origin + _ahead() * SpawnSpot.AHEAD
	var rocks := func(p: Vector3) -> bool: return p.distance_to(blocked) < 1.0
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, rocks)
	assert_almost_eq(_angle_off_ahead(spot), SpawnSpot.STEP_DEG, 0.01)
	assert_almost_eq(spot.origin.distance_to(_from.origin), SpawnSpot.AHEAD, 0.001)

func test_a_ship_ahead_moves_it_too():
	var ships: Array[Vector3] = [_from.origin + _ahead() * (SpawnSpot.AHEAD + SpawnSpot.CLEAR - 5.0)]
	var spot: Transform3D = SpawnSpot.find(_from, ships, _no_rocks)
	assert_almost_eq(_angle_off_ahead(spot), SpawnSpot.STEP_DEG, 0.01)

func test_blocked_all_round_it_goes_farther_out():
	var rocks := func(p: Vector3) -> bool: return p.distance_to(_from.origin) < SpawnSpot.AHEAD + 1.0
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, rocks)
	assert_almost_eq(spot.origin, _from.origin + _ahead() * SpawnSpot.FARTHER, Vector3.ONE * 0.001)

## Coming straight at you, its wake would hide behind it: it comes in across
## your view instead, toward you and to one side, level with the spot's up.
func test_it_comes_in_across_your_view():
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, _no_rocks)
	var line := SpawnSpot.arrival_line(spot)
	var toward_you := (_from.origin - spot.origin).normalized()
	assert_almost_eq(line.length(), 1.0, 0.0001)
	assert_almost_eq(rad_to_deg(line.angle_to(toward_you)), SpawnSpot.ACROSS_DEG, 0.01)
	assert_almost_eq(line.dot(spot.basis.y), 0.0, 0.0001)

func test_with_nothing_clear_it_refuses():
	assert_null(SpawnSpot.find(_from, _no_ships, func(_p: Vector3) -> bool: return true))
