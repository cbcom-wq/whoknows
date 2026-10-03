extends SceneTree

# The computer mode in the real starter, for the owner
# (docs/superpowers/specs/2026-09-30-computer-mode-design.md §8.2). Run it
# WITHOUT --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/computer_mode_render.gd -- <abs out dir>
#
# Writes mode_5km.png, mode_500km.png, mode_system.png, mode_world.png (the
# system with the nearest planet selected and the cursor's tag on it),
# mode_status.png and mode_orbit.png (the eye raised and the holo spun), and
# prints the worst frame's holo update while zooming from 1 km to 9,000 km and
# back, where it was drawn, and the sweep's mean.

var _out := ""

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	# The starter, never the owner's saved ship (and never their save).
	scene.save_enabled = false
	root.add_child(scene)
	# A script error mid-run stops _run without quitting: never hang.
	create_timer(120.0).timeout.connect(func() -> void:
		print("probe   TIMED OUT")
		quit(1))
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(shot_name: String) -> void:
	await _frames(12)
	var file := "%s/mode_%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

## The planet nearest the ship among the map's targets, or null.
func _nearest_planet(map: MapPage, ctx: ComputerContext) -> Contact:
	var best: Contact = null
	for c in map.targets(ctx):
		if c.kind != &"body" or c.id == &"body:star":
			continue
		if best == null or ctx.relative(c.point).length() < ctx.relative(best.point).length():
			best = c
	return best

func _run(scene: Node) -> void:
	await _frames(5)
	var ship: Ship = scene.get_node("Ship")
	ship.npc_director.set_physics_process(false)
	for npc in ship.npc_director.live.values():
		(npc as Node3D).visible = false
	var computer: ShipComputer = ship.interior_builder.computers()[0]
	var avatar: Avatar = ship.get_node("Interior/Avatar")
	avatar.place(ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(Vector3i(-1, 0, -2))))
	await _frames(5)
	computer.station.interact(avatar)
	await _frames(60)
	var map := computer.pages[0] as MapPage
	for pair in [[5000.0, "5km"], [500000.0, "500km"], [9000000.0, "system"]]:
		map.restore({"scale": pair[0], "selected": String(map.selected)})
		await _shot(pair[1])
	# The overlay up close: the system still, a planet selected, its card, and
	# the tag beside the cursor over its mark.
	var cluster := map.selected
	var planet := _nearest_planet(map, computer.ctx)
	if planet != null:
		computer.select(planet.id)
		await _frames(12)
		for m: Dictionary in map.placed_marks:
			if m["id"] == planet.id:
				var cam := root.get_viewport().get_camera_3d()
				root.get_viewport().warp_mouse(cam.unproject_position(computer.holo.marks_to_global(m["position"])))
		await _frames(2)
		computer.hovered = planet.id
		await _shot("world")
		computer.hovered = &""
		computer.select(cluster)
	computer.station.orbit(30.0)
	computer.spin = 0.8
	await _shot("orbit")
	computer.station.recentre()
	computer.tab(1)
	await _shot("status")
	computer.tab(0)
	map.restore({"scale": 1000.0})
	# The computer's own _process would update the holo a second time each
	# frame, untimed, and could take the placings this loop is here to time.
	computer.set_process(false)
	var worst := 0.0
	var worst_at := 0.0
	var total := 0.0
	for i in 80:
		computer.zoom(1.0 if i < 40 else -1.0)
		var t := Time.get_ticks_usec()
		computer.update(1.0 / 60.0)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		total += ms
		if ms > worst:
			worst = ms
			worst_at = map.shown_m()
		await process_frame
	print("zoom    worst holo update %.2f ms over a 1 km - 9,000 km sweep" % worst)
	print("        at %d km drawn; mean %.2f ms a frame over the sweep's 80" % [roundi(worst_at / 1000.0), total / 80.0])
	quit()
