extends GutTest

## Every baked block mesh must be wound the way Godot draws: a triangle's front
## is the side (b - a) x (c - a) points away from. A mesh wound the other way
## renders inside-out -- the engine culls its outside and draws its inside --
## with no warning anywhere. The Task 15 bake wound every mesh it made that way
## (cockpit pod spec §6); this keeps it fixed.

const MESH_DIR := "res://data/blocks/meshes/"

func test_every_block_mesh_is_wound_for_godot():
	var checked := 0
	for file in DirAccess.get_files_at(MESH_DIR):
		if not file.ends_with(".tres"):
			continue
		var mesh: ArrayMesh = load(MESH_DIR + file)
		for s in mesh.get_surface_count():
			assert_eq(_backwards_triangles(mesh, s), 0, "%s surface %d is wound backwards" % [file, s])
			checked += 1
	assert_gt(checked, 0, "found the meshes")

static func _backwards_triangles(mesh: ArrayMesh, surface: int) -> int:
	var arrays := mesh.surface_get_arrays(surface)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		idx = arrays[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		for i in v.size():
			idx.append(i)
	var backwards := 0
	for t in range(0, idx.size(), 3):
		var a := v[idx[t]]
		var face := (v[idx[t + 1]] - a).cross(v[idx[t + 2]] - a)
		if face.length() > 1e-7 and face.dot(n[idx[t]]) > 0.0:
			backwards += 1
	return backwards
