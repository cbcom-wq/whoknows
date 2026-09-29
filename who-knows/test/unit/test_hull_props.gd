extends GutTest

## Ship exterior spec §3.3: the skin's pieces build from a kit and a frame
## alone, wound so they face out.

var _root: Node3D
var _kit: InteriorKit

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_kit = InteriorKit.new(_root)

## Godot's front face is clockwise seen from the front, so each triangle's
## winding normal must point away from the normal it carries (InteriorKit.tri).
func _faces_out(mesh: Mesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0, v.size(), 3):
		if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i]) > 0.0001:
			return false
	return true

func _triangles(mesh: Mesh) -> int:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3

func _commit() -> Dictionary:
	var out := {}
	for mi in _kit.commit():
		out[String(mi.name)] = mi.mesh
		assert_true(_faces_out(mi.mesh), "%s faces out" % mi.name)
		# Freed at once, so a second commit in one test keeps the batches' names.
		mi.get_parent().remove_child(mi)
		mi.free()
	return out

func test_a_plate_is_a_seam_and_a_proud_panel():
	HullProps.plate(_kit, Transform3D.IDENTITY, Vector2(1.2, 1.2))
	var made := _commit()
	assert_true(made.has("DressingSolid"), "the seam colour behind")
	assert_true(made.has("DressingHull"), "the livery panel in front")
	var aabb: AABB = made["DressingHull"].get_aabb()
	assert_almost_eq(aabb.end.z, HullProps.PLATE_PROUD, 0.0001, "it stands proud by PLATE_PROUD")
	assert_almost_eq(aabb.size.x, 1.2 - HullProps.PLATE_GAP, 0.0001, "the gap between plates is the panel line")

func test_a_chamfer_is_one_quad_and_a_triangle_per_cap():
	HullProps.chamfer_strip(_kit, Transform3D.IDENTITY, -1.0, 0.6, true, false)
	assert_eq(_triangles(_commit()["DressingHull"]), 3)

func test_a_corner_is_one_triangle_facing_out_of_the_corner():
	HullProps.corner_facet(_kit, Transform3D.IDENTITY)
	var mesh: Mesh = _commit()["DressingHull"]
	assert_eq(_triangles(mesh), 1)
	var n: Vector3 = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
	assert_almost_eq(n, Vector3.ONE.normalized(), Vector3.ONE * 0.0001)

func test_a_facet_on_a_quad_gets_a_proud_panel_and_on_a_triangle_lies_flat():
	var quad := PackedVector3Array([Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)])
	HullProps.facet(_kit, Transform3D.IDENTITY, quad, Vector3(0, 1, -1).normalized())
	var made := _commit()
	assert_eq(_triangles(made["DressingSolid"]), 2, "the seam under it")
	assert_eq(_triangles(made["DressingHull"]), 10, "the panel and its four sides")
	var tri := PackedVector3Array([Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1)])
	HullProps.facet(_kit, Transform3D.IDENTITY, tri, Vector3.RIGHT)
	assert_eq(_triangles(_commit()["DressingHull"]), 1)

func test_bells_pods_and_strips_build_in_a_bare_frame():
	HullProps.thruster_bell(_kit, Transform3D.IDENTITY)
	HullProps.rcs_pod(_kit, InteriorKit.at(Vector3(3, 0, 0)))
	HullProps.running_strip(_kit, InteriorKit.at(Vector3(6, 0, 0)), -1.0, 1.0)
	var made := _commit()
	assert_true(made.has("DressingSolid"))
	assert_true(made.has("DressingGlow"), "the bell's ring and the strip glow")

func test_the_materials_are_engine_materials():
	assert_true(HullMaterials.trim() is StandardMaterial3D)
	assert_true(HullMaterials.window_glass() is StandardMaterial3D)
	assert_eq(HullMaterials.livery(), Ship.HULL_LIVERY_MATERIAL, "the livery the hull always had")
	var a := HullMaterials.glow_instance(1.0)
	var b := HullMaterials.glow_instance(1.0)
	assert_ne(a, b, "each glow instance dims on its own")
	assert_eq(a.shader, InteriorMaterials.GLOW_SHADER, "the glow shader, not a new one")
	var beam := HullMaterials.beam(HullPalette.WORK_LIGHT)
	assert_eq(beam.blend_mode, BaseMaterial3D.BLEND_MODE_ADD)
	assert_true(beam.proximity_fade_enabled)

func test_windows_and_the_pod_shell_build_and_face_out():
	HullProps.window_porthole(_kit, Transform3D.IDENTITY, 0.26)
	HullProps.window_rect(_kit, InteriorKit.at(Vector3(3, 0, 0)), Vector2(1.1, 1.13))
	HullProps.pod_shell(_kit, InteriorKit.at(Vector3(8, 0, 0)))
	var made := _commit()
	assert_true(made.has("DressingGlass"), "the glass")
	assert_true(made.has("DressingGlow"), "the warm bands behind it")
	assert_true(made.has("DressingHull"), "the pod's plating")
	var shell: AABB = made["DressingHull"].get_aabb()
	assert_gt(shell.end.y, InteriorProps.POD_ROOF, "the roof stands over the interior's")

## Spec §6.4: a beam fades from the lens (v = 1) to nothing at its far end
## (v = 0), and the material's gradient is brighter as v rises.
func test_a_beam_fades_from_the_lens_to_its_far_end():
	HullProps.beam_cone(_kit, Transform3D.IDENTITY, 10.0, 3.0)
	var made := _commit()
	var arrays: Array = (made["DressingGlow"] as Mesh).surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var near := 0
	var far := 0
	for i in v.size():
		if v[i].z < 0.5:
			near += 1
			assert_almost_eq(uv[i].y, 1.0, 0.0001, "the lens end is v = 1")
		else:
			far += 1
			assert_almost_eq(uv[i].y, 0.0, 0.0001, "the far end is v = 0")
	assert_gt(near, 0)
	assert_gt(far, 0)
	var tex := HullMaterials.beam(HullPalette.WORK_LIGHT).albedo_texture as GradientTexture2D
	assert_gt(tex.fill_to.y, tex.fill_from.y, "the gradient runs with v")
	assert_almost_eq(tex.gradient.sample(0.0).a, 0.0, 0.0001, "v = 0 is clear")
	assert_almost_eq(tex.gradient.sample(1.0).a, 1.0, 0.0001, "v = 1 is full")
	assert_lt(tex.gradient.sample(0.25).a, tex.gradient.sample(0.5).a)
	assert_lt(tex.gradient.sample(0.5).a, tex.gradient.sample(0.75).a, "brighter as v rises")
