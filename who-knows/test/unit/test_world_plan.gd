extends GutTest

## Open ground is read this far from any shore: past the sea, its beach and
## every cell that reaches the beach.
const AWAY_FROM_SEA := 2.0 * WorldPlan.PUDDLE_FROM

var _wadis_plan: WorldPlan

func _wadis() -> WorldRecipe:
	return SystemRecipe.from_seed(1337).body(&"p3").recipe

func test_wadis_has_one_sea_of_its_share():
	var p := _wadis().plan()
	assert_eq(p.shapes.seas.size(), 1)
	assert_eq(_components(p, WorldPlan.Land.SEA), 1)
	var under := _share(func(d): return _ground(d) < p.sea_level, 20000)
	assert_between(under, 0.12, 0.18)

func test_the_sea_is_in_view_from_wadoo():
	var p := _wadis().plan()
	var shore := p.nearest_shore_m(SystemDesign.dir_of(-2.16, -171.97))
	assert_between(shore, 20000.0, 40000.0)

func test_a_desert_with_no_sea_has_no_sea_level():
	var r := _desert_with(func(d: PlanDials): return d.sea == 0.0)
	assert_eq(r.plan().sea_level, -INF)

func test_a_desert_with_no_sea_has_no_shore():
	var p := _desert_with(func(d: PlanDials): return d.sea == 0.0).plan()
	assert_eq(p.shapes.seas.size(), 0)
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var wet := 0
	for k in 500:
		var d := _dir(rng)
		if p.nearest_shore_m(d) != INF or p.land_at(d) == WorldPlan.Land.SEA:
			wet += 1
	assert_eq(wet, 0, "no shore and no sea anywhere")

func test_two_seas_grow_apart_to_their_share():
	var p := _desert_with(func(d: PlanDials): return d.sea >= 0.1 and d.seas == 2).plan()
	assert_eq(p.shapes.seas.size(), 2)
	assert_eq(_components(p, WorldPlan.Land.SEA), 2)
	var under := _share(func(d): return p.map.at(WorldPlan.S_BASE, d) < p.sea_level, 20000)
	assert_almost_eq(under, p.dials.sea, 0.03)

func test_the_shore_is_the_great_circle_to_the_seas_outline():
	var p := _wadis().plan()
	var radius := _wadis().radius_m
	var sea := _sea_cells(p)
	var outline := _outline(p, sea)
	assert_gt(outline.size(), 100)
	var rng := RandomNumberGenerator.new(); rng.seed = 12
	# At the map's corners, where the front ran.
	var worst := 0.0
	for k in 300:
		var face := rng.randi_range(0, CubeSphere.FACES - 1)
		var i := rng.randi_range(0, PlanMap.CELLS)
		var j := rng.randi_range(0, PlanMap.CELLS)
		var near := _nearest(p.map.corner_dir(face, i, j), outline) * radius
		var got := p.map.corner(WorldPlan.S_SHORE, face, i, j)
		worst = maxf(worst, absf(absf(got) - near) - 0.01 * near)
	assert_lt(worst, 100.0, "a corner within 100 m and 1% of the nearest outline corner")
	# Anywhere, read between the corners: within a cell of it, and on the
	# right side of the water.
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	worst = 0.0
	var wrong_side := 0
	for k in 300:
		var d := _dir(rng)
		var near := _nearest(d, outline) * radius
		var got := p.nearest_shore_m(d)
		worst = maxf(worst, absf(absf(got) - near))
		if near > edge and (got < 0.0) != sea.has(p.map.cell_of(d)):
			wrong_side += 1
	assert_lt(worst, edge, "within a cell of the nearest outline corner")
	assert_eq(wrong_side, 0, "negative in the sea's cells, positive out of them")

func test_no_sea_or_land_is_one_cell_thin():
	# A corner-held field can't show a one-cell feature: a sea cell whose
	# corners are all on the outline is water with no depth, and a land cell
	# with three sides at sea is a notch or spit that reads as sea.
	var plans: Array[WorldPlan] = [_wadis().plan()]
	for s in 200:
		var r := WorldRecipe.from_seed(s)
		if r.is_desert() and PlanDials.roll(r.seed, r.radius_m).sea > 0.0:
			plans.append(r.plan())
			if plans.size() == 4:
				break
	assert_eq(plans.size(), 4)
	for p in plans:
		var sea := _sea_cells(p)
		var outline := {}
		for d in _outline(p, sea):
			outline[d] = true
		var thin_sea := 0
		var sea_sided := {}
		for c: Vector4i in sea:
			var on := 0
			for corner in 4:
				if outline.has(p.map.corner_dir(c.x, c.z + (corner & 1), c.w + (corner >> 1))):
					on += 1
			if on == 4:
				thin_sea += 1
			for o in p.map.neighbours(c):
				if not sea.has(o) and p.map.neighbours(o).filter(func(n): return sea.has(n)).size() >= 3:
					sea_sided[o] = true
		assert_gt(sea.size(), 0)
		assert_eq(thin_sea, 0, "no sea cell with all four corners on the outline")
		assert_eq(sea_sided.size(), 0, "no land cell with three or more sea neighbours")

func test_the_seabed_falls_from_the_shore_through_the_shelf():
	var p := _wadis().plan()
	var m := p.map
	var bad := {}
	var deep := 0
	for face in CubeSphere.FACES:
		for j in PlanMap.SIDE:
			for i in PlanMap.SIDE:
				var s := m.corner(WorldPlan.S_SHORE, face, i, j)
				var h := m.corner(WorldPlan.S_BASE, face, i, j)
				if s == 0.0 and h != p.sea_level:
					bad["the water's edge is at sea level"] = h
				if s < 0.0 and (h >= p.sea_level or h < p.sea_level - WorldPlan.SEA_DEEP):
					bad["the seabed is under the water, over the deep floor"] = h
				if s < 0.0 and s >= -WorldPlan.SHELF_WIDTH and h < p.sea_level - WorldPlan.SHELF_DEPTH:
					bad["the shelf is shallow"] = h
				if s <= -WorldPlan.SHELF_WIDTH - WorldPlan.SLOPE_WIDTH:
					deep += 1
					if h != p.sea_level - WorldPlan.SEA_DEEP:
						bad["past the slope lies the deep floor"] = h
				if s > 0.0 and h <= p.sea_level:
					bad["land is over the water"] = h
				if s >= WorldPlan.PUDDLE_FROM and h < p.sea_level + WorldPlan.LAND_ABOVE:
					bad["past the beach, land stands LAND_ABOVE over the water"] = h
	assert_eq(bad, {})
	assert_gt(deep, 100, "a deep floor")

func test_a_sea_keeps_off_a_kept_disc():
	var r := _desert_with(func(d: PlanDials): return d.sea >= 0.1)
	var first := WorldPlan.build(r)
	var here: Vector3 = first.shapes.seas[0].centre
	r.keeps.append({"place": &"here", "dir": here, "radius": 2000.0, "blend": 1500.0})
	var p := WorldPlan.build(r)
	assert_eq(p.shapes.seas.size(), first.shapes.seas.size())
	assert_gte(p.nearest_shore_m(here), 3500.0)
	var nearest := INF
	for sea: Dictionary in p.shapes.seas:
		for c: int in sea.cells:
			var key := PlanShapes.cell_key(c)
			for corner in 4:
				var d := p.map.corner_dir(key.x, key.z + (corner & 1), key.w + (corner >> 1))
				nearest = minf(nearest, d.angle_to(here) * r.radius_m)
	assert_gte(nearest, 3500.0, "no sea cell within the disc's radius and blend")

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
	# Its canyons too, which few of those fall in: the shapes, and the samples
	# down every canyon's floor.
	assert_eq(a.shapes.canyons.size(), b.shapes.canyons.size())
	var floors := 0
	for i in mini(a.shapes.canyons.size(), b.shapes.canyons.size()):
		var ca: Dictionary = a.shapes.canyons[i]
		var cb: Dictionary = b.shapes.canyons[i]
		for key in ["path", "floor", "half_floor", "rim", "mouth", "joins"]:
			assert_eq(ca.get(key), cb.get(key), "canyon %d's %s" % [i, key])
		for d: Vector3 in ca.path:
			a.sample(d, oa); b.sample(d, ob)
			assert_lte(oa[WorldPlan.S_CANYON], 1.0, "a point of a canyon's path is on its floor")
			assert_eq(oa, ob)
			floors += 1
	assert_gt(floors, 300)

func test_samples_are_continuous_across_every_face_edge():
	var p := _wadis().plan()
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	var across := PackedFloat64Array(); across.resize(WorldPlan.S_SIZE)
	for edge_dir in _face_edge_points(400):   # points on edges and the 8 corners
		var e: Vector3 = edge_dir[0]; var step: Vector3 = edge_dir[1]   # tangent across the edge
		p.sample((e + step * 1e-6).normalized(), out)
		p.sample((e - step * 1e-6).normalized(), across)
		assert_almost_eq(out[WorldPlan.S_BASE], across[WorldPlan.S_BASE], 0.1)

func test_building_wadis_takes_well_under_a_second():
	# Spec §5.1: well under a second, and never a hitch, since the first build
	# moves to a worker at load. 800 ms, raised from 500 when the canyons came.
	var t := Time.get_ticks_usec()
	WorldPlan.build(_wadis())
	assert_lt(Time.get_ticks_usec() - t, 800000)

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
		if out[WorldPlan.S_SHORE] < AWAY_FROM_SEA or out[WorldPlan.S_MOUNTAIN] > 0.0 or out[WorldPlan.S_PLATEAU] > 0.0:
			continue
		assert_between(out[WorldPlan.S_BASE], -WorldPlan.BASE_ROLL, WorldPlan.BASE_ROLL)
		assert_between(out[WorldPlan.S_DUNES], 0.0, 1.0)
		assert_eq(out[WorldPlan.S_KEEP], 0.0)
		var land := p.land_at(d)
		assert_eq(land, WorldPlan.Land.DUNES if out[WorldPlan.S_DUNES] >= 0.5 else WorldPlan.Land.PLAINS)
		if land == WorldPlan.Land.DUNES:
			dunes += 1
	assert_between(dunes, 400, 1600, "both dune seas and plains")

func test_plateaus_no_longer_all_stand_at_one_height():
	var tops := {}
	for r in _wadis().plan().shapes.plateaus:
		assert_between(r.top, 100.0, 400.0)
		tops[snappedf(r.top, 10.0)] = true
	assert_gt(tops.size(), 1)

func test_dunes_and_plains_keep_at_least_half_the_world():
	var p := _wadis().plan()
	var open := _share(func(d): var l := p.land_at(d); return l == WorldPlan.Land.DUNES or l == WorldPlan.Land.PLAINS, 20000)
	assert_gt(open, 0.5)
	assert_between(_share(func(d): return p.land_at(d) == WorldPlan.Land.PLATEAU, 20000), 0.15, 0.25)

func test_plateaus_stand_on_their_tops_and_keep_off_ranges_and_keeps():
	var r := _wadis()
	var p := r.plan()
	var m := p.map
	var lifted := 0
	for face in CubeSphere.FACES:
		for j in PlanMap.SIDE:
			for i in PlanMap.SIDE:
				var w := m.corner(WorldPlan.S_PLATEAU, face, i, j)
				assert_between(w, 0.0, 1.0)
				if w <= 0.0:
					continue
				assert_eq(m.corner(WorldPlan.S_MOUNTAIN, face, i, j), 0.0, "no plateau on a range's flank")
				assert_gt(m.corner(WorldPlan.S_SHORE, face, i, j), 0.0, "no plateau at sea")
				var top := m.corner(WorldPlan.S_PLATEAU_TOP, face, i, j)
				assert_between(top, 100.0, 400.0)
				if w == 1.0:
					lifted += 1
					assert_almost_eq(m.corner(WorldPlan.S_BASE, face, i, j), top, 0.01)
				var d := m.corner_dir(face, i, j)
				for keep: Dictionary in r.keeps:
					assert_gt(d.angle_to(keep.dir) * r.radius_m, keep.radius + keep.blend)
	assert_gt(lifted, 100)
	assert_gt(p.shapes.plateaus.size(), 1)

func test_wadis_has_three_ranges_to_two_km():
	var p := _wadis().plan()
	assert_eq(p.shapes.ranges.size(), 3)
	var top := 0.0
	for r in p.shapes.ranges:
		top = maxf(top, Array(r.height).max())
	assert_between(top, 1800.0, 2000.0)

func test_a_range_stands_on_wadoos_skyline_but_not_in_its_disc():
	var p := _wadis().plan()
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	var nearest := INF
	for r in p.shapes.ranges:
		var spine_m := INF
		for d: Vector3 in r.spine:
			spine_m = minf(spine_m, d.angle_to(wadoo) * _wadis().radius_m)
		assert_gte(spine_m, 3500.0 + r.half_width)   # its flanks stay out of keep + blend
		nearest = minf(nearest, spine_m)
	assert_lte(nearest, 15000.0)

func test_some_range_reaches_the_coast():
	var p := _wadis().plan()
	assert_true(p.shapes.ranges.any(func(r):
		return absf(p.nearest_shore_m(r.spine[0])) < 2000.0 or absf(p.nearest_shore_m(r.spine[-1])) < 2000.0))

func test_ranges_raise_their_flanks_and_never_the_sea():
	var p := _wadis().plan()
	var m := p.map
	var bad := {}
	for face in CubeSphere.FACES:
		for j in PlanMap.SIDE:
			for i in PlanMap.SIDE:
				var w := m.corner(WorldPlan.S_MOUNTAIN, face, i, j)
				if w < 0.0 or w > 1.0:
					bad["a weight is 0 to 1"] = w
				if m.corner(WorldPlan.S_SHORE, face, i, j) <= 0.0 and w != 0.0:
					bad["no weight at sea or at the water's edge"] = w
				if w > 0.0 and m.corner(WorldPlan.S_RIDGE, face, i, j) >= WorldPlan.RANGE_HALF_WIDTH.y:
					bad["weight only within a half-width of a spine"] = w
	assert_eq(bad, {})
	var edge := CubeSphere.edge_m(_wadis().radius_m, PlanMap.PLAN_DEPTH)
	var high := 0
	for r: Dictionary in p.shapes.ranges:
		for k in r.spine.size():
			var d: Vector3 = r.spine[k]
			if p.nearest_shore_m(d) > 2.0 * edge:
				assert_gt(m.at(WorldPlan.S_BASE, d), 0.2 * r.height[k], "the base stands high on the spine")
				high += 1
	assert_gt(high, 100)
	assert_between(_share(func(d): return m.at(WorldPlan.S_MOUNTAIN, d) > 0.0, 20000), 0.06, 0.12,
		"the flanks cover about the mountains dial's share")
	assert_gt(_share(func(d): return p.land_at(d) == WorldPlan.Land.MOUNTAINS, 20000), 0.02)

func test_ridge_m_is_the_way_to_the_nearest_spine():
	var p := _wadis().plan()
	var radius := _wadis().radius_m
	var rng := RandomNumberGenerator.new(); rng.seed = 14
	var flanks := 0
	for i in p.shapes.ranges.size():
		var r: Dictionary = p.shapes.ranges[i]
		var spine: PackedVector3Array = r.spine
		for k in 200:
			# Within the range's half-width of one of its spine's points.
			var at := spine[rng.randi_range(0, spine.size() - 1)]
			var d := _off(at, rng.randf() * r.half_width / radius, rng)
			var cell := p.map.cell_of(d)
			assert_true(p.shapes.near(cell).has(PlanShapes.RANGE * PlanShapes.SHAPES + i), "near names the range")
			var want := _nearest_spine(p, d)
			if want.x * radius < want.z:
				var got := p.shapes.ridge_m(d, cell)
				assert_almost_eq(got.x, want.x * radius, 0.5)
				assert_almost_eq(got.y, want.y, 0.5)
				flanks += 1
	assert_gt(flanks, 400)
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	var far := 0
	for k in 1000:
		var d := _dir(rng)
		if _nearest_spine(p, d).x * radius > WorldPlan.RANGE_HALF_WIDTH.y + 2.0 * edge:
			assert_eq(p.shapes.ridge_m(d, p.map.cell_of(d)), Vector2(INF, 0.0))
			far += 1
	assert_gt(far, 500)

func test_every_canyon_reaches_the_sea_or_a_basin_and_never_climbs():
	var p := _wadis().plan()
	assert_eq(p.shapes.canyons.filter(func(c): return not c.has("joins")).size(), 4)
	for c in p.shapes.canyons:
		var f: PackedFloat32Array = c.floor
		for i in range(1, f.size()):
			assert_true(f[i] <= f[i - 1] + 1e-3, "a canyon's floor climbs toward its mouth")
		assert_true(c.mouth == &"beach" or c.mouth == &"basin" or c.has("joins"))

func test_a_canyon_ends_on_a_beach():
	assert_true(_wadis().plan().shapes.canyons.any(func(c): return c.mouth == &"beach"))

func test_every_canyon_floor_takes_the_starter():
	for c in _wadis().plan().shapes.canyons:
		assert_gte(Array(c.half_floor).min() * 2.0, 150.0)

func test_canyon_floors_stay_over_the_sea_until_their_mouth():
	var p := _wadis().plan()
	var bad := {}
	for c: Dictionary in p.shapes.canyons:
		var path: PackedVector3Array = c.path
		var f: PackedFloat32Array = c.floor
		var n := path.size()
		for i in n:
			var w := Vector2(c.half_floor[i] * 2.0, c.rim[i])
			if w.x < WorldPlan.CANYON_FLOOR_WIDTH.x - 1e-3 or w.x > WorldPlan.CANYON_FLOOR_WIDTH.y + 1e-3:
				bad["the floor's width is within CANYON_FLOOR_WIDTH"] = w.x
			if w.y <= 0.0:
				bad["the walls stand over the floor"] = w.y
			var mouth: bool = i == n - 1 and c.mouth == &"beach"
			if not mouth and f[i] < p.sea_level + WorldPlan.CANYON_LAND_FLOOR - 1e-3:
				bad["over the sea until the mouth"] = f[i]
			if not mouth and p.nearest_shore_m(path[i]) <= 0.0:
				bad["on land until the mouth"] = i
		if c.mouth == &"beach":
			assert_lte(p.nearest_shore_m(path[-1]), 0.0, "a beach's mouth is at the water")
			assert_almost_eq(f[-1], p.sea_level, 1e-3, "and its floor at sea level")
	assert_eq(bad, {})

func test_some_canyon_opens_on_open_ground_by_the_sea():
	# A beach, not a cliff: no range's flank and no plateau at its mouth.
	var p := _wadis().plan()
	assert_true(p.shapes.canyons.any(func(c): return c.mouth == &"beach" \
			and p.map.at(WorldPlan.S_MOUNTAIN, c.path[-2]) == 0.0 and p.map.at(WorldPlan.S_PLATEAU, c.path[-2]) == 0.0))

func test_with_no_canyon_on_a_beach_the_nearest_is_rerouted_to_one():
	# WADIS's first draw opens on its beaches, so take those canyons away: the
	# reroute must then bring one of the rest to a beach, in its place.
	var r := _wadis()
	var p := WorldPlan.build(r)
	var rest := p.shapes.canyons.filter(func(c): return not c.has("joins") and not p._on_beach(c))
	assert_gt(rest.size(), 0)
	p.shapes.canyons.assign(rest)
	var draw := PlanCanyons.new(p, r, p._corner_dirs())
	for i in rest.size():
		draw.mark(i)
	draw.to_beach()
	assert_eq(p.shapes.canyons.size(), rest.size(), "rerouted in place, not added")
	assert_true(p.shapes.canyons.any(func(c): return p._on_beach(c)))
	for c in p.shapes.canyons:
		var f: PackedFloat32Array = c.floor
		for i in range(1, f.size()):
			assert_true(f[i] <= f[i - 1] + 1e-3, "a rerouted floor climbs toward its mouth")
		assert_gte(Array(c.half_floor).min() * 2.0, WorldPlan.CANYON_FLOOR_WIDTH.x)

func test_one_or_two_branches_meet_their_parents_floor():
	var p := _wadis().plan()
	var radius := _wadis().radius_m
	var branches := p.shapes.canyons.filter(func(c): return c.has("joins"))
	assert_between(branches.size(), 1, 2)
	for b: Dictionary in branches:
		assert_eq(b.mouth, &"")
		var parent: Dictionary = p.shapes.canyons[b.joins]
		assert_false(parent.has("joins"), "a branch joins a canyon, not a branch")
		var end: Vector3 = b.path[-1]
		var at := _nearest_on(parent.path, end)
		assert_lt(at.x * radius, 0.5, "its last point is on its parent's path")
		assert_almost_eq(b.floor[-1], lerpf(parent.floor[int(at.y)], parent.floor[int(at.y) + 1], at.z), 0.01,
			"and its floor is its parent's there")

func test_canyon_at_is_the_nearest_canyon_whose_walls_reach():
	var p := _wadis().plan()
	var radius := _wadis().radius_m
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	var rng := RandomNumberGenerator.new(); rng.seed = 15
	var inside := 0
	var outside := 0
	for k in 600:
		var d: Vector3
		if k % 5 == 4:
			d = _dir(rng)
		else:
			# Within one and a half reaches of a canyon's point.
			var c: Dictionary = p.shapes.canyons[rng.randi_range(0, p.shapes.canyons.size() - 1)]
			var i := rng.randi_range(0, c.path.size() - 1)
			var reach: float = c.half_floor[i] + c.rim[i] * WorldPlan.CANYON_WALL_RUN
			d = _off(c.path[i], rng.randf() * 1.5 * reach / radius, rng)
		var want := _brute_canyon(p, d)
		var got := p.shapes.canyon_at(d, PlanShapes.cell_index(p.map.cell_of(d)))
		# sample() fills the canyon's fields from canyon_at (a direction is
		# good to a few millimetres in single precision).
		p.sample(d, out)
		var filled := Vector3(out[WorldPlan.S_CANYON], out[WorldPlan.S_CANYON_FLOOR], out[WorldPlan.S_CANYON_RIM])
		if is_inf(got.x):
			assert_eq(filled, got)
		else:
			assert_almost_eq(filled, got, Vector3(1e-4, 1e-3, 1e-3))
		if is_inf(want.x):
			assert_eq(got, Vector3(INF, 0.0, 0.0))
			outside += 1
		else:
			assert_almost_eq(got.x, want.x, 1e-3)
			assert_almost_eq(got.y, want.y, 0.01)
			assert_almost_eq(got.z, want.z, 0.01)
			inside += 1
	assert_gt(inside, 300)
	assert_gt(outside, 100)

func test_a_canyons_walls_top_the_ground_and_its_detail_where_they_end():
	# Leaving a canyon's reach makes no seam: there, either side of every point
	# of its path, its walls stand over the base and the most detail the land
	# there may add (DETAIL_REACH), so close-up detail cannot open one.
	var walls := _walls_short(_wadis().plan())
	assert_gt(walls.y, 800)
	assert_eq(walls.x, 0, "walls under the ground and its detail where they end")

func test_every_rim_settles_on_wadis_and_a_handful_of_worlds():
	# The rim is looked for out to where the walls end, at most
	# CANYON_RIM_LOOKS times; on these (ranges' flanks among them) every one
	# settles, with no error, and its walls top the ground and its detail.
	var recipes: Array[WorldRecipe] = [_wadis()]
	for s in [119, 139, 141, 248]:
		recipes.append(WorldRecipe.from_seed(s))
	for r in recipes:
		assert_true(r.is_desert())
		var walls := _walls_short(WorldPlan.build(r))
		assert_gt(walls.y, 200, r.name)
		assert_eq(walls.x, 0, "%s: walls under the ground and its detail where they end" % r.name)
	assert_push_error(0, "every rim settles, and nothing else goes wrong")

func test_no_canyon_reaches_wadoos_disc():
	var p := _wadis().plan()
	var radius := _wadis().radius_m
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	var nearest := INF
	for c: Dictionary in p.shapes.canyons:
		var path: PackedVector3Array = c.path
		for s in path.size() - 1:
			var reach := maxf(c.half_floor[s] + c.rim[s] * WorldPlan.CANYON_WALL_RUN,
				c.half_floor[s + 1] + c.rim[s + 1] * WorldPlan.CANYON_WALL_RUN)
			nearest = minf(nearest, _segment_rad(path, s, wadoo) * radius - reach)
	assert_gte(nearest, 3500.0, "the walls and all keep out of the kept disc and its blend")
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	var rng := RandomNumberGenerator.new(); rng.seed = 16
	for k in 300:
		p.sample(_off(wadoo, sqrt(rng.randf()) * 3500.0 / radius, rng), out)
		assert_true(is_inf(out[WorldPlan.S_CANYON]))

func test_a_desert_with_no_sea_digs_its_canyons_basins():
	var p := _desert_with(func(d: PlanDials): return d.sea == 0.0 and d.canyons >= 2).plan()
	var mains := p.shapes.canyons.filter(func(c): return not c.has("joins"))
	assert_eq(mains.size(), p.dials.canyons)
	for c in mains:
		assert_eq(c.mouth, &"basin")

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

## WADIS's ground at `d`: the plan's base, until the terrain reads the plan.
func _ground(d: Vector3) -> float:
	if _wadis_plan == null:
		_wadis_plan = _wadis().plan()
	return _wadis_plan.map.at(WorldPlan.S_BASE, d)

## The share of `n` seeded directions, even over the sphere, where `pred` holds.
func _share(pred: Callable, n: int) -> float:
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	var hits := 0
	for k in n:
		if pred.call(_dir(rng)):
			hits += 1
	return float(hits) / n

## How many separate bodies of `land` the plan has: land_at at every cell's
## centre, flooded through the map's neighbours.
func _components(p: WorldPlan, land: WorldPlan.Land) -> int:
	var of := {}
	for face in CubeSphere.FACES:
		for j in PlanMap.CELLS:
			for i in PlanMap.CELLS:
				var c := Vector4i(face, PlanMap.PLAN_DEPTH, i, j)
				if p.land_at(_centre(c)) == land:
					of[c] = true
	var bodies := 0
	var seen := {}
	for c: Vector4i in of:
		if seen.has(c):
			continue
		bodies += 1
		seen[c] = true
		var todo: Array[Vector4i] = [c]
		while not todo.is_empty():
			for o in p.map.neighbours(todo.pop_back()):
				if of.has(o) and not seen.has(o):
					seen[o] = true
					todo.append(o)
	return bodies

## The first desert world, by seed, whose rolled dials meet `cond`.
func _desert_with(cond: Callable) -> WorldRecipe:
	for s in 10000:
		var r := WorldRecipe.from_seed(s)
		if r.is_desert() and cond.call(PlanDials.roll(r.seed, r.radius_m)):
			return r
	return null

## Every cell of every sea, as the quadtree's node keys.
func _sea_cells(p: WorldPlan) -> Dictionary:
	var out := {}
	for sea: Dictionary in p.shapes.seas:
		for c: int in sea.cells:
			out[PlanShapes.cell_key(c)] = true
	return out

## The direction of every corner shared by a sea's cell and a land cell.
func _outline(p: WorldPlan, sea: Dictionary) -> Array[Vector3]:
	var wet := {}
	var dry := {}
	for face in CubeSphere.FACES:
		for j in PlanMap.CELLS:
			for i in PlanMap.CELLS:
				var into: Dictionary = wet if sea.has(Vector4i(face, PlanMap.PLAN_DEPTH, i, j)) else dry
				for corner in 4:
					into[p.map.corner_dir(face, i + (corner & 1), j + (corner >> 1))] = true
	var out: Array[Vector3] = []
	for d: Vector3 in wet:
		if dry.has(d):
			out.append(d)
	return out

## The direction `angle` radians from `d`, on a seeded bearing.
func _off(d: Vector3, angle: float, rng: RandomNumberGenerator) -> Vector3:
	var across := _dir(rng)
	across = (across - d * d.dot(across)).normalized()
	return (d * cos(angle) + across * sin(angle)).normalized()

## Vector3(radians from `d` to the nearest point of any range's spine, the
## spine's height there, that range's half-width), every segment tried.
func _nearest_spine(p: WorldPlan, d: Vector3) -> Vector3:
	var out := Vector3(INF, 0.0, 0.0)
	for r: Dictionary in p.shapes.ranges:
		var spine: PackedVector3Array = r.spine
		for s in spine.size() - 1:
			var a := spine[s]
			var ab := spine[s + 1] - a
			var t := clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var angle := d.angle_to(a + ab * t)
			if angle < out.x:
				out = Vector3(angle, lerpf(r.height[s], r.height[s + 1], t), r.half_width)
	return out

# Vector2i(where a canyon's walls end below the base and the DETAIL_REACH of
# the land there, the places tried): either side of every point of every
# canyon's path of `p`, across it as the plan draws its rim.
func _walls_short(p: WorldPlan) -> Vector2i:
	var radius := p.shapes.radius_m
	var out := Vector2i.ZERO
	for c: Dictionary in p.shapes.canyons:
		var path: PackedVector3Array = c.path
		var n := path.size()
		for i in n:
			var across := path[i].cross(path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
			var reach: float = (c.half_floor[i] + c.rim[i] * WorldPlan.CANYON_WALL_RUN) / radius
			for side: float in [-1.0, 1.0]:
				var d := (path[i] * cos(reach) + across * side * sin(reach)).normalized()
				var need: float = p.map.at(WorldPlan.S_BASE, d) + WorldPlan.DETAIL_REACH[p.land_at(d)]
				if need > c.floor[i] + c.rim[i] + 0.01:
					out.x += 1
				out.y += 1
	return out

## Radians from `d` to the nearest point of segment `s` of `path`.
func _segment_rad(path: PackedVector3Array, s: int, d: Vector3) -> float:
	var a := path[s]
	var ab := path[s + 1] - a
	return d.angle_to(a + ab * clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0))

## Vector3(radians from `d` to the nearest point of `path`, its segment, how
## far along it), every segment tried.
func _nearest_on(path: PackedVector3Array, d: Vector3) -> Vector3:
	var out := Vector3(INF, 0.0, 0.0)
	for s in path.size() - 1:
		var a := path[s]
		var ab := path[s + 1] - a
		var t := clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var angle := d.angle_to(a + ab * t)
		if angle < out.x:
			out = Vector3(angle, s, t)
	return out

## What canyon_at should give at `d`, every segment of every canyon tried: of
## each canyon, the nearest point of its path whose walls reach `d` (its floor's
## half-width and CANYON_WALL_RUN times its rim); of those, the one whose cut
## stands lowest at `d` (its floor, and the walls' rise past the floor's edge).
## Nearest by the chord, as canyon_at measures, so where two points of a path
## are as near as makes no odds (inside a bend) both pick the same.
func _brute_canyon(p: WorldPlan, d: Vector3) -> Vector3:
	var radius := p.shapes.radius_m
	var out := Vector3(INF, 0.0, 0.0)
	var lowest := INF
	for c: Dictionary in p.shapes.canyons:
		var path: PackedVector3Array = c.path
		var best := INF
		var got := Vector3.ZERO
		var cut := INF
		for s in path.size() - 1:
			var a := path[s]
			var ab := path[s + 1] - a
			var t := clampf((d - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var chord := d.distance_to(a + ab * t)
			var metres := d.angle_to(a + ab * t) * radius
			var half := lerpf(c.half_floor[s], c.half_floor[s + 1], t)
			var rim := lerpf(c.rim[s], c.rim[s + 1], t)
			if chord < best and metres <= half + rim * WorldPlan.CANYON_WALL_RUN:
				best = chord
				var bed := lerpf(c.floor[s], c.floor[s + 1], t)
				got = Vector3(metres / half, bed, rim)
				cut = bed + maxf(metres - half, 0.0) / WorldPlan.CANYON_WALL_RUN
		if cut < lowest:
			lowest = cut
			out = got
	return out

## Radians from `d` to the nearest of `points`.
func _nearest(d: Vector3, points: Array[Vector3]) -> float:
	var near := INF
	for o in points:
		near = minf(near, d.angle_to(o))
	return near
