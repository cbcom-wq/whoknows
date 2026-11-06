extends GutTest
## The outside's sky, haze and light follow the air (desert-world spec §6.2-§6.3).

var P: Dictionary = SpacePalette.WORLDS[6]
var S: Dictionary = SpacePalette.STARS[0]

## A Whereabouts standing in a world's well, in thick air, the sun overhead
## and "up" along +X.
const FAKE_WHERE := """extends Whereabouts
var body: SystemBody
func air() -> float:
	return 1.0
func sun_up() -> float:
	return 1.0
func up() -> Vector3:
	return Vector3.RIGHT
func well() -> SystemBody:
	return body
"""

func _fake_where(body: SystemBody) -> Whereabouts:
	var script := GDScript.new()
	script.source_code = FAKE_WHERE
	script.reload()
	var where := Whereabouts.new()
	where.set_script(script)
	where.set(&"body", body)
	autofree(where)
	return where

func _share(c: Color, from: Color, to: Color) -> float:
	var total := 0.0
	for i in 3:
		total += (c[i] - from[i]) / (to[i] - from[i])
	return total / 3.0

func test_no_air_is_todays_space():
	var m := AirMood.mood(0.0, 0.7, P, S)
	assert_eq(m.sky_top, SpacePalette.SPACE_SKY_TOP)
	assert_eq(m.sky_horizon, SpacePalette.SPACE_SKY_HORIZON)
	assert_eq(m.ground_horizon, SpacePalette.SPACE_SKY_HORIZON)
	assert_eq(m.ground_bottom, SpacePalette.SPACE_GROUND_BOTTOM)
	assert_false(m.fog)
	assert_eq(m.ambient_colour, SpacePalette.AMBIENT)
	assert_almost_eq(m.ambient_energy, AirMood.SPACE_AMBIENT_ENERGY, 1e-6)
	assert_almost_eq(m.bloom, AirMood.SPACE_BLOOM, 1e-6)
	assert_almost_eq(m.halo_deg, AirMood.SPACE_HALO_DEG, 1e-6)
	assert_eq(m.sun_colour, S[&"light"])
	assert_almost_eq(m.sun_energy, S[&"energy"], 1e-6)

func test_thick_air_at_noon_is_the_worlds_sky():
	var m := AirMood.mood(1.0, 1.0, P, S)
	assert_true(m.sky_top.is_equal_approx(P[&"sky_high"]))
	assert_true(m.sky_horizon.is_equal_approx(P[&"sky_low"]))
	assert_true(m.fog)
	assert_almost_eq(m.fog_density, AirMood.FOG_GROUND, 1e-9)
	assert_true(m.fog_colour.is_equal_approx(P[&"sky_low"]))
	assert_almost_eq(m.halo_deg, AirMood.HALO_DEG, 1e-6)

func test_the_horizon_fills_before_the_top():
	var m := AirMood.mood(0.2, 1.0, P, S)
	assert_gt(_share(m.sky_horizon, SpacePalette.SPACE_SKY_HORIZON, P[&"sky_low"]),
		_share(m.sky_top, SpacePalette.SPACE_SKY_TOP, P[&"sky_high"]) + 0.2)

func test_the_haze_thickens_all_the_way_down():
	var last := 0.0
	for a in [0.05, 0.2, 0.5, 1.0]:
		var d: float = AirMood.mood(a, 1.0, P, S).fog_density
		assert_gt(d, last)
		last = d

func test_night_is_dark_and_dusk_is_warm():
	var night := AirMood.mood(1.0, -0.6, P, S)
	assert_true(night.sky_top.is_equal_approx(SpacePalette.NIGHT_SKY))
	assert_almost_eq(night.ambient_energy, AirMood.SPACE_AMBIENT_ENERGY, 1e-6)   # the lamp still matters
	var slate: Dictionary = SpacePalette.WORLDS[1]
	var dusk: Color = AirMood.mood(1.0, 0.02, slate, S).sky_horizon
	var noon: Color = AirMood.mood(1.0, 1.0, slate, S).sky_horizon
	assert_gt(dusk.r / dusk.b, noon.r / noon.b, "dusk's horizon is warmer than noon's")

func test_every_world_palette_has_two_sky_colours():
	for p in SpacePalette.WORLDS:
		assert_true(p.has(&"sky_high") and p.has(&"sky_low"), String(p[&"name"]))

func test_sky_basis_turns_up_onto_the_local_up():
	for up in [Vector3.UP, Vector3.RIGHT, Vector3(0.3, -0.9, 0.2).normalized(), Vector3.DOWN]:
		assert_almost_eq(AirMood.sky_basis(up) * Vector3.UP, up, Vector3.ONE * 1e-5)
	assert_almost_eq(AirMood.sky_basis(Vector3.ZERO) * Vector3.UP, Vector3.UP, Vector3.ONE * 1e-6)

func test_differs():
	var m := AirMood.mood(0.5, 1.0, P, S)
	assert_true(AirMood.differs(m, {}, AirMood.APPLY_STEP))
	assert_false(AirMood.differs(m, m, AirMood.APPLY_STEP))
	assert_false(AirMood.differs(AirMood.mood(0.5005, 1.0, P, S), m, AirMood.APPLY_STEP))
	assert_true(AirMood.differs(AirMood.mood(0.6, 1.0, P, S), m, AirMood.APPLY_STEP))

func _rig() -> Array:
	var env := Environment.new()
	var mat := ProceduralSkyMaterial.new()
	env.sky = Sky.new()
	env.sky.sky_material = mat
	var sun := DirectionalLight3D.new()
	autofree(sun)
	return [env, mat, sun]

func test_apply_writes_what_reads_back():
	var r := _rig()
	var env: Environment = r[0]
	var mat: ProceduralSkyMaterial = r[1]
	var sun: DirectionalLight3D = r[2]
	var m := AirMood.mood(1.0, 1.0, P, S)
	AirMood.apply(m, env, mat, sun)
	assert_eq(mat.sky_top_color, m.sky_top)
	assert_eq(mat.ground_bottom_color, m.ground_bottom)
	assert_almost_eq(mat.sun_angle_max, m.halo_deg, 1e-6)
	assert_true(env.fog_enabled)
	assert_almost_eq(env.fog_density, m.fog_density, 1e-9)
	assert_eq(env.fog_light_color, m.fog_colour)
	assert_eq(env.ambient_light_color, m.ambient_colour)
	assert_eq(sun.light_color, m.sun_colour)

func test_setup_snaps_at_once():
	var r := _rig()
	var env: Environment = r[0]
	var sun: DirectionalLight3D = r[2]
	var system := SystemRecipe.from_seed(1)
	var body := SystemBody.new()
	body.recipe = WorldRecipe.new()
	body.recipe.palette = 6
	var where := _fake_where(body)
	var mood := AirMood.new()
	add_child_autofree(mood)
	mood.setup(env, sun, where, system)
	assert_true(env.fog_enabled, "no physics frame has run yet")
	assert_almost_eq(Basis.from_euler(env.sky_rotation) * Vector3.UP, Vector3.RIGHT, Vector3.ONE * 1e-4)
	assert_true(mood.last_mood.fog)
