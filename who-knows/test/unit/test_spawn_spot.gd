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

func test_moving_ahead_it_steps_out_of_your_path():
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, _no_rocks, _ahead() * 120.0)
	assert_almost_eq(_angle_off_ahead(spot), SpawnSpot.STEP_DEG, 0.01)

func test_drifting_slowly_it_is_still_straight_ahead():
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, _no_rocks, _ahead() * 1.0)
	assert_almost_eq(_angle_off_ahead(spot), 0.0, 0.01)

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

## Final review M4: in a world's well the spot is lifted clear of the ground
## first (`lift`), and the rocks and ships are asked about where it ends.
func test_a_lift_raises_the_spot_before_it_is_judged():
	var up := _from.basis.y
	var lift := func(p: Vector3) -> Vector3: return p + up * 50.0
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, _no_rocks, Vector3.ZERO, lift)
	assert_almost_eq(spot.origin, _from.origin + _ahead() * SpawnSpot.AHEAD + up * 50.0, Vector3.ONE * 0.001)
	var raised := _from.origin + _ahead() * SpawnSpot.AHEAD + up * 50.0
	var rocks := func(p: Vector3) -> bool: return p.distance_to(raised) < 1.0
	spot = SpawnSpot.find(_from, _no_ships, rocks, Vector3.ZERO, lift)
	var round_once := _from.origin + _ahead().rotated(up, deg_to_rad(SpawnSpot.STEP_DEG)) * SpawnSpot.AHEAD + up * 50.0
	assert_almost_eq(spot.origin, round_once, Vector3.ONE * 0.001, "a rock where it is lifted to moves it round")

## On 1337's desert, p3: a spot 10 m over the ground is lifted to the highest
## ground within the ship's reach of it, plus that reach and GROUND_CLEAR; one
## well up is left where it is.
func test_a_spot_in_a_desert_s_ground_is_lifted_clear_of_it():
	var body := SystemRecipe.from_seed(1337).body(&"p3")
	var t := WorldTerrain.new(body.recipe)
	var centre := Vector3(100.0, -200.0, 50.0)
	var up := Vector3(0.31, 0.9, 0.22).normalized()
	var radius := 30.0
	var low := centre + up * (t.radius + t.height_at(up) + 10.0)
	var lifted := SpawnSpot.clear_of_ground(low, centre, t, radius)
	assert_almost_eq((lifted - centre).normalized(), up, Vector3.ONE * 0.0001, "straight up")
	var highest := -INF
	var a := up.cross(Vector3.RIGHT).normalized()
	var b := up.cross(a)
	for k in 16:
		var o := (a * cos(k * TAU / 16.0) + b * sin(k * TAU / 16.0)) * (radius / t.radius)
		highest = maxf(highest, t.height_at((up + o).normalized()))
	highest = maxf(highest, t.height_at(up))
	assert_gte((lifted - centre).length(), t.radius + highest + radius + SpawnSpot.GROUND_CLEAR - 0.01,
		"its reach and GROUND_CLEAR over the highest ground round it")
	var high := centre + up * (t.radius + t.height_at(up) + 2000.0)
	assert_eq(SpawnSpot.clear_of_ground(high, centre, t, radius), high, "well up: where it is")
