extends RefCounted

## Level ground near a point on any world, for tests that set a ship down and
## expect it to stand level (the flattest-ground search landing_play.gd makes,
## held to a tilt). On a desert the dunes leave no level ground for a ship's
## legs (their gentle side is about 5 deg), but a mesa top, a butte or a sand
## sheet is level. Shared by test_landing_legs.gd and test_landing_monitor.gd.

## Level: no point within REACH m rises or falls more than this, as a slope.
const LEVEL := deg_to_rad(0.5)
## Judged on rings this far round the spot, m: wider than the starter's legs.
const REACH := 20.0
## The search: rings this far apart, m, out to this far, this many bearings
## round each.
const RING_STEP := 100.0
const SEARCH := 8000.0
const BEARINGS := 24

## The nearest level spot to unit direction `near` on `terrain`'s world (the
## nearest ring holding one, its levellest), or the levellest found if none is.
static func near(terrain: WorldTerrain, near_dir: Vector3) -> Vector3:
	var a := near_dir.cross(Vector3.UP if absf(near_dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := near_dir.cross(a)
	var best := near_dir
	var least := tilt(terrain, near_dir)
	var ring := 1
	while least >= LEVEL and ring * RING_STEP <= SEARCH:
		for k in BEARINGS:
			var o := (a * cos(k * TAU / BEARINGS) + b * sin(k * TAU / BEARINGS)) * (ring * RING_STEP / terrain.radius)
			var d := (near_dir + o).normalized()
			var s := tilt(terrain, d)
			if s < least:
				least = s
				best = d
		ring += 1
	return best

## The steepest the ground rises or falls from unit direction `dir` to any of
## 16 points on rings REACH / 2 and REACH round it, as an angle.
static func tilt(terrain: WorldTerrain, dir: Vector3) -> float:
	var a := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := dir.cross(a)
	var h0 := terrain.height_at(dir)
	var most := 0.0
	for r: float in [REACH * 0.5, REACH]:
		for k in 8:
			var o := (a * cos(k * TAU / 8.0) + b * sin(k * TAU / 8.0)) * (r / terrain.radius)
			most = maxf(most, atan(absf(terrain.height_at((dir + o).normalized()) - h0) / r))
	return most
