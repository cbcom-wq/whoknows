extends GutTest

## A world's surface (the world scale spec §5): which chunks are drawn for
## where you are, and (below) the node that streams them.

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
