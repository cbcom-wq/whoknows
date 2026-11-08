extends RefCounted

## Level ground near a point on any world, for tests that set a ship down and
## expect it to stand level (the flattest-ground search landing_play.gd makes,
## held to a tilt). On a desert the dunes leave no level ground for a ship's
## legs (their gentle side is about 5 deg), but a mesa top, a butte or a sand
## sheet is level. And clear: every world has boulders now, and they are
## solid (GroundCover, in the finest chunks' collision), so level ground with
## a stone on it is not where a ship stands on its legs. Shared by
## test_landing_legs.gd, test_landing_monitor.gd and test_system_scene.gd.

## Level: no point within REACH m rises or falls more than this, as a slope.
const LEVEL := deg_to_rad(0.5)
## Judged on rings this far round the spot, m: wider than the starter's legs.
const REACH := 20.0
## Clear: no boulder comes within this many metres of the spot (to the stone's
## farthest point). The starter's hull reaches 11.4 m from its middle; a disc
## as wide as REACH holds a stone or two on most of a desert's flats.
const CLEAR := 12.0
## The search: rings this far apart, m, out to this far, this many bearings
## round each.
const RING_STEP := 100.0
const SEARCH := 8000.0
const BEARINGS := 24
## Round a level spot with a stone on it, the search looks for a clear one on
## rings this far apart, m, out to this far, this many bearings round each:
## a mesa top or a sand sheet is level for a good way, and its stones sparse.
const NUDGE_STEP := 10.0
const NUDGE := 100.0
const NUDGE_BEARINGS := 16

## The nearest level, clear spot to unit direction `near` on `terrain`'s world
## (the first found ring by ring, each level spot with the ground round it),
## or the levellest found if none is.
static func near(terrain: WorldTerrain, near_dir: Vector3) -> Vector3:
	var a := near_dir.cross(Vector3.UP if absf(near_dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := near_dir.cross(a)
	var best := near_dir
	var least := tilt(terrain, near_dir)
	if least < LEVEL:
		var here := _clear_round(terrain, near_dir)
		if here != Vector3.ZERO:
			return here
	var ring := 1
	while ring * RING_STEP <= SEARCH:
		for k in BEARINGS:
			var o := (a * cos(k * TAU / BEARINGS) + b * sin(k * TAU / BEARINGS)) * (ring * RING_STEP / terrain.radius)
			var d := (near_dir + o).normalized()
			var s := tilt(terrain, d)
			# Clear is only asked round a level spot: it scatters the chunks' cover.
			if s < LEVEL:
				var spot := _clear_round(terrain, d)
				if spot != Vector3.ZERO:
					return spot
			if s < least:
				least = s
				best = d
		ring += 1
	return best

## A level, clear spot at level unit direction `dir` or within NUDGE m of it,
## nearest first; Vector3.ZERO if there is none.
static func _clear_round(terrain: WorldTerrain, dir: Vector3) -> Vector3:
	if clear(terrain, dir):
		return dir
	var a := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := dir.cross(a)
	var ring := 1
	while ring * NUDGE_STEP <= NUDGE:
		for k in NUDGE_BEARINGS:
			var o := (a * cos(k * TAU / NUDGE_BEARINGS) + b * sin(k * TAU / NUDGE_BEARINGS)) \
				* (ring * NUDGE_STEP / terrain.radius)
			var d := (dir + o).normalized()
			if tilt(terrain, d) < LEVEL and clear(terrain, d):
				return d
		ring += 1
	return Vector3.ZERO

## Whether no boulder lies within CLEAR m of unit direction `dir`, along the
## ground, to its farthest point: the boulders of every finest chunk that
## might hold one, as GroundCover scatters them for the collision.
static func clear(terrain: WorldTerrain, dir: Vector3) -> bool:
	var d := dir.normalized()
	var a := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := d.cross(a)
	var depth := CubeSphere.depth_for(terrain.radius)
	var edge := CubeSphere.edge_m(terrain.radius, depth)
	# A stone centred this far off can still reach in.
	var span := CLEAR + GroundCover.BOULDER_SIZE.y * AsteroidRecipe.STRETCH_MAX
	# The square round the spot, sampled at under half a chunk: every chunk in it.
	var steps := ceili(span / (edge * 0.5))
	var keys := {}
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			var o := (a * i + b * j) * (span / steps / terrain.radius)
			keys[CubeSphere.key_for((d + o).normalized(), depth)] = true
	for key: Vector4i in keys:
		var centre := Vector3(TerrainChunkData.centre_of(terrain, key))
		for stone: Array in GroundCover.scatter(terrain, key).boulders:
			var place: Transform3D = stone[0]
			var extent := 0.0
			for p in RockMesh.cut_vertices(stone[1], 0):
				extent = maxf(extent, (place.basis * p).length())
			if d.angle_to(centre + place.origin) * terrain.radius - extent < CLEAR:
				return false
	return true

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
