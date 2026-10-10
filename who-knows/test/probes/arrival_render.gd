extends SceneTree

# A ship arriving out of warp, for the owner's eyes (docs/superpowers/specs/
# 2026-10-02-ship-library-design.md §6, §7.2): from the starter's seat and
# from the chase view, 0.2, 0.6 and 1.0 s into an arrival and after it; the
# spawn panel open in the cockpit; and the frame rate in the worst view (seated
# by a big rock's night side, both light groups on) with and without a ship
# arriving. Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 \
#     --script <abs path>/test/probes/arrival_render.gd -- <abs out dir>
#
# Saving is off before the scene enters the tree, so the owner's game is never
# touched.

var _out := ""

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	root.add_child(scene)
	# A script error mid-run stops _run without quitting: never hang.
	create_timer(120.0).timeout.connect(func() -> void:
		print("arrival TIMED OUT")
		quit(1))
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## The next frame drawn, with no more waited: an arrival does not wait. Read
## without waiting for a draw, the viewport hands back a stale frame.
func _grab(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var file := "%s/arrival_%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _fps(seconds: float) -> float:
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < seconds * 1e6:
		await process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - start) / 1e6)

func _press(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
	await _frames(2)

## One arrival seen from wherever the view is now (or, `side_on`, from a camera
## 150 m to the side of its last 200 m): shots 0.2, 0.6 and 1.0 s in and a
## second after it stops; then it is removed again.
func _watch(scene: Node, tag: String, side_on := false) -> void:
	var fleet: Fleet = scene.get("fleet")
	var start := Time.get_ticks_msec()
	var said: String = scene.call("spawn_from_library", ShipLibrary.STARTER)
	print("arrival %s: %s" % [tag, said])
	if not said.begins_with("SPAWNED"):
		return
	var ship: Ship = fleet.ships()[fleet.ships().size() - 1]
	var cam: Camera3D = null
	if side_on:
		var a := WarpArrival.of(ship.exterior)
		var up := a.at.basis.y
		var across := a.along.cross(up).normalized()
		var middle := a.at.origin - a.along * 100.0
		cam = Camera3D.new()
		cam.far = 5000.0
		scene.get_node("Outside").add_child(cam)
		cam.global_transform = Transform3D(Basis.looking_at(-across, up), middle + across * 150.0 + up * 10.0)
		cam.current = true
	# On the arrival's own clock: building the ship costs a hitch first.
	var arrival := WarpArrival.of(ship.exterior)
	for t: float in [0.2, 0.6, 1.0]:
		while is_instance_valid(arrival) and arrival.elapsed < t:
			await process_frame
		await _grab("%s_%.1f" % [tag, t])
	while fleet.arriving(ship):
		await process_frame
	await _frames(10)
	await _grab("%s_flash" % tag)
	await _frames(60)
	await _grab("%s_after" % tag)
	print("arrival %s: %.2f s from the key to its stop" % [tag, (Time.get_ticks_msec() - start) / 1000.0])
	var starter: Ship = scene.get_node("Ship")
	print("arrival %s: at rest %.2f m/s, %.0f m from the starter" % [tag, ship.exterior.linear_velocity.length(),
		ship.exterior.global_position.distance_to(starter.exterior.global_position)])
	print("arrival %s: %s" % [tag, scene.call("remove_nearest_spawned")])
	if cam != null:
		cam.queue_free()
	await _frames(5)

## Nose on to a big rock's night side, `gap` off its surface, as ship_probe.gd
## parks for its worst view. False with no big rock in sensor range.
func _park_by_a_rock(scene: Node, ship: Ship, gap: float) -> bool:
	var universe: Universe = scene.get_node("Universe")
	var best: Contact = null
	for c in ship.sensors.contacts(RockContacts.RANGE):
		if c.kind == RockContacts.KIND:
			best = c
			break
	if best == null:
		return false
	var light_goes := -(scene.get_node("DirectionalLight3D") as DirectionalLight3D).global_basis.z
	var rock := universe.to_engine(best.point)
	var at := rock + light_goes * (best.radius + gap)
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.exterior.global_transform = Transform3D(Basis.looking_at(rock - at, Vector3.UP), at)
	await _frames(90)
	await physics_frame
	var space := ship.exterior.get_world_3d().direct_space_state
	var from := rock + light_goes * (best.radius * 1.5 + 200.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, rock, AsteroidBody.LAYER))
	var surface := best.radius if hit.is_empty() else (hit["position"] as Vector3).distance_to(rock)
	at = rock + light_goes * (surface + gap)
	var dir := (rock - at).normalized()
	ship.exterior.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT), at)
	await _frames(30)
	return true

func _run(scene: Node) -> void:
	await _frames(3)
	var starter: Ship = scene.get_node("Ship")
	var director: CameraDirector = scene.get_node("CameraDirector")
	director.sit_now(starter.seat)
	await _frames(30)
	await _press(KEY_F6)
	await _frames(5)
	await _grab("panel")
	await _press(KEY_F6)
	await _watch(scene, "seat")
	director.cycle_view()
	await _frames(30)
	await _watch(scene, "chase")
	director.cycle_view()
	await _frames(10)
	starter.lights.set_group(ShipLights.FLOOD, true)
	starter.lights.set_group(ShipLights.FORWARD, true)
	if await _park_by_a_rock(scene, starter, 60.0):
		print("fps     %.0f seated by a rock, both groups on" % await _fps(2.0))
		# 60 m off a big rock nothing is clear to arrive in (300 m): 150 m off,
		# the spot behind you is.
		await _park_by_a_rock(scene, starter, 150.0)
		print("fps     %.0f the same, 150 m off it" % await _fps(2.0))
		var said: String = scene.call("spawn_from_library", ShipLibrary.STARTER)
		print("fps     %.0f the same, a ship arriving (%s)" % [await _fps(1.4), said])
	else:
		print("fps     no big rock in range")
	# Last, as it leaves its own camera current: from the side, to judge the
	# wake and the flash themselves.
	await _frames(120)
	scene.call("remove_nearest_spawned")
	await _watch(scene, "side", true)
	quit(0)
