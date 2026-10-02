extends SceneTree

# A big world in the real flight scene, for the owner and for the budgets
# (docs/superpowers/specs/2026-09-30-world-scale-design.md §5.6, §8.3). Run it
# WITHOUT --headless so it renders and the frame times mean something:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/world_probe.gd -- <abs out dir> [seed] [fly|shots]
#
# Writes world_*.png: the largest planet from a neighbour, from its warp limit,
# from its well's edge, from 1 km, skimming at 150 m, standing (1.6 m), a
# moon in its sky, a belt from a planet, and after the descent. Then flies
# from the limit to 150 m at the speed limit and skims 20 km, printing per
# phase: frames and seconds, the worst frame, draw calls, chunks visible (all
# round you), in the frustum (what the canopy camera draws) and built, and
# the floor's count. Budgets: worst frame 33 ms, 150 chunks in the frustum,
# floor 0. A "spike" line is printed for each frame over budget (the first
# 60), with what the surface was doing and the render's CPU and GPU times.
# One missed vsync on a 60 Hz screen reads as 33.3 to 34 ms, so each phase also
# counts its frames over budget: a slip or two in thousands is not a stall.
# "fly" as the third argument skips the shots and only flies, "shots" skips
# the flight (pass any non-number as the seed to keep the flight test's own).
#
# The hull is carried by hand but not frozen: each tick it is put where the
# flight has got to and given the velocity it is flying at, so the ground's
# solid reach and the asteroid bubble see a real flight. A frozen hull's
# velocity comes from its moves instead, and the floating origin's shift reads
# as a jump of 100+ km/s: the bubble then searched a path hundreds of km long
# (a 41 s frame), which no real flight does.

## A frame over this is over budget (§5.6), and printed.
const BUDGET_MS := 33.0
const SPIKES_PRINTED := 60
## Ticks to let a teleport settle before a phase's clock starts: the first
## frames at a new place compile and upload what it shows (140 ms and more),
## which no flight pays but a warp's arrival.
const SETTLE_TICKS := 60
## A phase that takes longer than this is given up and printed as far as it
## got (a hang is a finding). The skim runs 160 s at a steady 60 fps.
const DESCENT_LIMIT_MSEC := 6 * 60 * 1000
const SKIM_LIMIT_MSEC := 3 * 60 * 1000

var _out := ""
var _root: Node
var _ship: Ship
var _universe: Universe
var _stream: AsteroidStream
var _system: SystemRecipe
var _planet: SystemBody
var _terrain: WorldTerrain
var _fly_only := false
var _shots_only := false
var _spikes := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_fly_only = args.size() > 2 and args[2] == "fly"
	_shots_only = args.size() > 2 and args[2] == "shots"
	_root = load("res://scenes/flight_test.tscn").instantiate()
	if args.size() > 1 and args[1].is_valid_int():
		(_root.get_node("AsteroidStream") as AsteroidStream).seed = args[1].to_int()
	# Never the owner's game: saving is on outside --headless.
	_root.save_enabled = false
	root.add_child(_root)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## `outside`: look from the hull with a camera of the probe's own, the ship
## hidden, because the player's view is the ship's interior and the world only
## shows in its windows.
func _shot(name: String, outside := true) -> void:
	var before := root.get_viewport().get_camera_3d()
	var cam: Camera3D = null
	if outside:
		cam = Camera3D.new()
		cam.far = BodyProxy.VIEW_FAR
		cam.near = 0.05
		cam.add_to_group(Universe.EXTERIOR_SPACE)
		_root.get_node("Outside").add_child(cam)
		cam.global_transform = _ship.exterior.global_transform
		cam.make_current()
		_ship.visible = false
	await _frames(8)
	var file := "%s/world_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s   %s" % [file, _root.star_system.whereabouts.text()])
	if cam != null:
		_ship.visible = true
		cam.queue_free()
		if before != null:
			before.make_current()

func _surface() -> WorldSurface:
	return (_root.star_system.proxy(_planet.id) as BodyProxy).surface()

## Puts the hull, at rest, at `at`, facing `target`, and everything outside
## ready for it, the ground built.
func _put(at: UniversePoint, target: UniversePoint) -> void:
	var hull := _ship.exterior
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	var dir := target.minus(at).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	hull.global_transform = Transform3D(Basis.looking_at(dir, up), _universe.to_engine(at))
	_universe.check()
	_root.star_system.place_all()
	_root.star_system.whereabouts.look()
	_stream.update(0.0, true)
	if _surface() != null:
		_surface().finish()

## The hull where the flight has got to, flying at `velocity`.
func _carry(at: UniversePoint, velocity: Vector3) -> void:
	var hull := _ship.exterior
	hull.global_position = _universe.to_engine(at)
	hull.linear_velocity = velocity
	hull.angular_velocity = Vector3.ZERO

## How many of the surface's visible chunks have any of their box inside the
## canopy camera's frustum (the one that draws the world): visible_chunks()
## counts those behind the camera and off to the sides too, never drawn.
func _in_frustum() -> int:
	var cam := _ship.get_node("Canopy/CanopyCam") as Camera3D
	var surface := _surface()
	if cam == null or surface == null:
		return 0
	var planes := cam.get_frustum()
	var n := 0
	for c in surface.get_children():
		var m := c as MeshInstance3D
		if m == null or not m.visible:
			continue
		var box := m.global_transform * m.get_aabb()
		var inside := true
		for pl in planes:
			if pl.distance_to(box.get_support(-pl.normal)) > 0.0:
				inside = false
				break
		if inside:
			n += 1
	return n

## A frame over budget, with what the surface was doing: where a spike came
## from. The process and physics times are the frame's before.
func _spike(ms: float) -> void:
	if ms <= BUDGET_MS or _surface() == null or _spikes >= SPIKES_PRINTED:
		return
	_spikes += 1
	var alt := _terrain.altitude_of(_universe.to_universe(_ship.exterior.global_position).minus(_planet.point))
	var rid := root.get_viewport().get_viewport_rid()
	print("spike   %.0f ms at %.0f m  jobs %d  built %d  leaves %d  process %.0f ms  physics %.0f ms  render cpu %.1f gpu %.1f ms" % [ms, alt,
		_surface().jobs_in_flight(), _surface().chunk_count(), _surface().leaves.size(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(rid), RenderingServer.viewport_get_measured_render_time_gpu(rid)])

func _ground(dir: Vector3, above: float) -> UniversePoint:
	return _planet.point.plus(dir * (_planet.radius + _terrain.height_at(dir) + above))

func _run() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport().get_viewport_rid(), true)
	await _frames(5)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	_stream = _root.get_node("AsteroidStream")
	_system = _root.system
	for p in _system.planets():
		if _planet == null or p.radius > _planet.radius:
			_planet = p
	_terrain = WorldTerrain.new(_planet.recipe)
	print("probe   %s  r %.0f m  relief %.0f m  %s" % [_planet.name, _planet.radius, _terrain.relief,
		WorldRecipe.Archetype.keys()[_planet.recipe.archetype]])
	# On the sunward side, a little off the line to the star, so relief shades.
	var sun := _system.star.point.minus(_planet.point).normalized()
	var dir := sun.rotated(Vector3.UP, 0.6).normalized()
	if not _fly_only:
		var neighbour := _nearest_other(_planet)
		_put(neighbour.point.plus(_planet.point.minus(neighbour.point).normalized() * neighbour.warp_limit), _planet.point)
		await _shot("from_neighbour")
		_put(_planet.point.plus(dir * _planet.warp_limit), _planet.point)
		await _shot("from_limit")
		_put(_planet.point.plus(dir * _planet.well_radius), _planet.point)
		await _shot("from_well_edge")
		var ahead := dir.cross(Vector3.UP).normalized()
		_put(_ground(dir, 1000.0), _ground(dir.rotated(Vector3.UP.cross(dir).normalized(), 0.05), 0.0))
		await _shot("from_1km")
		_put(_ground(dir, 150.0), _ground(dir.rotated(ahead, 0.01), 150.0))
		await _shot("skimming_150m")
		await _standing(dir)
		await _moon_in_the_sky(dir)
		await _belt_from_a_planet()
	if not _shots_only:
		await _descend(dir)
	print("probe   done")
	quit()

func _nearest_other(p: SystemBody) -> SystemBody:
	var best: SystemBody = null
	for q in _system.planets():
		if q != p and (best == null or q.point.minus(p.point).length() < best.point.minus(p.point).length()):
			best = q
	return best

## A camera at 1.6 m on the ground, looking along it: eye height (CLAUDE.md).
func _standing(dir: Vector3) -> void:
	_put(_ground(dir, 30.0), _ground(dir.rotated(Vector3.UP.cross(dir).normalized(), 0.001), 30.0))
	var before := root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.far = BodyProxy.VIEW_FAR
	cam.near = 0.05
	cam.add_to_group(Universe.EXTERIOR_SPACE)
	_root.get_node("Outside").add_child(cam)
	var eye := _ground(dir, 1.6)
	var look := _ground(dir.rotated(Vector3.UP.cross(dir).normalized(), 0.002), 1.6)
	cam.global_transform = Transform3D(Basis.looking_at(look.minus(eye).normalized(), dir), _universe.to_engine(eye))
	cam.make_current()
	await _shot("standing", false)
	cam.queue_free()
	# The pilot's camera again: the canopy's view, and what is in its frustum,
	# follow it.
	if before != null:
		before.make_current()
	await _frames(2)

func _moon_in_the_sky(dir: Vector3) -> void:
	var moons := _system.moons_of(_planet)
	if moons.is_empty():
		print("probe   no moon round %s" % _planet.name)
		return
	var m := moons[0]
	var up := m.point.minus(_planet.point).normalized()
	_put(_ground(up.slerp(dir, 0.3).normalized(), 200.0), m.point)
	await _shot("moon_in_the_sky")

func _belt_from_a_planet() -> void:
	if _system.belts.is_empty():
		return
	var belt := _system.belts[0]
	var best: SystemBody = null
	for p in _system.planets():
		var r := p.point.minus(belt.centre).length()
		if best == null or absf(r - belt.radius) < absf(best.point.minus(belt.centre).length() - belt.radius):
			best = p
	var out := best.point.minus(belt.centre)
	var at := best.point.plus(-out.normalized() * best.warp_limit)
	var target := belt.centre.plus(out.normalized() * belt.radius)
	_put(at, target)
	await _shot("belt_from_planet")

## The numbers of one flight phase, gathered a tick at a time.
class _Phase:
	var name := ""
	var frames := 0
	var worst := 0.0
	var late := 0
	var calls := 0
	var chunks := 0
	var seen := 0
	var built := 0
	var fell := 0
	var _t0 := 0
	var _begun := 0
	var _limit := 0

	func _init(p_name: String, p_limit: int) -> void:
		name = p_name
		_limit = p_limit
		_t0 = Time.get_ticks_usec()
		_begun = Time.get_ticks_msec()

	func over() -> bool:
		return Time.get_ticks_msec() - _begun >= _limit

	## The frame just gone, in ms.
	func tick() -> float:
		var now := Time.get_ticks_usec()
		var ms := (now - _t0) / 1000.0
		_t0 = now
		frames += 1
		worst = maxf(worst, ms)
		late += 1 if ms > BUDGET_MS else 0
		calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		return ms

	func text() -> String:
		return "probe   %s  %d frames in %.0f s%s  worst frame %.1f ms (%d over %.0f ms)  draw calls %d  chunks visible %d  in frustum %d  built %d  floor %d" % [
			name, frames, (Time.get_ticks_msec() - _begun) / 1000.0, " (given up)" if over() else "",
			worst, late, BUDGET_MS, calls, chunks, seen, built, fell]

func _measure(phase: _Phase) -> void:
	_spike(phase.tick())
	var s := _surface()
	if s != null:
		phase.chunks = maxi(phase.chunks, s.visible_chunks().size())
		phase.seen = maxi(phase.seen, _in_frustum())
		phase.built = maxi(phase.built, s.chunk_count())
		phase.fell = s.floor_fired

## From the limit to 150 m at the speed limit, then 20 km at 150 m. Each
## phase's clock starts a tick in: the frame that draws a teleport is the
## probe's, not the flight's.
func _descend(dir: Vector3) -> void:
	var at := _planet.point.plus(dir * _planet.warp_limit)
	_put(at, _planet.point)
	var well_top := _planet.well_radius - _planet.radius
	for i in SETTLE_TICKS:
		await physics_frame
	var phase := _Phase.new("descent", DESCENT_LIMIT_MSEC)
	while not phase.over():
		await physics_frame
		_measure(phase)
		var alt := _terrain.altitude_of(at.minus(_planet.point))
		if alt <= 150.0:
			break
		var limit := FlightComputer.speed_limit(alt, well_top)
		at = at.plus(-dir * minf(limit / 60.0, alt - 150.0))
		_carry(at, -dir * limit)
	_carry(at, Vector3.ZERO)
	print(phase.text())
	await _shot("after_descent")
	var ahead := dir.cross(Vector3.UP).normalized()
	var here := dir
	var travelled := 0.0
	await physics_frame
	phase = _Phase.new("skim 20 km", SKIM_LIMIT_MSEC)
	while travelled < 20000.0 and not phase.over():
		await physics_frame
		_measure(phase)
		var limit := FlightComputer.speed_limit(150.0, well_top)
		var axis := ahead.cross(here).normalized()
		here = here.rotated(axis, limit / 60.0 / (_planet.radius + 150.0)).normalized()
		travelled += limit / 60.0
		_carry(_ground(here, 150.0), axis.cross(here).normalized() * limit)
	_carry(_ground(here, 150.0), Vector3.ZERO)
	print(phase.text())
