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
## A MESA's top is an ellipse (Rework 1, round 2): `radius` is its long half
## axis, and the short one is radius / stretch (1: a disc).
var stretch := 1.0
## The bearing (deg, clockwise from north at the centre) of a MESA's long
## axis, as the design gave it (`axis` is what the shape uses).
var heading := 0.0
## The unit way along a MESA's long axis, at its centre (a tangent of the
## world). Vector3.ZERO: north.
var axis := Vector3.ZERO
## How far a MESA's edge wanders in and out of its ellipse, as a share of the
## ellipse's radius that way: WOBBLE's low harmonics, their phases from the id.
var wobble := 0.0
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
## A palette key for the ground within `radius` (a MESA's: its top), or none.
var ground: StringName = &""

## A MESA's wobble: [harmonic round its edge, share of `wobble`]; the shares add
## to 1, so the edge is never more than `wobble` out of its ellipse.
const WOBBLE := [[2, 0.5], [3, 0.3], [5, 0.2]]

## The long and short tangents at the centre and the wobble's phases, worked
## out by shape() (copy() calls it, so a terrain's own stamps have them before
## any thread reads them).
var _long := Vector3.ZERO
var _short := Vector3.ZERO
var _phases := PackedFloat64Array()

## Great-circle metres from this stamp's centre to `dir` (a unit direction). Taken
## by atan2 of the cross and dot, which keeps its precision for the few metres
## that matter on a world tens of kilometres across.
func metres_from(dir: Vector3, world_radius: float) -> float:
	return atan2(centre.cross(dir).length(), centre.dot(dir)) * world_radius

## How far from the centre this stamp changes the height (m): a MESA's with its
## long axis and the most its edge wobbles out.
func reach() -> float:
	if kind == Kind.BASIN:
		return radius
	if kind == Kind.MESA and not is_round():
		return radius * (1.0 + wobble) + edge
	return radius + edge

## Whether this stamp's flat part is a disc of `radius` (every FLATTEN and
## BASIN, and a MESA with no stretch and no wobble).
func is_round() -> bool:
	return kind != Kind.MESA or (stretch == 1.0 and wobble == 0.0)

## Works out the long and short tangents at the centre and the wobble's phases.
func shape() -> void:
	var along := axis - centre * centre.dot(axis)
	if along.length() < 1e-9:
		along = Vector3.UP - centre * centre.y
	if along.length() < 1e-9:
		along = Vector3.RIGHT - centre * centre.x
	_long = along.normalized()
	_short = centre.cross(_long).normalized()
	_phases = PackedFloat64Array()
	var h := hash(String(id))
	for k in WOBBLE.size():
		_phases.append(TAU * float((h >> (k * 8)) & 255) / 256.0)

## How far (m) the flat part reaches from the centre toward `dir` (a unit
## direction): `radius`, or for a stretched or wobbled MESA its ellipse that
## way, wobbled. Straight up over the centre it is the short half axis.
func flat_radius(dir: Vector3) -> float:
	if is_round():
		return radius
	if _phases.is_empty():
		shape()
	var t := dir - centre * centre.dot(dir)
	var x := t.dot(_long)
	var y := t.dot(_short)
	var short := radius / stretch
	if x * x + y * y < 1e-18:
		return short
	var turn := atan2(y, x)
	var ellipse := radius * short / sqrt(pow(short * cos(turn), 2.0) + pow(radius * sin(turn), 2.0))
	var out := 0.0
	for k in WOBBLE.size():
		out += float(WOBBLE[k][1]) * sin(float(WOBBLE[k][0]) * turn + _phases[k])
	return ellipse * (1.0 + wobble * out)

## Whether the terrain finds this stamp a level (a FLATTEN or a MESA).
func has_level() -> bool:
	return kind != Kind.BASIN

## A FLATTEN's pull toward its level at `m` metres from the centre: 1 within
## `radius`, easing to 0 over `edge`.
func weight(m: float) -> float:
	if m <= radius:
		return 1.0
	return 1.0 - smoothstep(radius, radius + edge, m)

## A MESA's share of its top at `m` metres from the centre toward `dir`: 1
## within its flat part (flat_radius), falling straight to 0 over `edge` (6 m
## over 5.5 m is 47 deg, past the rock slope), with a crisp lip and foot as the
## world's mesas have.
func fall(m: float, dir := Vector3.ZERO) -> float:
	var top := radius if dir == Vector3.ZERO else flat_radius(dir)
	if m <= top:
		return 1.0
	return clampf(1.0 - (m - top) / edge, 0.0, 1.0) if edge > 0.0 else 0.0

## A BASIN's depth at `m` metres from the centre: `depth` over its floor, easing
## to 0 at the rim.
func dig(m: float) -> float:
	if m <= floor_radius:
		return depth
	if m >= radius:
		return 0.0
	return depth * (1.0 - smoothstep(floor_radius, radius, m))

## The 37 points a FLATTEN's level is the mean of the ground under: the centre,
## and 12 points each on rings at a third, two thirds and all of `radius` (of a
## stretched or wobbled MESA's flat part, each that way).
func level_samples(world_radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = [centre]
	var side := centre.cross(Vector3.UP if absf(centre.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := centre.cross(side)
	for ring in 3:
		for k in 12:
			var turn := TAU * k / 12.0
			var way := side * cos(turn) + other * sin(turn)
			var reach_that_way := radius if is_round() else flat_radius(way)
			var angle := reach_that_way * float(ring + 1) / 3.0 / world_radius
			out.append((centre * cos(angle) + way * sin(angle)).normalized())
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
	s.stretch = stretch
	s.heading = heading
	s.axis = axis
	s.wobble = wobble
	s.raise = raise
	s.keep = keep
	s.floor_radius = floor_radius
	s.depth = depth
	s.ground = ground
	if not s.is_round():
		s.shape()
	return s
