extends SceneTree

# Real-scene check of a ship: what the grid validates and flies like, what the
# interior made of it, whether you can sit, stand up and walk away, and what
# it looks like at eye height -- with the frame rate. Run it WITHOUT
# --headless so it renders (and shaders compile):
#
#   godot --path who-knows --resolution 1280x720 \
#     --script <abs path>/ship_probe.gd -- <abs out dir> [scene path]
#
# The scene defaults to res://scenes/flight_test.tscn. It must hold a Ship at
# Ship, with Interior/Avatar, Interior/PilotSeat and CameraDirector, as that
# scene does. Writes <out>/probe_spawn.png, probe_seated.png and
# probe_stood.png.

var _out := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	# Vsync would cap the frame rate at the monitor's; measure the real one.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var path := args[1] if args.size() > 1 else "res://scenes/flight_test.tscn"
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	_run.call_deferred(scene)

func _process_frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _process_frames(5)
	var file := "%s/probe_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _fps(seconds: float) -> float:
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < seconds * 1e6:
		await process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - start) / 1e6)

func _run(scene: Node) -> void:
	# A process frame or two first: the canopy camera is placed on the first.
	await _process_frames(3)
	var ship: Ship = scene.get_node("Ship")
	var avatar: Avatar = ship.get_node("Interior/Avatar")
	var seat: PilotSeat = ship.get_node("Interior/PilotSeat")
	var director: CameraDirector = ship.get_node("CameraDirector")

	var issues := ShipValidator.validate(ship.grid, ship.catalog)
	for issue in issues:
		print("ISSUE   %s %s" % [issue.code, issue.message])
	print("grid    %d blocks, %d issues, can launch %s" % [ship.grid.coords().size(), issues.size(),
		ShipValidator.can_launch(issues)])
	var s := ShipStats.compute(ship.grid, ship.catalog)
	print("mass    %.1f t, centre of mass %s" % [s.total_mass_kg / 1000.0, s.center_of_mass])
	print("power   %.1f MW made, %.1f MW drawn" % [s.power_gen, s.power_draw])
	print("thrust  kN fwd %.0f rev %.0f lat %.0f vert %.0f" % [s.thrust_budget[&"forward"] / 1000.0,
		s.thrust_budget[&"reverse"] / 1000.0, s.thrust_budget[&"lateral"] / 1000.0,
		s.thrust_budget[&"vertical"] / 1000.0])
	print("torque  authority %s, imbalance under burn %s" % [s.torque_budget, s.torque_imbalance])
	# The feel: assist is the same for every ship, so these decide how it flies.
	var kg := maxf(s.total_mass_kg, 1.0)
	var side: float = s.thrust_budget[&"lateral"] / kg
	print("feel    turn accel rad/s2 pitch %.2f yaw %.2f roll %.2f" % [
		s.torque_budget.x / maxf(s.inertia.x, 1.0), s.torque_budget.y / maxf(s.inertia.y, 1.0),
		s.torque_budget.z / maxf(s.inertia.z, 1.0)])
	print("feel    m/s2 side %.1f vert %.1f brake %.1f fwd %.1f; 100 m/s sideways gone in %.0f s" % [
		side, s.thrust_budget[&"vertical"] / kg, s.thrust_budget[&"reverse"] / kg,
		s.thrust_budget[&"forward"] / kg, 100.0 / maxf(side, 0.001)])
	# An rcs block whose exhaust face touches another block puffs inside it.
	var blocked := []
	var rcs := RcsShow.gather(ship.grid, ship.catalog, s.center_of_mass)
	for b in rcs:
		var push: Vector3 = (b["force"] as Vector3).normalized().round()
		if ship.grid.has_block(b["coord"] - Vector3i(push)):
			blocked.append(b["coord"])
	print("rcs     %d blocks%s" % [rcs.size(),
		"" if blocked.is_empty() else ", exhaust BLOCKED at %s" % [blocked]])

	var layout := ship.interior_builder.layout()
	for room in layout.rooms():
		print("room    %s %s doorway %s" % [room["zone"], room["coords"], room["doorway"]])
	print("pods    %s" % [layout.pods()])
	print("locks   %s" % [layout.airlocks()])

	await _shot("spawn")
	print("fps     %.0f standing at spawn" % await _fps(2.0))

	seat.interact(avatar)
	await director.transition_finished
	await _shot("seated")
	print("fps     %.0f seated" % await _fps(2.0))

	director.stand()
	await director.transition_finished
	var at := seat.global_transform.affine_inverse() * avatar.global_position
	print("stood   seat-local %s (stand spots %s)" % [at, PilotSeat.STAND_SPOTS])
	await _shot("stood")
	var from := avatar.global_position
	Input.action_press("move_back")
	for i in 60:
		await physics_frame
	Input.action_release("move_back")
	var walked := from.distance_to(avatar.global_position)
	print("walked  %.2f m in 1 s after standing%s" % [walked, "" if walked > 1.0 else "  <-- STUCK"])
	quit()
