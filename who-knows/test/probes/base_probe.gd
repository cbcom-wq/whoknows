extends SceneTree

# A base, played through in real time (docs/superpowers/specs/
# 2026-09-26-habitat-modules-design.md §5): a hub package made at the ship's
# quantum machine; carried out on a spacewalk; a green ghost and a coral one
# found on the big rock; planted, and watched unfolding; then over to its
# airlock, a full cycle in, and standing inside in gravity; then a drill and a
# store planted beside it (§6.2, §6.3), your ship flown 25 km off until the
# base sleeps and back after 90 s of play to find its drill has earned, and
# the hub's link panel pressed both ways (§6.1). Every step prints
# what it found, the key moments are rendered (eye height 1.6 m where it
# stands on something), and the frame time is measured inside the hub and
# outside it, and with three modules in view. Run it WITHOUT --headless:
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
	create_timer(480.0).timeout.connect(func() -> void:
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

## Of the base frame's four quarters (frame-local, horizontal, unit), the
## one the sun shines on most: a view from there sees the lit side.
func _sunward(scene: Node, frame: Transform3D) -> Vector3:
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var toward := frame.basis.inverse() * sun.global_basis.z
	toward.y = 0.0
	var best := Vector3.BACK
	var best_dot := -INF
	for q in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		var d: float = (q as Vector3).normalized().dot(toward)
		if d > best_dot:
			best_dot = d
			best = (q as Vector3).normalized()
	return best

## Stands the avatar on its floor 1.1-1.8 m from `target`, on a side of it
## (along `room`'s axes) where it fits and nothing is between its eye and
## `target`, looking at it. False if there is no such place.
func _stand_facing(avatar: Avatar, target: Vector3, room: Basis) -> bool:
	var up := room.y.normalized()
	var space := avatar.get_world_3d().direct_space_state
	for dist in [1.4, 1.8, 1.1]:
		for d: Vector3 in [room.z, -room.z, room.x, -room.x]:
			var dir := d.normalized()
			var feet: Vector3 = target + dir * dist
			feet += up * (avatar.global_position - feet).dot(up)
			var pose := Transform3D(Basis.looking_at(-dir, up), feet)
			if not avatar.can_stand_at(pose):
				continue
			var eye: Vector3 = feet + up * 1.6
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target, 0xFFFFFFFF,
				[avatar.get_rid()]))
			if not hit.is_empty() and (hit["position"] as Vector3).distance_to(target) > 0.35:
				continue
			avatar.place(pose)
			avatar.set_head_pitch(atan2((target - eye).dot(up), dist))
			return true
	return false

## True if nothing stands between `p` and the sun (the avatar aside).
func _sunlit(scene: Node, avatar: Avatar, p: Vector3) -> bool:
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var query := PhysicsRayQueryParameters3D.create(p, p + sun.global_basis.z * 3000.0, 0xFFFFFFFF, [avatar.get_rid()])
	return avatar.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## After the ship is moved far in one go: the origin follows it at once, and
## the worlds and rocks there are ready, as the flight scene's hop() does.
func _arrive(scene: Node, u: Universe) -> void:
	u.check()
	var star_system: StarSystem = scene.get("star_system")
	star_system.place_all()
	star_system.whereabouts.look()
	(scene.get_node("AsteroidStream") as AsteroidStream).update(0.0, true)
	await _frames(5)

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
	_check(_stand_facing(avatar, machine.bay.item.global_position, ship.interior.global_basis),
		"somewhere to stand with the bay in view")
	await _frames(3)
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
		# The hub goes where it fits and the sun reaches it: under the ship's
		# shadow the plain-sun views would show only a black shape.
		if r.fit == Planting.Fit.OK and green == null and _sunlit(scene, avatar, r.body.origin):
			green = eye
			_look_at_ghost(eye, r)
			await _shot("ghost_green")
			_check(_ghost_shown(outside), "the green ghost stays shown while aimed")
		elif r.fit != Planting.Fit.OK and r.fit != Planting.Fit.NO_GROUND and coral == "":
			coral = Planting.prompt(r, ModuleCatalog.get_def(&"hub"))
			_look_at_ghost(eye, r)
			await _shot("ghost_coral")
			_check(_ghost_shown(outside), "the coral ghost stays shown while aimed: %s" % coral)
	_check(green != null, "somewhere on the near face, in the sun, takes a hub")
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

	# 7. A drill and a store beside the hub, planted as the hub was, the ghost
	# snapping to the base's grid; each unfolds before the next.
	for kind: StringName in [&"drill_package", &"store_package"]:
		var item := Item.new()
		item.setup(ship.item_catalog.get_def(kind))
		outside.add_child(item)
		var item_use: PackageUse = item.use_node
		var planted := false
		for ring in [Vector3(10, 0, 0), Vector3(-8, 0, 0), Vector3(0, 0, 10), Vector3(0, 0, -8),
				Vector3(12, 0, 6), Vector3(-10, 0, 6), Vector3(10, 0, -6), Vector3(-10, 0, -6)]:
			var over := hull * (ring as Vector3) + up * 4.0
			var aim := Transform3D(Basis.looking_at(-up, hull.basis.z), over)
			var r := item_use.refit(item, aim, outside)
			if r != null and r.fit == Planting.Fit.OK:
				planted = item_use.use(item, aim, outside, null)
				print("plant   %s at base cell %s" % [kind, r.cell])
				break
		_check(planted, "a %s planted beside the hub" % kind)
		await _frames(1)
		_check(base.unfolding >= 0, "and unfolding")
		await _until(func() -> bool: return base.unfolding < 0, 7.0)
		_check(base.unfolding < 0, "and unfolded")
	_check(base.site.modules.size() == 3, "hub, drill and store")
	_check(base.quantum.store.capacity == HabitatValues.HUB_STORE + HabitatValues.STORE_ADDS,
		"the store module adds 1,000: %d" % base.quantum.store.capacity)
	# All three in view: from the sunnier quarter, 6 m up, back far enough.
	var mid := Vector3.ZERO
	for i in base.site.modules.size():
		mid += base.site.centre_of(i)
	mid = hull * (mid / base.site.modules.size())
	var wide := mid + hull.basis * (_sunward(scene, hull) * 30.0) + up * 6.0
	_look(wide, mid, up)
	await _shot("three_modules")
	var fill3 := DirectionalLight3D.new()
	fill3.light_cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	fill3.light_energy = 1.4
	scene.add_child(fill3)
	fill3.global_basis = _cam.global_basis * Basis.from_euler(Vector3(deg_to_rad(-22), deg_to_rad(28), 0))
	await _shot("three_modules_fill_lit")
	fill3.queue_free()
	await _frame_time(300, "outside, three modules")

	# 8. Away until it sleeps, back after 90 s of play, and it has earned. Your
	# ship goes, with you aboard it; where it was is kept as a universe point,
	# since the origin follows it.
	var site := base.site
	var before := base.quantum.store.amount
	var played := float(scene.get("play_time"))
	avatar.move_aboard(ship.interior, ship.wake_spots()[0])
	scene.call("board", ship, true)
	await _frames(2)
	var u: Universe = scene.get_node("Universe")
	var ship_at := u.to_universe(ship.exterior.global_position)
	var off := (ship.exterior.global_position - hull.origin).normalized()
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.exterior.global_position += off * 25000.0
	await _arrive(scene, u)
	var focus_off := u.to_universe(ship.exterior.global_position).minus(site.at).length()
	_check(focus_off > HabitatValues.SLEEP_AT and ship.exterior.global_position.length() < Universe.FORCE_AT,
		"25 km off (%.0f m), the origin with the ship" % focus_off)
	bases.check_sleep()
	# Freed at the end of the frame.
	await _frames(2)
	_check(bases.named(site.id) == null and not is_instance_valid(base), "25 km off, the base sleeps")
	await _seconds(90.0)
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.global_position = u.to_engine(ship_at)
	await _arrive(scene, u)
	bases.check_sleep()
	var back := bases.named(site.id)
	_check(back != null, "back within 18 km, it wakes")
	print("store   %d before, %d after %.0f s of play" % [before, back.quantum.store.amount if back != null else -1,
		float(scene.get("play_time")) - played])
	_check(back != null and back.quantum.store.amount > before, "and its drill earned while it slept")
	await _frames(5)
	_check(back != null and back.exterior.global_transform.origin.distance_to(bases.frame_of(site).origin) < 0.01,
		"it wakes where it stood")

	# 9. The link: inside the hub, 50 QE each way with its two buttons.
	avatar.move_aboard(back.interior, back.wake_spots()[0])
	scene.call("board_base", back, true)
	avatar.camera.make_current()
	await _frames(5)
	_check(QuantumLink.in_reach(back.exterior.global_position, ship.exterior.global_position),
		"your ship within the link's reach")
	for press: Array in [[&"to_base", "to the base"], [&"to_ship", "to the ship"]]:
		var button := back.link.get_node("Panel_%s" % press[0]) as ReadoutPanel
		_check(_stand_facing(avatar, button.global_position, back.link.global_basis),
			"somewhere to stand facing the %s button" % press[0])
		await _frames(4)
		_check(avatar.interactor.current() == button, "aimed, the %s button is the one offered: %s"
			% [press[0], button.prompt_text()])
		var ship_was := ship.quantum.store.amount
		var base_was := back.quantum.store.amount
		if avatar.interactor.current() != null:
			avatar.interactor.current().interact(avatar)
		var to_ship: bool = press[0] == &"to_ship"
		var moved: int = ship.quantum.store.amount - ship_was if to_ship else back.quantum.store.amount - base_was
		_check(moved == HabitatValues.LINK_STEP and ship.quantum.store.amount + back.quantum.store.amount \
			== ship_was + base_was, "the link moves %d QE %s, none lost" % [HabitatValues.LINK_STEP, press[1]])
	# The panel at eye height, as you come up to it.
	_check(_stand_facing(avatar, back.link.global_transform * Vector3(0, LinkPanel.PEDESTAL.y + 0.1, 0),
		back.link.global_basis), "somewhere to stand facing the link panel")
	await _frames(5)
	print("screen  %s" % " / ".join(back.link.lines()))
	await _shot("link_panel")
	avatar.move_aboard(ship.interior, ship.wake_spots()[0])
	scene.call("board", ship, true)
	await _frames(2)
	_check(scene.get("home") == ship, "and back aboard your ship")

	print("probe   done, %d fails" % _fails)
	quit(_fails)
