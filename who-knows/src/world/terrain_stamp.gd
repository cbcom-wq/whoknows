class_name TerrainStamp
extends RefCounted

## A hand-made shape in a world's ground (docs/superpowers/specs/
## 2026-11-03-desert-world-design.md §8.1): a flattened disc, a basin or a mesa
## (a raised flat top with a steep edge: Rework 1's ledge), blended into
## WorldTerrain.height_at. It is data a design gives a world; the terrain
## reads it and never changes it (it keeps its own copies, with any level it
## works out), so a recipe stays read-only across threads.
##
## Two stamps on a body either keep apart (blend edges included) or one lies
## wholly inside the other's flat part; they apply in order, outer first.

enum Kind { FLATTEN, BASIN, MESA }

## Ground cover is cleared this far past a stamp's flat part or rim (m).
const CLEAR_MARGIN := 2.0

var id: StringName
var kind: Kind = Kind.FLATTEN
## A unit direction from the world's centre.
var centre := Vector3.UP
## Metres: a FLATTEN's or a MESA's flat part, a BASIN's rim.
var radius := 0.0
## Metres: a FLATTEN's blend out from its flat part; a MESA's fall from its top
## to the ground beneath, straight, as the world's own mesas' risers are.
var edge := 0.0
## A FLATTEN's or a MESA's level, metres above the world's radius_m. NAN: the
## terrain takes the mean of the ground under the flat part.
var level := NAN
## A MESA's top stands this far (m) above its level.
var height := 0.0
## A FLATTEN stands this far (m) above its level.
var raise := 0.0
## A FLATTEN keeps this share (0 to 1) of the land's roll: inside its flat part
## the height is level + keep * (ground before - level), where the ground before
## is what the stamps ahead of it left. 0 is dead flat; the blend outside runs
## from that kept surface to the land.
var keep := 0.0
## A BASIN's flat floor out to this radius (m), and how far under the ground it is.
var floor_radius := 0.0
var depth := 0.0
## A palette key for the ground within `radius`, or none.
var ground: StringName = &""

## Great-circle metres from this stamp's centre to `dir` (a unit direction). Taken
## by atan2 of the cross and dot, which keeps its precision for the few metres
## that matter on a world tens of kilometres across.
func metres_from(dir: Vector3, world_radius: float) -> float:
	return atan2(centre.cross(dir).length(), centre.dot(dir)) * world_radius

## How far from the centre this stamp changes the height (m).
func reach() -> float:
	return radius if kind == Kind.BASIN else radius + edge

## Whether the terrain finds this stamp a level (a FLATTEN or a MESA).
func has_level() -> bool:
	return kind != Kind.BASIN

## A FLATTEN's pull toward its level at `m` metres from the centre: 1 within
## `radius`, easing to 0 over `edge`.
func weight(m: float) -> float:
	if m <= radius:
		return 1.0
	return 1.0 - smoothstep(radius, radius + edge, m)

## A MESA's share of its top at `m` metres from the centre: 1 within `radius`,
## falling straight to 0 over `edge` (6 m over 5.5 m is 47 deg, past the rock
## slope), with a crisp lip and foot as the world's mesas have.
func fall(m: float) -> float:
	if m <= radius:
		return 1.0
	return clampf(1.0 - (m - radius) / edge, 0.0, 1.0) if edge > 0.0 else 0.0

## A BASIN's depth at `m` metres from the centre: `depth` over its floor, easing
## to 0 at the rim.
func dig(m: float) -> float:
	if m <= floor_radius:
		return depth
	if m >= radius:
		return 0.0
	return depth * (1.0 - smoothstep(floor_radius, radius, m))

## The 37 points a FLATTEN's level is the mean of the ground under: the centre,
## and 12 points each on rings at a third, two thirds and all of `radius`.
func level_samples(world_radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = [centre]
	var side := centre.cross(Vector3.UP if absf(centre.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := centre.cross(side)
	for ring in 3:
		var angle := radius * float(ring + 1) / 3.0 / world_radius
		for k in 12:
			var turn := TAU * k / 12.0
			out.append((centre * cos(angle) + (side * cos(turn) + other * sin(turn)) * sin(angle)).normalized())
	return out

func copy() -> TerrainStamp:
	var s := TerrainStamp.new()
	s.id = id
	s.kind = kind
	s.centre = centre
	s.radius = radius
	s.edge = edge
	s.level = level
	s.height = height
	s.raise = raise
	s.keep = keep
	s.floor_radius = floor_radius
	s.depth = depth
	s.ground = ground
	return s
