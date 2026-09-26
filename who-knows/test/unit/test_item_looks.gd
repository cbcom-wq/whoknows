extends GutTest

## The item asset library (hands-and-items spec §4.3): every look builds from
## a bare kit, with no grid and no ship, and stays inside its item's box.

var _root: Node3D
var _kit: InteriorKit

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_kit = InteriorKit.new(_root)

func _bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var box := meshes[0].mesh.get_aabb()
	for mi in meshes:
		box = box.merge(mi.mesh.get_aabb())
	return box

func test_every_look_builds_inside_its_box():
	var cat := ItemCatalog.load_from_dir()
	for id in cat.ids():
		var def := cat.get_def(id)
		var root := Node3D.new()
		add_child_autofree(root)
		var kit := InteriorKit.new(root)
		ItemLooks.build(kit, def.look, def.size, 0.4)
		var meshes := kit.commit()
		assert_gt(meshes.size(), 0, "%s drew something" % id)
		var box := _bounds(meshes)
		var half := def.size * 0.5 + Vector3.ONE * 0.005
		assert_true(box.position.x >= -half.x and box.position.y >= -half.y and box.position.z >= -half.z
			and box.end.x <= half.x and box.end.y <= half.y and box.end.z <= half.z,
			"%s stays inside its %s box (drew %s)" % [id, def.size, box])

func test_the_pistol_has_a_lit_charge_light():
	ItemLooks.build(_kit, &"plasma_pistol", Vector3(0.06, 0.16, 0.24), 0.0)
	var names := _kit.commit().map(func(mi): return String(mi.name))
	assert_has(names, "DressingGlow", "the charge light and muzzle glow")

func test_looks_are_on_the_interior_layer():
	ItemLooks.build(_kit, &"crate", Vector3(0.45, 0.35, 0.35), 0.7)
	for mi in _kit.commit():
		assert_eq(mi.layers, 2)

## Quantum energy spec §10.5: the six salvage kinds, as the catalogue sizes
## them.
const SALVAGE := {
	&"rock_chunk": Vector3(0.20, 0.16, 0.18),
	&"ice_chunk": Vector3(0.20, 0.18, 0.20),
	&"scrap_plate": Vector3(0.50, 0.04, 0.35),
	&"wire_coil": Vector3(0.20, 0.08, 0.20),
	&"broken_module": Vector3(0.25, 0.06, 0.18),
	&"quantum_shard": Vector3(0.08, 0.20, 0.08),
}

func _batches(look: StringName) -> Array:
	var root := Node3D.new()
	add_child_autofree(root)
	var kit := InteriorKit.new(root)
	ItemLooks.build(kit, look, SALVAGE[look], 0.4)
	return kit.commit().map(func(mi): return String(mi.name))

func test_the_six_salvage_looks_build_in_bare_boxes():
	for look in SALVAGE:
		assert_true(ItemLooks.has_look(look), "%s is in the library" % look)
		assert_true(ItemLooks.has_glint(look), "%s glints" % look)
		assert_has(_batches(look), "DressingSolid" if look != &"quantum_shard" else "DressingGlow",
			"%s drew something" % look)

func test_only_salvage_glints():
	for look in ItemLooks.LOOKS:
		assert_eq(ItemLooks.has_glint(look), SALVAGE.has(look), "%s" % look)

func test_the_shard_is_all_glow():
	assert_eq(_batches(&"quantum_shard"), ["DressingGlow"], "a crystal on the glow batch, nothing else")

func test_the_broken_modules_light_is_dead():
	assert_eq(_batches(&"broken_module"), ["DressingSolid"], "nothing lit")

## Spec §10.4, §14.2: a small warm glint, as if it caught the sun: an unshaded
## billboard quad in LIGHT_WARM on the world's render layer, gone by 60 m.
func test_the_glint_builds_in_a_bare_box():
	var g := ItemLooks.glint(_root, 0.4)
	assert_eq(g.get_parent(), _root, "a child of the look")
	assert_eq(g.name, &"Glint")
	assert_eq(g.layers, 1, "the exterior render layer")
	assert_eq(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var m := g.material_override as StandardMaterial3D
	assert_not_null(m, "a built-in material, not a new shader")
	assert_eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_eq(m.billboard_mode, BaseMaterial3D.BILLBOARD_ENABLED)
	assert_eq(m.albedo_color, InteriorPalette.LIGHT_WARM)
	assert_eq(g.mesh.get_surface_count(), 1)
	assert_eq(g.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 4, "one quad")

func test_the_glint_is_visible_to_50_m_and_gone_by_60():
	var g := ItemLooks.glint(_root, 0.4)
	assert_eq(g.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
	assert_almost_eq(g.visibility_range_end - g.visibility_range_end_margin, 50.0, 0.001, "fading from 50 m")
	assert_almost_eq(g.visibility_range_end + g.visibility_range_end_margin, 60.0, 0.001, "gone by 60 m")

## Steps `g` for `seconds` at 1 ms, returning when each flash began and how
## long it lasted.
func _flashes(g: ItemLooks.Glint, seconds: float) -> Array:
	var out := []
	var was := g.visible
	var started := 0.0
	for i in int(seconds * 1000.0):
		g.advance(0.001)
		var t := (i + 1) * 0.001
		if g.visible and not was:
			started = t
		elif was and not g.visible:
			out.append([started, t - started])
		was = g.visible
	return out

func test_the_glint_flashes_for_0_15_s_every_2_to_4_s():
	for variety in [0.0, 0.13, 0.5, 0.77, 0.99]:
		var g := ItemLooks.glint(_root, variety)
		var flashes := _flashes(g, 20.0)
		assert_gte(flashes.size(), 4, "variety %s flashed" % variety)
		for i in range(1, flashes.size()):
			assert_almost_eq(flashes[i][1], ItemLooks.GLINT_FLASH, 0.0015, "a 0.15 s flash")
			var gap: float = flashes[i][0] - flashes[i - 1][0]
			assert_between(gap, 2.0 - 0.002, 4.0 + 0.002, "every 2-4 s (variety %s)" % variety)
		g.free()

func test_the_glint_is_seeded():
	var a := _flashes(ItemLooks.glint(_root, 0.3), 12.0)
	var b := _flashes(ItemLooks.glint(_root, 0.3), 12.0)
	var c := _flashes(ItemLooks.glint(_root, 0.6), 12.0)
	assert_eq(a, b, "the same seed flashes the same")
	assert_ne(a, c, "neighbours flash apart")
