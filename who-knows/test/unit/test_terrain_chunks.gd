extends GutTest

## One chunk of a world's ground (the world scale spec §5.2, §5.4):
## deterministic, small chunk-relative numbers, edges that meet their
## neighbours across cube faces too, skirts, and collision that is exactly
## the ground drawn.

const N := CubeSphere.QUADS

var _terrain: WorldTerrain

func before_each():
	var r := WorldRecipe.from_seed(1337)
	r.radius_m = 60000.0
	r.relief_m = 1200.0
	_terrain = WorldTerrain.new(r)

func _abs(c: TerrainChunkData, i: int, j: int) -> Vector3:
	return c.grid[j * (N + 1) + i] + Vector3(c.centre)

func test_the_same_key_gives_the_same_chunk():
	var a := TerrainChunkData.build(_terrain, Vector4i(2, 5, 7, 11))
	var b := TerrainChunkData.build(WorldTerrain.new(_terrain.recipe), Vector4i(2, 5, 7, 11))
	assert_eq(a.centre, b.centre)
	assert_eq(a.positions, b.positions)
	assert_eq(a.colours, b.colours)

func test_numbers_are_chunk_sized_and_finite():
	for key in [Vector4i(0, 0, 0, 0), Vector4i(4, 12, 2000, 1000)]:
		var c := TerrainChunkData.build(_terrain, key)
		var reach := CubeSphere.edge_m(_terrain.radius, key.y) * 1.5 + _terrain.relief
		for p in c.positions:
			assert_true(p.is_finite())
			assert_lte(p.length(), reach, "%s: chunk-relative, never world-sized" % key)

func test_neighbours_on_a_face_share_their_edge():
	var a := TerrainChunkData.build(_terrain, Vector4i(1, 6, 20, 30))
	var b := TerrainChunkData.build(_terrain, Vector4i(1, 6, 21, 30))
	for j in N + 1:
		assert_almost_eq(_abs(a, N, j), _abs(b, 0, j), Vector3.ONE * 0.01)

func test_neighbours_across_a_cube_edge_share_their_edge():
	# Face 0's u = +1 edge is face 5's u = -1 edge, with the same v.
	var a := TerrainChunkData.build(_terrain, Vector4i(0, 2, 3, 1))
	var b := TerrainChunkData.build(_terrain, Vector4i(5, 2, 0, 1))
	for j in N + 1:
		assert_almost_eq(_abs(a, N, j), _abs(b, 0, j), Vector3.ONE * 0.01)

func test_ground_then_skirts_and_collision_is_the_ground_drawn():
	var c := TerrainChunkData.build(_terrain, Vector4i(3, 7, 40, 90))
	var ground := N * N * 2 * 3
	var skirts := 4 * N * 4 * 3
	assert_eq(c.positions.size(), ground + skirts)
	assert_eq(c.normals.size(), c.positions.size())
	assert_eq(c.colours.size(), c.positions.size())
	assert_eq(c.faces.size(), ground)
	for k in ground:
		assert_eq(c.faces[k], c.positions[k])

func test_ground_faces_look_outward():
	var c := TerrainChunkData.build(_terrain, Vector4i(4, 9, 300, 200))
	for t in range(0, N * N * 2 * 3, 3):
		var mid := (c.positions[t] + c.positions[t + 1] + c.positions[t + 2]) / 3.0 + Vector3(c.centre)
		assert_gt(c.normals[t].dot(mid.normalized()), 0.0)

func test_a_chunk_builds_in_time():
	var t0 := Time.get_ticks_usec()
	for k in 5:
		TerrainChunkData.build(_terrain, Vector4i(k, 10, 300 + k, 400))
	var ms := (Time.get_ticks_usec() - t0) / 5000.0
	gut.p("a chunk builds in %.1f ms on one thread (spec §5.6: 10 ms)" % ms)
	assert_lt(ms, 40.0, "far over budget: see the spec's fallbacks")
