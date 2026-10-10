extends GutTest

## The hose's tether (quantum energy spec §11.3): slack inside the line's
## length; at full length it removes outward velocity and pulls back at
## 1 m/s^2. Pure.

const LENGTH := 30.0
const DT := 1.0 / 60.0

func test_slack_inside_the_length_changes_nothing():
	var v := Tether.constrain(Vector3(10, 0, 0), Vector3(3, 1, -2), Vector3.ZERO, LENGTH, DT)
	assert_eq(v, Vector3(3, 1, -2))

func test_at_full_length_outward_velocity_is_removed():
	var v := Tether.constrain(Vector3(LENGTH, 0, 0), Vector3(2, 1, 0), Vector3.ZERO, LENGTH, DT)
	assert_almost_eq(v.x, -Tether.PULL * DT, 0.0001, "no outward speed, a little pull back")
	assert_almost_eq(v.y, 1.0, 0.0001, "sideways speed is left alone")

func test_inward_velocity_is_kept_and_pulled_on():
	var v := Tether.constrain(Vector3(LENGTH, 0, 0), Vector3(-3, 0, 0), Vector3.ZERO, LENGTH, DT)
	assert_almost_eq(v.x, -3.0 - Tether.PULL * DT, 0.0001)

func test_beyond_full_length_it_still_holds():
	var v := Tether.constrain(Vector3(0, 31, 0), Vector3(0, 5, 0), Vector3.ZERO, LENGTH, DT)
	assert_lte(v.y, 0.0)

func test_it_is_about_the_anchor_not_the_origin():
	var anchor := Vector3(100, -40, 7)
	var v := Tether.constrain(anchor + Vector3(0, 0, LENGTH), Vector3(0, 0, 4), anchor, LENGTH, DT)
	assert_lte(v.z, 0.0)

func test_thrusting_outward_holds_at_the_length():
	var pos := Vector3(LENGTH - 1.0, 0, 0)
	var vel := Vector3.ZERO
	for i in 600:
		vel += Vector3(2.5, 0, 0) * DT
		vel = Tether.constrain(pos, vel, Vector3.ZERO, LENGTH, DT)
		pos += vel * DT
	assert_lte(pos.x, LENGTH + 0.1, "held at the line's length, not carried past it")
