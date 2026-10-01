class_name WorldTerrain
extends RefCounted

## The ground of one world (docs/superpowers/specs/2026-09-30-world-scale-design.md
## §4): how high it is, what colour it is, and how far above it a point is.
## Pure and deterministic: the same on every machine. Everything that needs
## the ground asks this -- the far mesh, the surface's chunks, collision, the
## analytic floor and the speed limit -- never each other.
##
## Not thread-safe (FastNoiseLite is not): each thread makes its own from the
## same recipe, and they all agree.
##
## A height is metres above radius_m, within half the relief either way: a
## continent layer the size of the world under the archetype's own hills,
## and for a cratered world the same craters its far pattern paints. The
## colours are that pattern -- patches, bands, plateaus, craters (style guide
## §3.5) -- with steep ground bare rock, in shade patches a few triangles
## across (PATCH_QUADS) at every detail.

## Continents: this many across the unit sphere.
const CONTINENT_SCALE := 1.4
## The archetype's hills: the biggest this many metres across, and octaves
## down to the smallest.
const HILL_WAVE := 4000.0
const HILL_OCTAVES := 7
## How the relief is shared between continents and hills.
const CONTINENT_SHARE := 0.45
const HILL_SHARE := 0.55
## Mesa terraces: how many, and the flat share of each.
const TERRACES := 4
const TERRACE_FLAT := 0.8
## A cratered world's hills are this much gentler.
const CRATERED_HILLS := 0.4
## A crater's bowl and rim, as shares of the relief's half.
const CRATER_DEPTH := 0.8
const CRATER_RIM := 0.25
## Of a crater's width, the dark floor; the rest is its light rim.
const CRATER_FLOOR := 0.78
## Craters: how many, and how wide, in radians round the sphere.
const CRATERS := Vector2i(5, 9)
const CRATER_SIZE := Vector2(0.12, 0.35)
## Ridged bands of colour: how many round the sphere.
const BANDS := 9.0
## How finely the colour pattern varies over the unit sphere.
const PATTERN_SCALE := 1.6
## Steeper than this, the ground is bare rock.
const ROCK_SLOPE := deg_to_rad(35.0)
## A shade patch is this many triangles across (about six), so shades come in
## broad patches at every detail, never triangle by triangle.
const PATCH_QUADS := 6.0

var recipe: WorldRecipe
var radius: float
var relief: float
var archetype: WorldRecipe.Archetype
var palette: Dictionary
## [centre direction, angular radius] per crater; empty unless CRATERED.
var craters: Array = []
var band_axis := Vector3.UP

var _continents := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _pattern := FastNoiseLite.new()
var _shades := FastNoiseLite.new()

func _init(p_recipe: WorldRecipe) -> void:
	recipe = p_recipe
	radius = recipe.radius_m
	relief = recipe.relief_m
	archetype = recipe.archetype
	palette = SpacePalette.WORLDS[recipe.palette]
	_continents.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"continents"))
	_continents.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continents.frequency = 1.0
	_continents.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continents.fractal_octaves = 3
	_hills.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"terrain"))
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 1.0
	_hills.fractal_octaves = HILL_OCTAVES
	_hills.fractal_type = FastNoiseLite.FRACTAL_RIDGED if archetype == WorldRecipe.Archetype.RIDGED \
		else FastNoiseLite.FRACTAL_FBM
	# The far pattern keeps the sub-seeds it always had, so a world looks as
	# it did from afar.
	_pattern.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"look"))
	_pattern.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_pattern.frequency = 1.0
	_pattern.fractal_type = FastNoiseLite.FRACTAL_FBM
	_pattern.fractal_octaves = 2
	_shades.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"shades"))
	_shades.noise_type = FastNoiseLite.TYPE_CELLULAR
	_shades.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_shades.frequency = 1.0
	_shades.fractal_type = FastNoiseLite.FRACTAL_NONE
	var rng := WorldSeed.rng(recipe.seed, &"marks")
	band_axis = _direction(rng)
	if archetype == WorldRecipe.Archetype.CRATERED:
		for i in rng.randi_range(CRATERS.x, CRATERS.y):
			craters.append([_direction(rng), rng.randf_range(CRATER_SIZE.x, CRATER_SIZE.y)])

## Metres above radius at `dir`, within half the relief either way.
func height_at(dir: Vector3) -> float:
	var d := dir.normalized()
	var continent := _continents.get_noise_3dv(d * CONTINENT_SCALE)
	var hills := _hills.get_noise_3dv(d * (radius / HILL_WAVE))
	match archetype:
		WorldRecipe.Archetype.MESA:
			hills = _terrace(hills)
		WorldRecipe.Archetype.CRATERED:
			hills = hills * CRATERED_HILLS + _crater(d)
	return relief * 0.5 * clampf(CONTINENT_SHARE * continent + HILL_SHARE * hills, -1.0, 1.0)

## How far `local` (from the world's centre) is above the ground under it.
func altitude_of(local: Vector3) -> float:
	if local.is_zero_approx():
		return -radius
	return local.length() - (radius + height_at(local))

## Which of the palette's grounds faces `dir` on ground this steep (radians).
func ground_at(dir: Vector3, slope: float) -> StringName:
	if slope > ROCK_SLOPE:
		return &"rock"
	var d := dir.normalized()
	var n := _pattern.get_noise_3dv(d * PATTERN_SCALE)
	match archetype:
		WorldRecipe.Archetype.RIDGED:
			var band := sin(d.dot(band_axis) * BANDS + n * 2.5)
			if band > 0.75:
				return &"rock"
			return &"ground_high" if band > 0.05 else &"ground_low"
		WorldRecipe.Archetype.MESA:
			if absf(n - 0.05) < 0.06:
				return &"rock"
			return &"ground_high" if n > 0.05 else &"ground_low"
		WorldRecipe.Archetype.CRATERED:
			for c: Array in craters:
				var angle := d.angle_to(c[0])
				if angle < float(c[1]) * CRATER_FLOOR:
					return &"rock"
				if angle < float(c[1]):
					return &"ground_high"
			return &"dust" if n > 0.2 else &"ground_low"
	if n < -0.45:
		return &"rock"
	return &"ground_high" if n > 0.1 else &"ground_low"

## The colour of ground facing `dir`, this steep, in shade patches about
## `patch_m` metres across.
func colour_at(dir: Vector3, slope: float, patch_m: float) -> Color:
	var d := dir.normalized()
	var base: Color = palette[ground_at(d, slope)]
	var cell := (_shades.get_noise_3dv(d * (radius / maxf(patch_m, 1.0))) + 1.0) * 0.5
	var k := clampi(floori(cell * SpacePalette.SHADES.size()), 0, SpacePalette.SHADES.size() - 1)
	return SpacePalette.shade(base, k)

## Mesa: flat steps with steep risers.
func _terrace(h: float) -> float:
	var t := (h + 1.0) * 0.5 * TERRACES
	var step := floorf(t)
	var f := t - step
	var rise := 0.0 if f < TERRACE_FLAT else (f - TERRACE_FLAT) / (1.0 - TERRACE_FLAT)
	return (step + rise) / TERRACES * 2.0 - 1.0

## Every crater's bowl and rim at `d`.
func _crater(d: Vector3) -> float:
	var out := 0.0
	for c: Array in craters:
		var t := d.angle_to(c[0]) / float(c[1])
		if t >= 1.0:
			continue
		if t < CRATER_FLOOR:
			var k := t / CRATER_FLOOR
			out -= CRATER_DEPTH * (1.0 - k * k)
		else:
			out += CRATER_RIM * sin(PI * (t - CRATER_FLOOR) / (1.0 - CRATER_FLOOR))
	return out

static func _direction(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if v.length() > 0.2 and v.length() <= 1.0:
			return v.normalized()
	return Vector3.UP
