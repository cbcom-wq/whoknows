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
		OasisPalette.PIPE, OasisPalette.PATH, OasisPalette.GREEN_PATCH, OasisPalette.GRASS_OLIVE,
		OasisPalette.GRASS_DRY_EDGE]
	OasisLooks.green_patch(_kit, _flat_ground(Vector3.ZERO, 30.0, 2.0, 0.0), Vector3.ZERO, Vector2(20, 15), 6.0, 3)
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

## The tufts of a GrassRing: [where each stands (its meta), its tiles].
func _tiles(ring: Node3D) -> Array:
	return ring.find_children("*", "MultiMeshInstance3D", true, false)

func test_the_grass_ring_keeps_out_of_the_water():
	var f := Transform3D(Basis.IDENTITY, Vector3(3, 1, -2))
	var axes := Vector2(36, 26)
	var water := 14.5
	var inner := 1.5
	var ring := OasisLooks.grass_ring(f, axes, water, inner, 7, func(_x: float, _z: float) -> float: return 0.5)
	add_child_autofree(ring)
	var tiles := _tiles(ring)
	assert_gt(tiles.size(), 8, "tiles of tufts, each fading by its own distance")
	var count := 0
	for t: MultiMeshInstance3D in tiles:
		count += t.multimesh.instance_count
		assert_eq(t.multimesh.mesh, GroundCover.grass_mesh())
	assert_gt(count, 500, "a ring of tufts")
	var tufts: PackedVector3Array = ring.get_meta(&"tufts")
	assert_eq(tufts.size(), count)
	for i in tufts.size():
		var at := tufts[i]
		var d := Vector2(at.x - f.origin.x, at.z - f.origin.z)
		assert_gt(d.length(), water + inner - 0.001, "tuft %d is out of the water and its bank" % i)
		# Rework 2: a few strays lie up to STRAY_OUT past the outline.
		assert_lte(d.length(), OasisLooks.green_reach(axes, d.angle(), 7) + OasisLooks.STRAY_OUT.y + OasisLooks.CLUMP_RADIUS,
			"tuft %d is in the green or a stray by it" % i)
		assert_almost_eq(at.y, 0.5, 0.0001, "on the ground")
	assert_eq(ring.find_children("*", "CollisionObject3D", true, false).size(), 0, "no collision")

## From the air only the green patch shows: every tile of tufts fades out by
## distance (Checkpoint B), gone by about 100 m, never cast a shadow, and
## each tile's node sits among its own tufts, so it is judged by their
## distance.
func test_the_tufts_fade_out_by_distance():
	var f := Transform3D(Basis.IDENTITY, Vector3(3, 1, -2))
	var ring := OasisLooks.grass_ring(f, Vector2(36, 26), 14.5, 1.5, 7, func(_x: float, _z: float) -> float: return 0.5)
	add_child_autofree(ring)
	for t: MultiMeshInstance3D in _tiles(ring):
		assert_eq(t.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
		assert_between(t.visibility_range_end + t.visibility_range_end_margin, 90.0, 110.0, "gone by about 100 m")
		assert_gt(t.visibility_range_end - t.visibility_range_end_margin, 50.0, "whole up close")
		assert_eq(t.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var reach := 0.0
		for i in t.multimesh.instance_count:
			reach = maxf(reach, t.multimesh.get_instance_transform(i).origin.length())
		assert_lt(reach, OasisLooks.TUFT_TILE * 1.5, "%s's tufts lie round it" % t.name)

## Flat ground triangles over a square `half` either side of `centre`, `quad` m
## a side, at height `y`, split as the world splits its quads.
func _flat_ground(centre: Vector3, half: float, quad: float, y: float) -> Array:
	var out := []
	var n := int(ceil(2.0 * half / quad))
	for j in n:
		for i in n:
			var p00 := Vector3(centre.x - half + i * quad, y, centre.z - half + j * quad)
			var p10 := p00 + Vector3(quad, 0, 0)
			var p01 := p00 + Vector3(0, 0, quad)
			var p11 := p00 + Vector3(quad, 0, quad)
			out.append(PackedVector3Array([p00, p10, p11]))
			out.append(PackedVector3Array([p00, p11, p01]))
	return out

func test_the_green_patch_lies_on_the_ground_out_of_the_water():
	var centre := Vector3(3, 0.5, -2)
	var axes := Vector2(36, 26)
	var water := 14.5
	var laid := OasisLooks.green_patch(_kit, _flat_ground(centre, 45.0, 1.31, 0.5), centre, axes, water, 7)
	var solid := _solid()
	var vertices: PackedVector3Array = solid[0]
	assert_gt(vertices.size(), 3000, "a carpet of triangles")
	var colours: PackedColorArray = solid[1]
	var green := _count_of(colours, OasisPalette.GREEN_PATCH)
	var olive := _count_of(colours, OasisPalette.GRASS_OLIVE)
	var dry := _count_of(colours, OasisPalette.GRASS_DRY_EDGE)
	assert_eq(green + olive + dry, vertices.size(), "all of it the green or its dry rim, in their shades")
	assert_gt(green, vertices.size() / 2, "mostly green")
	assert_gt(olive, 0, "olive toward its edge")
	assert_gt(dry, 0, "and straw at it")
	# Rework 2: the green dries only in its outer GREEN_FADE m.
	for i in vertices.size():
		var v := vertices[i]
		var d := Vector2(v.x - centre.x, v.z - centre.z)
		var inside := OasisLooks.green_reach(axes, d.angle(), 7) - d.length()
		if _count_of(PackedColorArray([colours[i]]), OasisPalette.GRASS_DRY_EDGE) > 0:
			assert_lt(inside, OasisLooks.GREEN_FADE + 2.0, "straw only at the rim (%.1f m in)" % inside)
	var reach_lo := INF
	var reach_hi := 0.0
	var near := INF
	for v in vertices:
		assert_almost_eq(v.y, 0.5 + OasisLooks.PATCH_PROUD, 0.0005, "PATCH_PROUD over the ground")
		var d := Vector2(v.x - centre.x, v.z - centre.z)
		near = minf(near, d.length())
		# A cut point is on its triangle's edge, where the outline is straight
		# (Rework 2: its finer bays bend it more within an edge).
		assert_lte(d.length(), OasisLooks.green_reach(axes, d.angle(), 7) + 0.1, "inside the green's outline")
	assert_almost_eq(near, water + OasisLooks.PATCH_SHORE, 0.05, "out of the water, up to its shore")
	assert_eq(laid.size() > 0, true)
	# The outline is ragged: its reach strays from the ellipse's by more than 8%.
	for k in 72:
		var a := TAU * k / 72.0
		var ellipse := 1.0 / sqrt(pow(cos(a) / axes.x, 2) + pow(sin(a) / axes.y, 2))
		var share := OasisLooks.green_reach(axes, a, 7) / ellipse
		reach_lo = minf(reach_lo, share)
		reach_hi = maxf(reach_hi, share)
	assert_gt(reach_hi - reach_lo, 0.16, "an organic outline, not a perfect ellipse")
	assert_between(reach_lo, 0.8, 1.0)
	assert_between(reach_hi, 1.0, 1.2)

func test_the_green_patch_is_darker_and_greener_than_the_tufts():
	var patch := OasisPalette.GREEN_PATCH
	var tuft := OasisPalette.GRASS
	assert_lt(patch.get_luminance(), tuft.get_luminance(), "darker")
	assert_gt(patch.g / (patch.r + patch.g + patch.b), tuft.g / (tuft.r + tuft.g + tuft.b), "and greener")
	var code := FileAccess.get_file_as_string("res://src/world/oasis_looks.gd")
	assert_true(code.contains("OasisPalette.GREEN_PATCH"), "the patch takes the palette's green")

## The tracks are 1.5 times as big since Checkpoint B: a print about 3.6 m
## long, and the gait scaled with it.
func test_the_tracks_are_big_enough_to_read_from_the_seat():
	assert_almost_eq(OasisLooks.PRINT_LENGTH, 3.6, 0.001)
	assert_almost_eq(OasisLooks.PRINT_WIDTH / OasisLooks.PRINT_LENGTH, 1.4 / 2.4, 0.01, "the same shape")
	assert_almost_eq(OasisLooks.STRIDE / OasisLooks.PRINT_LENGTH, 7.0 / 2.4, 0.01, "the stride scaled with it")
	assert_almost_eq(OasisLooks.FRONT_GAUGE / OasisLooks.PRINT_LENGTH, 2.0 / 2.4, 0.01, "and the gauge")
	var tracks := OasisLooks.tracks(Transform3D.IDENTITY, Vector2.ZERO, 0.0, 60.0,
		func(_x: float, _z: float) -> float: return 0.0, 0.4)
	add_child_autofree(tracks)
	var prints: Array = tracks.get_meta(&"prints")
	assert_gt(prints.size(), 15)
	var first: PackedVector3Array = prints[0]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in first:
		lo = lo.min(v)
		hi = hi.max(v)
		assert_almost_eq(v.y, OasisLooks.PRINT_PROUD, 0.0001, "on the ground")
	assert_between(hi.z - lo.z, 3.2, 3.7, "a print about 3.6 m long (its toes notched)")
	assert_between(hi.x - lo.x, 1.9, 2.5, "and about 2.1 m wide")
	var colours: PackedColorArray = (tracks.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var sand: Color = SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE][&"ground_low"]
	var track := InteriorKit.solid(OasisPalette.TRACK)
	for c in colours:
		# Every print is OasisPalette.TRACK faded part way to the sand.
		var t := (c.r - track.r) / (sand.r - track.r)
		assert_between(t, -0.02, OasisLooks.TRACK_FADE + 0.02)
		# (A mesh keeps its vertex colours in 8 bits.)
		assert_almost_eq(c.g, lerpf(track.g, sand.g, t), 0.008, "TRACK toward the sand")
