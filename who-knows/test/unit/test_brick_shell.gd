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

func _is_wood(c: Color) -> bool:
	for k in SpacePalette.SHADES.size():
		if _same(c, InteriorKit.solid(SpacePalette.shade(OasisPalette.WOOD, k))):
			return true
	return false

func test_a_box_builds_alone():
	BrickShell.box(_kit, Transform3D.IDENTITY, SIZE, _openings(), 0.3)
	var solid := _solid()
	var vertices: PackedVector3Array = solid[0]
	assert_gt(vertices.size(), 100, "it has a shape")
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var wood := -INF
	for i in vertices.size():
		var v := vertices[i]
		lo = lo.min(v)
		# An open shutter swings out past the wall (Rework 2): measured apart.
		if _is_wood((solid[1] as PackedColorArray)[i]):
			wood = maxf(wood, v.x)
		else:
			hi = hi.max(v)
	assert_almost_eq(lo.y, -BrickShell.FOUNDATION - BrickShell.SUNK, 0.01, "its foundation stands under the frame (Rework 2)")
	assert_between(hi.y, SIZE.y - 0.01, SIZE.y + 0.3, "its parapet and its steps top it")
	assert_lt(absf(hi.x - SIZE.x * 0.5), BrickShell.FOUNDATION_PROUD + 0.02, "as wide as asked, its foundation proud")
	assert_lt(wood - SIZE.x * 0.5, 0.8 * 0.5 + 0.1, "a shutter swings out no further than its own width")
	var code := _code(PATH)
	for ident in RULES.GRID_SIDE:
		assert_null(RegEx.create_from_string("\\b%s\\b" % ident).search(code),
			"brick_shell.gd uses %s: it builds from (kit, frame, variety) alone" % ident)
	assert_true(RULES.REUSABLE_FILES.has(PATH), "and the rules test guards it")
	assert_true(RULES.PAINTING_FILES.has(PATH), "and its colours")

func test_openings_are_holes():
	# Asked open (Part C's doorway): since Rework 2 a shell's door is shut by default.
	var shapes := BrickShell.box_shapes(Transform3D.IDENTITY, SIZE, _openings(), 0.3, false)
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
	BrickShell.pier(_kit, InteriorKit.at(Vector3(0, 0, 32)), Vector3(1.2, 3.4, 1.2), 0.3)
	var allowed := [OasisPalette.BRICK, OasisPalette.BRICK_DARK, OasisPalette.SAIL, OasisPalette.SAIL_POLE,
		OasisPalette.REVEAL, OasisPalette.WOOD, OasisPalette.FOUNDATION, OasisPalette.FLOOR]
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

## Rework 1: a gate pier, a thick block of the brick `size` (x along the wall,
## y up, z across), its foot on the frame, one box its solid twin.
func test_a_pier_builds_alone_and_is_solid():
	var size := Vector3(1.2, 3.4, 1.2)
	BrickShell.pier(_kit, Transform3D.IDENTITY, size, 0.4)
	var vertices: PackedVector3Array = _solid()[0]
	assert_gt(vertices.size(), 24, "it has a shape")
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in vertices:
		lo = lo.min(v)
		hi = hi.max(v)
	assert_almost_eq(lo.y, 0.0, 0.01, "it stands on the frame")
	assert_between(hi.y, size.y - 0.01, size.y + 0.2, "as tall as asked, its cap on top")
	assert_between(hi.x - lo.x, size.x - 0.01, size.x + 0.3, "as thick as asked")
	var shapes := BrickShell.pier_shapes(Transform3D.IDENTITY, size, 0.4)
	assert_eq(shapes.size(), 1, "one box")
	_solid_body(shapes)
	await wait_physics_frames(2)
	var hit := _ray(Vector3(-3, 1.5, 0), Vector3(3, 1.5, 0))
	assert_false(hit.is_empty(), "solid")
	if not hit.is_empty():
		assert_almost_eq((hit["position"] as Vector3).x, -size.x * 0.5, 0.05, "at its face")

func test_a_round_hut_is_round_and_open_at_its_door():
	_solid_body(BrickShell.round_hut_shapes(Transform3D.IDENTITY, 5.4, 3.0, 0.5, false))
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
	var roof_y := SIZE.y - BrickShell.parapet(0.3)
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

# --- foundations, floors and doors (Rework 2) -----------------------------------

## The highest and lowest vertex of `colour` (or a shade) in `solid`.
func _span_of(solid: Array, colour: Color) -> Vector2:
	var lo := INF
	var hi := -INF
	for v in _of(solid, colour):
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	return Vector2(lo, hi)

## Rework 2: every shell stands on a foundation course FOUNDATION high over the
## ground (the frame is the floor, the ground FOUNDATION under it; the course's
## foot SUNK more), FOUNDATION_PROUD proud of its walls, in
## OasisPalette.FOUNDATION; a floor slab in OasisPalette.FLOOR fills the inside
## at the frame, the foundation's top.
func test_every_shell_stands_on_a_foundation_and_a_floor():
	var builds := {
		"box": func(kit: InteriorKit) -> void: BrickShell.box(kit, Transform3D.IDENTITY, SIZE, _openings(), 0.3),
		"round": func(kit: InteriorKit) -> void: BrickShell.round_hut(kit, Transform3D.IDENTITY, 4.0, 3.0, 0.6),
		"crushed": func(kit: InteriorKit) -> void: BrickShell.crushed(kit, Transform3D.IDENTITY, Vector3(7, 3.2, 5.5), 0.2),
	}
	for kind: String in builds:
		var kit := InteriorKit.new(_root)
		kit.keep_arrays = true
		builds[kind].call(kit)
		var solid := _solid(kit)
		var course := _span_of(solid, OasisPalette.FOUNDATION)
		assert_almost_eq(course.x, -BrickShell.FOUNDATION - BrickShell.SUNK, 0.01, "%s: the course's foot is sunk" % kind)
		assert_almost_eq(course.y, 0.0, 0.01, "%s: its top is the floor" % kind)
		var slab := _span_of(solid, OasisPalette.FLOOR)
		assert_almost_eq(slab.y, 0.0, 0.01, "%s: a floor slab at the foundation's top" % kind)
		var reach := 0.0
		for v in _of(solid, OasisPalette.FOUNDATION):
			reach = maxf(reach, absf(v.x))
		var wall := SIZE.x * 0.5 if kind == "box" else (4.0 if kind == "round" else 3.5)
		assert_between(reach, wall + BrickShell.FOUNDATION_PROUD - 0.02, wall + BrickShell.FOUNDATION_PROUD + 0.1,
			"%s: the course stands proud of the walls" % kind)
	assert_between(BrickShell.FOUNDATION, 0.25, 0.35, "about 0.3 m tall")

## A whole shell's door is shut: a ray through its middle meets its collider,
## and a window stays a hole. Asked open (Part C's doorway), it is a hole.
func test_shell_doors_are_shut():
	_solid_body(BrickShell.box_shapes(Transform3D.IDENTITY, SIZE, _openings(), 0.3))
	var round := BrickShell.round_hut_shapes(InteriorKit.at(Vector3(20, 0, 0)), 4.0, 3.0, 0.5)
	_solid_body(round)
	var open := BrickShell.box_shapes(InteriorKit.at(Vector3(-20, 0, 0)), SIZE, _openings(), 0.3, false)
	_solid_body(open)
	await wait_physics_frames(2)
	var door: Vector3 = _openings()[0][0]
	assert_false(_ray(door + Vector3(0, 0, -1.0), door + Vector3(0, 0, 1.0)).is_empty(), "the box's door is shut")
	var window: Vector3 = _openings()[1][0]
	assert_true(_ray(window + Vector3(1.0, 0, 0), window - Vector3(1.0, 0, 0)).is_empty(), "its window is open")
	assert_false(_ray(Vector3(20, 1.0, -6), Vector3(20, 1.0, -3.0)).is_empty(), "the round hut's door is shut")
	var far := door + Vector3(-20, 0, 0)
	assert_true(_ray(far + Vector3(0, 0, -1.0), far + Vector3(0, 0, 1.0)).is_empty(), "an open door is a hole")

## The floor is solid at the frame inside every shell, and the threshold stone
## before a door stands THRESHOLD_RISE over the ground, so the way in rises by
## steps no higher than that.
func test_the_floor_and_the_threshold_are_solid():
	_solid_body(BrickShell.box_shapes(Transform3D.IDENTITY, SIZE, _openings(), 0.3))
	await wait_physics_frames(2)
	var inside := _ray(Vector3(1.0, 1.0, 0.5), Vector3(1.0, -2.0, 0.5))
	assert_false(inside.is_empty(), "a floor inside")
	if not inside.is_empty():
		assert_almost_eq((inside["position"] as Vector3).y, 0.0, 0.01, "at the frame")
	var door: Vector3 = _openings()[0][0]
	var ground := -BrickShell.FOUNDATION
	var before := Vector3(door.x, 1.0, -SIZE.z * 0.5 - BrickShell.FOUNDATION_PROUD - 0.15)
	var step := _ray(before, before - Vector3(0, 3, 0))
	assert_false(step.is_empty(), "a threshold stone before the door")
	if not step.is_empty():
		var rise := (step["position"] as Vector3).y - ground
		assert_almost_eq(rise, BrickShell.THRESHOLD_RISE, 0.01, "a step up from the ground")
		assert_lte(-(step["position"] as Vector3).y, 0.15 + 0.001, "and a step up to the floor")
	assert_lte(BrickShell.THRESHOLD_RISE, 0.15)
	assert_lte(BrickShell.FOUNDATION - BrickShell.THRESHOLD_RISE, 0.15)

## No two shells look alike: the parapet's height and the beams' spacing
## follow the variety.
func test_variety_changes_the_parapet_and_the_beams():
	assert_ne(snappedf(BrickShell.parapet(0.1), 0.001), snappedf(BrickShell.parapet(0.8), 0.001), "parapets differ")
	var counts := {}
	for v in [0.05, 0.3, 0.55, 0.8]:
		counts[BrickShell.viga_spots(6.0, 2.8, [], v, 0).size()] = true
	assert_gt(counts.size(), 1, "the beams' spacing differs")

## Openings by variety: a door in the front; windows, each shuttered; a
## two-storey house an upper window; a wide door when asked.
func test_openings_for_a_shell():
	var low := BrickShell.openings_for(Vector3(8, 3, 5.5), 0.4)
	var doors := low.filter(func(o: Array) -> bool: return (o[0] as Vector3).y - float(o[2]) * 0.5 < 0.02)
	assert_eq(doors.size(), 1, "one door")
	assert_gt(low.size(), 1, "and windows")
	var tall := BrickShell.openings_for(Vector3(7.5, 5.6, 6), 0.9)
	assert_true(tall.any(func(o: Array) -> bool: return (o[0] as Vector3).y > 3.0), "an upper window")
	var wide := BrickShell.openings_for(Vector3(11, 2.9, 4.6), 0.4, 2.4)
	assert_true(wide.any(func(o: Array) -> bool: return absf(float(o[1]) - 2.4) < 0.01), "a wide double door")

## The broken wall stands on its foundation course too, and where it ends at a
## breach its courses step down to a stub.
func test_a_wall_has_a_footing_and_steps_down_at_a_breach():
	var points := PackedVector3Array()
	for k in 5:
		points.append(Vector3(k * 2.0, 0.0, 0))
	BrickShell.wall(_kit, points, 2.6, 0.5, [false, true])
	var solid := _solid()
	var course := _span_of(solid, OasisPalette.FOUNDATION)
	assert_almost_eq(course.x, -BrickShell.SUNK, 0.01, "its footing's foot is sunk")
	assert_almost_eq(course.y, BrickShell.FOUNDATION, 0.02, "and stands about 0.3 m over the ground")
	# Each segment's top, from its solid box (the mesh's vertices are at its
	# ends, shared with its neighbours'), from the breach in.
	var shapes := BrickShell.wall_shapes(points, 2.6, 0.5, [false, true])
	assert_eq(shapes.size(), points.size() - 1 + BrickShell.BREAK_STEPS.size(), "the steps are solid too")
	var segs := []
	for c in shapes:
		segs.append([c.transform.origin.x, c.transform.origin.y + (c.shape as BoxShape3D).size.y * 0.5])
		c.free()
	segs.sort_custom(func(p: Array, q: Array) -> bool: return p[0] > q[0])
	var tops := []
	for k in BrickShell.BREAK_STEPS.size():
		tops.append(float(segs[k][1]))
	gut.p("the breach end's tops: %s" % str(tops))
	assert_lt(tops[0], 1.0, "a stub at the very end")
	for k in range(1, tops.size()):
		assert_gt(tops[k], tops[k - 1] + 0.2, "stepping down toward the breach")
	assert_gt(tops[tops.size() - 1] - tops[0], 1.2, "a long way down from the whole wall")
	var stub := 0.0
	for v in (solid[0] as PackedVector3Array):
		if v.x > 8.0 - float(BrickShell.BREAK_STEPS[0][0]) + 0.05:
			stub = maxf(stub, v.y)
	assert_almost_eq(stub, tops[0], 0.15, "and the mesh steps as its solid does")
