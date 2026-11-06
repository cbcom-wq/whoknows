class_name AirMood
extends Node
## The outside's sky, haze and light follow how thick the air is (desert-world
## spec §6.2-§6.3). With no air it is today's space exactly; as the air thickens
## the horizon fills first, then the top, the haze comes up, the sun warms and
## its halo widens. At night the sky goes to NIGHT_SKY, at dusk the horizon warms.
##
## It writes the outside's WorldEnvironment (the chase view and the canopy
## feed). That may change freely now: the interior camera carries its own
## environment (ship_interior.tres), so the cabin's look is untouched. Every
## colour comes from SpacePalette; this file names none.
##
## The sun's glow is the StarHalo's, on the star itself: the engine hands the
## sky shader the light's way unturned by sky_rotation, so the sky's own sun
## glow sat as far off the star as the sky was turned. The light is taken out
## of the sky (SKY_MODE_LIGHT_ONLY); halo_deg still goes to the sky material,
## where it no longer shows.

## No air: the values flight_test.gd always gave the outside.
const SPACE_AMBIENT_ENERGY := 0.4
const SPACE_BLOOM := 0.05
const SPACE_HALO_DEG := 1.0

## The air at which the horizon, and then the top, reach the world's sky.
const HORIZON_FULL_AT := 0.25
const TOP_FULL_AT := 0.6

## Haze: density per metre at full air, how much of the horizon colour shows
## in the distance, and how much the sun scatters through it by day.
const FOG_GROUND := 0.00004
const FOG_AERIAL := 0.5
const SUN_SCATTER := 0.25

const AMBIENT_IN_AIR := 0.9
const BLOOM_IN_AIR := 0.02
const HALO_DEG := 12.0

## The sun reddens low in thick air and thins a little in it.
const SUN_WARMTH := 0.6
const SUN_IN_AIR := 0.9

## Day comes in over sun_up from DAY_FROM to DAY_TO; dusk is the band round the
## horizon, warming the horizon by DUSK_WARMTH.
const DAY_FROM := -0.10
const DAY_TO := 0.20
const DUSK_BAND := 0.25
const DUSK_WARMTH := 0.5

## How often it looks, how far a value must move to be written, and how far
## the local up must turn to turn the sky.
const APPLY_EVERY := 0.1
const APPLY_STEP := 0.004
const TURN_STEP := deg_to_rad(0.2)

var last_mood: Dictionary = {}

var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _halo: StarHalo
var _where: Whereabouts
var _system: SystemRecipe
var _since := 0.0
var _turned_up := Vector3.ZERO

func setup(env: Environment, sun: DirectionalLight3D, whereabouts: Whereabouts, system: SystemRecipe,
		halo: StarHalo = null) -> void:
	_env = env
	_sky = env.sky.sky_material as ProceduralSkyMaterial
	_sun = sun
	_halo = halo
	_where = whereabouts
	_system = system
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.0
	snap()

## Applies the mood for where the focus is now, at once.
func snap() -> void:
	if _env == null:
		return
	last_mood = _now()
	apply(last_mood, _env, _sky, _sun, _halo)
	_turn_sky()
	_since = 0.0

func _physics_process(delta: float) -> void:
	if _env == null:
		return
	_since += delta
	if _since < APPLY_EVERY:
		return
	_since = 0.0
	var m := _now()
	if differs(m, last_mood, APPLY_STEP):
		last_mood = m
		apply(m, _env, _sky, _sun, _halo)
	var up := _where.up()
	if up.is_zero_approx() != _turned_up.is_zero_approx() \
			or (not up.is_zero_approx() and up.angle_to(_turned_up) > TURN_STEP):
		_turn_sky()

func _now() -> Dictionary:
	var b := _where.well()
	var palette: Dictionary = SpacePalette.WORLDS[0]
	if b != null and b.recipe != null:
		palette = SpacePalette.WORLDS[b.recipe.palette]
	var star_index := _system.star.star_palette if _system != null and _system.star != null else 0
	var star: Dictionary = SpacePalette.STARS[maxi(star_index, 0)]
	return mood(_where.air(), _where.sun_up(), palette, star)

func _turn_sky() -> void:
	_turned_up = _where.up()
	_env.sky_rotation = sky_basis(_turned_up).get_euler()

## Everything the outside shows for `air` and `sun_up` (spec §6.2), worked out
## from the world's `palette` and the `star`'s.
static func mood(air: float, sun_up: float, palette: Dictionary, star: Dictionary) -> Dictionary:
	var day := smoothstep(DAY_FROM, DAY_TO, sun_up)
	var dusk := 1.0 - clampf(absf(sun_up) / DUSK_BAND, 0.0, 1.0)
	var high: Color = SpacePalette.NIGHT_SKY.lerp(palette[&"sky_high"], day)
	var low: Color = SpacePalette.NIGHT_SKY.lerp(palette[&"sky_low"], day) \
		.lerp(SpacePalette.DUSK, dusk * DUSK_WARMTH * day)
	var h := smoothstep(0.0, HORIZON_FULL_AT, air)
	var t := smoothstep(0.0, TOP_FULL_AT, air)
	var horizon: Color = SpacePalette.SPACE_SKY_HORIZON.lerp(low, h)
	var sun_light: Color = star[&"light"]
	return {
		&"sky_top": SpacePalette.SPACE_SKY_TOP.lerp(high, t),
		&"sky_horizon": horizon,
		&"ground_horizon": horizon,
		&"ground_bottom": SpacePalette.SPACE_GROUND_BOTTOM.lerp(low, h),
		&"halo_deg": lerpf(SPACE_HALO_DEG, HALO_DEG, air * day),
		&"fog": air > 0.001,
		&"fog_density": FOG_GROUND * sqrt(air),
		&"fog_colour": low,
		&"fog_aerial": FOG_AERIAL * h,
		&"fog_sun_scatter": SUN_SCATTER * air * day,
		&"ambient_colour": SpacePalette.AMBIENT.lerp(high, t),
		&"ambient_energy": lerpf(SPACE_AMBIENT_ENERGY, AMBIENT_IN_AIR, t * day),
		&"bloom": lerpf(SPACE_BLOOM, BLOOM_IN_AIR, t),
		&"sun_colour": sun_light.lerp(SpacePalette.SUN_LOW, air * SUN_WARMTH * (1.0 - clampf(sun_up, 0.0, 1.0))),
		&"sun_energy": float(star[&"energy"]) * lerpf(1.0, SUN_IN_AIR, air),
	}

## The shortest turn taking Vector3.UP onto `up`; none for a zero `up`.
static func sky_basis(up: Vector3) -> Basis:
	if up.is_zero_approx():
		return Basis.IDENTITY
	var u := up.normalized()
	var d := Vector3.UP.dot(u)
	if d > 0.999999:
		return Basis.IDENTITY
	if d < -0.999999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, u))

## True when `b` is empty, the haze switched, a colour channel moved by more
## than `step`, or a number by more than `step` of its own size (so a fog
## density of 4e-5 still counts).
static func differs(a: Dictionary, b: Dictionary, step: float) -> bool:
	if b.is_empty():
		return true
	for key in a:
		var x: Variant = a[key]
		var y: Variant = b.get(key)
		if x is bool:
			if x != y:
				return true
		elif x is Color:
			var c: Color = y
			if absf(x.r - c.r) > step or absf(x.g - c.g) > step or absf(x.b - c.b) > step:
				return true
		else:
			if absf(x - y) > step * maxf(absf(x), absf(y)):
				return true
	return false

## Writes every part of `m` where it lives; the star's `halo`, if given, glows
## halo_deg / HALO_DEG strong, and not at all with no air (today's space).
static func apply(m: Dictionary, env: Environment, sky: ProceduralSkyMaterial, sun: DirectionalLight3D,
		halo: StarHalo = null) -> void:
	if halo != null:
		halo.set_strength(float(m[&"halo_deg"]) / HALO_DEG if m[&"fog"] else 0.0)
	sky.sky_top_color = m[&"sky_top"]
	sky.sky_horizon_color = m[&"sky_horizon"]
	sky.ground_horizon_color = m[&"ground_horizon"]
	sky.ground_bottom_color = m[&"ground_bottom"]
	sky.sun_angle_max = m[&"halo_deg"]
	env.fog_enabled = m[&"fog"]
	env.fog_density = m[&"fog_density"]
	env.fog_light_color = m[&"fog_colour"]
	env.fog_aerial_perspective = m[&"fog_aerial"]
	env.fog_sun_scatter = m[&"fog_sun_scatter"]
	env.ambient_light_color = m[&"ambient_colour"]
	env.ambient_light_energy = m[&"ambient_energy"]
	env.glow_bloom = m[&"bloom"]
	sun.light_color = m[&"sun_colour"]
	sun.light_energy = m[&"sun_energy"]
