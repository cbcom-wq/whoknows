extends GutTest

## The spacewalk's suit (docs/superpowers/specs/2026-09-24-airlock-design.md
## §8), headless: thrust along the view, and an assist that holds you still
## relative to your own ship.

const DT := 1.0 / 60.0

func _run(v: Vector3, v_ref: Vector3, input: Vector3, view: Basis, assist: bool, seconds: float) -> Vector3:
	for i in int(round(seconds / DT)):
		v = Suit.step(v, v_ref, input, view, assist, DT)
	return v

func test_thrust_pushes_along_the_view():
	var view := Basis(Vector3.UP, 0.5)
	var v := _run(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -1), view, false, 1.0)
	assert_almost_eq(v, view * Vector3(0, 0, -Suit.ACCEL), Vector3.ONE * 0.01, "forward is where you look")
	var up := _run(Vector3.ZERO, Vector3.ZERO, Vector3(0, 1, 0), view, false, 1.0)
	assert_almost_eq(up, view * Vector3(0, Suit.ACCEL, 0), Vector3.ONE * 0.01)

func test_diagonal_thrust_is_no_stronger():
	var v := _run(Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, -1), Basis.IDENTITY, false, 1.0)
	assert_almost_eq(v.length(), Suit.ACCEL, 0.01)

func test_without_assist_you_coast():
	var v := _run(Vector3(1, 2, 3), Vector3.ZERO, Vector3.ZERO, Basis.IDENTITY, false, 5.0)
	assert_almost_eq(v, Vector3(1, 2, 3), Vector3.ONE * 0.0001, "Newton")

## The ship is drifting at 3 m/s: the assist brings you to its speed, not to a
## standstill, so you hold station beside it.
func test_the_assist_holds_you_still_relative_to_your_ship():
	var ship := Vector3(3, 0, 0)
	var v := _run(Vector3(0, 0, 1), ship, Vector3.ZERO, Basis.IDENTITY, true, 3.0)
	assert_almost_eq(v, ship, Vector3.ONE * 0.001)

func test_the_assist_never_fights_your_thrust():
	var v := _run(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -1), Basis.IDENTITY, true, 1.0)
	assert_almost_eq(v.z, -Suit.ACCEL, 0.01)

func test_the_assist_caps_your_speed_relative_to_the_ship():
	var v := _run(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -1), Basis.IDENTITY, true, 10.0)
	assert_almost_eq(v.length(), Suit.ASSIST_CAP, 0.01)
	var free := _run(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -1), Basis.IDENTITY, false, 10.0)
	assert_gt(free.length(), Suit.ASSIST_CAP, "assist off, no cap")

func test_a_ship_accelerating_harder_than_the_suit_leaves_you():
	var v := Vector3.ZERO
	var ship := Vector3.ZERO
	for i in 120:
		ship += Vector3(0, 0, -5.0) * DT   # 5 m/s^2, twice what the suit can do
		v = Suit.step(v, ship, Vector3.ZERO, Basis.IDENTITY, true, DT)
	assert_gt((ship - v).length(), 4.0, "you fall behind")
