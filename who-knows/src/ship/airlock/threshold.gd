class_name Threshold
extends RefCounted

## The maths of crossing an airlock's outer hatch (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §7): carrying a pose and a velocity between
## interior space and the real world, exactly, both ways. Pure.
##
## Interior-local space is hull-local space -- the same grid coordinates on
## the same axes -- except that interior storeys are taller than the grid, so
## on storey `y` the interior sits InteriorBuilder.storey_offset(y) higher.
## That offset is taken off going out and put back coming in.

## How far past the plane the body must be before it crosses, either way, so
## standing exactly on the threshold never flickers between the two.
const HYSTERESIS := 0.02
## Coming in, your speed relative to the ship is capped at walking pace, so a
## fast entry never slams you into the inner hatch.
const ENTRY_SPEED := 4.0

## `pose` (in the world, inside interior space) carried onto the hull.
static func to_world(interior: Transform3D, hull: Transform3D, pose: Transform3D,
		storey_offset: float) -> Transform3D:
	var local := interior.affine_inverse() * pose
	local.origin.y -= storey_offset
	return hull * local

## `pose` in the world carried into interior space: the inverse of to_world.
static func to_interior(interior: Transform3D, hull: Transform3D, pose: Transform3D,
		storey_offset: float) -> Transform3D:
	var local := hull.affine_inverse() * pose
	local.origin.y += storey_offset
	return interior * local

## The velocity of the point `p` of a body moving at `linear` and spinning at
## `angular` about `com` (all in the world).
static func point_velocity(linear: Vector3, angular: Vector3, com: Vector3, p: Vector3) -> Vector3:
	return linear + angular.cross(p - com)

## Going out: the hull's velocity where you cross, plus your own step, turned
## from interior (hull-local) axes into the world's.
static func carry_velocity_out(hull_point_velocity: Vector3, hull_basis: Basis, interior_velocity: Vector3) -> Vector3:
	return hull_point_velocity + hull_basis * interior_velocity

## Coming in: your velocity relative to the hull where you cross, in
## interior axes, capped at ENTRY_SPEED.
static func carry_velocity_in(world_velocity: Vector3, hull_point_velocity: Vector3, hull_basis: Basis) -> Vector3:
	return (hull_basis.inverse() * (world_velocity - hull_point_velocity)).limit_length(ENTRY_SPEED)

## How to stand you up after floating in with your view at `view` (a camera
## basis in interior space, -z forward): {body, pitch, righting}. The body is
## upright facing where you looked; the head keeps your pitch; and `righting`
## is the camera's offset from that upright view to the one you had, which it
## then eases away, so there is never a cut.
static func upright(view: Basis) -> Dictionary:
	var v := view.orthonormalized()
	var forward := -v.z
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.0001:
		# Looking straight up or down: face the way the top of your head was.
		flat = Vector3(v.y.x, 0.0, v.y.z) * signf(-forward.y)
		if flat.length_squared() < 0.0001:
			flat = Vector3.FORWARD
	var body := Basis.looking_at(flat.normalized(), Vector3.UP)
	var pitch := clampf(asin(clampf(forward.y, -1.0, 1.0)), -Avatar.PITCH_LIMIT, Avatar.PITCH_LIMIT)
	var target := (body * Basis(Vector3.RIGHT, pitch)).get_rotation_quaternion()
	var righting := target.inverse() * v.get_rotation_quaternion()
	return {"body": body, "pitch": pitch, "righting": righting}

## True once a body `local_z` along an outer hatch's frame (+z into the room)
## is far enough outside it to have crossed out.
static func crossed_out(local_z: float) -> bool:
	return local_z < -HYSTERESIS

static func crossed_in(local_z: float) -> bool:
	return local_z > HYSTERESIS
