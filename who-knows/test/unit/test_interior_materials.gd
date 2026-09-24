extends GutTest

func test_structure_is_flat_colour_with_no_rim():
	var m := InteriorMaterials.flat(InteriorPalette.WALL)
	assert_eq(m.albedo_color, InteriorPalette.WALL)
	assert_false(m.rim_enabled,
		"rim light on a surface seen edge-on (the whole ceiling) blows it out")

func test_materials_are_built_once_and_shared():
	assert_same(InteriorMaterials.flat(InteriorPalette.WALL), InteriorMaterials.flat(InteriorPalette.WALL))
	assert_same(InteriorMaterials.props(), InteriorMaterials.props())
	assert_same(InteriorMaterials.glow(), InteriorMaterials.glow())

func test_props_take_their_colour_from_vertices():
	var m := InteriorMaterials.props()
	assert_true(m.vertex_color_use_as_albedo)
	assert_true(m.rim_enabled, "a faint rim keeps chunky shapes apart in dim light")

func test_the_three_custom_shaders():
	assert_eq(InteriorMaterials.glow().shader, InteriorMaterials.GLOW_SHADER)
	assert_eq(InteriorMaterials.screen().shader, InteriorMaterials.SCREEN_SHADER)
	assert_eq(InteriorMaterials.canopy_fallback().shader, InteriorMaterials.CANOPY_SHADER)

func test_glow_energy_matches_what_the_kit_scales_by():
	assert_almost_eq(InteriorMaterials.glow().get_shader_parameter(&"energy"),
		InteriorMaterials.GLOW_ENERGY, 0.0001)

func test_screen_colours_come_from_the_palette():
	var m := InteriorMaterials.screen()
	assert_eq(m.get_shader_parameter(&"back_color"), InteriorPalette.SCREEN_BACK)
	assert_eq(m.get_shader_parameter(&"color_a"), InteriorPalette.AMBER)
	assert_eq(m.get_shader_parameter(&"color_b"), InteriorPalette.LAVENDER)
	assert_eq(m.get_shader_parameter(&"color_c"), InteriorPalette.SKY)
	assert_eq(m.get_shader_parameter(&"color_d"), InteriorPalette.CORAL)

func test_glass_is_transparent_and_vertex_tinted():
	var m := InteriorMaterials.glass()
	assert_eq(m.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_true(m.vertex_color_use_as_albedo)

func test_canopy_fallback_has_no_view_and_the_palette_colours():
	var m := InteriorMaterials.canopy_fallback()
	assert_null(m.get_shader_parameter(&"canopy_view"), "windows render black, never a hole")
	assert_eq(m.get_shader_parameter(&"shell_color"), InteriorPalette.WALL)
	assert_eq(m.get_shader_parameter(&"frame_color"), InteriorPalette.TRIM)

func test_portal_fallback_is_all_glass_with_no_view():
	var m := InteriorMaterials.portal_fallback()
	assert_eq(m.shader, InteriorMaterials.CANOPY_SHADER)
	assert_true(m.get_shader_parameter(&"all_glass"))
	assert_null(m.get_shader_parameter(&"canopy_view"))
