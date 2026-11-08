extends "res://test/probes/descent_render.gd"

# The desert's land (docs/superpowers/specs/2026-11-03-desert-world-design.md
# §7.2; phase 2's Task 3, Checkpoint A), rendered in the flight scene on the
# system's largest desert with thick air (system 1337's p3), on its day side
# with the sun about 30 deg up as descent_render has it. Seated is at the
# starter's helm, looking out of its canopy; on foot is you, out of its airlock.
#
# The spot is chosen on open dunes, off the mesas and the tower band, away
# from the wind axis's poles (where the dunes fade into a sand sheet), with
# dunes at least DUNE_SPOT_RANGE m from trough to crest round it, and a tower
# and a mesa as near as can be found round the ring of ground where the sun is
# SUN_DEG up (and a little off it): so the mesa and the tower are in sight from
# the ground.
#
#   land   from orbit at 3 radii off the centre, the far mesh, straight at the
#          world (orbit_3r) and seated (orbit_3r_seated); at the air top,
#          seated, pitched down to the horizon toward the sun (airtop_sun);
#          seated hovering at 2 km and 300 m, pitched down to the horizon,
#          toward the sun and away (seated_<h>_sun, _away), the 2 km one twice
#          25 m apart to judge shimmer (seated_2000_sun_b), the frame rate
#          seated at each; seated low at 60 m over the dunes, nose across the
#          wind (low_across_wind: along the crests) and along it (downwind,
#          low_along_wind: the ridges across the view); then flown over the
#          dunes at 120 m/s for 10 s, 60 m over the highest crest on the way,
#          the frame rate over the 10 s and a render at the end
#          (low_flight); landed on open dunes, seated (landed_seated, and the
#          frame rate); on foot, eye 1.6 m over the ground, WALK_OFF m off the
#          hatch: toward the sun (foot_sun), away (foot_away), across the
#          ridges upwind at their lee faces (foot_ridges) and downwind
#          (foot_ridges_down), and the frame rate there; then, since beside
#          the ship you stand in a trough, from the nearest crest across the
#          ridges (foot_crest_ridges), and at the nearest mesa (foot_mesa) and
#          the nearest tower (foot_tower), each from the nearest ground toward
#          it with its upper half in sight (you are stood there by hand).
#   cover  Task 7's (boulders, grass and blowing sand): not written yet.
#   all    both.
#
# desert_sheet.png puts the on-foot views beside stage 4 of the concept
# (descent.html's own SVG, rasterised here), over the views from above.
# Every render prints its name, the eye's altitude over the ground, the
# altitude the air is judged at, the air, and the sky. Run it WITHOUT
# --headless:
#
#   godot --path who-knows --resolution 1280x720 \
#     --script res://test/probes/desert_render.gd -- <abs out dir> [land|cover|all]

## From orbit: this many radii off the planet's centre.
const ORBIT_RADII := 3.0
## Seated hovering heights over the ground, m.
const SEATED_HIGH := 2000.0
const SEATED_LOW := 300.0
## The second 2 km render, this far along from the first, m: a shimmer is the
## far dunes changing between the two.
const SHIMMER_STEP := 25.0
## Low flight: this high over the dunes (over the highest crest on the way),
## this fast, this long.
const LOW_FLIGHT := 60.0
const LOW_SPEED := 120.0
const LOW_SECONDS := 10.0
## On foot: this far from the hatch along the ground, m; a crest looked for
## this far upwind and downwind; a mesa aimed at this far past its foot; and
## ground with the mesa or tower in sight looked for in steps of this, this
## far toward it.
const WALK_OFF := 25.0
const CREST_REACH := 200.0
const MESA_BEYOND := 100.0
const STAND_STEP := 10.0
const STAND_REACH := 600.0
## The spot: round the sun's ring, this many bearings, at these offsets off
## it toward and away from the sun, m (each 1 km moves the sun about 1 deg).
const RING_BEARINGS := 144
const RING_OFFSETS: Array[float] = [-2000.0, -1000.0, 0.0, 1000.0, 2000.0]
## Open dunes: the continent layer under this (the tower band begins at
## MESA_FROM - TOWER_BAND, 0.06 today), the wind axis's d . axis under this
## (the dunes fade from DUNE_POLE, 0.9), and the dunes at least this many m
## from trough to crest within 400 m along the wind.
const DUNE_SPOT_MARGIN := 0.005
const DUNE_SPOT_POLE := 0.8
const DUNE_SPOT_RANGE := 12.0
## The search for the nearest tower and mesa: bearings, step and reach, m.
const NEAR_BEARINGS := 72
const TOWER_STEP := 10.0
const TOWER_REACH := 1500.0
const MESA_STEP_M := 50.0
const MESA_REACH := 5000.0
## A tower is rock by rule in the tower band standing this far over the spot.
const TOWER_TALL := 25.0
## The landing: the flattest spot within this many m of the chosen one, in
## steps of this, judged over this reach (the starter's legs' spread).
const LAND_SEARCH := 150.0
const LAND_STEP := 15.0
const LAND_REACH := 15.0
## The contact sheet's tiles, and its two rows: the ground beside the concept,
## and the way down. "mockup" is descent.html's stage 4.
const DESERT_TILE := Vector2i(400, 225)
const DESERT_SHEET := [
	["mockup", "foot_sun", "foot_away", "foot_crest_ridges", "foot_mesa", "foot_tower"],
	["orbit_3r", "airtop_sun", "seated_2000_sun", "seated_300_away", "low_along_wind", "landed_seated"],
]
const MOCKUP := "../docs/superpowers/specs/2026-11-03-desert-world/descent.html"

## The set asked for: land, cover or all.
var _which := "land"
## A terrain of the probe's own for the searches (FastNoiseLite is not
## thread-safe, and the scene's chunk workers have theirs).
var _terrain: WorldTerrain
## The wind at `_spot` (windward to lee, along the ground), and the nearest
## mesa's and tower's foot: [direction, metres from the spot]; INF if none.
var _wind := Vector3.ZERO
var _mesa := [Vector3.ZERO, INF]
var _tower := [Vector3.ZERO, INF]

func _run() -> void:
	await _frames(3)
	_fleet = _scene.get("fleet")
	_starter = _scene.get_node("Ship")
	_director = _scene.get_node("CameraDirector")
	_avatar = get_first_node_in_group(Avatar.GROUP)
	_universe = _scene.get_node("Universe")
	_gravity = _scene.get("world_gravity")
	_stars = _scene.get("star_system")
	_scene.set("reload", func() -> void: pass)
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		_which = args[1]
	if not _which in ["land", "cover", "all"]:
		print("desert  no set called %s: land, cover or all" % _which)
		quit(1)
		return
	print("gpu     %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	if not await _to_the_planet():
		print("desert  no desert to come down on")
		quit(1)
		return
	if not _planet.recipe.is_desert():
		_check(false, "the chosen planet %s is a desert" % _planet.id)
		quit(1)
		return
	_terrain = WorldTerrain.new(_planet.recipe)
	_starter.flight_computer.assist_enabled = true
	_desert_spot()
	await _sit(_starter)
	await _hide_the_card()
	if _which in ["land", "all"]:
		await _land_set()
	if _which in ["cover", "all"]:
		print("SKIPPED cover: Task 7 adds the cover set")
	_desert_sheet()
	_let_go()
	print("        the frame rate:")
	for line in _readings:
		print("        %s" % line)
	print("desert  %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)

## The largest desert with thick air, else the largest desert, else
## descent_render's choice.
func _pick_planet(system: SystemRecipe) -> SystemBody:
	var thick: SystemBody = null
	var any: SystemBody = null
	for p in system.planets():
		var r := p.recipe
		print("        planet %s (%s): radius %.1f km, air %s, %s, palette %s" % [p.name, p.id, p.radius / 1000.0,
			WorldRecipe.Atmosphere.keys()[r.atmosphere], WorldRecipe.Archetype.keys()[r.archetype],
			SpacePalette.WORLDS[r.palette][&"name"]])
		if not r.is_desert():
			continue
		if any == null or p.radius > any.radius:
			any = p
		if r.atmosphere == WorldRecipe.Atmosphere.THICK and (thick == null or p.radius > thick.radius):
			thick = p
	var chosen: SystemBody = thick if thick != null else any if any != null else super(system)
	print("        chosen: %s (%s)%s" % [chosen.name, chosen.id, "" if chosen.recipe.is_desert() else ", NOT a desert"])
	return chosen

# --- the spot ------------------------------------------------------------------

## `_spot` on open dunes with the sun about SUN_DEG up and a tower and a mesa
## near; the landing spot is the flattest open dune within LAND_SEARCH of it.
## The ways toward the sun, across it and the wind's there.
func _desert_spot() -> void:
	var t0 := Time.get_ticks_msec()
	var to_star := _to_star()
	var axis := _tangents(to_star)[0]
	var best := Vector3.ZERO
	var best_score := INF
	var best_line := ""
	var fallback := Vector3.ZERO
	var fallback_range := -1.0
	var seen := 0
	for k in RING_BEARINGS:
		for offset in RING_OFFSETS:
			var d := to_star.rotated(axis, deg_to_rad(90.0 - SUN_DEG) + offset / _planet.radius) \
				.rotated(to_star, k * TAU / RING_BEARINGS).normalized()
			if not _open_dunes(d):
				continue
			seen += 1
			var dunes := _dune_range(d)
			if dunes > fallback_range:
				fallback_range = dunes
				fallback = d
			if dunes < DUNE_SPOT_RANGE:
				continue
			var tower := _nearest_tower(d)
			if float(tower[1]) == INF:
				continue
			var mesa := _nearest_mesa(d)
			if float(mesa[1]) == INF:
				continue
			var score := float(tower[1]) + 0.5 * float(mesa[1])
			if score < best_score:
				best_score = score
				best = d
				best_line = "bearing %d of %d, %.0f m off the ring: dunes %.1f m trough to crest, a tower %.0f m off, a mesa %.0f m off" % [
					k, RING_BEARINGS, offset, dunes, float(tower[1]), float(mesa[1])]
	if best == Vector3.ZERO:
		print("        no open dunes on the ring have both a tower within %.0f m and a mesa within %.0f m: the tallest dunes (%.1f m)" % [
			TOWER_REACH, MESA_REACH, fallback_range])
		best = fallback if fallback != Vector3.ZERO else to_star.rotated(axis, deg_to_rad(90.0 - SUN_DEG))
		best_line = "the fallback"
	print("        the spot: %s (%d open-dune spots of %d looked at, %d ms)" % [best_line, seen,
		RING_BEARINGS * RING_OFFSETS.size(), Time.get_ticks_msec() - t0])
	_spot = _flattest_dune(best)
	_sun_flat = (to_star - _spot * to_star.dot(_spot)).normalized()
	_across = _spot.cross(_sun_flat).normalized()
	_forward = _across
	_wind = _terrain.wind_at(_spot)
	_mesa = _nearest_mesa(_spot)
	_tower = _nearest_tower(_spot)
	print("        landing spot %.0f m from it: the sun %.1f deg up; within %.0f m the ground rises or falls %.2f m; the continent layer %.3f (open dunes under %.3f), d . the wind axis %.2f" % [
		best.angle_to(_spot) * _planet.radius, 90.0 - rad_to_deg(_spot.angle_to(to_star)), LAND_REACH,
		_spread(_spot, LAND_REACH), _terrain.continent_at(_spot), _open_below(), _spot.dot(_terrain.wind_axis)])
	print("        the wind there %.0f deg round from the sun's way (windward to lee); the nearest mesa %.0f m off, %.0f deg round; the nearest tower %.0f m off, %.0f deg round, %.0f m over the spot" % [
		_bearing(_wind), float(_mesa[1]), _bearing(_toward(_mesa[0])), float(_tower[1]), _bearing(_toward(_tower[0])),
		_terrain.height_at(_tower[0]) - _terrain.height_at(_spot)])

func _open_below() -> float:
	return WorldTerrain.MESA_FROM - WorldTerrain.TOWER_BAND - DUNE_SPOT_MARGIN

func _open_dunes(d: Vector3) -> bool:
	return _terrain.continent_at(d) < _open_below() and absf(d.dot(_terrain.wind_axis)) < DUNE_SPOT_POLE

## Trough to crest within 400 m either way along the wind at `d`, m.
func _dune_range(d: Vector3) -> float:
	var w := _terrain.wind_at(d)
	var lo := INF
	var hi := -INF
	for i in 41:
		var h := _terrain.height_at(_off(d, w, (i - 20) * 20.0))
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return hi - lo

## `d` moved `m` metres along the ground the way `w`.
func _off(d: Vector3, w: Vector3, m: float) -> Vector3:
	return (d + w * (m / _planet.radius)).normalized()

## The nearest point from `from` along NEAR_BEARINGS bearings, in `step`s out
## to `reach`, where `test` holds: [direction, metres]; [ZERO, INF] if none.
func _nearest(from: Vector3, test: Callable, step: float, reach: float) -> Array:
	var ab := _tangents(from)
	var best := [Vector3.ZERO, INF]
	for b in NEAR_BEARINGS:
		var w: Vector3 = ab[0] * cos(b * TAU / NEAR_BEARINGS) + ab[1] * sin(b * TAU / NEAR_BEARINGS)
		var s := step
		while s <= minf(reach, float(best[1])):
			var d := _off(from, w, s)
			if test.call(d):
				if s < float(best[1]):
					best = [d, s]
				break
			s += step
	return best

## The nearest mesa: the continent layer at or over MESA_FROM.
func _nearest_mesa(from: Vector3) -> Array:
	return _nearest(from, func(d: Vector3) -> bool: return _terrain.continent_at(d) >= WorldTerrain.MESA_FROM,
		MESA_STEP_M, MESA_REACH)

## The nearest tower: a tall rise, rock by rule, in the tower band.
func _nearest_tower(from: Vector3) -> Array:
	var h0 := _terrain.height_at(from)
	return _nearest(from, func(d: Vector3) -> bool:
		var z := _terrain.continent_at(d)
		return z >= WorldTerrain.MESA_FROM - WorldTerrain.TOWER_BAND and z < WorldTerrain.MESA_FROM \
			and _terrain.ground_at(d, 0.0) == &"rock" and _terrain.height_at(d) - h0 > TOWER_TALL,
		TOWER_STEP, TOWER_REACH)

## The flattest open dune within LAND_SEARCH of `near`.
func _flattest_dune(near: Vector3) -> Vector3:
	var ab := _tangents(near)
	var best := near
	var least := _spread(near, LAND_REACH)
	var n := int(LAND_SEARCH / LAND_STEP)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var d := (near + (ab[0] * i + ab[1] * j) * (LAND_STEP / _planet.radius)).normalized()
			if not _open_dunes(d):
				continue
			var s := _spread(d, LAND_REACH)
			if s < least:
				least = s
				best = d
	return best

## The way along the ground at `_spot` toward `d`.
func _toward(d: Vector3) -> Vector3:
	var v := d - _spot
	return (v - _spot * v.dot(_spot)).normalized()

## Degrees round from the sun's way at `_spot` to `w`, toward `_across`.
func _bearing(w: Vector3) -> float:
	return rad_to_deg(atan2(w.dot(_across), w.dot(_sun_flat)))

# --- the land set ----------------------------------------------------------------

func _land_set() -> void:
	await _from_orbit()
	await _seated_hover()
	await _low()
	await _on_the_dunes()

## From ORBIT_RADII off the centre over the spot: straight at the world from
## there, the hull out of the picture, and seated looking down; then at the
## air top, seated, pitched down to the horizon toward the sun.
func _from_orbit() -> void:
	var r := _planet.radius
	print("orbit   %.0f radii off the centre, %.0f km over the ground" % [ORBIT_RADII, (r * ORBIT_RADII - r) / 1000.0])
	var down := Basis(_level(_spot, _sun_flat).x.normalized(), deg_to_rad(-90.0))
	await _hold_at(_spot, r * ORBIT_RADII - r, _sun_flat, down)
	var at := _starter.canopy_camera.global_position
	await _bare_shot("orbit_3r", Transform3D(Basis.looking_at(_centre() - at, _sun_flat), at))
	await _shot("orbit_3r_seated")
	var top := _planet.recipe.air_top()
	await _hold_at(_spot, top, _sun_flat, _tilt_down(top, _sun_flat))
	await _shot("airtop_sun")

## The probe's camera at `pose` with the hull's own layer out of its mask.
func _bare_shot(shot_name: String, pose: Transform3D) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "ProbeCamera"
		_cam.far = BodyProxy.VIEW_FAR
		_scene.add_child(_cam)
		_cam.add_to_group(Universe.EXTERIOR_SPACE)
	_cam.cull_mask = 1
	await _camera_shot(shot_name, pose)
	_cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER

## Seated hovering at SEATED_HIGH and SEATED_LOW, pitched down to the horizon,
## toward the sun and away; the frame rate seated at each.
func _seated_hover() -> void:
	for h: float in [SEATED_HIGH, SEATED_LOW]:
		print("hover   seated %.0f m over the ground" % h)
		var tilt_sun := _tilt_down(h, _sun_flat)
		var tilt_away := _tilt_down(h, -_sun_flat)
		await _hold_at(_spot, h, _sun_flat, tilt_sun)
		await _shot("seated_%d_sun" % roundi(h))
		if h == SEATED_HIGH:
			await _hold_at(_off(_spot, _sun_flat, SHIMMER_STEP), h, _sun_flat, tilt_sun)
			await _shot("seated_%d_sun_b" % roundi(h))
		await _hold_at(_spot, h, -_sun_flat, tilt_away)
		await _shot("seated_%d_away" % roundi(h))
		await _reading("seated at the starter's helm hovering %.0f m over the dunes, away from the sun, pitched %.1f deg down to the horizon" % [
			_alt(_starter), rad_to_deg(acos(_planet.radius / (_planet.radius + h)))])

## Pitched down by the horizon's dip at `height`, about the level right of a
## nose along `forward`: the horizon lies across the middle of the view.
func _tilt_down(height: float, forward: Vector3) -> Basis:
	var dip := acos(_planet.radius / (_planet.radius + height))
	return Basis(_level(_spot, forward).x.normalized(), -dip)

## Seated LOW_FLIGHT over the dunes at the spot, nose across the wind and
## along it; then flown over the dunes at LOW_SPEED for LOW_SECONDS.
func _low() -> void:
	var across_wind := _spot.cross(_wind).normalized()
	print("low     seated %.0f m over the dunes" % LOW_FLIGHT)
	await _hold_at(_spot, LOW_FLIGHT, across_wind)
	await _shot("low_across_wind")
	await _hold_at(_spot, LOW_FLIGHT, _wind)
	await _shot("low_along_wind")
	await _low_flight()

## A route of LOW_SPEED x LOW_SECONDS (and a margin) from the spot over open
## dunes: along the wind if it stays on them, else against it, else across.
## Flown each physics tick along the great circle, LOW_FLIGHT over the highest
## crest on the way, the hull held level; the frame rate over the flight.
func _low_flight() -> void:
	var length := LOW_SPEED * (LOW_SECONDS + 2.0) + 100.0
	var across_wind := _spot.cross(_wind).normalized()
	var ways := {"along the wind": _wind, "against the wind": -_wind, "across the wind": across_wind,
		"across the wind the other way": -across_wind}
	var chosen := ""
	var start := _off(_spot, -_wind, 100.0)
	for way_name: String in ways:
		var w: Vector3 = ways[way_name]
		var s := _off(_spot, -w, 100.0)
		var ok := true
		var m := 0.0
		while m <= length and ok:
			ok = _terrain.continent_at(_off(s, w, m)) < _open_below()
			m += 50.0
		if ok:
			chosen = way_name
			start = s
			break
	if chosen == "":
		chosen = "along the wind (no way stays on open dunes for %.0f m)" % length
		start = _off(_spot, -_wind, 100.0)
	var way: Vector3 = ways[chosen] if ways.has(chosen) else _wind
	# The great circle from `start` along `way`, and the highest ground on it.
	var axis := start.cross(way).normalized()
	var lo := INF
	var hi := -INF
	var m := 0.0
	while m <= length:
		var h := _terrain.height_at(start.rotated(axis, m / _planet.radius))
		lo = minf(lo, h)
		hi = maxf(hi, h)
		m += 10.0
	var radius := _planet.radius + hi + _starter.stance_depth() + LOW_FLIGHT
	print("low     flown %s at %.0f m/s for %.0f s, %.0f m over the highest crest (the ground %.1f to %.1f m over the radius on the way: %.0f to %.0f m over it)" % [
		chosen, LOW_SPEED, LOW_SECONDS, LOW_FLIGHT, lo, hi, LOW_FLIGHT, LOW_FLIGHT + hi - lo])
	await _hold_at(start, hi - _terrain.height_at(start) + LOW_FLIGHT, way)
	await _seconds(1.0)
	var flown := [0.0, INF, -INF]
	var fly := func() -> void:
		flown[0] = float(flown[0]) + LOW_SPEED / Engine.physics_ticks_per_second
		var dir := start.rotated(axis, float(flown[0]) / _planet.radius)
		var nose := axis.cross(dir).normalized()
		_starter.exterior.global_transform = Transform3D(_level(dir, nose), _centre() + dir * radius)
		var over := _alt(_starter)
		flown[1] = minf(float(flown[1]), over)
		flown[2] = maxf(float(flown[2]), over)
	physics_frame.connect(fly)
	var shifts := _universe.shifts
	var fps := await _fps(LOW_SECONDS)
	var line := "fps     %.0f seated in low flight at %.0f m/s over the dunes for %.0f s (%.0f m flown %s, %.0f to %.0f m over the ground under the keel, air %.3f, the origin shifted %d times) %s" % [
		fps, LOW_SPEED, LOW_SECONDS, float(flown[0]), chosen, float(flown[1]), float(flown[2]), _stars.whereabouts.air(),
		_universe.shifts - shifts, _ms()]
	print(line)
	_readings.append(line)
	_check(fps >= FPS_FLOOR, "fps %.0f seated in low flight at %.0f m/s, %.0f m over the dunes (at least %.0f)" % [
		fps, LOW_SPEED, LOW_FLIGHT, FPS_FLOOR])
	await _shot("low_flight")
	physics_frame.disconnect(fly)

## Landed on the open dunes at `_spot`: seated, and the frame rate; out of the
## airlock on foot WALK_OFF m off the hatch, eye 1.6 m over the ground: toward
## the sun, away, across the ridges both ways, and the frame rate; then from
## the nearest crest, and at the nearest mesa and the nearest tower.
func _on_the_dunes() -> void:
	print("ground  landed on open dunes")
	if not await _land_here(_spot, _across, "ground"):
		return
	await _seconds(1.0)
	await _shot("landed_seated")
	await _reading("seated at the starter's helm landed on open dunes")
	_director.stand_now()
	await _frames(3)
	var lock: Airlock = _starter.airlocks.values()[0]
	if not await _out_through(lock, "", "ground"):
		return
	await _walk_away(func() -> Vector3: return lock.beacon(), WALK_OFF, 12.0)
	var eye := _gravity.altitude_at(_avatar.camera.global_position)
	print("        on foot %.1f m off the hatch along the ground, eye %.2f m over the ground (%.2f over your feet)" % [
		_flat(_avatar.global_position - lock.beacon()).length(), eye,
		(_avatar.camera.global_position - _avatar.global_position).dot(_avatar.up)])
	_check(absf(eye - EYE) < 0.15, "ground the eye %.2f m over the ground on foot (%.1f within 0.15)" % [eye, EYE])
	var sun_way := _flat(_sun_dir())
	var here := _up(_avatar.global_position)
	var wind := _terrain.wind_at(here)
	await _foot_view("foot_sun", sun_way, SUN_PITCH)
	await _foot_view("foot_away", -sun_way, 0.0)
	await _foot_view("foot_ridges", -wind, 0.0)
	await _foot_view("foot_ridges_down", wind, 0.0)
	_face(-sun_way)
	_avatar.set_head_pitch(0.0)
	await _seconds(0.5)
	await _reading("on foot %.0f m off the hatch on open dunes, away from the sun, eye %.2f m over the ground" % [
		_flat(_avatar.global_position - lock.beacon()).length(), eye])
	# Beside the ship you stand in a trough (the landing wants the flattest
	# ground), and the next dune hides everything past it: the crest, the mesa
	# and the tower are each seen from the nearest ground with them in view.
	await _crest_view("foot_crest_ridges", here, wind)
	await _foot_at("foot_mesa", _nearest_mesa(here), MESA_BEYOND)
	await _foot_at("foot_tower", _nearest_tower(here), 0.0)

## On foot, facing `way` along the ground, the head `pitch` deg up.
func _foot_view(shot_name: String, way: Vector3, pitch: float) -> void:
	_face(way)
	_avatar.set_head_pitch(deg_to_rad(pitch))
	await _seconds(0.5)
	await _shot(shot_name)

## On foot on the highest ground within CREST_REACH m upwind or downwind of
## `from`, looking upwind across the ridges at their lee faces.
func _crest_view(shot_name: String, from: Vector3, wind: Vector3) -> void:
	var best := from
	var m := -CREST_REACH
	while m <= CREST_REACH:
		var d := _off(from, wind, m)
		if _terrain.height_at(d) > _terrain.height_at(best):
			best = d
		m += 5.0
	await _stand_at(best, -_terrain.wind_at(best))
	print("        %s: on a crest %.0f m from where you stood, %.1f m higher" % [shot_name,
		from.angle_to(best) * _planet.radius, _terrain.height_at(best) - _terrain.height_at(from)])
	_avatar.set_head_pitch(0.0)
	await _seconds(0.5)
	await _shot(shot_name)

## You, stood on the ground at `dir`, facing `way` along it, at rest.
func _stand_at(dir: Vector3, way: Vector3) -> void:
	var up := dir.normalized()
	_avatar.place(Transform3D(_level(up, way), _centre() + up * (_ground_r(up) + 0.1)))
	await _seconds(0.5)
	_face(way)

## On foot, facing `near` (from _nearest: [foot's direction, metres]), the head
## pitched halfway up to the ground `beyond` m past its foot. If the dunes
## between hide its upper half from where you stand, you are stood first on
## the nearest ground toward it (STAND_STEP m apart, up to STAND_REACH) from
## which they do not.
func _foot_at(shot_name: String, near: Array, beyond: float) -> void:
	if float(near[1]) == INF:
		_check(false, "%s: none within reach of the spot" % shot_name)
		return
	var foot: Vector3 = near[0]
	var from := _up(_avatar.global_position)
	var w := foot - from
	w = (w - from * w.dot(from)).normalized()
	var top := _off(foot, w, beyond)
	var top_h := _terrain.height_at(top)
	var aim := _centre() + top * (_planet.radius + (top_h + _terrain.height_at(foot)) * 0.5)
	var moved := 0.0
	var m := 0.0
	var reach := minf(STAND_REACH, float(near[1]) - 100.0)
	while m <= reach:
		var d := _off(from, w, m)
		if _in_sight(_centre() + d * (_ground_r(d) + EYE), aim):
			moved = m
			break
		m += STAND_STEP
	if m > reach:
		moved = -1.0
	elif moved > 0.0:
		await _stand_at(_off(from, w, moved), w)
	var target := _centre() + top * (_planet.radius + top_h)
	var eye := _avatar.camera.global_position
	var to := target - eye
	_face(to)
	_avatar.set_head_pitch(atan2(to.dot(_avatar.up) * 0.5, _flat(to).length()))
	print("        %s: %.0f m off along the ground, its top %.0f m over your eye; %s" % [shot_name, _flat(to).length(),
		to.dot(_avatar.up), "in sight from where you stood" if moved == 0.0 else "stood %.0f m toward it first, where its upper half is in sight" % moved
		if moved > 0.0 else "its upper half hidden from every spot within %.0f m toward it" % reach])
	await _seconds(0.5)
	await _shot(shot_name)

## Whether nothing of the ground stands between engine points `a` and `b`.
func _in_sight(a: Vector3, b: Vector3) -> bool:
	var n := int(a.distance_to(b) / 10.0)
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		var r := p - _centre()
		if r.length() < _ground_r(r.normalized()) + 0.5:
			return false
	return true

## As descent_render's _land, set down at `at` itself: the probe chose it.
func _land_here(at: Vector3, forward: Vector3, step: String) -> bool:
	await _unland()
	_starter.exterior.freeze = false
	_starter.flight_computer.assist_enabled = true
	_place(_starter, at, 3.0, forward)
	await _ground_built()
	var legs := _starter.exterior_builder.legs()
	await _until(func() -> bool: return legs.is_down(), 4.0)
	var end := Time.get_ticks_msec() + 15000
	while _starter.landing.state == LandingMonitor.State.FLYING and Time.get_ticks_msec() < end:
		_hold_sink(_starter, 1.0)
		await physics_frame
	_stick_y(0.0)
	var landed := await _until(func() -> bool: return _starter.landing.is_landed(), 10.0)
	_check(landed, "%s the starter landed on %s's open dunes, the sun %.0f deg up, tilt %.1f deg; within %.0f m the ground rises or falls %.2f m" % [
		step, _planet.name, 90.0 - rad_to_deg(at.angle_to(_to_star())), rad_to_deg(_starter.landing.tilt()),
		LAND_REACH, _spread(at, LAND_REACH)])
	_check_stick(_starter, step)
	return landed

# --- the renders -----------------------------------------------------------------

## One render, once the air's mood has caught up, as desert_<name>.png; its
## name, the eye's altitude over the ground, the air there and the sky.
func _shot(shot_name: String) -> void:
	await _seconds(0.3)
	await _frames(5)
	var image := root.get_viewport().get_texture().get_image()
	var file := "%s/desert_%s.png" % [_out, shot_name]
	image.save_png(file)
	print("render  %s" % file)
	_images[shot_name] = image
	var w := _stars.whereabouts
	var env := _env()
	var sky := _sky()
	var eye := _eye_altitude()
	print("air     %s: the eye %.1f m over the ground, the air judged at %.0f m, air %.4f, sun_up %.3f, fog %s %s, sky top #%s horizon #%s" % [
		shot_name, eye, w.altitude(), w.air(), w.sun_up(), "on" if env.fog_enabled else "off",
		_sci(env.fog_density), sky.sky_top_color.to_html(false), sky.sky_horizon_color.to_html(false)])

## How high the eye that sees the outside is over the ground under it: the
## probe's camera if it is the one drawing, else yours on foot, else the
## canopy's seated (the viewport's camera is then the cabin's, elsewhere).
func _eye_altitude() -> float:
	var cam: Camera3D = _starter.canopy_camera
	if _cam != null and _cam.current:
		cam = _cam
	elif _avatar.mode == Avatar.Mode.FIELD:
		cam = _avatar.camera
	var p := cam.global_position
	return (p - _centre()).length() - _ground_r(_up(p))

## desert_sheet.png: DESERT_SHEET's renders at DESERT_TILE size, the concept's
## stage 4 first.
func _desert_sheet() -> void:
	var mock := _mockup()
	if mock != null:
		_images["mockup"] = mock
	var cols := (DESERT_SHEET[0] as Array).size()
	var sheet := Image.create_empty(DESERT_TILE.x * cols, DESERT_TILE.y * DESERT_SHEET.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for row in DESERT_SHEET.size():
		for col in (DESERT_SHEET[row] as Array).size():
			var shot_name: String = DESERT_SHEET[row][col]
			if not _images.has(shot_name):
				print("        the sheet has no %s" % shot_name)
				continue
			var tile := (_images[shot_name] as Image).duplicate() as Image
			tile.convert(Image.FORMAT_RGBA8)
			tile.resize(DESERT_TILE.x, DESERT_TILE.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, DESERT_TILE), Vector2i(col * DESERT_TILE.x, row * DESERT_TILE.y))
	var file := "%s/desert_sheet.png" % _out
	sheet.save_png(file)
	print("render  %s (rows: %s)" % [file, " / ".join(DESERT_SHEET.map(func(r: Array) -> String: return ", ".join(r)))])

## Stage 4 of descent.html, its own SVG rasterised at DESERT_TILE; null if the
## file or the stage is not found.
func _mockup() -> Image:
	var path := ProjectSettings.globalize_path("res://").path_join(MOCKUP).simplify_path()
	var text := FileAccess.get_file_as_string(path)
	var at := text.find("<!-- 4 GROUND -->")
	var from := text.find("<svg", at) if at >= 0 else -1
	var to := text.find("</svg>", from) if from >= 0 else -1
	if to < 0:
		print("        no stage 4 in %s: the sheet goes without the concept" % path)
		return null
	var image := Image.new()
	var err := image.load_svg_from_string(text.substr(from, to + 6 - from), DESERT_TILE.x / 320.0)
	if err != OK:
		print("        stage 4's SVG did not load (%s): the sheet goes without the concept" % error_string(err))
		return null
	print("        the concept's stage 4 from %s, %d x %d" % [path, image.get_width(), image.get_height()])
	return image
