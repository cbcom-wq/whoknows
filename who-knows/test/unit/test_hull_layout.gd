extends GutTest

## Ship exterior spec §3.1: the skin over every occupied cell -- plates,
## chamfered convex edges, corner facets, and the faces of shaped blocks.

var _cat: BlockCatalog
var _grid: ShipGrid

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	_grid = ShipGrid.new()

func _put(coord: Vector3i, id: StringName, o := 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = o
	_grid.set_block(coord, i)

func _plan() -> HullLayout:
	return HullLayout.plan(_grid, _cat, null)

func _edges_along(l: HullLayout, axis_index: int) -> int:
	var n := 0
	for e in l.edges:
		var axis: Vector3i = e["axis"]
		if axis[axis_index] != 0:
			n += 1
	return n

func test_one_cube_has_six_plates_twelve_edges_eight_corners():
	_put(Vector3i.ZERO, &"hull")
	var l := _plan()
	assert_eq(l.plates.size(), 6)
	assert_eq(l.edges.size(), 12)
	assert_eq(l.corners.size(), 8)
	for p in l.plates:
		assert_almost_eq(p["lo"], Vector2(-0.6, -0.6), Vector2.ONE * 0.0001, "chamfered on every side")
		assert_almost_eq(p["hi"], Vector2(0.6, 0.6), Vector2.ONE * 0.0001)
	for e in l.edges:
		assert_eq(e["ends"], [&"corner", &"corner"])

func test_two_cubes_share_no_face_and_their_edges_run_through():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	var l := _plan()
	assert_eq(l.plates.size(), 10)
	assert_eq(l.edges.size(), 16)
	assert_eq(l.corners.size(), 8)
	var through := 0
	for e in l.edges:
		if e["ends"].has(&"through"):
			through += 1
	assert_eq(through, 8, "the four long edges, from both cubes")

func test_an_l_has_no_chamfer_in_its_concave_corner():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(0, 0, 1), &"hull")
	assert_eq(_edges_along(_plan(), 1), 5, "five convex vertical edges; the sixth corner is concave")

func test_a_walkable_cell_open_to_space_is_skinned():
	_put(Vector3i.ZERO, &"deck")
	assert_eq(_plan().plates.size(), 6)

func test_a_slope_hides_the_face_its_back_is_against():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(0, 0, -1), &"fairing_slope")
	var l := _plan()
	assert_false(l.skin[Vector3i.ZERO].has(Vector3i(0, 0, -1)))
	for e in l.edges:
		assert_false(e["a"] == Vector3i(0, 0, -1) or e["b"] == Vector3i(0, 0, -1), "no chamfer into the slope")
	assert_eq(l.facets.size(), 4, "the slope's back face is hidden against the cube")

func test_a_face_half_hidden_by_a_shaped_block_still_shows():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"fairing_half")
	var l := _plan()
	assert_true(l.skin[Vector3i.ZERO].has(Vector3i(1, 0, 0)),
		"a half block covers only half the cube's face: the rest must be drawn")

func test_an_edge_that_meets_an_unchamfered_neighbour_is_capped():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(0, 0, 1), &"hull")
	_put(Vector3i(1, 0, 1), &"hull")
	var l := _plan()
	var found := false
	for e in l.edges:
		if e["coord"] == Vector3i.ZERO and e["a"] == Vector3i(1, 0, 0) and e["b"] == Vector3i(0, 1, 0):
			found = true
			assert_eq(e["axis"], Vector3i(0, 0, 1))
			assert_eq(e["ends"], [&"corner", &"cap"])
	assert_true(found)

func test_an_airlock_alcove_is_left_to_the_alcove():
	_put(Vector3i(0, 0, 0), &"airlock")
	_put(Vector3i(0, 0, -1), &"deck")
	_put(Vector3i(1, 0, 0), &"hull")
	_put(Vector3i(-1, 0, 0), &"hull")
	var l := _plan()
	assert_eq(l.shape_at(Vector3i.ZERO), HullLayout.ALCOVE)
	assert_false(l.skin.has(Vector3i.ZERO))
	for e in l.edges:
		assert_ne(e["coord"], Vector3i.ZERO)
	assert_false(l.skin[Vector3i(0, 0, -1)].has(Vector3i(0, 0, 1)), "the deck's face on the alcove is inside")

func test_an_engine_gets_a_nozzle_on_its_exhaust_face():
	_put(Vector3i.ZERO, &"thruster")
	var l := _plan()
	assert_eq(l.nozzles.size(), 1)
	assert_eq(l.nozzles[0]["normal"], Vector3i(0, 0, 1), "a FORWARD thruster exhausts aft")
	assert_eq(l.nozzles[0]["kind"], &"thruster")

func test_inside_follows_the_shapes():
	_put(Vector3i.ZERO, &"fairing_slope")
	var l := _plan()
	assert_true(l.inside(Vector3(0, -0.5, 0.5)))
	assert_false(l.inside(Vector3(0, 0.5, -0.5)), "above the slope is open")
	assert_false(l.inside(Vector3(0, 0, 5)))

func test_the_same_grid_gives_the_same_skin():
	_put(Vector3i(0, 0, 0), &"hull")
	_put(Vector3i(1, 0, 0), &"fairing_slope", 12)
	_put(Vector3i(0, 1, 0), &"deck")
	assert_eq(str(_plan().plates), str(_plan().plates))
	assert_eq(str(_plan().edges), str(_plan().edges))
