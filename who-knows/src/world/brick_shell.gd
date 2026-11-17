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
## door's side) toward -z. Since Rework 2 (the owner: "the huts are like built
## into the sand? They don't have floors?") that foot is the shell's floor: the
## walls stand on a foundation course FOUNDATION high, FOUNDATION_PROUD proud
## of them all round, whose own foot is SUNK under the ground (FOUNDATION under
## f), so no gap shows where it meets the ground; a floor slab fills the
## inside at f; a threshold stone steps up before every door; and a whole
## shell's door is shut (planks in its reveal, sometimes ajar onto a dark
## inside) and its windows shuttered.
##
## Every shell has a twin with the same arguments less the kit, `<name>_shapes`,
## which gives its solid parts as box CollisionShape3Ds for the caller's one
## StaticBody3D (BodyProxy.LAYER outside). The twins follow the walls piece for
## piece (each wall piece, column and run segment is one box; a window stays
## open, a shut door is one box in its doorway); a roof is one box (two crossed
## for the round hut), a fallen slab one box, a foundation one box (one a
## segment for the round hut, from its middle out), a threshold one box;
## courses, lintels, copings, shutters, rubble, patches and sails have none.

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
## A bench under a sail (Wadoo spec §5): a plank seat on two stone blocks, its
## length from the layout, this deep and its seat this high, m. Sitters face its +z.
const BENCH_DEPTH := 0.45
const BENCH_SEAT := 0.45
const BENCH_PLANK := 0.07
## The bench's stone feet: this wide, this far in from its ends, sunk this far.
const BENCH_FOOT := 0.34
const BENCH_FOOT_IN := 0.3
const BENCH_SINK := 0.1
## What a building stands on (Rework 2): a course of stone FOUNDATION high over
## the ground and FOUNDATION_PROUD proud of the walls, the floor slab on it at
## its top (FLOOR_THICK of it shows above the ground inside a crushed hut).
## Part C's call 9 puts a building's floor 0.15 m over the ground at its door;
## here it is 0.3, with a threshold stone halfway, so the way in is two steps of
## THRESHOLD_RISE, each walked over without a jump. The threshold reaches
## THRESHOLD_DEEP out from the wall's face and THRESHOLD_WIDE past each jamb.
const FOUNDATION := 0.3
const FOUNDATION_PROUD := 0.1
const FLOOR_THICK := 0.2
const THRESHOLD_RISE := 0.15
const THRESHOLD_DEEP := 0.5
const THRESHOLD_WIDE := 0.3
## A shut door: planks PLANK thick, set DOOR_SET in from the wall's outer face,
## WOOD's shades; a door wider than DOUBLE is two leaves. Ajar, a leaf's free
## edge stands AJAR (a hand's width) in, onto the dark inside.
const PLANK := 0.07
const DOOR_SET := 0.1
const DOUBLE := 1.6
const AJAR := 0.1
## A window: width and height, its sill WINDOW_SILL over the floor (LOW_SILL
## in a building under LOW_HEIGHT); an upper storey's, smaller. A box taller
## than STOREY has two storeys, its upper floor at half its height.
const WINDOW := Vector2(0.7, 0.75)
const WINDOW_SILL := 1.05
const LOW_SILL := 0.9
const LOW_HEIGHT := 2.8
const UPPER_WINDOW := Vector2(0.55, 0.6)
const STOREY := 4.5
## A shutter's leaf is SHUTTER thick.
const SHUTTER := 0.05
## By variety, the parapet's height (m) and the beams' spacing (m) lie within
## these, so no two shells look alike.
const PARAPET_RANGE := Vector2(0.26, 0.52)
const VIGA_SPAN_RANGE := Vector2(0.95, 1.75)
## Where the broken wall ends at a breach its courses step down: [how far from
## the end each step reaches (m), its top as a share of the height]; the first
## is a stub.
const BREAK_STEPS := [[0.4, 0.25], [1.15, 0.52], [1.9, 0.7], [2.7, 0.86]]
## The gate's lintel beam: its height and depth, and how far it runs out past
## each pier.
const BEAM := Vector2(0.32, 0.4)
const BEAM_OUT := 0.35

# --- the box ------------------------------------------------------------------

## A box of `size` (x wide, y to the parapet's top, z deep) at `f`: four thick
## walls, `openings` (each [centre in f, width, height]) left as holes with a
## chunky lintel over each, two proud courses, a bevelled coping and a flat
## roof of slabs PARAPET under the top. `variety` (0 to 1) shades the walls.
static func box(kit: InteriorKit, f: Transform3D, size: Vector3, openings: Array, variety: float,
		shut := true) -> void:
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	var walls := _walls(size)
	var roof_y := size.y - parapet(variety)
	_box_footing(kit, f, size)
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
			_fill(kit, f * w, h, shut, variety, i)
		if i < 2 and size.y > STOREY:
			# A two-storey house: a band of beams at its upper floor.
			_vigas(kit, f * w, length - 2.0 * WALL, size.y * 0.5, holes, variety, i + 8)
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

## box's solid parts: each wall piece, the roof, the foundation (one box, its
## top the floor), each threshold and, `shut`, each door's leaf.
static func box_shapes(f: Transform3D, size: Vector3, openings: Array, variety: float,
		shut := true) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for wall: Array in _walls(size):
		var w: Transform3D = wall[0]
		var holes := _holes(w, wall[1], openings)
		for p: Array in _pieces(wall[1], size.y, holes):
			out.append(_shape(f * w * _span(p), _span_size(p, WALL)))
		for h: Array in holes:
			if _is_door(h):
				out.append(_threshold_shape(f * w, h))
				if shut:
					out.append(_door_shape(f * w, h))
	var span := Vector2(size.x - 2.0 * WALL, size.z - 2.0 * WALL)
	out.append(_shape(f * InteriorKit.at(Vector3(0, size.y - parapet(variety) - SLAB * 0.5, 0)), Vector3(span.x, SLAB, span.y)))
	var foot := FOUNDATION + SUNK
	out.append(_shape(f * InteriorKit.at(Vector3(0, -foot * 0.5, 0)),
		Vector3(size.x + 2.0 * FOUNDATION_PROUD, foot, size.z + 2.0 * FOUNDATION_PROUD)))
	return out

# --- the round hut --------------------------------------------------------------

## A round hut at `f`: HUT_SIDES chunky wall segments whose outer faces lie
## `radius` out, `height` to the parapet's top, a door in its front (-z), two
## courses, a coping and a flat roof.
static func round_hut(kit: InteriorKit, f: Transform3D, radius: float, height: float, variety: float,
		shut := true) -> void:
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	var roof_y := height - parapet(variety)
	var side := _hut_side(radius)
	_hut_footing(kit, f, radius)
	for i in HUT_SIDES:
		var w := _hut_wall(radius, i)
		var holes := _hut_holes(i, height, variety)
		var pieces := _pieces(side, height, holes)
		for p: Array in pieces:
			kit.bevel_box(InteriorKit.Batch.SOLID, f * w * _span(p), _span_size(p, WALL), BEVEL, _base())
		_blocks(kit, f * w, side, pieces, WALL, height - COPING.x * 0.5, variety, i)
		for share in COURSES:
			_course(kit, f * w, -side * 0.5, side * 0.5, _course_y(roof_y, share), holes, WALL, dark)
		for h: Array in holes:
			_reveal(kit, f * w, h, h[3], h[3] < height - LINTEL.x, variety, i)
			_lintel(kit, f * w, h, height)
			_fill(kit, f * w, h, shut, variety, i)
		var coping_top := height + COPING.x - 0.03
		kit.bevel_box(InteriorKit.Batch.SOLID, f * w * InteriorKit.at(Vector3(0, coping_top - COPING.x * 0.5, 0)),
			Vector3(side + 0.08, COPING.x, WALL + 2.0 * COPING.y), 0.03, dark)
		# A beam out of every other segment, none over the door or a window;
		# the parapet steps up over every third, the door's first.
		if i % 2 == 1 and holes.is_empty():
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

## round_hut's solid parts: each wall piece, the roof as two crossed boxes,
## the foundation as a box a segment (from the middle out to its face, its top
## the floor), the threshold and, `shut`, the door's leaf.
static func round_hut_shapes(f: Transform3D, radius: float, height: float, variety: float,
		shut := true) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	var side := _hut_side(radius)
	var outer := radius + FOUNDATION_PROUD
	var foot := FOUNDATION + SUNK
	for i in HUT_SIDES:
		var w := _hut_wall(radius, i)
		var holes := _hut_holes(i, height, variety)
		for p: Array in _pieces(side, height, holes):
			out.append(_shape(f * w * _span(p), _span_size(p, WALL)))
		for h: Array in holes:
			if _is_door(h):
				out.append(_threshold_shape(f * w, h))
				if shut:
					out.append(_door_shape(f * w, h))
		var turn := Basis(Vector3.UP, PI + TAU * i / HUT_SIDES)
		out.append(_shape(f * Transform3D(turn, turn * Vector3(0, -foot * 0.5, outer * 0.5)),
			Vector3(_hut_side(outer), foot, outer)))
	var square := 2.0 * (radius - WALL) * cos(PI * 0.25)
	for turn in [0.0, PI * 0.25]:
		out.append(_shape(f * Transform3D(Basis(Vector3.UP, turn), Vector3(0, height - parapet(variety) - SLAB * 0.5, 0)),
			Vector3(square, SLAB, square)))
	return out

static func _hut_side(radius: float) -> float:
	return 2.0 * radius * tan(PI / HUT_SIDES)

## Segment `i`'s frame: segment 0 faces the front (-z).
static func _hut_wall(radius: float, i: int) -> Transform3D:
	var turn := Basis(Vector3.UP, PI + TAU * i / HUT_SIDES)
	return Transform3D(turn, turn * Vector3(0, 0, radius - WALL * 0.5))

## Segment `i`'s openings, [u0, u1, y0, y1]: the door in segment 0, and by
## `variety` a window in two of the side segments of a hut `height` high.
static func _hut_holes(i: int, height: float, variety: float) -> Array:
	if i == 0:
		return [[-DOOR.x * 0.5, DOOR.x * 0.5, 0.0, DOOR.y]]
	var first := 3 + int(_noise(variety, 2.0, 31.0) * 1.99)
	if i == first or i == HUT_SIDES - first + (1 if _noise(variety, 3.0, 31.0) > 0.5 else 0):
		var sill := WINDOW_SILL if height > LOW_HEIGHT else LOW_SILL
		var tall := minf(WINDOW.y, height - parapet(variety) - SLAB - LINTEL.x - sill - 0.05)
		if tall > 0.4:
			return [[-WINDOW.x * 0.4, WINDOW.x * 0.4, sill, sill + tall]]
	return []

# --- the crushed hut ------------------------------------------------------------

## A hut of `size` crushed in from its +x side: the walls there broken down to
## stumps and falling away along the front and back toward it, the far wall
## standing nearly whole, no coping; the roof's slabs fallen in at angles, no
## higher than FALLEN_TOP of its height; and rubble over the floor. Its
## foundation and floor slab stand whole under it all (Rework 2), so what fell
## lies on the floor, not on sand. A door stays in the front, at its whole
## end, open, with its threshold.
static func crushed(kit: InteriorKit, f: Transform3D, size: Vector3, variety: float) -> void:
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	var walls := _walls(size)
	var door := _crushed_door(size)
	_box_footing(kit, f, size)
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
			if _is_door(h):
				_threshold(kit, f * w, h)
		# The beams still in the standing wall, over the far (whole) end.
		if i < 2:
			for v: Array in viga_spots(length - 2.0 * WALL, size.y - PARAPET, holes, variety, i):
				if _column_height(i, w, length, size, v[0], variety) > size.y - PARAPET + 0.05:
					_viga(kit, f * w, v[0], size.y - PARAPET, variety, int(v[1]))
	for slab: Array in _fallen(size, variety):
		kit.bevel_box(InteriorKit.Batch.SOLID, f * (slab[0] as Transform3D), slab[1], 0.03, _roof(variety, int(slab[2])))
	var span := Vector2(size.x - 2.0 * WALL, size.z - 2.0 * WALL)
	rubble(kit, f * InteriorKit.at(Vector3(span.x * 0.12, 0, 0)), span * Vector2(0.72, 0.8),
		int(span.x * span.y * 0.35), variety, func(_x: float, _z: float) -> float: return 0.0)

## crushed's solid parts: each standing column of wall, each fallen slab, the
## foundation (its top the floor) and the threshold. Its door stays open.
static func crushed_shapes(f: Transform3D, size: Vector3, variety: float) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	var walls := _walls(size)
	for i in walls.size():
		var w: Transform3D = walls[i][0]
		var length: float = walls[i][1]
		var holes := _holes(w, length, [_crushed_door(size)])
		for p: Array in _crushed_pieces(i, w, length, size, holes, variety):
			out.append(_shape(f * w * _span(p), _span_size(p, WALL)))
		for h: Array in holes:
			out.append(_threshold_shape(f * w, h))
	for slab: Array in _fallen(size, variety):
		out.append(_shape(f * (slab[0] as Transform3D), slab[1]))
	var foot := FOUNDATION + SUNK
	out.append(_shape(f * InteriorKit.at(Vector3(0, -foot * 0.5, 0)),
		Vector3(size.x + 2.0 * FOUNDATION_PROUD, foot, size.z + 2.0 * FOUNDATION_PROUD)))
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
		while hi - lo > top - 0.04 and tries < 12:
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
		var at := Vector3(-span.x * 0.5 + width * (k + 0.5), 0.04 - lo, (a - 0.5) * 0.5)
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
## BAND_AT over the ground. It stands on a footing course as a shell's
## foundation does (Rework 2). Where `broken` says its start or its end is a
## breach ([start, end]), its courses step down there (BREAK_STEPS) to a stub.
static func wall(kit: InteriorKit, points: PackedVector3Array, height: float, variety: float,
		broken := [false, false]) -> void:
	var dark := InteriorKit.solid(OasisPalette.BRICK_DARK)
	for seg: Array in _run_segments(points, height, variety, broken):
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var top: float = seg[2]
		var dir: Vector3 = seg[3]
		var k: int = seg[4]
		var side := dir.cross(Vector3.UP)
		_prism(kit, a, b, top, side, _base())
		_run_blocks(kit, a, b, top - CHAMFER, side, variety, k)
		_footing(kit, a, b, side)
		var ground := (a.y + b.y) * 0.5 + SUNK
		if top - maxf(a.y, b.y) > BAND_AT + 0.4:
			var slope := (b - a).normalized()
			var up := side.cross(slope).normalized()
			var mid := (a + b) * 0.5
			mid.y = ground + BAND_AT
			kit.box(InteriorKit.Batch.SOLID, Transform3D(Basis(slope, up, side), mid),
				Vector3(a.distance_to(b) - 0.04, COURSE.x, RUN + 2.0 * COURSE.y), dark)

## wall's solid parts: a box a segment, from its lower foot to its top.
static func wall_shapes(points: PackedVector3Array, height: float, variety: float,
		broken := [false, false]) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for seg: Array in _run_segments(points, height, variety, broken):
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

## A run's segments: [its foot at the start and the end (SUNK under the
## ground, stretched BEND_OVERLAP where the run bends), its top, its
## horizontal direction, its index] each, segments with no length left out.
## A broken end gets points at BREAK_STEPS' reaches from it, and each segment
## there tops out at its step's share of `height`.
static func _run_segments(points: PackedVector3Array, height: float, variety: float, broken: Array) -> Array:
	var pts := points
	for end in 2:
		if bool(broken[end]):
			for step: Array in BREAK_STEPS:
				pts = _insert_at(pts, float(step[0]), end == 1)
	var along := PackedFloat64Array([0.0])
	for k in pts.size() - 1:
		along.append(along[k] + Vector2(pts[k + 1].x - pts[k].x, pts[k + 1].z - pts[k].z).length())
	var total := along[along.size() - 1]
	var out := []
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var flat := Vector3(b.x - a.x, 0, b.z - a.z)
		if flat.length() < 0.01:
			continue
		var dir := flat.normalized()
		var share := lerpf(RAGGED, 1.0, _noise(variety, k, 5.3))
		var mid := (along[k] + along[k + 1]) * 0.5
		for end in 2:
			if not bool(broken[end]):
				continue
			var from_end := mid if end == 0 else total - mid
			for step: Array in BREAK_STEPS:
				if from_end < float(step[0]):
					share = float(step[1]) + (_noise(variety, k, 6.1) - 0.5) * 0.06
					break
		var top := minf(a.y, b.y) + height * share
		var start := a - Vector3(0, SUNK, 0)
		var stop := b - Vector3(0, SUNK, 0)
		if k > 0 and _bends(pts[k - 1], a, b):
			start -= dir * BEND_OVERLAP
		if k + 2 < pts.size() and _bends(a, b, pts[k + 2]):
			stop += dir * BEND_OVERLAP
		out.append([start, stop, top, dir, k])
	return out

## `points` with one more, `d` m along the run from its start (or its end),
## on the line between its neighbours; unchanged if one lies within 5 cm.
static func _insert_at(points: PackedVector3Array, d: float, from_end: bool) -> PackedVector3Array:
	var pts := points.duplicate()
	if from_end:
		pts.reverse()
	var acc := 0.0
	for i in pts.size() - 1:
		var length := Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
		if acc + length > d:
			if d - acc > 0.05 and acc + length - d > 0.05:
				pts.insert(i + 1, pts[i].lerp(pts[i + 1], (d - acc) / length))
			break
		acc += length
	if from_end:
		pts.reverse()
	return pts

## The footing course under a run's segment from foot `a` to foot `b` (both
## SUNK under the ground): FOUNDATION over the ground at each end, RUN +
## 2 FOUNDATION_PROUD wide across `side`, its top edges chamfered, in
## OasisPalette.FOUNDATION.
static func _footing(kit: InteriorKit, a: Vector3, b: Vector3, side: Vector3) -> void:
	var h := RUN * 0.5 + FOUNDATION_PROUD
	var c := 0.04
	var rise := FOUNDATION + SUNK
	var colour := InteriorKit.solid(OasisPalette.FOUNDATION)
	var profile := [Vector2(-h, 0), Vector2(-h, rise - c), Vector2(-h + c, rise), Vector2(h - c, rise),
		Vector2(h, rise - c), Vector2(h, 0)]
	var at_a := PackedVector3Array()
	var at_b := PackedVector3Array()
	for p: Vector2 in profile:
		at_a.append(a + Vector3(0, p.y, 0) + side * p.x)
		at_b.append(b + Vector3(0, p.y, 0) + side * p.x)
	var normals := [-side, (Vector3.UP - side).normalized(), Vector3.UP, (Vector3.UP + side).normalized(), side]
	for i in 5:
		kit.quad(InteriorKit.Batch.SOLID, at_a[i], at_b[i], at_b[i + 1], at_a[i + 1], normals[i], colour)
	var way := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	for i in range(1, 5):
		kit.tri(InteriorKit.Batch.SOLID, at_a[0], at_a[i], at_a[i + 1], -way, colour)
		kit.tri(InteriorKit.Batch.SOLID, at_b[0], at_b[i], at_b[i + 1], way, colour)

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

## A bench at `f` (its middle on the ground, sitters facing its +z): a wooden
## plank BENCH_SEAT high on two blocks of the foundation's stone, `length` long.
static func bench(kit: InteriorKit, f: Transform3D, length: float, variety: float) -> void:
	var stone := InteriorKit.solid(SpacePalette.shade(OasisPalette.FOUNDATION, int(clampf(variety, 0.0, 1.0) * 2.99)))
	var foot := BENCH_SEAT - BENCH_PLANK + BENCH_SINK
	for side: float in [-1.0, 1.0]:
		kit.bevel_box(InteriorKit.Batch.SOLID,
			f * InteriorKit.at(Vector3(side * (length * 0.5 - BENCH_FOOT_IN), foot * 0.5 - BENCH_SINK, 0.0)),
			Vector3(BENCH_FOOT, foot, BENCH_DEPTH * 0.85), 0.04, stone)
	kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0.0, BENCH_SEAT - BENCH_PLANK * 0.5, 0.0)),
		Vector3(length, BENCH_PLANK, BENCH_DEPTH), 0.02, InteriorKit.solid(OasisPalette.WOOD))

## The bench's collider: one box, from its feet to its seat.
static func bench_shapes(f: Transform3D, length: float) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	out.append(_shape(f * InteriorKit.at(Vector3(0.0, (BENCH_SEAT - BENCH_SINK) * 0.5, 0.0)),
		Vector3(length, BENCH_SEAT + BENCH_SINK, BENCH_DEPTH)))
	return out

# --- the gate's piers ----------------------------------------------------------

## A gate pier at `f` (its foot, SUNK under the ground; x along the wall, z
## across it): a thick block `size` high in the wall's adobe, its four faces
## laid in blocks, on a footing course as the wall's (Rework 2), under a
## bevelled coping COPING.x thick that stands COPING.y proud all round, the
## coping's top at `size.y`.
static func pier(kit: InteriorKit, f: Transform3D, size: Vector3, variety: float) -> void:
	var body := size.y - COPING.x
	var rise := FOUNDATION + SUNK
	kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, rise * 0.5, 0)),
		Vector3(size.x + 2.0 * FOUNDATION_PROUD, rise, size.z + 2.0 * FOUNDATION_PROUD), 0.04,
		InteriorKit.solid(OasisPalette.FOUNDATION))
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

## The gate's lintel beam (Rework 2): a squared wooden log BEAM thick from pier
## top `a` to pier top `b` (each the middle of a pier's top, under its
## coping, in the kit's space), through both piers and BEAM_OUT past them
## (`pier` thick), its top at their lower top.
static func gate_beam(kit: InteriorKit, a: Vector3, b: Vector3, pier: float, variety: float) -> void:
	var along := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := along.length() + pier + 2.0 * BEAM_OUT
	var x := along.normalized()
	var mid := (a + b) * 0.5
	mid.y = minf(a.y, b.y) - BEAM.x * 0.5
	var colour := InteriorKit.solid(SpacePalette.shade(OasisPalette.WOOD, int(_noise(variety, 1.0, 25.0) * 2.99)))
	kit.bevel_box(InteriorKit.Batch.SOLID, Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), mid),
		Vector3(length, BEAM.x, BEAM.y), 0.04, colour)

# --- foundations, floors, doors and shutters (Rework 2) -----------------------

## The parapet's height over the roof of a shell of `variety`: within
## PARAPET_RANGE.
static func parapet(variety: float) -> float:
	return lerpf(PARAPET_RANGE.x, PARAPET_RANGE.y, _noise(variety, 2.0, 26.0))

## The openings of a box shell `size` by `variety`, each [centre in the
## shell's frame, width, height]: a door DOOR.y high and `door_width` wide in
## the front (-z), at its middle or, on a long front, off it; a window either
## side of it where there is room, and one in a side wall, by variety; a
## house over STOREY high an upper window over its door.
static func openings_for(size: Vector3, variety: float, door_width := DOOR.x) -> Array:
	var front := -size.z * 0.5 + WALL * 0.5
	var inner := size.x * 0.5 - WALL
	var slack := maxf(inner - door_width * 0.5 - 1.6, 0.0)
	var door_u := (_noise(variety, 1.0, 27.0) - 0.5) * 2.0 * slack * 0.6 if size.x > 7.5 else 0.0
	var out := [[Vector3(door_u, DOOR.y * 0.5, front), door_width, DOOR.y]]
	var low := size.y <= LOW_HEIGHT
	var sill := LOW_SILL if low else WINDOW_SILL
	var tall := minf(WINDOW.y, size.y - parapet(variety) - SLAB - LINTEL.x - sill - 0.05)
	if tall < 0.4:
		return out
	var wide := WINDOW.x * (0.8 if low else 1.0)
	for side: float in [-1.0, 1.0]:
		var jamb := door_u + side * (door_width * 0.5 + LINTEL.y)
		var room := inner - absf(jamb)
		if room > wide + 0.9 and _noise(variety, side, 28.0) > 0.25:
			out.append([Vector3(jamb + side * room * 0.5, sill + tall * 0.5, front), wide, tall])
	if size.z - 2.0 * WALL > wide + 1.2:
		var x := size.x * 0.5 - WALL * 0.5
		var on := 1.0 if _noise(variety, 3.0, 28.0) > 0.5 else -1.0
		out.append([Vector3(on * x, sill + tall * 0.5, (_noise(variety, 4.0, 28.0) - 0.5) * 0.6), wide, tall])
	if size.y > STOREY:
		out.append([Vector3(door_u, size.y * 0.5 + 0.35 + UPPER_WINDOW.y * 0.5, front), UPPER_WINDOW.x, UPPER_WINDOW.y])
	return out

## Whether hole `h` ([u0, u1, y0, y1]) is a door: it starts at the floor.
static func _is_door(h: Array) -> bool:
	return float(h[2]) < 0.02

## The doors of a shell in its own frame, each [the middle of the doorway (in
## the wall's middle) at the floor, the unit way out, its width]: of a box
## (its `openings`); of a round hut (`radius` over 0); or of a crushed hut
## (`crushed_size` not zero).
static func door_spots(openings: Array, radius := 0.0, crushed_size := Vector3.ZERO) -> Array:
	if radius > 0.0:
		return [[Vector3(0, 0, -(radius - WALL * 0.5)), Vector3.FORWARD, DOOR.x]]
	var list := [_crushed_door(crushed_size)] if crushed_size != Vector3.ZERO else openings
	var out := []
	for o: Array in list:
		var c: Vector3 = o[0]
		if c.y - float(o[2]) * 0.5 > 0.02:
			continue
		var way := Vector3.RIGHT if c.x > 0.0 else Vector3.LEFT
		if absf(c.z) >= absf(c.x):
			way = Vector3.BACK if c.z > 0.0 else Vector3.FORWARD
		out.append([Vector3(c.x, 0, c.z), way, float(o[1])])
	return out

## A box's (or a crushed hut's) foundation course and floor slab, under `f`.
static func _box_footing(kit: InteriorKit, f: Transform3D, size: Vector3) -> void:
	var stone := InteriorKit.solid(OasisPalette.FOUNDATION)
	var rise := FOUNDATION + SUNK
	var band := WALL + FOUNDATION_PROUD
	var out := Vector2(size.x, size.z) + Vector2.ONE * 2.0 * FOUNDATION_PROUD
	for z_side: float in [-1.0, 1.0]:
		kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, -rise * 0.5, z_side * (out.y - band) * 0.5)),
			Vector3(out.x, rise, band), 0.04, stone)
	for x_side: float in [-1.0, 1.0]:
		kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(x_side * (out.x - band) * 0.5, -rise * 0.5, 0)),
			Vector3(band, rise, out.y - 2.0 * band + 0.02), 0.04, stone)
	var inside := Vector2(size.x - 2.0 * WALL, size.z - 2.0 * WALL)
	kit.box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, -FLOOR_THICK * 0.5 - 0.004, 0)),
		Vector3(inside.x + 0.02, FLOOR_THICK, inside.y + 0.02), InteriorKit.solid(OasisPalette.FLOOR))

## A round hut's foundation course (a segment under each wall) and its floor
## slab, under `f`.
static func _hut_footing(kit: InteriorKit, f: Transform3D, radius: float) -> void:
	var stone := InteriorKit.solid(OasisPalette.FOUNDATION)
	var rise := FOUNDATION + SUNK
	var band := WALL + FOUNDATION_PROUD
	var outer := radius + FOUNDATION_PROUD
	for i in HUT_SIDES:
		var turn := Basis(Vector3.UP, PI + TAU * i / HUT_SIDES)
		kit.bevel_box(InteriorKit.Batch.SOLID, f * Transform3D(turn, turn * Vector3(0, -rise * 0.5, outer - band * 0.5)),
			Vector3(_hut_side(outer), rise, band), 0.04, stone)
	var ring := PackedVector3Array()
	var corner := (radius - WALL + 0.01) / cos(PI / HUT_SIDES)
	for i in HUT_SIDES:
		var a := PI + TAU * (i + 0.5) / HUT_SIDES
		ring.append(Vector3(sin(a) * corner, 0, cos(a) * corner))
	_slab(kit, f, ring, -FLOOR_THICK - 0.004, -0.004, InteriorKit.solid(OasisPalette.FLOOR))

## Hole `h`'s threshold stone, in wall frame `w`: on the ground (FOUNDATION
## under the floor) before the wall's face, THRESHOLD_RISE high, THRESHOLD_DEEP
## out and THRESHOLD_WIDE past each jamb, in a light shade of the foundation.
static func _threshold(kit: InteriorKit, w: Transform3D, h: Array) -> void:
	var t := _threshold_frame(h)
	kit.bevel_box(InteriorKit.Batch.SOLID, w * InteriorKit.at(t[0]), t[1], 0.04,
		InteriorKit.solid(SpacePalette.shade(OasisPalette.FOUNDATION, 2)))

static func _threshold_shape(w: Transform3D, h: Array) -> CollisionShape3D:
	var t := _threshold_frame(h)
	return _shape(w * InteriorKit.at(t[0]), t[1])

## [middle, size] of hole `h`'s threshold in its wall's frame.
static func _threshold_frame(h: Array) -> Array:
	var rise := THRESHOLD_RISE + SUNK
	var size := Vector3(float(h[1]) - float(h[0]) + 2.0 * THRESHOLD_WIDE, rise, THRESHOLD_DEEP)
	return [Vector3((float(h[0]) + float(h[1])) * 0.5, -FOUNDATION - SUNK + rise * 0.5,
		WALL * 0.5 + THRESHOLD_DEEP * 0.5 - 0.02), size]

## A shut door's solid part, in wall frame `w`: its leaves closed, PLANK thick.
static func _door_shape(w: Transform3D, h: Array) -> CollisionShape3D:
	var z := WALL * 0.5 - DOOR_SET - PLANK * 0.5
	return _shape(w * InteriorKit.at(Vector3((float(h[0]) + float(h[1])) * 0.5, float(h[3]) * 0.5, z)),
		Vector3(float(h[1]) - float(h[0]), float(h[3]), PLANK))

## What fills hole `h` in wall frame `w`: a door its threshold and, `shut`,
## its plank leaves (one, or two if wider than DOUBLE), sometimes one ajar by
## AJAR; a window its shutters, closed, one open or both half open. Behind
## either, when shut, a dark backing at the wall's inner face, so a gap shows
## a dark inside, never sand. By `variety` and `salt`.
static func _fill(kit: InteriorKit, w: Transform3D, h: Array, shut: bool, variety: float, salt: int) -> void:
	var u0 := float(h[0])
	var u1 := float(h[1])
	var y0 := float(h[2])
	var y1 := float(h[3])
	var door := _is_door(h)
	if door:
		_threshold(kit, w, h)
	if not shut:
		return
	kit.box(InteriorKit.Batch.SOLID, w * InteriorKit.at(Vector3((u0 + u1) * 0.5, (y0 + y1) * 0.5, -WALL * 0.5 + 0.012)),
		Vector3(u1 - u0 + 0.02, y1 - y0 + 0.02, 0.02), InteriorKit.solid(SpacePalette.shade(OasisPalette.REVEAL, 0)))
	if door:
		var leaves := 2 if u1 - u0 > DOUBLE else 1
		var leaf := (u1 - u0) / leaves - 0.02
		var ajar := -1
		if _noise(variety, salt, 29.0) > 0.55:
			ajar = int(_noise(variety, salt, 30.0) * leaves * 0.999)
		var z := WALL * 0.5 - DOOR_SET - PLANK * 0.5
		for k in leaves:
			var s := 1.0 if k == 0 else -1.0
			var hinge := Vector3(u0 + 0.01 if k == 0 else u1 - 0.01, 0.0, z)
			var turn := s * asin(AJAR / leaf) if k == ajar else 0.0
			_leaf(kit, w * Transform3D(Basis(Vector3.UP, turn), hinge), s, leaf, y1 - 0.02, PLANK, variety, salt * 4 + k, true)
		return
	var mode := _noise(variety, salt, 31.0)
	var half := (u1 - u0) * 0.5 - 0.01
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		var swing := 0.0
		if mode > 0.75 or (mode > 0.4 and k == int(_noise(variety, salt, 32.0) * 1.999)):
			swing = deg_to_rad(lerpf(55.0, 105.0, _noise(variety, salt, 33.0 + k)))
		if swing == 0.0:
			var hinge := Vector3(u0 + 0.005 if k == 0 else u1 - 0.005, y0 + 0.01, WALL * 0.5 - 0.04 - SHUTTER * 0.5)
			_leaf(kit, w * InteriorKit.at(hinge), s, half, y1 - y0 - 0.02, SHUTTER, variety, salt * 8 + k, false)
		else:
			# Hung on the surround's outer corner and swung out toward the wall.
			var hinge := Vector3(u0 - SURROUND.x if k == 0 else u1 + SURROUND.x, y0 + 0.01,
				WALL * 0.5 + SURROUND.y + SHUTTER * 0.5)
			_leaf(kit, w * Transform3D(Basis(Vector3.UP, s * swing), hinge), -s, half, y1 - y0 - 0.02, SHUTTER,
				variety, salt * 8 + k, false)

## One wooden leaf in frame `t` (its hinge edge at the origin, its foot at y
## 0): `width` along `s` x, `tall` high, `thick` deep, of planks in WOOD's
## shades (a door's three, a shutter's two) with two dark battens across.
static func _leaf(kit: InteriorKit, t: Transform3D, s: float, width: float, tall: float, thick: float, variety: float,
		salt: int, door: bool) -> void:
	var planks := 3 if door else 2
	var each := width / planks
	for k in planks:
		var colour := InteriorKit.solid(SpacePalette.shade(OasisPalette.WOOD, int(_noise(variety, salt * 3 + k, 34.0) * 2.99)))
		kit.bevel_box(InteriorKit.Batch.SOLID, t * InteriorKit.at(Vector3(s * each * (k + 0.5), tall * 0.5, 0)),
			Vector3(each - 0.012, tall, thick), 0.012, colour)
	var dark := InteriorKit.solid(SpacePalette.shade(OasisPalette.WOOD, 0))
	for y_share: float in ([0.2, 0.78] if door else [0.25, 0.75]):
		kit.bevel_box(InteriorKit.Batch.SOLID, t * InteriorKit.at(Vector3(s * width * 0.5, tall * y_share, thick * 0.5 + 0.015)),
			Vector3(width * 0.92, 0.1 if door else 0.07, 0.03), 0.01, dark)

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
## just under a roof at `roof_y`: [u along the wall, a salt] each, a spacing
## within VIGA_SPAN_RANGE (by `variety`) apart, none over an opening whose
## lintel reaches them.
static func viga_spots(inner: float, roof_y: float, holes: Array, variety: float, salt: int) -> Array:
	var count := maxi(2, roundi(inner / lerpf(VIGA_SPAN_RANGE.x, VIGA_SPAN_RANGE.y, _noise(variety, 1.0, 24.0))))
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
	for v: Array in viga_spots(inner, roof_y, holes, variety, salt):
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
