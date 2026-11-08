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
## across (PATCH_QUADS) at every detail. A desert (DUNES) is its own shape
## and colours on the same continent layer: dunes, mesas and towers (the
## desert world spec §7.2), and the wind that laid them (wind_at).

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

# A desert (DUNES; the desert world spec §7.2): long asymmetric dunes on the
# continent layer, running across one wind axis and turning across the world;
# flat mesas where the continent layer is high; rock towers just below them.

## Dunes: crests this far apart, this high at most, the lee taking this share
## of each wave (about 17° at full height; the windward side about 4°).
const DUNE_WAVE := 320.0
const DUNE_HEIGHT := 18.0
const DUNE_LEE := 0.18
## The trough and the crest are rounded over this share of a wave either
## side, so no triangle is a knife edge.
const DUNE_EASE := 0.04
## Along its crest a dune's height swells from this share to full and back,
## by a noise this many metres across.
const DUNE_LOW := 0.35
const DUNE_SWELL := 6000.0
## The ridges are level lines of d . wind_axis, shifted by up to this many
## waves by a noise this many metres across, so they turn across the world.
const DUNE_WARP := 1.5
const DUNE_TURN := 5000.0
## Past this |d . wind_axis|, toward the axis's poles where the ridges would
## close into rings, the dunes fade into a flat sand sheet, gone halfway to
## the pole.
const DUNE_POLE := 0.9
## The lowest fifth of a dune (of its height, faded as the dune fades) is
## dust: the flats between dunes, and the sand sheets.
const DUNE_DUST := 0.2
## Under the dunes and mesas the continent layer stands at this share of its
## height, so the dunes lie on a nearly level floor (a fraction of a degree)
## and are not lost on its slopes.
const DUNE_FLOOR := 0.25
## Mesas rise where the continent layer (continent_at: a share of half the
## relief) is above MESA_FROM; the dunes fade out over MESA_EDGE below it. A
## desert's layer carries MESA_HILLS of the hills, so the mesa line wanders
## and breaks up rather than following a contour.
const MESA_FROM := 0.12
const MESA_EDGE := 0.05
const MESA_HILLS := 0.02
## One terrace per MESA_STEP of the layer, each MESA_RISE of half the relief
## above the last: its riser takes the first 1 - MESA_FLAT of it, the rest is
## flat.
const MESA_STEP := 0.02
const MESA_RISE := 0.15
const MESA_FLAT := 0.98
## Towers stand in the band TOWER_BAND below the mesa line: cells TOWER_WAVE
## metres apart, one in TOWER_SHARE standing, its flat top TOWER_RADIUS in
## radius and its flank spreading to TOWER_FOOT times that. Each rises to the
## first terrace, shorter toward the band's floor.
const TOWER_BAND := 0.06
const TOWER_WAVE := 140.0
const TOWER_RADIUS := Vector2(8.0, 22.0)
const TOWER_SHARE := 0.3
const TOWER_FOOT := 1.4
## A dune's crest, and its windward and lee slopes, per unit of wave.
const _CREST := 1.0 - DUNE_LEE
const _UP := 1.0 / _CREST
const _DOWN := -1.0 / DUNE_LEE

var recipe: WorldRecipe
var radius: float
var relief: float
var archetype: WorldRecipe.Archetype
var palette: Dictionary
## [centre direction, angular radius] per crater; empty unless CRATERED.
var craters: Array = []
var band_axis := Vector3.UP
## A desert's dune crests run along this axis's lines of latitude (before
## their warp), and its wind blows across them, toward the axis.
var wind_axis := Vector3.UP

var _continents := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _pattern := FastNoiseLite.new()
var _shades := FastNoiseLite.new()
## A desert's alone: the ridges' warp, the crests' swell, and the towers'
## cells (two returns of the same cells).
var _wind: FastNoiseLite
var _swell: FastNoiseLite
var _tower_gap: FastNoiseLite
var _tower_cell: FastNoiseLite

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
	if archetype == WorldRecipe.Archetype.DUNES:
		wind_axis = _direction(WorldSeed.rng(recipe.seed, &"wind"))
		_wind = _simplex(&"wind", 2)
		_swell = _simplex(&"dunes", 1)
		_tower_gap = _cells(FastNoiseLite.RETURN_DISTANCE)
		_tower_cell = _cells(FastNoiseLite.RETURN_CELL_VALUE)

## Metres above radius at `dir`, within half the relief either way.
func height_at(dir: Vector3) -> float:
	var d := dir.normalized()
	var continent := _continents.get_noise_3dv(d * CONTINENT_SCALE)
	if archetype == WorldRecipe.Archetype.DUNES:
		return _desert_height(d, continent)
	var hills := _hills.get_noise_3dv(d * (radius / HILL_WAVE))
	match archetype:
		WorldRecipe.Archetype.MESA:
			hills = _terrace(hills)
		WorldRecipe.Archetype.CRATERED:
			hills = hills * CRATERED_HILLS + _crater(d)
	return relief * 0.5 * clampf(CONTINENT_SHARE * continent + HILL_SHARE * hills, -1.0, 1.0)

## The continent layer at `dir`, as a share of half the relief (CONTINENT_SHARE
## of the continents' noise), that a desert's mesas rise from: on a desert
## with MESA_HILLS of the hills in it.
func continent_at(dir: Vector3) -> float:
	var d := dir.normalized()
	var continent := _continents.get_noise_3dv(d * CONTINENT_SCALE)
	if archetype != WorldRecipe.Archetype.DUNES:
		return CONTINENT_SHARE * continent
	return CONTINENT_SHARE * continent + MESA_HILLS * _hills.get_noise_3dv(d * (radius / HILL_WAVE))

## A desert's continent_at, from the continents' noise at `d`. Where the
## hills (within -1 to 1) could not lift it into the tower band, the layer
## without them, which every desert rule treats the same: so the hills are
## only sampled near the mesas.
func _mesa_continent(d: Vector3, continent: float) -> float:
	var layer := CONTINENT_SHARE * continent
	if layer < MESA_FROM - TOWER_BAND - MESA_HILLS:
		return layer
	return layer + MESA_HILLS * _hills.get_noise_3dv(d * (radius / HILL_WAVE))

## Which way the wind blows at `dir` on a desert: the unit tangent from a
## dune's windward side to its lee, the way the dune phase grows (by central
## differences 1 m apart). Vector3.ZERO on any other world.
func wind_at(dir: Vector3) -> Vector3:
	if archetype != WorldRecipe.Archetype.DUNES:
		return Vector3.ZERO
	var d := dir.normalized()
	var e1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := d.cross(e1)
	var h := 0.5 / radius
	var g := e1 * (_phase(d + e1 * h) - _phase(d - e1 * h)) \
		+ e2 * (_phase(d + e2 * h) - _phase(d - e2 * h))
	if g.length_squared() < 1e-20:
		return e1
	return g.normalized()

## Whether `dir` is where a desert's boulders gather: the low ground of the
## tower band below a mesa (which holds the MESA_EDGE the dunes fade over),
## off the towers themselves. False on any other world.
func in_talus(dir: Vector3) -> bool:
	if archetype != WorldRecipe.Archetype.DUNES:
		return false
	var d := dir.normalized()
	var z := _mesa_continent(d, _continents.get_noise_3dv(d * CONTINENT_SCALE))
	return z >= MESA_FROM - TOWER_BAND and z < MESA_FROM and _tower(d, z) == 0.0

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
	if archetype == WorldRecipe.Archetype.DUNES:
		return _desert_ground(d)
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

## A desert's height at `d`, from the continents' noise there: dunes on the
## continent layer (flattened to DUNE_FLOOR), faded toward the mesas and the
## wind axis's poles; terraces above the mesa line; towers in the band below.
func _desert_height(d: Vector3, continent: float) -> float:
	var half := relief * 0.5
	var z := _mesa_continent(d, continent)
	var ground := half * DUNE_FLOOR * CONTINENT_SHARE * continent
	if z < MESA_FROM:
		var dune := _dune(d, z)
		if dune > 0.0:
			var swell := clampf(_swell.get_noise_3dv(d * (radius / DUNE_SWELL)) + 0.5, 0.0, 1.0)
			ground += DUNE_HEIGHT * dune * (DUNE_LOW + (1.0 - DUNE_LOW) * swell)
	else:
		# Terrace k + 1, rising from terrace k (or from the floor for the first).
		var t := (z - MESA_FROM) / MESA_STEP
		var k := mini(floori(t), TERRACES - 1)
		var top := half * (DUNE_FLOOR * MESA_FROM + MESA_RISE * (k + 1))
		var below := ground if k == 0 else top - half * MESA_RISE
		ground = lerpf(below, top, clampf((t - k) / (1.0 - MESA_FLAT), 0.0, 1.0))
	if z >= MESA_FROM - TOWER_BAND and z < MESA_FROM + MESA_STEP:
		var top := half * (DUNE_FLOOR * MESA_FROM + MESA_RISE)
		if top > ground:
			ground = lerpf(ground, top, _tower(d, z))
	return clampf(ground, -half, half)

## How tall a dune stands at `d`, whose continent layer is `z`, as a share
## of DUNE_HEIGHT before its swell: its profile (0 at a trough, 1 at a
## crest), faded toward the mesas and the poles.
func _dune(d: Vector3, z: float) -> float:
	var a := d.dot(wind_axis)
	var stand := 1.0
	if z > MESA_FROM - MESA_EDGE:
		stand = 1.0 - smoothstep(MESA_FROM - MESA_EDGE, MESA_FROM, z)
	if absf(a) > DUNE_POLE:
		stand *= 1.0 - smoothstep(DUNE_POLE, (1.0 + DUNE_POLE) * 0.5, absf(a))
	if stand <= 0.0:
		return 0.0
	# _phase(d), written out: this runs per height.
	var phase := radius * a / DUNE_WAVE \
		+ DUNE_WARP * sqrt(maxf(0.0, 1.0 - a * a)) * _wind.get_noise_3dv(d * (radius / DUNE_TURN))
	return stand * _dune_profile(fposmod(phase, 1.0))

## Where `dir` lies in the dune waves, in waves: level lines of
## d . wind_axis, warped. The warp is scaled by the distance from the axis, so
## the ridges turn as much at every latitude and never fold back.
func _phase(dir: Vector3) -> float:
	var d := dir.normalized()
	var a := d.dot(wind_axis)
	return radius * a / DUNE_WAVE \
		+ DUNE_WARP * sqrt(maxf(0.0, 1.0 - a * a)) * _wind.get_noise_3dv(d * (radius / DUNE_TURN))

## A dune's cross-section over one wave, `t` from 0 at a trough: rising
## gently over 1 - DUNE_LEE to the crest, falling over DUNE_LEE, both corners
## rounded by parabolas tangent to the two slopes over DUNE_EASE either side.
static func _dune_profile(t: float) -> float:
	if t >= DUNE_EASE and t <= _CREST - DUNE_EASE:
		return t * _UP
	if t >= _CREST + DUNE_EASE and t <= 1.0 - DUNE_EASE:
		return (1.0 - t) / DUNE_LEE
	if absf(t - _CREST) < DUNE_EASE:
		var e := t - _CREST + DUNE_EASE
		return 1.0 + _UP * (t - _CREST) + (_DOWN - _UP) * e * e / (4.0 * DUNE_EASE)
	var x := t - 1.0 if t > 0.5 else t
	var e := x + DUNE_EASE
	return _DOWN * x + (_UP - _DOWN) * e * e / (4.0 * DUNE_EASE)

## How much of a tower stands at `d`, whose continent layer is `z`: 1 on its
## top, 0 off it. Towers stand in the band below the mesa line and merge into the
## first terrace above it. Their cells are laid out flat on each cube face in
## equal angles, so they keep their size; none stands astride a face's edge.
## (Worked out here rather than through CubeSphere: this runs per height.)
func _tower(d: Vector3, z: float) -> float:
	var floor_z := MESA_FROM - TOWER_BAND
	if z < floor_z or z >= MESA_FROM + MESA_STEP:
		return 0.0
	# The cube face `d` lies on, and its two angles across that face.
	var a := d.abs()
	var face := 0.0
	var x: float
	var y: float
	if a.x >= a.y and a.x >= a.z:
		face = 0.0 if d.x > 0.0 else 1.0
		x = atan(d.y / a.x)
		y = atan(d.z / a.x)
	elif a.y >= a.z:
		face = 2.0 if d.y > 0.0 else 3.0
		x = atan(d.x / a.y)
		y = atan(d.z / a.y)
	else:
		face = 4.0 if d.z > 0.0 else 5.0
		x = atan(d.x / a.z)
		y = atan(d.y / a.z)
	var edge := PI * 0.25 - TOWER_RADIUS.y * TOWER_FOOT / radius
	if absf(x) > edge or absf(y) > edge:
		return 0.0
	# Each face's cells apart from the others'.
	var scale := radius / TOWER_WAVE
	x = x * scale + face * PI * scale
	y *= scale
	var cell := (_tower_cell.get_noise_2d(x, y) + 1.0) * 0.5
	if cell >= TOWER_SHARE:
		return 0.0
	var r := lerpf(TOWER_RADIUS.x, TOWER_RADIUS.y, cell / TOWER_SHARE)
	var gap := (_tower_gap.get_noise_2d(x, y) + 1.0) * TOWER_WAVE
	var stand := clampf((r * TOWER_FOOT - gap) / (r * (TOWER_FOOT - 1.0)), 0.0, 1.0)
	return stand * smoothstep(floor_z, floor_z + TOWER_BAND * 0.25, z)

## A desert's colours: mesa tops ground_high, towers rock, the dunes'
## lowest fifth dust, the rest of the dunes ground_low. Steep ground is rock
## before this is asked.
func _desert_ground(d: Vector3) -> StringName:
	var z := _mesa_continent(d, _continents.get_noise_3dv(d * CONTINENT_SCALE))
	if z >= MESA_FROM:
		return &"ground_high"
	if _tower(d, z) > 0.0:
		return &"rock"
	return &"dust" if _dune(d, z) < DUNE_DUST else &"ground_low"

func _simplex(concern: StringName, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, concern))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n

func _cells(returns: FastNoiseLite.CellularReturnType) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, &"towers"))
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_return_type = returns
	n.frequency = 1.0
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n

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
