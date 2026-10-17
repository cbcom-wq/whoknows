extends SceneTree

# The weapons in the real flight scene (docs/superpowers/specs/
# 2026-10-11-ship-weapons-design.md §10.2): the Warden in ENGAGE on a starter
# jinking sideways at 5 m/s², and the hit rate at each range; the frame rate
# with every gun firing; the heavy turret by hand at 2 km; renders. Windowed,
# so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/combat_probe.gd -- <abs out dir>
#
# Prints a `hit` line per range, `fps`, `heavy`, and a `render` line per PNG:
# combat_chase (outside the hull, bolts in flight), combat_bridge, combat_gun (the gun camera, job active, a
# listed target in view: cross, barrel ring and lead diamond), combat_gun_fire,
# combat_turret_upright and combat_turret_flipped (a light turret's barrels
# lying back at 135°, seen from the side).
#
# Pass: at least 80% at 400 m, at most 30% at 1.2 km, at least 120 fps.

const RANGES := [200.0, 400.0, 600.0, 800.0, 1000.0, 1150.0, 1200.0, 1400.0]
const JINK := 5.0
const RUN := 8.0
## How far ahead the firing line must be free of rocks, m.
const REACH := 3500.0

var _out := ""
var _gpu_ms := 0.0
var _cpu_ms := 0.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "user://combat_probe"
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()

func _scene() -> Node:
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	scene.starter_ship = "warden"
	root.add_child(scene)
	return scene

func _physics(n: int) -> void:
	for i in n:
		await physics_frame

## Turns the Warden about its up axis to a heading with no rock within REACH of
## its bow (the world's rocks are fixed, and one dead ahead would take every
## bolt), tested along five rays a couple of degrees apart. Prints the heading.
func _clear_heading(warden: Ship) -> void:
	var space := warden.exterior.get_world_3d().direct_space_state
	var exclude: Array[RID] = [warden.exterior.get_rid()]
	var from := warden.exterior.global_position
	for yaw_deg in [0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180]:
		var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
		var clear := true
		for spread: Vector2 in [Vector2.ZERO, Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
			var dir := (basis * Basis.from_euler(Vector3(deg_to_rad(spread.y), deg_to_rad(spread.x), 0)) * Vector3.FORWARD)
			var query := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, PhaserBolt.RAY_MASK, exclude)
			if not space.intersect_ray(query).is_empty():
				clear = false
				break
		if clear:
			warden.exterior.global_basis = basis
			print("heading %d deg, no rock within %.0f m" % [yaw_deg, REACH])
			return
	print("heading none clear: a rock is in the way")

## A starter `ahead` metres off the Warden's bow, flying itself no more.
func _target(scene: Node, warden: Ship, ahead: float) -> Ship:
	var place := Transform3D(warden.exterior.global_basis,
		warden.exterior.global_position - warden.exterior.global_basis.z * ahead)
	return _target_at(scene, place)

## A starter `offset` (the Warden's own axes) from the Warden.
func _target_off(scene: Node, warden: Ship, offset: Vector3) -> Ship:
	return _target_at(scene, Transform3D(warden.exterior.global_basis,
		warden.exterior.global_position + warden.exterior.global_basis * offset))

func _target_at(scene: Node, place: Transform3D) -> Ship:
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	var ship: Ship = scene.fleet.spawn(grid, place)
	ship.flight_computer.set_physics_process(false)
	return ship

static func _taken(ship: Ship) -> float:
	var sum := 0.0
	for v in ship.damage.section_damage.values():
		sum += v
	for v in ship.damage.component_damage.values():
		sum += v
	return sum

func _run() -> void:
	for range_m: float in RANGES:
		var scene := _scene()
		await _physics(10)
		var warden: Ship = scene.get_node("Ship")
		_clear_heading(warden)
		await _physics(3)
		var target := _target(scene, warden, range_m)
		await _physics(5)
		warden.quantum.store.amount = warden.quantum.store.capacity
		var shots := [0]
		for t in warden.turrets:
			# The heavy is left idle here: its 120 hp bolts would swamp the count
			# of 15 hp light ones.
			if t.kind == WeaponValues.HEAVY:
				t.set_physics_process(false)
				continue
			t.fired.connect(func(_k: StringName) -> void: shots[0] += 1)
		warden.fire_control.mark(Weapons.ship_id(target))
		warden.fire_control.set_orders(FireControl.Orders.ENGAGE)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(range_m)
		var push := Vector3.ZERO
		var next_turn := 0.0
		var t0 := _taken(target)
		var elapsed := 0.0
		while elapsed < RUN:
			await physics_frame
			var dt := 1.0 / Engine.physics_ticks_per_second
			elapsed += dt
			if elapsed >= next_turn:
				var side := target.exterior.global_basis.x if rng.randf() < 0.5 else target.exterior.global_basis.y
				push = side * (1.0 if rng.randf() < 0.5 else -1.0)
				next_turn = elapsed + rng.randf_range(1.0, 2.0)
			target.exterior.linear_velocity += push * JINK * dt
		var hits := (_taken(target) - t0) / float(WeaponValues.spec(WeaponValues.LIGHT)["damage"])
		print("hit     %4.0f m: %d bolts, %.0f hit (%.0f%%)" % [range_m, shots[0], hits,
			100.0 * hits / maxf(shots[0], 1.0)])
		scene.queue_free()
		await _physics(3)
	await _fps_and_renders()
	quit(0)

func _fps_and_renders() -> void:
	var scene := _scene()
	await _physics(10)
	var warden: Ship = scene.get_node("Ship")
	_clear_heading(warden)
	await _physics(30)
	var base := await _fps(scene, 2.0)
	print("fps     %.0f baseline, the Warden alone %s" % [base, _ms()])
	# Two targets, one up and to starboard and one down and to port, so that every
	# turret (dorsal, ventral and both flanks) has one in its half-sky.
	var target := _target_off(scene, warden, Vector3(60.0, 40.0, -350.0))
	var other := _target_off(scene, warden, Vector3(-60.0, -40.0, -350.0))
	await _physics(5)
	warden.quantum.store.amount = warden.quantum.store.capacity
	warden.fire_control.mark(Weapons.ship_id(target))
	warden.fire_control.mark(Weapons.ship_id(other))
	await _physics(30)
	var idle := await _fps(scene, 2.0)
	print("fps     %.0f guns idle, a target listed %s" % [idle, _ms()])
	var shots := [0]
	for t in warden.turrets:
		t.fired.connect(func(_k: StringName) -> void: shots[0] += 1)
	warden.fire_control.set_orders(FireControl.Orders.ENGAGE)
	await _physics(60)
	var live := [0]
	var rate := await _fps(scene, 3.0, live)
	print("fps     %.0f with every gun firing (%d shots in the run, at most %d bolts live, %s) %s" % [rate, shots[0],
		live[0], " ".join(warden.fire_control.pips()), _ms()])
	await _chase_shot(warden, scene)
	var director: CameraDirector = scene.get_node("CameraDirector")
	director.sit_now(warden.seat)
	await _physics(30)
	await _shot("combat_bridge")
	director.stand_now()
	var station: WeaponsStation = null
	for s in warden.seats():
		if s is WeaponsStation:
			station = s
	if station == null:
		print("heavy   no weapons station")
		return
	# The gun camera with the job active and a target listed in the heavy's sky:
	# the cross, the barrel's ring and the lead diamond all show.
	# The first two targets step aside, out of the line the heavy will fire along.
	for ship in [target, other]:
		ship.exterior.global_position += warden.exterior.global_basis.z * 600.0
	warden.fire_control.set_orders(FireControl.Orders.HOLD)
	warden.fire_control.clear()
	var job := station.job as WeaponsJob
	var heavy := job.heavy()
	var shown := _target_at(scene, _in_sky_of(heavy, 400.0, 25.0, 20.0))
	await _physics(5)
	warden.fire_control.mark(Weapons.ship_id(shown))
	await _physics(30)
	director.sit_now(station)
	await _physics(30)
	# The reticle off the barrels (which slew at 30°/s), so the cross, the ring
	# and the diamond are three marks.
	job.aim += Vector2(deg_to_rad(14.0), deg_to_rad(6.0))
	await _physics(3)
	print("sight   %s, size %s, %d listed, lead %s" % ["visible" if job.sight.visible else "HIDDEN",
		job.sight.size, warden.fire_control.entries.size(), "set" if job.sight.lead_point != null else "NONE"])
	await _shot("combat_gun")
	# A shot leaving the gun, seen through it.
	var s0 := WeaponAim.intercept(heavy.muzzle(), warden.exterior.linear_velocity,
		WeaponValues.spec(WeaponValues.HEAVY)["speed"], Weapons.point_of(shown.exterior), Weapons.velocity_of(shown.exterior))
	if not s0.is_empty():
		var q := (s0["dir"] as Vector3)
		var a := heavy.upright_angles(q)
		job.aim = a
		await _physics(int(4.0 * Engine.physics_ticks_per_second))
		heavy.pull_trigger()
		await _physics(8)
		await _shot("combat_gun_fire")
	# The job aims from the reticle every frame; the probe aims instead.
	job.active = false
	var far := _target(scene, warden, 2000.0)
	await _physics(5)
	var t1 := _taken(far)
	var pulled := [0]
	heavy.fired.connect(func(_k: StringName) -> void: pulled[0] += 1)
	for i in 5:
		var s := WeaponAim.intercept(heavy.muzzle(), warden.exterior.linear_velocity,
			WeaponValues.spec(WeaponValues.HEAVY)["speed"], Weapons.point_of(far.exterior), Weapons.velocity_of(far.exterior))
		if not s.is_empty():
			heavy.manual_aim = s["dir"]
		await _physics(int(3.2 * Engine.physics_ticks_per_second))
		heavy.pull_trigger()
	await _physics(int(5.0 * Engine.physics_ticks_per_second))
	print("heavy   %d bolts fired at 2 km, %.0f hit" % [pulled[0], (_taken(far) - t1) / float(WeaponValues.spec(WeaponValues.HEAVY)["damage"])])
	director.stand_now()
	await _turret_shots(warden)
	print("render  done")
	scene.queue_free()

## The ship's chase camera, swung out to the side and a little above, while the
## guns fire: the burst and its trails seen from outside the hull.
func _chase_shot(warden: Ship, scene: Node) -> void:
	var previous := root.get_viewport().get_camera_3d()
	var cam := warden.chase_camera
	var rest := cam.transform
	cam.transform = Transform3D(Basis.looking_at(Vector3(-14.0, -3.0, -52.0), Vector3.UP), Vector3(14.0, 6.0, 12.0))
	cam.current = true
	for i in 240:
		await physics_frame
		if scene.bolt_pool.live >= 6:
			break
	await _shot("combat_chase")
	cam.current = false
	cam.transform = rest
	if previous != null:
		previous.current = true

## A place `dist` m from the turret, `yaw_deg` off its forward and `elev_deg` over its face.
func _in_sky_of(t: Turret, dist: float, yaw_deg: float, elev_deg: float) -> Transform3D:
	var dir := t.global_basis * Vector3(sin(deg_to_rad(yaw_deg)) * cos(deg_to_rad(elev_deg)), sin(deg_to_rad(elev_deg)),
		-cos(deg_to_rad(yaw_deg)) * cos(deg_to_rad(elev_deg)))
	return Transform3D(t.global_basis, t.muzzle() + dir * dist)

## One Warden light turret upright and then with its barrels lying back at 135°,
## from the side, a few metres off and a little above, fill-lit.
func _turret_shots(warden: Ship) -> void:
	var turret: Turret = null
	for t in warden.turrets:
		if t.kind == WeaponValues.LIGHT and t.normal == Vector3i.UP:
			turret = t
			break
	if turret == null:
		print("render  no upward light turret")
		return
	turret.set_physics_process(false)
	var cam := Camera3D.new()
	cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	cam.far = 5000.0
	cam.fov = 60.0
	turret.add_child(cam)
	var light := DirectionalLight3D.new()
	light.light_cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	light.light_energy = 1.4
	light.shadow_enabled = false
	light.rotation_degrees = Vector3(-22, 28, 0)
	cam.add_child(light)
	var at := Vector3(6.0, 2.6, -0.5)
	var look_at := Vector3(0, WeaponValues.MUZZLE_UP, -0.2)
	cam.transform = Transform3D(Basis.looking_at(look_at - at, Vector3.UP), at)
	cam.current = true
	for pose: Array in [["upright", 20.0], ["flipped", 135.0]]:
		turret.yaw = 0.0
		turret.elevation = deg_to_rad(pose[1])
		turret._pose()
		await _shot("combat_turret_%s" % pose[0])
	cam.current = false
	cam.queue_free()

## Frames a second over `seconds`; `live` (if given) takes the most bolts live.
## `_gpu_ms` and `_cpu_ms` take the mean render times the renderer measured.
func _fps(scene: Node, seconds: float, live: Array = []) -> float:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var frames := 0
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(seconds * 1e6):
		await process_frame
		frames += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		if not live.is_empty():
			live[0] = maxi(live[0], scene.bolt_pool.live)
	RenderingServer.viewport_set_measure_render_time(vp, false)
	_gpu_ms = gpu / maxf(frames, 1.0)
	_cpu_ms = cpu / maxf(frames, 1.0)
	return frames / seconds

## "  (render: gpu x ms, cpu y ms)" for the last _fps.
func _ms() -> String:
	return "(render gpu %.1f ms, cpu %.1f ms)" % [_gpu_ms, _cpu_ms]

func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	var file := "%s/%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)
