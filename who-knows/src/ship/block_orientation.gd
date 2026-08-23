class_name BlockOrientation
extends RefCounted

## The 24 axis-aligned rotations of a cube, encoded as 0..23.
## Layout: `o >> 2` selects one of six forward directions,
##         `o & 3` selects one of four quarter-turn rolls about it.
##
## Named BlockOrientation rather than Orientation: Godot has a built-in
## global enum called Orientation (HORIZONTAL/VERTICAL, used by Container,
## HSlider and friends). Shadowing it fails loudly rather than silently,
## but the error reads like a typo and would cost real debugging time.

const COUNT := 24

const _FORWARDS := [
	Vector3.FORWARD, Vector3.BACK, Vector3.LEFT,
	Vector3.RIGHT, Vector3.UP, Vector3.DOWN,
]

static func basis_for(o: int) -> Basis:
	var forward: Vector3 = _FORWARDS[(o >> 2) % 6]
	# looking_at needs an up vector that is not parallel to forward.
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	var b := Basis.looking_at(forward, up)
	return b.rotated(forward, (o & 3) * PI * 0.5).orthonormalized()
