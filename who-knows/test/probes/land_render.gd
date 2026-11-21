extends "res://test/probes/desert_render.gd"

# WADIS's land, rendered in the flight scene for Checkpoint 1 of the wadis land
# spec (docs/superpowers/specs/2026-11-19-wadis-land-design.md §11): every
# point comes from the plan (WorldPlan.shapes, .sites), none is hand-picked.
#
#   orbit      WADIS from 3 radii off, from the lit side with the most sea and
#              range in view (orbit_3r)
#   10 km      over the land behind a shore site, looking out over the sea
#              (shore_10km)
#   2 km       over a range's flank (range_2km), and over the dry sea basin
#              (sea_2km)
#   300 m      along a canyon (canyon_300m)
#   eye 1.6 m  on a canyon floor (canyon_floor_1.6m), at a range's foot
#              (range_foot_1.6m), on a beach looking out (beach_1.6m) and from
#              Wadoo's pad toward the range on its skyline (wadoo_pad_1.6m)
#   flown      the starter at its speed limit near the ground, 60 m over the
#              ground, along a canyon (flight_canyon) and over a range
#              (flight_range), each LAND_FLIGHT_SECONDS
#
# Each view is held by the starter 120 m behind the camera with the hull's layer
# culled, the frame rate is read seated there, and the render is the probe's own
# camera. A view is lit by the system's real star: a candidate point is chosen
# in daylight (the sun SUN_MIN deg up or more over it); only when no candidate is
# lit does the probe move the star for that one view, and the PNG's name then
# ends in _relit (the star is put back after). Run WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 \
#     --script res://test/probes/land_render.gd -- <abs out dir> [views|flights|all]
#
# The PNGs are land_<name>.png.

## Daylight: the sun at least this many degrees up over a point.
const SUN_MIN := 12.0
## A relit view: the star moved to stand SUN_UP over the target's horizon,
## SUN_ROUND round from the way back to the camera.
const SUN_UP := 30.0
const SUN_ROUND := 50.0
const FLIGHT_OVER := 60.0
const LAND_FLIGHT_SECONDS := 20.0
## A flight's route is sampled this far apart, m, and its height is the highest
## ground within FLIGHT_WINDOW samples either side, plus the clearance.
const ROUTE_STEP := 20.0
const FLIGHT_WINDOW := 4
const ORBIT_CANDIDATES := 600
const ORBIT_REACH_DEG := 55.0

var _relit_view := false
var _canyon_pick := {}
var _range_pick := {}

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
	var which := args[1] if args.size() > 1 else "all"
	if not which in ["all", "views", "flights"]:
		print("land    no set called %s: views, flights or all" % which)
		quit(1)
		return
	print("gpu     %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	if not await _to_the_planet():
		quit(1)
		return
	_terrain = WorldTerrain.new(_planet.recipe)
	_starter.flight_computer.assist_enabled = true
	await _sit(_starter)
	await _hide_the_card()
	if which in ["all", "views"]:
		await _views()
	if which in ["all", "flights"]:
		await _flights()
	_let_go()
	print("        the frame rate:")
	for line in _readings:
		print("        %s" % line)
	print("land    %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)

# --- helpers ---------------------------------------------------------------------

func _sun_up(d: Vector3) -> float:
	return 90.0 - rad_to_deg(d.angle_to(_to_star()))

func _lit(d: Vector3) -> bool:
	return _sun_up(d) >= SUN_MIN

## Ground height, or the sea's level where there is sea (the water, once drawn).
func _h(d: Vector3) -> float:
	return maxf(_terrain.height_at(d), _terrain.plan.sea_level)

func _pt(d: Vector3, h: float) -> Vector3:
	return _centre() + d * (_planet.radius + h)

func _way(d: Vector3, to: Vector3) -> Vector3:
	var w := to - d
	return (w - d * w.dot(d)).normalized()

## The star moved so the sun stands SUN_UP over `target`'s horizon, SUN_ROUND
## round from the way back to `cam`.
func _relight(target: Vector3, cam: Vector3) -> void:
	var star: SystemBody = (_scene.get("system") as SystemRecipe).star
	var dist := star.point.minus(_planet.point).length()
	var back := _way(target, cam).rotated(target, deg_to_rad(SUN_ROUND))
	var e := deg_to_rad(SUN_UP)
	star.point = _planet.point.plus((target * sin(e) + back * cos(e)).normalized() * dist)
	_moved()

## One view: the ship held `hold` m over the ground 120 m behind `cam`, the
## frame rate seated there, then the probe's camera `eye` m over the radius at
## `cam` looking at `target` at `target_h` m over the radius. `relit` moves the
## star for this view only, and says so in the name.
func _view(shot_name: String, cam: Vector3, eye: float, target: Vector3, target_h: float, hold := 40.0, relit := false) -> void:
	var way := _way(cam, target)
	var star: SystemBody = (_scene.get("system") as SystemRecipe).star
	var star_was := star.point
	if relit:
		_relight(target, cam)
		shot_name += "_relit"
	await _hold_at(_off(cam, -way, 120.0), hold, way)
	await _seconds(2.0)
	await _ground_built()
	var at := _pt(cam, eye)
	print("view    %s: camera sun %.1f deg up (target %.1f), eye %.1f m over the ground, the target %.0f m off along the ground, %.0f m over the eye%s" % [
		shot_name, _sun_up(cam), _sun_up(target), eye - _terrain.height_at(cam), cam.angle_to(target) * _planet.radius,
		target_h - eye, ", RELIT: no lit candidate" if relit else ""])
	await _reading_for("seated at %s" % shot_name, 3.0)
	await _bare_shot(shot_name, Transform3D(Basis.looking_at(_pt(target, target_h) - at, _up(at)), at))
	if relit:
		star.point = star_was
		_moved()

func _shot(shot_name: String) -> void:
	await _seconds(0.3)
	await _frames(5)
	var image := root.get_viewport().get_texture().get_image()
	var file := "%s/land_%s.png" % [_out, shot_name]
	image.save_png(file)
	print("render  %s" % file)

## The unit ground gradient of the shore field: the way down to the water.
func _shore_fall(d: Vector3) -> Vector3:
	var p := _terrain.plan
	var ab := _tangents(d)
	var gx := p.map.at(WorldPlan.S_SHORE, _off(d, ab[0], 1.0)) - p.map.at(WorldPlan.S_SHORE, _off(d, ab[0], -1.0))
	var gy := p.map.at(WorldPlan.S_SHORE, _off(d, ab[1], 1.0)) - p.map.at(WorldPlan.S_SHORE, _off(d, ab[1], -1.0))
	return -(ab[0] * gx + ab[1] * gy).normalized()

func _sites(kind: PlanSite.Kind) -> Array[PlanSite]:
	var out: Array[PlanSite] = []
	for s in _terrain.plan.sites:
		if s.kind == kind:
			out.append(s)
	return out

# --- the views -------------------------------------------------------------------

func _views() -> void:
	await _orbit()
	await _shore_views()
	await _range_views()
	await _canyon_views()
	await _wadoo_view()

## From 3 radii off, the lit vantage that shows the most sea, range and canyon
## within ORBIT_REACH_DEG of the point under it.
func _orbit() -> void:
	var p := _terrain.plan
	var star := _to_star()
	var marks := PackedVector3Array()
	for s in _sites(PlanSite.Kind.SHORE):
		marks.append(s.dir)
	for rg: Dictionary in p.shapes.ranges:
		for q: Vector3 in rg.spine:
			marks.append(q)
	for c: Dictionary in p.shapes.canyons:
		for q: Vector3 in c.path:
			marks.append(q)
	var best := star
	var best_score := -1.0
	for k in ORBIT_CANDIDATES:
		var y := 1.0 - 2.0 * (k + 0.5) / ORBIT_CANDIDATES
		var a := PI * (1.0 + sqrt(5.0)) * (k + 0.5)
		var v := Vector3(cos(a) * sqrt(1.0 - y * y), y, sin(a) * sqrt(1.0 - y * y))
		if v.dot(star) < 0.5:
			continue
		var score := 0.0
		for q in marks:
			if v.angle_to(q) < deg_to_rad(ORBIT_REACH_DEG):
				score += 1.0
		for j in 40:
			var w := v.rotated(_tangents(v)[0], deg_to_rad(ORBIT_REACH_DEG) * (j % 8) / 8.0).rotated(v, TAU * j / 40.0)
			if p.land_at(w) == WorldPlan.Land.SEA:
				score += 20.0
		score += 50.0 * v.dot(star)
		if score > best_score:
			best_score = score
			best = v
	var r := _planet.radius
	print("orbit   %.0f radii off, over the lit point %.1f deg from the star (sun %.0f deg up), score %.0f" % [
		ORBIT_RADII, rad_to_deg(best.angle_to(star)), _sun_up(best), best_score])
	await _hold_at(best, r * ORBIT_RADII - r, _tangents(best)[1])
	await _reading_for("seated, WADIS from 3 radii off", 3.0)
	var at := _centre() + best * (r * ORBIT_RADII)
	await _bare_shot("orbit_3r", Transform3D(Basis.looking_at(_centre() - at, _tangents(best)[1]), at))

## 10 km over the land behind a lit shore site, looking out to sea; 2 km out
## over the dry basin, looking across it; at eye height on the beach.
func _shore_views() -> void:
	var p := _terrain.plan
	var pick: PlanSite = null
	var relit := false
	for s in _sites(PlanSite.Kind.SHORE):
		var fall := _shore_fall(s.dir)
		if _lit(s.dir) and _lit(_off(s.dir, fall, 8000.0)) and _lit(_off(s.dir, -fall, 12000.0)) and p.land_at(_off(s.dir, fall, 4000.0)) == WorldPlan.Land.SEA:
			pick = s
			break
	if pick == null:
		relit = true
		for s in _sites(PlanSite.Kind.SHORE):
			if p.land_at(_off(s.dir, _shore_fall(s.dir), 4000.0)) == WorldPlan.Land.SEA:
				pick = s
				break
	if pick == null:
		_check(false, "a shore site with sea beyond it")
		return
	var d := pick.dir
	var fall := _shore_fall(d)
	print("shore   site at %.1f deg off the star, sun %.1f deg up there%s" % [rad_to_deg(d.angle_to(_to_star())), _sun_up(d), ", relit" if relit else ""])
	var back := _off(d, -fall, 12000.0)
	var out := _off(d, fall, 4000.0)
	await _view("shore_10km", back, _h(back) + 10000.0, out, _h(out), 40.0, relit)
	# 2 km over the basin, 6 km out, looking on across it.
	var mid := _off(d, fall, 6000.0)
	var far := _off(d, fall, 16000.0)
	await _view("sea_2km", mid, _h(mid) + 2000.0, far, _terrain.height_at(far), 40.0, relit)
	# On the beach, eye height, looking out.
	var stand := _off(d, fall, 80.0)
	var seaward := _off(d, fall, 3000.0)
	await _view("beach_1.6m", stand, _terrain.height_at(stand) + EYE, seaward, _terrain.height_at(seaward) + 40.0, 30.0, relit)

## A range: from 2 km over its flank, and at eye height at its foot.
func _range_views() -> void:
	var p := _terrain.plan
	var best := []
	var best_score := -INF
	var fallback := []
	var fallback_score := -INF
	for k in p.shapes.ranges.size():
		var rg: Dictionary = p.shapes.ranges[k]
		var spine: PackedVector3Array = rg.spine
		var hts: PackedFloat32Array = rg.height
		for i in range(2, spine.size() - 2, 2):
			var s := spine[i]
			var along := _way(spine[i - 1], spine[i + 1])
			var side := s.cross(along).normalized()
			for sg: float in [1.0, -1.0]:
				var w := side * sg
				var m := 0.0
				var foot := Vector3.ZERO
				while m < float(rg.half_width) * 2.0 + 5000.0:
					var q := _off(s, w, m)
					if p.map.at(WorldPlan.S_MOUNTAIN, q) <= 0.0:
						foot = q
						break
					m += 100.0
				if foot == Vector3.ZERO:
					continue
				var stand := _off(foot, w, 120.0)
				var c := _off(foot, w, 2500.0)
				var sl := p.land_at(stand)
				if sl != WorldPlan.Land.PLAINS and sl != WorldPlan.Land.DUNES:
					continue
				var all_lit := _lit(s) and _lit(stand) and _lit(c)
				var into := (-w).dot(_sun_way_at(c))
				var score := float(hts[i]) - 1500.0 * maxf(into, 0.0)
				var cand := [k, i, s, foot, c, stand, w, m]
				if all_lit and score > best_score:
					best_score = score
					best = cand
				if score > fallback_score:
					fallback_score = score
					fallback = cand
	var relit := best.is_empty()
	if relit:
		best = fallback
	if best.is_empty():
		_check(false, "a range with plains at its foot")
		return
	_range_pick = {"spine": best[2], "w": best[6], "foot": best[3]}
	var s: Vector3 = best[2]
	var foot: Vector3 = best[3]
	var stand: Vector3 = best[5]
	var w: Vector3 = best[6]
	print("range   %d, spine point %d: the spine %.0f m over the radius, foot %.0f m out, sun %.1f deg up%s" % [
		best[0], best[1], _terrain.height_at(s), float(best[7]), _sun_up(s), ", relit" if relit else ""])
	var cam := _off(s, w, float(best[7]) + 3000.0)
	await _view("range_2km", cam, _h(cam) + 2000.0, s, _terrain.height_at(s) * 0.6, 40.0, relit)
	await _view("range_foot_1.6m", stand, _terrain.height_at(stand) + EYE, s, _terrain.height_at(s), 30.0, relit)

func _sun_way_at(d: Vector3) -> Vector3:
	var t := _to_star()
	return (t - d * t.dot(d)).normalized()

## A canyon: 300 m over its floor looking along it, and at eye height on the
## floor. The canyon whose longest stretch is in daylight, at its middle.
func _canyon_views() -> void:
	var p := _terrain.plan
	var best := []
	var deepest := -1.0
	for n in p.shapes.canyons.size():
		var c: Dictionary = p.shapes.canyons[n]
		var path: PackedVector3Array = c.path
		for i in range(6, path.size() - 8):
			# The deepest lit stretch: the walls highest over the floor.
			if float(c.rim[i]) > deepest and _lit(path[i - 6]) and _lit(path[i]) and _lit(path[i + 6]):
				deepest = float(c.rim[i])
				best = [n, i, 0]
	var relit := best.is_empty()
	if relit:
		var longest := -1
		for n in p.shapes.canyons.size():
			var size := (p.shapes.canyons[n].path as PackedVector3Array).size()
			if size > longest:
				longest = size
				best = [n, size / 2, 0]
	var c: Dictionary = p.shapes.canyons[best[0]]
	var path: PackedVector3Array = c.path
	var i: int = clampi(best[1], 6, path.size() - 8)
	var floor_h: float = c.floor[i]
	print("canyon  %d of %d points at point %d: floor %.0f m, half floor %.0f m, rim %.0f m over it, mouth %s, sun %.1f deg up%s" % [
		best[0], path.size(), i, floor_h, float(c.half_floor[i]), float(c.rim[i]), c.get("mouth", &""), _sun_up(path[i]),
		", relit" if relit else ""])
	_canyon_pick = {"n": best[0], "i": i}
	var ahead: Vector3 = path[i + 6]
	await _view("canyon_300m", path[i], _h(path[i]) + 300.0, ahead, float(c.floor[i + 6]), 40.0, relit)
	await _view("canyon_floor_1.6m", path[i], floor_h + EYE, ahead, float(c.floor[i + 6]) + 40.0, 40.0, relit)

## Wadoo's middle, from the plan's one KEPT site.
func _wadoo_dir() -> Vector3:
	return _sites(PlanSite.Kind.KEPT)[0].dir

## From Wadoo's pad at eye height, toward the nearest range's spine (the one on
## its skyline).
func _wadoo_view() -> void:
	var p := _terrain.plan
	var oasis := _wadoo_dir()
	var frame := SystemDesign.frame_at(oasis, 0.0)
	var east := frame.x
	var north := -frame.z
	# The pad is Wadoo's own: places/oasis.json's "pad" "at", metres east and north of the place.
	var at: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))["pad"]["at"]
	var pad := _off(_off(oasis, east, float(at[0])), north, float(at[1]))
	var spine := Vector3.ZERO
	var near := INF
	for rg: Dictionary in p.shapes.ranges:
		for q: Vector3 in rg.spine:
			var m := oasis.angle_to(q) * _planet.radius
			if m < near:
				near = m
				spine = q
	var relit := not (_lit(pad) and _lit(spine))
	print("wadoo   pad %.0f m off the oasis's middle (inside the kept disc: weight %.2f), nearest range spine %.1f km off, sun %.1f deg up at the pad%s" % [
		pad.angle_to(oasis) * _planet.radius, p.keep_weight(pad), near / 1000.0, _sun_up(pad), ", relit" if relit else ""])
	await _view("wadoo_pad_1.6m", pad, _terrain.height_at(pad) + EYE, spine, _terrain.height_at(spine) * 0.5, 30.0, relit)

# --- flown at the limit ----------------------------------------------------------

func _flights() -> void:
	var p := _terrain.plan
	if _canyon_pick.is_empty():
		_canyon_pick = {"n": 0, "i": 6}
	var c: Dictionary = p.shapes.canyons[_canyon_pick.n]
	await _fly_route("flight_canyon", c.path, maxi(int(_canyon_pick.i) - 10, 0), FLIGHT_WINDOW)
	if _range_pick.is_empty():
		var rg: Dictionary = p.shapes.ranges[0]
		_range_pick = {"spine": rg.spine[rg.spine.size() / 2], "w": _way(rg.spine[2], rg.spine[4]).cross(rg.spine[2]), "foot": rg.spine[2]}
	# Across the range: a great circle through the spine point, along the way
	# the foot lies from it, from 12 km before to 12 km past.
	var s: Vector3 = _range_pick.spine
	var w: Vector3 = _range_pick.w
	var route := PackedVector3Array()
	var length := 25000.0
	for k in int(length / 500.0) + 1:
		route.append(_off(s, w, 12500.0 - k * 500.0))
	await _fly_route("flight_range", route, 0, 12)

## The route flown by carrying the frozen hull along it each physics tick at the
## speed limit where it is (FlightComputer.speed_limit_now), FLIGHT_OVER m over
## the highest ground within `window` samples either side, LAND_FLIGHT_SECONDS;
## the frame rate over the flight, and a render at the end. A route's points
## are directions; it is walked along the ground between them.
func _fly_route(shot_name: String, points: PackedVector3Array, from: int, window: int) -> void:
	var step := ROUTE_STEP
	var dirs := PackedVector3Array()
	var total := 0.0
	for i in range(from, points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var m := a.angle_to(b) * _planet.radius
		var n := maxi(1, int(m / step))
		for k in n:
			dirs.append(a.slerp(b, float(k) / n))
		total += m
	dirs.append(points[-1])
	var ground := PackedFloat32Array()
	for q in dirs:
		ground.append(_terrain.height_at(q))
	var height := PackedFloat32Array()
	var win := maxi(window, 1)
	for i in dirs.size():
		var hi := -INF
		for j in range(maxi(i - win, 0), mini(i + win, dirs.size() - 1) + 1):
			hi = maxf(hi, ground[j])
		height.append(hi)
	var computer := _starter.flight_computer
	await _hold_at(dirs[0], height[0] + FLIGHT_OVER - ground[0], _way(dirs[0], dirs[1]))
	await _seconds(1.0)
	var limit := computer.speed_limit_now()
	var cap := FlightComputer.CRUISE_LIMIT_MPS
	print("flight  %s: %.0f m of route (%.0f m of ground flown at most), the speed limit %.1f m/s %.0f m over the ground (cruise %.0f, plus 1/%.0f per m), %.0f m over the highest ground within %d samples" % [
		shot_name, total, limit * LAND_FLIGHT_SECONDS, limit, FLIGHT_OVER, cap, 1.0 / FlightComputer.LIMIT_PER_M, FLIGHT_OVER, win])
	var flown := [0.0, INF, -INF]
	var fly := func() -> void:
		flown[0] = float(flown[0]) + limit / Engine.physics_ticks_per_second
		var f := float(flown[0]) / step
		var i := mini(int(f), dirs.size() - 2)
		var t := clampf(f - i, 0.0, 1.0)
		var dir := dirs[i].slerp(dirs[i + 1], t)
		var nose := _way(dir, dirs[mini(i + 2, dirs.size() - 1)])
		var h := lerpf(height[i], height[i + 1], t) + FLIGHT_OVER
		_starter.exterior.global_transform = Transform3D(_level(dir, nose),
			_centre() + dir * (_planet.radius + h + _starter.stance_depth()))
		var over := _alt(_starter)
		flown[1] = minf(float(flown[1]), over)
		flown[2] = maxf(float(flown[2]), over)
	physics_frame.connect(fly)
	var shifts := _universe.shifts
	var fps := await _fps(LAND_FLIGHT_SECONDS)
	var line := "fps     %.0f seated flown %s at %.0f m/s for %.0f s (%.0f m flown, %.0f to %.0f m over the ground under the keel, the origin shifted %d times) %s" % [
		fps, shot_name, limit, LAND_FLIGHT_SECONDS, float(flown[0]), float(flown[1]), float(flown[2]), _universe.shifts - shifts, _ms()]
	print(line)
	_readings.append(line)
	_check(fps >= FPS_FLOOR, "fps %.0f flown %s (at least %.0f)" % [fps, shot_name, FPS_FLOOR])
	await _shot(shot_name)
	physics_frame.disconnect(fly)
