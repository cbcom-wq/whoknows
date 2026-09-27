extends SceneTree

# The bridge computer in the real starter at eye height (1.6 m), for the owner
# (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §12.2). Run it
# WITHOUT --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/computer_render.gd -- <abs out dir>
#
# Writes computer_bridge.png (the bridge from the corridor, the table on the
# left and the machine on the right) and computer_table.png (the table from
# where you use it).

var _out := ""
var _ship: Ship
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
	var file := "%s/computer_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _local(p: Vector3) -> Vector3:
	return _ship.interior.global_transform * p

func _eye(cell: Vector3i, offset: Vector3, at: Vector3) -> void:
	var eye := DeckPaths.floor_point(cell) + offset + Vector3(0, 1.6, 0)
	_cam.global_transform = _ship.interior.global_transform * Transform3D(Basis.IDENTITY, eye)
	_cam.look_at(_local(at), Vector3.UP)

func _run(scene: Node) -> void:
	await _frames(5)
	_ship = scene.get_node("Ship")
	var avatar: Avatar = _ship.get_node("Interior/Avatar")
	# Out of the way, in the bunk room.
	avatar.place(_ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(Vector3i(-1, 0, 1))))
	_ship.npc_director.set_physics_process(false)
	for npc in _ship.npc_director.live.values():
		(npc as Node3D).visible = false
	var acam: Camera3D = avatar.camera
	_cam = Camera3D.new()
	_cam.environment = acam.environment
	_cam.cull_mask = acam.cull_mask
	_cam.fov = acam.fov
	_cam.near = 0.05
	_ship.interior.add_child(_cam)
	_cam.make_current()
	# 1. The bridge from the corridor's mouth: the table on the left, the
	# machine on the right.
	_eye(Vector3i(0, 0, 0), Vector3(0, 0, -0.85), DeckPaths.floor_point(Vector3i(0, 0, -2)) + Vector3(0, 0.9, 0))
	await _shot("bridge")
	# 2. The table from where you use it.
	var table := DeckPaths.floor_point(Vector3i(-1, 0, -1))
	_eye(Vector3i(0, 0, -1), Vector3(-0.1, 0, 0), table + Vector3(0, 1.1, 0))
	await _shot("table")
	quit()
