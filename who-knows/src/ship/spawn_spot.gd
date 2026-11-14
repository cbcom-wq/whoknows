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
## How far off the line to you a spawned ship comes in, so its wake streams
## across your view.
const ACROSS_DEG := 60.0
## How far ahead along your velocity a spot must keep CLEAR of: at cruise
## (120 m/s) the brakes need 25 s.
const PATH_SECONDS := 30.0
## How far over the highest ground within its reach a ship spawned in a
## world's well arrives (final review M4): never inside a dune or a mesa.
const GROUND_CLEAR := 10.0

## The spot, or null when nowhere is clear. `from` is where you look from, its
## -z the way you face; `ships` every other ship's hull position; `rock_near`
## takes an engine position and says whether a rock is too near it;
## `velocity` yours, whose next PATH_SECONDS from `from` the spot keeps CLEAR
## of, so a ship spawned while cruising is not parked in your way. `lift`,
## when given, takes a spot and gives it back moved clear of a world's ground
## (clear_of_ground); the rocks, ships and path are judged where it ends.
static func find(from: Transform3D, ships: Array[Vector3], rock_near: Callable,
		velocity := Vector3.ZERO, lift := Callable()) -> Variant:
	var up := from.basis.y.normalized()
	var ahead := -from.basis.z.normalized()
	for distance: float in [AHEAD, FARTHER]:
		for step in STEPS:
			var dir := ahead.rotated(up, deg_to_rad(STEP_DEG * step))
			var p := from.origin + dir * distance
			if lift.is_valid():
				p = lift.call(p)
			if rock_near.call(p) or _near_a_ship(p, ships) or _in_path(p, from.origin, velocity):
				continue
			return Transform3D(Basis.looking_at(-dir, up), p)
	return null

## The way a ship spawned at `spot` travels in (WarpArrival's line): toward
## you, ACROSS_DEG to one side. Straight at you, its wake would hide behind it.
static func arrival_line(spot: Transform3D) -> Vector3:
	var up := spot.basis.y.normalized()
	return (-spot.basis.z.normalized()).rotated(up, deg_to_rad(ACROSS_DEG))

## `p` lifted straight up from the world's `centre` until it is GROUND_CLEAR
## plus `radius` (the ship's ANCHOR_RADIUS) over the highest ground under it
## and eight points `radius` round it; a spot already that high is unchanged.
static func clear_of_ground(p: Vector3, centre: Vector3, terrain: WorldTerrain,
		radius: float) -> Vector3:
	var up := (p - centre).normalized()
	var a := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := up.cross(a)
	var highest := terrain.height_at(up)
	for k in 8:
		var o := (a * cos(k * TAU / 8.0) + b * sin(k * TAU / 8.0)) * (radius / terrain.radius)
		highest = maxf(highest, terrain.height_at((up + o).normalized()))
	var least := terrain.radius + highest + radius + GROUND_CLEAR
	if (p - centre).length() >= least:
		return p
	return centre + up * least

static func _in_path(p: Vector3, from: Vector3, velocity: Vector3) -> bool:
	if velocity == Vector3.ZERO:
		return false
	var t := clampf((p - from).dot(velocity) / velocity.length_squared(), 0.0, PATH_SECONDS)
	return p.distance_to(from + velocity * t) < CLEAR

static func _near_a_ship(p: Vector3, ships: Array[Vector3]) -> bool:
	for s in ships:
		if p.distance_to(s) < CLEAR:
			return true
	return false
