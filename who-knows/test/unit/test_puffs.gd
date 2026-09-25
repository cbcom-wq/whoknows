extends GutTest

## The shared chunky puff (flight controls spec §6.2): the airlock's steam and
## the RCS thrusters draw the same thing.

func test_a_puff_is_a_chunky_low_poly_sphere():
	var m := Puffs.mesh(false)
	assert_eq(m.radial_segments, 8)
	assert_eq(m.rings, 4)

func test_flat_puffs_are_unshaded_and_others_are_lit():
	var flat := Puffs.mesh(true).material as StandardMaterial3D
	var lit := Puffs.mesh(false).material as StandardMaterial3D
	assert_eq(flat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_ne(lit.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)

func test_puffs_are_steam_coloured_and_fade_in_and_out():
	assert_eq((Puffs.mesh(true).material as StandardMaterial3D).albedo_color, InteriorPalette.STEAM)
	var ramp := Puffs.fade(0.5).gradient
	assert_almost_eq(ramp.colors[0].a, 0.0, 0.001)
	assert_almost_eq(ramp.colors[1].a, 0.5, 0.001)
	assert_almost_eq(ramp.colors[3].a, 0.0, 0.001)

func test_a_puff_grows_over_its_life():
	var c := Puffs.grow(0.8, 2.2).curve
	assert_almost_eq(c.sample(0.0), 0.8, 0.001)
	assert_almost_eq(c.sample(1.0), 2.2, 0.001)
