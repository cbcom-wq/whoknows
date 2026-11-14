extends GutTest

## A world's surface (the world scale spec §5): which chunks are drawn for where you are, and the node that streams them.

const R := 60000.0
const RELIEF := 1200.0

var _depth := CubeSphere.depth_for(R)

func _leaves(altitude: float, was := {}) -> Array:
	return WorldSurface.select(R, RELIEF, _depth, Vector3.UP * (R + altitude), was, {})

func test_from_far_off_a_world_is_a_few_coarse_chunks():
	var leaves: Array[Vector4i] = _leaves(R * 9.0)[0]
	assert_between(leaves.size(), 1, 24)
	for k in leaves:
		assert_lte(k.y, 1)

func test_on_the_ground_the_finest_chunk_is_under_you():
	var leaves: Array[Vector4i] = _leaves(2.0)[0]
	assert_true(leaves.has(CubeSphere.key_for(Vector3.UP, _depth)))

func test_the_chunk_count_stays_in_budget_at_every_height():
	# These are chunks BUILT (leaves selected); the spec's binding budget is chunks IN VIEW (~150, spec §5.6), about a third.
	for altitude in [2.0, 1000.0, 10000.0, 100000.0]:
		var n: int = (_leaves(altitude)[0] as Array).size()
		gut.p("%.0f m up: %d chunks built" % [altitude, n])
		assert_lte(n, 500, "%.0f m up" % altitude)

func test_nothing_behind_the_horizon_is_chosen():
	for k: Vector4i in _leaves(100.0)[0]:
		var b := CubeSphere.node_bound(k, R, RELIEF)
		assert_gt((b[0] as Vector3).normalized().dot(Vector3.UP), 0.0, "%s is on the far side" % k)

func test_leaves_never_overlap():
	var leaves: Array[Vector4i] = _leaves(300.0)[0]
	var set := {}
	for k in leaves:
		set[k] = true
	for k in leaves:
		var p := k
		while p.y > 0:
			p = CubeSphere.parent(p)
			assert_false(set.has(p), "%s and its ancestor %s are both leaves" % [k, p])

func test_a_split_node_stays_split_until_merge():
	# A node between SPLIT and MERGE edges away splits only if it already was.
	var key := Vector4i(2, 4, 8, 8)
	var b := WorldSurface.bound_of(key, R, RELIEF, {})
	var edge := CubeSphere.edge_m(R, key.y)
	var ground: Vector3 = b[2]
	var chord: float = b[3]
	var at := ground + ground.normalized() * (chord + edge * (WorldSurface.SPLIT + WorldSurface.MERGE) * 0.5)
	var fresh: Dictionary = WorldSurface.select(R, RELIEF, _depth, at, {}, {})[1]
	assert_false(fresh.has(key), "not split from fresh")
	var kept: Dictionary = WorldSurface.select(R, RELIEF, _depth, at, {key: true}, {})[1]
	assert_true(kept.has(key), "kept split")

func test_selection_from_the_centre_is_sane():
	var sel := WorldSurface.select(R, RELIEF, _depth, Vector3.ZERO, {}, {})
	for k: Vector4i in sel[0]:
		assert_lte(k.y, _depth)
	assert_eq(WorldSurface.horizon_reach(R, RELIEF, 0.0), INF)

func test_height_at_callable_is_honoured():
	# With a height callable providing +500 m, focus at R + 502 m sees the finest
	# chunk under an off-grid direction as a leaf; without the callable an ancestor
	# stays a leaf (because the ground is then 502 m away, within SPLIT * edge).
	var dir := Vector3(0.31, 0.9, 0.22).normalized()
	var at := dir * (R + 502.0)
	var height_at_func := func(_d: Vector3) -> float: return 500.0
	var key := CubeSphere.key_for(dir, _depth)
	var with_height: Array[Vector4i] = WorldSurface.select(R, RELIEF, _depth, at, {}, {}, height_at_func)[0]
	assert_true(with_height.has(key), "finest chunk is a leaf with height callable")
	var without_height: Array[Vector4i] = WorldSurface.select(R, RELIEF, _depth, at, {}, {})[0]
	assert_false(without_height.has(key), "finest chunk is an ancestor leaf without height callable")

func test_bounds_cache_respects_height_at():
	# A bounds dictionary filled without height_at and later read with one must
	# recompute ground; the lifted ground point (R + 500) is much closer.
	var bounds := {}
	var dir := Vector3(0.31, 0.9, 0.22).normalized()
	var at := dir * (R + 502.0)
	var key := CubeSphere.key_for(dir, _depth)
	var height_at_func := func(_d: Vector3) -> float: return 500.0
	# Fill cache without height_at
	WorldSurface.select(R, RELIEF, _depth, at, {}, bounds)
	# Use same bounds with height_at; ground should be lifted and key should be a leaf
	var with_height: Array[Vector4i] = WorldSurface.select(R, RELIEF, _depth, at, {}, bounds, height_at_func)[0]
	assert_true(with_height.has(key), "finest chunk is a leaf when bounds are reused with height_at")

# --- the node (§5.3, §5.4) ----------------------------------------------------

var _universe: Universe
var _system: SystemRecipe

func after_each():
	WorldSurface.warn_on_floor = true

## Off the cube's grid lines: straight up is where four cells meet, and
## "the chunk under you" would be a tie.
var _up := Vector3(0.31, 0.9, 0.22).normalized()

func _planet() -> SystemBody:
	if _system == null:
		_system = SystemRecipe.from_seed(1337)
	return _system.planets()[0]

func _surface(altitude: float) -> WorldSurface:
	_universe = Universe.new()
	add_child_autofree(_universe)
	var p := _planet()
	var s := WorldSurface.new()
	s.setup(p, _universe)
	add_child_autofree(s)
	s.build_roots()
	var focus := _above(p, s, altitude)
	_universe.origin = focus
	s.update(focus)
	return s

func _above(p: SystemBody, s: WorldSurface, altitude: float) -> UniversePoint:
	return p.point.plus(_up * (p.radius + s.terrain.height_at(_up) + altitude))

func test_a_surface_is_whole_from_its_first_frame():
	_universe = Universe.new()
	add_child_autofree(_universe)
	var s := WorldSurface.new()
	s.setup(_planet(), _universe)
	add_child_autofree(s)
	s.build_roots()
	assert_eq(s.chunk_count(), 6)
	assert_eq(s.visible_chunks().size(), 6)

func test_every_leaf_is_drawn_once_and_nothing_overlaps():
	var s := _surface(500.0)
	s.finish()
	var shown := s.visible_chunks()
	assert_eq(shown.size(), s.leaves.size())
	for k in s.leaves:
		assert_true(shown.has(k), "%s is drawn" % k)
	assert_eq(s.jobs_in_flight(), 0)

func test_chunks_are_members_and_the_surface_never_moves():
	var s := _surface(500.0)
	s.finish()
	assert_false(s.is_in_group(Universe.EXTERIOR_SPACE))
	assert_eq(s.global_transform, Transform3D.IDENTITY)
	# The cover field never moves either; its blocks are members (test_cover_field).
	assert_false(s.cover.is_in_group(Universe.EXTERIOR_SPACE))
	for c in s.get_children():
		if c != s.cover:
			assert_true(c.is_in_group(Universe.EXTERIOR_SPACE), "%s shifts" % c.name)

func test_a_shift_moves_every_chunk_with_the_focus():
	var s := _surface(500.0)
	s.finish()
	var before := {}
	for c: Node3D in s.get_children():
		if c != s.cover:
			before[c.name] = c.global_position
	_universe.shift(Vector3(2000, 0, -1000))
	for c: Node3D in s.get_children():
		if c != s.cover:
			assert_almost_eq(c.global_position, before[c.name] - Vector3(2000, 0, -1000), Vector3.ONE * 0.001)
	assert_eq(s.cover.global_transform, Transform3D.IDENTITY)

func test_climbing_away_merges_chunks():
	var s := _surface(300.0)
	s.finish()
	var low := s.chunk_count()
	var p := _planet()
	var high := _above(p, s, 80000.0)
	s.update(high)
	s.finish()
	assert_lt(s.chunk_count(), low)
	assert_eq(s.visible_chunks().size(), s.leaves.size())

func test_a_surface_freed_mid_build_waits_for_its_jobs():
	var s := _surface(200.0)
	assert_gt(s.jobs_in_flight(), 0, "jobs are out")
	remove_child(s)
	s.free()
	pass_test("freed with jobs in flight, and nothing broke")

## Skimming fast, jobs finish for chunks the focus has already left. Those
## results must go at once and a wanted one must still be made, even with the
## budget spent: once they piled up, sorting them alone took the whole budget,
## nothing was ever made, and the pile grew for ever.
func test_results_nobody_wants_are_dropped_and_a_wanted_one_is_always_made():
	var s := _surface(500.0)
	s.finish()
	var k: Vector4i = s.leaves[0]
	(s._chunks[k] as Node).free()
	s._chunks.erase(k)
	var data := TerrainChunkData.build(s.terrain, k)
	var wanted := {}
	for l in s.leaves:
		wanted[l] = true
	s._done[k] = data
	var stale := 0
	for x in 64:
		for y in 64:
			var other := Vector4i(CubeSphere.face_of(-_up), 6, x, y)
			if not wanted.has(other):
				s._done[other] = data
				stale += 1
	assert_gt(stale, 4000)
	s._apply(0.0)
	assert_true(s._chunks.has(k), "the wanted chunk is made though the deadline has passed")
	assert_true(s._done.is_empty(), "the results nobody wants are gone")

## The bounds cache grows by nearly one node a metre on a long low flight;
## past BOUNDS_KEPT it keeps only what the last selection looked at.
func test_the_bounds_cache_stays_bounded_on_a_long_flight():
	var s := _surface(500.0)
	s.finish()
	var kept := s._bounds.size()
	for i in WorldSurface.BOUNDS_KEPT:
		s._bounds[Vector4i(CubeSphere.face_of(-_up), 14, i, 0)] = [Vector3.ZERO, 1.0, 1.0]
	s.update(_above(_planet(), s, 500.0 + 2.0 * WorldSurface.RESELECT_AFTER))
	assert_lt(s._bounds.size(), kept * 2, "only the last selection's bounds are kept")
	for k in s.leaves:
		assert_true(s._bounds.has(k), "%s's bound is kept" % k)
	s.finish()

## Task 7b: skimming low, chunks are made nearly every tick, and the drawn
## chunks are sorted out only once in PRUNE_TICKS ticks. A chunk made between
## waits hidden, so no tick ever shows a chunk over a shown ancestor (two
## grounds at once), and once the ticks catch up every leaf is drawn once.
func test_low_and_fast_nothing_overlaps_between_prunes():
	var s := _surface(30.0)
	s.finish()
	var p := _planet()
	var along := _up.cross(Vector3.RIGHT).normalized()
	var made_hidden := 0
	for tick in 60:
		# 120 m/s at 60 ticks a second, 30 m over the ground.
		var d := (_up + along * (2.0 * (tick + 1) / p.radius)).normalized()
		var focus := p.point.plus(d * (p.radius + s.terrain.height_at(d) + 30.0))
		var before := s._chunks.size()
		s.update(focus)
		for id: int in s._jobs.values():
			WorkerThreadPool.wait_for_task_completion(id)
		s._jobs.clear()
		var shown := {}
		for k in s.visible_chunks():
			shown[k] = true
		for k: Vector4i in shown:
			assert_false(_shown_above(k, shown), "tick %d: %s shows over a shown ancestor" % [tick, k])
		if s._chunks.size() > before and s._since_prune > 0:
			made_hidden += 1
	gut.p("%d ticks made a chunk between prunes" % made_hidden)
	assert_gt(made_hidden, 0, "some chunk was made between prunes")
	s.finish()
	var shown := s.visible_chunks()
	assert_eq(shown.size(), s.leaves.size())
	for k in s.leaves:
		assert_true(shown.has(k), "%s is drawn once it is all caught up" % k)

static func _shown_above(key: Vector4i, shown: Dictionary) -> bool:
	var k := key
	while k.y > 0:
		k = CubeSphere.parent(k)
		if shown.has(k):
			return true
	return false

# --- solid ground (§5.5) --------------------------------------------------------

func _anchor(s: WorldSurface, altitude: float, mask := BodyProxy.LAYER) -> RigidBody3D:
	var a := RigidBody3D.new()
	a.freeze = true
	a.collision_mask = mask
	a.add_to_group(AsteroidStream.SPACE_ANCHOR)
	a.add_to_group(Universe.EXTERIOR_SPACE)
	add_child_autofree(a)
	a.global_position = _universe.to_engine(_above(_planet(), s, altitude))
	return a

func test_no_keys_from_the_centre_or_far_away():
	var t := WorldTerrain.new(_planet().recipe)
	var d := CubeSphere.depth_for(t.radius)
	assert_eq(TerrainCollider.keys_near(t, d, Vector3.ZERO, 100.0).size(), 0)
	assert_eq(TerrainCollider.keys_near(t, d, Vector3.UP * (t.radius + t.relief + 5000.0), 160.0).size(), 0)

func test_the_ground_under_you_is_among_the_keys_and_they_are_few():
	var t := WorldTerrain.new(_planet().recipe)
	var d := CubeSphere.depth_for(t.radius)
	var local := _up * (t.radius + t.height_at(_up) + 10.0)
	var keys := TerrainCollider.keys_near(t, d, local, 160.0)
	assert_eq(keys[0], CubeSphere.key_for(local, d), "the one under you first")
	# A finest edge is 16-32 m, so 160 m reach is a disc of 6-11 cells' radius: 113 to
	# 380 chunks, 149 here. "A few dozen" (spec §5.5) is the common case, at 64 m.
	assert_lte(keys.size(), 200)
	assert_lt(TerrainCollider.keys_near(t, d, local, TerrainCollider.REACH).size(), keys.size())

## Task 7b: the keys are every cell with ground within the reach along the
## ground, and only those: the window of whole cells round the anchor was up
## to twice the reach's area, every cell of it a body made and freed in low
## flight. Some on a cube edge too.
func test_the_keys_are_the_ground_within_the_reach():
	var t := WorldTerrain.new(_planet().recipe)
	var d := CubeSphere.depth_for(t.radius)
	var edge := CubeSphere.edge_m(t.radius, d)
	var near_edge := Vector3(1.0, 0.31, 0.999).normalized()
	for dir: Vector3 in [_up, near_edge]:
		for reach: float in [TerrainCollider.REACH, 160.0]:
			var local := dir * (t.radius + t.height_at(dir) + 30.0)
			var keys := TerrainCollider.keys_near(t, d, local, reach)
			var have := {}
			for k in keys:
				have[k] = true
			assert_eq(have.size(), keys.size(), "no key twice")
			# Every point within the reach along the ground is in some key.
			var a := dir.cross(Vector3.UP).normalized()
			var b := dir.cross(a)
			var step := edge * 0.25
			var n := int(reach / step)
			var missed := 0
			for j in range(-n, n + 1):
				for i in range(-n, n + 1):
					var off := a * (i * step) + b * (j * step)
					if off.length() > reach:
						continue
					if not have.has(CubeSphere.key_for(dir * t.radius + off, d)):
						missed += 1
			assert_eq(missed, 0, "%s, %.0f m: every cell with ground within the reach" % [dir, reach])
			# And none whose nearest ground lies a cell's width past it.
			var here := dir * t.radius
			for k in keys:
				var r := CubeSphere.node_rect(k)
				var mid := CubeSphere.direction(k.x, r.x + r.z * 0.5, r.y + r.z * 0.5) * t.radius
				assert_lt(here.distance_to(mid), reach + edge, "%s lies within the reach" % k)
			gut.p("%.0f m reach: %d keys" % [reach, keys.size()])

## Fix round 2 of Task 7b: the solid ground is a capsule, 64 m round where
## the anchor is and round its way over the next second. Every cell with
## ground within the reach of that way's ground track is a key, on a face and
## across a cube edge, flying level, slanting down and diving.
func test_the_keys_are_the_ground_within_the_reach_of_the_way():
	var t := WorldTerrain.new(_planet().recipe)
	var d := CubeSphere.depth_for(t.radius)
	var edge := CubeSphere.edge_m(t.radius, d)
	var reach := TerrainCollider.REACH
	var near_edge := Vector3(1.0, 0.31, 0.999).normalized()
	for dir: Vector3 in [_up, near_edge]:
		var east := dir.cross(Vector3.UP).normalized()
		var north := dir.cross(east)
		var local := dir * (t.radius + t.height_at(dir) + 30.0)
		for v: Vector3 in [east * 150.0, (north - east).normalized() * 120.0,
				(east - dir).normalized() * 120.0]:
			var keys := TerrainCollider.keys_along(t, d, local, v * TerrainCollider.LOOKAHEAD, reach)
			var have := {}
			for k in keys:
				have[k] = true
			assert_eq(have.size(), keys.size(), "no key twice")
			var a := local.normalized() * t.radius
			var b := (local + v).normalized() * t.radius
			var step := edge * 0.25
			var n := int((reach + a.distance_to(b)) / step) + 1
			var missed := 0
			var tried := 0
			for j in range(-n, n + 1):
				for i in range(-n, n + 1):
					var g := a + east * (i * step) + north * (j * step)
					if TerrainCollider._to_segment(g, a, b) > reach:
						continue
					tried += 1
					if not have.has(CubeSphere.key_for(g, d)):
						missed += 1
			assert_eq(missed, 0, "%s, %s: every cell with ground within the reach of the way (%d tried)" % [dir, v, tried])
			# And none whose ground lies a cell's width past it.
			for k in keys:
				var r := CubeSphere.node_rect(k)
				var mid := CubeSphere.direction(k.x, r.x + r.z * 0.5, r.y + r.z * 0.5) * t.radius
				assert_lt(TerrainCollider._to_segment(mid, a, b), reach + edge, "%s lies within the reach" % k)
			gut.p("%s at %.0f m/s: %d keys (a still anchor's: %d)" % [dir, v.length(), keys.size(),
				TerrainCollider.keys_near(t, d, local, reach).size()])

## A hull at the speed limit, any way it flies -- level on eight headings,
## slanting down, diving straight at the ground, climbing -- never outruns the
## solid ground: under every point of its way over the next second, and
## round it as far as a hull reaches (20 m), the ground is a key.
func test_a_fast_hull_never_outruns_the_solid_ground():
	var t := WorldTerrain.new(_planet().recipe)
	var d := CubeSphere.depth_for(t.radius)
	var well := 1.0e6
	var near_edge := Vector3(1.0, 0.31, 0.999).normalized()
	var worst := 0
	var cases := 0
	for dir: Vector3 in [_up, near_edge]:
		var east := dir.cross(Vector3.UP).normalized()
		var north := dir.cross(east)
		var ways: Array[Vector3] = [-dir, dir, (east - dir).normalized(), (east - dir * 2.0).normalized()]
		for k in 8:
			ways.append(east.rotated(dir, k * TAU / 8.0))
		for altitude: float in [3.0, 30.0, 64.0, 120.0]:
			var speed := FlightComputer.speed_limit(altitude, well)
			var local := dir * (t.radius + t.height_at(dir) + altitude)
			for way in ways:
				var v := way * speed
				var keys := TerrainCollider.keys_along(t, d, local, v * TerrainCollider.LOOKAHEAD, TerrainCollider.REACH)
				var have := {}
				for k in keys:
					have[k] = true
				var missed := 0
				for i in 41:
					var p := local + v * TerrainCollider.LOOKAHEAD * (i / 40.0)
					if t.altitude_of(p) > TerrainCollider.REACH:
						continue
					var g := p.normalized() * t.radius
					var round_it: Array[Vector3] = [g]
					for q in 8:
						round_it.append(g + east.rotated(dir, q * TAU / 8.0) * 20.0)
					for at in round_it:
						if not have.has(CubeSphere.key_for(at, d)):
							missed += 1
				cases += 1
				worst = maxi(worst, missed)
				assert_eq(missed, 0, "%s, %.0f m up at %.0f m/s along %s: the ground under its way is solid" % [
					dir, altitude, speed, way])
	gut.p("%d ways flown at the speed limit; the most points uncovered on one: %d" % [cases, worst])

## A hull that turns hard is covered on its new heading at once: the keys
## are worked out again when the way's end has moved half an edge, not only
## when the hull has.
func test_a_hard_turn_is_covered_at_once():
	var s := _surface(3000.0)
	var a := _anchor(s, 30.0)
	var t := s.terrain
	var d := s.depth_max
	var east := _up.cross(Vector3.UP).normalized()
	a.linear_velocity = east * 120.0
	s._solid_wanted()
	var before: Dictionary = s._solid_cache[a.get_instance_id()]
	a.linear_velocity = east.rotated(_up, deg_to_rad(2.0)) * 120.0
	s._solid_wanted()
	assert_same(s._solid_cache[a.get_instance_id()], before, "a 2 deg turn keeps the keys")
	var north := _up.cross(east)
	var step := CubeSphere.edge_m(t.radius, d) * 0.25
	for turn: float in [90.0, 180.0, -45.0]:
		var v := east.rotated(_up, deg_to_rad(turn)) * 120.0
		a.linear_velocity = v
		var wanted := s._solid_wanted()
		var local := _universe.to_universe(a.global_position).minus(_planet().point)
		# Every ground point within the reach of the new way's ground track.
		var ga := local.normalized() * t.radius
		var gb := (local + v * TerrainCollider.LOOKAHEAD).normalized() * t.radius
		var n := int((TerrainCollider.REACH + ga.distance_to(gb)) / step) + 1
		var missed := 0
		var tried := 0
		for j in range(-n, n + 1):
			for i in range(-n, n + 1):
				var g := ga + east * (i * step) + north * (j * step)
				if TerrainCollider._to_segment(g, ga, gb) > TerrainCollider.REACH:
					continue
				tried += 1
				if not wanted.has(CubeSphere.key_for(g, d)):
					missed += 1
		assert_eq(missed, 0, "turned %.0f deg: the ground within 64 m of the new way is wanted solid (%d tried)" % [turn, tried])
	a.linear_velocity = Vector3.ZERO
	s.finish()   # no job left holding the surface when it is freed

## Fix round 3 of Task 7b: a dive with the assist off reaches ~2 km/s. The
## way is cut at TRAVEL_MAX, so a 2 km/s pass 30 m up costs a few hundred
## keys at most, and the guarantee holds to the cut: at 300 m/s every point
## of the next second is solid, and past it the 64 m round the hull and the
## first TRAVEL_MAX of the way. Fix round 4: the lead is taken from the
## uncapped speed (LEAD_MAX at 2 km/s), so the keys last a few ticks. The key
## count is the tight guard; the time a loose one (a loaded machine is slow).
func test_a_2_km_s_pass_stays_in_budget():
	var s := _surface(3000.0)
	var a := _anchor(s, 30.0)
	var t := s.terrain
	var d := s.depth_max
	var east := _up.cross(Vector3.UP).normalized()
	var north := _up.cross(east)
	var dt := 1.0 / Engine.physics_ticks_per_second
	var most := 0
	var total := 0
	var peak := 0
	var worked_out := 0
	var ticks := 30
	for way: Vector3 in [east, (east + north).normalized()]:
		a.global_position = _universe.to_engine(_above(_planet(), s, 30.0))
		a.linear_velocity = way * 2100.0
		s._solid_cache.clear()
		var last: Variant = null
		for i in ticks:
			a.global_position += way * 2100.0 * dt
			var t0 := Time.get_ticks_usec()
			s._wanted_solid = s._solid_wanted()
			s._missing()
			var took := Time.get_ticks_usec() - t0
			total += took
			peak = maxi(peak, took)
			most = maxi(most, s._wanted_solid.size())
			var cached: Dictionary = s._solid_cache[a.get_instance_id()]
			if not is_same(cached, last):
				worked_out += 1
				last = cached
				assert_almost_eq((cached.end - cached.local).length(),
					TerrainCollider.TRAVEL_MAX + TerrainCollider.LEAD_MAX, 0.01,
					"at 2 km/s the way is cut at TRAVEL_MAX and led by LEAD_MAX")
	var per_tick := total / float(ticks * 2) / 1000.0
	gut.p("2.1 km/s, 30 m up: %.2f ms a tick on average, %.2f ms at most, for the keys and what is missing; at most %d keys; worked out on %d of %d ticks" % [
		per_tick, peak / 1000.0, most, worked_out, ticks * 2])
	# 169 keys and 16 of 60 measured (fix round 4).
	assert_lt(most, 190, "the keys are bounded")
	assert_lte(worked_out, ticks * 2 / 3, "the keys last a few ticks, not one")
	assert_lt(per_tick, 4.0, "a 2 km/s pass works out its solid ground in a few ms a tick")
	# To the cut, every point of the next second; past it, the hull's own 64 m
	# and the first TRAVEL_MAX of its way.
	var local := _up * (t.radius + t.height_at(_up) + 30.0)
	for speed: float in [TerrainCollider.TRAVEL_MAX, 2100.0]:
		for way: Vector3 in [east, (east - _up).normalized(), -_up]:
			var v := way * speed * TerrainCollider.LOOKAHEAD
			var keys := TerrainCollider.keys_along(t, d, local, v, TerrainCollider.REACH)
			var have := {}
			for k in keys:
				have[k] = true
			for k in TerrainCollider.keys_near(t, d, local, TerrainCollider.REACH):
				assert_true(have.has(k), "%.0f m/s along %s: the 64 m round the hull" % [speed, way])
			var missed := 0
			var reach_m := minf(v.length(), TerrainCollider.TRAVEL_MAX)
			for i in 31:
				var p := local + v.normalized() * reach_m * (i / 30.0)
				if t.altitude_of(p) > TerrainCollider.REACH:
					continue
				if not have.has(CubeSphere.key_for(p, d)):
					missed += 1
			assert_eq(missed, 0, "%.0f m/s along %s: the ground under the first %.0f m of its way" % [speed, way, reach_m])
	a.linear_velocity = Vector3.ZERO
	s.finish()   # no job left holding the surface when it is freed

## A node standing for an anchor of `radius` (its ANCHOR_RADIUS), or of none.
func _sized(radius := -1.0) -> Node:
	var n := Node.new()
	if radius >= 0.0:
		n.set_meta(AsteroidStream.ANCHOR_RADIUS, radius)
	autofree(n)
	return n

## The chunk under a hull is built on the main thread only when it could
## touch the ground within two ticks (fix round 3 of Task 7b), measured from
## its lowest point, ANCHOR_RADIUS under its origin (fix round 4: a hull
## whose stance is over 10 m touched down with its chunk left to workers).
func test_only_an_anchor_near_the_ground_has_its_chunk_built_at_once():
	var s := _surface(3000.0)
	var t := s.terrain
	var east := _up.cross(Vector3.UP).normalized()
	var at := func(h: float) -> Vector3: return _up * (t.radius + t.height_at(_up) + h)
	var tick := 1.0 / Engine.physics_ticks_per_second
	var small := _sized()
	assert_true(s._touching_soon(small, at.call(5.0), Vector3.ZERO), "5 m up and still")
	assert_false(s._touching_soon(small, at.call(30.0), Vector3.ZERO), "30 m up and still: a worker's")
	assert_false(s._touching_soon(small, at.call(30.0), east * 2100.0), "a level pass at 2 km/s, 30 m up")
	assert_true(s._touching_soon(small, at.call(30.0), -_up * 30.0 / tick), "falling 30 m a tick")
	var big := _sized(30.0)
	assert_true(s._touching_soon(big, at.call(30.0), Vector3.ZERO), "a 30 m hull 30 m up stands on the ground")
	assert_true(s._touching_soon(big, at.call(39.0), Vector3.ZERO), "a 30 m hull 39 m up is 9 m off it")
	assert_false(s._touching_soon(big, at.call(45.0), Vector3.ZERO), "a 30 m hull 45 m up is 15 m off it: a worker's")
	assert_true(s._touching_soon(big, at.call(45.0), -_up * 3.0 / tick), "a 30 m hull 45 m up, falling 3 m a tick")
	s.finish()

## Fix round 4 of Task 7b (M3): the build itself, not only the gate. Small
## and 5 m up, the chunk under an anchor is solid after one _solid_wanted;
## the starter's size (24 m) 40 m up, and small 30 m up, it is left to the
## workers; a 30 m hull 30 m up, where a small anchor's would wait, has it
## built at once.
func test_the_chunk_under_a_hull_about_to_touch_is_built_at_once():
	for c: Array in [[-1.0, 5.0, true], [-1.0, 30.0, false], [24.0, 40.0, false], [30.0, 30.0, true]]:
		var s := _surface(3000.0)
		var a := _anchor(s, c[1])
		if c[0] >= 0.0:
			a.set_meta(AsteroidStream.ANCHOR_RADIUS, c[0])
		var local := _universe.to_universe(a.global_position).minus(_planet().point)
		var under := CubeSphere.key_for(local, s.depth_max)
		var wanted := s._solid_wanted()
		assert_true(wanted.has(under), "radius %.0f, %.0f m up: wanted solid" % [c[0], c[1]])
		assert_eq(s.solid_keys().has(under), c[2], "radius %.0f, %.0f m up: %s" % [c[0], c[1],
			"built at once" if c[2] else "left to the workers"])
		s.finish()
		a.remove_from_group(AsteroidStream.SPACE_ANCHOR)   # the next case's surface sees only its own

## Fix round 4 of Task 7b (M4): on a fast slanting arrival the hull hits the
## chunk under where it will be two ticks on, not the one under it now; that
## one is built at once too.
func test_a_fast_slanting_arrival_has_the_chunk_it_will_hit_built_at_once():
	var s := _surface(3000.0)
	var a := _anchor(s, 5.0)
	var east := _up.cross(Vector3.UP).normalized()
	var tick := 1.0 / Engine.physics_ticks_per_second
	var local := _universe.to_universe(a.global_position).minus(_planet().point)
	var under := CubeSphere.key_for(local, s.depth_max)
	# Some heading 33 m a tick sideways crosses into a neighbour in two ticks.
	var v := Vector3.ZERO
	var ahead := under
	for k in 8:
		v = east.rotated(_up, k * TAU / 8.0) * 33.0 / tick - _up * 1.0 / tick
		ahead = CubeSphere.key_for(local + v * 2.0 * tick, s.depth_max)
		if ahead != under:
			break
	assert_ne(ahead, under, "a heading whose two ticks cross a chunk's edge")
	a.linear_velocity = v
	var wanted := s._solid_wanted()
	assert_true(wanted.has(ahead), "the chunk it will hit is wanted")
	assert_true(s.solid_keys().has(under), "the chunk under it is built at once")
	assert_true(s.solid_keys().has(ahead), "the chunk it will hit is built at once")
	a.linear_velocity = Vector3.ZERO
	s.finish()

## The keys are worked out again only once an anchor has moved half a
## finest edge; until then the ground within the reach of where it is now,
## not where they were worked out, must still be solid (fix round 1 of
## Task 7b: cut at exactly the reach, it shrank to ~48 m ahead).
func test_the_reach_holds_until_the_keys_are_worked_out_again():
	var s := _surface(3000.0)
	var a := _anchor(s, 20.0)
	var t := s.terrain
	var d := s.depth_max
	var edge := CubeSphere.edge_m(t.radius, d)
	var reach := TerrainCollider.REACH
	s._solid_wanted()
	var a_dir := _up.cross(Vector3.UP).normalized()
	var b_dir := _up.cross(a_dir)
	var worst := 0
	for heading: Vector3 in [a_dir, -a_dir, b_dir, -b_dir, (a_dir + b_dir).normalized()]:
		var start := _universe.to_engine(_above(_planet(), s, 20.0))
		a.global_position = start + heading * edge * 0.49
		var wanted := s._solid_wanted()
		var local := _universe.to_universe(a.global_position).minus(_planet().point)
		var dir := local.normalized()
		var step := edge * 0.25
		var n := int(reach / step)
		var missed := 0
		for j in range(-n, n + 1):
			for i in range(-n, n + 1):
				var off := a_dir * (i * step) + b_dir * (j * step)
				if off.length() > reach:
					continue
				if not wanted.has(CubeSphere.key_for(dir * t.radius + off, d)):
					missed += 1
		worst = maxi(worst, missed)
		a.global_position = start
		s._solid_wanted()
	assert_eq(worst, 0, "every point within the reach of where the anchor is now is wanted solid")
	s.finish()   # no job left holding the surface when it is freed

func test_an_anchor_near_the_ground_has_solid_ground_round_it():
	var s := _surface(3000.0)
	var a := _anchor(s, 20.0)
	s.update(_universe.to_universe(a.global_position))
	s.finish()
	var solid := s.solid_keys()
	assert_gt(solid.size(), 0)
	var bodies := s.get_children().filter(func(n: Node) -> bool: return n is StaticBody3D)
	# Kept bodies (fix round 2 of Task 7b) hold no shape; the rest one each.
	var holding := bodies.filter(func(b: StaticBody3D) -> bool:
		return (b.get_child(0) as CollisionShape3D).shape != null)
	assert_eq(holding.size(), solid.size())
	assert_eq(bodies.size() - holding.size(), s.spare_solids())
	for b: StaticBody3D in bodies:
		assert_eq(b.collision_layer, BodyProxy.LAYER)
		assert_eq(b.collision_mask, 0)
		assert_true(b.is_in_group(Universe.EXTERIOR_SPACE))

## A solid let go of is kept and used again: moving on, no new body is made
## while one is kept, none kept holds a shape, and at most SPARE_SOLIDS are.
func test_solid_bodies_are_used_again():
	var s := _surface(3000.0)
	var a := _anchor(s, 20.0)
	s.update(_universe.to_universe(a.global_position))
	s.finish()
	var made := s._solids_made
	var east := _up.cross(Vector3.UP).normalized()
	for step in 6:
		a.global_position += east * 40.0
		s.update(_universe.to_universe(a.global_position))
		s.finish()
		assert_lte(s.spare_solids(), WorldSurface.SPARE_SOLIDS)
		for b: StaticBody3D in s._spare:
			assert_null((b.get_child(0) as CollisionShape3D).shape, "a kept body holds no shape")
			assert_false(s._solid.values().has(b), "a kept body stands for no chunk")
	var solid := s.solid_keys()
	for k in solid:
		var cs := (s._solid[k] as StaticBody3D).get_child(0) as CollisionShape3D
		assert_not_null(cs.shape, "%s is solid" % k)
	var bodies := s.get_children().filter(func(n: Node) -> bool: return n is StaticBody3D)
	assert_eq(bodies.size(), solid.size() + s.spare_solids(), "every body holds a chunk or is kept")
	gut.p("240 m flown: %d bodies made at first, %d in all; %d solid, %d kept" % [
		made, s._solids_made, solid.size(), s.spare_solids()])
	assert_lt(s._solids_made, made + solid.size(), "moving on uses kept bodies, not all new")

func test_an_anchor_arriving_fast_has_ground_under_it():
	var s := _surface(3000.0)
	var a := _anchor(s, 5.0)
	s.update(_universe.to_universe(a.global_position))   # no finish(): this tick
	var under := CubeSphere.key_for(_universe.to_universe(a.global_position).minus(_planet().point), s.depth_max)
	assert_true(s.solid_keys().has(under), "built at once, not waited for")
	s.finish()   # a worker mid-job locks the surface against being freed

func test_an_anchor_under_the_ground_is_lifted_out():
	WorldSurface.warn_on_floor = false
	var s := _surface(3000.0)
	var a := _anchor(s, -20.0)
	a.freeze = false
	var tangent := _up.cross(Vector3.RIGHT).normalized()
	a.linear_velocity = -_up * 30.0 + tangent * 5.0
	s.update(_universe.to_universe(a.global_position))
	WorldSurface.warn_on_floor = true
	var local := _universe.to_universe(a.global_position).minus(_planet().point)
	assert_gte(s.terrain.altitude_of(local), 0.0)
	assert_eq(s.floor_fired, 1)
	var up := local.normalized()
	assert_gte(a.linear_velocity.dot(up), -0.01, "no longer moving in")
	assert_almost_eq(a.linear_velocity.dot(tangent), 5.0, 0.1, "the sideways motion is kept")
	s.finish()

func test_the_chunk_under_you_is_always_first():
	var t := WorldTerrain.new(_planet().recipe)
	var d := CubeSphere.depth_for(t.radius)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 50:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var local := dir * (t.radius + t.height_at(dir) + 3.0)
		var keys := TerrainCollider.keys_near(t, d, local, TerrainCollider.REACH)
		assert_eq(keys[0], CubeSphere.key_for(local, d), "direction %d" % i)

func test_an_anchors_keys_are_kept_until_it_has_moved_half_an_edge():
	var s := _surface(3000.0)
	var a := _anchor(s, 40.0)
	s.update(_universe.to_universe(a.global_position))
	# 40 m up and still, the chunk under it is a worker's (not built at once:
	# see _touching_soon), so the keys it wants are what is checked.
	var first: Array = s._solid_cache[a.get_instance_id()].keys
	var edge := CubeSphere.edge_m(_planet().radius, s.depth_max)
	a.global_position += Vector3(0.1, 0, 0) * edge   # well under half an edge, in the same cell or a neighbour
	var cached_before: Dictionary = s._solid_cache.duplicate(true)
	s.update(_universe.to_universe(a.global_position))
	assert_eq(s._solid_cache[a.get_instance_id()].local, cached_before[a.get_instance_id()].local, "not recomputed")
	a.global_position += Vector3(0.9, 0, 0) * edge
	s.update(_universe.to_universe(a.global_position))
	assert_ne(s._solid_cache[a.get_instance_id()].local, cached_before[a.get_instance_id()].local, "recomputed")
	assert_gt(first.size(), 0)
	a.remove_from_group(AsteroidStream.SPACE_ANCHOR)
	s.update(_universe.to_universe(a.global_position))
	assert_true(s._solid_cache.is_empty(), "a gone anchor is forgotten")
	s.finish()

func test_a_ghosted_hull_is_left_alone():
	var s := _surface(3000.0)
	var a := _anchor(s, -20.0, 0)
	s.update(_universe.to_universe(a.global_position))
	assert_eq(s.floor_fired, 0, "at warp the hull passes through everything")
	s.finish()

# --- the floor at a lip (final review I1) --------------------------------------

## 1337's desert, p3: its mesas' risers are near-sheer, so at a lip the finest
## chunk's triangles cut the convex edge metres under height_at.
func _desert() -> SystemBody:
	if _system == null:
		_system = SystemRecipe.from_seed(1337)
	return _system.body(&"p3")

## A point on the ground the collision has (a finest chunk's triangle, found
## as GroundCover finds it) where that triangle is more than `under` m under
## the analytic ground: on a mesa's or a tower's lip. Body-local; ZERO if none
## is found. The reviewer's search: lines across the mesa line, a step of more
## than 8 m in 2 m is an edge.
static func _a_lip(t: WorldTerrain, under: float) -> Vector3:
	var depth := CubeSphere.depth_for(t.radius)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tried := {}
	for line in 4000:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		if absf(t.continent_at(d) - WorldTerrain.MESA_FROM) > 0.03:
			continue
		var a := d.cross(Vector3.UP).normalized()
		var h0 := t.height_at(d)
		for i in 1500:
			var p := (d + a * (i * 2.0 / t.radius)).normalized()
			var h := t.height_at(p)
			var key := CubeSphere.key_for(p, depth)
			if absf(h - h0) > 8.0 and not tried.has(key):
				tried[key] = true
				var g := GroundCover._Ground.new(t, key, PackedVector3Array())
				var centre := Vector3(TerrainChunkData.centre_of(t, key))
				for j in 16:
					for k in 16:
						var at: Vector3 = g.at((k + 0.5) / 16.0, (j + 0.5) / 16.0).point + centre
						if -t.altitude_of(at) > under:
							return at
			h0 = h
	return Vector3.ZERO

## The ground the collision has, worked out from a point: on a lip it is the
## triangle, metres under height_at; on open ground the same triangle too.
func test_the_solid_altitude_is_the_triangle_under_a_point():
	var t := WorldTerrain.new(_desert().recipe)
	var lip := _a_lip(t, 3.0)
	assert_ne(lip, Vector3.ZERO, "a lip with its triangle 3 m under the analytic ground")
	var up := lip.normalized()
	gut.p("a lip on p3: the triangle %.2f m under height_at" % -t.altitude_of(lip))
	assert_almost_eq(TerrainChunkData.solid_altitude_of(t, lip), 0.0, 0.05, "on the triangle")
	assert_almost_eq(TerrainChunkData.solid_altitude_of(t, lip + up * 2.0), 2.0, 0.05, "2 m over it")
	# Open ground: any point's triangle, as GroundCover finds it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var depth := CubeSphere.depth_for(t.radius)
	for n in 20:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var key := CubeSphere.key_for(d, depth)
		var g := GroundCover._Ground.new(t, key, PackedVector3Array())
		var at: Vector3 = g.at(rng.randf(), rng.randf()).point + Vector3(TerrainChunkData.centre_of(t, key))
		assert_almost_eq(TerrainChunkData.solid_altitude_of(t, at + at.normalized() * 0.5), 0.5, 0.05, "point %d" % n)

## Final review I1: standing on the triangle at a lip, metres under the
## analytic ground, is standing on the ground, not under it: the floor leaves
## the anchor alone. A metre under the triangle there it is still lifted out.
func test_the_floor_leaves_an_anchor_on_the_triangles_at_a_lip_alone():
	var p := _desert()
	_universe = Universe.new()
	add_child_autofree(_universe)
	var s := WorldSurface.new()
	s.setup(p, _universe)
	add_child_autofree(s)
	s.build_roots()
	var lip := _a_lip(s.terrain, 3.0)
	assert_ne(lip, Vector3.ZERO, "a lip found")
	var up := lip.normalized()
	var focus := p.point.plus(lip + up * 1.6)
	_universe.origin = focus
	s.update(focus)
	var a := RigidBody3D.new()
	a.freeze = true
	a.collision_mask = BodyProxy.LAYER
	a.add_to_group(AsteroidStream.SPACE_ANCHOR)
	a.add_to_group(Universe.EXTERIOR_SPACE)
	add_child_autofree(a)
	a.global_position = _universe.to_engine(p.point.plus(lip + up * 0.05))
	for i in 3:
		s.update(focus)
	assert_eq(s.floor_fired, 0, "on the triangle, %.2f m under height_at: left alone" % -s.terrain.altitude_of(lip))
	WorldSurface.warn_on_floor = false
	a.global_position = _universe.to_engine(p.point.plus(lip - up * 1.0))
	s.update(focus)
	WorldSurface.warn_on_floor = true
	assert_eq(s.floor_fired, 1, "a metre under the triangle: lifted out")
	assert_gt(TerrainChunkData.solid_altitude_of(s.terrain, _universe.to_universe(a.global_position).minus(p.point)), 0.0,
		"over the triangle")
	s.finish()

# --- the near-ground gate makes the whole footprint solid (final review I2, M1) --

## An anchor of `radius` (its ANCHOR_RADIUS) at `local` (body-local), frozen.
func _anchor_at(local: Vector3, radius: float) -> RigidBody3D:
	var a := RigidBody3D.new()
	a.freeze = true
	a.collision_mask = BodyProxy.LAYER
	a.set_meta(AsteroidStream.ANCHOR_RADIUS, radius)
	a.add_to_group(AsteroidStream.SPACE_ANCHOR)
	a.add_to_group(Universe.EXTERIOR_SPACE)
	add_child_autofree(a)
	a.global_position = _universe.to_engine(_planet().point.plus(local))
	return a

## The corner of the finest cell under `_up` where four cells meet, and those
## four: [corner direction, keys].
func _a_corner(depth: int) -> Array:
	var t := WorldTerrain.new(_planet().recipe)
	var k := CubeSphere.key_for(_up * t.radius, depth)
	var rect := CubeSphere.node_rect(k)
	var corner := CubeSphere.direction(k.x, rect.x, rect.y)
	var keys: Array[Vector4i] = []
	for dy in 2:
		for dx in 2:
			keys.append(Vector4i(k.x, depth, k.z - dx, k.w - dy))
	return [corner, keys]

## A 30 m hull 12 m up, centred where four cells meet: its footprint covers
## all four, so all four are solid after one _solid_wanted, not only the one
## under its origin (the gate built "under" and "ahead" alone).
func test_a_wide_hull_has_its_whole_footprint_solid_at_once():
	var s := _surface(3000.0)
	var c := _a_corner(s.depth_max)
	var corner: Vector3 = c[0]
	var a := _anchor_at(corner * (s.terrain.radius + s.terrain.height_at(corner) + 12.0), 30.0)
	s._solid_wanted()
	for k: Vector4i in c[1]:
		assert_true(s.solid_keys().has(k), "%s, a corner cell, solid at once" % k)
	a.remove_from_group(AsteroidStream.SPACE_ANCHOR)
	s.finish()

## Final review M1: the gate uses a worker's finished result, or waits on the
## job in flight, before it builds a chunk itself on the main thread.
func test_the_gate_uses_finished_work_before_building():
	var s := _surface(3000.0)
	var c := _a_corner(s.depth_max)
	var keys: Array = c[1]
	# One finished, waiting to be applied; one still on a worker.
	var done := TerrainChunkData.build(s.terrain, keys[0], true)
	done.shape = WorldSurface.shape_of(done)
	s._done[keys[0]] = done
	s._jobs[keys[1]] = WorkerThreadPool.add_task(s._job.bind(keys[1], _planet().recipe, true, true), false, "test chunk")
	var corner: Vector3 = c[0]
	var a := _anchor_at(corner * (s.terrain.radius + s.terrain.height_at(corner) + 12.0), 30.0)
	var built := s.gate_builds
	s._solid_wanted()
	assert_true(s.solid_keys().has(keys[0]) and s.solid_keys().has(keys[1]), "both solid")
	assert_eq((s._solid[keys[0]].get_child(0) as CollisionShape3D).shape, done.shape, "the finished result's own shape")
	assert_false(s._jobs.has(keys[1]), "the job in flight was waited on and taken")
	assert_false(s._done.has(keys[0]) or s._done.has(keys[1]), "and neither is left to apply again")
	var now: Array = s._gate_cache[a.get_instance_id()].now
	gut.p("a 30 m hull 12 m up: %d chunks made solid at once, %d of them built here" % [now.size(), s.gate_builds - built])
	assert_eq(s.gate_builds - built, now.size() - 2, "all but those two were built here")
	a.remove_from_group(AsteroidStream.SPACE_ANCHOR)
	s.finish()

## Within 3 x ARRIVE of the ground the footprint is not built at once, but it
## is first in the workers' queue: a ship woken 18 km from you had its
## footprint queued behind every chunk round you.
func test_a_far_anchor_near_the_ground_has_its_footprint_queued_first():
	_universe = Universe.new()
	add_child_autofree(_universe)
	var p := _planet()
	var s := WorldSurface.new()
	s.setup(p, _universe)
	add_child_autofree(s)
	s.build_roots()
	var focus := _above(p, s, 3.0)
	_universe.origin = focus
	var east := _up.cross(Vector3.UP).normalized()
	var far := (_up + east * (18000.0 / p.radius)).normalized()
	var lowest := WorldSurface.ARRIVE * 2.0
	var a := _anchor_at(far * (s.terrain.radius + s.terrain.height_at(far) + 30.0 + lowest), 30.0)
	s.update(focus)
	var local := _universe.to_universe(a.global_position).minus(p.point)
	# Its footprint and the way of its next two ticks, as wide as the gate
	# works it out (half an edge wider, as the reach is).
	var half_edge := CubeSphere.edge_m(p.radius, s.depth_max) * 0.5
	var want := TerrainCollider.keys_near(s.terrain, s.depth_max, local, 30.0 + WorldSurface.ARRIVE + half_edge, true)
	assert_gt(want.size(), WorldSurface.MAX_JOBS, "more than a queue's worth")
	var queued := 0
	for k: Vector4i in s._jobs:
		if want.has(k):
			queued += 1
	assert_false(s.solid_keys().has(want[0]), "%.0f m over the ground: not built at once" % lowest)
	assert_eq(s.jobs_in_flight(), WorldSurface.MAX_JOBS)
	assert_eq(queued, WorldSurface.MAX_JOBS, "every job in flight is its footprint's (%d of %d)" % [
		queued, s.jobs_in_flight()])
	a.remove_from_group(AsteroidStream.SPACE_ANCHOR)
	s.finish()
