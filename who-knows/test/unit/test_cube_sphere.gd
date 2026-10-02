extends GutTest

## The cube-sphere and its quadtree (Planetfall §6.4; the world scale spec
## §5.2): unit directions, a round trip back to the face, depths per radius,
## and children that tile their parent exactly.

func test_directions_are_unit_and_face_centres_are_the_axes():
	for f in CubeSphere.FACES:
		assert_true(CubeSphere.direction(f, 0.0, 0.0).is_equal_approx(CubeSphere.AXES[f][0]))
		for uv in [Vector2(-1, -1), Vector2(0.3, -0.7), Vector2(1, 1), Vector2(-0.99, 0.5)]:
			assert_almost_eq(CubeSphere.direction(f, uv.x, uv.y).length(), 1.0, 1e-6)

func test_a_direction_goes_back_to_its_face_and_place():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		var f := rng.randi_range(0, 5)
		var u := rng.randf_range(-0.98, 0.98)
		var v := rng.randf_range(-0.98, 0.98)
		var back := CubeSphere.face_uv(CubeSphere.direction(f, u, v))
		assert_eq(int(back.x), f)
		assert_almost_eq(back.y, u, 1e-4)
		assert_almost_eq(back.z, v, 1e-4)

func test_the_finest_quad_is_about_two_metres():
	assert_eq(CubeSphere.depth_for(60000.0), 12)
	assert_eq(CubeSphere.depth_for(15000.0), 10)
	assert_eq(CubeSphere.depth_for(4000.0), 8)
	for r in [4000.0, 15000.0, 37000.0, 60000.0]:
		var quad := CubeSphere.edge_m(r, CubeSphere.depth_for(r)) / CubeSphere.QUADS
		assert_between(quad, 1.0, CubeSphere.FINEST_QUAD)

func test_children_tile_their_parent_and_know_it():
	var key := Vector4i(3, 2, 1, 2)
	var rect := CubeSphere.node_rect(key)
	var area := 0.0
	for c in CubeSphere.children(key):
		assert_eq(CubeSphere.parent(c), key)
		assert_eq(c.y, 3)
		var r := CubeSphere.node_rect(c)
		assert_between(r.x, rect.x - 1e-9, rect.x + rect.z)
		assert_between(r.y, rect.y - 1e-9, rect.y + rect.z)
		area += r.z * r.z
	assert_almost_eq(area, rect.z * rect.z, 1e-12)

func test_a_node_s_centre_finds_the_node():
	for key in [Vector4i(0, 0, 0, 0), Vector4i(2, 3, 5, 1), Vector4i(5, 6, 63, 0), Vector4i(1, 4, 7, 15)]:
		var rect := CubeSphere.node_rect(key)
		var d := CubeSphere.direction(key.x, rect.x + rect.z * 0.5, rect.y + rect.z * 0.5)
		assert_eq(CubeSphere.key_for(d, key.y), key)

func test_a_node_s_bound_holds_its_corners_and_relief():
	var key := Vector4i(4, 3, 2, 6)
	var b := CubeSphere.node_bound(key, 20000.0, 400.0)
	var centre: Vector3 = b[0]
	var r: float = b[1]
	var rect := CubeSphere.node_rect(key)
	for k in 4:
		var corner := CubeSphere.direction(key.x, rect.x + rect.z * float(k & 1), rect.y + rect.z * float(k >> 1))
		assert_lte((corner * 20200.0).distance_to(centre), r + 0.01)
		assert_lte((corner * 19800.0).distance_to(centre), r + 0.01)
