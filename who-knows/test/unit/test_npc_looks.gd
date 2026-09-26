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
