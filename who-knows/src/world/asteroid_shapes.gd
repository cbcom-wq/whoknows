class_name AsteroidShapes
extends RefCounted

## Where a star system keeps its rocks (the system skeleton spec §6): belts
## round the star, rings round planets, and the bodies no rock may lie in;
## and, for the warp (docs/superpowers/specs/2026-09-28-warp-design.md §3),
## planets' orbital debris and the belts' clusters.
## Pure data and arithmetic, so AsteroidRecipe can ask it on worker threads
## without ever seeing the system.

## A belt's profile is 1 within this share of its cross-section and eases to
## 0 at its edge.
const BELT_CORE := 0.6
## A ring's profile eases off over this share of its width and thickness.
const RING_EDGE := 0.2
## Rocks keep out of a body's radius times this.
const BLOCK_MARGIN := 1.1
## A debris disc eases off over this share of its width and thickness, outward
## only: its inner edge is the planet's well, a hard stop (the warp spec §3.3).
const DEBRIS_EDGE := 0.4
## A cluster lifts the belt's group noise fully within this share of its
## reach, easing to nothing at its edge (§3.1).
const CLUSTER_CORE := 0.5
## How far towards certain a cluster's heart lifts the chance of a group.
const CLUSTER_LIFT := 0.8

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

## Orbital debris round a planet (the warp spec §3.3): a thick disc from the
## planet's well out to near its warp limit, with holes where other bodies'
## wells lie, so no rock ever lies in a well.
class Debris:
	var centre: UniversePoint
	var normal := Vector3.UP
	var inner: float
	var outer: float
	var half_thickness: float
	## [offset from `centre`, radius] of each well it must leave empty.
	var holes: Array = []

	func profile(u: UniversePoint) -> float:
		return profile_local(u.minus(centre))

	## 0 in the well and the holes, 1 in the disc, easing off outward and
	## towards its faces.
	func profile_local(p: Vector3) -> float:
		var h := p.dot(normal)
		var r := (p - normal * h).length()
		if r < inner or r > outer or absf(h) > half_thickness:
			return 0.0
		for hole: Array in holes:
			if p.distance_to(hole[0]) < hole[1]:
				return 0.0
		var edge_r := (outer - r) / (DEBRIS_EDGE * (outer - inner))
		var edge_h := (half_thickness - absf(h)) / (DEBRIS_EDGE * half_thickness)
		return smoothstep(0.0, 1.0, minf(edge_r, 1.0)) * smoothstep(0.0, 1.0, minf(edge_h, 1.0))

## A belt cluster's reach (§3.1): where the belt's groups crowd.
class Cluster:
	var centre: UniversePoint
	var radius: float

	## 1 within CLUSTER_CORE of its reach, easing to 0 at its edge.
	func profile(u: UniversePoint) -> float:
		var q := u.minus(centre).length() / radius
		return 1.0 - smoothstep(CLUSTER_CORE, 1.0, q)

## A body rocks keep out of.
class Blocker:
	var centre: UniversePoint
	var radius: float

var belts: Array[Belt] = []
var rings: Array[Ring] = []
var blockers: Array[Blocker] = []
var debris: Array[Debris] = []
var clusters: Array[Cluster] = []

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

## The debris discs whose bounds touch the box of edge `size` at `corner`.
func debris_near(corner: UniversePoint, size: float) -> Array[Debris]:
	var out: Array[Debris] = []
	for d in debris:
		if AsteroidRecipe.box_distance(d.centre.minus(corner), size) <= d.outer + d.half_thickness:
			out.append(d)
	return out

## How far towards certain the clusters lift a group's chance at `u`: 0 to
## CLUSTER_LIFT.
func cluster_lift(u: UniversePoint) -> float:
	var best := 0.0
	for c in clusters:
		best = maxf(best, c.profile(u))
	return best * CLUSTER_LIFT

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
