extends SceneTree

# The star system in the real flight scene, for the owner (the system skeleton
# spec §12): from the pilot's seat through the canopy, and in chase view. Run
# it WITHOUT --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/system_render.gd -- <abs out dir> [seed]
#
# With a seed, that system instead of the flight test's own: pick one with a
# ringed planet for the ring shots.
#
# With no GPU (a cloud container), Mesa's lavapipe renders Forward+ under
# Xvfb: xvfb-run -a -s "-screen 0 1280x720x24" godot ... as above.
#
# Writes system_*.png: the start (ahead, and turned to the star), a ringed
# planet from 25 km and 3 km, a moon by its planet, the belts from above the
# system, the star from 40 km and 8 km, dust going past at boost in open space
# and in a belt, and every world and star palette side by side. For the warp
# (docs/superpowers/specs/2026-09-28-warp-design.md §10.2): a planet's debris
# from its warp limit (seat and chase), a cluster from its limit, and a warp
# lined up, spooling, mid-travel and just dropped out (system_warp_*_seat).

var _out := ""
var _root: Node
var _ship: Ship
var _universe: Universe
var _stream: AsteroidStream
var _director: CameraDirector
var _system: SystemRecipe

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
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

func _shot(name: String) -> void:
	await _frames(8)
	var file := "%s/system_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s   %s" % [file, _root.star_system.whereabouts.text()])

## Puts the hull, at rest, at `at`, facing `target`, and everything outside
## ready for it, as the debug hop does.
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
	_stream.details.step()
	_stream.details.finish()
	_stream.details.step()

## Both views of where the hull is: the seat, then chase.
func _both(name: String) -> void:
	await _shot(name + "_seat")
	_director.cycle_view()
	await _frames(40)
	await _shot(name + "_chase")
	_director.cycle_view()
	await _frames(40)

func _run() -> void:
	await _frames(5)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	_stream = _root.get_node("AsteroidStream")
	_director = _ship.get_node("CameraDirector")
	_system = _root.system
	print(_system.describe())
	var avatar: Avatar = _ship.get_node("Interior/Avatar")
	var seat: PilotSeat = _ship.get_node("Interior/PilotSeat")
	seat.interact(avatar)
	await _director.transition_finished
	# 1. The start: the belt's big rock ahead; then turned to the star.
	var entry := _system.entry()
	await _both("start")
	_put(entry, _system.star.point)
	await _shot("start_to_star")
	# 2. A ringed planet, from its sunward side and a little above its ring.
	var ringed: SystemBody = null
	for p in _system.planets():
		if p.ring != null:
			ringed = p
			break
	if ringed == null:
		# No ring in this system: the biggest planet.
		for p in _system.planets():
			if ringed == null or p.radius > ringed.radius:
				ringed = p
	var sunward := _system.star.point.minus(ringed.point).normalized()
	var side := sunward.cross(Vector3.UP).normalized()
	var tilt := (ringed.ring.normal if ringed.ring != null else Vector3.UP)
	for d in [25000.0, 3000.0]:
		var dir := (sunward * 0.7 + side * 0.6 + tilt * 0.25).normalized()
		_put(ringed.point.plus(dir * (ringed.radius + d)), ringed.point)
		await _both("planet_%dkm" % roundi(d / 1000.0))
	# 3. A moon beside its planet.
	for p in _system.planets():
		var moons := _system.moons_of(p)
		if moons.is_empty():
			continue
		var m := moons[0]
		var out := m.point.minus(p.point).normalized()
		var across := out.cross(Vector3.UP).normalized()
		var sun := _system.star.point.minus(m.point).normalized()
		var eye := m.point.plus(out * 4000.0 + sun * 5000.0 + across * 1500.0)
		var mid := p.point.plus(m.point.minus(p.point) * 0.7)
		_put(eye, mid)
		await _shot("moon_seat")
		break
	# 4. The belts from above the system, looking at the star.
	var belt := _system.belts[0]
	_put(_system.star.point.plus(Vector3(0, belt.radius * 0.6, belt.radius * 1.3)), _system.star.point)
	await _shot("belts_from_above_seat")
	# 5. The star from 40 km and 8 km.
	for d in [40000.0, 8000.0]:
		_put(_system.star.point.plus(Vector3(0.3, 0.1, 1.0).normalized() * (_system.star.radius + d)), _system.star.point)
		await _shot("star_%dkm_seat" % roundi(d / 1000.0))
	# 6. Dust going past at boost: open space, then in the belt.
	var open := _system.star.point.plus(Vector3(0, 12000, belt.radius * 0.5))
	for where in [["open", open], ["belt", belt.centre.plus(Vector3(belt.radius, 0, 0))]]:
		var at: UniversePoint = where[1]
		_put(at, at.plus(Vector3(0, 0, -1000)))
		_ship.exterior.linear_velocity = -_ship.exterior.global_basis.z * 300.0
		await _frames(20)
		await _shot("dust_%s_seat" % where[0])
	# 8. A planet's debris from its warp limit, and a cluster from its limit
	# (docs/superpowers/specs/2026-09-28-warp-design.md §10.2).
	var planet := _system.planets()[0]
	_put(planet.point.plus(_system.star.point.minus(planet.point).normalized() * planet.warp_limit), planet.point)
	await _both("debris_from_limit")
	if not _system.clusters.is_empty():
		var c := _system.clusters[_system.clusters.size() - 1]
		_put(c.point.plus(Vector3.UP * c.limit * 0.3 + Vector3.BACK * c.limit * 0.95), c.point)
		await _shot("cluster_from_limit_seat")
	# 9. A warp: lined up and ready, spooling, mid-travel, and just dropped out.
	await _warp_shots()
	# 7. Every palette side by side.
	await _palettes()
	quit()

## A warp to the biggest planet it can reach, flown in along its debris disc
## from 60 km out, stepped by hand so each stage can be caught: ready, half
## spooled, mid-travel, just dropped out.
func _warp_shots() -> void:
	var drive := _ship.warp
	drive.set_physics_process(false)
	_ship.quantum.store.amount = _ship.quantum.store.capacity
	var planets := _system.planets()
	var order := range(planets.size())
	order.sort_custom(func(a: int, b: int) -> bool: return planets[a].radius > planets[b].radius)
	var ready := false
	for k: int in order:
		var t := _system.warp_target(planets[k].id)
		var normal := _system.debris[k].normal
		var flat := normal.cross(Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
		for turn in 8:
			var out := flat.rotated(normal, turn * TAU / 8.0)
			_put(t.point.plus(out * (t.limit + 60000.0)), t.point)
			drive.chart(t.id)
			if drive.check().status == WarpPlan.Status.READY:
				ready = true
				break
		if ready:
			break
	if not ready:
		print("warp    no planet reachable from above for the warp shots")
		drive.set_physics_process(true)
		return
	await _shot("warp_ready_seat")
	drive.engage()
	await _step(drive, WarpDrive.SPOOL * 0.6)
	await _shot("warp_spooling_seat")
	await _step(drive, WarpDrive.SPOOL * 0.4 + 8.0)
	await _shot("warp_travel_seat")
	await _step(drive, drive.time_left() + 0.1)
	await _frames(20)
	await _shot("warp_dropped_seat")
	drive.set_physics_process(true)

## Steps `drive` by hand for `seconds`, a frame drawn each tick.
func _step(drive: WarpDrive, seconds: float) -> void:
	var dt := 1.0 / 60.0
	for i in ceili(seconds / dt):
		drive.step(dt)
		_root.star_system.streak = drive.streak()
		await process_frame

## The eight world palettes and the star palettes, each on a proxy, in a row
## in front of the canopy, lit by the same sun.
func _palettes() -> void:
	# The star behind and above you, so every swatch is lit full on.
	var at := _system.star.point.plus(Vector3(0, 12000, 40000))
	_put(at, at.plus(Vector3(0, -300, 1000)))
	await _frames(5)
	var holder := Node3D.new()
	holder.name = "Palettes"
	_root.add_child(holder)
	var forward := -_ship.exterior.global_basis.z
	var right := _ship.exterior.global_basis.x
	var up := _ship.exterior.global_basis.y
	var centre := _ship.exterior.global_position + forward * 12000.0
	var count := SpacePalette.WORLDS.size()
	for k in count:
		var b := SystemBody.new()
		b.kind = SystemBody.Kind.PLANET
		b.seed = 7000 + k
		b.recipe = WorldRecipe.from_seed(b.seed)
		b.recipe.palette = k
		b.recipe.archetype = (k % 4) as WorldRecipe.Archetype
		b.radius = 380.0
		var m := MeshInstance3D.new()
		m.mesh = BodyLook.mesh(b, BodyLook.FAR_DETAIL)
		m.material_override = BodyLook.material(false)
		holder.add_child(m)
		m.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * b.radius),
			centre + right * (k - (count - 1) * 0.5) * 820.0 + up * 600.0)
	for k in SpacePalette.STARS.size():
		var s := SystemBody.new()
		s.kind = SystemBody.Kind.STAR
		s.seed = 9000 + k
		s.star_palette = k
		var m := MeshInstance3D.new()
		m.mesh = BodyLook.mesh(s, BodyLook.STAR_DETAIL)
		m.material_override = BodyLook.material(true)
		holder.add_child(m)
		m.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * 380.0),
			centre + right * (k - 1) * 1400.0 - up * 700.0)
	await _shot("palettes_seat")
