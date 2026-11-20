extends GutTest

func _wadis() -> WorldRecipe:
	return SystemRecipe.from_seed(1337).body(&"p3").recipe

func test_the_same_seed_builds_the_same_plan_on_any_thread():
	var a := WorldPlan.build(_wadis())
	# A lambda captures locals by value, so the worker's plan comes back in a box.
	var box := [null]
	var id := WorkerThreadPool.add_task(func(): box[0] = WorldPlan.build(_wadis()))
	WorkerThreadPool.wait_for_task_completion(id)
	var b: WorldPlan = box[0]
	var oa := PackedFloat64Array(); oa.resize(WorldPlan.S_SIZE)
	var ob := oa.duplicate()
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for k in 2000:
		var d := _dir(rng)
		a.sample(d, oa); b.sample(d, ob)
		assert_eq(oa, ob)

func test_samples_are_continuous_across_every_face_edge():
	var p := _wadis().plan()
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	var across := PackedFloat64Array(); across.resize(WorldPlan.S_SIZE)
	for edge_dir in _face_edge_points(400):   # points on edges and the 8 corners
		var e: Vector3 = edge_dir[0]; var step: Vector3 = edge_dir[1]   # tangent across the edge
		p.sample((e + step * 1e-6).normalized(), out)
		p.sample((e - step * 1e-6).normalized(), across)
		assert_almost_eq(out[WorldPlan.S_BASE], across[WorldPlan.S_BASE], 0.1)

func test_building_wadis_takes_under_half_a_second():
	var t := Time.get_ticks_usec()
	WorldPlan.build(_wadis())
	assert_lt(Time.get_ticks_usec() - t, 500000)

func test_the_edge_points_cross_their_edges():
	var points := _face_edge_points(400)
	assert_gte(points.size(), 400)
	var corners := {}
	var distinct := {}
	for edge_dir in points:
		var e: Vector3 = edge_dir[0]; var step: Vector3 = edge_dir[1]
		distinct[Vector3i((e * 1e5).round())] = true
		assert_ne(CubeSphere.face_of((e + step * 1e-6).normalized()),
			CubeSphere.face_of((e - step * 1e-6).normalized()))
		var a := e.abs()
		if is_equal_approx(a.x, a.y) and is_equal_approx(a.y, a.z):
			corners[e.sign()] = true
	assert_eq(corners.size(), 8, "all eight cube corners")
	# Spread along each edge, not just its ends and middle: every point but the
	# corners (shared by three edges) is its own.
	var per := points.size() / 12
	assert_gt(distinct.size(), 20)
	assert_eq(distinct.size(), 12 * (per - 2) + 8, "points spread along every edge")

func test_open_ground_is_a_gentle_roll_of_dunes_and_plains():
	var p := _wadis().plan()
	assert_eq(p.sea_level, WorldPlan.SEA_LEVEL, "WADIS has a sea")
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var dunes := 0
	for k in 2000:
		var d := _dir(rng)
		p.sample(d, out)
		assert_between(out[WorldPlan.S_BASE], -WorldPlan.BASE_ROLL, WorldPlan.BASE_ROLL)
		assert_between(out[WorldPlan.S_DUNES], 0.0, 1.0)
		assert_eq(out[WorldPlan.S_SHORE], INF)
		assert_eq(out[WorldPlan.S_CANYON], INF)
		assert_eq(out[WorldPlan.S_KEEP], 0.0)
		var land := p.land_at(d)
		assert_eq(land, WorldPlan.Land.DUNES if out[WorldPlan.S_DUNES] >= 0.5 else WorldPlan.Land.PLAINS)
		if land == WorldPlan.Land.DUNES:
			dunes += 1
	assert_between(dunes, 400, 1600, "both dune seas and plains")

func test_a_corner_on_a_face_edge_is_one_corner():
	var m := PlanMap.new(2)
	var n := PlanMap.CELLS
	# Face 0's edge u = 1 is face 5's edge u = -1.
	m.set_corner(1, 0, n, 17, 3.5)
	assert_eq(m.corner(1, 5, 0, 17), 3.5)
	assert_eq(m.corner(0, 5, 0, 17), 0.0, "and no other field")
	# Every corner on a face's edge, grouped by its direction: one value set on
	# one copy is what every copy holds.
	var groups := {}
	for face in CubeSphere.FACES:
		for j in PlanMap.SIDE:
			for i in PlanMap.SIDE:
				if i % n == 0 or j % n == 0:
					var d := m.corner_dir(face, i, j)
					if not groups.has(d):
						groups[d] = []
						m.set_corner(0, face, i, j, groups.size())
					groups[d].append(Vector3i(face, i, j))
	assert_eq(groups.size(), 12 * (n - 1) + 8, "each edge's corners and the cube's, once")
	var threes := 0
	for d: Vector3 in groups:
		var copies: Array = groups[d]
		var first: Vector3i = copies[0]
		threes += 1 if copies.size() == 3 else 0
		for c: Vector3i in copies:
			assert_eq(m.corner(0, c.x, c.y, c.z), m.corner(0, first.x, first.y, first.z))
			assert_true(d.is_equal_approx(CubeSphere.direction(c.x, -1.0 + 2.0 * c.y / n, -1.0 + 2.0 * c.z / n)))
	assert_eq(threes, 8, "the cube's corners are shared by three faces")

func test_a_cell_is_the_quadtree_node_at_plan_depth():
	var m := PlanMap.new(1)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for k in 3000:
		var d := _dir(rng)
		assert_eq(m.cell_of(d), CubeSphere.key_for(d, PlanMap.PLAN_DEPTH))

func test_at_is_bilinear_in_the_cell():
	var m := PlanMap.new(1)
	m.set_corner(0, 3, 10, 20, 1.0)
	m.set_corner(0, 3, 11, 20, 2.0)
	m.set_corner(0, 3, 10, 21, 3.0)
	m.set_corner(0, 3, 11, 21, 4.0)
	var r := CubeSphere.node_rect(Vector4i(3, PlanMap.PLAN_DEPTH, 10, 20))
	var d := CubeSphere.direction(3, r.x + r.z * 0.25, r.y + r.z * 0.5)
	assert_almost_eq(m.at(0, d), 1.0 * 0.375 + 2.0 * 0.125 + 3.0 * 0.375 + 4.0 * 0.125, 1e-4)

func test_every_cell_has_four_neighbours_that_name_it_back():
	var m := PlanMap.new(1)
	var n := PlanMap.CELLS
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	var cells: Array[Vector4i] = []
	for face in CubeSphere.FACES:
		for k in n:
			cells.append_array([Vector4i(face, PlanMap.PLAN_DEPTH, k, 0), Vector4i(face, PlanMap.PLAN_DEPTH, k, n - 1),
				Vector4i(face, PlanMap.PLAN_DEPTH, 0, k), Vector4i(face, PlanMap.PLAN_DEPTH, n - 1, k)])
		for k in 50:
			cells.append(Vector4i(face, PlanMap.PLAN_DEPTH, rng.randi_range(0, n - 1), rng.randi_range(0, n - 1)))
	for c in cells:
		var near := m.neighbours(c)
		assert_eq(near.size(), 4)
		var centre := _centre(c)
		for o in near:
			assert_true(m.neighbours(o).has(c), "%s and %s" % [c, o])
			assert_almost_eq(centre.angle_to(_centre(o)), PI * 0.5 / n, 0.3 * PI * 0.5 / n)

func test_bounds_of_a_node_span_the_cells_under_it():
	var m := PlanMap.new(1)
	var cells := 6 * PlanMap.CELLS * PlanMap.CELLS
	var low := PackedFloat32Array(); low.resize(cells)
	var high := PackedFloat32Array(); high.resize(cells)
	var rng := RandomNumberGenerator.new(); rng.seed = 6
	for k in cells:
		low[k] = rng.randf_range(-100.0, 0.0)
		high[k] = low[k] + rng.randf_range(0.0, 100.0)
	m.set_bounds(low, high)
	var deep := Vector4i(4, 9, 300, 17)
	var cell := (4 * PlanMap.CELLS + (17 >> 3)) * PlanMap.CELLS + (300 >> 3)
	assert_eq(m.bounds_of(deep), Vector2(low[cell], high[cell]))
	for key: Vector4i in [Vector4i(2, 0, 0, 0), Vector4i(5, 3, 6, 1), Vector4i(1, 5, 31, 12)]:
		var want := Vector2(INF, -INF)
		var span := 1 << (PlanMap.PLAN_DEPTH - key.y)
		for y in range(key.w * span, (key.w + 1) * span):
			for x in range(key.z * span, (key.z + 1) * span):
				var k := (key.x * PlanMap.CELLS + y) * PlanMap.CELLS + x
				want = Vector2(minf(want.x, low[k]), maxf(want.y, high[k]))
		assert_eq(m.bounds_of(key), want)

func test_the_plan_bounds_hold_its_base():
	var p := _wadis().plan()
	var rng := RandomNumberGenerator.new(); rng.seed = 8
	for k in 2000:
		var d := _dir(rng)
		var b := p.bounds_of(CubeSphere.key_for(d, 8))
		var h := p.map.at(WorldPlan.S_BASE, d)
		assert_between(h, b.x - 1e-3, b.y + 1e-3)
		var top := p.bounds_of(CubeSphere.key_for(d, 2))
		assert_true(top.x <= b.x and top.y >= b.y)

## A random unit direction, even over the sphere.
func _dir(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(r * cos(a), r * sin(a), z)

## About `n` points spread along the cube's 12 edges, its 8 corners among them,
## each as [the point, a unit tangent there that crosses the edge].
func _face_edge_points(n: int) -> Array:
	var out := []
	var per := ceili(n / 12.0)
	for a in CubeSphere.FACES:
		for b in range(a + 1, CubeSphere.FACES):
			var na: Vector3 = CubeSphere.AXES[a][0]
			var nb: Vector3 = CubeSphere.AXES[b][0]
			if na.dot(nb) != 0.0:
				continue   # opposite faces share no edge
			var along := na.cross(nb)
			var eu: Vector3 = CubeSphere.AXES[a][1]
			var ev: Vector3 = CubeSphere.AXES[a][2]
			for k in per:
				var p := na + nb + along * (-1.0 + 2.0 * float(k) / float(per - 1))
				var e := CubeSphere.direction(a, p.dot(eu), p.dot(ev))
				var across := (nb - na) - e * e.dot(nb - na)
				out.append([e, across.normalized()])
	return out

func _centre(cell: Vector4i) -> Vector3:
	var r := CubeSphere.node_rect(cell)
	return CubeSphere.direction(cell.x, r.x + r.z * 0.5, r.y + r.z * 0.5)
