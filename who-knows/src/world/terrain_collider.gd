class_name TerrainCollider
extends RefCounted

## Which of a world's finest chunks must be solid round an anchor
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5.5; Planetfall
## §6.5): every one within REACH plus a second of travel, at most REACH_MAX,
## of an anchor that close to the ground. Pure.
##
## The chunks are found in the face's own grid round the one under the
## anchor -- cells are nearly even on a spherified cube -- and by sampling
## directions only where that window crosses a cube edge.

const REACH := 64.0
const LOOKAHEAD := 1.0
const REACH_MAX := 160.0

static func reach_for(speed: float) -> float:
	return minf(REACH + LOOKAHEAD * speed, REACH_MAX)

## The finest chunks within `reach` of `local` (from the world's centre): the
## one that holds it first, then the rest nearest first; none from the centre
## or from higher than `reach` up.
static func keys_near(terrain: WorldTerrain, depth: int, local: Vector3, reach: float) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	if local.is_zero_approx() or terrain.altitude_of(local) > reach:
		return out
	var under := CubeSphere.key_for(local, depth)
	var edge := CubeSphere.edge_m(terrain.radius, depth)
	var n := ceili(reach / edge) + 1
	var cells := 1 << depth
	var inside := under.z - n >= 0 and under.w - n >= 0 and under.z + n < cells and under.w + n < cells
	if inside:
		for dy in range(-n, n + 1):
			for dx in range(-n, n + 1):
				if dx * dx + dy * dy <= n * n:
					out.append(Vector4i(under.x, depth, under.z + dx, under.w + dy))
	else:
		var up := local.normalized()
		var a := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
		var b := up.cross(a)
		var seen := {}
		var step := edge * 0.5
		var m := ceili((reach + edge) / step)
		for j in range(-m, m + 1):
			for i in range(-m, m + 1):
				var off := a * (i * step) + b * (j * step)
				if off.length() > reach + edge:
					continue
				var k := CubeSphere.key_for(local + off, depth)
				if not seen.has(k):
					seen[k] = true
					out.append(k)
	var centre_of := func(k: Vector4i) -> Vector3:
		var r := CubeSphere.node_rect(k)
		return CubeSphere.direction(k.x, r.x + r.z * 0.5, r.y + r.z * 0.5) * terrain.radius
	# Centres are not the cells: on the spherified cube the nearest centre is
	# sometimes a neighbour's, so the cell under the anchor is put first by hand.
	out.erase(under)
	var d := {}
	for k in out:
		d[k] = (centre_of.call(k) as Vector3).distance_to(local)
	out.sort_custom(func(p: Vector4i, q: Vector4i) -> bool: return d[p] < d[q])
	out.push_front(under)
	return out
