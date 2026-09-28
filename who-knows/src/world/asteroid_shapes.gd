class_name AsteroidShapes
extends RefCounted

## Where a star system keeps its rocks (the system skeleton spec §6): belts
## round the star, rings round planets, and the bodies no rock may lie in.
## Pure data and arithmetic, so AsteroidRecipe can ask it on worker threads
## without ever seeing the system.

## A belt's profile is 1 within this share of its cross-section and eases to
## 0 at its edge.
const BELT_CORE := 0.6
## A ring's profile eases off over this share of its width and thickness.
const RING_EDGE := 0.2
## Rocks keep out of a body's radius times this.
const BLOCK_MARGIN := 1.1

## A torus round `centre`: its centre circle of `radius` in the plane normal
## to `normal`, with an elliptical cross-section.
class Belt:
	var centre: UniversePoint
	var normal := Vector3.UP
	var radius: float
	var half_width: float
	var half_thickness: float

	## 1 in the core, easing to 0 at the edge, 0 outside.
	func profile(u: UniversePoint) -> float:
		var p := u.minus(centre)
		var h := p.dot(normal)
		var r := (p - normal * h).length()
		var q := Vector2((r - radius) / half_width, h / half_thickness).length()
		return 1.0 - smoothstep(BELT_CORE, 1.0, q)

	## How far a point can be from `centre` and still be in the belt.
	func reach() -> float:
		return radius + maxf(half_width, half_thickness)

## A flat annulus round `centre`, in the plane normal to `normal`.
class Ring:
	var centre: UniversePoint
	var normal := Vector3.UP
	var inner: float
	var outer: float
	var half_thickness: float

	## 1 inside the slab, easing off over its last RING_EDGE, 0 outside.
	func profile(u: UniversePoint) -> float:
		var p := u.minus(centre)
		return profile_local(p)

	## The same, for `p` from the ring's centre.
	func profile_local(p: Vector3) -> float:
		var h := p.dot(normal)
		var r := (p - normal * h).length()
		if r < inner or r > outer or absf(h) > half_thickness:
			return 0.0
		var edge_r := minf(r - inner, outer - r) / (RING_EDGE * (outer - inner))
		var edge_h := (half_thickness - absf(h)) / (RING_EDGE * half_thickness)
		return smoothstep(0.0, 1.0, minf(edge_r, 1.0)) * smoothstep(0.0, 1.0, minf(edge_h, 1.0))

## A body rocks keep out of.
class Blocker:
	var centre: UniversePoint
	var radius: float

var belts: Array[Belt] = []
var rings: Array[Ring] = []
var blockers: Array[Blocker] = []

## The deepest any belt goes at `u`, 0 to 1.
func belt_profile(u: UniversePoint) -> float:
	var best := 0.0
	for b in belts:
		best = maxf(best, b.profile(u))
	return best

## The rings whose bounds touch the box of edge `size` at `corner`.
func rings_near(corner: UniversePoint, size: float) -> Array[Ring]:
	var out: Array[Ring] = []
	for g in rings:
		if AsteroidRecipe.box_distance(g.centre.minus(corner), size) <= g.outer:
			out.append(g)
	return out

## The bodies whose kept-out sphere touches the box of edge `size` at
## `corner`: [centre from the corner, radius], as AsteroidRecipe's blockers.
func blockers_near(corner: UniversePoint, size: float) -> Array:
	var out := []
	for b in blockers:
		var at := b.centre.minus(corner)
		var radius := b.radius * BLOCK_MARGIN
		if AsteroidRecipe.box_distance(at, size) <= radius:
			out.append([at, radius])
	return out
