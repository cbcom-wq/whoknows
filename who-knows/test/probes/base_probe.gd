extends SceneTree

# A base, played through in real time (docs/superpowers/specs/
# 2026-09-26-habitat-modules-design.md §5): a hub package made at the ship's
# quantum machine; carried out on a spacewalk; a green ghost and a coral one
# found on the big rock; planted, and watched unfolding; then over to its
# airlock, a full cycle in, and standing inside in gravity. Every step prints
# what it found, the key moments are rendered (eye height 1.6 m where it
# stands on something), and the frame time is measured inside the hub and
# outside it. Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 \
#     --script <abs path>/test/probes/base_probe.gd -- <abs out dir>
#
# Saving is turned off before the scene enters the tree, so the owner's game
# is never touched.

var _out := ""
var _fails := 0

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	root.add_child(scene)
	# A script error mid-run stops _run without quitting: never hang.
	create_timer(300.0).timeout.connect(func() -> void:
		print("probe   TIMED OUT")
		quit(1))
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await physics_frame

## Waits until `done` is true, at most `limit` seconds. True if it came true.
func _until(done: Callable, limit: float) -> bool:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		if done.call():
			return true
		await physics_frame
	return done.call()

func _shot(shot_name: String) -> void:
	await _frames(5)
	var file := "%s/base_%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok     " if ok else "FAILED ", what])
	if not ok:
		_fails += 1

const SIDES := [Vector2.ZERO, Vector2(15, 0), Vector2(-15, 0), Vector2(0, 15), Vector2(0, -15),
	Vector2(30, 30), Vector2(-30, 30), Vector2(30, -30), Vector2(-30, -30), Vector2(50, 0), Vector2(-50, 0)]

var _cam: Camera3D
var _reticle: CanvasItem

## A camera of the probe's own for outside views, at `from` looking at `at`.
## The reticle is the player's, at the screen's middle, where these views put
## what they look at: it is hidden while they are current.
func _look(from: Vector3, at: Vector3, up := Vector3.UP) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.far = BodyProxy.VIEW_FAR
		root.add_child(_cam)
	if _reticle != null:
		_reticle.visible = false
	var hint := up if absf((at - from).normalized().dot(up)) < 0.95 else Vector3.RIGHT
	_cam.global_transform = Transform3D(Basis.looking_at(at - from, hint), from)
	_cam.make_current()

## An eye 4 m off the rock where the line from the ship lands, `side` across.
func _eye(ship: Ship, surface: RockSurface, side: Vector2) -> Variant:
	var toward := (surface.detail.global_position - ship.exterior.global_position).normalized()
	var across := toward.cross(Vector3.UP).normalized()
	var other := toward.cross(across)
	var hit := surface.cast(ship.exterior.global_position + across * side.x + other * side.y, toward, 2000.0)
	if hit.is_empty():
		return null
	var n: Vector3 = hit["normal"]
	var hint := n.cross(Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.BACK).normalized()
	return Transform3D(Basis.looking_at(-n, hint), hit["position"] + n * 4.0)

## A view of a ghost from off to one side and above it, the rock's up as up,
## far enough out to see all of it and the ground round it.
func _look_at_ghost(eye: Transform3D, r: Planting.Result) -> void:
	var n := eye.basis.z
	_look(r.body.origin + n * 7.0 + eye.basis.x * 12.0, r.body.origin, n)

## Of the base frame's two front quarters (frame-local, horizontal, unit; the
## front is +z, where the hatch is), the one that faces the sun more.
func _sunward(scene: Node, frame: Transform3D) -> Vector3:
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var toward := frame.basis.inverse() * sun.global_basis.z
	var best := Vector3.BACK
	var best_dot := -INF
	for q in [Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		var d: float = (q as Vector3).normalized().dot(toward)
		if d > best_dot:
			best_dot = d
			best = (q as Vector3).normalized()
	return best

func _ghost_shown(outside: Node3D) -> bool:
	var ghost := outside.get_node_or_null("PackageGhost") as Node3D
	return ghost != null and ghost.visible

## Floats the suit so its head is at `eye`, looking along it: the game's own
## grasp then aims the package there every tick, and keeps its ghost shown.
func _float_at(avatar: Avatar, eye: Transform3D) -> void:
	avatar.set_head_pitch(0.0)
	avatar.global_transform = eye * Transform3D(Basis.IDENTITY, -avatar.head.position)
	avatar.velocity = Vector3.ZERO

## Mean and worst frame, ms, over `n` frames, with vsync off so the screen's
## refresh rate does not cap it.
func _frame_time(n: int, what: String) -> void:
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _frames(10)
	var worst := 0.0
	var total := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		total += ms
		worst = maxf(worst, ms)
	DisplayServer.window_set_vsync_mode(vsync)
	print("frames  %s: mean %.1f ms (%.0f fps), worst %.1f ms" % [what, total / n, 1000.0 * n / total, worst])

func _run(scene: Node) -> void:
	await _frames(3)
	# The controls card (H hides it) would cover a third of every outside view.
	_reticle = scene.get_node("Prompt/Reticle")
	var card: ControlsCard = scene.get_node("HudRoot/Screen/ControlsCard")
	card.shown = false
	card.visible = false
	var ship: Ship = scene.get_node("Ship")
	var bases: Bases = scene.get("bases")
	var outside: Node3D = scene.get_node("Outside")
	var avatar: Avatar = get_first_node_in_group(Avatar.GROUP)
	avatar.suit_cell.from_dict({"charge": 100.0})
	var stream: AsteroidStream = scene.get_node("AsteroidStream")
	var surface := RockSurface.new(stream.details.nearest(ship.exterior.global_position))

	# 1. Make a hub at the machine, with the store full.
	ship.quantum.store.credit(ship.quantum.store.room(), &"probe")
	var machine: QuantumMachine = ship.interior_builder.quantum_machines()[0]
	var cycle: MachineCycle = ship.quantum.cycles[machine.cell]
	cycle.selected = QuantumValues.makeable(ship.item_catalog).find(ship.item_catalog.get_def(&"hub_package"))
	await _frames(2)
	machine.panel.interact(avatar)
	var made := await _until(func() -> bool: return not machine.bay.is_free() \
		and machine.bay.item.definition.id == &"hub_package", 5.0)
	_check(made, "the machine makes a hub package")
	_check(ship.quantum.store.amount == 1200 - 800, "for 800 QE")
	await _shot("package_in_the_bay")

	# 2. Out on a spacewalk with it.
	var package: Item = machine.bay.item
	_check(avatar.grasp.take(package), "taken in both hands")
	var first: Variant = _eye(ship, surface, Vector2.ZERO)
	avatar.enter_suit(outside, first, Vector3.ZERO, ship.exterior)
	await _frames(10)
	_check(avatar.grasp.item == package, "still carried outside")

	# 3. A green ghost and a coral one.
	var use: PackageUse = package.use_node
	var green: Variant = null
	var coral := ""
	for side in SIDES:
		var eye: Variant = _eye(ship, surface, side)
		if eye == null:
			continue
		_float_at(avatar, eye)
		var r := use.refit(package, eye, outside)
		if r == null:
			continue
		if r.fit == Planting.Fit.OK and green == null:
			green = eye
			_look_at_ghost(eye, r)
			await _shot("ghost_green")
			_check(_ghost_shown(outside), "the green ghost stays shown while aimed")
		elif r.fit != Planting.Fit.OK and r.fit != Planting.Fit.NO_GROUND and coral == "":
			coral = Planting.prompt(r, ModuleCatalog.get_def(&"hub"))
			_look_at_ghost(eye, r)
			await _shot("ghost_coral")
			_check(_ghost_shown(outside), "the coral ghost stays shown while aimed: %s" % coral)
	_check(green != null, "somewhere on the near face takes a hub")
	print("coral   %s" % (coral if coral != "" else "(none found)"))

	# 4. Plant it, and watch it unfold.
	_float_at(avatar, green)
	await _frames(2)
	_check(avatar.grasp.use(), "planted, with use")
	await _frames(1)
	_check(not is_instance_valid(package) and avatar.grasp.item == null and avatar.grasp.mode == Grasp.Mode.EMPTY,
		"the package used up, the hands empty")
	# Halfway through the walls growing: the case has landed, the legs are down.
	await _seconds(3.0)
	var base: Base = bases.awake()[0] if not bases.awake().is_empty() else null
	_check(base != null, "a base, unfolding")
	var frame := base.exterior.global_transform
	var middle := frame * base.site.centre_of(0)
	_look(middle + frame.basis * (_sunward(scene, frame) * 10.0 + Vector3(0, 3.0, 0)), middle, frame.basis.y)
	await _shot("mid_unfold")
	var done := await _until(func() -> bool: return base.unfolding < 0, 6.0)
	_check(done, "unfolded")

	# 5. In through its airlock.
	avatar.suit_assist = false
	var lock: Airlock = base.airlocks.values()[0]
	var hull := base.exterior.global_transform
	avatar.global_position = hull * (lock.alcove.outer_frame * Vector3(0, 0.3, -8.0))
	avatar.velocity = Vector3.ZERO
	avatar.camera.make_current()
	_reticle.visible = true
	var tied := await _until(func() -> bool: return scene.get("home") == base, 2.0)
	_check(tied, "near the hub, the suit is the base's")
	lock.alcove.hull_panel.interact(avatar)
	var opened := await _until(func() -> bool: return lock.cycle.outer_open >= 1.0, 12.0)
	_check(opened, "the hub's outer hatch opens")
	var inward := (hull.basis * lock.alcove.outer_frame.basis * Vector3(0, 0, 1)).normalized()
	avatar.global_position = hull * (lock.alcove.outer_frame * Vector3(0, 0.3, -1.5))
	avatar.velocity = inward * 1.2
	var inside := await _until(func() -> bool: return avatar.mode == Avatar.Mode.PLATING, 6.0)
	_check(inside and avatar.get_parent() == base.interior, "standing in the hub's airlock")
	await _seconds(1.5)
	lock.room.room_panel.interact(avatar)
	var cycled := await _until(func() -> bool: return lock.cycle.inner_open >= 1.0, 12.0)
	_check(cycled, "the inner hatch opens on air")
	# Standing where you wake, looking across the room to its far side.
	var spots := base.wake_spots()
	var far: Transform3D = spots[0]
	for spot in spots:
		if spot.origin.distance_to(spots[0].origin) > far.origin.distance_to(spots[0].origin):
			far = spot
	var across := far.origin - spots[0].origin
	var room_up := base.interior.global_transform.basis.y
	across -= room_up * across.dot(room_up)
	avatar.place(Transform3D(Basis.looking_at(across, room_up), spots[0].origin) if across.length() > 0.1 else spots[0])
	avatar.set_head_pitch(-0.15)
	await _frames(10)
	_check(avatar.grav_strength > 0.0 and avatar.mode == Avatar.Mode.PLATING, "walking in gravity, the suit idle")
	await _shot("inside_the_hub")
	await _frame_time(300, "inside the hub")

	# 6. The hub from outside, 20 m and 2 km off, from the sunnier of its front
	# quarters, at 1.6 m above the rock.
	var up := hull.basis.y
	var centre := hull * base.site.centre_of(0)
	var near := centre + hull.basis * (_sunward(scene, hull) * 20.0)
	var ground := surface.cast(near + up * 30.0, -up, 80.0)
	if not ground.is_empty():
		near = ground["position"]
	_look(near + up * 1.6, centre, up)
	await _shot("hub_from_20_m")
	# The same, fill-lit (as ship_probe does): the sun stands high over the
	# hub, so its walls are dark, and the shape is judged under a fill.
	var fill := DirectionalLight3D.new()
	fill.light_cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	fill.light_energy = 1.4
	scene.add_child(fill)
	fill.global_basis = _cam.global_basis * Basis.from_euler(Vector3(deg_to_rad(-22), deg_to_rad(28), 0))
	await _shot("hub_from_20_m_fill_lit")
	# Closer, fill-lit: the front, at the hatch, and an end.
	for view: Array in [[Vector3(3.0, -1.0, 9.0), "hub_front_fill_lit"], [Vector3(-9.0, -2.5, -3.0), "hub_end_fill_lit"]]:
		_look(centre + hull.basis * (view[0] as Vector3), centre, up)
		fill.global_basis = _cam.global_basis * Basis.from_euler(Vector3(deg_to_rad(-22), deg_to_rad(28), 0))
		await _shot(view[1])
	fill.queue_free()
	await _frame_time(300, "outside, the hub and the rock")
	var away := (hull.basis * _sunward(scene, hull)).normalized()
	_look(centre + up * 600.0 + away * 1900.0, centre, up)
	await _shot("hub_from_2_km")
	avatar.camera.make_current()
	_reticle.visible = true

	print("probe   done, %d fails" % _fails)
	quit(_fails)
