extends GutTest

## Ship exterior spec §4: the shapes a hull block can have, block-local with
## the block facing FORWARD, a cell spanning -1..1 m.

const ALL := [HullShapes.CUBE, HullShapes.SLOPE, HullShapes.SLOPE_LONG_LOW, HullShapes.SLOPE_LONG_HIGH,
	HullShapes.CORNER_OUT, HullShapes.CORNER_IN, HullShapes.HALF]

func test_blocks_that_are_not_listed_are_cubes():
	assert_eq(HullShapes.shape_of(&"hull"), HullShapes.CUBE)
	assert_eq(HullShapes.shape_of(&"deck"), HullShapes.CUBE)
	assert_eq(HullShapes.shape_of(&"thruster"), HullShapes.CUBE)
	assert_eq(HullShapes.shape_of(&"hull_wedge"), HullShapes.SLOPE)
	assert_eq(HullShapes.shape_of(&"canopy"), HullShapes.SLOPE)
	assert_eq(HullShapes.shape_of(&"fairing_half"), HullShapes.HALF)

## hull_wedge's own mesh is the wedge every slope must match: a full bottom
## rising to a full back face (+z), so its slope faces up and toward the bow.
func test_the_slope_is_the_old_wedge():
	var mesh: ArrayMesh = load("res://data/blocks/meshes/hull_wedge.tres")
	var want := {}
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		want[v.snapped(Vector3.ONE * 0.01)] = true
	var got := {}
	for p in HullShapes.points(HullShapes.SLOPE):
		got[p] = true
	assert_eq(got.size(), want.size())
	for p in want:
		assert_true(got.has(p), "the slope has the wedge's point %s" % p)

func test_every_face_normal_points_out_of_its_solid():
	for shape in ALL:
		for face in HullShapes.faces(shape):
			var mid := Vector3.ZERO
			for p: Vector3 in face["points"]:
				mid += p
			mid /= face["points"].size()
			var n: Vector3 = face["normal"]
			assert_almost_eq(n.length(), 1.0, 0.0001)
			assert_false(HullShapes.contains(shape, mid + n * 0.05), "%s: a normal points inward" % shape)
			assert_true(HullShapes.contains(shape, mid - n * 0.05), "%s: just inside a face is solid" % shape)

func _full_sides(shape: StringName) -> Array:
	var out := []
	for face in HullShapes.faces(shape):
		if face["full"]:
			out.append(face["side"])
	out.sort()
	return out

func test_which_faces_fill_their_cell_face():
	assert_eq(_full_sides(HullShapes.CUBE).size(), 6)
	assert_eq(_full_sides(HullShapes.SLOPE), [Vector3i(0, -1, 0), Vector3i(0, 0, 1)])
	assert_eq(_full_sides(HullShapes.SLOPE_LONG_LOW), [Vector3i(0, -1, 0)])
	assert_eq(_full_sides(HullShapes.SLOPE_LONG_HIGH), [Vector3i(0, -1, 0), Vector3i(0, 0, 1)])
	assert_eq(_full_sides(HullShapes.CORNER_OUT), [Vector3i(0, -1, 0)])
	assert_eq(_full_sides(HullShapes.CORNER_IN), [Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)])
	assert_eq(_full_sides(HullShapes.HALF), [Vector3i(0, -1, 0)])

func test_covers_turns_with_the_block():
	assert_true(HullShapes.covers(HullShapes.CUBE, 0, Vector3i.UP))
	assert_true(HullShapes.covers(HullShapes.SLOPE, 0, Vector3i(0, 0, 1)), "its back is full")
	assert_false(HullShapes.covers(HullShapes.SLOPE, 0, Vector3i(0, 0, -1)), "its front is an edge")
	assert_true(HullShapes.covers(HullShapes.SLOPE, 4, Vector3i(0, 0, -1)), "facing aft, its back is to the bow")
	assert_true(HullShapes.covers(HullShapes.HALF, 2, Vector3i.UP), "turned over, it fills the cell's top")
	assert_false(HullShapes.covers(HullShapes.HALF, 2, Vector3i.DOWN))

func test_the_inner_corner_is_two_slopes():
	assert_eq(HullShapes.collider_parts(HullShapes.CORNER_IN).size(), 2)
	assert_eq(HullShapes.collider_parts(HullShapes.SLOPE).size(), 1)
	assert_true(HullShapes.contains(HullShapes.CORNER_IN, Vector3(0.9, 0.8, -0.9)), "under the slope rising to +x")
	assert_true(HullShapes.contains(HullShapes.CORNER_IN, Vector3(-0.9, 0.8, 0.9)), "under the slope rising to +z")
	assert_false(HullShapes.contains(HullShapes.CORNER_IN, Vector3(-0.9, 0.8, -0.9)), "the valley between them")
	for part in HullShapes.collider_parts(HullShapes.CORNER_IN):
		for p in part:
			assert_true(HullShapes.contains(HullShapes.CORNER_IN, p), "every collider point is in the solid")
