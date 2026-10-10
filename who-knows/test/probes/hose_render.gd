extends SceneTree

# The hose in the real starter, for the owner: the reel on the hull, the
# nozzle in hand, the line paid out, and a salvage chunk going in. Run it
# WITHOUT --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/hose_render.gd -- <abs out dir>
#
# Writes hose_reel.png, hose_out.png, hose_draw.png and hose_toast.png, and
# prints the frame time with the hose drawing: every frame from the chunk
# starting its way in to the swallow (the frames that save a PNG are not
# counted, and vsync is off so the screen's refresh does not cap it).
#
# The hull is moved 300 m from the Outside origin first, where the line's node
# sits: a line culled by a bounding box about that node would be missing from
# these renders, and the headless tests cannot see a culled mesh (quantum
# energy spec §11.3; the plan's Controller Ruling 12).
#
# A windowed run would save and load the owner's real game (saving spec §9), so
# the probe turns saving off before the scene enters the tree.

## The longest the chunk may take to go in, seconds: past it the run reports
## that it did not and stops.
const DRAW_LIMIT := 10.0

var _out := ""
## The toast line the avatar last sent (a lambda captures a local by value, so
## it is set through a member).
var _said := ""

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	# Vsync would cap the frame rate at the monitor's; measure the real one.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	root.add_child(scene)
	# A script error mid-run stops _run without quitting: never hang.
	create_timer(90.0).timeout.connect(func() -> void:
		print("hose    TIMED OUT")
		quit(1))
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(shot_name: String) -> void:
	await _frames(6)
	var file := "%s/%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _run(scene: Node) -> void:
	await _frames(5)
	# The controls card would cover a third of every outside view.
	var card: ControlsCard = scene.get_node("HudRoot/Screen/ControlsCard")
	card.shown = false
	card.visible = false
	var ship: Ship = scene.get_node("Ship")
	var avatar: Avatar = ship.get_node("Interior/Avatar")
	var outside: Node3D = scene.get_node("Outside")
	var airlock: Airlock = ship.airlocks.values()[0]
	var reel: HoseReel = airlock.alcove.reel
	print("hose    renderer %s (Vulkan %s)" % [
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	ship.exterior.freeze = true
	# Ruling 12: the hull a long way from the Outside origin, where the
	# line's node sits, so a culled line (a custom bounding box about that
	# node) would show here and in the headless tests could not.
	ship.exterior.global_position += Vector3(300, 0, 0)
	# A hatch frame's +z points INTO its room: outside is -z (Airlock.home()
	# uses -HOME_OUT).
	var hatch := airlock.alcove.outer_hatch.global_transform
	var out := -hatch.basis.z
	# The suit's cell starts empty, and a dry suit lets the nozzle go on the
	# next tick.
	avatar.suit_cell.charge = SuitCell.CAPACITY
	# On a spacewalk, 3 m off the hatch, looking at the reel.
	avatar.enter_suit(outside, Transform3D(Basis.looking_at(-out, Vector3.UP), hatch.origin + out * 3.0),
		Vector3.ZERO, ship.exterior)
	await _frames(3)
	avatar.camera.global_position = reel.global_position + out * 2.0 + Vector3.UP * 0.3
	avatar.camera.look_at(reel.global_position, Vector3.UP)
	await _shot("hose_reel")
	# Taken (Hands' grab swipe takes 0.3 s), and paid out along the hull.
	var nozzle := reel.item
	avatar.grasp.take(nozzle)
	await _frames(30)
	avatar.global_position = reel.anchor() + out * 9.0 + hatch.basis.x * 0.8 + Vector3.UP * 0.2
	await _frames(20)
	avatar.camera.global_position = reel.anchor() + out * 5.0 + hatch.basis.x * 3.0 + Vector3.UP * 1.0
	avatar.camera.look_at(reel.anchor() + out * 6.0 + hatch.basis.x * 0.4, Vector3.UP)
	await _shot("hose_out")
	# A chunk of salvage in the cone, on its way in.
	var def := ship.item_catalog.get_def(&"rock_chunk")
	var chunk := Item.new()
	chunk.setup(def)
	chunk.set_space(true)
	outside.add_child(chunk)
	chunk.global_position = nozzle.global_transform * nozzle.definition.use_point + (-nozzle.global_basis.z) * 3.5
	# The trigger, held on every physics tick as the player's finger holds it:
	# this runs far faster than 60 frames a second, and a pull applied once per
	# rendered frame would be a different force.
	var pull := func() -> void:
		avatar.grasp.hold_now(1.0 / 60.0, true)
	physics_frame.connect(pull)
	avatar.toast.connect(func(line: String) -> void: _said = line)
	var started := Time.get_ticks_msec()
	var frames := 0
	var total := 0.0
	var worst := 0.0
	var shown_draw := false
	var last := Time.get_ticks_usec()
	while _said == "" and Time.get_ticks_msec() - started < int(DRAW_LIMIT * 1000.0):
		await process_frame
		var ms := (Time.get_ticks_usec() - last) / 1000.0
		frames += 1
		total += ms
		worst = maxf(worst, ms)
		# Partway to the mouth, so the owner sees the chunk coming in.
		if not shown_draw and is_instance_valid(chunk):
			var mouth := nozzle.global_transform * nozzle.definition.use_point
			if chunk.global_position.distance_to(mouth) < 1.6:
				shown_draw = true
				await _shot("hose_draw")
		last = Time.get_ticks_usec()
	if _said == "":
		print("hose    FAILED: the chunk was not swallowed in %.0f s" % DRAW_LIMIT)
		physics_frame.disconnect(pull)
		quit(1)
		return
	# The toast is up: the owner sees it at eye height (it lives 1.2 s).
	await _shot("hose_toast")
	print("toast   %s" % _said)
	print("frame time with the hose drawing: %.2f ms average, %.2f ms worst, over %d frames (%.0f fps)" % [
		total / frames, worst, frames, 1000.0 * frames / total])
	physics_frame.disconnect(pull)
	quit(0)
