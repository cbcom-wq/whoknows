extends GutTest

## What NPCs look like (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.4, §14.4).

func _triangles(root: Node) -> int:
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			n += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3
	return n

func test_the_droid_builds_from_the_kit_on_the_interior_layer():
	var look := autofree(NpcLooks.build(&"droid", 0.2, true)) as DroidLook
	assert_not_null(look)
	var meshes := look.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0)
	for mi: MeshInstance3D in meshes:
		assert_eq(mi.layers, InteriorKit.LAYER, "%s on the interior layer" % mi.name)
		assert_true(InteriorKit.BATCH_NAMES.has(mi.name), "%s is a kit batch" % mi.name)
	assert_eq(look.find_children("*", "Light3D", true, false).size(), 0, "no light of its own")

func test_the_droid_is_small_and_its_triangles_are_pinned():
	var look := autofree(NpcLooks.build(&"droid", 0.2, true)) as DroidLook
	var tris := _triangles(look)
	assert_eq(tris, 512, "pin the droid's triangle count; change it on purpose")

func test_the_droid_moves_its_parts():
	var look := autofree(NpcLooks.build(&"droid", 0.2, true)) as DroidLook
	add_child(look)
	look.act(&"polish")
	for i in 20:
		look.pose(0.05, 0.0)
	assert_false(look.arm_basis().is_equal_approx(Basis.IDENTITY), "the arm works")
	look.act(&"notice")
	for i in 30:
		look.pose(0.05, 0.0)
	assert_gt(look.cap_basis().get_euler().x, 0.1, "the cap tilts")
	look.act(&"brace")
	for i in 30:
		look.pose(0.05, 0.0)
	assert_lt(look.body_height(), -0.015, "it squats")
	look.act(&"")
	for i in 60:
		look.pose(0.05, 0.0)
	assert_true(look.arm_basis().is_equal_approx(Basis.IDENTITY), "and all comes back")
	assert_almost_eq(look.body_height(), 0.0, 0.001)
	remove_child(look)

func test_an_unknown_look_is_a_box():
	var look := autofree(NpcLooks.build(&"nothing_yet", 0.0, false)) as Node3D
	assert_not_null(look.get_node_or_null("Placeholder"))

func test_the_skitter_is_chunky_faceted_and_in_its_rocks_colour():
	var look := autofree(NpcLooks.build(&"skitter", 0.4, false, SpacePalette.UMBER, Vector2(250, 300))) as SkitterLook
	assert_not_null(look)
	assert_lt(_triangles(look), 300, "under 300 triangles")
	var colours := {}
	for mi: MeshInstance3D in look.find_children("*", "MeshInstance3D", true, false):
		assert_eq(mi.layers, 1, "%s outside" % mi.name)
		var m := mi.material_override as StandardMaterial3D
		assert_eq(m.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER, "%s fades" % mi.name)
		assert_almost_eq(m.distance_fade_min_distance, 300.0, 0.001)
		assert_almost_eq(m.distance_fade_max_distance, 250.0, 0.001)
		if mi.mesh is ArrayMesh:
			for c in (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
				colours[c] = true
	assert_true(_has(colours, SpacePalette.CRYSTAL), "a lavender patch")
	assert_true(_has(colours, SpacePalette.SKITTER_EYE), "pale eyes")
	var in_rock := 0
	for k in SpacePalette.SHADES.size():
		if _has(colours, SpacePalette.shade(SpacePalette.UMBER, k)):
			in_rock += 1
	assert_gt(in_rock, 0, "its back in its rock's shades")

## Mesh colours are stored at 8 bits a channel.
static func _has(colours: Dictionary, want: Color) -> bool:
	for c: Color in colours:
		if absf(c.r - want.r) < 0.01 and absf(c.g - want.g) < 0.01 and absf(c.b - want.b) < 0.01:
			return true
	return false

func test_the_skitters_legs_reach_their_feet():
	var hip := Vector3(-0.2, 0.14, -0.2)
	var foot := Vector3(-0.42, 0.0, -0.32)
	var knee := SkitterLook.knee_for(hip, foot, SkitterLook.THIGH, SkitterLook.SHIN)
	assert_almost_eq(knee.distance_to(hip), SkitterLook.THIGH, 0.001)
	assert_almost_eq(knee.distance_to(foot), SkitterLook.SHIN, 0.001)
	assert_gt(knee.y, foot.y + 0.05, "the knee bends up off the ground")
	assert_gt(absf(knee.x), absf(hip.x), "and out to the side")

func test_the_skitters_legs_never_stretch():
	var look := autofree(NpcLooks.build(&"skitter", 0.4, false, SpacePalette.UMBER, Vector2(250, 300))) as SkitterLook
	add_child(look)
	var far: Array[Vector3] = []
	for f in SkitterLook.FEET:
		far.append(f + Vector3(0, 0, 3.0))
	look._pose_legs(far)
	for mi in look.find_children("Leg*", "MeshInstance3D", true, false):
		var length := (mi as MeshInstance3D).transform.basis.z.length()
		assert_lt(length, SkitterLook.SHIN + 0.01, "%s is %.2f m long" % [mi.name, length])
	remove_child(look)
