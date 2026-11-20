class_name WorldPlan
extends RefCounted

## A desert world's plan: where its seas, ranges, plateaus and canyons lie
## (docs/superpowers/specs/2026-11-19-wadis-land-design.md §5). Built once from
## a recipe, on any thread, the same on every one, and never written after:
## its dials, and a map (PlanMap) of fields that sample() reads anywhere. So
## far the map holds only the open ground, dune seas and gravel plains on a
## gentle roll; the seas, ranges, plateaus, canyons and kept discs come later.

enum Land { SEA, DUNES, PLAINS, PLATEAU, MOUNTAINS }

## Metres above radius where a sea's water stands: under Wadoo's lowest
## ground, -31 m.
const SEA_LEVEL := -40.0

# What sample() writes, by index (indices are added at the end, never
# reordered). Heights are metres above radius.

## The base height.
const S_BASE := 0
## Signed metres to the coast: negative at sea, INF with no sea.
const S_SHORE := 1
## The share of open ground that is dune sea, 0 to 1.
const S_DUNES := 2
## Plateau country's weight, 0 to 1, and that region's top.
const S_PLATEAU := 3
const S_PLATEAU_TOP := 4
## Mountains' weight, 0 to 1, and metres from the nearest spine (INF with
## none).
const S_MOUNTAIN := 5
const S_RIDGE := 6
## Metres from the nearest canyon's centreline over its floor's half-width (at
## most 1 on the floor, INF with none); the floor's height; the walls' top
## over the floor, metres.
const S_CANYON := 7
const S_CANYON_FLOOR := 8
const S_CANYON_RIM := 9
## A kept disc's weight, 0 to 1.
const S_KEEP := 10
const S_SIZE := 11

## The open ground's base rolls this many metres either way of the radius, in
## swells about BASE_WAVE metres across: the open desert, never as low as a
## sea.
const BASE_ROLL := 25.0
const BASE_WAVE := 24000.0
## Dune seas and gravel plains lie in patches about DUNES_WAVE metres across:
## S_DUNES is 0.5 plus DUNES_CONTRAST times a noise, so most ground is plainly
## one or the other. Open ground is dune sea where S_DUNES is DUNES_FROM or
## more.
const DUNES_WAVE := 30000.0
const DUNES_CONTRAST := 1.5
const DUNES_FROM := 0.5

var dials: PlanDials
## Metres above radius of the sea's water: SEA_LEVEL, or -INF with no sea.
var sea_level := -INF
var map: PlanMap

static func build(recipe: WorldRecipe) -> WorldPlan:
	var p := WorldPlan.new()
	p.dials = PlanDials.roll(recipe.seed, recipe.radius_m)
	p.dials.pin(recipe.plan_pins)
	p.sea_level = SEA_LEVEL if p.dials.sea > 0.0 else -INF
	p.map = PlanMap.new(S_SIZE)
	p._open_ground(recipe)
	var low := PackedFloat32Array()
	var high := PackedFloat32Array()
	p.map.cell_range(S_BASE, low, high)
	p.map.set_bounds(low, high)
	return p

## Every field at `d` into `out` (S_SIZE long, the caller's own): allocates
## nothing.
func sample(d: Vector3, out: PackedFloat64Array) -> void:
	map.sample(d, out)

func land_at(d: Vector3) -> Land:
	return Land.DUNES if map.at(S_DUNES, d) >= DUNES_FROM else Land.PLAINS

## Vector2(least, most) height of the ground under the quadtree node `key`.
func bounds_of(key: Vector4i) -> Vector2:
	return map.bounds_of(key)

## Fills the map with open ground alone: the base's roll and the dunes'
## patches, from noises of the plan's own that live only while it is built.
## The fields with nothing in them yet hold their none: INF to the coast, a
## spine and a canyon, and no weight.
func _open_ground(recipe: WorldRecipe) -> void:
	var roll := _noise(recipe, &"plan_base", BASE_WAVE, 3)
	var dunes := _noise(recipe, &"plan_dunes", DUNES_WAVE, 2)
	map.fill(S_SHORE, INF)
	map.fill(S_RIDGE, INF)
	map.fill(S_CANYON, INF)
	for face in CubeSphere.FACES:
		for j in PlanMap.SIDE:
			for i in PlanMap.SIDE:
				var d := map.corner_dir(face, i, j)
				map.set_corner(S_BASE, face, i, j, BASE_ROLL * clampf(roll.get_noise_3dv(d), -1.0, 1.0))
				map.set_corner(S_DUNES, face, i, j, clampf(0.5 + DUNES_CONTRAST * dunes.get_noise_3dv(d), 0.0, 1.0))

## A smooth noise for `concern`, its features about `wave` metres across on
## this world, read at unit directions.
static func _noise(recipe: WorldRecipe, concern: StringName, wave: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = WorldSeed.noise_seed(WorldSeed.sub(recipe.seed, concern))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = recipe.radius_m / wave
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n
