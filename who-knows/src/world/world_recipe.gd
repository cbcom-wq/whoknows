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
##
## DUNES is the one archetype the terrain draw never reaches: a planet with air
## becomes a desert by its own roll (DESERT_SHARE, sub-seed "desert"), so every
## other world keeps the archetype and palette it always had.

enum Kind { PLANET, MOON }
enum Archetype { CRATERED, ROLLING, RIDGED, MESA, DUNES }
enum Atmosphere { NONE, THIN, THICK }

## Part of a world's identity: bumped whenever a seed's world changes.
## 3: a quarter of planets with air became deserts (desert world spec §7.4).
const GENERATOR_VERSION := 3
## The archetypes the terrain draw can pick: all but DUNES.
const DRAWN_ARCHETYPES := 4
## The share of planets with air that are deserts.
const DESERT_SHARE := 0.25
## Radius, metres, by kind: uniform. Worlds you fly down into, not balls you
## orbit (the world scale spec §3.1).
const RADIUS: Array[Vector2] = [Vector2(15000.0, 60000.0), Vector2(4000.0, 15000.0)]
## Surface gravity, m/s2, by kind: capped so every library ship lifts off the
## heaviest planet with ShipRules.LIFT_MARGIN to spare (the desert world spec
## §5.4); the starter's two-way vertical is 9.5 m/s2.
const GRAVITY: Array[Vector2] = [Vector2(2.0, 7.0), Vector2(1.0, 4.0)]
## Where the air ends, as a share of radius above the surface, by Atmosphere
## (NONE / THIN / THICK): the "ground" the gravity hold stops at.
const AIR_TOP: Array[float] = [0.15, 0.12, 0.20]
## Peak-to-trough terrain, as a share of radius, and never more than
## RELIEF_MAX metres: real mountains to fly between.
const RELIEF := Vector2(0.01, 0.025)
const RELIEF_MAX := 1200.0
## Atmosphere weights, NONE / THIN / THICK, by kind: moons are mostly bare.
const ATMOSPHERE_WEIGHTS := [[0.40, 0.35, 0.25], [0.80, 0.20, 0.0]]
## A world's well reaches this many radii: its edge is a radius above the
## ground (the world scale spec §3.1).
const WELL_RADII := 2.0

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
## Hand-made shapes in the ground (TerrainStamp), in the order they apply, outer
## first. Empty unless a design fills it; read-only once built, since every
## thread's terrain reads it.
var stamps: Array[TerrainStamp] = []

static func from_seed(p_seed: int, p_kind := Kind.PLANET) -> WorldRecipe:
	var r := WorldRecipe.new()
	r.seed = p_seed
	r.kind = p_kind
	r.name = WorldNames.world(WorldSeed.rng(p_seed, &"name"))
	var size := WorldSeed.rng(p_seed, &"size")
	r.radius_m = size.randf_range(RADIUS[p_kind].x, RADIUS[p_kind].y)
	r.surface_gravity = WorldSeed.rng(p_seed, &"gravity").randf_range(GRAVITY[p_kind].x, GRAVITY[p_kind].y)
	var terrain := WorldSeed.rng(p_seed, &"terrain")
	r.archetype = terrain.randi_range(0, DRAWN_ARCHETYPES - 1) as Archetype
	r.relief_m = minf(r.radius_m * terrain.randf_range(RELIEF.x, RELIEF.y), RELIEF_MAX)
	r.palette = WorldSeed.rng(p_seed, &"palette").randi_range(0, SpacePalette.DRAWN_PALETTES - 1)
	r.atmosphere = WorldSeed.rng(p_seed, &"atmosphere").rand_weighted(PackedFloat32Array(ATMOSPHERE_WEIGHTS[p_kind])) as Atmosphere
	if p_kind == Kind.PLANET and r.atmosphere != Atmosphere.NONE \
			and WorldSeed.rng(p_seed, &"desert").randf() < DESERT_SHARE:
		r.archetype = Archetype.DUNES
		r.palette = SpacePalette.DESERT_PALETTE
	return r

func is_desert() -> bool:
	return archetype == Archetype.DUNES

## Metres above `radius_m` where this world's air ends: below it gravity holds
## the avatar, loose items and NPCs (the desert world spec §5.1, §6.1). Ships
## feel the whole well, out to well_radius().
func air_top() -> float:
	return radius_m * AIR_TOP[atmosphere]

## How much air a world holds at its ground, by Atmosphere: none, thin, thick
## (the desert world spec §6.1, call 1).
const AIR_GROUND: Array[float] = [0.0, 0.35, 1.0]

## How thick the air is `altitude` metres over the ground, 0 to 1. This is the
## one place air is worked out (spec §6.1, call 1): the ground's value falls
## to nothing at air_top() as the square of the way up, so it thins faster
## near the ground. Thin air tops out at 0.35, not 1.
func air_at(altitude: float) -> float:
	var s := clampf(1.0 - altitude / air_top(), 0.0, 1.0)
	return AIR_GROUND[atmosphere] * s * s

func well_radius() -> float:
	return radius_m * WELL_RADII
