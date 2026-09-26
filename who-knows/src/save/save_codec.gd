class_name SaveCodec
extends RefCounted

## Engine values to and from the plain arrays a save file holds
## (docs/superpowers/specs/2026-09-26-saving-design.md §8). JSON has only
## numbers, and every number reads back as a float, so each reader here turns
## it back into what it was. Pure and static.

static func vec3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func to_vec3(a: Variant, fallback := Vector3.ZERO) -> Vector3:
	if not (a is Array) or a.size() != 3:
		return fallback
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func vec3i(v: Vector3i) -> Array:
	return [v.x, v.y, v.z]

static func to_vec3i(a: Variant) -> Vector3i:
	if not (a is Array) or a.size() != 3:
		return Vector3i.ZERO
	return Vector3i(int(a[0]), int(a[1]), int(a[2]))

## A rotation, as its quaternion: four numbers, and never a scale.
static func basis(b: Basis) -> Array:
	var q := b.orthonormalized().get_rotation_quaternion()
	return [q.x, q.y, q.z, q.w]

static func to_basis(a: Variant) -> Basis:
	if not (a is Array) or a.size() != 4:
		return Basis.IDENTITY
	var q := Quaternion(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	if q.length_squared() < 0.0001:
		return Basis.IDENTITY
	return Basis(q.normalized())

static func transform(t: Transform3D) -> Dictionary:
	return {"at": vec3(t.origin), "turn": basis(t.basis)}

static func to_transform(d: Variant) -> Transform3D:
	if not (d is Dictionary):
		return Transform3D.IDENTITY
	return Transform3D(to_basis(d.get("turn")), to_vec3(d.get("at")))

## [x, y, z, fx, fy, fz]: whole metres, then the part of a metre past them.
static func upoint(u: UniversePoint) -> Array:
	return [u.x, u.y, u.z, u.fx, u.fy, u.fz]

static func to_upoint(a: Variant) -> UniversePoint:
	var u := UniversePoint.new()
	if not (a is Array) or a.size() != 6:
		return u
	u.x = int(a[0])
	u.y = int(a[1])
	u.z = int(a[2])
	u.fx = float(a[3])
	u.fy = float(a[4])
	u.fz = float(a[5])
	return u

## A cell as a dictionary key: "x,y,z".
static func cell_key(c: Vector3i) -> String:
	return "%d,%d,%d" % [c.x, c.y, c.z]

static func to_cell(key: String) -> Vector3i:
	var parts := key.split(",")
	if parts.size() != 3:
		return Vector3i.ZERO
	return Vector3i(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
