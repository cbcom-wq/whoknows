extends GutTest

## The star's halo through air (StarHalo): a disc in the star's light that
## fades to nothing at its rim, so it never shows an edge against the sky.

func test_its_alpha_is_zero_at_the_rim():
	var halo := StarHalo.new()
	autofree(halo)
	halo.setup(SpacePalette.STARS[0])
	var arrays := halo.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var rim := 0
	var middle := 0
	for i in verts.size():
		if is_equal_approx(verts[i].length(), 1.0):
			rim += 1
			assert_eq(colours[i].a, 0.0, "a rim vertex is clear")
		elif verts[i].is_zero_approx():
			middle += 1
			assert_eq(colours[i].a, 1.0, "the middle is whole")
		var light: Color = SpacePalette.STARS[0][&"light"]
		assert_almost_eq(Vector3(colours[i].r, colours[i].g, colours[i].b), Vector3(light.r, light.g, light.b),
			Vector3.ONE * 1e-6, "in the star's light")
	assert_eq(rim, StarHalo.SEGMENTS * 2)
	assert_eq(middle, StarHalo.SEGMENTS)
