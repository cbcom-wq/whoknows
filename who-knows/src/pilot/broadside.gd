class_name Broadside
extends RefCounted

## Which face of its hull a pilot shows its target, and how it turns there
## (hostile ships spec §5.2): the face along which most live turrets can bear
## (each turret's sky map says which way it can fire), the stick that swings it
## onto the target, and how many bolts are coming its way. Pure: hull-local
## directions in, stick out.

## The rate (rad/s) the turn gives up per rad/s already spun, so it brakes
## into the face instead of swinging past.
const DAMPING := 1.0

## The 26 unit directions of a cube's faces, edges and corners.
static var SAMPLES: Array[Vector3] = _samples()

static func _samples() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				if x != 0 or y != 0 or z != 0:
					out.append(Vector3(x, y, z).normalized())
	return out

## The hull-local sample along which the most turrets whose `live[i]` is true
## can bear (`skies[i]`, SkyMaps), ties to the one nearest the nose; the nose
## when there are none.
static func best_face(skies: Array, live: Array) -> Vector3:
	var best := Vector3.FORWARD
	var best_count := 0
	var best_nose := -INF
	for dir: Vector3 in SAMPLES:
		var count := 0
		for i in skies.size():
			if i < live.size() and live[i] and (skies[i] as SkyMap).can_bear(dir):
				count += 1
		var nose := dir.dot(Vector3.FORWARD)
		if count > best_count or (count == best_count and nose > best_nose):
			best = dir
			best_count = count
			best_nose = nose
	return best

## `current` turned by the shortest arc that puts `current * face_local` along
## `to_target` (world).
static func desired_basis(current: Basis, face_local: Vector3, to_target: Vector3) -> Basis:
	var face := (current * face_local).normalized()
	var want := to_target.normalized()
	var axis := face.cross(want)
	var angle := face.angle_to(want)
	if axis.length() < 1e-6:
		if face.dot(want) > 0.0:
			return current
		# Dead away: any half turn about an axis across the face.
		axis = face.cross(Vector3.UP if absf(face.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)
	return (Basis(axis.normalized(), angle) * current).orthonormalized()

## Stick and roll in -1..1 (set_pilot_input's `rotate`: x pitch, y yaw, z
## roll, each a rate about the hull's own axis over ASSIST_TURN_RATE) that turn
## `current` onto `desired`: the error as an axis-angle in hull axes times
## `gain`, less DAMPING of `spin_local` (rad/s, hull axes).
static func rotate_input(current: Basis, desired: Basis, spin_local: Vector3, gain: float) -> Vector3:
	var err := (current.orthonormalized().inverse() * desired.orthonormalized()).get_rotation_quaternion()
	if err.w < 0.0:
		err = -err   # the short way round
	var angle := err.get_angle()
	var error := err.get_axis() * angle if angle > 1e-6 else Vector3.ZERO
	var rate := error * gain - spin_local * DAMPING
	return (rate / FlightComputer.ASSIST_TURN_RATE).clamp(-Vector3.ONE, Vector3.ONE)

## How many of `bolts` not from `own_ship` pass within `miss` of `at` in the
## next `horizon` seconds, by their motion against `own_v` (world). Duck-typed:
## anything with `global_position`, `direction`, `carrier`, `speed`, `source`.
static func inbound(bolts: Array, own_ship: Node, at: Vector3, own_v: Vector3, miss: float, horizon: float) -> int:
	var count := 0
	for bolt in bolts:
		var source: Variant = bolt.source
		if own_ship != null and is_instance_valid(source) and source == own_ship:
			continue
		var r: Vector3 = bolt.global_position - at
		var u: Vector3 = bolt.carrier + bolt.direction * float(bolt.speed) - own_v
		var t := 0.0
		if u.length_squared() > 1e-9:
			t = clampf(-r.dot(u) / u.length_squared(), 0.0, horizon)
		if (r + u * t).length() < miss:
			count += 1
	return count
