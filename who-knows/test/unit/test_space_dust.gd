extends GutTest

## Space dust (the system skeleton spec §9): flecks fixed in the universe,
## wrapping round a box about the focus, exact however far you go.

var _universe: Universe
var _dust: SpaceDust

func before_each():
	_universe = Universe.new()
	add_child_autofree(_universe)
	_dust = SpaceDust.new()
	add_child_autofree(_dust)

## Fleck `i`'s universe place, as the dust draws it for `focus`.
func _place(i: int, focus: UniversePoint) -> UniversePoint:
	_dust.place(_universe, focus)
	return _universe.to_universe(_dust.global_position + _dust.fleck(i))

func test_a_fleck_holds_still_as_you_pass():
	var focus := UniversePoint.at(1000, 2000, 3000)
	_universe.origin = UniversePoint.at(1000, 2000, 3000)
	var tried := 0
	for i in SpaceDust.COUNT:
		# Flecks well inside the box, which the move cannot wrap.
		_dust.rework()
		var a := _place(i, focus)
		if a.minus(focus).length() > 50.0:
			continue
		var b := _place(i, focus.plus(Vector3(23.0, -12.0, 15.5)))   # past REWORK_AFTER: worked out again
		assert_almost_eq(a.minus(b).length(), 0.0, 0.01, "fleck %d moved" % i)
		tried += 1
		if tried >= 5:
			break
	assert_eq(tried, 5)

func test_a_fleck_left_behind_wraps_to_the_far_side():
	# (Pure: offset() is what place() uses whenever it works flecks out.)
	var focus := UniversePoint.at(0, 0, 0)
	var rel := SpaceDust.offset(Vector3(10, 100, 100), focus)
	assert_almost_eq(rel.x, 10.0, 0.001)
	var on := SpaceDust.offset(Vector3(10, 100, 100), focus.plus(Vector3(120, 0, 0)))
	assert_almost_eq(on.x, 90.0, 0.001, "wrapped ahead")

func test_it_is_exact_a_billion_metres_out():
	var near := SpaceDust.offset(Vector3(37.25, 12.5, 150.75), UniversePoint.at(0, 0, 0).plus(Vector3(0.5, 0.25, 0.125)))
	var far := SpaceDust.offset(Vector3(37.25, 12.5, 150.75),
		UniversePoint.at(1000000000, -2000000000, 3000000000).plus(Vector3(0.5, 0.25, 0.125)))
	assert_almost_eq(near.distance_to(far), 0.0, 1e-4)

func test_a_shift_changes_nothing_you_see():
	var focus := UniversePoint.at(5000, 0, 0)
	_universe.origin = UniversePoint.at(5000, 0, 0)
	var before := _place(3, focus)
	_universe.shift(Vector3(2000, 0, -1000))
	var after := _place(3, focus)
	assert_almost_eq(before.minus(after).length(), 0.0, 0.01)
	assert_true(_dust.is_in_group(Universe.EXTERIOR_SPACE))

func test_flecks_shrink_to_nothing_at_the_box_edge():
	assert_eq(SpaceDust.edge_scale(Vector3.ZERO), 1.0)
	assert_eq(SpaceDust.edge_scale(Vector3(SpaceDust.BOX * 0.5, 0, 0)), 0.0)
	assert_between(SpaceDust.edge_scale(Vector3(SpaceDust.BOX * 0.5 - 10.0, 0, 0)), 0.4, 0.6)

func test_it_is_worked_out_again_only_after_you_have_moved_a_way():
	var focus := UniversePoint.at(0, 0, 0)
	_dust.place(_universe, focus)
	var at := _dust.global_position
	_dust.place(_universe, focus.plus(Vector3(SpaceDust.REWORK_AFTER * 0.5, 0, 0)))
	assert_eq(_dust.global_position, at, "not yet")
	_dust.place(_universe, focus.plus(Vector3(SpaceDust.REWORK_AFTER * 1.5, 0, 0)))
	assert_ne(_dust.global_position, at)

func test_density_sets_how_many_show():
	_dust.density = 0.5
	assert_eq(_dust.multimesh.visible_instance_count, SpaceDust.COUNT / 2)
	_dust.density = 3.0
	assert_eq(_dust.multimesh.visible_instance_count, SpaceDust.COUNT)
