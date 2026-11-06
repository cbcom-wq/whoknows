extends GutTest

## The glow round a world with air, seen from outside (desert-world spec §6.2
## stage 1, §6.3). R = 30000, air to 6000 over it.

var _glow: LimbGlow

func before_each():
	var body := SystemBody.new()
	body.radius = 30000.0
	body.recipe = WorldRecipe.new()
	body.recipe.radius_m = 30000.0
	body.recipe.atmosphere = WorldRecipe.Atmosphere.THICK
	body.recipe.palette = 6
	_glow = LimbGlow.new()
	_glow.setup(body)
	add_child_autofree(_glow)

func test_far_off_the_rim_is_the_air_shell():
	var a := LimbGlow.angles(30000.0, 6000.0, 300000.0)
	assert_almost_eq(a.x, asin(0.1) - deg_to_rad(LimbGlow.INNER_INSET_DEG), 1e-6)
	assert_almost_eq(a.y, asin(36000.0 / 300000.0), 1e-6)

func test_inside_the_air_it_is_a_band_over_the_limb():
	var d := 33000.0
	assert_almost_eq(LimbGlow.angles(30000.0, 6000.0, d).y, asin(30000.0 / d) + deg_to_rad(LimbGlow.BAND_INSIDE_DEG), 1e-6)

func test_continuous_across_the_air_top_and_never_past_the_horizontal():
	assert_almost_eq(LimbGlow.angles(30000.0, 6000.0, 36001.0).y, LimbGlow.angles(30000.0, 6000.0, 35999.0).y, 0.01)
	assert_lte(LimbGlow.angles(30000.0, 6000.0, 30010.0).y, deg_to_rad(LimbGlow.MAX_ANGLE_DEG))

func test_strength_from_outside_and_near_the_ground():
	assert_almost_eq(LimbGlow.strength(30000.0, 300000.0, 0.0), 1.0, 1e-6)
	assert_eq(LimbGlow.strength(30000.0, 30010.0, 0.0), 0.0)    # the limb dips 1.5 deg
	assert_eq(LimbGlow.strength(30000.0, 31000.0, 0.9), 0.0)    # thick air low down

func test_lit_by_the_sun_dim_at_night():
	assert_almost_eq(LimbGlow.lit(Vector3.UP, Vector3.UP), 1.0, 1e-6)
	assert_almost_eq(LimbGlow.lit(Vector3.DOWN, Vector3.UP), LimbGlow.RIM_NIGHT, 1e-6)

func test_the_ring_lies_in_the_limb_plane():
	_glow.place(Vector3(0, 0, 300000), Vector3.UP, 0.0)
	assert_true(_glow.visible)
	var verts: PackedVector3Array = _glow.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0)
	var inner := (300000.0 - 3000.0) * tan(LimbGlow.angles(30000.0, 6000.0, 300000.0).x)
	var nearest := INF
	for v in verts:
		assert_lt(absf(v.z - 30000.0 * 30000.0 / 300000.0), 0.01)
		nearest = minf(nearest, Vector2(v.x, v.y).length())
	assert_almost_eq(nearest, inner, 0.1)

func test_hidden_near_the_ground_and_drawn_from_afar():
	_glow.place(Vector3(0, 0, 30010), Vector3.UP, 0.0)
	assert_false(_glow.visible)
	_glow.place(Vector3(0, 0, 300000), Vector3.UP, 0.0)
	assert_true(_glow.visible)

func test_a_small_move_does_not_redraw_it():
	_glow.place(Vector3(0, 0, 300000), Vector3.UP, 0.0)
	var was := _glow.mesh
	_glow.place(Vector3(0, 0, 300100), Vector3.UP, 0.0)
	assert_same(_glow.mesh, was)
	_glow.place(Vector3(0, 0, 330000), Vector3.UP, 0.0)
	assert_not_same(_glow.mesh, was)

func test_ignores_fog_and_adds_light():
	var m := _glow.material_override as StandardMaterial3D
	assert_true(m.disable_fog)
	assert_eq(m.blend_mode, BaseMaterial3D.BLEND_MODE_ADD)
