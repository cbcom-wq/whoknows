class_name AsteroidRecipe
extends RefCounted

## What rocks are where (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §5): a pure function from (seed, tier, cell) to that cell's rocks, the same
## every time, on any thread. Touches no nodes. Each instance has its own
## noise and cache, so give each worker its own.
##
## Cells nest: each tier's cell is NEST times the one below, so a cell lies in
## exactly one cell of every larger tier. A rock stays inside its own cell and
## clear of the rocks of the larger cells around it, so no two rocks ever
## overlap -- which matters, because overlapping bodies fly apart.

enum Tier { RUBBLE, MID, GIANT }

const TIERS := 3
const NEST := 5
## Cell edge per tier, metres.
const CELL: Array[int] = [200, 1000, 5000]
const D_MIN: Array[float] = [1.0, 5.0, 40.0]
const D_MAX: Array[float] = [5.0, 40.0, 300.0]
const MOST: Array[int] = [24, 12, 3]
## Giants live only where density is over this: the cores of fields.
const GIANT_DENSITY := 0.7
const STRETCH_MIN := 0.75
const STRETCH_MAX := 1.25
## Bounding radius per metre of diameter per unit of stretch: over
## RockMesh.REACH, so it covers every shape.
const BOUND := 0.7
const VEINED_CHANCE := 0.1
## Kilograms per cubic metre of diameter: rock at about 2,000 kg/m3 in a rough
## sphere, less voids.
const MASS_PER_M3 := 840.0
## Nothing within this of the start, in any tier.
const START_CLEAR := 150.0
## Density noise, in universe kilometres: fields about 15 km across.
const NOISE_FREQUENCY := 0.05
## Density is the noise shaped: nothing below LOW, a full core above HIGH.
## Set from the noise's own spread: LOW is its median, so about half of space
## is empty; HIGH its 90th percentile, so a tenth is core.
const DENSITY_LOW := 0.5
const DENSITY_HIGH := 0.67
## splitmix64's constants, as signed 64-bit ints.
const _GOLDEN := -7046029254386353131
const _MIX_1 := -4658895280553007687
const _MIX_2 := -7723592293110705685

var world_seed: int
## The centre of the clear bubble at the start, or null for none.
var start: UniversePoint

var _noise: FastNoiseLite
var _cache := {}

func _init(p_seed: int, p_start: UniversePoint = null) -> void:
	world_seed = p_seed
	start = p_start
	_noise = FastNoiseLite.new()
	_noise.seed = p_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = NOISE_FREQUENCY
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3

## How full of rock space is at `u`: 0, empty, to 1, a field's core. The one
## place density is decided -- the hook for keeping fields off worlds later.
func density_at(u: UniversePoint) -> float:
	var n := _noise.get_noise_3d((u.x + u.fx) / 1000.0, (u.y + u.fy) / 1000.0, (u.z + u.fz) / 1000.0)
	return smoothstep(DENSITY_LOW, DENSITY_HIGH, (n + 1.0) * 0.5)

## The density at a cell's centre.
func cell_density(tier: int, cell: Vector3i) -> float:
	var size := CELL[tier]
	var half := size / 2
	return density_at(UniversePoint.at(cell.x * size + half, cell.y * size + half, cell.z * size + half))

## How many rocks a cell tries to place at `density`.
static func count_for(tier: int, density: float) -> int:
	if tier == Tier.GIANT:
		if density <= GIANT_DENSITY:
			return 0
		return roundi((density - GIANT_DENSITY) / (1.0 - GIANT_DENSITY) * MOST[tier])
	return roundi(density * MOST[tier])

## The cell's rocks, in candidate order. Cached.
func cell_rocks(tier: int, cell: Vector3i) -> Array[AsteroidRock]:
	var key := Vector4i(cell.x, cell.y, cell.z, tier)
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 4096:
		_cache.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = cell_seed(world_seed, tier, cell)
	var size := float(CELL[tier])
	var margin := BOUND * D_MAX[tier] * STRETCH_MAX
	var blockers := _blockers(tier, cell)
	var rocks: Array[AsteroidRock] = []
	for i in count_for(tier, cell_density(tier, cell)):
		# Every candidate takes the same draws, placed or not, so one rejection
		# never reshuffles the rest.
		var local := Vector3(rng.randf_range(margin, size - margin), rng.randf_range(margin, size - margin),
			rng.randf_range(margin, size - margin))
		var u := rng.randf()
		var diameter := D_MIN[tier] * pow(D_MAX[tier] / D_MIN[tier], u * u)
		var stretch := Vector3(rng.randf_range(STRETCH_MIN, STRETCH_MAX), rng.randf_range(STRETCH_MIN, STRETCH_MAX),
			rng.randf_range(STRETCH_MIN, STRETCH_MAX))
		var turn := Basis.from_euler(Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI),
			rng.randf_range(-PI, PI)))
		var shape_roll := rng.randf()
		var colour_roll := rng.randi_range(0, SpacePalette.ROCKS.size() - 1)
		var radius := BOUND * diameter * maxf(stretch.x, maxf(stretch.y, stretch.z))
		if _touches(local, radius, rocks, blockers):
			continue
		var rock := AsteroidRock.new()
		rock.tier = tier
		rock.cell = cell
		rock.index = i
		rock.local = local
		rock.turn = turn
		rock.size = stretch * diameter
		rock.radius = radius
		rock.mass = MASS_PER_M3 * rock.size.x * rock.size.y * rock.size.z
		if tier != Tier.RUBBLE and shape_roll < VEINED_CHANCE:
			rock.shape = RockMesh.Shape.VEINED
			rock.colour = SpacePalette.UNTINTED
		else:
			rock.shape = RockMesh.Shape.BOULDER if shape_roll < 0.55 else RockMesh.Shape.SHARD
			rock.colour = SpacePalette.ROCKS[colour_roll]
		rocks.append(rock)
	_cache[key] = rocks
	return rocks

## The universe point at a cell's lowest corner.
static func cell_corner(tier: int, cell: Vector3i) -> UniversePoint:
	var size := CELL[tier]
	return UniversePoint.at(cell.x * size, cell.y * size, cell.z * size)

## The cell of `tier` that holds `u`.
static func cell_of(tier: int, u: UniversePoint) -> Vector3i:
	var size := CELL[tier]
	return Vector3i(floor_div(u.x, size), floor_div(u.y, size), floor_div(u.z, size))

## The cell of the larger `tier` that holds `cell` of `from_tier`.
static func parent_of(from_tier: int, cell: Vector3i, tier: int) -> Vector3i:
	var k := 1
	for i in tier - from_tier:
		k *= NEST
	return Vector3i(floor_div(cell.x, k), floor_div(cell.y, k), floor_div(cell.z, k))

## Integer division rounding toward minus infinity.
static func floor_div(a: int, b: int) -> int:
	var q := a / b
	if a % b != 0 and (a < 0) != (b < 0):
		q -= 1
	return q

## What a new rock here must stay clear of: the rocks of the larger cells
## around it, and the start. Each is [centre from this cell's corner, radius].
func _blockers(tier: int, cell: Vector3i) -> Array:
	var out := []
	var corner := cell_corner(tier, cell)
	for t in range(tier + 1, TIERS):
		var parent := parent_of(tier, cell, t)
		var offset := cell_corner(t, parent).minus(corner)
		for rock in cell_rocks(t, parent):
			out.append([offset + rock.local, rock.radius])
	if start != null:
		out.append([start.minus(corner), START_CLEAR])
	return out

static func _touches(local: Vector3, radius: float, rocks: Array[AsteroidRock], blockers: Array) -> bool:
	for rock in rocks:
		if local.distance_to(rock.local) < radius + rock.radius:
			return true
	for b in blockers:
		if local.distance_to(b[0]) < radius + b[1]:
			return true
	return false

## A cell's generator seed: splitmix64 over (seed, tier, x, y, z). Written out
## rather than the engine's hash(), which is not promised to stay the same
## between engine versions.
static func cell_seed(p_seed: int, tier: int, cell: Vector3i) -> int:
	var h := mix(p_seed)
	for v in [tier, cell.x, cell.y, cell.z]:
		h = mix(h ^ mix(v + _GOLDEN))
	return h

## splitmix64's finalizer on 64-bit ints: wrapping multiplies, and logical
## shifts made from arithmetic ones by masking.
static func mix(x: int) -> int:
	x ^= (x >> 30) & 0x3FFFFFFFF
	x *= _MIX_1
	x ^= (x >> 27) & 0x1FFFFFFFFF
	x *= _MIX_2
	x ^= (x >> 31) & 0x1FFFFFFFF
	return x

## Where a flight starts (§5.6): the first whole kilometre along +z from the
## universe's origin that sits at a field's edge.
func find_start() -> UniversePoint:
	for k in 4000:
		var u := UniversePoint.at(0, 0, k * 1000)
		var d := density_at(u)
		if d >= 0.3 and d <= 0.6:
			return u
	push_warning("AsteroidRecipe: no field edge found; starting at the universe's origin")
	return UniversePoint.at(0, 0, 0)
