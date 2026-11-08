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
	# Cells are only nearly even: the window is counted in the one under the
	# anchor's narrower side, as CoverField's is (by the nominal edge it fell
	# short of a 160 m reach where cells are small: Task 7b).
	var rect := CubeSphere.node_rect(under)
	var c00 := CubeSphere.direction(under.x, rect.x, rect.y) * terrain.radius
	var side_u := (CubeSphere.direction(under.x, rect.x + rect.z, rect.y) * terrain.radius).distance_to(c00)
	var side_v := (CubeSphere.direction(under.x, rect.x, rect.y + rect.z) * terrain.radius).distance_to(c00)
	var edge := minf(CubeSphere.edge_m(terrain.radius, depth), minf(side_u, side_v))
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
	# Centres are not the cells: on the spherified cube the nearest centre is
	# sometimes a neighbour's, so the cell under the anchor is put first by hand.
	out.erase(under)
	# The window above is whole cells and one more all round, up to twice the
	# reach's area; only the cells whose ground lies within `reach` along it
	# are kept (Task 7b: in low flight every one of them was a body made and
	# freed). Judged on the sphere under the anchor, ignoring its height, so
	# never fewer than the reach asks for.
	var here := local.normalized() * terrain.radius
	var d := {}
	var kept: Array[Vector4i] = []
	for k in out:
		var r := CubeSphere.node_rect(k)
		var mid := CubeSphere.direction(k.x, r.x + r.z * 0.5, r.y + r.z * 0.5) * terrain.radius
		var chord := 0.0
		for c in 4:
			var corner := CubeSphere.direction(k.x, r.x + r.z * float(c & 1), r.y + r.z * float(c >> 1)) * terrain.radius
			chord = maxf(chord, corner.distance_to(mid))
		if here.distance_to(mid) - chord > reach:
			continue
		d[k] = mid.distance_to(local)
		kept.append(k)
	kept.sort_custom(func(p: Vector4i, q: Vector4i) -> bool: return d[p] < d[q])
	kept.push_front(under)
	return kept
