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
	for c in s.get_children():
		assert_true(c.is_in_group(Universe.EXTERIOR_SPACE), "%s shifts" % c.name)

func test_a_shift_moves_every_chunk_with_the_focus():
	var s := _surface(500.0)
	s.finish()
	var before := {}
	for c: Node3D in s.get_children():
		before[c.name] = c.global_position
	_universe.shift(Vector3(2000, 0, -1000))
	for c: Node3D in s.get_children():
		assert_almost_eq(c.global_position, before[c.name] - Vector3(2000, 0, -1000), Vector3.ONE * 0.001)

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
	var keys := TerrainCollider.keys_near(t, d, local, TerrainCollider.REACH_MAX)
	assert_eq(keys[0], CubeSphere.key_for(local, d), "the one under you first")
	# A finest edge is 16-32 m, so 160 m reach is a disc of 6-11 cells' radius: 113 to
	# 380 chunks, 149 here. "A few dozen" (spec §5.5) is the common case, at 64 m.
	assert_lte(keys.size(), 200)
	assert_lt(TerrainCollider.keys_near(t, d, local, TerrainCollider.REACH).size(), keys.size())

func test_an_anchor_near_the_ground_has_solid_ground_round_it():
	var s := _surface(3000.0)
	var a := _anchor(s, 20.0)
	s.update(_universe.to_universe(a.global_position))
	s.finish()
	var solid := s.solid_keys()
	assert_gt(solid.size(), 0)
	var bodies := s.get_children().filter(func(n: Node) -> bool: return n is StaticBody3D)
	assert_eq(bodies.size(), solid.size())
	for b: StaticBody3D in bodies:
		assert_eq(b.collision_layer, BodyProxy.LAYER)
		assert_eq(b.collision_mask, 0)
		assert_true(b.is_in_group(Universe.EXTERIOR_SPACE))

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
	var first := s.solid_keys()
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
