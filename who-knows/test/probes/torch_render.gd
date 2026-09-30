extends SceneTree

# The repair torch and the knocked-out droid in the real starter, at eye
# height (1.6 m), for the owner (docs/superpowers/specs/
# 2026-09-29-health-and-damage-design.md §8, §11.2). Run it WITHOUT
# --headless so it renders:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/torch_render.gd -- <abs out dir>
#
# Writes torch_hand, torch_weld and droid_down.png.

var _out := ""
var _ship: Ship
var _avatar: Avatar

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	# Never the owner's saved game (saving spec §9).
	scene.save_enabled = false
	root.add_child(scene)
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(6)
	var file := "%s/%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _run(scene: Node) -> void:
	await _frames(5)
	_ship = scene.get_node("Ship")
	_ship.exterior.freeze = true
	_avatar = _ship.get_node("Interior/Avatar")
	var torch: Item = null
	for node in _ship.items.get_children():
		if node is Item and node.definition.id == &"repair_torch":
			torch = node
	# A hull wall: stand a metre from it, looking at it, the torch in hand.
	var layout := _ship.interior_builder.layout()
	var coord := Vector3i.ZERO
	var normal := Vector3i.ZERO
	for face in layout.faces():
		var n: Vector3i = face["normal"]
		if face["kind"] == InteriorLayout.Kind.WALL and face["owner"] and n.y == 0 \
				and layout.zone_at(face["coord"]) == &"common" \
				and _ship.grid.has_block(face["coord"] + n) and _ship.grid.get_block(face["coord"] + n).block_id == &"hull":
			coord = face["coord"]
			normal = n
			break
	var feet := DeckPaths.floor_point(coord) - Vector3(normal) * 0.1
	var facing := Basis.looking_at(Vector3(normal), Vector3.UP)
	_avatar.place(_ship.interior.global_transform * Transform3D(facing, feet))
	_avatar.set_head_pitch(-0.15)
	_avatar.grasp.take(torch)
	await _shot("torch_hand")
	_ship.take_damage(coord + normal, 150.0)
	await _frames(3)
	var use := torch.use_node as RepairTorch
	for i in 20:
		use.hold(torch, _avatar.grasp.aim(), _ship.items, _avatar, 1.0 / 60.0)
		await process_frame
	await _shot("torch_weld")
	# The droid, knocked out, seen from a couple of metres.
	var droid: Npc = _ship.npc_director.live.values()[0]
	droid.take_damage(1000.0)
	var at := droid.global_position
	var eye := at + _ship.interior.global_basis * Vector3(1.6, 1.6, 1.2)
	_avatar.grasp.let_fall(_ship.items)
	var cam := _avatar.camera
	cam.global_position = eye
	cam.look_at(at + Vector3.UP * 0.2, Vector3.UP)
	await _shot("droid_down")
	quit(0)
