class_name RockAvoid
extends RefCounted

## What a pilot steers round (hostile ships spec §5.2): it must never fly into
## an asteroid. Rays from the hull along its velocity and FEELERS more at
## FEELER_ANGLE about it, out as far as it flies in LOOK_AHEAD; a rock hit near
## enough the path to touch a hull of `radius` plus CLEARANCE is steered from,
## across the path, harder the nearer it is. World vectors in, a velocity
## change out; it remembers nothing, so the floating origin cannot catch it.

## Seconds of flight looked ahead.
const LOOK_AHEAD := 8.0
## Metres kept past the hull's radius (its AsteroidStream.ANCHOR_RADIUS meta);
## also the least it looks ahead, however slow.
const CLEARANCE := 80.0
## Rays round the velocity, besides the one along it.
const FEELERS := 4
const FEELER_ANGLE := deg_to_rad(20.0)
## The velocity change (m/s) for a rock right at the hull, per m/s of speed.
const URGENCY := 1.0

## A world velocity change away from the nearest rock (mask AsteroidBody.LAYER)
## within max(speed * LOOK_AHEAD, CLEARANCE) of `from`, flying at `velocity`;
## zero when clear. Away is the hit's normal across the path; a rock dead ahead
## turns it aside all the same.
static func steer(space: PhysicsDirectSpaceState3D, from: Vector3, velocity: Vector3, radius: float,
		exclude: Array[RID]) -> Vector3:
	var speed := velocity.length()
	if space == null or speed < 0.01:
		return Vector3.ZERO
	var ahead := velocity / speed
	var reach := maxf(speed * LOOK_AHEAD, CLEARANCE)
	var clear := radius + CLEARANCE
	var side := ahead.cross(Vector3.UP if absf(ahead.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var nearest := INF
	var normal := Vector3.ZERO
	for i in FEELERS + 1:
		var dir := ahead
		if i > 0:
			var spin := Basis(ahead, TAU * (i - 1) / FEELERS) * side
			dir = Basis(spin, FEELER_ANGLE) * ahead
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach, AsteroidBody.LAYER, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var offset: Vector3 = hit["position"] - from
		var along := offset.dot(ahead)
		# Off the path by more than the hull and its clearance: it passes by.
		if along < 0.0 or (offset - ahead * along).length() > clear:
			continue
		if along < nearest:
			nearest = along
			normal = hit["normal"]
	if nearest == INF:
		return Vector3.ZERO
	var away := normal - ahead * normal.dot(ahead)
	if away.length() < 0.05:
		away = side   # dead ahead: either side will do, so always the same one
	var urgency := clampf(1.0 - nearest / reach, 0.0, 1.0)
	return away.normalized() * speed * URGENCY * urgency
