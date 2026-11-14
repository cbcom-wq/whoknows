class_name TerrainCollider
extends RefCounted

## Which of a world's finest chunks must be solid round an anchor
## (docs/superpowers/specs/2026-09-30-world-scale-design.md §5.5; Planetfall
## §6.5): every one with ground within REACH of where the anchor is or will
## be in the next LOOKAHEAD seconds -- a capsule along its way, not a disc
## (Task 7b fix round 2: a 160 m disc round a hull at 120 m/s was three times
## the ground it could reach in a second, every cell of it a body made and
## freed; and capped at 160 m, a hull over 96 m/s could outrun it). Pure.
##
## The chunks are found in the face's own grid round the ones under the way
## -- cells are nearly even on a spherified cube -- and by sampling
## directions only where that window crosses a cube edge.

const REACH := 64.0
const LOOKAHEAD := 1.0
## The longest way looked along: LOOKAHEAD at 300 m/s. Faster (a dive with
## the assist off reaches ~2 km/s) the way is cut there: 615 keys at 2 km/s
## took 16 ms a tick and no worker could build them in time (Task 7b fix
## round 3). Up to it the guarantee holds; past it, the 64 m round the hull
## and the first 300 m of its way.
const TRAVEL_MAX := 300.0
## How much further a fast anchor's keys are worked out than its way, so
## they last a few ticks: a tenth of the way it would go in LOOKAHEAD
## uncapped, at most LEAD_MAX (WorldSurface). From 1 km/s on that is
## LEAD_MAX, and the way worked out is TRAVEL_MAX + LEAD_MAX long (fix round
## 4 of Task 7b: taken from the capped way it never passed 30 m).
const LEAD := 0.1
const LEAD_MAX := 100.0

## The finest chunks within `reach` of `local` (from the world's centre): the
## one that holds it first, then the rest nearest first; none from the centre
## or from higher than `reach` up, unless `always`. A still anchor's capsule.
static func keys_near(terrain: WorldTerrain, depth: int, local: Vector3, reach: float,
		always := false) -> Array[Vector4i]:
	return keys_along(terrain, depth, local, Vector3.ZERO, reach, always)

## The finest chunks whose ground lies within `reach` of the way from `local`
## to `local + travel` (both from the world's centre), measured along the
## ground under it: the one under `local` first, then the rest nearest it
## first. None from the centre, or if no point of the way comes within
## `reach` of the ground, unless `always` (the ground under the way however
## high it is: the near-ground gate's, which asks from higher than its reach).
## A hull diving at the ground has its way's end under it: the ground under
## that end is in, as is all the ground under the way. A way longer than
## TRAVEL_MAX + LEAD_MAX is cut to it.
static func keys_along(terrain: WorldTerrain, depth: int, local: Vector3, travel: Vector3,
		reach: float, always := false) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	if local.is_zero_approx():
		return out
	travel = travel.limit_length(TRAVEL_MAX + LEAD_MAX)
	var end := local + travel
	if end.is_zero_approx():
		end = local
	# Near the ground anywhere along the way? Sampled every quarter reach,
	# with an eighth of the reach to spare between samples.
	var samples := maxi(ceili(travel.length() / (reach * 0.25)), 1)
	var near := always
	for i in (0 if always else samples + 1):
		var p := local.lerp(end, float(i) / samples)
		if not p.is_zero_approx() and terrain.altitude_of(p) <= reach * 1.125:
			near = true
			break
	if not near:
		return out
	var a := local.normalized() * terrain.radius
	var b := end.normalized() * terrain.radius
	var under := CubeSphere.key_for(local, depth)
	var last := CubeSphere.key_for(end, depth)
	# Cells are only nearly even: the window is counted in the one under the
	# anchor's narrower side, as CoverField's is (by the nominal edge it fell
	# short of a 160 m reach where cells are small: Task 7b).
	var r0 := CubeSphere.node_rect(under)
	var c00 := CubeSphere.direction(under.x, r0.x, r0.y) * terrain.radius
	var side_u := (CubeSphere.direction(under.x, r0.x + r0.z, r0.y) * terrain.radius).distance_to(c00)
	var side_v := (CubeSphere.direction(under.x, r0.x, r0.y + r0.z) * terrain.radius).distance_to(c00)
	var edge := minf(CubeSphere.edge_m(terrain.radius, depth), minf(side_u, side_v))
	var n := ceili(reach / edge) + 1
	var cells := 1 << depth
	var lo := Vector2i(mini(under.z, last.z) - n, mini(under.w, last.w) - n)
	var hi := Vector2i(maxi(under.z, last.z) + n, maxi(under.w, last.w) + n)
	var candidates: Array[Vector4i] = []
	if last.x == under.x and lo.x >= 0 and lo.y >= 0 and hi.x < cells and hi.y < cells:
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				candidates.append(Vector4i(under.x, depth, x, y))
	else:
		# Across a cube edge the faces' grids disagree: the capsule grown by a
		# cell and a half is sampled every half edge in the plane under the
		# anchor, and each sample's cell is a candidate.
		var up := local.normalized()
		var flat := (b - a) - up * (b - a).dot(up)
		var length := flat.length()
		var u := flat / length if length > 0.01 \
			else up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := up.cross(u)
		var grow := reach + edge * 1.5
		var step := edge * 0.5
		var seen := {}
		var i0 := -ceili(grow / step)
		var i1 := ceili((length + grow) / step)
		var j1 := ceili(grow / step)
		for j in range(-j1, j1 + 1):
			for i in range(i0, i1 + 1):
				var along := i * step
				var aside := j * step
				var off := along - clampf(along, 0.0, length)
				if off * off + aside * aside > grow * grow:
					continue
				var k := CubeSphere.key_for(a + u * along + v * aside, depth)
				if not seen.has(k):
					seen[k] = true
					candidates.append(k)
	# Only the cells whose ground lies within `reach` of the way under the
	# anchor are kept, judged on the sphere, ignoring its height, so never
	# fewer than the reach asks for. A cell's own chord is worked out only
	# where it matters: one and a half times the chord of the cell under the
	# anchor (its neighbours are all but the same size) rules out the rest.
	var m0 := CubeSphere.direction(under.x, r0.x + r0.z * 0.5, r0.y + r0.z * 0.5) * terrain.radius
	var rough := 0.0
	for c in 4:
		var corner := CubeSphere.direction(under.x, r0.x + r0.z * float(c & 1), r0.y + r0.z * float(c >> 1)) * terrain.radius
		rough = maxf(rough, corner.distance_to(m0))
	rough *= 1.5
	var d := {}
	var kept: Array[Vector4i] = []
	for k in candidates:
		if k == under:
			continue
		var r := CubeSphere.node_rect(k)
		var mid := CubeSphere.direction(k.x, r.x + r.z * 0.5, r.y + r.z * 0.5) * terrain.radius
		var gap := _to_segment(mid, a, b)
		if gap - rough > reach:
			continue
		var chord := 0.0
		for c in 4:
			var corner := CubeSphere.direction(k.x, r.x + r.z * float(c & 1), r.y + r.z * float(c >> 1)) * terrain.radius
			chord = maxf(chord, corner.distance_to(mid))
		if gap - chord > reach:
			continue
		d[k] = mid.distance_to(a)
		kept.append(k)
	kept.sort_custom(func(p: Vector4i, q: Vector4i) -> bool: return d[p] < d[q])
	kept.push_front(under)
	return kept

## How near finest cell `key` comes to the segment `a`-`b` (points on the
## sphere of `radius`, as keys_along takes them), judged on the sphere as
## keys_along keeps its cells: its middle's distance less its chord, so never
## farther than it is.
static func cell_gap(key: Vector4i, radius: float, a: Vector3, b: Vector3) -> float:
	var r := CubeSphere.node_rect(key)
	var mid := CubeSphere.direction(key.x, r.x + r.z * 0.5, r.y + r.z * 0.5) * radius
	var chord := 0.0
	for c in 4:
		var corner := CubeSphere.direction(key.x, r.x + r.z * float(c & 1), r.y + r.z * float(c >> 1)) * radius
		chord = maxf(chord, corner.distance_to(mid))
	return _to_segment(mid, a, b) - chord

## How near finest cell `key`'s ground comes to the segment `a`-`b` (points
## from the world's middle, in 3D): from the segment's point nearest the
## cell's middle to the cell's own rectangle on its face, held at its highest
## ground (of its middle and corners), so never much farther than it is. The
## near-ground gate builds at once only the cells this puts in reach: flown
## 33 m up, the cells round the one under you are not (cell_gap, on the
## sphere, put every cell within reach along the ground in).
static func ground_gap(key: Vector4i, terrain: WorldTerrain, a: Vector3, b: Vector3) -> float:
	var r := CubeSphere.node_rect(key)
	var mid_dir := CubeSphere.direction(key.x, r.x + r.z * 0.5, r.y + r.z * 0.5)
	var high := terrain.height_at(mid_dir)
	for c in 4:
		high = maxf(high, terrain.height_at(
			CubeSphere.direction(key.x, r.x + r.z * float(c & 1), r.y + r.z * float(c >> 1))))
	var at := terrain.radius + high
	var p := _nearest_on_segment(mid_dir * at, a, b)
	var fuv := CubeSphere.face_uv(p)
	if int(fuv.x) != key.x:
		return cell_gap(key, at, a, b)
	var q := CubeSphere.direction(key.x, clampf(fuv.y, r.x, r.x + r.z), clampf(fuv.z, r.y, r.y + r.z)) * at
	return p.distance_to(q)

static func _nearest_on_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-6:
		return a
	return a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0)

## How far `p` is from the segment `a`-`b`.
static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-6:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))
