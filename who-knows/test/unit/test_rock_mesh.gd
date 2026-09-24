extends GutTest

## The rock shapes (docs/superpowers/specs/2026-09-24-asteroids-design.md §8):
## chunky, flat-shaded, wound the way Godot draws, within reach, and tinted
## per rock -- except the veined one, which carries its own crystal.

const SHAPES := [RockMesh.Shape.BOULDER, RockMesh.Shape.SHARD, RockMesh.Shape.VEINED]

func _arrays(shape: int, detail: int) -> Array:
	return RockMesh.mesh(shape, detail).surface_get_arrays(0)

func test_detail_sets_the_triangle_count():
	for detail in 3:
		var v: PackedVector3Array = _arrays(RockMesh.Shape.BOULDER, detail)[Mesh.ARRAY_VERTEX]
		assert_eq(v.size() / 3, [20, 80, 320][detail])

func test_every_vertex_is_within_reach():
	var worst := 0.0
	for shape in SHAPES:
		for detail in 3:
			for v in RockMesh.hull_points(shape, detail):
				worst = maxf(worst, v.length())
	assert_lte(worst, RockMesh.REACH + 0.0001)
	assert_gt(worst, 0.45, "and it is a rock of diameter about one")

func test_flat_shaded_and_wound_for_godot():
	var bad := 0
	for shape in SHAPES:
		for detail in 3:
			var a := _arrays(shape, detail)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			for t in range(0, v.size(), 3):
				var face := (v[t + 1] - v[t]).cross(v[t + 2] - v[t])
				if n[t] != n[t + 1] or n[t] != n[t + 2]:
					bad += 1
				elif face.length() > 1e-7 and face.dot(n[t]) >= 0.0:
					bad += 1
				elif n[t].dot(v[t] + v[t + 1] + v[t + 2]) <= 0.0:
					bad += 1
	assert_eq(bad, 0, "every triangle flat, facing out, drawn from outside")

func test_only_the_veined_shape_has_colours_of_its_own():
	for shape in SHAPES:
		var colours: PackedColorArray = _arrays(shape, 1)[Mesh.ARRAY_COLOR]
		var crystal := 0
		var rock := 0
		for c in colours:
			if c == SpacePalette.CRYSTAL:
				crystal += 1
			elif c != SpacePalette.UNTINTED:
				rock += 1
		if shape == RockMesh.Shape.VEINED:
			assert_gt(crystal, 0, "a vein of crystal")
			assert_gt(rock, crystal, "in a rock that is mostly rock")
		else:
			assert_eq(crystal + rock, 0, "white, so each rock's own tint shows")

func test_meshes_are_built_once_and_shared():
	assert_same(RockMesh.mesh(RockMesh.Shape.SHARD, 1), RockMesh.mesh(RockMesh.Shape.SHARD, 1))

func test_hull_points_are_the_distinct_vertices():
	assert_eq(RockMesh.hull_points(RockMesh.Shape.BOULDER, 0).size(), 12)
	assert_eq(RockMesh.hull_points(RockMesh.Shape.BOULDER, 2).size(), 162)

func test_the_cuts_make_facets_not_a_ball():
	var cut := 0
	var pts := RockMesh.hull_points(RockMesh.Shape.BOULDER, 2)
	for p in pts:
		if p.length() < 0.49:
			cut += 1
	assert_gt(cut, pts.size() / 3, "much of the surface lies on flat cuts")
