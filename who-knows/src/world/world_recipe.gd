class_name WorldRecipe
extends RefCounted

## What a seed decides about one world, a planet or a moon
## (docs/superpowers/specs/2026-09-23-planetfall-design.md §5.2; the system
## skeleton spec §4.1). Pure: no nodes, any thread, the same on every machine.
## Each field draws from its own sub-seed (WorldSeed), so a field added later
## never changes the others.
##
## Built by the system skeleton ahead of Planetfall, which adds terrain,
## boulders and sites under sub-seeds of their own.

enum Kind { PLANET, MOON }
enum Archetype { CRATERED, ROLLING, RIDGED, MESA }
enum Atmosphere { NONE, THIN, THICK }

## Part of a world's identity: bumped whenever a seed's world changes.
const GENERATOR_VERSION := 1
## Radius, metres, by kind: uniform.
const RADIUS: Array[Vector2] = [Vector2(300.0, 1200.0), Vector2(120.0, 400.0)]
## Surface gravity, m/s2, by kind: capped below the starter shuttle's lift of
## about 10.8 m/s2 so no world strands the only ship (Planetfall §5.2).
const GRAVITY: Array[Vector2] = [Vector2(2.0, 8.0), Vector2(1.0, 4.0)]
## Peak-to-trough terrain, as a share of radius, and never more than
## RELIEF_MAX metres.
const RELIEF := Vector2(0.02, 0.06)
const RELIEF_MAX := 72.0
## Atmosphere weights, NONE / THIN / THICK, by kind: moons are mostly bare.
const ATMOSPHERE_WEIGHTS := [[0.40, 0.35, 0.25], [0.80, 0.20, 0.0]]
## A world's well reaches this many radii (Planetfall §7.1).
const WELL_RADII := 3.0

var seed: int
var kind: Kind
var name: String
var radius_m: float
var surface_gravity: float
var archetype: Archetype
var relief_m: float
## An index into SpacePalette.WORLDS.
var palette: int
var atmosphere: Atmosphere

static func from_seed(p_seed: int, p_kind := Kind.PLANET) -> WorldRecipe:
	var r := WorldRecipe.new()
	r.seed = p_seed
	r.kind = p_kind
	r.name = WorldNames.world(WorldSeed.rng(p_seed, &"name"))
	var size := WorldSeed.rng(p_seed, &"size")
	r.radius_m = size.randf_range(RADIUS[p_kind].x, RADIUS[p_kind].y)
	r.surface_gravity = WorldSeed.rng(p_seed, &"gravity").randf_range(GRAVITY[p_kind].x, GRAVITY[p_kind].y)
	var terrain := WorldSeed.rng(p_seed, &"terrain")
	r.archetype = terrain.randi_range(0, Archetype.size() - 1) as Archetype
	r.relief_m = minf(r.radius_m * terrain.randf_range(RELIEF.x, RELIEF.y), RELIEF_MAX)
	r.palette = WorldSeed.rng(p_seed, &"palette").randi_range(0, SpacePalette.WORLDS.size() - 1)
	r.atmosphere = WorldSeed.rng(p_seed, &"atmosphere").rand_weighted(PackedFloat32Array(ATMOSPHERE_WEIGHTS[p_kind])) as Atmosphere
	return r

func well_radius() -> float:
	return radius_m * WELL_RADII
