class_name WorldSurface
extends Node3D

## A world's ground at its true place and size
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5): a quadtree on
## each face of a cube-sphere, split finer where the focus is near and never
## drawn behind the horizon, each leaf one chunk of TerrainChunkData.
##
## This part chooses the leaves, and is pure.

## Split a node when the focus is within SPLIT times its edge of it; merge it
## again only beyond MERGE (§5.2). Tuned to 1.3/1.6 for chunk budget per spec §5.6.
const SPLIT := 1.3
const MERGE := 1.6

## The leaves to draw for a focus at `local` (from the world's centre), and
## which nodes are split: [leaves, split]. `was_split` is the last call's
## split, for hysteresis; `bounds` caches each node's bound between calls.
static func select(radius: float, relief: float, depth_max: int, local: Vector3,
		was_split: Dictionary, bounds: Dictionary) -> Array:
	var leaves: Array[Vector4i] = []
	var split := {}
	var reach := horizon_reach(radius, relief, local.length())
	for f in CubeSphere.FACES:
		_walk(Vector4i(f, 0, 0, 0), radius, relief, depth_max, local, reach, was_split, bounds, leaves, split)
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

## A node's [centre, radius], cached.
static func bound_of(key: Vector4i, radius: float, relief: float, bounds: Dictionary) -> Array:
	if not bounds.has(key):
		bounds[key] = CubeSphere.node_bound(key, radius, relief)
	return bounds[key]

static func _walk(key: Vector4i, radius: float, relief: float, depth_max: int, local: Vector3, reach: float,
		was_split: Dictionary, bounds: Dictionary, leaves: Array[Vector4i], split: Dictionary) -> void:
	var b := bound_of(key, radius, relief, bounds)
	var to := (b[0] as Vector3).distance_to(local)
	var near := maxf(to - float(b[1]), 0.0)
	if near > reach:
		return
	var factor := MERGE if was_split.has(key) else SPLIT
	if key.y < depth_max and near < factor * CubeSphere.edge_m(radius, key.y):
		split[key] = true
		for c in CubeSphere.children(key):
			_walk(c, radius, relief, depth_max, local, reach, was_split, bounds, leaves, split)
	else:
		leaves.append(key)
