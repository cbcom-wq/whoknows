extends GutTest

func test_identity_orientation_points_forward():
	var b := BlockOrientation.basis_for(0)
	assert_almost_eq(b * Vector3(0, 0, -1), Vector3.FORWARD, Vector3.ONE * 0.001)

func test_there_are_twenty_four_orientations():
	assert_eq(BlockOrientation.COUNT, 24, "24 axis-aligned rotations of a cube")

func test_all_orientations_are_distinct():
	var seen: Array[String] = []
	for o in range(BlockOrientation.COUNT):
		var b := BlockOrientation.basis_for(o)
		var key := "%.2f,%.2f,%.2f|%.2f,%.2f,%.2f" % [
			b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z
		]
		assert_false(seen.has(key), "orientation %d duplicates another" % o)
		seen.append(key)

func test_all_orientations_are_right_handed_and_axis_aligned():
	for o in range(BlockOrientation.COUNT):
		var b := BlockOrientation.basis_for(o)
		assert_almost_eq(b.determinant(), 1.0, 0.001, "orientation %d is not a rotation" % o)
		for axis in [b.x, b.y, b.z]:
			var longest := maxf(absf(axis.x), maxf(absf(axis.y), absf(axis.z)))
			assert_almost_eq(longest, 1.0, 0.001, "orientation %d is not axis-aligned" % o)

func test_four_rolls_return_to_start():
	var start := BlockOrientation.basis_for(0)
	var rolled := BlockOrientation.basis_for(3)  # same forward, three rolls
	assert_almost_eq((rolled * Vector3(0, 0, -1)), (start * Vector3(0, 0, -1)), Vector3.ONE * 0.001)
