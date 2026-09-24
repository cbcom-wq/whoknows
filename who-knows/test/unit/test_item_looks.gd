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
