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

func test_the_limpet_is_built_low_and_cheap():
	var look := autofree(NpcLooks.build(&"limpet", 0.4, false, SpacePalette.UMBER, Vector2(70, 95))) as LimpetLook
	assert_not_null(look)
	assert_null(look.get_node_or_null("Placeholder"), "not a placeholder")
	assert_lte(_triangles(look), 80, "at most 80 triangles")
	assert_almost_eq(NpcLooks.built_size(&"limpet"), 1.0, 0.0001)
	var low := INF
	var high := -INF
	var wide := 0.0
	for mi: MeshInstance3D in look.find_children("*", "MeshInstance3D", true, false):
		assert_eq(mi.layers, 1, "%s outside" % mi.name)
		var m := mi.material_override as StandardMaterial3D
		assert_eq(m.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER, "%s fades" % mi.name)
		assert_almost_eq(m.distance_fade_min_distance, 95.0, 0.001)
		assert_almost_eq(m.distance_fade_max_distance, 70.0, 0.001)
		for v in (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			low = minf(low, v.y)
			high = maxf(high, v.y)
			wide = maxf(wide, Vector2(v.x, v.z).length() * 2.0)
	assert_gt(high - low, 0.0)
	assert_lt(high - low, wide * 0.6, "a low, flat cone")
	assert_almost_eq(wide, NpcLooks.built_size(&"limpet"), 0.01, "as wide as it says")

func test_the_limpets_shell_takes_its_rocks_shades_and_its_ribs_the_crystal():
	var look := autofree(NpcLooks.build(&"limpet", 0.4, false, SpacePalette.UMBER, Vector2(70, 95))) as LimpetLook
	var shell := _colours(look.get_node("Shell") as MeshInstance3D)
	var ribs := _colours(look.get_node("Ribs") as MeshInstance3D)
	assert_true(_has(shell, SpacePalette.shade(SpacePalette.UMBER, 1)), "its shell in its rock's shades")
	assert_false(_has(shell, SpacePalette.CRYSTAL), "no crystal in the shell between the ribs")
	assert_eq(ribs.size(), 1, "the ribs are one colour")
	assert_true(_has(ribs, SpacePalette.shade(SpacePalette.CRYSTAL, 0)), "lavender, its darkest step at rest")
	var veined := autofree(NpcLooks.build(&"limpet", 0.4, false, SpacePalette.UNTINTED, Vector2(70, 95))) as LimpetLook
	assert_true(_has(_colours(veined.get_node("Shell") as MeshInstance3D), SpacePalette.shade(SpacePalette.ASH, 1)),
		"on a veined rock, in the ash it is made of")

## Not a stone: a raised nub at the middle, and a rim that scallops (tips on
## the ground, drawn out, between valleys lifted and drawn in).
func test_the_limpet_has_an_apex_nub_and_a_scalloped_rim():
	var look := autofree(NpcLooks.build(&"limpet", 0.4, false, SpacePalette.UMBER, Vector2(70, 95))) as LimpetLook
	var tips := {}
	var valleys := {}
	var apex := Vector3.ZERO
	for v in (look.get_node("Shell") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var vec := v as Vector3
		if vec.y > apex.y:
			apex = vec
		if vec.y < 0.01:
			tips[snappedf(atan2(vec.x, vec.z), 0.01)] = Vector2(vec.x, vec.z).length()
		elif vec.y < 0.2:
			valleys[snappedf(atan2(vec.x, vec.z), 0.01)] = Vector2(vec.x, vec.z).length()
	assert_almost_eq(Vector2(apex.x, apex.z).length(), 0.0, 0.001, "the nub is at the middle")
	assert_gt(apex.y, 0.5, "and stands up")
	assert_eq(tips.size(), LimpetLook.RIBS, "a tip to each rib")
	assert_eq(valleys.size(), LimpetLook.RIBS, "a valley between each")
	for r: float in tips.values():
		assert_almost_eq(r, LimpetLook.TIP_RADIUS, 0.001)
	for r: float in valleys.values():
		assert_almost_eq(r, LimpetLook.VALLEY_RADIUS, 0.001)

func test_a_limpet_sipping_brightens_its_ribs_and_stops():
	var look := autofree(NpcLooks.build(&"limpet", 0.4, false, SpacePalette.UMBER, Vector2(70, 95))) as LimpetLook
	var under := look.get_node("Ribs") as MeshInstance3D
	var rest := SpacePalette.shade(SpacePalette.CRYSTAL, 0)
	var brightest := SpacePalette.shade(SpacePalette.CRYSTAL, SpacePalette.SHADES.size() - 1)
	assert_gt(brightest.v, rest.v * 1.2, "a step you can see from above")
	assert_true(_has(_colours(under), rest))
	look.act(&"sip")
	assert_true(_has(_colours(under), brightest), "sipping: the brightest step of the crystal")
	assert_false(_has(_colours(under), rest))
	look.act(&"cling")
	assert_true(_has(_colours(under), rest), "any other action swaps back")
	assert_false(_has(_colours(under), brightest))
	look.act(&"sip")
	look.act(&"bite")
	assert_true(_has(_colours(under), rest))

static func _colours(mi: MeshInstance3D) -> Dictionary:
	var out := {}
	for c in (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		out[c] = true
	return out
