class_name RockAvoid
extends RefCounted

## What a pilot steers round (hostile ships spec §5.2): it must never fly into
## an asteroid. Rays from the hull along its velocity and FEELERS more at
## FEELER_ANGLE about it, out as far as it flies in LOOK_AHEAD (or, slow to
## brake, as far as it takes to stop); a rock hit near
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
## How fast it backs from a ship already inside the clearance, m/s at least.
const SHY_SPEED := 10.0

## A world velocity change away from the nearest rock (mask AsteroidBody.LAYER)
## in the way, rock_ahead's; zero when clear.
static func steer(space: PhysicsDirectSpaceState3D, from: Vector3, velocity: Vector3, radius: float,
		exclude: Array[RID], brake := 0.0) -> Vector3:
	return swerve(rock_ahead(space, from, velocity, radius, exclude, brake), velocity)

## The nearest rock in the way of a hull at `from` flying at `velocity`: within
## max(speed * LOOK_AHEAD, CLEARANCE) of it -- or, given the `brake` it can stop
## by (m/s²), as far as it would take to stop and keep its CLEARANCE, if that
## is further. {distance: along the path to the hit, normal, reach}, or {}.
static func rock_ahead(space: PhysicsDirectSpaceState3D, from: Vector3, velocity: Vector3,
		radius: float, exclude: Array[RID], brake := 0.0) -> Dictionary:
	var speed := velocity.length()
	if space == null or speed < 0.01:
		return {}
	var ahead := velocity / speed
	var reach := maxf(speed * LOOK_AHEAD, CLEARANCE)
	if brake > 0.0:
		reach = maxf(reach, speed * speed / (2.0 * brake) + CLEARANCE)
	var clear := radius + CLEARANCE
	var side := side_of(ahead)
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
		return {}
	return {"distance": nearest, "normal": normal, "reach": reach}

## The velocity change away from a rock rock_ahead saw, flying at `velocity`:
## the hit's normal across the path, harder the nearer; a rock dead ahead turns
## it aside all the same. Zero for {}.
static func swerve(seen: Dictionary, velocity: Vector3) -> Vector3:
	var speed := velocity.length()
	if seen.is_empty() or speed < 0.01:
		return Vector3.ZERO
	var ahead := velocity / speed
	var normal: Vector3 = seen["normal"]
	var away := normal - ahead * normal.dot(ahead)
	if away.length() < 0.05:
		away = side_of(ahead)   # dead ahead: either side will do, so always the same one
	var urgency := clampf(1.0 - float(seen["distance"]) / float(seen["reach"]), 0.0, 1.0)
	return away.normalized() * speed * URGENCY * urgency

## The fastest it can close on something `distance` m off and still stop
## CLEARANCE short of it, braking at `brake` m/s².
static func stopping_speed(distance: float, brake: float) -> float:
	return sqrt(2.0 * maxf(brake, 0.0) * maxf(distance - CLEARANCE, 0.0))

## A fixed direction across `ahead` (a unit vector).
static func side_of(ahead: Vector3) -> Vector3:
	return ahead.cross(Vector3.UP if absf(ahead.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()

## The other ships a pilot steers round (spec §5.2), which move, so a ray along
## its own velocity cannot see them coming: each of `others` is {at, v, radius}
## (world). Over LOOK_AHEAD of motion relative to it, one whose nearest
## approach comes within both radii and CLEARANCE, and which `brake` (m/s², the
## pilot's weakest axis) cannot stop it short of, is steered from across the
## relative path, harder the sooner; the soonest decides. One already that near
## is backed from. A world velocity change, zero when clear. Pure.
static func steer_ships(from: Vector3, velocity: Vector3, radius: float, brake: float,
		others: Array) -> Vector3:
	var soonest := INF
	var out := Vector3.ZERO
	for other: Dictionary in others:
		var r: Vector3 = other["at"] - from
		var u: Vector3 = velocity - other["v"]
		var dist := r.length()
		var clear := radius + float(other["radius"]) + CLEARANCE
		var t := 0.0
		var away := -r
		var strength := maxf(u.length(), SHY_SPEED)
		if dist >= clear:
			var closing := u.dot(r) / dist
			if closing <= 0.0:
				continue
			t = r.dot(u) / u.length_squared()
			var miss := r - u * t   # it, from here, when nearest
			if t > LOOK_AHEAD or miss.length() >= clear:
				continue
			if closing * closing / (2.0 * maxf(brake, 0.01)) < dist - clear:
				continue   # it can stop short
			away = -miss
			strength = u.length() * URGENCY * (1.0 - t / LOOK_AHEAD)
		if t >= soonest:
			continue
		var ahead := u.normalized() if u.length_squared() > 1e-6 else Vector3.ZERO
		away -= ahead * away.dot(ahead)
		if away.length() < 1.0:
			# Dead on: each turns to its own right of the line between them, so
			# two closing head on part rather than dodge into each other.
			away = side_of(ahead)
		soonest = t
		out = away.normalized() * strength
	return out
