extends GutTest

## Mud-brick shells (desert world phase 3, Task 9): each builds in a bare frame
## from a kit, a frame and a variety, with no grid and no place, in
## OasisPalette colours only. Part C's BaseExterior reuses them.

const PATH := "res://src/world/brick_shell.gd"
const RULES := preload("res://test/unit/test_visual_style_rules.gd")

const SIZE := Vector3(6.0, 3.2, 4.5)

var _root: Node3D
var _kit: InteriorKit

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_kit = InteriorKit.new(_root)
	_kit.keep_arrays = true

## Every vertex of the kit's solid batch: positions and colours.
func _solid(kit: InteriorKit = _kit) -> Array:
	kit.commit()
	var arrays: Array = kit.arrays.get(InteriorKit.Batch.SOLID, [])
	if arrays.is_empty():
		return [PackedVector3Array(), PackedColorArray()]
	return [arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_COLOR]]

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002

## A door in the front (-z) wall and a window in the east (+x) wall, each
## [centre in the frame, width, height].
func _openings() -> Array:
	var front := -SIZE.z * 0.5 + BrickShell.WALL * 0.5
	var east := SIZE.x * 0.5 - BrickShell.WALL * 0.5
	return [[Vector3(-1.4, 1.0, front), 1.1, 2.0], [Vector3(east, 1.6, 1.3), 0.8, 0.7]]

## The shapes on one StaticBody3D in the tree, ready for rays.
func _solid_body(shapes: Array[CollisionShape3D]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = BodyProxy.LAYER
	body.collision_mask = 0
	_root.add_child(body)
	for s in shapes:
		body.add_child(s)
	return body

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, BodyProxy.LAYER)
	return _root.get_world_3d().direct_space_state.intersect_ray(query)

static func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var comment_at := line.find("#")
		out.append(line if comment_at < 0 else line.substr(0, comment_at))
	return "\n".join(out)

func test_a_box_builds_alone():
	BrickShell.box(_kit, Transform3D.IDENTITY, SIZE, _openings(), 0.3)
	var vertices: PackedVector3Array = _solid()[0]
	assert_gt(vertices.size(), 100, "it has a shape")
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in vertices:
		lo = lo.min(v)
		hi = hi.max(v)
	assert_almost_eq(lo.y, 0.0, 0.01, "its walls stand on the frame")
	assert_between(hi.y, SIZE.y - 0.01, SIZE.y + 0.3, "its parapet and its steps top it")
	assert_lt(absf(hi.x - SIZE.x * 0.5), 0.1, "as wide as asked")
	var code := _code(PATH)
	for ident in RULES.GRID_SIDE:
		assert_null(RegEx.create_from_string("\\b%s\\b" % ident).search(code),
			"brick_shell.gd uses %s: it builds from (kit, frame, variety) alone" % ident)
	assert_true(RULES.REUSABLE_FILES.has(PATH), "and the rules test guards it")
	assert_true(RULES.PAINTING_FILES.has(PATH), "and its colours")

func test_openings_are_holes():
	var shapes := BrickShell.box_shapes(Transform3D.IDENTITY, SIZE, _openings(), 0.3)
	assert_gt(shapes.size(), 4, "walls in pieces round the openings")
	_solid_body(shapes)
	await wait_physics_frames(2)
	for o: Array in _openings():
		var c: Vector3 = o[0]
		var across := Vector3(0, 0, 1) if absf(c.z) > absf(c.x) * SIZE.z / SIZE.x else Vector3(1, 0, 0)
		var hit := _ray(c - across * 1.0, c + across * 1.0)
		assert_true(hit.is_empty(), "the opening at %s is a hole" % c)

func test_the_walls_are_solid():
	_solid_body(BrickShell.box_shapes(Transform3D.IDENTITY, SIZE, _openings(), 0.3))
	await wait_physics_frames(2)
	var mid := SIZE.y * 0.45
	for face_out: Array in [[Vector3(0, mid, SIZE.z * 0.5), Vector3.BACK], [Vector3(0.5, mid, -SIZE.z * 0.5), Vector3.FORWARD],
			[Vector3(SIZE.x * 0.5, mid, -0.8), Vector3.RIGHT], [Vector3(-SIZE.x * 0.5, mid, 0), Vector3.LEFT]]:
		var face: Vector3 = face_out[0]
		var out: Vector3 = face_out[1]
		var hit := _ray(face + out * 2.0, face - out * 2.0)
		assert_false(hit.is_empty(), "the wall at %s is solid" % face)
		if not hit.is_empty():
			assert_lt((hit["position"] as Vector3).distance_to(face), 0.6, "hit at the wall's face")

func test_colours_come_from_the_palette():
	BrickShell.box(_kit, Transform3D.IDENTITY, SIZE, _openings(), 0.3)
	BrickShell.round_hut(_kit, InteriorKit.at(Vector3(12, 0, 0)), 5.4, 3.0, 0.6)
	BrickShell.crushed(_kit, InteriorKit.at(Vector3(-14, 0, 0)), Vector3(12, 3.2, 8), 0.2)
	BrickShell.wall(_kit, PackedVector3Array([Vector3(0, 0, 10), Vector3(2, 0.1, 10), Vector3(4, 0.15, 11)]), 2.6, 0.5)
	BrickShell.rubble(_kit, InteriorKit.at(Vector3(0, 0, 14)), Vector2(4, 8), 20, 0.7)
	BrickShell.patch(_kit, InteriorKit.at(Vector3(0, 1, 20)), Vector2(1.2, 0.9), 0.4)
	BrickShell.sail(_kit, InteriorKit.at(Vector3(0, 0, 26)), Vector2(4.5, 3.5), 0.8)
	var allowed := [OasisPalette.BRICK, OasisPalette.BRICK_DARK, OasisPalette.SAIL, OasisPalette.SAIL_POLE,
		OasisPalette.REVEAL, OasisPalette.WOOD]
	var colours: PackedColorArray = _solid()[1]
	assert_gt(colours.size(), 0)
	var strays := 0
	var seen := {}
	for v in colours:
		var found := false
		for c in allowed:
			for k in SpacePalette.SHADES.size():
				if _same(v, InteriorKit.solid(SpacePalette.shade(c, k))) or _same(v, InteriorKit.solid(c)):
					found = true
					seen[c] = true
		if not found:
			strays += 1
	assert_eq(strays, 0, "every vertex is a palette colour or a shade of one")
	assert_eq(seen.size(), allowed.size(), "and every colour is used")

## The highest vertex over a shell's inside: inset from its walls, so the walls
## and parapet are left out and what is left is its roof (or what fell in).
func _roof_top(vertices: PackedVector3Array, size: Vector3) -> float:
	var hx := size.x * 0.5 - BrickShell.WALL - 0.3
	var hz := size.z * 0.5 - BrickShell.WALL - 0.3
	var top := -INF
	for v in vertices:
		if absf(v.x) < hx and absf(v.z) < hz:
			top = maxf(top, v.y)
	return top

func test_a_crushed_hut_differs_from_a_whole_one():
	var size := Vector3(12, 3.2, 8)
	BrickShell.box(_kit, Transform3D.IDENTITY, size, [], 0.2)
	var whole := _roof_top(_solid()[0], size)
	var other := InteriorKit.new(_root)
	other.keep_arrays = true
	BrickShell.crushed(other, Transform3D.IDENTITY, size, 0.2)
	var crushed := _roof_top(_solid(other)[0], size)
	assert_gt(whole, size.y * 0.8, "the whole one has its roof")
	assert_lt(crushed, whole * 0.7, "the crushed one's roof has fallen in")
	assert_gt(crushed, 0.3, "and lies inside it")

func test_each_shape_twin_gives_boxes():
	var sets := [BrickShell.box_shapes(Transform3D.IDENTITY, SIZE, [], 0.1),
		BrickShell.round_hut_shapes(Transform3D.IDENTITY, 5.4, 3.0, 0.1),
		BrickShell.crushed_shapes(Transform3D.IDENTITY, Vector3(12, 3.2, 8), 0.1),
		BrickShell.wall_shapes(PackedVector3Array([Vector3.ZERO, Vector3(2, 0, 0), Vector3(4, 0.1, 1)]), 2.6, 0.1)]
	for shapes: Array[CollisionShape3D] in sets:
		assert_gt(shapes.size(), 1)
		for s in shapes:
			assert_true(s.shape is BoxShape3D, "boxes only")
			s.free()

func test_a_round_hut_is_round_and_open_at_its_door():
	_solid_body(BrickShell.round_hut_shapes(Transform3D.IDENTITY, 5.4, 3.0, 0.5))
	await wait_physics_frames(2)
	var door := _ray(Vector3(0, 1.0, -8), Vector3(0, 1.0, 0))
	assert_true(door.is_empty() or (door["position"] as Vector3).z > 4.0, "in through the door (-z)")
	for k in 5:
		var a := PI * 0.25 + k * PI * 0.3
		var out := Vector3(sin(a), 0, cos(a))
		var hit := _ray(out * 8.0 + Vector3(0, 1.4, 0), Vector3(0, 1.4, 0))
		assert_false(hit.is_empty(), "a wall at %.1f rad" % a)
		if not hit.is_empty():
			assert_almost_eq(Vector2((hit["position"] as Vector3).x, (hit["position"] as Vector3).z).length(), 5.4, 0.45)

func test_a_wall_follows_the_ground_and_breaks_at_its_top():
	var points := PackedVector3Array()
	for k in 9:
		points.append(Vector3(k * 2.0, 0.1 * sin(k * 0.7), 0))
	BrickShell.wall(_kit, points, 2.6, 0.5)
	var vertices: PackedVector3Array = _solid()[0]
	# Each top vertex's height over the ground under it (the ground runs
	# straight from point to point).
	var lo := INF
	var hi := -INF
	for v in vertices:
		var t := clampf(v.x / 2.0, 0.0, 7.999)
		var ground := lerpf(points[int(t)].y, points[int(t) + 1].y, t - int(t))
		var over := v.y - ground
		if over > 1.0:
			lo = minf(lo, over)
			hi = maxf(hi, over)
	assert_between(lo, 1.3, 2.65, "the lowest of the top")
	assert_between(hi, 1.3, 2.65, "the highest")
	assert_gt(hi - lo, 0.3, "a ragged top")
	for p in points:
		var under := INF
		for v in vertices:
			if absf(v.x - p.x) < 0.01:
				under = minf(under, v.y)
		if under < INF:
			assert_almost_eq(under, p.y - BrickShell.SUNK, 0.02, "the base at %s is on the ground, sunk" % p)

# --- adobe (Checkpoint B) -------------------------------------------------------

## The vertices of `colour` (or a shade of it) among `solid` ([positions, colours]).
func _of(solid: Array, colour: Color) -> PackedVector3Array:
	var out := PackedVector3Array()
	var vertices: PackedVector3Array = solid[0]
	var colours: PackedColorArray = solid[1]
	for i in vertices.size():
		for k in SpacePalette.SHADES.size():
			if _same(colours[i], InteriorKit.solid(SpacePalette.shade(colour, k))) or _same(colours[i], InteriorKit.solid(colour)):
				out.append(vertices[i])
				break
	return out

## The brick is sun-baked: lighter than it was and than the sand's shade,
## warm, and not the sand's orange.
func test_the_brick_is_sun_baked():
	var brick := OasisPalette.BRICK
	var sand: Color = SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE][&"ground_low"]
	assert_gt(brick.get_luminance(), Color("a8774f").get_luminance() + 0.08, "lighter than the dark brown it was")
	assert_gt(brick.r, brick.b + 0.15, "warm")
	assert_lt(brick.s, 0.5, "a buff, less saturated than the sand's orange (about c88050 in the sun, 0.6)")
	assert_gt(brick.get_luminance(), sand.get_luminance(), "and lighter than the sand's own colour")
	assert_lt(OasisPalette.REVEAL.get_luminance(), brick.get_luminance() * 0.6, "the reveals are deep and dark")

## A box's beams poke out of its front and back under the parapet, in wood;
## its openings have wooden lintels and dark reveals; and its outer faces are
## laid in blocks of more than one shade.
func test_a_box_is_adobe():
	BrickShell.box(_kit, Transform3D.IDENTITY, SIZE, _openings(), 0.3)
	var solid := _solid()
	var wood := _of(solid, OasisPalette.WOOD)
	var roof_y := SIZE.y - BrickShell.PARAPET
	var beams := 0
	for v in wood:
		if absf(v.z) > SIZE.z * 0.5 + 0.3:
			beams += 1
			assert_between(v.y, roof_y - BrickShell.SLAB - 3.0 * BrickShell.VIGA_RADIUS, roof_y, "a beam under the roof")
	assert_gt(beams, 8 * BrickShell.VIGA_SIDES, "beams poke out of the front and back")
	for o: Array in _openings():
		var c: Vector3 = o[0]
		var top := c.y + float(o[2]) * 0.5
		var lintel := 0
		for v in wood:
			if v.distance_to(Vector3(c.x, top + BrickShell.LINTEL.x * 0.5, c.z)) < float(o[1]) * 0.5 + BrickShell.LINTEL.y + 0.4:
				lintel += 1
		assert_gt(lintel, 0, "a wooden lintel over the opening at %s" % c)
		var reveal := 0
		for v in _of(solid, OasisPalette.REVEAL):
			if absf(v.y - c.y) <= float(o[2]) * 0.5 + 0.01 and v.distance_to(c) < float(o[1]) * 0.5 + float(o[2]) * 0.5 + 0.3:
				reveal += 1
		assert_gt(reveal, 0, "a dark reveal in the opening at %s" % c)
	var shades := {}
	var colours: PackedColorArray = solid[1]
	for v in colours:
		for k in SpacePalette.SHADES.size():
			if _same(v, InteriorKit.solid(SpacePalette.shade(OasisPalette.BRICK, k))):
				shades[k] = true
	assert_eq(shades.size(), SpacePalette.SHADES.size(), "blocks in every shade of the brick")

## The round hut has its beams, its door's lintel and reveal; the crushed hut
## keeps beams only in its standing wall; the broken wall is laid in blocks.
func test_the_round_hut_the_crushed_hut_and_the_wall_are_adobe_too():
	BrickShell.round_hut(_kit, Transform3D.IDENTITY, 5.4, 3.0, 0.6)
	var solid := _solid()
	var out := 0
	for v in _of(solid, OasisPalette.WOOD):
		if Vector2(v.x, v.z).length() > 5.4 + 0.3:
			out += 1
	assert_gt(out, 4 * BrickShell.VIGA_SIDES, "the round hut's beams poke out")
	assert_gt(_of(solid, OasisPalette.REVEAL).size(), 0, "and its door is deep")
	var crushed := InteriorKit.new(_root)
	crushed.keep_arrays = true
	var size := Vector3(12, 3.2, 8)
	BrickShell.crushed(crushed, Transform3D.IDENTITY, size, 0.2)
	var broken := _solid(crushed)
	var beams_west := 0
	var beams_east := 0
	for v in _of(broken, OasisPalette.WOOD):
		if absf(v.z) > size.z * 0.5 + 0.3:
			if v.x < 0.0:
				beams_west += 1
			else:
				beams_east += 1
	assert_gt(beams_west, 0, "beams in the standing (west) wall")
	assert_lt(beams_east, beams_west, "fewer where it was crushed in")
	var run := InteriorKit.new(_root)
	run.keep_arrays = true
	BrickShell.wall(run, PackedVector3Array([Vector3(0, 0, 10), Vector3(2, 0.1, 10), Vector3(4, 0.15, 11)]), 2.6, 0.5)
	var shades := {}
	for c in (_solid(run)[1] as PackedColorArray):
		for k in SpacePalette.SHADES.size():
			if _same(c, InteriorKit.solid(SpacePalette.shade(OasisPalette.BRICK, k))):
				shades[k] = true
	assert_gt(shades.size(), 1, "the wall's blocks are shaded")
