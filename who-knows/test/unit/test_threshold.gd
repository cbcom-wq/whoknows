extends GutTest

## The threshold's maths (docs/superpowers/specs/2026-09-24-airlock-design.md
## §7), headless: carrying a pose and a velocity between interior space and
## the world, both ways.

## Interior space sits 5 km down, where single-precision floats resolve about
## half a millimetre: the crossing is held to a millimetre, as the spec asks.
const EPS := 0.001

var _interior := Transform3D(Basis.IDENTITY, Vector3(0, -5000, 0))
var _hull := Transform3D(Basis(Vector3(0.3, 1, -0.2).normalized(), 0.7), Vector3(120, 40, -60))

func _pose(at: Vector3, yaw := 0.4, pitch := -0.2) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), at)

func test_a_pose_goes_out_and_comes_back_exactly():
	var inside := _pose(_interior * Vector3(0.2, -0.95, 7.03))
	var world := Threshold.to_world(_interior, _hull, inside, 0.0)
	var back := Threshold.to_interior(_interior, _hull, world, 0.0)
	assert_true(back.is_equal_approx(inside), "%s vs %s" % [back, inside])

func test_the_world_pose_is_the_same_place_on_the_hull():
	var local := Vector3(0.2, -0.95, 7.03)
	var world := Threshold.to_world(_interior, _hull, _pose(_interior * local), 0.0)
	assert_almost_eq(world.origin, _hull * local, Vector3.ONE * EPS)

func test_upper_storeys_take_off_their_offset():
	var offset := InteriorBuilder.storey_offset(1)
	var interior_local := Vector3(0, InteriorBuilder.floor_y(Vector3i(0, 1, 0)), 3)
	var world := Threshold.to_world(_interior, _hull, _pose(_interior * interior_local), offset)
	var hull_floor := ShipGrid.cell_center(Vector3i(0, 1, 0)).y - ShipGrid.CELL_SIZE * 0.5 + InteriorBuilder.FLOOR_THICKNESS * 0.5
	assert_almost_eq((_hull.affine_inverse() * world.origin).y, hull_floor, EPS, "the hull's floor, not the taller interior's")
	var back := Threshold.to_interior(_interior, _hull, world, offset)
	assert_almost_eq(back.origin, _interior * interior_local, Vector3.ONE * EPS)

func test_going_out_you_keep_the_hulls_motion_and_your_own():
	var hull_point := Vector3(3, 0, -12)
	var step := Vector3(0, 0, 1.5)   # walking out along interior +z
	var v := Threshold.carry_velocity_out(hull_point, _hull.basis, step)
	assert_almost_eq(v, hull_point + _hull.basis * step, Vector3.ONE * EPS)

func test_coming_in_you_keep_your_speed_relative_to_the_ship_up_to_a_cap():
	var hull_point := Vector3(3, 0, -12)
	var drift := _hull.basis * Vector3(0, 0, -1.2)
	var v := Threshold.carry_velocity_in(hull_point + drift, hull_point, _hull.basis)
	assert_almost_eq(v, Vector3(0, 0, -1.2), Vector3.ONE * EPS)
	var fast := Threshold.carry_velocity_in(hull_point + _hull.basis * Vector3(0, 0, -20), hull_point, _hull.basis)
	assert_almost_eq(fast.length(), Threshold.ENTRY_SPEED, EPS, "capped, so a fast entry does not slam you")

## A spinning hull's point velocity includes w x r about its centre of mass.
func test_the_hulls_velocity_at_a_point_includes_its_spin():
	var v := Threshold.point_velocity(Vector3(1, 0, 0), Vector3(0, 2, 0), Vector3(10, 0, 0), Vector3(10, 0, 3))
	assert_almost_eq(v, Vector3(1, 0, 0) + Vector3(0, 2, 0).cross(Vector3(0, 0, 3)), Vector3.ONE * EPS)

## Floating in upside down, you land upright looking the same way.
func test_coming_in_upside_down_you_land_upright_facing_the_same_way():
	var view := Basis(Vector3.FORWARD, PI) * Basis(Vector3.UP, 0.8) * Basis(Vector3.RIGHT, 0.3)
	var upright := Threshold.upright(view)
	var body: Basis = upright["body"]
	assert_almost_eq(body.y, Vector3.UP, Vector3.ONE * EPS, "standing up")
	var flat_view := -view.z
	flat_view.y = 0.0
	assert_almost_eq(-body.z, flat_view.normalized(), Vector3.ONE * 0.001, "facing where you looked")
	var pitch: float = upright["pitch"]
	assert_almost_eq(pitch, asin(-view.z.y), 0.001, "looking up or down as much as before")
	var righting: Quaternion = upright["righting"]
	var target := body * Basis(Vector3.RIGHT, pitch)
	assert_true((Basis(target.get_rotation_quaternion() * righting)).is_equal_approx(view.orthonormalized()),
		"the camera starts exactly where it was, and rights itself from there")

func test_the_crossing_has_a_little_give():
	assert_false(Threshold.crossed_out(-0.01))
	assert_true(Threshold.crossed_out(-0.03))
	assert_false(Threshold.crossed_in(0.01))
	assert_true(Threshold.crossed_in(0.03))
