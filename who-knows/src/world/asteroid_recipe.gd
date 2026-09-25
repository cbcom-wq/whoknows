class_name AsteroidRecipe
extends RefCounted

## What rocks are where (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §5, as amended by §17): a pure function from (seed, tier, cell) to that
## cell's rocks, the same every time, on any thread. Touches no nodes. Each
## instance has its own noise and cache, so give each worker its own.
##
## Rocks come in groups: each giant cell -- a 5 km region -- holds at most one
## big rock, by a chance the noise sets, so groups are mostly 3 to 6 km apart
## with empty stretches between. Mid-size and rubble rocks crowd round the big
## ones, thickest just off the surface and thinning out over a few of its
## radii; elsewhere there is only a thin sprinkle.
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
const D_MIN: Array[float] = [1.0, 5.0, 150.0]
const D_MAX: Array[float] = [5.0, 40.0, 600.0]
## Candidates per cell: a region has one big rock at most.
const MOST: Array[int] = [40, 16, 1]
## Round a big rock, the chance a candidate is kept just off its surface, per
## tier; it falls off as exp(-height / (HALO_SCALE x radius)) and stops at
## HALO_REACH of those.
const HALO_PEAK: Array[float] = [0.6, 0.6, 0.0]
const HALO_SCALE := 1.0
const HALO_REACH := 4.0
## Away from every big rock, the chance a candidate is kept: a thin sprinkle,
## about one piece of rubble every 270 m and a stray mid-size rock every 1.5 km.
const SPRINKLE: Array[float] = [0.01, 0.02, 0.0]
const STRETCH_MIN := 0.75
const STRETCH_MAX := 1.25
## Bounding radius per metre of diameter per unit of stretch: over
## RockMesh.REACH, so it covers every shape.
const BOUND := 0.7
const VEINED_CHANCE := 0.1
## Kilograms per cubic metre of diameter: rock at about 2,000 kg/m3 in a rough
## sphere, less voids.
const MASS_PER_M3 := 840.0
## The flight starts this far off a big rock's surface, facing it.
const START_STANDOFF := 700.0
## Nothing within this of the start, in any tier: room for the ship.
const START_CLEAR := 80.0
## The noise that makes some stretches of space busier than others, in
## universe kilometres: features about 15 km across.
const NOISE_FREQUENCY := 0.05
## The chance a region holds a group is the noise shaped: none below LOW,
## certain above HIGH. Tuned so groups are mostly 3 to 6 km apart.
const GROUP_LOW := 0.42
const GROUP_HIGH := 0.6
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

## The chance a group is at `u`, 0 to 1. The one place it is decided -- the
## hook for keeping groups off worlds later.
func density_at(u: UniversePoint) -> float:
	var n := _noise.get_noise_3d((u.x + u.fx) / 1000.0, (u.y + u.fy) / 1000.0, (u.z + u.fz) / 1000.0)
	return smoothstep(GROUP_LOW, GROUP_HIGH, (n + 1.0) * 0.5)

## The chance a region (a giant cell) holds a group: taken at its centre.
func group_chance(cell: Vector3i) -> float:
	var size := CELL[Tier.GIANT]
	var half := size / 2
	return density_at(UniversePoint.at(cell.x * size + half, cell.y * size + half, cell.z * size + half))

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
	var chance := group_chance(cell) if tier == Tier.GIANT else 0.0
	var bigs := _big_rocks_near(tier, cell) if tier != Tier.GIANT else []
	var rocks: Array[AsteroidRock] = []
	for i in MOST[tier]:
		var local := Vector3(rng.randf_range(margin, size - margin), rng.randf_range(margin, size - margin),
			rng.randf_range(margin, size - margin))
		var keep := chance if tier == Tier.GIANT else _keep_chance(tier, local, bigs)
		if rng.randf() >= keep:
			continue
		# A kept candidate takes the same draws whether or not it fits, so one
		# that overlaps never reshuffles the rest.
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

## The big rocks whose halo reaches this cell: [centre from its corner,
## radius]. A halo reaches at most half a region, so the region round this
## cell's and its neighbours cover it.
func _big_rocks_near(tier: int, cell: Vector3i) -> Array:
	var out := []
	var corner := cell_corner(tier, cell)
	var size := float(CELL[tier])
	var home := parent_of(tier, cell, Tier.GIANT)
	var region_size := float(CELL[Tier.GIANT])
	var middle := Vector3.ONE * size * 0.5
	# The farthest any big rock's halo reaches from its centre.
	var reach_most := BOUND * D_MAX[Tier.GIANT] * STRETCH_MAX * (1.0 + HALO_REACH * HALO_SCALE)
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var region := home + Vector3i(x, y, z)
				var offset := cell_corner(Tier.GIANT, region).minus(corner)
				# Too far for any halo: skip it before making its rock.
				if box_distance(middle - offset, region_size) - size * 0.87 > reach_most:
					continue
				for big in cell_rocks(Tier.GIANT, region):
					var at := offset + big.local
					var reach := big.radius * (1.0 + HALO_REACH * HALO_SCALE)
					if box_distance(at, size) <= reach:
						out.append([at, big.radius])
	return out

## The chance a candidate at `local` is kept: the sprinkle, plus the halo of
## every big rock near.
static func _keep_chance(tier: int, local: Vector3, bigs: Array) -> float:
	var keep := SPRINKLE[tier]
	for b in bigs:
		var radius: float = b[1]
		var height := maxf(0.0, local.distance_to(b[0]) - radius)
		var scale := HALO_SCALE * radius
		if height < HALO_REACH * scale:
			keep += HALO_PEAK[tier] * exp(-height / scale)
	return minf(keep, 1.0)

## How far `p` (from a box's lowest corner) is from the box [0, size]^3.
static func box_distance(p: Vector3, size: float) -> float:
	return Vector3(maxf(0.0, maxf(-p.x, p.x - size)), maxf(0.0, maxf(-p.y, p.y - size)),
		maxf(0.0, maxf(-p.z, p.z - size))).length()

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

## Where a flight starts (§17): START_STANDOFF off the surface of the first
## big rock along +z from the universe's origin, on its +z side, so it is dead
## ahead of a ship facing -z, with its swarm round it.
func find_start() -> UniversePoint:
	for k in 4000:
		var region := Vector3i(0, 0, k)
		var rocks := cell_rocks(Tier.GIANT, region)
		if rocks.is_empty():
			continue
		var big := rocks[0]
		var at := cell_corner(Tier.GIANT, region).plus(big.local + Vector3(0, 0, big.radius + START_STANDOFF))
		return UniversePoint.at(at.x, at.y, at.z)
	push_warning("AsteroidRecipe: no group found; starting at the universe's origin")
	return UniversePoint.at(0, 0, 0)
