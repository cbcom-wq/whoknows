extends GutTest

## The oasis's pieces (desert world phase 3): each builds in a bare frame with
## no place and no grid, in OasisPalette colours only.

var _root: Node3D
var _kit: InteriorKit

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_kit = InteriorKit.new(_root)
	_kit.keep_arrays = true

## Every vertex of the kit's solid batch: positions and colours.
func _solid() -> Array:
	_kit.commit()
	var arrays: Array = _kit.arrays.get(InteriorKit.Batch.SOLID, [])
	if arrays.is_empty():
		return [PackedVector3Array(), PackedColorArray()]
	return [arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_COLOR]]

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002

## The vertices coloured `c` or a shade of it.
func _count_of(colours: PackedColorArray, c: Color) -> int:
	var n := 0
	for v in colours:
		for k in SpacePalette.SHADES.size():
			if _same(v, InteriorKit.solid(SpacePalette.shade(c, k))):
				n += 1
				break
	return n

func _top(vertices: PackedVector3Array) -> float:
	var top := -INF
	for v in vertices:
		top = maxf(top, v.y)
	return top

func test_a_palm_builds_alone():
	OasisLooks.palm(_kit, Transform3D.IDENTITY, 0.2)
	var s := _solid()
	var low: float = _top(s[0])
	assert_between(low, 6.0, 9.0, "6 to 9 m tall")
	assert_eq(OasisLooks.TRUNK_DRUMS, 7, "7 drums")
	assert_between(OasisLooks.TRUNK_DRUMS, 6, 8)
	var other := InteriorKit.new(_root)
	other.keep_arrays = true
	OasisLooks.palm(other, Transform3D.IDENTITY, 0.9)
	other.commit()
	var tall := _top(other.arrays[InteriorKit.Batch.SOLID][Mesh.ARRAY_VERTEX])
	assert_between(tall, 6.0, 9.0)
	assert_ne(snappedf(tall, 0.01), snappedf(low, 0.01), "two varieties differ in height")
	var a := OasisLooks.palm_collider(Transform3D.IDENTITY, 0.2)
	var b := OasisLooks.palm_collider(Transform3D.IDENTITY, 0.9)
	var lean_a := a.transform.basis.y
	var lean_b := b.transform.basis.y
	a.free()
	b.free()
	assert_gt(lean_a.distance_to(lean_b), 0.01, "and in lean")

func test_a_palm_has_seven_fronds():
	OasisLooks.palm(_kit, Transform3D.IDENTITY, 0.3)
	var colours: PackedColorArray = _solid()[1]
	var green := _count_of(colours, OasisPalette.PALM_FROND)
	var dry := _count_of(colours, OasisPalette.PALM_FROND_DRY)
	assert_eq((green + dry) / OasisLooks.FROND_VERTICES, OasisLooks.FRONDS, "seven fronds")
	assert_eq(OasisLooks.FRONDS, 7)
	assert_between(dry / OasisLooks.FROND_VERTICES, 1, 2, "the lowest one or two are dry")

func test_colours_come_from_the_palette():
	OasisLooks.palm(_kit, Transform3D.IDENTITY, 0.6)
	OasisLooks.garden(_kit, Transform3D.IDENTITY, Vector2(4, 3), false, 0.4)
	OasisLooks.pump(_kit, Transform3D.IDENTITY)
	OasisLooks.pipe(_kit, Vector3.ZERO, Vector3(3, 0, 1))
	OasisLooks.path(_kit, PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(2, 0, 0.3)]), 1.4)
	var allowed := [OasisPalette.PALM_TRUNK, OasisPalette.PALM_FROND, OasisPalette.PALM_FROND_DRY,
		OasisPalette.GARDEN_SOIL, OasisPalette.CROP_GREEN, OasisPalette.PUMP, OasisPalette.PUMP_DARK,
		OasisPalette.PIPE, OasisPalette.PATH]
	var colours: PackedColorArray = _solid()[1]
	assert_gt(colours.size(), 0)
	var strays := 0
	for v in colours:
		var found := false
		for c in allowed:
			for k in SpacePalette.SHADES.size():
				if _same(v, InteriorKit.solid(SpacePalette.shade(c, k))):
					found = true
		if not found:
			strays += 1
	assert_eq(strays, 0, "every vertex is a palette colour or a shade of one")

func test_a_dried_garden_is_dry():
	OasisLooks.garden(_kit, Transform3D.IDENTITY, Vector2(4, 3), true, 0.4)
	var colours: PackedColorArray = _solid()[1]
	assert_gt(_count_of(colours, OasisPalette.CROP_DRY), 0, "dry crops")
	assert_eq(_count_of(colours, OasisPalette.CROP_GREEN), 0, "no green crops")
	assert_gt(_count_of(colours, OasisPalette.GARDEN_SOIL), 0, "on soil")

func test_a_green_garden_is_green():
	OasisLooks.garden(_kit, Transform3D.IDENTITY, Vector2(4, 3), false, 0.4)
	var colours: PackedColorArray = _solid()[1]
	assert_gt(_count_of(colours, OasisPalette.CROP_GREEN), 0)
	assert_eq(_count_of(colours, OasisPalette.CROP_DRY), 0)

func test_the_grass_ring_keeps_out_of_the_water():
	var f := Transform3D(Basis.IDENTITY, Vector3(3, 1, -2))
	var axes := Vector2(36, 26)
	var water := 14.5
	var inner := 1.5
	var ring := OasisLooks.grass_ring(f, axes, water, inner, 7, func(_x: float, _z: float) -> float: return 0.5)
	add_child_autofree(ring)
	var mm := ring.multimesh
	assert_gt(mm.instance_count, 500, "a ring of tufts")
	assert_eq(mm.mesh, GroundCover.grass_mesh())
	var tufts: PackedVector3Array = ring.get_meta(&"tufts")
	assert_eq(tufts.size(), mm.instance_count)
	for i in tufts.size():
		var at := tufts[i]
		var d := Vector2(at.x - f.origin.x, at.z - f.origin.z)
		assert_gt(d.length(), water + inner - 0.001, "tuft %d is out of the water and its bank" % i)
		assert_lte(d.x * d.x / (axes.x * axes.x) + d.y * d.y / (axes.y * axes.y), 1.000001, "tuft %d is inside the ellipse" % i)
		assert_almost_eq(at.y, 0.5, 0.0001, "on the ground")
	assert_eq(ring.find_children("*", "CollisionObject3D", true, false).size(), 0, "no collision")
