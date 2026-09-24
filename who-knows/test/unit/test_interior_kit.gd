extends GutTest

var _root: Node3D
var _body: StaticBody3D
var _kit: InteriorKit

func before_each():
	_body = StaticBody3D.new()
	add_child_autofree(_body)
	_root = Node3D.new()
	_body.add_child(_root)
	_kit = InteriorKit.new(_root, _body)

func _triangles(mi: MeshInstance3D) -> Array:
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var out := []
	for i in range(0, verts.size(), 3):
		out.append({"a": verts[i], "b": verts[i + 1], "c": verts[i + 2], "n": normals[i]})
	return out

func test_bevel_box_is_26_flat_faces():
	_kit.bevel_box(InteriorKit.Batch.SOLID, Transform3D.IDENTITY, Vector3(1, 1, 1), 0.1, Color.WHITE)
	var meshes := _kit.commit()
	# 6 faces and 12 edge strips of two triangles each, and 8 corner triangles.
	assert_eq(_triangles(meshes[0]).size(), 6 * 2 + 12 * 2 + 8)

func test_every_triangle_faces_its_normal():
	# Godot's front face is clockwise seen from the front: (b-a)x(c-a) points
	# away from the viewer, i.e. against the normal.
	_kit.bevel_box(InteriorKit.Batch.SOLID, Transform3D(Basis(Vector3.UP, 0.7), Vector3(1, 2, 3)),
		Vector3(1.4, 0.6, 0.3), 0.05, Color.WHITE)
	_kit.ring(InteriorKit.Batch.SOLID, Transform3D.IDENTITY, 0.2, 0.4, -0.1, 0.1, Color.WHITE)
	_kit.tube_x(InteriorKit.Batch.SOLID, Transform3D.IDENTITY, 0.05, 1.0, Color.WHITE)
	for t in _triangles(_kit.commit()[0]):
		var facing: Vector3 = (t["b"] - t["a"]).cross(t["c"] - t["a"])
		if facing.length() > 0.000001:
			assert_lt(facing.dot(t["n"]), 0.0, "triangle wound against its normal")

func test_one_merged_mesh_per_material():
	for i in 3:
		_kit.box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(i, 0, 0)), Vector3.ONE * 0.2, Color.WHITE)
	for i in 2:
		_kit.box(InteriorKit.Batch.GLOW, InteriorKit.at(Vector3(i, 1, 0)), Vector3.ONE * 0.2, Color.WHITE)
	var meshes := _kit.commit()
	assert_eq(meshes.size(), 2, "five pieces, two materials, two meshes")
	for mi in meshes:
		assert_eq(mi.get_parent(), _root)
		assert_eq(mi.layers, InteriorKit.LAYER)
	assert_eq(meshes[0].material_override, InteriorMaterials.props())
	assert_eq(meshes[1].material_override, InteriorMaterials.glow())

func test_lights_follow_the_interior_convention():
	var l := _kit.light(Vector3(1, 2, 3), InteriorPalette.LIGHT_WARM, 0.4, 3.0, &"ceiling")
	assert_eq(l.get_parent(), _root)
	assert_eq(l.light_cull_mask, 2)
	assert_false(l.shadow_enabled)
	assert_eq(l.get_meta(&"role"), &"ceiling")
	assert_eq(l.position, Vector3(1, 2, 3))

func test_colliders_join_the_body_and_the_dressing_group():
	var c := _kit.collider(InteriorKit.at(Vector3(0, 0.5, 0.2)), Vector3(1, 1, 0.4))
	assert_eq(c.get_parent(), _body, "shapes must be direct children of the body to register")
	assert_true(c.is_in_group(InteriorKit.GROUP))
	assert_eq((c.shape as BoxShape3D).size, Vector3(1, 1, 0.4))

func test_lit_colour_carries_energy_and_blink():
	var full := InteriorKit.lit(Color.WHITE, InteriorMaterials.GLOW_ENERGY)
	assert_almost_eq(full.r, 1.0, 0.001)
	var half := InteriorKit.lit(Color.WHITE, InteriorMaterials.GLOW_ENERGY * 0.5, 0.3)
	assert_almost_eq(half.g, 0.5, 0.001)
	assert_almost_eq(half.a, 0.3, 0.001, "alpha below 1 is the blink phase")

func test_screen_quad_carries_its_mode_and_variety():
	_kit.screen(Transform3D.IDENTITY, Vector2(1, 0.5), InteriorKit.Screen.WAVE, 0.3)
	var colors: PackedColorArray = _kit.commit()[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_almost_eq(colors[0].r, 0.25, 0.01, "mode 1 of 4")
	assert_almost_eq(colors[0].g, 0.3, 0.01)

func test_portal_glass_uses_the_supplied_material():
	var portal := ShaderMaterial.new()
	var kit := InteriorKit.new(_root, _body, portal)
	kit.box(InteriorKit.Batch.PORTAL, Transform3D.IDENTITY, Vector3.ONE, Color.WHITE)
	var meshes := kit.commit()
	assert_eq(meshes.size(), 1)
	assert_eq(meshes[0].material_override, portal)

func test_portal_glass_falls_back_without_a_view():
	_kit.box(InteriorKit.Batch.PORTAL, Transform3D.IDENTITY, Vector3.ONE, Color.WHITE)
	assert_eq(_kit.commit()[0].material_override, InteriorMaterials.portal_fallback(),
		"black glass, never a hole")
