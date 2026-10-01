class_name WorldSurface
extends Node3D

## A world's ground at its true place and size
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5): a quadtree on
## each face of a cube-sphere, split finer where the focus is near and never
## drawn behind the horizon, each leaf one chunk of TerrainChunkData.
##
## This part chooses the leaves, and is pure.

## Split a node when the focus is within SPLIT times its edge of it; merge it
## again only beyond MERGE (§5.2). About 21 leaves a level at 1.5.
const SPLIT := 1.5
const MERGE := 1.8

## The leaves to draw for a focus at `local` (from the world's centre), and
## which nodes are split: [leaves, split]. `was_split` is the last call's
## split, for hysteresis; `bounds` caches each node's bound between calls.
## `height_at` is an optional Callable(direction: Vector3) -> float that returns
## the height above the planet at a given direction; if provided, split decisions
## use the actual ground; if not, they use the planet centre. The relief pad is
## only safe for horizon visibility, not for measuring proximity.
static func select(radius: float, relief: float, depth_max: int, local: Vector3,
		was_split: Dictionary, bounds: Dictionary, height_at := Callable()) -> Array:
	var leaves: Array[Vector4i] = []
	var split := {}
	var reach := horizon_reach(radius, relief, local.length())
	for f in CubeSphere.FACES:
		_walk(Vector4i(f, 0, 0, 0), radius, relief, depth_max, local, reach, was_split, bounds, leaves, split, height_at)
	return [leaves, split]

## How far from a focus `d` from the centre any ground can still be seen: to
## the horizon of the lowest ground, then on to the highest ground beyond it.
## Everywhere, from inside the lowest ground.
static func horizon_reach(radius: float, relief: float, d: float) -> float:
	var low := radius - relief * 0.5
	var high := radius + relief * 0.5
	if d <= low:
		return INF
	return sqrt(d * d - low * low) + sqrt(high * high - low * low)

## A node's [centre, cull_radius, ground, chord], cached. The cull_radius
## (centre + relief/2) is safe for horizon visibility but not for split
## decisions; the chord (cull_radius - relief/2) is the node's actual edge.
## The ground (centre × (radius + height_at)) is the true surface; if height_at
## is not valid, ground = centre.
static func bound_of(key: Vector4i, radius: float, relief: float, bounds: Dictionary, height_at := Callable()) -> Array:
	if not bounds.has(key):
		var b := CubeSphere.node_bound(key, radius, relief)
		var centre: Vector3 = b[0]
		var cull_radius: float = b[1]
		var chord := cull_radius - relief * 0.5
		var ground := centre
		if height_at.is_valid():
			ground = centre.normalized() * (radius + height_at.call(centre.normalized()))
		bounds[key] = [centre, cull_radius, ground, chord]
	return bounds[key]

static func _walk(key: Vector4i, radius: float, relief: float, depth_max: int, local: Vector3, reach: float,
		was_split: Dictionary, bounds: Dictionary, leaves: Array[Vector4i], split: Dictionary, height_at := Callable()) -> void:
	var b := bound_of(key, radius, relief, bounds, height_at)
	var centre: Vector3 = b[0]
	var cull_radius: float = b[1]
	var ground: Vector3 = b[2]
	var chord: float = b[3]
	var to := centre.distance_to(local)
	var cull_near := maxf(to - cull_radius, 0.0)
	if cull_near > reach:
		return
	var ground_near := maxf(ground.distance_to(local) - chord, 0.0)
	var factor := MERGE if was_split.has(key) else SPLIT
	if key.y < depth_max and ground_near < factor * CubeSphere.edge_m(radius, key.y):
		split[key] = true
		for c in CubeSphere.children(key):
			_walk(c, radius, relief, depth_max, local, reach, was_split, bounds, leaves, split, height_at)
	else:
		leaves.append(key)
