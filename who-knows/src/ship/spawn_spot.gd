class_name SpawnSpot
extends RefCounted

## Where a ship spawned for you arrives (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §5): AHEAD in front of you, turned to face
## you, clear of rocks as a warp's drop-out is and CLEAR of every other ship.
## Blocked, it tries the same distance in STEP_DEG steps round you, the ones
## nearest the way you face first, then FARTHER out the same way. Pure: rocks
## are asked through a callable.

const AHEAD := 200.0
const FARTHER := 400.0
const STEP_DEG := 45.0
const CLEAR := 60.0
## The steps round you in the order tried: ahead, then each side, behind last.
const STEPS: Array[int] = [0, 1, -1, 2, -2, 3, -3, 4]

## The spot, or null when nowhere is clear. `from` is where you look from, its
## -z the way you face; `ships` every other ship's hull position; `rock_near`
## takes an engine position and says whether a rock is too near it.
static func find(from: Transform3D, ships: Array[Vector3], rock_near: Callable) -> Variant:
	var up := from.basis.y.normalized()
	var ahead := -from.basis.z.normalized()
	for distance: float in [AHEAD, FARTHER]:
		for step in STEPS:
			var dir := ahead.rotated(up, deg_to_rad(STEP_DEG * step))
			var p := from.origin + dir * distance
			if rock_near.call(p) or _near_a_ship(p, ships):
				continue
			return Transform3D(Basis.looking_at(-dir, up), p)
	return null

static func _near_a_ship(p: Vector3, ships: Array[Vector3]) -> bool:
	for s in ships:
		if p.distance_to(s) < CLEAR:
			return true
	return false
