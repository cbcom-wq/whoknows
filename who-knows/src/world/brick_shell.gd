class_name BrickShell
extends RefCounted

## Mud-brick buildings outside (desert world phase 3, Task 9): thick chunky
## walls with a bevelled parapet and a flat roof of slabs, a few proud brick
## courses and chunky lintels; a round hut; a hut crushed in; a broken brick
## wall along a line; rubble; a brick patch for a flat wall; a cloth shade
## sail on four poles; and a gate's pier (Rework 1's ring wall). Adobe since Checkpoint B: big sun-baked blocks a shade
## each on the outer faces, wooden roof beams (vigas) poking out under the
## parapet, a stepped parapet, and deep, dark reveals under wooden lintels. Built from a kit, a frame and a variety alone, in
## OasisPalette's brick and cloth: it never sees a grid or a place, so Part C's
## BaseExterior builds its homes with it too.
##
## A shell's frame `f` stands at its walls' foot, its y up, its front (the
## door's side) toward -z. The walls start SUNK under the floor a caller wants,
## so no gap shows where they meet the ground.
##
## Every shell has a twin with the same arguments less the kit, `<name>_shapes`,
## which gives its solid parts as box CollisionShape3Ds for the caller's one
## StaticBody3D (BodyProxy.LAYER outside). The twins follow the walls piece for
## piece (each wall piece, column and run segment is one box; openings stay
## open); a roof is one box (two crossed for the round hut), a fallen slab one
## box; courses, lintels, copings, rubble, patches and sails have none.

## A shell's walls, and the broken wall's, m thick.
const WALL := 0.45
const RUN := 0.5
## How far a wall's foot is under the ground it stands on, m.
const SUNK := 0.05
const BEVEL := 0.04
## The parapet stands this far over the roof; the roof's slabs are SLAB thick
## and about SLAB_SPAN wide.
const PARAPET := 0.35
const SLAB := 0.22
const SLAB_SPAN := 1.7
## A roof's slabs are laid in rows no longer than this, m.
const SLAB_LONG := 4.0
## A coping (the parapet's bevelled rim): height and how far it stands proud.
const COPING := Vector2(0.12, 0.06)
## A proud course: height and how far proud; at these shares of the height to
## the roof.
const COURSE := Vector2(0.1, 0.03)
const COURSES: Array[float] = [0.3, 0.66]
## A lintel, of wood: height, overhang each side and how far proud.
const LINTEL := Vector3(0.22, 0.22, 0.07)
## Adobe (Checkpoint B). The outer faces are laid in big blocks BLOCK long and
## a course high, each a SpacePalette shade of BRICK, BLOCK_SKIN proud of the
## wall (the darkest shade), with BLOCK_JOINT between them where it shows.
const BLOCK := Vector2(1.1, 0.5)
const BLOCK_SKIN := 0.012
const BLOCK_JOINT := 0.025
## The roof's beams (vigas): logs VIGA_RADIUS thick with VIGA_SIDES facets,
## about VIGA_SPAN apart, poking VIGA_OUT out of the wall just under the roof.
const VIGA_RADIUS := 0.11
const VIGA_SIDES := 6
const VIGA_SPAN := 1.3
const VIGA_OUT := 0.5
## The parapet steps up at its corners (and the middle of a long wall):
## STEP_UP high over the coping and STEP_LONG long, softly rounded.
const STEP_UP := 0.18
const STEP_LONG := 0.85
## An opening's reveal: lined REVEAL_LINING thick in OasisPalette.REVEAL
## through the wall, framed outside by a SURROUND (width, how far proud) in
## the wall's own brick.
const REVEAL_LINING := 0.035
const SURROUND := Vector2(0.18, 0.05)
## The round hut's sides, and the door every round hut has in its front.
const HUT_SIDES := 12
const DOOR := Vector2(1.1, 2.0)
## A crushed hut's walls break into columns about this wide; what fell in
## lies no higher than FALLEN_TOP of its height.
const COLUMN := 1.0
const FALLEN_TOP := 0.55
## The broken wall: its top is RAGGED to 1 of `height`, its top edges chamfered
## CHAMFER; its course at BAND_AT over the ground; segments meeting at a bend
## overlap by BEND_OVERLAP.
const RAGGED := 0.54
const CHAMFER := 0.06
const BAND_AT := 0.5
const BEND_OVERLAP := 0.1
## A brick of a patch, m: width and height (with its joint), and how far proud.
const PATCH_BRICK := Vector2(0.42, 0.2)
const PATCH_PROUD := 0.06
## A shade sail: the cloth's middle height, the front's lift over the back,
## its sag at the middle and its cells a side; the poles' radius.
const SAIL_HEIGHT := 2.4
const SAIL_LIFT := 0.5
const SAIL_SAG := 0.3
const SAIL_CELLS := 4
const POLE := 0.07

# --- the box ------------------------------------------------------------------

## A box of `size` (x wide, y to the parapet's top, z deep) at `f`: four thick
## walls, `openings` (each [centre in f, width, height]) left as holes with a
## chunky lintel over each, two proud courses, a bevelled coping and a flat
## roof of slabs PARAPET under the top. `variety` (0 to 1) shades the walls.
static func box(kit: InteriorKit, f: Transform3D, size: Vector3, openings: Array, variety: float) -> void:
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	var walls := _walls(size)
	var roof_y := size.y - PARAPET
	for i in walls.size():
		var w: Transform3D = walls[i][0]
		var length: float = walls[i][1]
		var holes := _holes(w, length, openings)
		var pieces := _pieces(length, size.y, holes)
		for p: Array in pieces:
			kit.bevel_box(InteriorKit.Batch.SOLID, f * w * _span(p), _span_size(p, WALL), BEVEL, _base())
		_blocks(kit, f * w, length, pieces, WALL, size.y - COPING.x * 0.5, variety, i)
		# The front and back walls run over the corners; the sides fit between.
		var reach := length * 0.5 + (COURSE.y if i < 2 else -COURSE.y)
		for share in COURSES:
			_course(kit, f * w, -reach, reach, _course_y(roof_y, share), holes, WALL, dark)
		for h: Array in holes:
			_reveal(kit, f * w, h, h[3], h[3] < size.y - LINTEL.x, variety, i)
			_lintel(kit, f * w, h, size.y)
		var rim := length + (2.0 * COPING.y if i < 2 else -2.0 * COPING.y)
		var drop := 0.0 if i < 2 else 0.005
		var coping_top := size.y + COPING.x - 0.03 - drop
		kit.bevel_box(InteriorKit.Batch.SOLID, f * w * InteriorKit.at(Vector3(0, coping_top - COPING.x * 0.5, 0)),
			Vector3(rim, COPING.x, WALL + 2.0 * COPING.y), 0.03, dark)
		if i < 2:
			# The beams span front to back, so they show on these two walls,
			# and the parapet steps up at the corners over them.
			_vigas(kit, f * w, length - 2.0 * WALL, roof_y, holes, variety, i)
			_steps(kit, f * w, rim, coping_top, variety, i)
	var span := Vector2(size.x - 2.0 * WALL, size.z - 2.0 * WALL)
	for slab: Array in _roof_slabs(span, roof_y):
		kit.bevel_box(InteriorKit.Batch.SOLID, f * (slab[0] as Transform3D), slab[1], 0.03, _roof(variety, int(slab[2])))

## box's solid parts: each wall piece and the roof.
static func box_shapes(f: Transform3D, size: Vector3, openings: Array, _variety: float) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for wall: Array in _walls(size):
		var w: Transform3D = wall[0]
		for p: Array in _pieces(wall[1], size.y, _holes(w, wall[1], openings)):
			out.append(_shape(f * w * _span(p), _span_size(p, WALL)))
	var span := Vector2(size.x - 2.0 * WALL, size.z - 2.0 * WALL)
	out.append(_shape(f * InteriorKit.at(Vector3(0, size.y - PARAPET - SLAB * 0.5, 0)), Vector3(span.x, SLAB, span.y)))
	return out

# --- the round hut --------------------------------------------------------------

## A round hut at `f`: HUT_SIDES chunky wall segments whose outer faces lie
## `radius` out, `height` to the parapet's top, a door in its front (-z), two
## courses, a coping and a flat roof.
static func round_hut(kit: InteriorKit, f: Transform3D, radius: float, height: float, variety: float) -> void:
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	var roof_y := height - PARAPET
	var side := _hut_side(radius)
	for i in HUT_SIDES:
		var w := _hut_wall(radius, i)
		var holes := _hut_holes(i)
		var pieces := _pieces(side, height, holes)
		for p: Array in pieces:
			kit.bevel_box(InteriorKit.Batch.SOLID, f * w * _span(p), _span_size(p, WALL), BEVEL, _base())
		_blocks(kit, f * w, side, pieces, WALL, height - COPING.x * 0.5, variety, i)
		for share in COURSES:
			_course(kit, f * w, -side * 0.5, side * 0.5, _course_y(roof_y, share), holes, WALL, dark)
		for h: Array in holes:
			_reveal(kit, f * w, h, h[3], h[3] < height - LINTEL.x, variety, i)
			_lintel(kit, f * w, h, height)
		var coping_top := height + COPING.x - 0.03
		kit.bevel_box(InteriorKit.Batch.SOLID, f * w * InteriorKit.at(Vector3(0, coping_top - COPING.x * 0.5, 0)),
			Vector3(side + 0.08, COPING.x, WALL + 2.0 * COPING.y), 0.03, dark)
		# A beam out of every other segment, none over the door; the parapet
		# steps up over every third, the door's first.
		if i % 2 == 1:
			_viga(kit, f * w, 0.0, roof_y, variety, i)
		if i % 3 == 0:
			_step(kit, f * w, 0.0, side * 0.6, STEP_UP, coping_top, variety, i)
	# The roof: one HUT_SIDES-sided slab inside the walls.
	var ring := PackedVector3Array()
	var corner := (radius - WALL) / cos(PI / HUT_SIDES)
	for i in HUT_SIDES:
		var a := PI + TAU * (i + 0.5) / HUT_SIDES
		ring.append(Vector3(sin(a) * corner, 0, cos(a) * corner))
	_slab(kit, f, ring, roof_y - SLAB, roof_y, _roof(variety, 0))

## round_hut's solid parts: each wall piece, and the roof as two crossed boxes.
static func round_hut_shapes(f: Transform3D, radius: float, height: float, _variety: float) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	var side := _hut_side(radius)
	for i in HUT_SIDES:
		var w := _hut_wall(radius, i)
		for p: Array in _pieces(side, height, _hut_holes(i)):
			out.append(_shape(f * w * _span(p), _span_size(p, WALL)))
	var square := 2.0 * (radius - WALL) * cos(PI * 0.25)
	for turn in [0.0, PI * 0.25]:
		out.append(_shape(f * Transform3D(Basis(Vector3.UP, turn), Vector3(0, height - PARAPET - SLAB * 0.5, 0)),
			Vector3(square, SLAB, square)))
	return out

static func _hut_side(radius: float) -> float:
	return 2.0 * radius * tan(PI / HUT_SIDES)

## Segment `i`'s frame: segment 0 faces the front (-z).
static func _hut_wall(radius: float, i: int) -> Transform3D:
	var turn := Basis(Vector3.UP, PI + TAU * i / HUT_SIDES)
	return Transform3D(turn, turn * Vector3(0, 0, radius - WALL * 0.5))

static func _hut_holes(i: int) -> Array:
	return [[-DOOR.x * 0.5, DOOR.x * 0.5, 0.0, DOOR.y]] if i == 0 else []

# --- the crushed hut ------------------------------------------------------------

## A hut of `size` crushed in from its +x side: the walls there broken down to
## stumps and falling away along the front and back toward it, the far wall
## standing nearly whole, no coping; the roof's slabs fallen in at angles, no
## higher than FALLEN_TOP of its height; and rubble over the floor (taken to be
## SUNK over `f`). A door stays in the front, at its whole end.
static func crushed(kit: InteriorKit, f: Transform3D, size: Vector3, variety: float) -> void:
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	var walls := _walls(size)
	var door := _crushed_door(size)
	for i in walls.size():
		var w: Transform3D = walls[i][0]
		var length: float = walls[i][1]
		var holes := _holes(w, length, [door])
		var pieces := _crushed_pieces(i, w, length, size, holes, variety)
		for p: Array in pieces:
			kit.bevel_box(InteriorKit.Batch.SOLID, f * w * _span(p), _span_size(p, WALL), BEVEL, _base())
			for share in COURSES:
				var y := _course_y(size.y - PARAPET, share)
				if p[2] < y - COURSE.x and p[3] > y + COURSE.x:
					kit.box(InteriorKit.Batch.SOLID, f * w * InteriorKit.at(Vector3((p[0] + p[1]) * 0.5, y, 0)),
						Vector3(p[1] - p[0], COURSE.x, WALL + 2.0 * COURSE.y), dark)
		_blocks(kit, f * w, length, pieces, WALL, size.y, variety, i)
		for h: Array in holes:
			# The jambs stand as high as their columns; the head and its
			# lintel only where the wall still rises over it.
			var jamb := minf(_column_height(i, w, length, size, h[0] - 0.1, variety),
				_column_height(i, w, length, size, h[1] + 0.1, variety))
			var headed: bool = _column_height(i, w, length, size, (h[0] + h[1]) * 0.5, variety) > h[3] + LINTEL.x
			_reveal(kit, f * w, h, minf(jamb, h[3]), headed, variety, i)
			if headed:
				_lintel(kit, f * w, h, size.y)
		# The beams still in the standing wall, over the far (whole) end.
		if i < 2:
			for v: Array in _viga_spots(length - 2.0 * WALL, size.y - PARAPET, holes, variety, i):
				if _column_height(i, w, length, size, v[0], variety) > size.y - PARAPET + 0.05:
					_viga(kit, f * w, v[0], size.y - PARAPET, variety, int(v[1]))
	for slab: Array in _fallen(size, variety):
		kit.bevel_box(InteriorKit.Batch.SOLID, f * (slab[0] as Transform3D), slab[1], 0.03, _roof(variety, int(slab[2])))
	var span := Vector2(size.x - 2.0 * WALL, size.z - 2.0 * WALL)
	rubble(kit, f * InteriorKit.at(Vector3(span.x * 0.12, 0, 0)), span * Vector2(0.72, 0.8),
		int(span.x * span.y * 0.35), variety, func(_x: float, _z: float) -> float: return SUNK)

## crushed's solid parts: each standing column of wall and each fallen slab.
static func crushed_shapes(f: Transform3D, size: Vector3, variety: float) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	var walls := _walls(size)
	for i in walls.size():
		var w: Transform3D = walls[i][0]
		var length: float = walls[i][1]
		for p: Array in _crushed_pieces(i, w, length, size, _holes(w, length, [_crushed_door(size)]), variety):
			out.append(_shape(f * w * _span(p), _span_size(p, WALL)))
	for slab: Array in _fallen(size, variety):
		out.append(_shape(f * (slab[0] as Transform3D), slab[1]))
	return out

static func _crushed_door(size: Vector3) -> Array:
	return [Vector3(-size.x * 0.25, DOOR.y * 0.5, -size.z * 0.5 + WALL * 0.5), DOOR.x, DOOR.y]

## How high wall `i`'s column at `u` along it stands: low on the broken (+x)
## side, nearly whole on the far one.
static func _column_height(i: int, w: Transform3D, length: float, size: Vector3, u: float, variety: float) -> float:
	var column := floorf((u + length * 0.5) / COLUMN)
	var n := _noise(variety, column, float(i) + 0.5)
	var x := (w * Vector3(u, 0, 0)).x
	var t := clampf((x + size.x * 0.5) / size.x, 0.0, 1.0)
	var share: float
	match i:
		2:
			share = 0.1 + 0.22 * n
		3:
			share = 0.82 + 0.18 * n
		_:
			share = lerpf(0.96, 0.2, pow(t, 1.3)) + (n - 0.5) * 0.24
	return size.y * clampf(share, 0.08, 1.0)

## Wall `i`'s pieces, [u0, u1, y0, y1], as columns of their own heights, cut
## round `holes`.
static func _crushed_pieces(i: int, w: Transform3D, length: float, size: Vector3, holes: Array,
		variety: float) -> Array:
	var cuts: Array[float] = [-length * 0.5, length * 0.5]
	var k := 1
	while -length * 0.5 + k * COLUMN < length * 0.5 - 0.2:
		cuts.append(-length * 0.5 + k * COLUMN)
		k += 1
	for h: Array in holes:
		cuts.append(h[0])
		cuts.append(h[1])
	cuts.sort()
	var out := []
	for j in cuts.size() - 1:
		var u0 := cuts[j]
		var u1 := cuts[j + 1]
		if u1 - u0 < 0.05:
			continue
		var top := _column_height(i, w, length, size, (u0 + u1) * 0.5, variety)
		var bottom := 0.0
		for h: Array in holes:
			if (u0 + u1) * 0.5 > h[0] and (u0 + u1) * 0.5 < h[1]:
				bottom = h[3]
		if top > bottom + 0.15:
			out.append([u0, u1, bottom, top])
	return out

## The roof's slabs fallen in: [frame in the shell's, size, index] each, tilted
## down toward the broken side and rolled, resting on the floor, none higher
## than FALLEN_TOP of the height.
static func _fallen(size: Vector3, variety: float) -> Array:
	var span := Vector2(size.x - 2.0 * WALL, size.z - 2.0 * WALL)
	var n := maxi(1, ceili(span.x / SLAB_SPAN))
	var width := span.x / n
	var top := size.y * FALLEN_TOP
	var out := []
	for k in n:
		var t := (k + 0.5) / n
		var a := _noise(variety, k, 7.0)
		var b := _noise(variety, k, 8.0)
		var c := _noise(variety, k, 9.0)
		var slab := Vector3(width - 0.08, SLAB, span.y * (0.72 + 0.2 * c))
		var tilt := lerpf(0.55, 0.12, t) + (a - 0.5) * 0.2
		var roll := (b - 0.5) * 0.35
		var basis := Basis.from_euler(Vector3(roll, (c - 0.5) * 0.3, -tilt))
		var lo := INF
		var hi := -INF
		for corner in _corners(slab):
			var y := (basis * corner).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		var tries := 0
		while hi - lo > top - SUNK - 0.04 and tries < 12:
			tilt *= 0.8
			roll *= 0.8
			basis = Basis.from_euler(Vector3(roll, (c - 0.5) * 0.3, -tilt))
			lo = INF
			hi = -INF
			for corner in _corners(slab):
				var y := (basis * corner).y
				lo = minf(lo, y)
				hi = maxf(hi, y)
			tries += 1
		var at := Vector3(-span.x * 0.5 + width * (k + 0.5), SUNK + 0.04 - lo, (a - 0.5) * 0.5)
		out.append([Transform3D(basis, at), slab, k])
	return out

static func _corners(size: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				out.append(Vector3(size.x * sx, size.y * sy, size.z * sz))
	return out

# --- the broken wall ------------------------------------------------------------

## A brick wall RUN thick along `points` (in the kit's space, each on the
## ground: a caller samples the ground about every 2 m), its foot following
## the ground SUNK under it from point to point. Each segment's top is its own,
## from RAGGED to 1 of `height` over its lower end by `variety`, so the top is
## stepped and broken; its top edges are chamfered, and one proud course runs
## BAND_AT over the ground.
static func wall(kit: InteriorKit, points: PackedVector3Array, height: float, variety: float) -> void:
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	for k in points.size() - 1:
		var seg := _run_segment(points, k, height, variety)
		if seg.is_empty():
			continue
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var top: float = seg[2]
		var dir: Vector3 = seg[3]
		var side := dir.cross(Vector3.UP)
		_prism(kit, a, b, top, side, _base())
		_run_blocks(kit, a, b, top - CHAMFER, side, variety, k)
		var ground := (a.y + b.y) * 0.5 + SUNK
		if top - maxf(a.y, b.y) > BAND_AT + 0.4:
			var slope := (b - a).normalized()
			var up := side.cross(slope).normalized()
			var mid := (a + b) * 0.5
			mid.y = ground + BAND_AT
			kit.box(InteriorKit.Batch.SOLID, Transform3D(Basis(slope, up, side), mid),
				Vector3(a.distance_to(b) - 0.04, COURSE.x, RUN + 2.0 * COURSE.y), dark)

## wall's solid parts: a box a segment, from its lower foot to its top.
static func wall_shapes(points: PackedVector3Array, height: float, variety: float) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for k in points.size() - 1:
		var seg := _run_segment(points, k, height, variety)
		if seg.is_empty():
			continue
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var top: float = seg[2]
		var dir: Vector3 = seg[3]
		var foot := minf(a.y, b.y)
		var mid := (a + b) * 0.5
		mid.y = (foot + top) * 0.5
		var length := Vector2(b.x - a.x, b.z - a.z).length()
		out.append(_shape(Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)), mid), Vector3(length, top - foot, RUN)))
	return out

## Segment `k` of a run: [its foot at the start and the end (SUNK under the
## ground, stretched BEND_OVERLAP where the run bends), its top, its
## horizontal direction], or [] for a segment with no length.
static func _run_segment(points: PackedVector3Array, k: int, height: float, variety: float) -> Array:
	var a := points[k]
	var b := points[k + 1]
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	if flat.length() < 0.01:
		return []
	var dir := flat.normalized()
	var top := minf(a.y, b.y) + height * lerpf(RAGGED, 1.0, _noise(variety, k, 5.3))
	var start := a - Vector3(0, SUNK, 0)
	var end := b - Vector3(0, SUNK, 0)
	if k > 0 and _bends(points[k - 1], a, b):
		start -= dir * BEND_OVERLAP
	if k + 2 < points.size() and _bends(a, b, points[k + 2]):
		end += dir * BEND_OVERLAP
	return [start, end, top, dir]

static func _bends(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var u := Vector2(b.x - a.x, b.z - a.z).normalized()
	var v := Vector2(c.x - b.x, c.z - b.z).normalized()
	return u.dot(v) < 0.999

## A segment of wall from foot `a` to foot `b` (its two feet may differ), up
## to a flat `top` with chamfered edges, RUN thick across `side`.
static func _prism(kit: InteriorKit, a: Vector3, b: Vector3, top: float, side: Vector3, colour: Color) -> void:
	var h := RUN * 0.5
	# Across the wall and up; the first and last are its feet, at each end's own.
	var profile := [Vector2(-h, 0), Vector2(-h, top - CHAMFER), Vector2(-h + CHAMFER, top),
		Vector2(h - CHAMFER, top), Vector2(h, top - CHAMFER), Vector2(h, 0)]
	var at_a := PackedVector3Array()
	var at_b := PackedVector3Array()
	for i in profile.size():
		var p: Vector2 = profile[i]
		var foot := i == 0 or i == profile.size() - 1
		at_a.append(Vector3(a.x, a.y if foot else p.y, a.z) + side * p.x)
		at_b.append(Vector3(b.x, b.y if foot else p.y, b.z) + side * p.x)
	var normals := [-side, (Vector3.UP - side).normalized(), Vector3.UP, (Vector3.UP + side).normalized(), side]
	for i in 5:
		kit.quad(InteriorKit.Batch.SOLID, at_a[i], at_b[i], at_b[i + 1], at_a[i + 1], normals[i], colour)
	var along := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	for i in range(1, 5):
		kit.tri(InteriorKit.Batch.SOLID, at_a[0], at_a[i], at_a[i + 1], -along, colour)
		kit.tri(InteriorKit.Batch.SOLID, at_b[0], at_b[i], at_b[i + 1], along, colour)

# --- rubble, patches, sails -----------------------------------------------------

## `count` broken bricks and lumps over an ellipse `spread` across (x and z,
## m) at `f`, thicker toward its middle, turned and tipped every way, each
## resting with its lowest corner just under the ground: `floor_of(x, z)` is
## the ground's height in f's terms (f's plane when none is given).
static func rubble(kit: InteriorKit, f: Transform3D, spread: Vector2, count: int, variety: float,
		floor_of := Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(variety * 100003.0) * 31 + count
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	for i in count:
		var rho := pow(rng.randf(), 0.75)
		var theta := rng.randf() * TAU
		var x := spread.x * 0.5 * rho * cos(theta)
		var z := spread.y * 0.5 * rho * sin(theta)
		var big := rng.randf() * (1.0 - 0.6 * rho)
		var size := Vector3(lerpf(0.3, 0.9, big) * rng.randf_range(0.8, 1.2), lerpf(0.15, 0.45, big), lerpf(0.22, 0.6, big))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45)))
		var shade := rng.randi_range(0, SpacePalette.SHADES.size() - 1)
		var is_dark := rng.randf() < 0.25
		var lo := INF
		for corner in _corners(size):
			lo = minf(lo, (basis * corner).y)
		var ground := float(floor_of.call(x, z)) if floor_of.is_valid() else 0.0
		var colour := dark if is_dark else InteriorKit.solid(SpacePalette.shade(OasisPalette.BRICK, shade))
		kit.bevel_box(InteriorKit.Batch.SOLID, f * Transform3D(basis, Vector3(x, ground - SUNK * 0.8 - lo, z)),
			size, 0.03, colour)

## A patch of brick `size` (x and y, m) on a flat wall at `f` (its xy plane on
## the wall's face, facing +z): rows of bricks PATCH_PROUD proud, staggered,
## their ends ragged by `variety`, a few in the dark brick.
static func patch(kit: InteriorKit, f: Transform3D, size: Vector2, variety: float) -> void:
	var rows := maxi(1, roundi(size.y / PATCH_BRICK.y))
	var height := size.y / rows
	for r in rows:
		var y := -size.y * 0.5 + height * (r + 0.5)
		var from := -size.x * 0.5 + (_noise(variety, r, 11.0) - 0.5) * PATCH_BRICK.x * 0.8
		var to := size.x * 0.5 + (_noise(variety, r, 12.0) - 0.5) * PATCH_BRICK.x * 0.8
		var x := from + (PATCH_BRICK.x * 0.5 if r % 2 == 1 else 0.0)
		var k := 0
		while x < to - 0.1:
			var w := minf(PATCH_BRICK.x, to - x)
			var n := _noise(variety, r * 7 + k, 13.0)
			var colour := InteriorKit.solid(OasisPalette.BRICK_DARK) if n > 0.85 \
				else InteriorKit.solid(SpacePalette.shade(OasisPalette.BRICK, int(n * 2.99)))
			kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(x + w * 0.5, y, PATCH_PROUD * 0.5)),
				Vector3(w - 0.03, height - 0.03, PATCH_PROUD), 0.015, colour)
			x += PATCH_BRICK.x
			k += 1

## A cloth shade sail `size` (x and z, m) at `f` (on the ground): four dark
## poles, the front pair (-z) SAIL_LIFT higher than the back, and the cloth
## between their tops sagging up to SAIL_SAG at its middle, both faces drawn,
## in faded stripes. `variety` sets the sag and a little skew.
static func sail(kit: InteriorKit, f: Transform3D, size: Vector2, variety: float) -> void:
	var pole := InteriorKit.solid(OasisPalette.SAIL_POLE)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	var tops: Array[Vector3] = []
	for i in 4:
		var c: Vector3 = corners[i]
		var lift := SAIL_LIFT * (0.5 if c.z < 0.0 else -0.5) + (_noise(variety, i, 15.0) - 0.5) * 0.2
		var top := Vector3(c.x, SAIL_HEIGHT + lift, c.z)
		kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(c.x, -0.15, c.z), f * (top + Vector3(0, 0.12, 0)), POLE, pole)
		tops.append(Vector3(c.x * 0.97, top.y, c.z * 0.97))
	var sag := SAIL_SAG * (0.7 + 0.6 * variety)
	var grid := []
	for j in SAIL_CELLS + 1:
		var row := []
		for i in SAIL_CELLS + 1:
			var u := float(i) / SAIL_CELLS
			var v := float(j) / SAIL_CELLS
			var p: Vector3 = tops[0].lerp(tops[1], u).lerp(tops[3].lerp(tops[2], u), v)
			p.y -= sag * (1.0 - pow(2.0 * u - 1.0, 2)) * (1.0 - pow(2.0 * v - 1.0, 2))
			row.append(f * p)
		grid.append(row)
	for j in SAIL_CELLS:
		for i in SAIL_CELLS:
			var colour := InteriorKit.solid(SpacePalette.shade(OasisPalette.SAIL, 1 if (i >> 1) % 2 == 0 else 0))
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			for t: Array in [[a, b, c], [a, c, d]]:
				var p0: Vector3 = t[0]
				var p1: Vector3 = t[1]
				var p2: Vector3 = t[2]
				var n := (p1 - p0).cross(p2 - p0).normalized()
				if n.dot(f.basis.y) < 0.0:
					n = -n
				kit.tri(InteriorKit.Batch.SOLID, p0, p1, p2, n, colour)
				kit.tri(InteriorKit.Batch.SOLID, p0, p1, p2, -n, colour)

# --- the gate's piers ----------------------------------------------------------

## A gate pier at `f` (its foot, x along the wall, z across it): a thick block
## `size` high in the wall's adobe, its four faces laid in blocks, under a
## bevelled coping COPING.x thick that stands COPING.y proud all round, the
## coping's top at `size.y`.
static func pier(kit: InteriorKit, f: Transform3D, size: Vector3, variety: float) -> void:
	var body := size.y - COPING.x
	kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, body * 0.5, 0)), Vector3(size.x, body, size.z),
		BEVEL, _base())
	for i in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * i)
		var length := size.x if i % 2 == 0 else size.z
		var thick := size.z if i % 2 == 0 else size.x
		_blocks(kit, f * Transform3D(turn, Vector3.ZERO), length, [[-length * 0.5, length * 0.5, 0.0, body]], thick, body,
			variety, 40 + i)
	kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, size.y - COPING.x * 0.5, 0)),
		Vector3(size.x + 2.0 * COPING.y, COPING.x, size.z + 2.0 * COPING.y), 0.03,
		InteriorKit.solid(OasisPalette.BRICK_DARK))

## pier's solid part: one box.
static func pier_shapes(f: Transform3D, size: Vector3, _variety: float) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = [_shape(f * InteriorKit.at(Vector3(0, size.y * 0.5, 0)), size)]
	return out

# --- shared ------------------------------------------------------------------

## A box's four walls: [frame (in the shell's frame: at the wall's foot and
## middle, x along it, z out of the box), length]. Back (+z) and front (-z)
## run the whole width; the sides fit between them.
static func _walls(size: Vector3) -> Array:
	var hx := size.x * 0.5 - WALL * 0.5
	var hz := size.z * 0.5 - WALL * 0.5
	var inner := size.z - 2.0 * WALL
	return [
		[Transform3D(Basis.IDENTITY, Vector3(0, 0, hz)), size.x],
		[Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -hz)), size.x],
		[Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(hx, 0, 0)), inner],
		[Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-hx, 0, 0)), inner],
	]

## The openings that lie in wall `w` (of `length`), as [u0, u1, y0, y1] along
## it, in order.
static func _holes(w: Transform3D, length: float, openings: Array) -> Array:
	var out := []
	for o: Array in openings:
		var c: Vector3 = w.affine_inverse() * (o[0] as Vector3)
		if absf(c.z) > WALL or absf(c.x) > length * 0.5:
			continue
		var half_w := float(o[1]) * 0.5
		var half_h := float(o[2]) * 0.5
		out.append([maxf(c.x - half_w, -length * 0.5), minf(c.x + half_w, length * 0.5), maxf(c.y - half_h, 0.0), c.y + half_h])
	out.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	return out

## A wall `length` long and `height` high cut round `holes`: [u0, u1, y0, y1]
## per piece: whole-height piers between the holes, and the wall under and
## over each.
static func _pieces(length: float, height: float, holes: Array) -> Array:
	var out := []
	var cursor := -length * 0.5
	for h: Array in holes:
		if h[0] > cursor + 0.01:
			out.append([cursor, h[0], 0.0, height])
		if h[2] > 0.02:
			out.append([h[0], h[1], 0.0, h[2]])
		if h[3] < height - 0.02:
			out.append([h[0], h[1], h[3], height])
		cursor = maxf(cursor, h[1])
	if cursor < length * 0.5 - 0.01:
		out.append([cursor, length * 0.5, 0.0, height])
	return out

static func _span(p: Array) -> Transform3D:
	return InteriorKit.at(Vector3((p[0] + p[1]) * 0.5, (p[2] + p[3]) * 0.5, 0))

static func _span_size(p: Array, thick: float) -> Vector3:
	return Vector3(p[1] - p[0], p[3] - p[2], thick)

## Where the proud course at `share` of the height to a roof at `roof_y`
## runs: on the joint between two courses of blocks nearest it.
static func _course_y(roof_y: float, share: float) -> float:
	return maxi(1, roundi(roof_y * share / BLOCK.y)) * BLOCK.y

## A proud course at `y` along wall frame `w` from `u0` to `u1`, broken where a
## hole crosses it, stopping just short of each jamb.
static func _course(kit: InteriorKit, w: Transform3D, u0: float, u1: float, y: float, holes: Array, thick: float,
		colour: Color) -> void:
	var runs := [[u0, u1]]
	for h: Array in holes:
		if h[2] > y + COURSE.x or h[3] < y - COURSE.x:
			continue
		var next := []
		for r: Array in runs:
			if h[1] <= r[0] or h[0] >= r[1]:
				next.append(r)
				continue
			if h[0] - 0.03 > r[0]:
				next.append([r[0], h[0] - 0.03])
			if h[1] + 0.03 < r[1]:
				next.append([h[1] + 0.03, r[1]])
		runs = next
	for r: Array in runs:
		if r[1] - r[0] > 0.05:
			kit.box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3((r[0] + r[1]) * 0.5, y, 0)),
				Vector3(r[1] - r[0], COURSE.x, thick + 2.0 * COURSE.y), colour)

## A chunky wooden lintel over hole `h` in wall frame `w`, if the wall rises
## over it.
static func _lintel(kit: InteriorKit, w: Transform3D, h: Array, height: float) -> void:
	if h[3] > height - LINTEL.x:
		return
	kit.bevel_box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3((h[0] + h[1]) * 0.5, h[3] + LINTEL.x * 0.5, 0)),
		Vector3(h[1] - h[0] + 2.0 * LINTEL.y, LINTEL.x, WALL + 2.0 * LINTEL.z), 0.03,
		InteriorKit.solid(OasisPalette.WOOD))

## Hole `h`'s reveal in wall frame `w` (WALL thick, its outer face toward +z):
## its jambs (up to `jamb_top`), its head (when `headed`) and its sill (a
## window's) lined through the wall in the dark REVEAL, so the opening reads
## deep; and outside, a proud SURROUND round its jambs and sill. Nothing here
## narrows the opening's colliders.
static func _reveal(kit: InteriorKit, w: Transform3D, h: Array, jamb_top: float, headed: bool, variety: float,
		salt: int) -> void:
	var dark := InteriorKit.solid(OasisPalette.REVEAL)
	var deep := WALL + 0.004
	var tall: float = jamb_top - h[2]
	if tall > 0.05:
		for u: float in [h[0] + REVEAL_LINING * 0.5, h[1] - REVEAL_LINING * 0.5]:
			kit.box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3(u, h[2] + tall * 0.5, 0)),
				Vector3(REVEAL_LINING, tall, deep), dark)
	if headed:
		kit.box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3((h[0] + h[1]) * 0.5, h[3] - REVEAL_LINING * 0.5, 0)),
			Vector3(h[1] - h[0], REVEAL_LINING, deep), dark)
	if h[2] > 0.02:
		kit.box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3((h[0] + h[1]) * 0.5, h[2] + REVEAL_LINING * 0.5, 0)),
			Vector3(h[1] - h[0], REVEAL_LINING, deep), dark)
		kit.bevel_box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3((h[0] + h[1]) * 0.5, h[2] - SURROUND.x * 0.5,
			WALL * 0.5 + SURROUND.y * 0.5)), Vector3(h[1] - h[0] + 2.0 * SURROUND.x, SURROUND.x, SURROUND.y), 0.02,
			_base())
	if tall > 0.05:
		var foot: float = maxf(h[2] - (SURROUND.x if h[2] > 0.02 else 0.0), 0.0)
		var top: float = jamb_top + (0.0 if headed else -0.02)
		for u: float in [h[0] - SURROUND.x * 0.5, h[1] + SURROUND.x * 0.5]:
			kit.bevel_box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3(u, (foot + top) * 0.5, WALL * 0.5 + SURROUND.y * 0.5)),
				Vector3(SURROUND.x, top - foot, SURROUND.y), 0.02, _base())

## Where the beams poke out of a wall whose inside is `inner` long, their tops
## just under a roof at `roof_y`: [u along the wall, a salt] each, about
## VIGA_SPAN apart, none over an opening whose lintel reaches them.
static func _viga_spots(inner: float, roof_y: float, holes: Array, _variety: float, salt: int) -> Array:
	var count := maxi(2, roundi(inner / VIGA_SPAN))
	var y := roof_y - SLAB - VIGA_RADIUS
	var out := []
	for k in count:
		var u := -inner * 0.5 + inner * (k + 0.5) / count
		var clear := true
		for h: Array in holes:
			if u > h[0] - LINTEL.y - VIGA_RADIUS and u < h[1] + LINTEL.y + VIGA_RADIUS \
					and h[3] + LINTEL.x > y - VIGA_RADIUS - 0.02:
				clear = false
		if clear:
			out.append([u, salt * 16 + k])
	return out

## The beams of a wall frame `w` (see _viga_spots).
static func _vigas(kit: InteriorKit, w: Transform3D, inner: float, roof_y: float, holes: Array, variety: float,
		salt: int) -> void:
	for v: Array in _viga_spots(inner, roof_y, holes, variety, salt):
		_viga(kit, w, v[0], roof_y, variety, int(v[1]))

## One beam at `u` along wall frame `w`, under a roof at `roof_y`: a faceted log
## from inside the wall to VIGA_OUT (give or take) out of it, its end capped.
static func _viga(kit: InteriorKit, w: Transform3D, u: float, roof_y: float, variety: float, salt: int) -> void:
	var colour := InteriorKit.solid(SpacePalette.shade(OasisPalette.WOOD, int(_noise(variety, salt, 21.0) * 2.99)))
	var y := roof_y - SLAB - VIGA_RADIUS
	var out := VIGA_OUT * (0.8 + 0.4 * _noise(variety, salt, 22.0))
	var a := w * Vector3(u, y, WALL * 0.5 - 0.1)
	var b := w * Vector3(u, y - 0.03, WALL * 0.5 + out)
	var axis := (b - a).normalized()
	var across := (w.basis * Vector3.RIGHT).normalized()
	var up := axis.cross(across).normalized()
	if up.dot(w.basis * Vector3.UP) < 0.0:
		up = -up
	var turn := _noise(variety, salt, 23.0) * TAU
	for k in VIGA_SIDES:
		var t0 := turn + TAU * k / VIGA_SIDES
		var t1 := turn + TAU * (k + 1) / VIGA_SIDES
		var d0 := across * cos(t0) + up * sin(t0)
		var d1 := across * cos(t1) + up * sin(t1)
		kit.quad(InteriorKit.Batch.SOLID, a + d0 * VIGA_RADIUS, b + d0 * VIGA_RADIUS, b + d1 * VIGA_RADIUS,
			a + d1 * VIGA_RADIUS, (d0 + d1).normalized(), colour)
		kit.tri(InteriorKit.Batch.SOLID, b, b + d1 * VIGA_RADIUS, b + d0 * VIGA_RADIUS, axis, colour)

## The parapet's steps on wall frame `w`: one at each end of a coping `rim`
## long whose top is `coping_top`, and a lower one in the middle of a long wall.
static func _steps(kit: InteriorKit, w: Transform3D, rim: float, coping_top: float, variety: float, salt: int) -> void:
	for u: float in [-rim * 0.5 + STEP_LONG * 0.5, rim * 0.5 - STEP_LONG * 0.5]:
		_step(kit, w, u, STEP_LONG, STEP_UP, coping_top, variety, salt)
	if rim > 4.5:
		_step(kit, w, 0.0, STEP_LONG * 1.6, STEP_UP * 0.6, coping_top, variety, salt + 1)

## One softly rounded step `long` along and `rise` high on a coping at `u`.
static func _step(kit: InteriorKit, w: Transform3D, u: float, long: float, rise: float, coping_top: float,
		variety: float, salt: int) -> void:
	kit.bevel_box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3(u, coping_top + rise * 0.5 - 0.02, 0)),
		Vector3(long, rise + 0.02, WALL + COPING.y), 0.06, _light(variety, salt))

## The blocks on the outer face (+z, `thick` / 2 out) of a wall frame `w`
## `length` long, over each of its `pieces` ([u0, u1, y0, y1]) up to `top`:
## courses BLOCK.y high, blocks about BLOCK.x long and staggered course to
## course, each a shade of BRICK by `variety` and `salt`, BLOCK_SKIN proud
## and BLOCK_JOINT apart, kept BEVEL in from a piece's edges.
static func _blocks(kit: InteriorKit, w: Transform3D, length: float, pieces: Array, thick: float, top: float,
		variety: float, salt: int) -> void:
	var z := thick * 0.5 + BLOCK_SKIN
	var normal := (w.basis * Vector3.BACK).normalized()
	for course in ceili(top / BLOCK.y):
		var y0 := course * BLOCK.y
		var y1 := minf(y0 + BLOCK.y, top)
		var u := -length * 0.5 - BLOCK.x * (0.5 if course % 2 == 1 else 0.15) * (0.6 + 0.8 * _noise(variety, salt, course))
		var k := 0
		while u < length * 0.5:
			var long := BLOCK.x * (0.75 + 0.5 * _noise(variety, salt * 64 + course, k + 0.5))
			var colour := _block_shade(variety, salt * 977 + course * 31 + k)
			for p: Array in pieces:
				var a := maxf(u + BLOCK_JOINT * 0.5, p[0] + BEVEL)
				var b := minf(u + long - BLOCK_JOINT * 0.5, p[1] - BEVEL)
				var lo := maxf(y0 + BLOCK_JOINT * 0.5, p[2] + BEVEL)
				var hi := minf(y1 - BLOCK_JOINT * 0.5, p[3] - BEVEL)
				if b - a > 0.08 and hi - lo > 0.08:
					kit.quad(InteriorKit.Batch.SOLID, w * Vector3(a, lo, z), w * Vector3(b, lo, z), w * Vector3(b, hi, z),
						w * Vector3(a, hi, z), normal, colour)
			u += long
			k += 1

## Blocks on both faces of a run segment from foot `a` to foot `b` (RUN thick
## across `side`), up to `top`, courses counted from its lower foot.
static func _run_blocks(kit: InteriorKit, a: Vector3, b: Vector3, top: float, side: Vector3, variety: float,
		salt: int) -> void:
	var along := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := along.length()
	var foot := minf(a.y, b.y)
	var mid := Vector3((a.x + b.x) * 0.5, foot, (a.z + b.z) * 0.5)
	for face: float in [1.0, -1.0]:
		var x := along.normalized() * face
		var z := side * face
		var w := Transform3D(Basis(x, Vector3.UP, z), mid)
		_blocks(kit, w, length, [[-length * 0.5, length * 0.5, 0.0, top - foot]], RUN, top - foot,
			variety, salt * 2 + (0 if face > 0.0 else 1))

## The roof's slabs over `span` (x and z between the walls), their tops at
## `roof_y`: [frame, size, index] each.
static func _roof_slabs(span: Vector2, roof_y: float) -> Array:
	var n := maxi(1, ceili(span.x / SLAB_SPAN))
	var m := maxi(1, ceili(span.y / SLAB_LONG))
	var width := span.x / n
	var depth := span.y / m
	var out := []
	for k in n:
		for j in m:
			out.append([InteriorKit.at(Vector3(-span.x * 0.5 + width * (k + 0.5), roof_y - SLAB * 0.5,
				-span.y * 0.5 + depth * (j + 0.5))), Vector3(width - 0.03, SLAB, depth - (0.03 if m > 1 else 0.0)), k + j])
	return out

## A flat slab whose outline is `ring` (in f's xz plane), from `y0` to `y1`.
static func _slab(kit: InteriorKit, f: Transform3D, ring: PackedVector3Array, y0: float, y1: float, colour: Color) -> void:
	var up := (f.basis * Vector3.UP).normalized()
	for i in ring.size():
		var p := ring[i]
		var q := ring[(i + 1) % ring.size()]
		kit.tri(InteriorKit.Batch.SOLID, f * Vector3(0, y1, 0), f * (p + Vector3(0, y1, 0)), f * (q + Vector3(0, y1, 0)), up, colour)
		kit.tri(InteriorKit.Batch.SOLID, f * Vector3(0, y0, 0), f * (p + Vector3(0, y0, 0)), f * (q + Vector3(0, y0, 0)), -up, colour)
		var out := (f.basis * ((p + q) * 0.5)).normalized()
		kit.quad(InteriorKit.Batch.SOLID, f * (p + Vector3(0, y0, 0)), f * (q + Vector3(0, y0, 0)),
			f * (q + Vector3(0, y1, 0)), f * (p + Vector3(0, y1, 0)), out, colour)

static func _shape(xf: Transform3D, size: Vector3) -> CollisionShape3D:
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	var c := CollisionShape3D.new()
	c.shape = box_shape
	c.transform = xf
	return c

## A wall's own colour, under its blocks: the middle shade of BRICK, so a
## joint shows only beside a darker or a lighter block and the wall reads as
## patched mud brick, never as a grid of stone.
static func _base() -> Color:
	return InteriorKit.solid(SpacePalette.shade(OasisPalette.BRICK, 1))

## A block's shade of BRICK: the dark, the middle or the light, about a third
## each.
static func _block_shade(variety: float, salt: int) -> Color:
	var n := _noise(variety, salt, 3.1)
	return InteriorKit.solid(SpacePalette.shade(OasisPalette.BRICK, 0 if n < 0.3 else (1 if n < 0.65 else 2)))

## The light, sun-bleached brick of a step or a surround.
static func _light(variety: float, salt: int) -> Color:
	return InteriorKit.solid(SpacePalette.shade(OasisPalette.BRICK, 2 if _noise(variety, salt, 3.7) < 0.7 else 1))

## A roof slab's colour: the darker shades of BRICK.
static func _roof(variety: float, salt: int) -> Color:
	return InteriorKit.solid(SpacePalette.shade(OasisPalette.BRICK, 0 if _noise(variety, salt, 4.2) < 0.6 else 1))

static func _noise(a: float, b: float, c: float) -> float:
	var s := sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
	return s - floorf(s)
