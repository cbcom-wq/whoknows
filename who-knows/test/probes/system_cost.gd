extends "res://test/probes/oasis_render.gd"

## What the rest of the star system costs you while you are on WADIS (the owner's
## question, 2026-11-23). The starter lands on Wadoo's pad and you step out; then,
## on foot in the village (eye 1.6 m), looking along the ground and looking up at
## the sky, the frame rate is read with everything on, then with each part of
## space switched off alone (the asteroid stream, the other worlds, the belts, the
## space dust, the sun's 2 km shadow reach cut to 300 m), then with all of them
## off. Each reading prints fps, the render's GPU and CPU ms, the engine's
## process and physics ms, draw calls, objects and primitives. Then each space
## system's own per-tick script is timed by calling it N times by hand.
##
##   godot --path . --resolution 1280x720 --script res://test/probes/system_cost.gd -- <abs out dir>

const READ_SECONDS := 6.0
const SETTLE := 1.5
const TIMED_CALLS := 200
## On foot by the pool, looking at the breach (oasis_render's fps view).
const STAND := [14.0, -12.0]
const LOOK := [46.4, -11.2]

var _sun: DirectionalLight3D
var _stream_node: AsteroidStream

func _run() -> void:
	await _frames(3)
	_fleet = _scene.get("fleet")
	_starter = _scene.get_node("Ship")
	_director = _scene.get_node("CameraDirector")
	_avatar = get_first_node_in_group(Avatar.GROUP)
	_universe = _scene.get_node("Universe")
	_gravity = _scene.get("world_gravity")
	_stars = _scene.get("star_system")
	_sun = _scene.get_node("DirectionalLight3D")
	_stream_node = _scene.get_node("AsteroidStream")
	_scene.set("reload", func() -> void: pass)
	_which = "village"
	print("gpu     %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	var system: SystemRecipe = _scene.get("system")
	_planet = system.body(WORLD_ID)
	for place in system.places():
		if place.id == PLACE_ID:
			_oasis = place
	print("system  %d bodies, %d belts" % [system.bodies.size(), system.belts.size()])
	_starter.flight_computer.assist_enabled = true
	await _sit(_starter)
	await _hide_the_card()
	await _warp_in()
	if not await _to_the_planet():
		print("cost    no world to come down on")
		quit(1)
		return
	_terrain = WorldTerrain.new(_planet.recipe)
	_find_the_oasis()
	await _aboard()
	await _starter_on_the_pad()
	if not _starter.landing.is_landed():
		print("cost    the starter did not land")
		quit(1)
		return
	_director.stand_now()
	await _frames(3)
	if not await _out_through(_starter.airlocks.values()[0], "", "foot"):
		quit(1)
		return
	var at := _oasis.local_dir(STAND[0], STAND[1], _planet.radius)
	var to := _oasis.local_dir(LOOK[0], LOOK[1], _planet.radius)
	await _stand_far(at, _way_to(at, to))
	_avatar.set_head_pitch(0.0)
	await _seconds(2.0)
	_census()
	if OS.get_cmdline_user_args().has("quick"):
		_time_rocks()
		_let_go()
		quit(0)
		return
	for view: Array in [["ground", 0.0], ["sky", deg_to_rad(35.0)]]:
		_avatar.set_head_pitch(view[1])
		await _seconds(SETTLE)
		await _shot("cost_%s" % view[0])
		print("view    %s" % view[0])
		await _measure("everything on")
		for part: String in ["rocks", "worlds", "belts", "dust", "shadow300"]:
			_switch(part, false)
			await _seconds(SETTLE)
			await _measure("%s off" % part)
			_switch(part, true)
			await _seconds(SETTLE)
		for part: String in ["rocks", "worlds", "belts", "dust"]:
			_switch(part, false)
		await _seconds(SETTLE)
		await _measure("all space off (shadow kept)")
		_switch("shadow300", false)
		await _seconds(SETTLE)
		await _measure("all space off, shadow 300 m")
		for part: String in ["rocks", "worlds", "belts", "dust", "shadow300"]:
			_switch(part, true)
		await _seconds(SETTLE)
		await _measure("everything back on")
	_avatar.set_head_pitch(0.0)
	_time_scripts()
	await _aboard()
	await _seconds(1.0)
	for run: Array in [["rocks on", true], ["rocks off", false], ["rocks on again", true]]:
		_switch("rocks", run[1])
		await _skim(run[0])
	_switch("rocks", true)
	_let_go()
	print("cost    done")
	quit(0)

func _switch(part: String, on: bool) -> void:
	match part:
		"rocks":
			_stream_node.visible = on
			if on:
				_stream_node.resume()
			else:
				_stream_node.suspended = true
		"worlds":
			for p in _stars.proxies:
				if p.body != _planet and p.body != _stars.recipe.star:
					p.visible = on
		"belts":
			for b in _stars.belts:
				b.visible = on
		"dust":
			_stars.dust.visible = on
		"shadow300":
			_sun.directional_shadow_max_distance = AsteroidStream.SHADOW_REACH if on else 300.0

func _measure(what: String) -> void:
	var proc := 0.0
	var phys := 0.0
	var draws := 0.0
	var objs := 0.0
	var prims := 0.0
	var n := 0
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(READ_SECONDS * 1e6):
		await process_frame
		n += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	RenderingServer.viewport_set_measure_render_time(vp, false)
	var k := maxf(n, 1.0)
	print("read    %-30s %5.0f fps  gpu %5.2f  cpu %5.2f  process %5.2f  physics %5.2f ms  draws %5.0f  objects %5.0f  prims %8.0f" % [
		what, n / READ_SECONDS, gpu / k, cpu / k, proc / k, phys / k, draws / k, objs / k, prims / k])

func _census() -> void:
	print("census  rock cells loaded %d / %d / %d, bubble bodies %d" % [
		_stream_node.loaded_count(0), _stream_node.loaded_count(1), _stream_node.loaded_count(2),
		_stream_node.bubble.live.size()])
	var shown := 0
	var surfaces := 0
	for p in _stars.proxies:
		if p.visible:
			shown += 1
		if p.get("_surface") != null:
			surfaces += 1
	print("census  %d body proxies (%d with a surface up), %d belts, dust density %.2f" % [
		_stars.proxies.size(), surfaces, _stars.belts.size(), _stars.dust.density])
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("census  %d nodes in the tree" % nodes)
	for child in _stream_node.get_children():
		print("census  stream/%s: %d children" % [child.name, child.get_child_count()])

## Seated, the hull carried SKIM_UP m over the ground at the speed limit for
## SKIM_SECONDS (world_probe's skim), from a fresh heading each run.
const SKIM_UP := 150.0
const SKIM_SECONDS := 20.0
var _skim_bearing := 0.0

func _skim(what: String) -> void:
	_skim_bearing += 2.1
	var here := _oasis.local_dir(0.0, 0.0, _planet.radius).normalized()
	var east := Vector3.UP.cross(here).normalized()
	var north := here.cross(east).normalized()
	var ahead := (east * sin(_skim_bearing) + north * cos(_skim_bearing)).normalized()
	var well_top := _planet.well_radius - _planet.radius
	var hull := _starter.exterior
	hull.freeze = false
	var t0 := Time.get_ticks_usec()
	var last := t0
	var worst := 0.0
	var over := 0
	var frames := 0
	var peak_jobs := 0
	var proc := 0.0
	var travelled := 0.0
	while Time.get_ticks_usec() - t0 < int(SKIM_SECONDS * 1e6):
		await process_frame
		var dt := (Time.get_ticks_usec() - last) / 1e6
		var limit := FlightComputer.speed_limit(SKIM_UP, well_top)
		var axis := ahead.cross(here).normalized()
		here = here.rotated(axis, limit * dt / (_planet.radius + SKIM_UP)).normalized()
		ahead = axis.cross(here).normalized()
		travelled += limit * dt
		var at := _planet.point.plus(here * (_planet.radius + _terrain.height_at(here) + SKIM_UP))
		hull.global_transform = Transform3D(Basis.looking_at(ahead, here), _universe.to_engine(at))
		hull.linear_velocity = ahead * limit
		hull.angular_velocity = Vector3.ZERO
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		if frames > 0:
			worst = maxf(worst, ms)
			if ms > 12.5:
				over += 1
		frames += 1
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		peak_jobs = maxi(peak_jobs, (_stream_node.get("_jobs") as Dictionary).size())
	hull.linear_velocity = Vector3.ZERO
	print("skim    %-16s %.0f m at %.0f m/s, %d frames, worst frame %.1f ms, %d frames over 12.5 ms, process %.2f ms, peak rock jobs %d, cells %d/%d/%d" % [
		what, travelled, FlightComputer.speed_limit(SKIM_UP, well_top), frames, worst, over, proc / maxf(frames, 1.0), peak_jobs,
		_stream_node.loaded_count(0), _stream_node.loaded_count(1), _stream_node.loaded_count(2)])
	var fps := await _fps(4.0)
	print("skim    %-16s then hovering: %.0f fps %s" % [what, fps, _ms()])

## The rock stream's per-tick work taken apart.
func _time_rocks() -> void:
	var anchors := get_nodes_in_group(AsteroidStream.SPACE_ANCHOR)
	print("rocks   %d anchors: %s" % [anchors.size(), ", ".join(anchors.map(func(n: Node) -> String: return str(n.get_path())))])
	_time("details.step", func() -> void: _stream_node.details.step())
	_time("details._near", func() -> void: _stream_node.details.call("_near"))
	_time("bubble.step", func() -> void: _stream_node.bubble.step(0.0))
	_time("bubble._near_paths", func() -> void: _stream_node.bubble.call("_near_paths"))
	_time("update", func() -> void: _stream_node.update(0.0))
	for a: Node3D in anchors:
		var at := a.global_position
		var box := AABB(at, Vector3.ZERO).grow(4500.0 + 250.0)
		print("rocks   %s: giant cells in its box %d" % [a.name, _stream_node.cells_in(2, box).size()])
		_time("  cells_in giant for %s" % a.name, func() -> void: _stream_node.cells_in(2, box))

func _time(what: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	for i in TIMED_CALLS:
		f.call()
	var us := float(Time.get_ticks_usec() - t0) / TIMED_CALLS
	print("script  %-40s %7.1f us a call" % [what, us])

func _time_scripts() -> void:
	print("script  each space system's per-tick work, called %d times by hand" % TIMED_CALLS)
	_time("StarSystem.place_all (every physics tick)", func() -> void: _stars.place_all())
	var focus := _universe.to_universe(_universe.focus.global_position)
	var others := 0.0
	for p in _stars.proxies:
		var t0 := Time.get_ticks_usec()
		for i in TIMED_CALLS:
			p.place(_universe, focus)
		var us := float(Time.get_ticks_usec() - t0) / TIMED_CALLS
		if p.body == _planet:
			print("script    WADIS's own proxy.place (its surface)  %7.1f us" % us)
		else:
			others += us
	print("script    the 12 other bodies' place, together    %7.1f us" % others)
	_time("  belts' place", func() -> void:
		for b in _stars.belts:
			b.place(_universe, focus))
	_time("  dust place", func() -> void: _stars.dust.place(_universe, focus))
	_time("AsteroidStream.update alone", func() -> void: _stream_node.update(0.0))
	_time("AsteroidStream.update+details (every frame)", func() -> void:
		_stream_node.update(0.0)
		_stream_node.details.step())
	_time("AsteroidBubble.step (every physics tick)", func() -> void: _stream_node.bubble.step(0.0))
	var salvage: SalvageField = _scene.get("salvage")
	if salvage != null:
		_time("SalvageField.update (every physics tick)", func() -> void: salvage.update())
	var places: PlaceField = _scene.get("places")
	if places != null:
		_time("PlaceField.update (every physics tick)", func() -> void: places.update())
	_time("Whereabouts.look (every EVERY s)", func() -> void: _stars.whereabouts.look())
