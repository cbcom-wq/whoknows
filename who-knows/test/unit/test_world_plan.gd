extends GutTest

## Open ground is read this far from any shore: past the sea, its beach and
## every cell that reaches the beach.
const AWAY_FROM_SEA := 2.0 * WorldPlan.PUDDLE_FROM

var _wadis_terrain: WorldTerrain

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

func test_the_bounds_hold_the_coast_where_ranges_and_plateaus_meet_it():
	var p := _wadis().plan()
	var rng := RandomNumberGenerator.new(); rng.seed = 12
	var reach: Dictionary = WorldPlan.DETAIL_REACH
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var checked := 0
	for k in 60000:
		var d := _dir(rng)
		if absf(p.nearest_shore_m(d)) > 3000.0:
			continue
		p.sample(d, f)
		if f[WorldPlan.S_MOUNTAIN] <= 0.0 and f[WorldPlan.S_PLATEAU] <= 0.0:
			continue
		checked += 1
		var b := p.bounds_of(CubeSphere.key_for(d, 8))
		var land := WorldPlan.land_in(f)
		assert_gte(f[WorldPlan.S_BASE] - reach[land], b.x - 1e-3)
		assert_lte(f[WorldPlan.S_BASE] + reach[land], b.y + 1e-3)
	assert_gt(checked, 0, "some coast has a range or plateau on it")

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
		if out[WorldPlan.S_SHORE] < AWAY_FROM_SEA or out[WorldPlan.S_MOUNTAIN] > 0.0 or out[WorldPlan.S_PLATEAU] > 0.0 or p.keep_weight(d) > 0.0:
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
				# A region may stand whole to the water's edge (its cliff's foot,
				# at sea level), never out at sea.
				var shore := m.corner(WorldPlan.S_SHORE, face, i, j)
				assert_gte(shore, 0.0, "no plateau at sea")
				var top := m.corner(WorldPlan.S_PLATEAU_TOP, face, i, j)
				assert_between(top, 100.0, 400.0)
				if w == 1.0 and shore > 0.0:
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
	# Both sides of each of the canyons' path points: some 400 points with the
	# plateau regions WorldPlan.PLATEAU_REGIONS draws.
	var walls := _walls_short(_wadis().plan())
	assert_gt(walls.y, 700)
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

func test_a_sample_is_at_and_cell_number_to_the_bit():
	# sample() writes out where a direction falls (_locate): it gives every field
	# as at() does and its cell as cell_number does, for directions of any length,
	# on every face and on the faces' edges and corners.
	var p := _wadis().plan()
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	var dirs: Array[Vector3] = []
	for k in 2000:
		dirs.append(_dir(rng) * (1.0 if k % 2 == 0 else 3.7))
	for e: Array in _face_edge_points(120):
		dirs.append(e[0])
	for d in dirs:
		assert_eq(p.map.sample(d, out), p.map.cell_number(d))
		for f in WorldPlan.S_SIZE:
			assert_eq(out[f], p.map.at(f, d), "field %d" % f)

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

func test_oasis_sites_are_low_level_dry_and_spaced():
	var p := _wadis().plan()
	var oases := p.sites.filter(func(s): return s.kind == PlanSite.Kind.OASIS)
	assert_gte(oases.size(), 6)
	assert_gte(oases.size(), p.dials.oases)
	for s in oases:
		assert_gt(p.nearest_shore_m(s.dir), 0.0)
		assert_eq(p.keep_weight(s.dir), 0.0)
		assert_lt(s.level, 0.3)
		for o in oases:
			if o != s:
				assert_gte(s.dir.angle_to(o.dir) * _wadis().radius_m, WorldPlan.OASIS_SPACING)

func test_a_world_lists_at_least_its_dials_oases():
	# WADIS, the first three deserts by seed, and the smallest of the first twelve.
	var worlds: Array[WorldRecipe] = [_wadis()]
	var small: WorldRecipe = null
	var found := 0
	for sd in 2000:
		var r := WorldRecipe.from_seed(sd)
		if not r.is_desert():
			continue
		found += 1
		if found <= 3:
			worlds.append(r)
		if found <= 12 and (small == null or r.radius_m < small.radius_m):
			small = r
		if found == 12:
			break
	worlds.append(small)
	assert_eq(found, 12, "enough deserts among the seeds")
	for r in worlds:
		var p := r.plan()
		var oases := p.sites.filter(func(s): return s.kind == PlanSite.Kind.OASIS)
		assert_gte(oases.size(), p.dials.oases, "%s (radius %.0f km) lists its dial's oases" % [r.name, r.radius_m / 1000.0])

func test_sites_are_listed_best_first_within_their_kind():
	var p := _wadis().plan()
	for kind in [PlanSite.Kind.OASIS, PlanSite.Kind.SHORE]:
		var last := -INF
		for s in p.sites.filter(func(s): return s.kind == kind):
			assert_gte(s.rank, last)
			last = s.rank
	var kept := p.sites.filter(func(s): return s.kind == PlanSite.Kind.KEPT)
	assert_eq(kept.size(), _wadis().keeps.size())
	assert_eq(kept[0].radius, _wadis().keeps[0].radius)

func test_the_same_seed_plans_the_same_sites():
	var a := _wadis().plan()
	var b := WorldPlan.build(_wadis())
	assert_eq(a.sites.size(), b.sites.size())
	for n in mini(a.sites.size(), b.sites.size()):
		assert_eq(a.sites[n].dir, b.sites[n].dir)
		assert_eq(a.sites[n].heading, b.sites[n].heading)

func test_shore_sites_lie_by_the_water():
	var p := _wadis().plan()
	for s in p.sites.filter(func(s): return s.kind == PlanSite.Kind.SHORE):
		assert_between(p.nearest_shore_m(s.dir), 0.0, 400.0)
		assert_eq(p.keep_weight(s.dir), 0.0)

func test_nothing_planned_comes_near_wadoo():
	var p := _wadis().plan()
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	for d in _disc_points(wadoo, 3500.0, 1000):
		p.sample(d, out)
		assert_eq(out[WorldPlan.S_MOUNTAIN], 0.0)
		assert_eq(out[WorldPlan.S_PLATEAU], 0.0)
		assert_true(is_inf(out[WorldPlan.S_CANYON]))   # no canyon reaches it, walls and all
		assert_gt(out[WorldPlan.S_SHORE], 0.0)
	for s in p.sites:
		if s.kind != PlanSite.Kind.KEPT:
			assert_gt(s.dir.angle_to(wadoo) * _wadis().radius_m, 3500.0)

func test_keep_weight_is_one_in_the_disc_and_eases_to_nothing_over_the_blend():
	var p := _wadis().plan()
	var radius := _wadis().radius_m
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	var keep: Dictionary = _wadis().keeps[0]
	var out := PackedFloat64Array(); out.resize(WorldPlan.S_SIZE)
	for metres in [0.0, 1000.0, 2000.0]:
		assert_eq(p.keep_weight(_off_by(wadoo, metres, 0.7, radius)), 1.0)
	for metres in [3500.0, 3600.0, 20000.0]:
		assert_eq(p.keep_weight(_off_by(wadoo, metres, 2.1, radius)), 0.0)
	var d := _off_by(wadoo, 2750.0, 4.0, radius)
	assert_almost_eq(p.keep_weight(d), 0.5, 1e-3, "halfway over the blend")
	p.sample(d, out)
	assert_eq(out[WorldPlan.S_KEEP], p.keep_weight(d))
	assert_eq(keep.radius, 2000.0)

func test_the_bounds_hold_the_base_less_and_plus_its_detail_the_canyons_and_the_kept_range():
	var p := _wadis().plan()
	var radius := _wadis().radius_m
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var reach: Dictionary = WorldPlan.DETAIL_REACH
	for k in 3000:
		var d := _dir(rng)
		var b := p.bounds_of(CubeSphere.key_for(d, 7))
		var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
		p.sample(d, f)
		var land := WorldPlan.land_in(f)
		assert_gte(f[WorldPlan.S_BASE] - reach[land], b.x - 1e-3)
		assert_lte(f[WorldPlan.S_BASE] + reach[land], b.y + 1e-3)
		if not is_inf(f[WorldPlan.S_CANYON]):
			assert_gte(f[WorldPlan.S_CANYON_FLOOR], b.x - 1e-3)
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	for d in _disc_points(wadoo, 3500.0, 200):
		var b := p.bounds_of(CubeSphere.key_for(d, 9))
		assert_lte(b.x, -60.0)
		assert_gte(b.y, 300.0)
	assert_lte(p.bounds_of(CubeSphere.key_for(wadoo, 12)).x, -60.0)

func test_wadoos_disc_is_todays_ground_to_the_bit():
	var planned := WorldTerrain.new(_wadis())
	var r := _wadis(); r.planned = false
	var today := WorldTerrain.new(r)
	for d in _disc_points(SystemDesign.dir_of(-2.16, -171.97), 2000.0, 2000):
		assert_eq(planned.height_at(d), today.height_at(d))
		assert_eq(planned.colour_at(d, 0.2, 8.0), today.colour_at(d, 0.2, 8.0))

func test_the_kept_disc_eases_out_without_a_step():
	# today's ground has its own cliffs (towers), so the weight is what is checked
	var p := _wadis().plan()
	var wadoo := SystemDesign.dir_of(-2.16, -171.97)
	var radius := _wadis().radius_m
	for bearing in 36:
		var last := NAN
		for m in range(1900, 3700):
			var w := p.keep_weight(_at(wadoo, float(m), deg_to_rad(bearing * 10.0), radius))
			if m <= 2000: assert_eq(w, 1.0)
			if m >= 3500: assert_eq(w, 0.0)
			if not is_nan(last):
				assert_lte(absf(w - last), 1.5 / 1500.0 + 1e-6)   # smoothstep's steepest, a metre
			last = w

func test_a_planned_desert_reaches_its_peaks_and_its_seabed():
	var t := WorldTerrain.new(_wadis())
	var hs := _heights(t, 20000)
	assert_lt(hs.min(), t.plan.sea_level - 100.0)
	assert_gt(hs.max(), 1000.0)

## Review fix 1: a dune sea's dunes are today's, whole across its interior.
## They rise over its edge only (WorldPlan.DUNES_EDGE of S_DUNES past
## DUNES_FROM). Faded over all of S_DUNES's range they stood at about half
## height at the median. On WADIS's dune seas (land DUNES, outside the kept
## disc), at least SEA_WHOLE of the ground has the plan's dunes
## (WorldTerrain._plan_dunes) whole, at WHOLE or more. The fade toward the
## wind axis's poles is today's own, the same on planned ground and today's,
## so it is printed beside them, not judged.
const SEA_WHOLE := 0.6
const WHOLE := 0.999

func test_a_dune_sea_stands_its_dunes_whole_off_its_edges():
	var t := WorldTerrain.new(_wadis())
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var rng := RandomNumberGenerator.new(); rng.seed = 27
	var plan: Array[float] = []
	var poled: Array[float] = []
	while plan.size() < 40000:
		var d := _dir(rng)
		t.plan.sample(d, f)
		if f[WorldPlan.S_KEEP] > 0.0 or WorldPlan.land_in(f) != WorldPlan.Land.DUNES:
			continue
		var s := t._plan_dunes(f)
		plan.append(s)
		poled.append(s * WorldTerrain.pole_fade(d.dot(t.wind_axis)))
	var a := _stand_spread(plan)
	var b := _stand_spread(poled)
	gut.p("the plan's dunes over 40000 points of dune sea: median %.3f, mean %.3f, whole %.3f, under a quarter %.3f" % a)
	gut.p("with the pole fade too: median %.3f, mean %.3f, whole %.3f, under a quarter %.3f" % b)
	assert_gte(a[0], WHOLE, "whole at the median")
	assert_gte(a[2], SEA_WHOLE, "whole across most of the dune seas")
	assert_lt(a[3], 0.25, "few points where under a quarter of the dunes stands")

## [median, mean, share at WHOLE or more, share under 0.25] of `stands`.
static func _stand_spread(stands: Array[float]) -> Array:
	var sorted := stands.duplicate()
	sorted.sort()
	var sum := 0.0
	var whole := 0
	var low := 0
	for s in stands:
		sum += s
		if s >= WHOLE:
			whole += 1
		if s < 0.25:
			low += 1
	var n := float(stands.size())
	return [sorted[stands.size() / 2], sum / n, whole / n, low / n]

## The edge a dune sea's dunes rise over is hundreds of metres wide, so whole
## 40 m dunes rise gently and never in a step. In every plan cell that
## S_DUNES's band (DUNES_FROM to DUNES_FROM + DUNES_EDGE) crosses, S_DUNES at
## its steepest climbs the band over EDGE_LEAST metres or more. The steepest
## is found at the cell's corners, as the cell is bilinear. At EDGE_LEAST the
## dunes' height grows at most 1.5 x 40 m / 300 m, a fifth of a metre a metre:
## half a dune's own lee face.
const EDGE_LEAST := 300.0

func test_a_dune_seas_edge_is_hundreds_of_metres_wide():
	var p := _wadis().plan()
	var radius := _wadis().radius_m
	var m := p.map
	var s := WorldPlan.S_DUNES
	var low := WorldPlan.DUNES_FROM
	var high := WorldPlan.DUNES_FROM + WorldPlan.DUNES_EDGE
	var narrowest := INF
	var widths: Array[float] = []
	for face in CubeSphere.FACES:
		for j in PlanMap.CELLS:
			for i in PlanMap.CELLS:
				var c00 := m.corner(s, face, i, j)
				var c10 := m.corner(s, face, i + 1, j)
				var c01 := m.corner(s, face, i, j + 1)
				var c11 := m.corner(s, face, i + 1, j + 1)
				if maxf(maxf(c00, c10), maxf(c01, c11)) < low or minf(minf(c00, c10), minf(c01, c11)) > high:
					continue
				var d00 := m.corner_dir(face, i, j)
				var d10 := m.corner_dir(face, i + 1, j)
				var d01 := m.corner_dir(face, i, j + 1)
				var d11 := m.corner_dir(face, i + 1, j + 1)
				var u0 := (c10 - c00) / (d00.angle_to(d10) * radius)
				var u1 := (c11 - c01) / (d01.angle_to(d11) * radius)
				var v0 := (c01 - c00) / (d00.angle_to(d01) * radius)
				var v1 := (c11 - c10) / (d10.angle_to(d11) * radius)
				var steepest := sqrt(maxf(u0 * u0, u1 * u1) + maxf(v0 * v0, v1 * v1))
				var width := WorldPlan.DUNES_EDGE / maxf(steepest, 1e-12)
				narrowest = minf(narrowest, width)
				widths.append(width)
	widths.sort()
	gut.p("%d cells on a dune sea's edge: narrowest %.0f m, 1%% %.0f m, median %.0f m" % [widths.size(), narrowest,
		widths[widths.size() / 100], widths[widths.size() / 2]])
	assert_gt(widths.size(), 100, "cells on the edge")
	assert_gte(narrowest, EDGE_LEAST)

## The planned ground is the same on every thread: several WorldTerrains of
## WADIS, each built and read on a worker of its own, give the main thread's
## heights to the bit at THREADED_POINTS points outside the kept disc. Each
## terrain's _fields is its own, and nothing they share is written.
const THREADED_POINTS := 3000
const WORKERS := 4

func test_planned_heights_on_workers_are_the_main_thread_s_to_the_bit():
	var recipe := _wadis()
	var main := WorldTerrain.new(recipe)
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	var points: Array[Vector3] = []
	var want := PackedFloat64Array()
	while points.size() < THREADED_POINTS:
		var d := _dir(rng)
		if main.plan.keep_weight(d) > 0.0:
			continue
		points.append(d)
		want.append(main.height_at(d))
	# A lambda captures locals by value, so each worker's heights come back in
	# a box of its own.
	var boxes: Array = []
	var ids: Array[int] = []
	for w in WORKERS:
		var box := [null]
		boxes.append(box)
		ids.append(WorkerThreadPool.add_task(func() -> void:
			var t := WorldTerrain.new(recipe)
			var got := PackedFloat64Array()
			for d in points:
				got.append(t.height_at(d))
			box[0] = got))
	for id in ids:
		WorkerThreadPool.wait_for_task_completion(id)
	for w in WORKERS:
		var got: PackedFloat64Array = boxes[w][0]
		assert_eq(got.size(), THREADED_POINTS, "worker %d's heights" % w)
		var differ := 0
		for k in mini(got.size(), want.size()):
			if got[k] != want[k]:
				differ += 1
		assert_eq(differ, 0, "worker %d: heights unlike the main thread's" % w)

# The land close up (the wadis land spec §6): each kind's own detail on the
# plan's base, within the plan's bounds, with canyon floors to land on and no
# puddle away from the sea.

func test_canyon_floors_are_level_enough_to_land_on():
	var t := WorldTerrain.new(_wadis())
	for d in _canyon_floor_points(t.plan, 400):
		assert_lt(_slope(t, d, 5.0), deg_to_rad(10.0))

func test_ground_stays_within_the_plans_bounds():
	var t := WorldTerrain.new(_wadis())
	for k in _keys_at_depths(t, [4, 6, 8, 10], 200):
		var b := t.plan.bounds_of(k)
		for d in _points_in(k, 25):
			var h := t.height_at(d)
			assert_true(h >= b.x - 0.01 and h <= b.y + 0.01, "%s outside %s" % [h, b])

func test_no_puddles_away_from_the_sea():
	var t := WorldTerrain.new(_wadis())
	for d in _dirs(20000):
		if t.height_at(d) < t.plan.sea_level:
			assert_lt(t.plan.nearest_shore_m(d), WorldPlan.PUDDLE_FROM)

func test_from_300_m_something_stands_on_the_horizon():
	# §3's anti-goal: from 300 m over open ground, a range, a plateau's edge, a canyon or the sea
	var t := WorldTerrain.new(_wadis())
	var hits := 0
	var spots := _open_ground(t, 200)
	for d in spots:
		if _horizon_feature(t, d, 300.0):
			hits += 1
	gut.p("%d of %d spots over open ground see something on the horizon from 300 m" % [hits, spots.size()])
	assert_gt(float(hits) / spots.size(), 0.8)

## A range's peaks stand sharp (the wadis land spec §6): of the ground within a
## third of a range's half-width of its spine, at least ROCK_SHARE is past
## ROCK_SLOPE, so rock; and its spine is a crest standing clear of its flanks,
## at four spine points in five at least CREST_CLEAR metres over the mean of the
## ground CREST_LOOK metres either side across it.
const ROCK_SHARE := 0.25
const CREST_CLEAR := 15.0
const CREST_LOOK := 150.0

func test_a_range_s_peaks_stand_sharp_with_rock_faces():
	var t := WorldTerrain.new(_wadis())
	var p := t.plan
	var radius := t.radius
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var rng := RandomNumberGenerator.new(); rng.seed = 97
	var points := 0
	var steep := 0
	while points < 400:
		var d := _dir(rng)
		p.sample(d, f)
		if f[WorldPlan.S_KEEP] > 0.0 or f[WorldPlan.S_CANYON] < INF or f[WorldPlan.S_SHORE] < 400.0 \
				or WorldPlan.land_in(f) != WorldPlan.Land.MOUNTAINS:
			continue
		var cell := p.map.cell_of(d)
		var spine := p.shapes.ridge_m(d, cell)
		var half: float = p.shapes.ranges[_nearest_range(p, d)].half_width
		if spine.x > half / 3.0:
			continue
		points += 1
		if _slope(t, d, 5.0) > WorldTerrain.ROCK_SLOPE:
			steep += 1
	gut.p("%d of %d points by a spine past ROCK_SLOPE" % [steep, points])
	assert_gt(float(steep) / points, ROCK_SHARE, "a range's ground near its spine is rock")
	var clear: Array[float] = []
	for r: Dictionary in p.shapes.ranges:
		var path: PackedVector3Array = r.spine
		for k in range(1, path.size() - 2):
			var q := path[k].lerp(path[k + 1], rng.randf()).normalized()
			if p.keep_weight(q) > 0.0 or p.nearest_shore_m(q) < 1000.0 or p.shapes.canyon_at(q, p.map.cell_number(q)).x < INF:
				continue
			var across := q.cross(path[k + 1] - path[k]).normalized()
			var side := 0.5 * (t.height_at(_across(q, across, CREST_LOOK, radius)) \
				+ t.height_at(_across(q, across, -CREST_LOOK, radius)))
			clear.append(t.height_at(q) - side)
	clear.sort()
	gut.p("crests over their flanks %.0f m either side: a fifth under %.1f m, the median %.1f m" \
		% [CREST_LOOK, clear[clear.size() / 5], clear[clear.size() / 2]])
	assert_gt(clear.size(), 100)
	assert_gt(clear[clear.size() / 5], CREST_CLEAR, "a range's spine stands clear of its flanks")

## The index of the range whose spine passes nearest `d`.
func _nearest_range(p: WorldPlan, d: Vector3) -> int:
	var best := INF
	var at := 0
	for i in p.shapes.ranges.size():
		var path: PackedVector3Array = p.shapes.ranges[i].spine
		for k in path.size():
			var a := d.angle_to(path[k])
			if a < best:
				best = a
				at = i
	return at

## A plateau's top stands flat at its own top, ground_high, but for where it
## meets the sea: from its cliff line (WorldTerrain._cliff_line) to the water.
func test_a_plateau_s_top_stands_flat_at_its_own_top():
	var t := WorldTerrain.new(_wadis())
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var tops := 0
	var off := 0
	for d in _dirs(20000):
		t.plan.sample(d, f)
		if f[WorldPlan.S_PLATEAU] < 1.0 or f[WorldPlan.S_CANYON] < INF or f[WorldPlan.S_KEEP] > 0.0 \
				or f[WorldPlan.S_SHORE] < t._cliff_line(d):
			continue
		tops += 1
		if t.height_at(d) != f[WorldPlan.S_PLATEAU_TOP] or t.ground_at(d, 0.0) != &"ground_high":
			off += 1
	assert_gt(tops, 1000)
	assert_eq(off, 0, "points on a top not at its top, or not ground_high")

func test_boulders_gather_at_the_feet_of_ranges_and_plateaus():
	var t := WorldTerrain.new(_wadis())
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var feet := 0
	var bare := 0
	var open := 0
	var strewn := 0
	for d in _dirs(20000):
		t.plan.sample(d, f)
		if f[WorldPlan.S_KEEP] > 0.0:
			continue
		var mountain := f[WorldPlan.S_MOUNTAIN]
		var plateau := f[WorldPlan.S_PLATEAU]
		if f[WorldPlan.S_SHORE] > 0.0 and plateau < WorldPlan.PLATEAU_FROM \
				and (plateau > 0.0 or (mountain >= WorldTerrain.MOUNTAIN_TALUS.x and mountain < WorldTerrain.MOUNTAIN_TALUS.y)):
			if plateau > 0.0 and t._tower_stand(d) > 0.0:
				continue
			feet += 1
			if not t.in_talus(d):
				bare += 1
		elif mountain == 0.0 and plateau == 0.0:
			open += 1
			if t.in_talus(d):
				strewn += 1
	assert_gt(feet, 500)
	assert_eq(bare, 0, "points at a foot with no boulders")
	assert_gt(open, 5000)
	assert_eq(strewn, 0, "points away from every foot with boulders")

func test_the_planned_ground_wears_the_desert_s_colours_and_its_waterline_is_damp():
	var t := WorldTerrain.new(_wadis())
	var palette: Dictionary = SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE]
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var seen := {}
	for d in _dirs(20000):
		if t.plan.keep_weight(d) == 0.0:
			var g := t.ground_at(d, 0.0)
			seen[g] = seen.get(g, 0) + 1
	gut.p("colours over the planned ground: %s" % seen)
	for g: StringName in seen:
		assert_true(palette.has(g), "%s is the desert palette's" % g)
	for g in [&"ground_low", &"ground_high", &"dust", &"damp"]:
		assert_true(seen.has(g), "some ground is %s" % g)
	# Along the coast the ground is damp where it stands in the band by the water
	# (on the beaches: a cliff's face and a canyon's own colours come first).
	var rng := RandomNumberGenerator.new(); rng.seed = 83
	var coast := 0
	var damp := 0
	var dry := 0
	while coast < 400:
		var d := _dir(rng)
		t.plan.sample(d, f)
		if f[WorldPlan.S_KEEP] > 0.0 or absf(f[WorldPlan.S_SHORE]) >= 150.0 or f[WorldPlan.S_CANYON] < INF \
				or f[WorldPlan.S_MOUNTAIN] > 0.0 or f[WorldPlan.S_PLATEAU] > 0.0:
			continue
		coast += 1
		var h := t.height_at(d) - t.plan.sea_level
		var in_band := h >= -WorldTerrain.DAMP_BAND.x and h <= WorldTerrain.DAMP_BAND.y
		var wet := t.ground_at(d, 0.0) == &"damp"
		if wet:
			damp += 1
		if wet != in_band:
			dry += 1
	gut.p("%d of %d points on the coast damp" % [damp, coast])
	assert_gt(damp, 100)
	assert_eq(dry, 0, "points damp out of the band by the water, or in it and not")

## Where a branch joins its parent, the ground is never over the lowest of every
## canyon's floor and stepped walls (worked out by brute force), and is that
## floor where it is one: no canyon's riser stands on another's floor. The
## branch's floor runs level onto its parent's. Within JOIN_SLACK metres: the
## terrain's canyon parts are 32-bit floats.
const JOIN_REACH := 1500.0
const JOIN_SLACK := 0.01

func test_where_canyons_meet_the_ground_is_their_lowest_cut():
	var t := WorldTerrain.new(_wadis())
	var p := t.plan
	var radius := t.radius
	var rng := RandomNumberGenerator.new(); rng.seed = 101
	var joins := 0
	var floors := 0
	for c: Dictionary in p.shapes.canyons:
		if not c.has("joins"):
			continue
		joins += 1
		var path: PackedVector3Array = c.path
		var end := path[path.size() - 1]
		var over := 0
		var off_floor := 0
		for k in 600:
			var d := _off(end, sqrt(rng.randf()) * JOIN_REACH / radius, rng)
			if p.keep_weight(d) > 0.0:
				continue
			var cut := _brute_cut(p, d)
			if cut.x == INF:
				continue
			var h := t.height_at(d)
			if h > cut.x + JOIN_SLACK:
				over += 1
			if cut.y <= 0.0:
				floors += 1
				if absf(h - cut.x) > JOIN_SLACK:
					off_floor += 1
		assert_eq(over, 0, "points by a join over the lowest cut")
		assert_eq(off_floor, 0, "points on a floor by a join not at that floor")
		var parent_floor := _brute_cut(p, end)
		assert_almost_eq(t.height_at(end), parent_floor.x, JOIN_SLACK, "the join is at its parent's floor")
		# The branch's last JOIN_REACH metres along its centreline, level enough.
		var along := 0.0
		for s in range(path.size() - 1, 0, -1):
			along += path[s].angle_to(path[s - 1]) * radius
			if along > JOIN_REACH:
				break
			if p.keep_weight(path[s - 1]) == 0.0:
				assert_lt(_slope(t, path[s - 1], 5.0), deg_to_rad(10.0), "the branch's floor by its join")
	assert_gt(joins, 0, "the world's canyons have a branch")
	assert_gt(floors, 50)

## Vector2(the lowest cut of every canyon at `d`: of each canyon, at the nearest
## point of its path whose walls reach `d`, its floor plus its stepped walls'
## rise, by every segment of every canyon; the metres past that canyon's floor's
## edge), or Vector2(INF, 0) where no canyon's walls reach.
func _brute_cut(p: WorldPlan, d: Vector3) -> Vector2:
	var radius := p.shapes.radius_m
	var lowest := Vector2(INF, 0.0)
	for c: Dictionary in p.shapes.canyons:
		var path: PackedVector3Array = c.path
		var best := INF
		var cut := Vector2(INF, 0.0)
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
				cut = Vector2(bed + PlanShapes.wall_rise(metres - half), metres - half)
		if cut.x < lowest.x:
			lowest = cut
	return lowest

## Where a range or a plateau meets the sea it ends in a cliff: walking to the
## water from CLIFF_SPOTS seeded spots on each kind of such coast, the ground
## falls from the cliff line (WorldTerrain._cliff_line, where the walk crosses
## it) at least CLIFF_DROP metres to within a metre of sea level over at most
## CLIFF_RUN_MOST metres, its face rock.
const CLIFF_SPOTS := 40
const CLIFF_DROP := 50.0
const CLIFF_RUN_MOST := 30.0

func test_ranges_and_plateaus_meet_the_sea_in_cliffs():
	var t := WorldTerrain.new(_wadis())
	var p := t.plan
	var radius := t.radius
	var spots := _cliff_spots(t, CLIFF_SPOTS, &"range")
	spots.append_array(_cliff_spots(t, CLIFF_SPOTS, &"plateau"))
	for d in spots:
		# Down the shore's fall, half a metre at a time, to past the cliff's foot.
		var fall := _shore_fall(p, d, radius)
		var top := Vector3.ZERO
		var top_m := 0.0
		var foot := Vector3.ZERO
		var foot_m := 0.0
		var m := 0.0
		while m < CLIFF_LOOK_M:
			var q := _across(d, fall, m, radius)
			var shore := p.map.at(WorldPlan.S_SHORE, q)
			var line := t._cliff_line(q)
			if shore >= line + 0.5:
				top = q
				top_m = m
			elif shore <= line - WorldTerrain.CLIFF_RUN - 0.5:
				foot = q
				foot_m = m
				break
			m += 0.5
		assert_ne(foot, Vector3.ZERO, "the walk reaches the cliff's foot")
		if foot == Vector3.ZERO:
			continue
		var high := t.height_at(top)
		var low := t.height_at(foot)
		assert_gt(high - p.sea_level, CLIFF_DROP, "the cliff stands over the water")
		assert_between(low, p.sea_level - 0.001, p.sea_level + 1.0, "its foot is at the water")
		assert_lt(foot_m - top_m, CLIFF_RUN_MOST, "it falls sheer")
		var face := _across(d, fall, 0.5 * (top_m + foot_m), radius)
		assert_eq(t.ground_at(face, 0.0), &"rock", "its face is rock")

## `n` seeded spots 10 to 150 metres (of S_SHORE) inland of the cliff line
## (WorldTerrain._cliff_line) on coasts where a range (its mountains' weight held
## to the water, PlanMap.held, half or more) or a plateau's top meets the sea, out
## of the kept discs and the canyons: drawn from the cells within 1.5 km of the
## water with either near. Only a range's coast if `kind` is &"range", a
## plateau's if &"plateau".
func _cliff_spots(t: WorldTerrain, n: int, kind := &"") -> Array[Vector3]:
	var p := t.plan
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var cells: Array[Vector4i] = []
	for index in CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS:
		var key := PlanShapes.cell_key(index)
		var r := CubeSphere.node_rect(key)
		var mid := CubeSphere.direction(key.x, r.x + 0.5 * r.z, r.y + 0.5 * r.z)
		p.sample(mid, f)
		var plateau := f[WorldPlan.S_PLATEAU] > 0.0 and kind != &"range"
		var range_near := f[WorldPlan.S_MOUNTAIN] > 0.0 and kind != &"plateau"
		if absf(f[WorldPlan.S_SHORE]) < 1500.0 and (plateau or range_near):
			cells.append(key)
	var rng := RandomNumberGenerator.new(); rng.seed = 103
	var out: Array[Vector3] = []
	var tries := 0
	while out.size() < n and tries < 200000 and not cells.is_empty():
		tries += 1
		var key := cells[rng.randi_range(0, cells.size() - 1)]
		var r := CubeSphere.node_rect(key)
		var d := CubeSphere.direction(key.x, r.x + rng.randf() * r.z, r.y + rng.randf() * r.z)
		p.sample(d, f)
		var shore := f[WorldPlan.S_SHORE]
		if shore > WorldTerrain.CLIFF_BAY + 150.0 or f[WorldPlan.S_KEEP] > 0.0 or f[WorldPlan.S_CANYON] < INF:
			continue
		var line := t._cliff_line(d)
		if shore < line + 10.0 or shore > line + 150.0:
			continue
		var on_top := f[WorldPlan.S_PLATEAU] >= 1.0
		if on_top and kind != &"range" \
				or not on_top and kind != &"plateau" and p.map.held(WorldPlan.S_MOUNTAIN, WorldPlan.S_SHORE, d) >= 0.5:
			out.append(d)
	assert_eq(out.size(), n, "spots on cliff coasts %s" % kind)
	return out

## The unit tangent at `d` down which the plan's S_SHORE falls fastest: toward
## the water.
func _shore_fall(p: WorldPlan, d: Vector3, radius: float) -> Vector3:
	var e1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := d.cross(e1)
	var gx := p.map.at(WorldPlan.S_SHORE, _across(d, e1, 1.0, radius)) - p.map.at(WorldPlan.S_SHORE, _across(d, e1, -1.0, radius))
	var gy := p.map.at(WorldPlan.S_SHORE, _across(d, e2, 1.0, radius)) - p.map.at(WorldPlan.S_SHORE, _across(d, e2, -1.0, radius))
	return -(e1 * gx + e2 * gy).normalized()

## A cliff's line wanders along the coast (the wadis land spec §6, Checkpoint 1):
## headlands where it stands at the water, bays where it steps back behind a
## beach, never a ruler-straight wall. Along WANDER_WALKS seeded walks of each kind
## of cliff coast (_cliff_walks), the line's distance inland of the water
## (_cliff_line_from) spreads at least WANDER_SPREAD metres, farthest less nearest,
## in every WANDER_WINDOW metres of the walk, and somewhere along each walk it is
## within HEADLAND_MOST metres of the water.
const WANDER_WALKS := 3
const WANDER_WALK := 5000.0
const WANDER_STEP := 100.0
const WANDER_WINDOW := 3000.0
const WANDER_SPREAD := 150.0
const HEADLAND_MOST := 60.0

func test_sea_cliffs_wander_in_headlands_and_bays():
	var t := WorldTerrain.new(_wadis())
	var window := int(WANDER_WINDOW / WANDER_STEP) + 1
	for kind: StringName in [&"range", &"plateau"]:
		var walks := _cliff_walks(t, kind, WANDER_WALKS)
		assert_eq(walks.size(), WANDER_WALKS, "walks along %s cliffs" % kind)
		for walk: Array in walks:
			var inland: Array[float] = []
			for q: Vector3 in walk:
				inland.append(float(_cliff_line_from(t, q)[0]))
			var least := INF
			var flat := 0
			for a in inland.size() - window + 1:
				var part := inland.slice(a, a + window)
				var spread: float = part.max() - part.min()
				least = minf(least, spread)
				if spread < WANDER_SPREAD:
					flat += 1
			gut.p("%s cliff: the line %.0f to %.0f m inland, the least spread over %.0f m %.0f m" % [
				kind, inland.min(), inland.max(), WANDER_WINDOW, least])
			assert_lt(inland.max(), INF, "%s cliff: a face found from every point of the walk" % kind)
			assert_eq(flat, 0, "%s cliff: windows where the line wanders under %.0f m" % [kind, WANDER_SPREAD])
			assert_lte(inland.min(), HEADLAND_MOST, "a headland on the %s cliff" % kind)

## A bay has a beach (spec §6, Checkpoint 1): from each point of the walks where
## the cliff line stands BAY_FROM metres or more inland, up the way to its nearest
## face a metre at a time to the face's foot (where the ground first rises a metre
## in one), the ground never stands under sea level, is never rock short of the
## foot's last BAY_FOOT_SLACK metres, and at the foot stands BAY_FOOT.x to
## BAY_FOOT.y metres over the sea: never flat ground at the water's level, where
## the sea's water will lie.
const BAY_FROM := 150.0
const BAY_FOOT := Vector2(0.5, 4.0)
const BAY_FOOT_SLACK := 2.0
const BAY_POINTS_LEAST := 20

func test_a_bay_has_a_beach_between_the_cliff_and_the_water():
	var t := WorldTerrain.new(_wadis())
	var p := t.plan
	var radius := t.radius
	var bays := 0
	for kind: StringName in [&"range", &"plateau"]:
		for walk: Array in _cliff_walks(t, kind, WANDER_WALKS):
			for q: Vector3 in walk:
				var line := _cliff_line_from(t, q)
				var line_m: float = line[0]
				if line_m < BAY_FROM or line_m == INF:
					continue
				bays += 1
				var way: Vector3 = line[1]
				var heights: Array[float] = [t.height_at(q)]
				while heights.size() < line_m + 1.0:
					var next := t.height_at(_across(q, way, heights.size(), radius))
					if next - heights[-1] >= 1.0:
						break
					heights.append(next)
				var foot := heights.size() - 1
				var under := 0
				var rock := 0
				for m in heights.size():
					if heights[m] < p.sea_level:
						under += 1
					if m < foot - BAY_FOOT_SLACK and t.ground_at(_across(q, way, m, radius), 0.0) == &"rock":
						rock += 1
				assert_eq(under, 0, "%s bay: beach points under the sea" % kind)
				assert_eq(rock, 0, "%s bay: beach points of rock" % kind)
				assert_between(heights[foot] - p.sea_level, BAY_FOOT.x, BAY_FOOT.y, "%s bay: the beach at the foot, %.0f m in" % [kind, foot])
	gut.p("%d bay points" % bays)
	assert_gt(bays, BAY_POINTS_LEAST, "bay points along the walks")

## A cliff stands once: up the shore's rise from the water the ground crosses the
## cliff line (WorldTerrain._cliff_line) once, onto the top, and never falls back
## under it into a pit behind. The line is read at the water's edge a point faces
## (_shore_point), and by a convex corner of the water's edge (a coastal cell with
## three corners on the water, where S_SHORE is a product and rises slowly) that
## point slides along the coast as one goes inland, so the line can outrun the
## shore there, most near the corner, where the shore rises slowest (with one
## Newton step ALLOROR-29, seed 139, had a pit behind a strip of top 250 m wide,
## up from 50 m of coast some 200 m from a corner). From every FOLD_SPACING metres
## of each water side of every such cell, out to FOLD_NEAR from its corner, on a
## cliff coast (its share CLIFF_SHARE_LEAST or more) of WADIS and of the worlds of
## FOLD_SEEDS, FOLD_STEP metres at a time to S_SHORE CLIFF_BAY.
const FOLD_SEEDS := [139]
const FOLD_SPACING := 15.0
const FOLD_NEAR := 450.0
const FOLD_STEP := 12.0
const FOLD_LOOK := 3000.0
const CLIFF_SHARE_LEAST := 0.05

func test_a_cliff_top_has_no_pit_behind_it():
	var recipes: Array[WorldRecipe] = [_wadis()]
	for s: int in FOLD_SEEDS:
		recipes.append(WorldRecipe.from_seed(s))
	for r in recipes:
		var t := WorldTerrain.new(r)
		var p := t.plan
		var radius := t.radius
		var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
		var corners := 0
		var walks := 0
		var folds := 0
		for index in CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS:
			var key := PlanShapes.cell_key(index)
			var rr := CubeSphere.node_rect(key)
			var wet: Array[Vector3] = []
			var dry := Vector3.ZERO
			for c in 4:
				var at := CubeSphere.direction(key.x, rr.x + (c & 1) * rr.z, rr.y + (c >> 1) * rr.z)
				if absf(p.map.at(WorldPlan.S_SHORE, at)) < 0.01:
					wet.append(at)
				elif p.map.at(WorldPlan.S_SHORE, at) > 0.0:
					dry = at
			if wet.size() != 3 or dry == Vector3.ZERO:
				continue
			# The water's corner across from the dry one, and its two water sides.
			var tip := wet[0]
			for w in wet:
				if w.angle_to(dry) > tip.angle_to(dry):
					tip = w
			var counted := false
			for w in wet:
				if w == tip:
					continue
				for k in int(FOLD_NEAR / FOLD_SPACING):
					var q := _onto_shore(p, tip.slerp(w, (k + 0.5) * FOLD_SPACING / (tip.angle_to(w) * radius)), radius)
					p.sample(q, f)
					if f[WorldPlan.S_KEEP] > 0.0 or f[WorldPlan.S_CANYON] < INF or t._cliff_share(q, f) < CLIFF_SHARE_LEAST:
						continue
					if not counted:
						corners += 1
						counted = true
					walks += 1
					var above := false
					var crossings := 0
					var m := 0.0
					while m < FOLD_LOOK:
						var shore := p.map.at(WorldPlan.S_SHORE, q)
						if shore >= WorldTerrain.CLIFF_BAY:
							break
						if (shore >= t._cliff_line(q)) != above:
							above = not above
							crossings += 1
						var rise := _shore_rise(p, q, radius)
						if rise.length_squared() < 1e-8:
							break
						q = _across(q, rise.normalized(), FOLD_STEP, radius)
						m += FOLD_STEP
					if crossings > 1:
						folds += 1
		gut.p("%s: %d walks up from %d convex corners of cliff coast, %d folded" % [r.name, walks, corners, folds])
		assert_gt(walks, 0, "%s: walks from convex corners of its cliff coasts" % r.name)
		assert_eq(folds, 0, "%s: walks that fall back under the cliff line" % r.name)

## A cliff coast is seamless: where a cell's edge or a cube face's edge crosses a
## cliff's face, and along the coast where the line turns between headland and
## bay, the ground steps from one metre to the next no more than the face's own
## fall over that metre allows: the cliff's height over the sea (the most along
## the way) times what S_SHORE and the line (WorldTerrain._cliff_line) move in it,
## over CLIFF_RUN, and SEAM_SLACK more for the ground's own slope. And the line,
## read at the water's edge each point faces (WorldTerrain._shore_point), moves
## no more than LINE_STEP_MOST in a metre, so no Newton step there overshoots to
## another shore's bays; S_SHORE no more than SHORE_STEP_MOST (the plan's field,
## drawn out over a cell: 1.62 by a cube's corner on TOMERKA-79). On the cliff
## coasts (_on_cliff_coast) of WADIS and the worlds of SEAM_SEEDS (WADIS's coasts
## never cross a face's edge; theirs do, SEAM_FACE_EDGES_LEAST times or more; and
## TOMERKA-79's and KASEN-88's cells are under CLIFF_BAY, WorldTerrain.bay_depth),
## from every point where a cell's edge crosses the line (_seam_crossings),
## SEAM_HALF metres either way at 1 m across the edge and down the shore's fall;
## and along the coast, the contour of S_SHORE through every SEAM_ALONG-th of
## them, SEAM_HALF_ALONG metres either way. (The line moves up to 6.6 m in a
## metre on TAROR-91, where it slides round a convex corner, and 6.9 on KASEN-88;
## a Newton step of twice its length moved it 15 to 106 m, a beach a twentieth
## short of whole within CLIFF_IN less CLIFF_RUN of the water stepped 2.9 m over
## the face's fall, and bays CLIFF_BAY deep moved it 32.6 on TOMERKA-79 and 145
## on KASEN-88, 0.8 of a cell deep 20.9 on KASEN-88.)
const SEAM_SEEDS := [139, 248, 71, 1812]
const SEAM_HALF := 30
const SEAM_ALONG := 5
const SEAM_HALF_ALONG := 150
const SEAM_SLACK := 1.0
const LINE_STEP_MOST := 10.0
const SHORE_STEP_MOST := 1.8
const SEAM_FACE_EDGES_LEAST := 3

func test_a_cliff_coast_is_seamless_over_cell_and_face_edges():
	var recipes: Array[WorldRecipe] = [_wadis()]
	for s: int in SEAM_SEEDS:
		recipes.append(WorldRecipe.from_seed(s))
	var face_edges := 0
	for r in recipes:
		var seams := _seams(WorldTerrain.new(r))
		var most: Array = seams[3]
		face_edges += seams[1]
		gut.p("%s: %d crossings of the cliff line with cell edges (%d on face edges), the face crossed %d times along the coast; the line moves up to %.2f m in a metre, S_SHORE %.2f, the ground over the face's fall by %.2f m" % [
			r.name, seams[0], seams[1], seams[2], most[0], most[1], most[2]])
		assert_gt(seams[0], 0, "%s: cell edges crossing its cliff lines" % r.name)
		assert_gt(seams[2], 0, "%s: the face crossed along the coast" % r.name)
		assert_eq(seams[4], 0, "%s: metre steps by cliff lines over the face's fall, LINE_STEP_MOST or SHORE_STEP_MOST" % r.name)
	assert_gte(face_edges, SEAM_FACE_EDGES_LEAST, "cube face edges crossing cliff lines")

## test_a_cliff_coast_is_seamless's walks over `t`'s cliff coasts: [crossings,
## those on face edges, the face's crossings along the coast, [the line's largest
## metre step, S_SHORE's, the ground's most over the face's fall], the steps
## that break its bounds]. Each walk keeps to the cliff coast (_on_cliff_coast,
## either kind) about its crossing: off it, a plateau's edge band steps down in
## its own sheer terraces.
func _seams(t: WorldTerrain) -> Array:
	var p := t.plan
	var radius := t.radius
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var on_coast := func(d: Vector3) -> bool:
		return _on_cliff_coast(p, d, &"range", f) or _on_cliff_coast(p, d, &"plateau", f)
	var crossings := _seam_crossings(t)
	var most := [0.0, 0.0, -INF]
	var bad := 0
	var turns := 0
	var on_faces := 0
	for i in crossings.size():
		var q: Vector3 = crossings[i][0]
		if crossings[i][2]:
			on_faces += 1
		for way: Vector3 in [q.cross(crossings[i][1]).normalized(), _shore_fall(p, q, radius)]:
			var path: Array[Vector3] = [q]
			for side in [-1, 1]:
				for m in range(1, SEAM_HALF + 1):
					var at := _across(q, way, side * m, radius)
					if not on_coast.call(at):
						break
					if side < 0:
						path.push_front(at)
					else:
						path.append(at)
			bad += _seam_steps(t, path, most)
		if i % SEAM_ALONG != 0:
			continue
		# Along the coast: the contour through q, back then on.
		var shore := p.map.at(WorldPlan.S_SHORE, q)
		var coast: Array[Vector3] = [q]
		for side: float in [-1.0, 1.0]:
			var at := q
			for m in SEAM_HALF_ALONG:
				var along := at.cross(_shore_rise(p, at, radius)).normalized() * side
				at = _onto_shore(p, _across(at, along, 1.0, radius), radius, shore)
				if not on_coast.call(at):
					break
				if side < 0.0:
					coast.push_front(at)
				else:
					coast.append(at)
		for k in coast.size() - 1:
			if (p.map.at(WorldPlan.S_SHORE, coast[k]) >= t._cliff_line(coast[k])) \
					!= (p.map.at(WorldPlan.S_SHORE, coast[k + 1]) >= t._cliff_line(coast[k + 1])):
				turns += 1
		bad += _seam_steps(t, coast, most)
	return [crossings.size(), on_faces, turns, most, bad]

## [point, the edge's unit tangent there, whether the edge is a cube face's]:
## where a cell's edge crosses the cliff line (S_SHORE at WorldTerrain._cliff_line)
## on a cliff coast of either kind (_on_cliff_coast), to a few millimetres. Over
## the edges of cells within 1.5 km of the water with a range or plateau near
## (as _cliff_spots draws from) whose corners' S_SHORE spans CLIFF_IN to
## CLIFF_BAY in part, each edge once, tried at sixteen points along it.
func _seam_crossings(t: WorldTerrain) -> Array:
	var p := t.plan
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var off_line := func(d: Vector3) -> float: return p.map.at(WorldPlan.S_SHORE, d) - t._cliff_line(d)
	var out := []
	var seen := {}
	for index in CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS:
		var key := PlanShapes.cell_key(index)
		var rr := CubeSphere.node_rect(key)
		p.sample(CubeSphere.direction(key.x, rr.x + 0.5 * rr.z, rr.y + 0.5 * rr.z), f)
		if absf(f[WorldPlan.S_SHORE]) >= 1500.0 or f[WorldPlan.S_PLATEAU] <= 0.0 and f[WorldPlan.S_MOUNTAIN] <= 0.0:
			continue
		for e: Array in [[0, 1], [2, 3], [0, 2], [1, 3]]:
			var a := Vector2(rr.x + (e[0] & 1) * rr.z, rr.y + (e[0] >> 1) * rr.z)
			var b := Vector2(rr.x + (e[1] & 1) * rr.z, rr.y + (e[1] >> 1) * rr.z)
			var da := CubeSphere.direction(key.x, a.x, a.y)
			var db := CubeSphere.direction(key.x, b.x, b.y)
			var sa := p.map.at(WorldPlan.S_SHORE, da)
			var sb := p.map.at(WorldPlan.S_SHORE, db)
			if minf(sa, sb) >= WorldTerrain.CLIFF_BAY or maxf(sa, sb) <= WorldTerrain.CLIFF_IN:
				continue
			var mid := (da + db).normalized()
			var id := Vector3i(roundi(mid.x * 1e6), roundi(mid.y * 1e6), roundi(mid.z * 1e6))
			if seen.has(id):
				continue
			seen[id] = true
			var on_face := a.x == b.x and absf(a.x) == 1.0 or a.y == b.y and absf(a.y) == 1.0
			var tangent := db - da
			var prev: float = off_line.call(da)
			for k in range(1, 17):
				var now: float = off_line.call(CubeSphere.direction(key.x, lerpf(a.x, b.x, k / 16.0), lerpf(a.y, b.y, k / 16.0)))
				if (prev > 0.0) != (now > 0.0):
					var lo := (k - 1) / 16.0
					var hi := k / 16.0
					var low_above := prev > 0.0
					for i in 30:
						var half_way := 0.5 * (lo + hi)
						if (off_line.call(CubeSphere.direction(key.x, lerpf(a.x, b.x, half_way), lerpf(a.y, b.y, half_way))) > 0.0) == low_above:
							lo = half_way
						else:
							hi = half_way
					var w := 0.5 * (lo + hi)
					var q := CubeSphere.direction(key.x, lerpf(a.x, b.x, w), lerpf(a.y, b.y, w))
					if _on_cliff_coast(p, q, &"range", f) or _on_cliff_coast(p, q, &"plateau", f):
						out.append([q, (tangent - q * q.dot(tangent)).normalized(), on_face])
				prev = now
	return out

## How many of the metre steps along `path` break test_a_cliff_coast_is_seamless's
## bounds; `most` keeps [the line's largest step, S_SHORE's, and the ground's most
## over the face's fall]. The cliff's height is the highest ground along the way:
## each runs through a crossing, where the ground stands at the cliff's top. The
## line and S_SHORE are read where height_at reads the ground, `d` normalised once
## more: on a face a few millimetres' rounding is a metre or more of height.
func _seam_steps(t: WorldTerrain, path: Array[Vector3], most: Array) -> int:
	var p := t.plan
	var heights: Array[float] = []
	var lines: Array[float] = []
	var shores: Array[float] = []
	for d in path:
		heights.append(t.height_at(d))
		lines.append(t._cliff_line(d.normalized()))
		shores.append(p.map.at(WorldPlan.S_SHORE, d.normalized()))
	var face: float = heights.max() - p.sea_level
	var bad := 0
	for k in path.size() - 1:
		var line := absf(lines[k + 1] - lines[k])
		var shore := absf(shores[k + 1] - shores[k])
		var over := absf(heights[k + 1] - heights[k]) - face * (line + shore) / WorldTerrain.CLIFF_RUN
		most[0] = maxf(most[0], line)
		most[1] = maxf(most[1], shore)
		most[2] = maxf(most[2], over)
		if line > LINE_STEP_MOST or shore > SHORE_STEP_MOST or over > SEAM_SLACK:
			bad += 1
	return bad

## A sea cliff's bay lays its beach a little over sea level up to the world's bay
## depth (WorldTerrain.bay_depth) of S_SHORE inland of the water
## (WorldTerrain._beach), and where a world's cells are small a cell can lie all
## on land within it: PlanBounds holds every cell with a corner under the bay
## depth down to sea level. With bays CLIFF_BAY deep, 53 such cells of
## TOMERKA-79 (BAY_BOUNDS_SEED, 15.7 km across, cells of 386 m) stood over it
## without that; with bays no deeper than its cells allow, none on it or on
## fifteen more worlds of 15 to 55 km, so this holds the beach to the bounds
## however PlanBounds comes to.
const BAY_BOUNDS_SEED := 71

func test_the_bounds_hold_a_bays_beach_where_cells_are_small():
	var r := WorldRecipe.from_seed(BAY_BOUNDS_SEED)
	var p := r.plan()
	var bay := WorldTerrain.bay_depth(r.radius_m)
	var nearest := PackedFloat32Array()
	var farthest := PackedFloat32Array()
	p.map.cell_range(WorldPlan.S_SHORE, nearest, farthest)
	var near := 0
	var dry := 0
	var over := 0
	for index in nearest.size():
		if nearest[index] >= bay:
			continue
		near += 1
		if nearest[index] >= 0.0:
			dry += 1
		if p.bounds_of(PlanShapes.cell_key(index)).x > p.sea_level:
			over += 1
	gut.p("%d cells with a corner within %.0f m of the water, %d of them all on land" % [near, bay, dry])
	assert_gt(dry, 0, "cells all on land within the bay depth of the water")
	assert_eq(over, 0, "cells within the bay depth of the water whose low bound stands over sea level")

## On land, just off the water: the S_SHORE a walk along a coast keeps to.
const WALK_SHORE := 2.0
## A walk's steps between its points, and the most it looks for a cliff's face.
const WALK_STRIDE := 10.0
const CLIFF_LOOK_M := 1500.0

## Up to `n` walks along coasts of `kind` (&"range" or &"plateau") where the land
## meets the sea in a cliff: each from a seeded spot of _cliff_spots, set on its
## water's edge, WANDER_WALK metres along the coast with a point every
## WANDER_STEP, the land on its left or, if that way leaves the cliff coast before
## the end, on its right; a spot whose walk leaves it both ways is passed over.
func _cliff_walks(t: WorldTerrain, kind: StringName, n: int) -> Array:
	var out := []
	for d in _cliff_spots(t, CLIFF_SPOTS, kind):
		var walk := _coast_walk(t, d, 1.0, kind)
		if walk.is_empty():
			walk = _coast_walk(t, d, -1.0, kind)
		if not walk.is_empty():
			out.append(walk)
			if out.size() == n:
				break
	return out

## A walk along the water's edge (S_SHORE at WALK_SHORE) from `d`, WALK_STRIDE
## metres at a time, the land on its left if `way` is 1 and on its right if -1: a
## point every WANDER_STEP over WANDER_WALK, each on a cliff coast of `kind`
## (_on_cliff_coast); empty if it leaves one first.
func _coast_walk(t: WorldTerrain, d: Vector3, way: float, kind: StringName) -> Array[Vector3]:
	var p := t.plan
	var radius := t.radius
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var q := _onto_shore(p, d, radius)
	var out: Array[Vector3] = [q]
	var gone := 0.0
	while out.size() <= int(WANDER_WALK / WANDER_STEP):
		var along := q.cross(_shore_rise(p, q, radius)).normalized() * way
		q = _onto_shore(p, _across(q, along, WALK_STRIDE, radius), radius)
		gone += WALK_STRIDE
		if gone >= out.size() * WANDER_STEP - 0.5 * WALK_STRIDE:
			if not _on_cliff_coast(p, q, kind, f):
				return []
			out.append(q)
	return out

## Whether `d` is on a coast of `kind` where the land meets the sea in a cliff,
## as _cliff_spots counts one (a plateau's top, or a range's weight held to the
## water half or more), out of the kept discs and the canyons.
func _on_cliff_coast(p: WorldPlan, d: Vector3, kind: StringName, f: PackedFloat64Array) -> bool:
	p.sample(d, f)
	if f[WorldPlan.S_KEEP] > 0.0 or f[WorldPlan.S_CANYON] < INF:
		return false
	if kind == &"plateau":
		return f[WorldPlan.S_PLATEAU] >= 1.0
	return p.map.held(WorldPlan.S_MOUNTAIN, WorldPlan.S_SHORE, d) >= 0.5

## `d` moved along the shore's rise to where S_SHORE is `shore` (WALK_SHORE).
func _onto_shore(p: WorldPlan, d: Vector3, radius: float, shore := WALK_SHORE) -> Vector3:
	for i in 8:
		var off := p.map.at(WorldPlan.S_SHORE, d) - shore
		if absf(off) < 0.01:
			break
		var rise := _shore_rise(p, d, radius)
		if rise.length_squared() < 1e-8:
			break
		d = _across(d, rise.normalized(), -off / rise.length(), radius)
	return d

## The plan's S_SHORE's rise at `d`, per metre, as a tangent: inland.
func _shore_rise(p: WorldPlan, d: Vector3, radius: float) -> Vector3:
	var e1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := d.cross(e1)
	var gx := p.map.at(WorldPlan.S_SHORE, _across(d, e1, 1.0, radius)) - p.map.at(WorldPlan.S_SHORE, _across(d, e1, -1.0, radius))
	var gy := p.map.at(WorldPlan.S_SHORE, _across(d, e2, 1.0, radius)) - p.map.at(WorldPlan.S_SHORE, _across(d, e2, -1.0, radius))
	return (e1 * gx + e2 * gy) * 0.5

## [metres, unit tangent at `q`]: how far from `q`, on the water's edge, the
## nearest point of a cliff's face stands, and the way to it. Over a fan of rays
## round the shore's rise, 75° either way in 15° steps (nearest the rise first),
## the first point each reaches, to half a metre, where the ground stands half
## CLIFF_DROP over the sea; INF if none within CLIFF_LOOK_M.
func _cliff_line_from(t: WorldTerrain, q: Vector3) -> Array:
	var p := t.plan
	var radius := t.radius
	var up := _shore_rise(p, q, radius).normalized()
	var side := q.cross(up).normalized()
	var over := p.sea_level + 0.5 * CLIFF_DROP
	var best := INF
	var best_way := up
	for k in 11:
		var a := deg_to_rad(15.0 * ((k + 1) >> 1) * (1.0 if k % 2 == 1 else -1.0))
		var way := (up * cos(a) + side * sin(a)).normalized()
		var m := 0.0
		while m <= minf(best, CLIFF_LOOK_M):
			if t.height_at(_across(q, way, m, radius)) >= over:
				var lo := maxf(m - 5.0, 0.0)
				var hi := m
				while hi - lo > 0.5:
					var mid := 0.5 * (lo + hi)
					if t.height_at(_across(q, way, mid, radius)) >= over:
						hi = mid
					else:
						lo = mid
				if hi < best:
					best = hi
					best_way = way
				break
			m += 5.0
	return [best, best_way]

func test_canyon_walls_step_up_and_meet_the_ground_with_no_seam():
	var t := WorldTerrain.new(_wadis())
	var p := t.plan
	var radius := t.radius
	var rng := RandomNumberGenerator.new(); rng.seed = 89
	var kinds := {}
	var walls := 0
	var profiles := 0
	while profiles < 120:
		# Half the profiles from a point of a path, half from between two, where
		# the floor and rim are lerped.
		var c: Dictionary = p.shapes.canyons[rng.randi_range(0, p.shapes.canyons.size() - 1)]
		var path: PackedVector3Array = c.path
		var i := rng.randi_range(1, path.size() - 2)
		var along := 0.0 if profiles % 2 == 0 else rng.randf()
		var at := path[i].lerp(path[i + 1], along).normalized()
		var ahead := path[i + 1] - path[i - 1] if along == 0.0 else path[i + 1] - path[i]
		var across := at.cross(ahead).normalized()
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var reach: float = lerpf(c.half_floor[i], c.half_floor[i + 1], along) \
			+ lerpf(c.rim[i], c.rim[i + 1], along) * WorldPlan.CANYON_WALL_RUN
		if p.keep_weight(at) > 0.0:
			continue
		profiles += 1
		var inside := _across(at, across, side * (reach - 0.05), radius)
		var outside := _across(at, across, side * (reach + 0.05), radius)
		assert_almost_eq(t.height_at(inside), t.height_at(outside), 0.25, "the ground where the walls end")
		var m: float = lerpf(c.half_floor[i], c.half_floor[i + 1], along) + 1.0
		while m < reach - 1.0:
			var g := t.ground_at(_across(at, across, side * m, radius), 0.0)
			kinds[g] = kinds.get(g, 0) + 1
			walls += 1
			m += 2.0
	gut.p("colours across canyon walls: %s" % kinds)
	assert_gt(kinds.get(&"rock", 0), walls / 10, "the walls' risers are rock")
	assert_gt(kinds.get(&"ground_high", 0), walls / 10, "their ledges ground_high")

## The heights of `t` at `n` seeded directions, even over the sphere.
func _heights(t: WorldTerrain, n: int) -> Array[float]:
	var rng := RandomNumberGenerator.new(); rng.seed = 27
	var out: Array[float] = []
	for k in n:
		out.append(t.height_at(_dir(rng)))
	return out

## `n` seeded points in the disc of `radius_m` round `centre`, even over its area.
func _disc_points(centre: Vector3, radius_m: float, n: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new(); rng.seed = 33
	var radius := _wadis().radius_m
	var out: Array[Vector3] = []
	for k in n:
		out.append(_off_by(centre, sqrt(rng.randf()) * radius_m, rng.randf() * TAU, radius))
	return out

## As _off_by, `m` metres from `centre` on bearing `bearing` on a world of
## `radius`, but worked out in 64-bit floats and only then made a Vector3: so
## points a metre apart are a metre apart to under a millimetre (_off_by turns
## 32-bit vectors, a few millimetres out on WADIS).
func _at(centre: Vector3, m: float, bearing: float, radius: float) -> Vector3:
	var n := sqrt(centre.x * centre.x + centre.y * centre.y + centre.z * centre.z)
	var cx := centre.x / n
	var cy := centre.y / n
	var cz := centre.z / n
	# East, centre x UP (or x RIGHT at a pole), then north, centre x east.
	var ex := -cz
	var ey := 0.0
	var ez := cx
	if ex * ex + ez * ez < 1e-6:
		ex = 0.0; ey = cz; ez = -cy
	var en := sqrt(ex * ex + ey * ey + ez * ez)
	ex /= en; ey /= en; ez /= en
	var nx := cy * ez - cz * ey
	var ny := cz * ex - cx * ez
	var nz := cx * ey - cy * ex
	var tx := ex * cos(bearing) + nx * sin(bearing)
	var ty := ey * cos(bearing) + ny * sin(bearing)
	var tz := ez * cos(bearing) + nz * sin(bearing)
	var a := m / radius
	return Vector3(cx * cos(a) + tx * sin(a), cy * cos(a) + ty * sin(a), cz * cos(a) + tz * sin(a))

## The direction `metres` from `from` on a world of `radius`, on bearing `bearing`.
func _off_by(from: Vector3, metres: float, bearing: float, radius: float) -> Vector3:
	return WorldPlan._toward(from, metres / radius, bearing)

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

## WADIS's ground at `d`, as its terrain draws it.
func _ground(d: Vector3) -> float:
	if _wadis_terrain == null:
		_wadis_terrain = WorldTerrain.new(_wadis())
	return _wadis_terrain.height_at(d)

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
## stands lowest at `d` (its floor, and its stepped walls' rise past the
## floor's edge, PlanShapes.wall_rise).
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
				cut = bed + PlanShapes.wall_rise(metres - half)
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

## `n` seeded directions, even over the sphere.
func _dirs(n: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new(); rng.seed = 61
	var out: Array[Vector3] = []
	for k in n:
		out.append(_dir(rng))
	return out

## Points on a canyon's floor are no nearer its edge than this share of its
## half-width (at least 11 m on the narrowest floor: past a 5 m slope's reach).
const FLOOR_IN := 0.85

## `n` seeded points on `p`'s canyon floors: each a seeded point of a seeded
## canyon's path moved across it up to FLOOR_IN of its floor's half-width, kept
## where the plan has it on a floor (S_CANYON FLOOR_IN or less), out of every
## kept disc.
func _canyon_floor_points(p: WorldPlan, n: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new(); rng.seed = 71
	var radius := p.shapes.radius_m
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var out: Array[Vector3] = []
	while out.size() < n:
		var c: Dictionary = p.shapes.canyons[rng.randi_range(0, p.shapes.canyons.size() - 1)]
		var path: PackedVector3Array = c.path
		var s := rng.randi_range(0, path.size() - 2)
		var t := rng.randf()
		var q := path[s].lerp(path[s + 1], t).normalized()
		var across := q.cross(path[s + 1] - path[s]).normalized()
		var off: float = rng.randf_range(-FLOOR_IN, FLOOR_IN) * lerpf(c.half_floor[s], c.half_floor[s + 1], t) / radius
		var d := (q * cos(off) + across * sin(off)).normalized()
		p.sample(d, f)
		if f[WorldPlan.S_CANYON] <= FLOOR_IN and f[WorldPlan.S_KEEP] == 0.0:
			out.append(d)
	return out

## The slope of `t`'s ground at `d`, radians: from its heights `step` metres
## either way along two bearings at right angles.
func _slope(t: WorldTerrain, d: Vector3, step: float) -> float:
	var r := t.radius
	var gx := (t.height_at(_at(d, step, 0.0, r)) - t.height_at(_at(d, step, PI, r))) / (2.0 * step)
	var gy := (t.height_at(_at(d, step, 0.5 * PI, r)) - t.height_at(_at(d, step, 1.5 * PI, r))) / (2.0 * step)
	return atan(sqrt(gx * gx + gy * gy))

## The unit direction `metres` from the unit direction `at` along the great
## circle toward the unit tangent `across` (backward for negative metres), on a
## world of `radius` metres.
func _across(at: Vector3, across: Vector3, metres: float, radius: float) -> Vector3:
	return (at * cos(metres / radius) + across * sin(metres / radius)).normalized()

## Quadtree nodes of `t`'s world to hold its ground to the plan's bounds: `n`
## seeded ones spread over `depths`, and at depths 8 and 10 the nodes round
## SPOTS seeded points of each kind where the detail is most or the land changes:
## on the coast (where the water's edge crosses a cell), on a coast where a range
## or plateau meets the sea, across a canyon's walls, on a plateau's edge band and
## on a range's flanks.
const SPOTS := 40

func _keys_at_depths(t: WorldTerrain, depths: Array, n: int) -> Array[Vector4i]:
	var rng := RandomNumberGenerator.new(); rng.seed = 73
	var p := t.plan
	var radius := t.radius
	var out: Array[Vector4i] = []
	for k in n:
		out.append(CubeSphere.key_for(_dir(rng), depths[k % depths.size()]))
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	var kinds := {
		"coast": func() -> bool: return absf(f[WorldPlan.S_SHORE]) < 300.0,
		"cliff": func() -> bool: return absf(f[WorldPlan.S_SHORE]) < 1500.0 \
			and (f[WorldPlan.S_MOUNTAIN] > 0.0 or f[WorldPlan.S_PLATEAU] > 0.0),
		"plateau edge": func() -> bool: return f[WorldPlan.S_PLATEAU] > 0.0 and f[WorldPlan.S_PLATEAU] < 1.0,
		"flanks": func() -> bool: return f[WorldPlan.S_MOUNTAIN] > 0.3,
	}
	var spots: Array[Vector3] = []
	for kind: String in kinds:
		var found := 0
		for k in 200000:
			var d := _dir(rng)
			p.sample(d, f)
			if f[WorldPlan.S_KEEP] == 0.0 and kinds[kind].call():
				spots.append(d)
				found += 1
				if found == SPOTS:
					break
		assert_eq(found, SPOTS, "spots on the %s" % kind)
	# Across canyon walls: out from the floor's edge to the walls' end.
	for k in SPOTS:
		var c: Dictionary = p.shapes.canyons[rng.randi_range(0, p.shapes.canyons.size() - 1)]
		var i := rng.randi_range(1, c.path.size() - 2)
		var at: Vector3 = c.path[i]
		var across: Vector3 = at.cross(c.path[i + 1] - c.path[i - 1]).normalized()
		var out_m: float = rng.randf_range(c.half_floor[i], c.half_floor[i] + c.rim[i] * WorldPlan.CANYON_WALL_RUN)
		var off := (1.0 if rng.randf() < 0.5 else -1.0) * out_m / radius
		spots.append((at * cos(off) + across * sin(off)).normalized())
	# On the cliff line itself, and over its face; and where the line stands
	# BAY_FROM or more inland, on the bay's beach, halfway to the water and by
	# the cliff's foot.
	var bays := 0
	for d in _cliff_spots(t, SPOTS):
		var fall := _shore_fall(p, d, radius)
		var shore := p.map.at(WorldPlan.S_SHORE, d)
		var line := t._cliff_line(d)
		spots.append(d)
		spots.append(_across(d, fall, shore - line + 5.0, radius))
		if line >= BAY_FROM:
			bays += 1
			var foot := line - WorldTerrain.CLIFF_RUN
			spots.append(_across(d, fall, shore - 0.5 * foot, radius))
			spots.append(_across(d, fall, shore - foot + 2.0, radius))
	assert_gt(bays, 4, "spots behind a bay")
	for d in spots:
		for depth in [8, 10]:
			out.append(CubeSphere.key_for(d, depth))
	return out

## `n` points inside the quadtree node `key`, in an even grid off its edges.
func _points_in(key: Vector4i, n: int) -> Array[Vector3]:
	var r := CubeSphere.node_rect(key)
	var side := roundi(sqrt(float(n)))
	var out: Array[Vector3] = []
	for j in side:
		for i in side:
			out.append(CubeSphere.direction(key.x, r.x + (i + 0.5) / side * r.z, r.y + (j + 0.5) / side * r.z))
	return out

## `n` seeded spots over `t`'s open ground (dunes or plains), out of the kept discs.
func _open_ground(t: WorldTerrain, n: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new(); rng.seed = 79
	var out: Array[Vector3] = []
	while out.size() < n:
		var d := _dir(rng)
		var land := t.plan.land_at(d)
		if (land == WorldPlan.Land.DUNES or land == WorldPlan.Land.PLAINS) and t.plan.keep_weight(d) == 0.0:
			out.append(d)
	return out

## Metres between the samples _horizon_feature takes along a bearing.
const HORIZON_STEP := 250.0

## True if, from `altitude` metres over the ground at `d`, something can be
## seen on one of 36 bearings: a sample, every HORIZON_STEP out to as far as the
## plan's highest ground could show over the curve, whose land is not open
## ground (a range, a plateau or the sea, its water at sea level), that a
## canyon's walls reach, or whose ground stands 60 m over the spot's, and whose
## elevation from the eye is HORIZON_CLEAR or more over every nearer sample's.
const HORIZON_CLEAR := 0.05

func _horizon_feature(t: WorldTerrain, d: Vector3, altitude: float) -> bool:
	var p := t.plan
	var r := t.radius
	var here := t.height_at(d)
	var eye := r + here + altitude
	var highest := -INF
	for face in CubeSphere.FACES:
		highest = maxf(highest, p.bounds_of(Vector4i(face, 0, 0, 0)).y)
	var reach := sqrt(2.0 * r * altitude) + sqrt(2.0 * r * maxf(highest - here, 0.0))
	var clear := deg_to_rad(HORIZON_CLEAR)
	var f := PackedFloat64Array(); f.resize(WorldPlan.S_SIZE)
	for b in 36:
		var over := -INF
		var m := HORIZON_STEP
		while m <= reach:
			var q := _at(d, m, deg_to_rad(b * 10.0), r)
			p.sample(q, f)
			var land := WorldPlan.land_in(f)
			var h := t.height_at(q)
			if land == WorldPlan.Land.SEA:
				h = maxf(h, p.sea_level)
			var angle := m / r
			var rise := atan2((r + h) * cos(angle) - eye, (r + h) * sin(angle))
			var feature := (land != WorldPlan.Land.DUNES and land != WorldPlan.Land.PLAINS) \
				or f[WorldPlan.S_CANYON] < INF or h > here + 60.0
			if feature and rise >= over + clear:
				return true
			over = maxf(over, rise)
			m += HORIZON_STEP
	return false

