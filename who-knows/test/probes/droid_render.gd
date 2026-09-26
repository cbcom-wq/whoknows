extends SceneTree

# The maintenance droid in the real starter at eye height (1.6 m), for the
# owner (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §17.2).
# Run it WITHOUT --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/droid_render.gd -- <abs out dir>
#
# Writes droid_corridor, droid_porthole, droid_giving_way, droid_close and
# droid_dock.png.

var _out := ""
var _ship: Ship
var _droid: Npc
var _cam: Camera3D

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.add_child(scene)
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(8)
	var file := "%s/droid_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _local(p: Vector3) -> Vector3:
	return _ship.interior.global_transform * p

func _pose_droid(cell: Vector3i, offset: Vector3, face: Vector3, action: StringName) -> void:
	var at := DeckPaths.floor_point(cell) + offset
	_droid.global_transform = _ship.interior.global_transform * Transform3D(Basis.IDENTITY, at)
	var look := face - at
	_droid.global_basis = Basis(Vector3.UP, atan2(-look.x, -look.z))
	_droid.velocity = Vector3.ZERO
	_droid.intent = Intent.idle(action)
	(_droid.look as DroidLook).act(action)

func _eye(cell: Vector3i, offset: Vector3, at: Vector3) -> void:
	var eye := DeckPaths.floor_point(cell) + offset + Vector3(0, 1.6, 0)
	_cam.global_transform = _ship.interior.global_transform * Transform3D(Basis.IDENTITY, eye)
	_cam.look_at(_local(at), Vector3.UP)

func _run(scene: Node) -> void:
	await _frames(5)
	_ship = scene.get_node("Ship")
	var avatar: Avatar = _ship.get_node("Interior/Avatar")
	_ship.npc_director.set_physics_process(false)
	_droid = _ship.npc_director.live.values()[0]
	_droid.set_physics_process(false)
	var acam: Camera3D = avatar.camera
	_cam = Camera3D.new()
	_cam.environment = acam.environment
	_cam.cull_mask = acam.cull_mask
	_cam.fov = acam.fov
	_cam.near = 0.05
	_ship.interior.add_child(_cam)
	_cam.make_current()
	avatar.place(_ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(Vector3i(-1, 0, -3))))
	# 1. In the corridor, trundling toward you.
	_pose_droid(Vector3i(0, 0, 1), Vector3.ZERO, DeckPaths.floor_point(Vector3i(0, 0, -1)), &"")
	_eye(Vector3i(0, 0, -1), Vector3(0, 0, -0.5), DeckPaths.floor_point(Vector3i(0, 0, 1)) + Vector3(0, 0.3, 0))
	await _shot("corridor")
	# 2. At a porthole, polishing.
	var spot: Dictionary = {}
	for s in _ship.crew_site.spots:
		if s["action"] == &"polish" and s["cell"].z <= 0:
			spot = s
			break
	var wall := DeckPaths.floor_point(spot["cell"]) + Vector3(spot["facing"]) * 1.0
	_pose_droid(spot["cell"], Vector3(spot["facing"]) * 0.45, wall + Vector3(0, 0.4, 0), &"polish")
	for i in 12:
		(_droid.look as DroidLook).pose(0.05, 0.0)
	var side := Vector3(spot["facing"]).cross(Vector3.UP)
	_eye(spot["cell"], -Vector3(spot["facing"]) * 0.6 + side * 0.9 - Vector3(0, 0, 0), DeckPaths.floor_point(spot["cell"]) + Vector3(spot["facing"]) * 0.5 + Vector3(0, 0.35, 0))
	print("porthole spot %s facing %s" % [spot["cell"], spot["facing"]])
	await _shot("porthole")
	# 3. Stepping aside by the galley's doorway, turned to you, cap tilted.
	_pose_droid(Vector3i(0, 0, 0), Vector3(0.6, 0, 0.3), DeckPaths.floor_point(Vector3i(0, 0, -2)), &"notice")
	for i in 20:
		(_droid.look as DroidLook).pose(0.05, 0.0)
	_eye(Vector3i(0, 0, -2), Vector3(-0.3, 0, 0.3), DeckPaths.floor_point(Vector3i(0, 0, 0)) + Vector3(0.4, 0.3, 0))
	await _shot("giving_way")
	# 3b. Close, noticing you.
	_pose_droid(Vector3i(0, 0, 0), Vector3(0.2, 0, 0.2), DeckPaths.floor_point(Vector3i(0, 0, -1)) + Vector3(-0.3, 0, 0.2), &"notice")
	for i in 20:
		(_droid.look as DroidLook).pose(0.05, 0.0)
	_eye(Vector3i(0, 0, -1), Vector3(-0.3, 0, 0.4), DeckPaths.floor_point(Vector3i(0, 0, 0)) + Vector3(0.2, 0.25, 0.2))
	await _shot("close")
	# 4. At its dock in the closet.
	_pose_droid(_ship.crew_site.dock, Vector3.ZERO, DeckPaths.floor_point(Vector3i(0, 0, 2)), &"dock")
	_eye(Vector3i(0, 0, 2), Vector3(-0.6, 0, 0), DeckPaths.floor_point(_ship.crew_site.dock) + Vector3(0, 0.3, 0))
	await _shot("dock")
	quit()
