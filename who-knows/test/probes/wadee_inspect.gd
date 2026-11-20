extends SceneTree

## Prints what a Wadee model holds once imported: its nodes, meshes and surfaces,
## its clips, and its skeleton's bones with their rest heights.
##   godot --headless --path . --script res://test/probes/wadee_inspect.gd -- a

func _init() -> void:
	var tag := "a"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		tag = args[0]
	var scene: PackedScene = load("res://assets/wadee/wadee_%s.glb" % tag)
	var root := scene.instantiate()
	_walk(root, 0)
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		var names := player.get_animation_list()
		print("clips %d: %s" % [names.size(), ", ".join(names)])
		for n in names:
			var a := player.get_animation(n)
			print("  %-22s %.2f s loop %d" % [n, a.length, a.loop_mode])
	var skel := root.find_child("*", true, false)
	for n in root.find_children("*", "Skeleton3D", true, false):
		var s := n as Skeleton3D
		for b in s.get_bone_count():
			var rest := s.get_bone_global_rest(b)
			print("  bone %-14s y %.3f  x %.3f z %.3f" % [s.get_bone_name(b), rest.origin.y, rest.origin.x, rest.origin.z])
	var staff: PackedScene = load("res://assets/wadee/sunstaff.glb")
	_walk(staff.instantiate(), 0)
	root.free()
	quit()

func _walk(n: Node, depth: int) -> void:
	var extra := ""
	if n is MeshInstance3D:
		var m := (n as MeshInstance3D).mesh
		extra = " surfaces %d" % m.get_surface_count()
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			extra += " [%s]" % (mat.resource_name if mat != null else "none")
		extra += " aabb %s" % m.get_aabb()
	print("%s%s (%s)%s" % ["  ".repeat(depth), n.name, n.get_class(), extra])
	for c in n.get_children():
		_walk(c, depth + 1)
