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

# --- the emergency cell's way home (quantum energy spec §9) --------------------

## Homes on `target` for `seconds` beside a ship drifting at `ship`, from `p`
## moving at `v`; the target drifts with the ship. Returns [position,
## velocity, target, the farthest from the target over the last `hold`
## seconds].
func _home(p: Vector3, v: Vector3, target: Vector3, ship: Vector3, seconds: float, hold := 0.0) -> Array:
	var worst := 0.0
	var steps := int(round(seconds / DT))
	for i in steps:
		v = Suit.home_step(v, ship, target - p, DT)
		p += v * DT
		target += ship * DT
		if i >= steps - int(round(hold / DT)):
			worst = maxf(worst, p.distance_to(target))
	return [p, v, target, worst]

func test_home_heads_for_the_hold_point_at_1_5_m_s_relative_to_the_ship():
	var ship := Vector3(3, 0, 0)
	var out := _home(Vector3.ZERO, ship, Vector3(0, 0, -30), ship, 4.0)
	var relative: Vector3 = out[1] - ship
	assert_almost_eq(relative.length(), 1.5, 0.001, "cruising home at 1.5 m/s")
	assert_almost_eq(relative.normalized(), Vector3(0, 0, -1), Vector3.ONE * 0.001, "straight for it")

func test_home_chases_its_speed_at_1_m_s2():
	var out := _home(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -30), Vector3.ZERO, 0.5)
	assert_almost_eq(out[1].length(), 0.5, 0.001)

func test_home_stops_at_the_point_and_holds_within_0_2_m():
	var ship := Vector3(3, 0, -1)
	var out := _home(Vector3(2, 1, 0), ship, Vector3(-12, 4, 9), ship, 40.0, 10.0)
	assert_lt(out[3], 0.2, "held within 0.2 m for the last 10 s")
	assert_almost_eq(out[1], ship, Vector3.ONE * 0.01, "at rest beside the ship")

func test_home_turns_you_round_if_you_were_flying_away():
	var out := _home(Vector3.ZERO, Vector3(0, 0, 6), Vector3(0, 0, -5), Vector3.ZERO, 40.0, 5.0)
	assert_lt(out[3], 0.2, "it brings you back and holds")

func test_with_nowhere_to_go_home_holds_station():
	var ship := Vector3(2, 0, 0)
	var v := Vector3(0, 0, 1)
	for i in 180:
		v = Suit.home_step(v, ship, Vector3.ZERO, DT)
	assert_almost_eq(v, ship, Vector3.ONE * 0.001)
