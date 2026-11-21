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
#   cover  Task 7's: the boulders, the grass and the blowing sand (spec §7.2,
#          §7.3). Landed among grass, the nose toward the most of it, seated
#          (cover_seated, and the frame rate over 10 s); on foot in the
#          grassiest ground near (across the sun's way from the hull, so the
#          ship is in neither view), eye 1.6 m over the ground, toward the sun
#          and away with the sand blowing (cover_sand_sun, cover_sand_away)
#          and the same with the sand hidden by hand (cover_still_sun,
#          cover_still), and the frame rate with it and without; on foot at
#          the nearest mesa's foot among its boulders (cover_talus) and before
#          the nearest tower (cover_tower); seated, flown COVER_LOW over the
#          ground (its highest within LOW_WINDOW either way) along a talus
#          band at 120 m/s and at the speed limit there (at least FAST_LEAST), for COVER_SECONDS
#          each: the frame rate, and each second the blocks CoverField still
#          wants ahead and the blocks that appeared within POP_NEAR m ahead
#          (cover_low, cover_low_fast); then the starter brought down at SINK
#          m/s onto the densest talus spot within TALUS_REACH m of the nearest
#          talus: the monitor's word (landed and its tilt, or its refusal),
#          the damage (none) and any stone inside the hull's colliders, rendered from
#          25 m at eye height from two sides (cover_starter_boulders_a, _b),
#          and the frame rate on foot 6 m off it; then the heaviest library
#          ship (the Warden) the same way (cover_warden_boulders).
#   all    both.
#
# desert_sheet.png puts the on-foot views beside stage 4 of the concept
# (descent.html's own SVG, rasterised here), over the views from above, and
# under them the cover set's.
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
## A planned desert's spot search (_plateau_edge_spot): the sun's elevation
## over the plateau edge cells looked at, the rings round each, m, and the
## cells looked at once a spot is found.
const EDGE_SUN_MIN := 15.0
const EDGE_SUN_MAX := 50.0
const EDGE_RINGS: Array[float] = [400.0, 800.0, 1200.0]
const EDGE_CELLS := 12
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
	["cover_sand_sun", "cover_sand_away", "cover_still", "cover_talus", "cover_tower", "cover_seated"],
	["cover_low", "cover_low_fast", "cover_starter_boulders_a", "cover_starter_boulders_b", "cover_warden_boulders"],
]
## The cover set. Landing among grass: the spot within COVER_SEARCH m of the
## landing spot, in steps of COVER_STEP, with the most tufts within
## GRASS_SEEN m, no stone within HULL_CLEAR m and the ground within LAND_REACH
## rising or falling at most GRASS_LAND_SPREAD m. On foot: the grassiest
## ground (tufts within GRASS_NEAR) GRASS_OFF to GRASS_STAND m from it, no
## stone within STONE_CLEAR m.
const COVER_SEARCH := 250.0
const COVER_STEP := 10.0
const GRASS_SEEN := 25.0
const HULL_CLEAR := 12.0
const GRASS_LAND_SPREAD := 1.0
const GRASS_NEAR := 8.0
const GRASS_OFF := 18.0
const GRASS_STAND := 60.0
const STONE_CLEAR := 1.0
## Before a mesa or a tower: this far back from its foot toward the spot, in
## talus (a mesa's, up to TALUS_BACK_MOST); the head pitched up to at most
## this, deg.
const FOOT_BACK := 120.0
const TALUS_BACK_MOST := 300.0
const FOOT_PITCH_MOST := 8.0
## The talus: the nearest within TALUS_SEARCH m of the spot (in steps of
## TALUS_STEP), and the densest spot within TALUS_REACH of that: the most
## stones reaching within TALUS_NEAR m (the starter's hull reaches 11.4 m from
## its middle), on ground whose own slope within LAND_REACH is at most
## TALUS_TILT deg (so a refusal is the stones', not the ground's).
const TALUS_SEARCH := 2000.0
const TALUS_STEP := 10.0
const TALUS_REACH := 300.0
const TALUS_NEAR := 12.0
const TALUS_TILT := 8.0
## Low over the talus: this high over the highest ground within LOW_WINDOW m
## either way along the route, for this long, at 120 m/s and at the limit.
const COVER_LOW := 30.0
const LOW_WINDOW := 50.0
const COVER_SECONDS := 10.0
## The fast flight's speed at least, m/s (the brief's "about 150").
const FAST_LEAST := 150.0
## A block appearing nearer than this ahead is a pop.
const POP_NEAR := 100.0
## The boulder landings start this high (the plane the legs stand on, over
## the ground), and come down at landing_play's SINK.
const BOULDER_DROP := 12.0
## The camera for a landed ship: this far out from its hull's reach, at eye
## height; at least BOULDER_VIEW from its middle.
const BOULDER_VIEW := 25.0
const VIEW_OFF := 13.0
## While the Warden comes down the starter hovers this far behind the
## camera's spot from it, this high, so the cover is drawn round the landing
## and the starter is out of the shot.
const WATCH_BACK := 50.0
const WATCH_HIGH := 20.0
const MOCKUP := "../docs/superpowers/specs/2026-11-03-desert-world/descent.html"

## The set asked for: land, cover or all.
var _which := "land"
## A terrain of the probe's own for the searches (FastNoiseLite is not
## thread-safe, and the scene's chunk workers have theirs).
var _terrain: WorldTerrain
## The wind at `_spot` (windward to lee, along the ground), and the nearest
## mesa's and tower's foot: [direction, metres from the spot]; INF if none.
var _wind := Vector3.ZERO
var _plan_fields := PackedFloat64Array()
var _mesa := [Vector3.ZERO, INF]
var _tower := [Vector3.ZERO, INF]
## The cover set's landing spots: among grass, and the densest talus (ZERO if
## none was found).
var _grass_spot := Vector3.ZERO
var _talus_spot := Vector3.ZERO

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
		await _cover_set()
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
	if best == Vector3.ZERO and _terrain.plan != null:
		var found := _plateau_edge_spot()
		if found != Vector3.ZERO:
			best = found
			best_line = "a planned plateau's edge band, found from the plan's cells"
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
	if _terrain.plan != null:
		# A planned desert's open dunes are the plan's dune land.
		return _terrain.plan.land_at(d) == WorldPlan.Land.DUNES and absf(d.dot(_terrain.wind_axis)) < DUNE_SPOT_POLE
	return _terrain.continent_at(d) < _open_below() and absf(d.dot(_terrain.wind_axis)) < DUNE_SPOT_POLE

## The plan's plateau weight (S_PLATEAU) at `d`: its country from
## WorldPlan.PLATEAU_FROM, its edge band below that.
func _plateau_at(d: Vector3) -> float:
	if _plan_fields.is_empty():
		_plan_fields.resize(WorldPlan.S_SIZE)
	_terrain.plan.sample(d, _plan_fields)
	return _plan_fields[WorldPlan.S_PLATEAU]

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
## On a planned desert a mesa is its plateau country, S_PLATEAU at or over
## WorldPlan.PLATEAU_FROM: the terraced edge climbing to the region's top.
func _nearest_mesa(from: Vector3) -> Array:
	if _terrain.plan != null:
		return _nearest(from, func(d: Vector3) -> bool: return _plateau_at(d) >= WorldPlan.PLATEAU_FROM,
			MESA_STEP_M, MESA_REACH)
	return _nearest(from, func(d: Vector3) -> bool: return _terrain.continent_at(d) >= WorldTerrain.MESA_FROM,
		MESA_STEP_M, MESA_REACH)

## The nearest tower: a tall rise, rock by rule, in the tower band.
## On a planned desert a tower stands on the outer half of a plateau's edge
## band (S_PLATEAU over 0, under WorldPlan.PLATEAU_FROM), rock by rule.
func _nearest_tower(from: Vector3) -> Array:
	var h0 := _terrain.height_at(from)
	if _terrain.plan != null:
		return _nearest(from, func(d: Vector3) -> bool:
			var z := _plateau_at(d)
			return z > 0.0 and z < WorldPlan.PLATEAU_FROM 				and _terrain.ground_at(d, 0.0) == &"rock" and _terrain.height_at(d) - h0 > TOWER_TALL,
			TOWER_STEP, TOWER_REACH)
	return _nearest(from, func(d: Vector3) -> bool:
		var z := _terrain.continent_at(d)
		return z >= WorldTerrain.MESA_FROM - WorldTerrain.TOWER_BAND and z < WorldTerrain.MESA_FROM \
			and _terrain.ground_at(d, 0.0) == &"rock" and _terrain.height_at(d) - h0 > TOWER_TALL,
		TOWER_STEP, TOWER_REACH)

## A planned desert's spot: open dunes with a tower within TOWER_REACH and a
## mesa within MESA_REACH, found from the plan's own cells. Every cell of the
## plan's map whose plateau weight (S_PLATEAU) is in its edge band, with the
## sun EDGE_SUN_MIN to EDGE_SUN_MAX deg up there, is a tower's possible home;
## rings of EDGE_RINGS round it are looked at for open dunes, and the best
## (the sun nearest SUN_DEG, then the nearest tower and mesa) is taken. ZERO
## if none.
func _plateau_edge_spot() -> Vector3:
	var p := _terrain.plan
	var f := PackedFloat64Array()
	f.resize(WorldPlan.S_SIZE)
	var cells: Array[Vector3] = []
	for index in CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS:
		var key := PlanShapes.cell_key(index)
		var rr := CubeSphere.node_rect(key)
		var mid := CubeSphere.direction(key.x, rr.x + 0.5 * rr.z, rr.y + 0.5 * rr.z)
		var up := 90.0 - rad_to_deg(mid.angle_to(_to_star()))
		if up < EDGE_SUN_MIN or up > EDGE_SUN_MAX:
			continue
		p.sample(mid, f)
		if f[WorldPlan.S_PLATEAU] > 0.1 and f[WorldPlan.S_PLATEAU] < WorldPlan.PLATEAU_FROM and f[WorldPlan.S_KEEP] <= 0.0 				and f[WorldPlan.S_CANYON] == INF:
			cells.append(mid)
	cells.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return absf(90.0 - rad_to_deg(a.angle_to(_to_star())) - SUN_DEG) < absf(90.0 - rad_to_deg(b.angle_to(_to_star())) - SUN_DEG))
	var best := Vector3.ZERO
	var best_score := INF
	var tried := 0
	for mid in cells:
		var ab := _tangents(mid)
		for ring: float in EDGE_RINGS:
			for k in 12:
				var d := _off(mid, ab[0] * cos(k * TAU / 12.0) + ab[1] * sin(k * TAU / 12.0), ring)
				if not _open_dunes(d) or _dune_range(d) < DUNE_SPOT_RANGE:
					continue
				var tower := _nearest_tower(d)
				if float(tower[1]) == INF:
					continue
				var mesa := _nearest_mesa(d)
				if float(mesa[1]) == INF:
					continue
				# The landing is on the flattest dune near, so the tower and mesa
				# must be in reach of that spot.
				var land := _flattest_dune(d)
				tower = _nearest_tower(land)
				mesa = _nearest_mesa(land)
				if float(tower[1]) == INF or float(mesa[1]) == INF:
					continue
				var score := float(tower[1]) + 0.5 * float(mesa[1])
				if score < best_score:
					best_score = score
					best = land
		tried += 1
		if best != Vector3.ZERO and tried >= EDGE_CELLS:
			break
	print("        plateau edge cells in daylight: %d, %d looked at" % [cells.size(), tried])
	return best

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

# --- the cover set -----------------------------------------------------------------

## Points on the sphere binned on the tangent plane at a centre, each with how
## far it reaches (a stone's farthest point; 0 for a tuft): how many come
## within some metres of a direction, and how near the nearest comes.
class Bins:
	extends RefCounted
	var a: Vector3
	var b: Vector3
	var radius: float
	var cell: float
	var cells := {}
	var size := 0

	func _init(centre: Vector3, p_radius: float, p_cell: float) -> void:
		var d := centre.normalized()
		a = d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
		b = d.cross(a)
		radius = p_radius
		cell = p_cell

	func flat(d: Vector3) -> Vector2:
		return Vector2(d.dot(a), d.dot(b)) * radius

	## `items` as _scattered gives them: [direction, reach, ...].
	func add_all(items: Array) -> void:
		for it: Array in items:
			var p := flat(it[0])
			var k := Vector2i(floori(p.x / cell), floori(p.y / cell))
			if not cells.has(k):
				cells[k] = []
			(cells[k] as Array).append(Vector3(p.x, p.y, float(it[1])))
			size += 1

	## [how many reach within `r` m of `d`, how near the nearest reaches, m].
	func near(d: Vector3, r: float) -> Array:
		var p := flat(d)
		var n := ceili((r + 4.0) / cell)
		var kx := floori(p.x / cell)
		var ky := floori(p.y / cell)
		var count := 0
		var gap := INF
		for i in range(-n, n + 1):
			for j in range(-n, n + 1):
				var list: Variant = cells.get(Vector2i(kx + i, ky + j))
				if list == null:
					continue
				for q: Vector3 in list:
					var g := Vector2(q.x, q.y).distance_to(p) - q.z
					gap = minf(gap, g)
					if g < r:
						count += 1
		return [count, gap]

func _cover_set() -> void:
	print("cover   the boulders, the grass and the blowing sand")
	await _aboard()
	await _among_grass()
	await _before_the_mesa_and_tower()
	await _aboard()
	_talus_spot = _densest_talus()
	await _cover_low()
	await _boulder_landings()

## What GroundCover scatters within `reach` m of `centre` (every finest chunk
## that might hold some), as the collision has it: [stones, tufts], a stone
## [direction, its farthest point from its middle, m, diameter], a tuft
## [direction, 0].
func _scattered(centre: Vector3, reach: float) -> Array:
	var d := centre.normalized()
	var ab := _tangents(d)
	var depth := CubeSphere.depth_for(_planet.radius)
	var edge := CubeSphere.edge_m(_planet.radius, depth)
	var steps := ceili(reach / (edge * 0.5))
	var keys := {}
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			if i * i + j * j > (steps + 1) * (steps + 1):
				continue
			var o := (ab[0] * i + ab[1] * j) * (reach / steps / _planet.radius)
			keys[CubeSphere.key_for((d + o).normalized(), depth)] = true
	var stones := []
	var tufts := []
	for key: Vector4i in keys:
		var c := Vector3(TerrainChunkData.centre_of(_terrain, key))
		var cover := GroundCover.scatter(_terrain, key)
		for stone: Array in cover.boulders:
			var place: Transform3D = stone[0]
			var extent := 0.0
			for p in RockMesh.cut_vertices(stone[1], 0):
				extent = maxf(extent, (place.basis * p).length())
			stones.append([(c + place.origin).normalized(), extent, float(stone[3])])
		for tuft: Array in cover.grass:
			tufts.append([(c + (tuft[0] as Transform3D).origin).normalized(), 0.0])
	return [stones, tufts]

## Directions on a grid `step` m apart within `reach` m of `centre`.
func _grid_round(centre: Vector3, reach: float, step: float) -> Array[Vector3]:
	var ab := _tangents(centre)
	var n := int(reach / step)
	var out: Array[Vector3] = []
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			if i * i + j * j <= n * n:
				out.append((centre + (ab[0] * i + ab[1] * j) * (step / _planet.radius)).normalized())
	return out

## `dirs` ordered by `score` (callable: direction -> float), highest first.
static func _by_score(dirs: Array[Vector3], score: Callable) -> Array[Vector3]:
	var order: Array[Vector2] = []
	for i in dirs.size():
		order.append(Vector2(-float(score.call(dirs[i])), i))
	order.sort()
	var out: Array[Vector3] = []
	for o in order:
		out.append(dirs[int(o.y)])
	return out

## The way along the ground at `from` toward `to`.
func _way_to(from: Vector3, to: Vector3) -> Vector3:
	var v := to - from
	return (v - from * v.dot(from)).normalized()

## `d`, or the nearest ground within 20 m (rings 2 m apart) no stone reaches
## within STONE_CLEAR m of: somewhere to stand.
func _off_the_stones(d: Vector3) -> Vector3:
	var bins := Bins.new(d, _planet.radius, 4.0)
	bins.add_all(_scattered(d, 30.0)[0])
	if float(bins.near(d, STONE_CLEAR)[1]) >= STONE_CLEAR:
		return d
	var ab := _tangents(d)
	for ring in range(1, 11):
		for k in 12:
			var o := (ab[0] * cos(k * TAU / 12.0) + ab[1] * sin(k * TAU / 12.0)) * (ring * 2.0 / _planet.radius)
			var e := (d + o).normalized()
			if float(bins.near(e, STONE_CLEAR)[1]) >= STONE_CLEAR:
				return e
	return d

## You, stood on the ground at `dir` far from where you are, facing `way`:
## the ground round it built first (and its stones solid), then stood again.
func _stand_far(dir: Vector3, way: Vector3) -> void:
	var up := dir.normalized()
	_avatar.place(Transform3D(_level(up, way), _centre() + up * (_ground_r(up) + 0.1)))
	_moved()
	await _ground_built()
	await _stand_at(dir, way)

## Landed among grass, the nose toward the most of it: seated, and the frame
## rate over COVER_SECONDS; out on foot in the grassiest ground near, toward
## the sun and away, with the sand blowing and hidden, and the frame rate.
func _among_grass() -> void:
	var t0 := Time.get_ticks_msec()
	var found := _scattered(_spot, COVER_SEARCH + GRASS_SEEN + GRASS_STAND)
	var stones := Bins.new(_spot, _planet.radius, 10.0)
	stones.add_all(found[0])
	var tufts := Bins.new(_spot, _planet.radius, 10.0)
	tufts.add_all(found[1])
	var cands := _by_score(_grid_round(_spot, COVER_SEARCH, COVER_STEP),
		func(d: Vector3) -> float: return float(tufts.near(d, GRASS_SEEN)[0]))
	_grass_spot = Vector3.ZERO
	for d in cands:
		if float(stones.near(d, HULL_CLEAR)[1]) < HULL_CLEAR or _spread(d, LAND_REACH) > GRASS_LAND_SPREAD:
			continue
		_grass_spot = d
		break
	if _grass_spot == Vector3.ZERO:
		_check(false, "cover a spot among grass within %.0f m with no stone within %.0f m and the ground within %.1f m" % [
			COVER_SEARCH, HULL_CLEAR, GRASS_LAND_SPREAD])
		return
	# The nose toward the tufts within GRASS_SEEN m of it.
	var pull := Vector3.ZERO
	for d in _grid_round(_grass_spot, GRASS_SEEN, 5.0):
		pull += (d - _grass_spot) * float(tufts.near(d, 3.0)[0])
	var nose := _way_to(_grass_spot, _grass_spot + pull) if pull.length() > 1e-9 else _across
	print("        among grass: %d tufts and %d stones within %.0f m of the spot; landing %.0f m from it with %d tufts within %.0f m, the nearest stone %.1f m off, the ground within %.0f m rising or falling %.2f m; the nose %.0f deg round from the sun's way (%d ms)" % [
		tufts.size, stones.size, COVER_SEARCH + GRASS_SEEN + GRASS_STAND, _spot.angle_to(_grass_spot) * _planet.radius,
		int(tufts.near(_grass_spot, GRASS_SEEN)[0]), GRASS_SEEN, float(stones.near(_grass_spot, 100.0)[1]), LAND_REACH,
		_spread(_grass_spot, LAND_REACH), _bearing(nose), Time.get_ticks_msec() - t0])
	if not await _land_here(_grass_spot, nose, "cover"):
		return
	await _seconds(1.0)
	await _shot("cover_seated")
	await _reading_for("seated at the starter's helm landed among grass, the sand blowing", COVER_SECONDS)
	_director.stand_now()
	await _frames(3)
	var lock: Airlock = _starter.airlocks.values()[0]
	if not await _out_through(lock, "", "cover"):
		return
	# The grassiest ground near the ship, off the hull and clear of stones,
	# across the sun's way from it: the ship in neither view.
	var hull := _up(_starter.exterior.global_position)
	var sun_at := _sun_way(hull)
	var near: Array[Vector3] = []
	for d in _grid_round(hull, GRASS_STAND, 4.0):
		if d.angle_to(hull) * _planet.radius >= GRASS_OFF and absf(_way_to(hull, d).dot(sun_at)) < 0.5:
			near.append(d)
	var stand := hull
	for d in _by_score(near, func(e: Vector3) -> float: return float(tufts.near(e, GRASS_NEAR)[0])):
		if float(stones.near(d, STONE_CLEAR)[1]) >= STONE_CLEAR:
			stand = d
			break
	var sun_way := _flat(_sun_dir())
	await _stand_at(stand, -sun_way)
	var eye := _gravity.altitude_at(_avatar.camera.global_position)
	print("        on foot among grass, across the sun's way from the hull, %.0f m from its middle: %d tufts within %.0f m, %d within %.0f m, eye %.2f m over the ground; the sand %s, %d of %d streaks (amount_ratio %.2f)" % [
		stand.angle_to(hull) * _planet.radius, int(tufts.near(stand, GRASS_NEAR)[0]), GRASS_NEAR,
		int(tufts.near(stand, 20.0)[0]), 20.0, eye, "blowing" if _stars.sand.emitting else "still",
		roundi(_stars.sand.amount * _stars.sand.amount_ratio), _stars.sand.amount, _stars.sand.amount_ratio])
	_check(absf(eye - EYE) < 0.15, "cover the eye %.2f m over the ground on foot among grass (%.1f within 0.15)" % [eye, EYE])
	_check(_stars.sand.emitting and _stars.sand.amount_ratio > 0.9,
		"cover on foot on the desert the sand blows (amount_ratio %.2f)" % _stars.sand.amount_ratio)
	await _foot_view("cover_sand_sun", sun_way, SUN_PITCH)
	await _foot_view("cover_sand_away", -sun_way, 0.0)
	await _reading_for("on foot among grass, away from the sun, the sand blowing", FPS_SECONDS)
	var sand := _stars.sand
	sand.visible = false
	await _foot_view("cover_still_sun", sun_way, SUN_PITCH)
	await _foot_view("cover_still", -sun_way, 0.0)
	await _reading_for("on foot among grass, away from the sun, the sand hidden by hand", FPS_SECONDS)
	sand.visible = true

## On foot at the nearest mesa's foot among its boulders (cover_talus), and
## before the nearest tower (cover_tower).
func _before_the_mesa_and_tower() -> void:
	await _foot_near("cover_talus", _mesa, true)
	await _foot_near("cover_tower", _tower, false)

## On foot before `near`'s foot (from _nearest: [direction, m]), FOOT_BACK m
## back toward the spot (with `talus`, on in_talus ground, up to
## TALUS_BACK_MOST), off any stone, facing it, the head pitched up half the way
## to its highest ground within 60 m past its foot (at most FOOT_PITCH_MOST).
func _foot_near(shot_name: String, near: Array, talus: bool) -> void:
	if float(near[1]) == INF:
		_check(false, "%s: none within reach of the spot" % shot_name)
		return
	var foot: Vector3 = near[0]
	var back := _way_to(foot, _spot)
	var m := FOOT_BACK
	var d := _off(foot, back, m)
	while talus and not _terrain.in_talus(d) and m < TALUS_BACK_MOST:
		m += 5.0
		d = _off(foot, back, m)
	d = _off_the_stones(d)
	await _stand_far(d, -back)
	var top := foot
	for k in 13:
		var e := _off(foot, -back, k * 5.0)
		if _terrain.height_at(e) > _terrain.height_at(top):
			top = e
	var eye := _avatar.camera.global_position
	var to := _centre() + top * (_planet.radius + _terrain.height_at(top)) - eye
	_face(to)
	var pitch := clampf(atan2(to.dot(_avatar.up) * 0.5, _flat(to).length()), 0.0, deg_to_rad(FOOT_PITCH_MOST))
	_avatar.set_head_pitch(pitch)
	var here := _up(_avatar.global_position)
	var bins := Bins.new(here, _planet.radius, 10.0)
	bins.add_all(_scattered(here, 40.0)[0])
	print("        %s: %.0f m from its foot (%s), its top %.0f m over your eye, %.0f m off; %d stones within 15 m, %d within 30 m, the nearest %.1f m off; pitched %.0f deg; eye %.2f m over the ground" % [
		shot_name, m, "talus" if _terrain.in_talus(here) else "not talus", to.dot(_avatar.up), _flat(to).length(),
		int(bins.near(here, 15.0)[0]), int(bins.near(here, 30.0)[0]), float(bins.near(here, 100.0)[1]), rad_to_deg(pitch),
		_gravity.altitude_at(_avatar.camera.global_position)])
	await _seconds(0.5)
	await _shot(shot_name)

## The densest talus spot within TALUS_REACH of the nearest talus to the spot
## (stones reaching within TALUS_NEAR m), on ground no steeper than
## TALUS_TILT; ZERO if there is no talus near.
func _densest_talus() -> Vector3:
	var t0 := Time.get_ticks_msec()
	var near := _nearest(_spot, func(d: Vector3) -> bool: return _terrain.in_talus(d), TALUS_STEP, TALUS_SEARCH)
	if float(near[1]) == INF:
		_check(false, "cover talus within %.0f m of the spot" % TALUS_SEARCH)
		return Vector3.ZERO
	var anchor: Vector3 = near[0]
	var stones := Bins.new(anchor, _planet.radius, TALUS_NEAR)
	stones.add_all(_scattered(anchor, TALUS_REACH + TALUS_NEAR + 4.0)[0])
	var cands := _by_score(_grid_round(anchor, TALUS_REACH, TALUS_STEP),
		func(d: Vector3) -> float: return float(stones.near(d, TALUS_NEAR)[0]))
	var best := Vector3.ZERO
	var looked := 0
	for d in cands:
		looked += 1
		if not _terrain.in_talus(d) or rad_to_deg(atan(_spread(d, LAND_REACH) / LAND_REACH)) > TALUS_TILT:
			continue
		best = d
		break
	if best == Vector3.ZERO:
		_check(false, "cover a talus spot within %.0f m of the nearest talus no steeper than %.0f deg" % [TALUS_REACH, TALUS_TILT])
		return Vector3.ZERO
	var most := 0
	for d in cands:
		most = maxi(most, int(stones.near(d, TALUS_NEAR)[0]))
	print("        talus: the nearest %.0f m from the spot; %d stones within %.0f m of it; the densest spot no steeper than %.0f deg (%d looked at) %.0f m from it with %d stones within %.0f m (the most anywhere %d), the nearest's edge %.1f m off, the ground within %.0f m rising or falling %.2f m (%.1f deg), the sun %.0f deg up (%d ms)" % [
		float(near[1]), stones.size, TALUS_REACH + TALUS_NEAR + 4.0, TALUS_TILT, looked, anchor.angle_to(best) * _planet.radius,
		int(stones.near(best, TALUS_NEAR)[0]), TALUS_NEAR, most, float(stones.near(best, 100.0)[1]), LAND_REACH,
		_spread(best, LAND_REACH), rad_to_deg(atan(_spread(best, LAND_REACH) / LAND_REACH)),
		90.0 - rad_to_deg(best.angle_to(_to_star())), Time.get_ticks_msec() - t0])
	return best

## Seated, COVER_LOW over a talus band at 120 m/s and then at the speed limit
## there, COVER_SECONDS each: the frame rate, and CoverField keeping ahead.
func _cover_low() -> void:
	if _talus_spot == Vector3.ZERO:
		return
	await _hold_at(_talus_spot, COVER_LOW, _across)
	await _seconds(1.0)
	var limit := _starter.flight_computer.speed_limit_now()
	var length := maxf(limit, FAST_LEAST) * (COVER_SECONDS + 2.0) + 100.0
	# The bearing from the densest talus with the most talus along the way.
	var ab := _tangents(_talus_spot)
	var way := ab[0]
	var share := -1.0
	for k in 16:
		var w: Vector3 = ab[0] * cos(k * TAU / 16.0) + ab[1] * sin(k * TAU / 16.0)
		var s := _off(_talus_spot, -w, 100.0)
		var on := 0
		var n := 0
		var m := 0.0
		while m <= length:
			n += 1
			if _terrain.in_talus(_off(s, w, m)):
				on += 1
			m += 20.0
		if float(on) / n > share:
			share = float(on) / n
			way = w
	var start := _off(_talus_spot, -way, 100.0)
	var axis := start.cross(way).normalized()
	# The ground along it every 10 m, and the highest within LOW_WINDOW.
	var ground := PackedFloat32Array()
	var along := 0.0
	while along <= length + LOW_WINDOW:
		ground.append(_terrain.height_at(start.rotated(axis, along / _planet.radius)))
		along += 10.0
	var win := int(LOW_WINDOW / 10.0)
	var profile := PackedFloat32Array()
	var lo := INF
	var hi := -INF
	for i in ground.size():
		var top := -INF
		for j in range(maxi(i - win, 0), mini(i + win, ground.size() - 1) + 1):
			top = maxf(top, ground[j])
		profile.append(top)
		lo = minf(lo, ground[i])
		hi = maxf(hi, ground[i])
	print("low     over the talus: %.0f%% of %.0f m along the route from the densest talus is talus; the ground %.1f to %.1f m over the radius; the speed limit %.0f m above it is %.0f m/s" % [
		share * 100.0, length, lo, hi, COVER_LOW, limit])
	await _fly_low(LOW_SPEED, start, axis, profile, "cover_low")
	# The limit this low is about LOW_SPEED: CoverField is tried at FAST_LEAST
	# at least, to see it keep ahead.
	await _fly_low(maxf(limit, FAST_LEAST), start, axis, profile, "cover_low_fast")
	# The same 120 m/s with the hull truly moving: carried, the hull's
	# velocity is 0 and TerrainCollider asks for 64 m round it; flown, for
	# 64 m round its way over the next second (Task 7b fix rounds 1, 2).
	await _fly_low(LOW_SPEED, start, axis, profile, "cover_low_moving", true)

## Flown from `start` round `axis` at `speed` for COVER_SECONDS, COVER_LOW over
## `profile` (the ground's height every 10 m), level: the frame rate, each
## second the blocks wanted ahead and not drawn and the blocks that appeared
## within POP_NEAR ahead; rendered at the end as `shot_name`.
## With `moving`, the hull is not carried but flown: thawed, the assist off
## (no thrust), its velocity set each tick to reach the next point on the
## route, so the physics moves it and everything that asks its speed (the
## solid ground's reach) sees 120 m/s.
func _fly_low(speed: float, start: Vector3, axis: Vector3, profile: PackedFloat32Array, shot_name: String,
		moving := false) -> void:
	var cover := _surface.cover
	var h0 := profile[0] - _terrain.height_at(start) + COVER_LOW
	await _hold_at(start, h0, axis.cross(start))
	await _seconds(1.0)
	var flown := [0.0, INF, -INF, 0.0, 0]
	var hull := _starter.exterior
	var assist := _starter.flight_computer.assist_enabled
	var point_at := func(at: float) -> Vector3:
		var dir := start.rotated(axis, at / _planet.radius)
		var i := mini(int(at / 10.0), profile.size() - 2)
		var t := clampf(at / 10.0 - i, 0.0, 1.0)
		var r := _planet.radius + lerpf(profile[i], profile[i + 1], t) + _starter.stance_depth() + COVER_LOW
		return _centre() + dir * r
	if moving:
		_starter.flight_computer.assist_enabled = false
		hull.freeze = false
	var fly := func() -> void:
		var dt := 1.0 / Engine.physics_ticks_per_second
		flown[0] = float(flown[0]) + speed * dt
		var at := float(flown[0])
		if moving:
			# The hull is where the physics put it; aimed at the route's next point.
			hull.linear_velocity = (point_at.call(at) - hull.global_position) / dt
			hull.angular_velocity = Vector3.ZERO
			flown[3] = maxf(float(flown[3]), hull.linear_velocity.length() * TerrainCollider.LOOKAHEAD)
			flown[4] = maxi(int(flown[4]), _surface.solid_keys().size())
		else:
			var dir := start.rotated(axis, at / _planet.radius)
			_starter.exterior.global_transform = Transform3D(_level(dir, axis.cross(dir)), point_at.call(at))
		var over := _alt(_starter)
		flown[1] = minf(float(flown[1]), over)
		flown[2] = maxf(float(flown[2]), over)
	# The blocks drawn last frame; pops [this second, frames with any, all,
	# the nearest's gap].
	var memo := {}
	var drawn := {}
	for k in cover.block_keys():
		drawn[k] = true
	var pops := [0, 0, 0, INF]
	var watch := func() -> void:
		var here := _up(_starter.exterior.global_position)
		var nose := axis.cross(here).normalized()
		var now := {}
		var popped := 0
		for k in cover.block_keys():
			now[k] = true
			if drawn.has(k):
				continue
			var g := _block_gap(k, here, nose, memo)
			if bool(g[1]) and float(g[0]) < POP_NEAR:
				popped += 1
				pops[3] = minf(float(pops[3]), float(g[0]))
		drawn.clear()
		drawn.merge(now)
		if popped > 0:
			pops[0] = int(pops[0]) + popped
			pops[1] = int(pops[1]) + 1
			pops[2] = int(pops[2]) + popped
	physics_frame.connect(fly)
	process_frame.connect(watch)
	var shifts := _universe.shifts
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var frames := 0
	var gpu := 0.0
	var cpu := 0.0
	var worst_ms := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	var second := 1
	var lines: Array[String] = []
	var most_missing := 0
	while Time.get_ticks_usec() - t0 < int(COVER_SECONDS * 1e6):
		await process_frame
		var tick := Time.get_ticks_usec()
		frames += 1
		worst_ms = maxf(worst_ms, (tick - last) / 1000.0)
		last = tick
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		if tick - t0 >= second * 1000000:
			var under := _up(_starter.exterior.global_position)
			var ahead := axis.cross(under).normalized()
			var missing := 0
			var nearest := INF
			for k: Vector4i in cover._wanted:
				if cover._blocks.has(k):
					continue
				var g := _block_gap(k, under, ahead, memo)
				if bool(g[1]):
					missing += 1
					nearest = minf(nearest, float(g[0]))
			most_missing = maxi(most_missing, missing)
			lines.append("        %s %d s: %.0f m flown, %.1f m over the ground; %d blocks drawn of %d wanted, %d wanted ahead not drawn%s, %d building; %d blocks appeared within %.0f m ahead this second" % [
				shot_name, second, float(flown[0]), _alt(_starter), cover.block_count(), cover._wanted.size(), missing,
				" (the nearest %.0f m off)" % nearest if missing > 0 else "", cover.jobs_in_flight(), int(pops[0]), POP_NEAR])
			pops[0] = 0
			second += 1
	RenderingServer.viewport_set_measure_render_time(vp, false)
	var fps := frames / COVER_SECONDS
	_gpu_ms = gpu / maxf(frames, 1.0)
	_cpu_ms = cpu / maxf(frames, 1.0)
	process_frame.disconnect(watch)
	for l in lines:
		print(l)
	var how := "the hull flown (moving at %.0f m/s, solid ground %.0f m round a way of %.0f m ahead, at most %d solid chunks)" % [
		hull.linear_velocity.length(), TerrainCollider.REACH, float(flown[3]), int(flown[4])] if moving else "the hull carried (frozen)"
	var line := "fps     %.0f seated in low flight at %.0f m/s over a talus band for %.0f s, %s (%.0f m flown, %.0f to %.0f m over the ground under the keel, the longest frame %.1f ms, the origin shifted %d times; %d frames saw a block appear within %.0f m ahead, %d blocks in all, the nearest %s; at most %d wanted ahead not drawn) %s" % [
		fps, speed, COVER_SECONDS, how, float(flown[0]), float(flown[1]), float(flown[2]), worst_ms, _universe.shifts - shifts,
		int(pops[1]), POP_NEAR, int(pops[2]), "%.0f m off" % float(pops[3]) if float(pops[3]) < INF else "none",
		most_missing, _ms()]
	print(line)
	_readings.append(line)
	_check(fps >= FPS_FLOOR, "fps %.0f seated in low flight at %.0f m/s, %.0f m over a talus band (at least %.0f)" % [
		fps, speed, COVER_LOW, FPS_FLOOR])
	_check(int(pops[1]) == 0, "%s no block of boulders appeared within %.0f m ahead (%d frames saw one)" % [
		shot_name, POP_NEAR, int(pops[1])])
	await _shot(shot_name)
	physics_frame.disconnect(fly)
	if moving:
		hull.linear_velocity = Vector3.ZERO
		hull.angular_velocity = Vector3.ZERO
		hull.freeze = true
		_starter.flight_computer.assist_enabled = assist

## Block `key`'s nearest ground from `here` (a direction), m along the ground
## (0 if it is under you), and whether it lies ahead along `nose`: [m, ahead].
func _block_gap(key: Vector4i, here: Vector3, nose: Vector3, memo: Dictionary) -> Array:
	var b: Variant = memo.get(key)
	if b == null:
		b = CoverField._bound(key, _planet.radius)
		memo[key] = b
	var middle: Vector3 = b[0]
	var at := here * _planet.radius
	var gap := maxf(at.distance_to(middle) - float(b[1]), 0.0)
	return [gap, gap == 0.0 or (middle - at).dot(nose) > 0.0]

## The starter and the heaviest library ship each brought down at SINK m/s
## onto the densest talus spot; the starter's frame rate on foot 6 m off.
func _boulder_landings() -> void:
	if _talus_spot == Vector3.ZERO:
		return
	print("boulder the starter onto the densest talus")
	await _unland()
	_starter.exterior.freeze = false
	_starter.flight_computer.assist_enabled = true
	_place(_starter, _talus_spot, BOULDER_DROP, _across)
	await _ground_built()
	var landed := await _set_down(_starter, true, "the starter")
	var way := await _boulder_shot("cover_starter_boulders_a", _starter, Vector3(17.0, 0.0, 18.0))
	await _boulder_shot("cover_starter_boulders_b", _starter, Vector3(-17.0, 0.0, -18.0))
	await _stone_shadows()
	if landed:
		_director.stand_now()
		await _frames(3)
		var lock: Airlock = _starter.airlocks.values()[0]
		if await _out_through(lock, "", "boulder"):
			_face(_starter.exterior.global_position - _avatar.global_position)
			_avatar.set_head_pitch(0.0)
			await _seconds(0.5)
			await _shot("cover_boulder_foot")
			await _reading_for("on foot %.1f m off the hatch of the starter landed among boulders, facing it" % [
				_flat(_avatar.global_position - lock.beacon()).length()], FPS_SECONDS)
		await _aboard()
	else:
		print("        no frame rate on foot by the starter: it did not land, so its airlock will not open")
	await _warden_landing(way)

## The stones round the landed starter from its sunward side, the sun at
## the camera's back so every stone's shadow falls away in view, 5 m up:
## once as drawn, once with the stones' distance fade off. The shadow pass
## measures the fade from the light, so a stone's shadow inside the reach
## could be dithered or lost; the two renders side by side say whether.
func _stone_shadows() -> void:
	var flat := _sunward(_starter) * 35.0
	var target := Vector3(0.0, -_starter.stance_depth(), 0.0)
	await _ground_shot("cover_shadows", _starter, flat, 5.0, target)
	var looks: Array[StandardMaterial3D] = []
	for tier in 2:
		var look := CoverField.boulder_material(tier)
		if not look in looks:
			looks.append(look)
	var modes: Array = []
	for look in looks:
		modes.append(look.distance_fade_mode)
		look.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	await _ground_shot("cover_shadows_unfaded", _starter, flat, 5.0, target)
	for i in looks.size():
		looks[i].distance_fade_mode = modes[i]
	var a: Image = _images["cover_shadows"]
	var b: Image = _images["cover_shadows_unfaded"]
	var differ := 0
	var dark_a := 0
	var dark_b := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.get_luminance() - cb.get_luminance()) > 0.04:
				differ += 1
			if ca.get_luminance() < 0.25:
				dark_a += 1
			if cb.get_luminance() < 0.25:
				dark_b += 1
	print("shadows the stones from 35 m sunward, 5 m up: %d sampled pixels differ with the fade off; dark pixels %d faded, %d unfaded" % [
		differ, dark_a, dark_b])

## The heaviest library ship, spawned and brought down at SINK m/s onto the
## densest talus spot, unseated (its own flight computer's input), the
## starter hovering out of the shot (WATCH_BACK behind the camera's spot along
## `way`, WATCH_HIGH up); rendered as the starter was, and let go.
func _warden_landing(way: Vector3) -> void:
	var library: ShipLibrary = _scene.get("library")
	var heaviest := &""
	var mass := 0.0
	for id in library.ids():
		var m := ShipStats.compute(library.grid(id), _starter.catalog).total_mass_kg
		if m > mass:
			mass = m
			heaviest = id
	print("boulder %s (%s, %.0f t, the heaviest library ship) onto the densest talus" % [library.name_of(heaviest), heaviest, mass / 1000.0])
	var watch_at := _off(_talus_spot, way, BOULDER_VIEW + VIEW_OFF + WATCH_BACK)
	await _hold_at(watch_at, WATCH_HIGH, -way)
	var grid := library.grid(heaviest)
	var big := _fleet.spawn(grid, Transform3D(Basis.IDENTITY, _centre() + _talus_spot * (_ground_r(_talus_spot) + 600.0)),
		true, "", ShipBlueprint.from_grid(grid, library.name_of(heaviest)))
	if big == null:
		_check(false, "boulder the heaviest library ship (%s) spawns" % heaviest)
		return
	big.flight_computer.assist_enabled = true
	_place(big, _talus_spot, BOULDER_DROP, _across)
	await _ground_built()
	await _set_down(big, false, library.name_of(heaviest))
	# From the same side as the starter's first: the starter is behind you.
	var hull := big.exterior.global_transform
	var side := hull.basis.inverse() * way
	side.y = 0.0
	await _boulder_shot("cover_warden_boulders", big, side.normalized())
	_fleet.remove(big, true)
	await _frames(2)

## `ship` from SINK m/s down until it touches and settles or not: the
## monitor's word, its tilt or refusal, any hard landing, the damage (none),
## its feet, and any stone inside a hull cell. `seated` flies it by the stick,
## else by its flight computer's input. True if LANDED.
func _set_down(ship: Ship, seated: bool, who: String) -> bool:
	var landing := ship.landing
	var hard: Array[float] = []
	var on_hard := func(speed: float) -> void: hard.append(speed)
	landing.hard_landing.connect(on_hard)
	var damage := _block_damage(ship)
	var whole := ship.hull_whole()
	var legs := ship.exterior_builder.legs()
	var legs_down := await _until(func() -> bool: return legs == null or legs.is_down(), 6.0)
	var start := _alt(ship)
	var sinks: Array[float] = []
	var end := Time.get_ticks_msec() + 30000
	while landing.state == LandingMonitor.State.FLYING and Time.get_ticks_msec() < end:
		_sink_by(ship, seated, SINK)
		if _alt(ship) < 3.0:
			sinks.append(_sink(ship))
		await physics_frame
	var touch := sinks[-1] if not sinks.is_empty() else _sink(ship)
	_sink_by(ship, seated, NAN)
	var landed := await _until(func() -> bool: return landing.is_landed(), 10.0)
	await _seconds(0.5)
	await _frames(5)
	var damage_after := _block_damage(ship)
	landing.hard_landing.disconnect(on_hard)
	var mean := 0.0
	for s in sinks:
		mean += s / maxf(sinks.size(), 1.0)
	var feet: Array[String] = []
	if legs != null:
		for foot in legs.feet():
			feet.append("%.2f" % _gravity.altitude_at(foot))
	var clip := _stones_in_hull(ship)
	print("        %s: legs %s; from %.1f m, down at %.2f m/s over the last 3 m (%.2f at the touch): %s, tilt %.1f deg; the monitor %s; feet %s m over the ground; %s" % [
		who, "down" if legs_down else "NOT down", start, mean, touch,
		"LANDED" if landed else "NOT landed (%s)" % LandingMonitor.State.keys()[landing.state],
		rad_to_deg(landing.tilt()), "says nothing" if landing.refusal() == "" else "refuses: '%s'" % landing.refusal(),
		", ".join(feet), clip[1]])
	_check(hard.is_empty(), "boulder %s: no hard landing (%s)" % [who, "none said" if hard.is_empty() else "said at %s m/s" % str(hard)])
	_check(damage_after == damage and ship.hull_whole() == whole,
		"boulder %s: the blocks' damage %.1f hp before and %.1f after (none taken); HULL %.0f%% and %.0f%%" % [
		who, damage, damage_after, whole * 100.0, ship.hull_whole() * 100.0])
	_check(int(clip[0]) == 0, "boulder %s: no stone's corner inside the hull's colliders (%d)" % [who, int(clip[0])])
	if seated:
		_check_stick(ship, "boulder")
	return landed

## `ship`'s vertical input so it sinks at `rate` m/s (NAN: hands off), by the
## stick when `seated`, else by its flight computer's pilot input.
func _sink_by(ship: Ship, seated: bool, rate: float) -> void:
	if seated:
		if is_nan(rate):
			_stick_y(0.0)
		else:
			_hold_sink(ship, rate)
		return
	var s := 0.0
	if not is_nan(rate):
		s = clampf((_sink(ship) - rate) * 0.5, -1.0, 1.0)
		if absf(s) < 0.02:
			s = 0.02 if _sink(ship) > rate else -0.02
	ship.flight_computer.set_pilot_input(Vector3(0.0, s, 0.0), Vector3.ZERO, false)

## The stones round `ship` (as the collision has them, detail 0) with a
## corner inside one of its occupied cells' boxes, and of those corners how
## many lie inside the hull's own colliders (a box is a whole cell, so a part
## block's empty half counts in the first): [corners in its colliders, a line
## saying so].
func _stones_in_hull(ship: Ship) -> Array:
	var hull := ship.exterior.global_transform
	var inv := hull.affine_inverse()
	var here := _up(hull.origin)
	var reach := _reach(ship, Vector3.ZERO, Vector3.FORWARD)
	for d: Vector3 in [Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		reach = maxf(reach, _reach(ship, Vector3.ZERO, d))
	var depth := CubeSphere.depth_for(_planet.radius)
	var edge := CubeSphere.edge_m(_planet.radius, depth)
	var ab := _tangents(here)
	var span := reach + 6.0
	var steps := ceili(span / (edge * 0.5))
	var keys := {}
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			keys[CubeSphere.key_for((here + (ab[0] * i + ab[1] * j) * (span / steps / _planet.radius)).normalized(), depth)] = true
	var corners := 0
	var stones := 0
	var near := 0
	var deepest := 0.0
	var which := ""
	# A corner in a cell's box may be in a part-block's empty half: the hull's
	# own colliders are asked too.
	var solid := 0
	var space := ship.exterior.get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = ship.exterior.collision_layer
	query.collide_with_areas = false
	for key: Vector4i in keys:
		var c := _centre() + Vector3(TerrainChunkData.centre_of(_terrain, key))
		for stone: Array in GroundCover.scatter(_terrain, key).boulders:
			var place: Transform3D = stone[0]
			if (inv * (c + place.origin)).length() > span:
				continue
			near += 1
			var inside := 0
			for v in RockMesh.cut_vertices(stone[1], 0):
				var p := inv * (c + place * v)
				var cell := Vector3i(roundi(p.x / ShipGrid.CELL_SIZE), roundi(p.y / ShipGrid.CELL_SIZE), roundi(p.z / ShipGrid.CELL_SIZE))
				if ship.grid.has_block(cell):
					inside += 1
					query.position = c + place * v
					for hit: Dictionary in space.intersect_point(query, 8):
						if hit["collider"] == ship.exterior:
							solid += 1
							break
					var off := (p - ShipGrid.cell_center(cell)).abs()
					var depth_in := ShipGrid.CELL_SIZE * 0.5 - maxf(off.x, maxf(off.y, off.z))
					if depth_in > deepest:
						deepest = depth_in
						which = "%s at %s, the stone %.1f m across" % [ship.grid.get_block(cell).block_id, cell, float(stone[3])]
			if inside > 0:
				corners += inside
				stones += 1
	return [solid, "%d stones within %.0f m of its middle; %d corners of %d of them inside occupied hull cells' boxes%s; %d inside the hull's own colliders" % [
		near, span, corners, stones, ", the deepest %.2f m in (%s)" % [deepest, which] if corners > 0 else "", solid]]

## `ship` landed (or resting) from BOULDER_VIEW m off its middle at eye height
## along `toward` (hull axes, level; farther if its hull reaches past
## BOULDER_VIEW - VIEW_OFF that way), turned by up to 60 deg if a stone stands
## at the camera, looking at its keel. Returns the way the camera stands from
## the hull, in the world, level.
func _boulder_shot(shot_name: String, ship: Ship, toward: Vector3) -> Vector3:
	var hull := ship.exterior.global_transform
	var dir := Vector3(toward.x, 0.0, toward.z).normalized()
	var flat := dir
	for turn: float in [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0]:
		var d := dir.rotated(Vector3.UP, deg_to_rad(turn))
		var dist := maxf(BOULDER_VIEW, _reach(ship, Vector3.ZERO, d) + VIEW_OFF)
		flat = d * dist
		var at := _up(_over_ground(ship, flat, EYE))
		var bins := Bins.new(at, _planet.radius, 4.0)
		bins.add_all(_scattered(at, 8.0)[0])
		if float(bins.near(at, 0.5)[1]) >= 0.5:
			break
	await _ground_shot(shot_name, ship, flat, EYE, Vector3(0.0, -ship.stance_depth() + 1.0, 0.0))
	var way := hull.basis * flat
	var up := _up(hull.origin)
	way = (way - up * way.dot(up)).normalized()
	print("        %s from %.0f m off its middle at eye height" % [shot_name, flat.length()])
	return way

## The frame rate over `seconds`, `what` it is of, against the floor.
func _reading_for(what: String, seconds: float) -> float:
	var fps := await _fps(seconds)
	var line := "fps     %.0f %s, over %.0f s %s" % [fps, what, seconds, _ms()]
	print(line)
	_readings.append(line)
	_check(fps >= FPS_FLOOR, "fps %.0f %s (at least %.0f)" % [fps, what, FPS_FLOOR])
	return fps

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
