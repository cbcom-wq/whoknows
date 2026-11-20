class_name OasisLooks
extends RefCounted

## What the oasis's pieces look like: faceted shapes built with an InteriorKit
## in the oasis's colours (OasisPalette). The kit builds on the outside's own
## layer here (layer 1, the world), never the interior's.

## Where the kit builds the pool's water: layer 1 and the world's light.
const WORLD_LAYER := 1

## A kit that draws on the world's layer under `root`.
static func kit_under(root: Node3D) -> InteriorKit:
	var kit := InteriorKit.new(root)
	kit.layer = WORLD_LAYER
	kit.light_mask = WORLD_LAYER
	return kit

## The pool's water: a flat, faceted disc of `radius` in the frame `f`'s
## horizontal plane (its up is the frame's y), in OasisPalette.WATER.
static func water(kit: InteriorKit, f: Transform3D, radius: float) -> void:
	var flat := Transform3D(f.basis * Basis(Vector3.RIGHT, -PI * 0.5), f.origin)
	kit.disc(InteriorKit.Batch.SOLID, flat, radius, InteriorKit.solid(OasisPalette.WATER))

# --- the green, the gardens, the pump and the path ----------------------------

## A palm's trunk is this many chunky drums, and its crown this many fronds,
## each FROND_VERTICES vertices (three triangles a side, both faces).
const TRUNK_DRUMS := 7
const DRUM_SIDES := 7
const FRONDS := 7
const FROND_VERTICES := 18
const TRUNK_RADIUS := 0.42
## The trunk's capsule: its radius, m.
const COLLIDER_RADIUS := 0.4

## A tuft of the grass ring: its height range, m, and how many to a square metre
## of ring.
const TUFT_HEIGHT := Vector2(0.35, 0.7)
const TUFTS_PER_M2 := 1.1
## The ring's tufts are drawn in square tiles TUFT_TILE m across, one
## MultiMesh a tile, so each tile fades by its own distance; they fade out
## between TUFT_REACH - TUFT_FADE and TUFT_REACH + TUFT_FADE from the eye (the
## engine's visibility range, measured to a tile's middle). From the air only
## the green patch under them shows (Checkpoint B: the owner saw the tufts
## from the air as speckled noise).
const TUFT_TILE := 12.0
const TUFT_REACH := 85.0
const TUFT_FADE := 20.0

## The green patch under the ring: PATCH_PROUD over the ground's own
## triangles (as the tracks lie), from PATCH_SHORE out of the water's edge
## (a bank of damp ground, as wide as the tufts' own; nearer the water the
## pool's bank curves too much for a coarser chunk's quads, which would cut
## over the patch from the air) to the green's ragged outline (green_reach).
## Its shade changes in broad, faceted patches about PATCH_WAVE m across.
const PATCH_PROUD := 0.025
const PATCH_SHORE := 1.5
const PATCH_WAVE := 9.0
## The outline's wobble: [lobes round the ring, share of the ellipse's reach]:
## broad lobes, and (Rework 2) finer bays and tongues.
const GREEN_WOBBLE := [[3, 0.07], [5, 0.05], [8, 0.035], [13, 0.025], [19, 0.016]]
## The green's dry rim (Rework 2: the owner, "the grass just ends abruptly"):
## over its outer GREEN_FADE m the patch steps from GREEN_PATCH through
## GRASS_OLIVE to GRASS_DRY_EDGE, a triangle at a time, each step's line
## jittered by FADE_JITTER of the band; the tufts thin out over their outer
## TUFT_FADE_BAND m (a tuft there is kept with the chance TUFT_KEEP.x +
## TUFT_KEEP.y * (inside / TUFT_FADE_BAND)^2) and dry the same way; and
## STRAYS single tufts and STRAY_CLUMPS clumps of CLUMP_TUFTS (within
## CLUMP_RADIUS m) lie STRAY_OUT m past the outline, dry.
const GREEN_FADE := 4.5
const FADE_JITTER := 0.18
const TUFT_FADE_BAND := 5.0
const TUFT_KEEP := Vector2(0.08, 0.92)
const STRAYS := 48
const STRAY_CLUMPS := 3
const CLUMP_TUFTS := Vector2i(7, 13)
const CLUMP_RADIUS := 1.6
const STRAY_OUT := Vector2(2.0, 8.0)

## Where the palm's trunk is, `t` from its foot (0) to its crown (1), in its
## frame: the lean grows as the square of the height, so it curves.
static func _trunk_point(variety: float, t: float) -> Vector3:
	var height := 6.2 + 1.9 * variety
	var angle := variety * TAU * 1.7
	var lean := (0.6 + 1.6 * variety) * Vector3(cos(angle), 0.0, sin(angle))
	return lean * t * t + Vector3.UP * (height * t)

static func _noise(a: float, b: float, c: float) -> float:
	var s := sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
	return s - floorf(s)

## A palm at `f` (its foot on the ground, the frame's y up): a leaning, curved
## trunk of faceted drums, 6.2 to 8.1 m tall by `variety` (0 to 1), and seven
## broad flat fronds drooping from the crown. The lowest one or two droop most
## and have dried.
static func palm(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	for i in TRUNK_DRUMS:
		var t0 := float(i) / TRUNK_DRUMS - (0.02 if i > 0 else 0.0)
		var t1 := float(i + 1) / TRUNK_DRUMS
		var r0 := TRUNK_RADIUS * (1.0 - 0.45 * t0) * (1.0 if i > 0 else 1.15)
		var r1 := TRUNK_RADIUS * (1.0 - 0.45 * t1) * 0.92
		var colour := InteriorKit.solid(SpacePalette.shade(OasisPalette.PALM_TRUNK, 1 if i % 2 == 0 else 0))
		_drum(kit, f, _trunk_point(variety, t0), r0, _trunk_point(variety, t1), r1, colour)
	var crown := _trunk_point(variety, 1.0) + Vector3.UP * 0.1
	var dry := 2 if variety > 0.5 else 1
	for k in FRONDS:
		_frond(kit, f, crown, TAU * k / FRONDS + variety * 1.1, k < dry)

## A faceted frustum from `a` (radius `ra`) to `b` (radius `rb`), in the frame
## `f`, closed on top.
static func _drum(kit: InteriorKit, f: Transform3D, a: Vector3, ra: float, b: Vector3, rb: float,
		colour: Color) -> void:
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	for k in DRUM_SIDES:
		var d0 := u * cos(TAU * k / DRUM_SIDES) + v * sin(TAU * k / DRUM_SIDES)
		var d1 := u * cos(TAU * (k + 1) / DRUM_SIDES) + v * sin(TAU * (k + 1) / DRUM_SIDES)
		kit.quad(InteriorKit.Batch.SOLID, f * (a + d0 * ra), f * (a + d1 * ra), f * (b + d1 * rb),
			f * (b + d0 * rb), (f.basis * (d0 + d1)).normalized(), colour)
		kit.tri(InteriorKit.Batch.SOLID, f * b, f * (b + d1 * rb), f * (b + d0 * rb),
			(f.basis * axis).normalized(), colour)

## One flat frond from `crown`: a narrow root, a wide middle that lifts, and a
## tip that droops. Both faces are drawn.
static func _frond(kit: InteriorKit, f: Transform3D, crown: Vector3, angle: float, dry: bool) -> void:
	var out := Vector3(cos(angle), 0.0, sin(angle))
	var side := Vector3(-out.z, 0.0, out.x)
	var mid := crown + out * 1.5 + Vector3.UP * (0.0 if dry else 0.55)
	var tip := crown + out * 3.1 + Vector3.UP * (-1.8 if dry else -0.5)
	var colour := InteriorKit.solid(OasisPalette.PALM_FROND_DRY if dry else OasisPalette.PALM_FROND)
	var rl := crown - side * 0.15
	var rr := crown + side * 0.15
	var ml := mid - side * 0.7
	var mr := mid + side * 0.7
	for tri_points in [[rl, ml, mr], [rl, mr, rr], [ml, tip, mr]]:
		var a: Vector3 = f * tri_points[0]
		var b: Vector3 = f * tri_points[1]
		var c: Vector3 = f * tri_points[2]
		var n := (b - a).cross(c - a).normalized()
		if n.dot(f.basis.y) < 0.0:
			n = -n
		kit.tri(InteriorKit.Batch.SOLID, a, b, c, n, colour)
		kit.tri(InteriorKit.Batch.SOLID, a, b, c, -n, colour)

## The trunk of the palm at `f` as a capsule from its foot to its crown, for
## the caller's body (layer BodyProxy.LAYER). Its foot is the capsule's end.
static func palm_collider(f: Transform3D, variety: float) -> CollisionShape3D:
	var foot := f.origin
	var top := f * _trunk_point(variety, 1.0)
	var axis := (top - foot).normalized()
	var shape := CapsuleShape3D.new()
	shape.radius = COLLIDER_RADIUS
	shape.height = foot.distance_to(top)
	var c := CollisionShape3D.new()
	c.shape = shape
	c.transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)), (foot + top) * 0.5)
	return c

## How far the green reaches from its pool's centre at angle `theta` (in the
## horizontal plane, from x toward z): the ellipse `axes` (half its width
## along x and along z), its edge wobbled in and out by GREEN_WOBBLE so it is
## an organic outline, never a perfect ellipse. The same outline bounds the
## green patch and the tufts. Pure.
static func green_reach(axes: Vector2, theta: float, seed: int) -> float:
	return _reach(axes, theta, _wobble_phases(seed))

## GREEN_WOBBLE's phases for `seed`, worked out once for many _reach calls.
static func _wobble_phases(seed: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k in GREEN_WOBBLE.size():
		out.append(TAU * _noise(float(posmod(seed, 1000)), k, 70.0))
	return out

static func _reach(axes: Vector2, theta: float, phases: PackedFloat64Array) -> float:
	var c := cos(theta) / axes.x
	var s := sin(theta) / axes.y
	var wobble := 0.0
	for k in phases.size():
		wobble += float(GREEN_WOBBLE[k][1]) * sin(float(GREEN_WOBBLE[k][0]) * theta + phases[k])
	return (1.0 + wobble) / sqrt(c * c + s * s)

## The most the green reaches out past its ellipse, as a share of it.
static func green_spill() -> float:
	var out := 0.0
	for w: Array in GREEN_WOBBLE:
		out += float(w[1])
	return out

## The ring of grass round a pool at `f` (its centre, on the ground): tufts
## from `water_radius` + `inner` (the water edge and a bank) out to the
## green's outline (green_reach on the ellipse `axes`), as MultiMeshes with no
## collision, one a TUFT_TILE tile, each fading out round TUFT_REACH from the
## eye. `floor_of(x, z)` is the ground height in the frame's own terms, where
## each tuft stands. No tuft stands within an `avoid` circle (x, z in the
## frame, radius): a bed, the pump, a stone. Returns a Node3D "GrassRing"
## holding the tiles; where each tuft stands is kept as its meta `tufts`.
static func grass_ring(f: Transform3D, axes: Vector2, water_radius: float, inner: float,
		seed: int, floor_of: Callable, avoid: Array[Vector3] = []) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var keep_out := water_radius + inner
	var spill := 1.0 + green_spill()
	var area := PI * axes.x * axes.y * spill * spill - PI * keep_out * keep_out
	var tiles := {}   # Vector2i -> [transforms, colours]
	var feet := PackedVector3Array()
	for i in int(maxf(area, 0.0) * TUFTS_PER_M2):
		var rho := sqrt(rng.randf()) * spill
		var theta := rng.randf() * TAU
		var offset := Vector3(axes.x * rho * cos(theta), 0.0, axes.y * rho * sin(theta))
		var yaw := rng.randf() * TAU
		var height := rng.randf_range(TUFT_HEIGHT.x, TUFT_HEIGHT.y)
		var width := rng.randf_range(0.9, 1.4)
		var k := rng.randi_range(0, SpacePalette.SHADES.size() - 1)
		var keep := rng.randf()
		var jitter := rng.randf_range(-FADE_JITTER, FADE_JITTER)
		var flat := Vector2(offset.x, offset.z)
		var inside := green_reach(axes, flat.angle(), seed) - flat.length()
		if flat.length() <= keep_out or inside < 0.0:
			continue
		# Thinner toward the edge, and drier.
		var t := clampf(inside / TUFT_FADE_BAND, 0.0, 1.0)
		if keep > TUFT_KEEP.x + TUFT_KEEP.y * t * t:
			continue
		_tuft(tiles, feet, f, offset, yaw, Vector3(width, height, width), _fade_colour(inside / GREEN_FADE + jitter,
			OasisPalette.GRASS, k), avoid, floor_of)
	# The strays past the edge: singles, and a few clumps.
	for i in STRAYS + STRAY_CLUMPS:
		var theta := rng.randf() * TAU
		var out := lerpf(STRAY_OUT.x, STRAY_OUT.y, pow(rng.randf(), 1.5))
		var r := green_reach(axes, theta, seed) + out
		var middle := Vector2(cos(theta), sin(theta)) * r
		var n := 1 if i < STRAYS else rng.randi_range(CLUMP_TUFTS.x, CLUMP_TUFTS.y)
		for j in n:
			var p := middle
			if n > 1:
				p += Vector2.from_angle(rng.randf() * TAU) * CLUMP_RADIUS * sqrt(rng.randf())
			var height := rng.randf_range(TUFT_HEIGHT.x, lerpf(TUFT_HEIGHT.x, TUFT_HEIGHT.y, 0.6))
			var width := rng.randf_range(0.8, 1.2)
			var colour := OasisPalette.GRASS_DRY_EDGE if rng.randf() < 0.7 else OasisPalette.GRASS_OLIVE
			_tuft(tiles, feet, f, Vector3(p.x, 0.0, p.y), rng.randf() * TAU, Vector3(width, height, width),
				InteriorKit.solid(SpacePalette.shade(colour, rng.randi_range(0, SpacePalette.SHADES.size() - 1))),
				avoid, floor_of)
	var ring := Node3D.new()
	ring.name = "GrassRing"
	## Where each tuft stands, kept here too: a MultiMesh reads back nothing
	## without a renderer (the headless tests).
	ring.set_meta(&"tufts", feet)
	var keys := tiles.keys()
	keys.sort()
	for tile: Vector2i in keys:
		var transforms: Array = tiles[tile][0]
		var colours: Array = tiles[tile][1]
		# Each tile's node at its tufts' middle, so the visibility range is
		# measured to where its tufts are.
		var middle := Vector3.ZERO
		for t: Transform3D in transforms:
			middle += t.origin
		middle /= transforms.size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = GroundCover.grass_mesh()
		mm.instance_count = transforms.size()
		for i in transforms.size():
			var t: Transform3D = transforms[i]
			mm.set_instance_transform(i, Transform3D(t.basis, t.origin - middle))
			mm.set_instance_color(i, colours[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Tufts_%d_%d" % [tile.x, tile.y]
		inst.multimesh = mm
		inst.position = middle
		inst.material_override = CoverField.grass_material()
		inst.layers = WORLD_LAYER
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.visibility_range_end = TUFT_REACH
		inst.visibility_range_end_margin = TUFT_FADE
		inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		ring.add_child(inst)
	return ring

## One tuft at `offset` in `f`'s frame into its tile (unless it stands in an
## `avoid` circle), on the ground `floor_of` gives.
static func _tuft(tiles: Dictionary, feet: PackedVector3Array, f: Transform3D, offset: Vector3, yaw: float,
		scale: Vector3, colour: Color, avoid: Array[Vector3], floor_of: Callable) -> void:
	var at: Vector3 = f * offset
	for a in avoid:
		if Vector2(at.x - a.x, at.z - a.y).length() < a.z:
			return
	at.y = float(floor_of.call(at.x, at.z))
	var tile := Vector2i(floori(offset.x / TUFT_TILE), floori(offset.z / TUFT_TILE))
	if not tiles.has(tile):
		tiles[tile] = [[], []]
	tiles[tile][0].append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), at))
	tiles[tile][1].append(colour)
	feet.append(at)

## The green's colour `fade` across its dry rim (GREEN_FADE bands in from the
## outline, jittered): `green` (shade k) well inside, GRASS_OLIVE nearer the
## edge, GRASS_DRY_EDGE at it. Linear, as the kit's colours are.
static func _fade_colour(fade: float, green: Color, k: int) -> Color:
	var base := green if fade > 0.67 else (OasisPalette.GRASS_OLIVE if fade > 0.3 else OasisPalette.GRASS_DRY_EDGE)
	return InteriorKit.solid(SpacePalette.shade(base, k))

## The green patch under a pool's grass ring: a flat, faceted carpet in
## OasisPalette.GREEN_PATCH, laid on `ground`, the ground's own triangles
## (each a PackedVector3Array of three points in the kit's space, y up, as the
## world draws them), PATCH_PROUD over them. Each triangle is cut to the
## green: inside its outline (green_reach on the ellipse `axes` round
## `centre`) and out of the water (`water_radius` + PATCH_SHORE from
## `centre`); a cut point lies on the triangle's own edge, so every vertex
## lies on the drawn ground. Its shade changes in broad patches by where each
## triangle lies, and (Rework 2) over its outer GREEN_FADE m it dries,
## through GRASS_OLIVE to GRASS_DRY_EDGE (_fade_colour). Returns every vertex
## laid, in the kit's space.
static func green_patch(kit: InteriorKit, ground: Array, centre: Vector3, axes: Vector2, water_radius: float,
		seed: int) -> PackedVector3Array:
	var shore := water_radius + PATCH_SHORE
	var phases := _wobble_phases(seed)
	var lift := Vector3(0.0, PATCH_PROUD, 0.0)
	var laid := PackedVector3Array()
	for tri: PackedVector3Array in ground:
		# How far inside the outline and out of the water each corner is: a
		# triangle wholly in is laid as it is, one wholly out is skipped, and
		# only one across an edge is cut.
		var outer := PackedFloat64Array()
		var inner := PackedFloat64Array()
		for p in tri:
			var d := Vector2(p.x - centre.x, p.z - centre.z)
			outer.append(_reach(axes, d.angle(), phases) - d.length())
			inner.append(d.length() - shore)
		if (outer[0] < 0.0 and outer[1] < 0.0 and outer[2] < 0.0) \
				or (inner[0] < 0.0 and inner[1] < 0.0 and inner[2] < 0.0):
			continue
		var poly := tri
		if outer[0] < 0.0 or outer[1] < 0.0 or outer[2] < 0.0:
			poly = _clip(poly, outer)
			inner.clear()
			for p in poly:
				inner.append(Vector2(p.x - centre.x, p.z - centre.z).length() - shore)
		for v in inner:
			if v < 0.0:
				poly = _clip(poly, inner)
				break
		if poly.size() < 3:
			continue
		var middle := Vector3.ZERO
		for p in poly:
			middle += p
		middle /= poly.size()
		var k := _patch_shade(middle - centre, seed)
		var from := Vector2(middle.x - centre.x, middle.z - centre.z)
		var jitter := (_noise(middle.x, middle.z, 72.0) - 0.5) * 2.0 * FADE_JITTER
		var fade := (_reach(axes, from.angle(), phases) - from.length()) / GREEN_FADE + jitter
		var colour := _fade_colour(fade, OasisPalette.GREEN_PATCH, k)
		for i in range(1, poly.size() - 1):
			var a := poly[0] + lift
			var b := poly[i] + lift
			var c := poly[i + 1] + lift
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-10:
				continue
			n = n.normalized()
			kit.tri(InteriorKit.Batch.SOLID, a, b, c, n if n.y > 0.0 else -n, colour)
		for p in poly:
			laid.append(p + lift)
	return laid

## The shade (an index into SpacePalette.SHADES) of the green at `p` (from
## its pool's centre): broad, soft bands about PATCH_WAVE across, mostly the
## middle shade.
static func _patch_shade(p: Vector3, seed: int) -> int:
	var a := TAU * _noise(float(posmod(seed, 1000)), 1.0, 71.0)
	var w := TAU / PATCH_WAVE
	var n := sin(p.x * w + a) + sin(p.z * w * 0.83 - a * 1.7) + sin((p.x + p.z) * w * 0.61 + a * 2.3)
	return 0 if n < -1.0 else (2 if n > 1.2 else 1)

## The polygon `poly` cut to where `value` (one a point) is >= 0, each cut
## point on the edge it crosses (so it stays on the polygon's plane), the
## value taken to change evenly along it. Sutherland-Hodgman.
static func _clip(poly: PackedVector3Array, value: PackedFloat64Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := poly.size()
	if n < 3:
		return out
	for i in n:
		var sp := value[i]
		var sq := value[(i + 1) % n]
		if sp >= 0.0:
			out.append(poly[i])
		if (sp >= 0.0) != (sq >= 0.0):
			out.append(poly[i].lerp(poly[(i + 1) % n], sp / (sp - sq)))
	return out

## A garden at `f`: a low raised bed of `size` (x and z, m) of soil with rows
## of crops, green, or collapsed and dry when `dried`. The bed's foot is 0.08 m
## into the ground, so no gap shows under it.
static func garden(kit: InteriorKit, f: Transform3D, size: Vector2, dried: bool, variety: float) -> void:
	kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, 0.12, 0)),
		Vector3(size.x, 0.4, size.y), 0.08, InteriorKit.solid(OasisPalette.GARDEN_SOIL))
	crops(kit, f, size, dried, variety)

## The bed's top over its foot, m: where the crops stand.
const BED_TOP := 0.28

## A garden's rows of crops at `f` (the bed's foot), green or dry, each `widen` m
## wider than a crop: the sun pump's green, grown over a dry bed's crops, is a
## little wider so it covers them (SunPump).
static func crops(kit: InteriorKit, f: Transform3D, size: Vector2, dried: bool, variety: float, widen := 0.0) -> void:
	var crop := OasisPalette.CROP_DRY if dried else OasisPalette.CROP_GREEN
	var rows := maxi(int((size.y - 0.4) / 0.6) + 1, 1)
	var cols := maxi(int((size.x - 0.5) / 0.55) + 1, 1)
	for r in rows:
		for c in cols:
			var n := _noise(variety, c, r)
			var h := (0.15 + 0.1 * n) if dried else (0.28 + 0.2 * n)
			var at := Vector3(-size.x * 0.5 + 0.3 + c * 0.55, BED_TOP + h * 0.5, -size.y * 0.5 + 0.3 + r * 0.6)
			kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(at), Vector3(0.3 + widen, h, 0.3 + widen), 0.06,
				InteriorKit.solid(SpacePalette.shade(crop, int(n * 2.99))))

# --- the memorial ---------------------------------------------------------------

## The memorial (Wadoo spec §4): its stones stand round a ring, stone k at
## MEMORIAL_TURN + TAU k / stones from east toward north, where WadooSite puts a
## mourner's kneeling spot; each is MEMORIAL_STONE (wide, tall, thick, its height
## give or take a fifth) and leans back a little; a lamp stands LAMP_OUT outside it
## and LAMP_ASIDE to its side, so a mourner kneels before the stone beside it.
const MEMORIAL_TURN := 0.3
const MEMORIAL_STONE := Vector3(0.62, 1.5, 0.3)
const MEMORIAL_SINK := 0.2
const CAIRN_ROCKS := 7
const LAMP_OUT := 0.45
const LAMP_ASIDE := 0.42
const LAMP_HEIGHT := 0.42
const LAMP_GLASS := 0.15

## The way from the memorial's middle to stone `k` of `stones`, in the place's
## frame (x east, z -north).
static func memorial_dir(k: int, stones: int) -> Vector3:
	var a := MEMORIAL_TURN + TAU * k / stones
	return Vector3(cos(a), 0.0, -sin(a))

## The memorial at `f` (its middle on the ground): `stones` standing stones on a
## ring of `radius`, a low cairn in the middle, a sunglass lamp before each stone.
static func memorial(kit: InteriorKit, f: Transform3D, radius: float, stones: int, variety: float) -> void:
	var bronze := InteriorKit.solid(OasisPalette.BRONZE)
	var glass := InteriorKit.lit(OasisPalette.SUNGLASS, InteriorMaterials.GLOW_ENERGY)
	for i in CAIRN_ROCKS:
		var n := _noise(variety, i, 31.0)
		var top := i >= CAIRN_ROCKS - 2
		var a := TAU * i / (CAIRN_ROCKS - 2) + n
		var at := Vector3(0.0, 0.5, 0.0) if i == CAIRN_ROCKS - 1 else (
			Vector3(cos(a) * 0.18, 0.32, -sin(a) * 0.18) if top else Vector3(cos(a) * 0.42, 0.1, -sin(a) * 0.42))
		var size := Vector3(0.42, 0.3, 0.38) * (0.8 + 0.4 * n)
		kit.bevel_box(InteriorKit.Batch.SOLID, f * Transform3D(Basis(Vector3.UP, n * TAU), at), size, 0.08,
			InteriorKit.solid(SpacePalette.shade(OasisPalette.MEMORIAL_STONE, int(n * 2.99))))
	for k in stones:
		var d := memorial_dir(k, stones)
		var n := _noise(variety, k, 41.0)
		var size := Vector3(MEMORIAL_STONE.x, MEMORIAL_STONE.y * (0.8 + 0.4 * n), MEMORIAL_STONE.z)
		var face := Basis.looking_at(-d, Vector3.UP)
		var lean := Basis(face.x, -0.05 - 0.07 * n)
		var at := d * radius
		kit.bevel_box(InteriorKit.Batch.SOLID,
			f * Transform3D(lean * face, at + Vector3(0.0, size.y * 0.5 - MEMORIAL_SINK, 0.0)), size, 0.08,
			InteriorKit.solid(SpacePalette.shade(OasisPalette.MEMORIAL_STONE, int(n * 2.99))))
		var foot := at + d * LAMP_OUT + face.x * LAMP_ASIDE
		kit.tube_between(InteriorKit.Batch.SOLID, f * (foot - Vector3(0.0, 0.1, 0.0)),
			f * (foot + Vector3(0.0, LAMP_HEIGHT, 0.0)), 0.025, bronze)
		kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(foot + Vector3(0.0, LAMP_HEIGHT, 0.0)),
			Vector3(0.14, 0.05, 0.14), 0.015, bronze)
		kit.bevel_box(InteriorKit.Batch.GLOW, f * Transform3D(Basis(Vector3(1, 0, 1).normalized(), PI * 0.25),
			foot + Vector3(0.0, LAMP_HEIGHT + LAMP_GLASS * 0.6, 0.0)), Vector3.ONE * LAMP_GLASS, 0.03, glass)

## The memorial's colliders: each stone, and the cairn.
static func memorial_shapes(f: Transform3D, radius: float, stones: int) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	for k in stones:
		var d := memorial_dir(k, stones)
		var c := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = MEMORIAL_STONE
		c.shape = box
		c.transform = f * Transform3D(Basis.looking_at(-d, Vector3.UP), d * radius + Vector3(0.0, MEMORIAL_STONE.y * 0.5 - MEMORIAL_SINK, 0.0))
		out.append(c)
	var cairn := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.6
	cyl.height = 0.7
	cairn.shape = cyl
	cairn.transform = f * InteriorKit.at(Vector3(0.0, 0.25, 0.0))
	out.append(cairn)
	return out

## A hand pump at `f`: a squat base, a column with a cap, a spout and a handle.
static func pump(kit: InteriorKit, f: Transform3D) -> void:
	var body := InteriorKit.solid(OasisPalette.PUMP)
	var dark := InteriorKit.solid(OasisPalette.PUMP_DARK)
	kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, 0.175, 0)), Vector3(0.7, 0.35, 0.7), 0.05, dark)
	kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(0, 0.3, 0), f * Vector3(0, 1.25, 0), 0.2, body)
	kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, 1.3, 0)), Vector3(0.5, 0.15, 0.5), 0.04, dark)
	kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(0, 1.0, 0), f * Vector3(0.5, 0.9, 0), 0.06,
		InteriorKit.solid(OasisPalette.PIPE))
	kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(-0.55, 1.6, 0), f * Vector3(0.25, 1.42, 0), 0.04, dark)

# --- Halla's sun pump (Wadoo spec §7) ------------------------------------------

## The sun pump's measures, m: the well head (radius, height); its two posts
## stand SUN_FRAME apart and SUN_FRAME_TALL high; the cage's middle (where a sun
## cell sits) at SUN_CAGE, SUN_CAGE_SIZE (radius, half height); the rod's pivot
## on the west post.
const SUN_WELL := Vector2(0.46, 0.6)
const SUN_FRAME := 0.86
const SUN_FRAME_TALL := 1.72
const SUN_CAGE := 1.4
const SUN_CAGE_SIZE := Vector2(0.12, 0.17)
const SUN_ROD_PIVOT := Vector3(-0.43, 1.12, 0.0)

## Halla's sun pump at `f` (its foot on the ground; the frame across x): a round
## stone well head with a dark mouth, two bronze posts and a crossbar, and the
## bronze cage hung from it where the sun cell goes, empty.
static func sun_pump(kit: InteriorKit, f: Transform3D) -> void:
	var stone := InteriorKit.solid(OasisPalette.PUMP)
	var dark := InteriorKit.solid(OasisPalette.PUMP_DARK)
	var bronze := InteriorKit.solid(OasisPalette.BRONZE)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(0, -0.1, 0), f * Vector3(0, SUN_WELL.y, 0), SUN_WELL.x, stone)
	kit.ring(InteriorKit.Batch.SOLID, f * Transform3D(up, Vector3(0, SUN_WELL.y, 0)), SUN_WELL.x - 0.1, SUN_WELL.x + 0.03,
		0.0, 0.07, dark)
	kit.disc(InteriorKit.Batch.SOLID, f * Transform3D(up, Vector3(0, SUN_WELL.y - 0.05, 0)), SUN_WELL.x - 0.1, dark)
	for x: float in [-SUN_FRAME * 0.5, SUN_FRAME * 0.5]:
		kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(x, SUN_WELL.y - 0.2, 0), f * Vector3(x, SUN_FRAME_TALL, 0), 0.035, bronze)
	kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(-SUN_FRAME * 0.5 - 0.06, SUN_FRAME_TALL, 0),
		f * Vector3(SUN_FRAME * 0.5 + 0.06, SUN_FRAME_TALL, 0), 0.04, bronze)
	var lo := SUN_CAGE - SUN_CAGE_SIZE.y
	var hi := SUN_CAGE + SUN_CAGE_SIZE.y
	for y: float in [lo, hi]:
		kit.ring(InteriorKit.Batch.SOLID, f * Transform3D(up, Vector3(0, y - 0.015, 0)), SUN_CAGE_SIZE.x - 0.015,
			SUN_CAGE_SIZE.x + 0.01, 0.0, 0.03, bronze)
	for i in 6:
		var d := Vector3(cos(TAU * i / 6.0), 0, sin(TAU * i / 6.0)) * SUN_CAGE_SIZE.x
		kit.tube_between(InteriorKit.Batch.SOLID, f * (d + Vector3(0, lo, 0)), f * (d + Vector3(0, hi, 0)), 0.01, bronze)
	kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(0, hi, 0), f * Vector3(0, SUN_FRAME_TALL, 0), 0.018, bronze)

## The sun pump's rod, in its pivot's frame `f`: a bronze beam out over the well's
## mouth and a rod hanging from its end down into it. It nods while the pump draws.
static func sun_pump_rod(kit: InteriorKit, f: Transform3D) -> void:
	var bronze := InteriorKit.solid(OasisPalette.BRONZE)
	var end := Vector3(-SUN_ROD_PIVOT.x, 0.0, 0.0)
	kit.tube_between(InteriorKit.Batch.SOLID, f * Vector3(-0.08, 0, 0), f * (end + Vector3(0.1, 0, 0)), 0.03, bronze)
	kit.tube_between(InteriorKit.Batch.SOLID, f * end, f * (end + Vector3(0, -(SUN_ROD_PIVOT.y - SUN_WELL.y) - 0.15, 0)),
		0.022, InteriorKit.solid(OasisPalette.PUMP_DARK))

## A stone channel on the ground from `a` to `b` (both in the kit's space, on the
## ground): a shallow trough `width` m across, its floor dark.
static func channel(kit: InteriorKit, a: Vector3, b: Vector3, width: float) -> void:
	var way := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := way.length()
	if length < 0.01:
		return
	var basis := Basis(Vector3.UP, atan2(-way.z, way.x))
	var mid := (a + b) * 0.5
	for side: float in [-1.0, 1.0]:
		kit.bevel_box(InteriorKit.Batch.SOLID, Transform3D(basis, mid + basis * Vector3(0, 0.06, side * (width * 0.5 + 0.04))),
			Vector3(length, 0.16, 0.08), 0.02, InteriorKit.solid(OasisPalette.PUMP))
	kit.box(InteriorKit.Batch.SOLID, Transform3D(basis, mid + Vector3(0, 0.0, 0)), Vector3(length, 0.04, width),
		InteriorKit.solid(OasisPalette.PUMP_DARK))

## The water running in a channel from `a` to `b`: a flat strip just under the
## trough's lip.
static func channel_water(kit: InteriorKit, a: Vector3, b: Vector3, width: float) -> void:
	var way := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := way.length()
	if length < 0.01:
		return
	var basis := Basis(Vector3.UP, atan2(-way.z, way.x))
	kit.box(InteriorKit.Batch.SOLID, Transform3D(basis, (a + b) * 0.5 + Vector3(0, 0.07, 0)), Vector3(length, 0.02, width),
		InteriorKit.solid(OasisPalette.WATER))

## A pipe from `from` to `to` (both in the kit's space).
static func pipe(kit: InteriorKit, from: Vector3, to: Vector3) -> void:
	kit.tube_between(InteriorKit.Batch.SOLID, from, to, 0.07, InteriorKit.solid(OasisPalette.PIPE))

## A path: one flat stone at each of `points` (already on the ground), turned
## along the way to the next, and set across it by up to a third of `width`.
static func path(kit: InteriorKit, points: PackedVector3Array, width: float) -> void:
	for i in points.size():
		var way := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		way.y = 0.0
		var yaw := atan2(-way.z, way.x) if way.length() > 0.01 else 0.0
		var n := _noise(float(i), width, 1.0)
		var m := _noise(float(i), width, 2.0)
		var basis := Basis(Vector3.UP, yaw + (m - 0.5) * 0.5)
		var across := basis * Vector3(0.0, 0.0, (n - 0.5) * width * 0.66)
		var stone := Vector3(0.6 + 0.3 * m, 0.08, 0.5 + 0.2 * n)
		var colour := SpacePalette.shade(OasisPalette.PATH, int(n * 2.99))
		kit.bevel_box(InteriorKit.Batch.SOLID, Transform3D(basis, points[i] + across + Vector3(0, 0.02, 0)),
			stone, 0.025, InteriorKit.solid(colour))

# --- the beast's tracks ---------------------------------------------------------

## The tracks are tuned at Checkpoint B to read from the seat coming in: every
## number that sets their size, gait and fade is here.
##
## A print: an oval PRINT_LENGTH long and PRINT_WIDTH wide (a little wider at
## its toes), with three toe notches NOTCH_DEPTH of its radius deep in its
## front, drawn as PRINT_SECTORS sectors of PRINT_RINGS quads out from its
## middle, PRINT_PROUD over the ground.
##
## Checkpoint B (the owner: at 40 m "dark dots", at 150 m "a thin dotted
## line") made them 1.5 times as big: the print 2.4 m to 3.6 m long, and the
## stride and gauges with it. PRINT_RINGS went from 2 to 3 so the vertices
## stay about as close as they were, each on the ground under it.
const PRINT_LENGTH := 3.6
const PRINT_WIDTH := 2.1
const NOTCH_DEPTH := 0.3
const PRINT_SECTORS := 24
const PRINT_RINGS := 3
const PRINT_PROUD := 0.03
## The beast's gait: four feet to a STRIDE; the front feet FRONT_GAUGE either
## side of the line, the hind HIND_GAUGE (inside the front, so no two prints
## lie on each other), each toed out by TOE_OUT radians.
const STRIDE := 10.5
const FRONT_GAUGE := 3.0
const HIND_GAUGE := 0.8
const TOE_OUT := 0.12
## The first print this far along from where the tracks start, m.
const TRACK_START := 1.5
## Along the tracks the prints fade from OasisPalette.TRACK toward the sand,
## TRACK_FADE of the way by the end; over the last third they thin out, to a
## TRACK_THIN share kept at the very end.
const TRACK_FADE := 0.8
const TRACK_THIN := 0.3

## [share of a stride, how far right of the line (m)] of each foot, in the
## order they fall: front left, hind right, front right, hind left.
const _FEET := [[0.0, -FRONT_GAUGE], [0.25, HIND_GAUGE], [0.5, FRONT_GAUGE], [0.75, -HIND_GAUGE]]

## The beast's tracks in the frame `f` (its x east, its -z north): flat,
## darker prints from `from` ([east, north] m in f) along `bearing_deg`
## (clockwise from north) for `length` m, four feet to a stride. Each print's
## vertices sit on the ground's own triangles: a print is quads, split as
## TerrainChunkData splits its quads, each corner at `floor_of(x, z)` (the
## ground's height in f's terms) and PRINT_PROUD over it. The colour fades
## toward the sand of `palette` (a world palette, the desert's when none is
## given: its `ground_low`, as the ground's own vertex colours carry it) and
## the last third thins out. Both run over `fade_over` m (the tracks' own
## length when 0): a short set off a long one fades at the long one's rate.
## One mesh on the world's layer, no collision; each print's vertices (in f's
## parent's terms) are kept as meta `prints`, which a headless test reads.
static func tracks(f: Transform3D, from: Vector2, bearing_deg: float, length: float, floor_of: Callable,
		variety: float, palette: Dictionary = {}, fade_over := 0.0) -> MeshInstance3D:
	var land: Dictionary = palette if not palette.is_empty() else SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE]
	var sand: Color = land[&"ground_low"]
	var bearing := deg_to_rad(bearing_deg)
	var ahead := Vector3(sin(bearing), 0.0, -cos(bearing))
	var right := Vector3(cos(bearing), 0.0, sin(bearing))
	var start := Vector3(from.x, 0.0, -from.y)
	var kit := InteriorKit.new(null)
	var prints: Array[PackedVector3Array] = []
	var strides := int((length - TRACK_START) / STRIDE) + 1
	for s in strides:
		for k in _FEET.size():
			var along := TRACK_START + (s + float(_FEET[k][0])) * STRIDE
			if along > length:
				continue
			var t := along / (fade_over if fade_over > 0.0 else length)
			if t > 2.0 / 3.0 and _noise(variety, s, k + 20.0) > lerpf(1.0, TRACK_THIN, (t - 2.0 / 3.0) * 3.0):
				continue
			var lateral := float(_FEET[k][1])
			var jitter := (_noise(variety, s, k + 40.0) - 0.5) * 0.4
			var heading := bearing + TOE_OUT * signf(lateral) + (_noise(variety, s, k + 30.0) - 0.5) * 0.12
			var colour := InteriorKit.solid(OasisPalette.TRACK).lerp(sand, t * TRACK_FADE)
			prints.append(_print(kit, f, start + ahead * (along + jitter) + right * lateral, heading, floor_of, colour))
	var inst := MeshInstance3D.new()
	inst.name = "Tracks"
	inst.mesh = kit.mesh(InteriorKit.Batch.SOLID)
	inst.material_override = InteriorMaterials.props()
	inst.layers = WORLD_LAYER
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.set_meta(&"prints", prints)
	return inst

## How far a print's edge is from its middle at angle `a` from its front.
static func _print_reach(a: float, sector: int) -> float:
	var along := PRINT_LENGTH * 0.5
	var across := PRINT_WIDTH * 0.5 * (1.0 + 0.12 * cos(a))
	var r := 1.0 / sqrt(pow(cos(a) / along, 2) + pow(sin(a) / across, 2))
	# The toe notches: the front sector and the second either side of it.
	if sector == 0 or sector == 2 or sector == PRINT_SECTORS - 2:
		r *= 1.0 - NOTCH_DEPTH
	return r

## One print at `centre` (f's terms, its height ignored) facing `heading`;
## returns its vertices in f's parent's terms.
static func _print(kit: InteriorKit, f: Transform3D, centre: Vector3, heading: float, floor_of: Callable,
		colour: Color) -> PackedVector3Array:
	var fwd := Vector3(sin(heading), 0.0, -cos(heading))
	var rt := Vector3(cos(heading), 0.0, sin(heading))
	var on := func(p: Vector3) -> Vector3:
		return f * Vector3(p.x, float(floor_of.call(p.x, p.z)) + PRINT_PROUD, p.z)
	# rings[0] is the middle; ring r (1 to PRINT_RINGS) is r / PRINT_RINGS of the way out.
	var rings: Array[PackedVector3Array] = [PackedVector3Array([on.call(centre)])]
	var out := PackedVector3Array([rings[0][0]])
	for r in range(1, PRINT_RINGS + 1):
		var ring := PackedVector3Array()
		for s in PRINT_SECTORS:
			var a := TAU * s / PRINT_SECTORS
			var p: Vector3 = on.call(centre + (fwd * cos(a) + rt * sin(a)) * _print_reach(a, s) * float(r) / PRINT_RINGS)
			ring.append(p)
			out.append(p)
		rings.append(ring)
	var up := f.basis.y.normalized()
	for s in PRINT_SECTORS:
		var n := (s + 1) % PRINT_SECTORS
		_print_tri(kit, rings[0][0], rings[1][s], rings[1][n], up, colour)
		for r in range(1, PRINT_RINGS):
			# Quad i00-i10-i11-i01, split i00-i10-i11 and i00-i11-i01 as a chunk's.
			var i00 := rings[r][s]
			var i10 := rings[r][n]
			var i01 := rings[r + 1][s]
			var i11 := rings[r + 1][n]
			_print_tri(kit, i00, i10, i11, up, colour)
			_print_tri(kit, i00, i11, i01, up, colour)
	return out

static func _print_tri(kit: InteriorKit, a: Vector3, b: Vector3, c: Vector3, up: Vector3, colour: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(up) < 0.0:
		n = -n
	kit.tri(InteriorKit.Batch.SOLID, a, b, c, n, colour)

# --- the ledge (Rework 2) ----------------------------------------------------------

## The ledge is the world's own ground (a MESA stamp, its sides in the world's
## rock look); what dresses it is here (the owner: the old outcrop "looks
## totally out of place"). Its foot: a few RockMesh boulders fallen from the
## face, LEDGE_BOULDER m across, sunk BOULDER_SUNK of that, and a talus of
## smaller stones LEDGE_TALUS m across, all in the world's `boulder` shades as
## its own boulders take them (raw, on the ground's material). Its boulders are
## RockMesh's at LEDGE_DETAIL, the talus at TALUS_DETAIL.
const LEDGE_DETAIL := 1
const TALUS_DETAIL := 0
const LEDGE_BOULDER := Vector2(1.6, 3.4)
const LEDGE_TALUS := Vector2(0.25, 0.8)
const BOULDER_SUNK := 0.25
## Where they lie: boulders within this band of the foot (m: in, out), the
## talus within the wider one; most on the village side, within SPREAD
## radians of its bearing; none within STAIR_CLEAR m of a step's middle.
const BOULDER_BAND := Vector2(-0.6, 1.8)
const TALUS_BAND := Vector2(-1.5, 4.5)
const SPREAD := 1.4
const STAIR_CLEAR := 2.0
## A rough stair cut into the ledge's village side, along its face:
## flat-topped stone blocks STAIR_STONE m (along, across), in the face's own
## rock (the palette's `ground_high`), STAIR_TREAD apart along the face, each
## rising the same, no more than STAIR_RISE (a jump peaks at 0.89 m), from the
## ground at its foot to the flat top. Each block's middle is STAIR_OUT out
## from where the face stands STAIR_LIP under its tread, so its back is bitten
## into the slope and it shows a low front, never a post; its foot STAIR_UNDER
## under the lowest ground beneath it, turned up to STAIR_TWIST either way.
## The last lands LANDING_IN m inside the top's lip.
const STAIR_STONE := Vector2(1.48, 1.3)
const STAIR_TREAD := 1.4
const STAIR_RISE := 0.62
const STAIR_OUT := 0.2
const STAIR_LIP := 0.1
const STAIR_UNDER := 0.3
const STAIR_TWIST := 0.05
const LANDING_IN := 0.5

## A layout point [east, north] and a height as a point in the place's frame.
static func _at(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, -p.y)

## The stair up a ledge whose middle is `centre` ([east, north] m) and whose
## flat top stands at `top` (in the place's frame), from `from` along the way
## to `to` (both [east, north], on the ledge's side, out past its foot):
## `height_of(east, north)` is the ground's height. Each step k is found where
## the face, measured across the line, stands at its rise's middle. Pure.
## Returns {"steps": [[top middle (place frame), unit way up to it from the
## last, size (along, height, across), turn off the line, the line's unit
## way]...], "landing": the point on the flat top the last step leads to}.
static func ledge_stair(height_of: Callable, centre: Vector2, from: Vector2, to: Vector2, top: float,
		variety: float) -> Dictionary:
	var dir := (to - from).normalized()
	var out := Vector2(-dir.y, dir.x)
	if out.dot(from - centre) < 0.0:
		out = -out
	var ground := float(height_of.call(from.x, from.y))
	var n := maxi(2, ceili((top - ground) / STAIR_RISE))
	var rise := (top - ground) / n
	var steps := []
	var last := _at(from, ground)
	for k in range(1, n + 1):
		var h := ground + rise * k
		var along := from + dir * (STAIR_TREAD * k)
		# Across the line, the face falls outward: where it stands just under
		# the tread (the landing: just under the top).
		var want := h - STAIR_LIP if k < n else top - 0.03
		var lo := -12.0
		var hi := 8.0
		for i in 40:
			var mid := (lo + hi) * 0.5
			if float(height_of.call(along.x + out.x * mid, along.y + out.y * mid)) > want:
				lo = mid
			else:
				hi = mid
		var t := (lo + hi) * 0.5
		if k == n:
			var landing := along + out * (t - LANDING_IN)
			return {"steps": steps, "landing": _at(landing, float(height_of.call(landing.x, landing.y)))}
		var middle := along + out * (t + STAIR_OUT)
		var turn := (_noise(variety, k, 80.0) - 0.5) * 2.0 * STAIR_TWIST
		var x := dir.rotated(-turn)
		var low := INF
		for sx in [-0.5, 0.0, 0.5]:
			for sz in [-0.5, 0.0, 0.5]:
				var p: Vector2 = middle + x * (STAIR_STONE.x * sx) + Vector2(-x.y, x.x) * (STAIR_STONE.y * sz)
				low = minf(low, float(height_of.call(p.x, p.y)))
		var at := _at(middle, h)
		var way := at - last
		way.y = 0.0
		steps.append([at, way.normalized(), Vector3(STAIR_STONE.x, h - low + STAIR_UNDER, STAIR_STONE.y), turn,
			Vector3(dir.x, 0.0, -dir.y)])
		last = at
	return {"steps": steps, "landing": last}

## The rocks at a ledge's foot: `boulders` and `talus` of them round `centre`
## ([east, north] m), most toward `facing` (a bearing, rad), at the foot
## `foot_of(bearing)` m out, each resting on `height_of(east, north)`, none on
## the stair's `steps`. Pure. Returns [[shape, placement (place frame),
## diameter, shade, detail]...], the boulders first.
static func ledge_rocks(height_of: Callable, centre: Vector2, foot_of: Callable, facing: float, steps: Array,
		boulders: int, talus: int, variety: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(variety * 100003.0) * 17 + boulders * 131 + talus
	var out := []
	var tries := 0
	while out.size() < boulders + talus and tries < (boulders + talus) * 20:
		tries += 1
		var big := out.size() < boulders
		# Two thirds toward the village, a third anywhere round it.
		var bearing := facing + rng.randfn(0.0, SPREAD * 0.5) if rng.randf() < 0.67 else rng.randf() * TAU
		var band := BOULDER_BAND if big else TALUS_BAND
		var r := float(foot_of.call(bearing)) + rng.randf_range(band.x, band.y)
		var p := centre + Vector2(sin(bearing), cos(bearing)) * r
		var clear := true
		for s: Array in steps:
			var m: Vector3 = s[0]
			if Vector2(m.x, -m.z).distance_to(p) < STAIR_CLEAR * (1.0 if big else 0.7):
				clear = false
		if not clear:
			continue
		var size := LEDGE_BOULDER if big else LEDGE_TALUS
		var d := lerpf(size.x, size.y, pow(rng.randf(), 1.6))
		var stretch := Vector3(rng.randf_range(0.8, 1.25), rng.randf_range(0.65, 1.0), rng.randf_range(0.8, 1.25))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))) \
			* Basis.from_scale(stretch * d)
		var shape := RockMesh.Shape.BOULDER if rng.randf() < 0.6 else RockMesh.Shape.SHARD
		var detail := LEDGE_DETAIL if big else TALUS_DETAIL
		var lo := INF
		for v in RockMesh.cut_vertices(shape, detail):
			lo = minf(lo, (basis * v).y)
		var ground := float(height_of.call(p.x, p.y))
		var sunk := BOULDER_SUNK * d if big else 0.12 * d
		out.append([shape, Transform3D(basis, _at(p, ground - sunk - lo)), d, rng.randi_range(0, SpacePalette.SHADES.size() - 1),
			detail])
	return out

## The ledge's dressing: one Node3D "Ledge" holding one mesh (its stair's
## stones in `palette`'s `ground_high` shades, as the face they are cut in,
## and its foot's rocks in its `boulder` shades as the world's boulders, all
## raw on the ground's own material) and one StaticBody3D "Stones" on
## BodyProxy.LAYER: a box a step and a hull a boulder (the talus is too small
## to stop you). The stair (ledge_stair's) is kept as its meta `steps`
## ([top middle, way] each) and `landing`; the counts as `boulders`, `talus`.
static func ledge(stair: Dictionary, rocks: Array, boulders: int, palette: Dictionary = {}) -> Node3D:
	var land: Dictionary = palette if not palette.is_empty() else SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE]
	var base: Color = land[&"boulder"]
	var cut: Color = land[&"ground_high"]
	var node := Node3D.new()
	node.name = "Ledge"
	var body := StaticBody3D.new()
	body.name = "Stones"
	body.collision_layer = BodyProxy.LAYER
	body.collision_mask = 0
	node.add_child(body)
	var kit := kit_under(node)
	kit.materials[InteriorKit.Batch.SOLID] = BodyLook.material(false)
	var meta := []
	var steps: Array = stair["steps"]
	for k in steps.size():
		var s: Array = steps[k]
		var at: Vector3 = s[0]
		var size: Vector3 = s[2]
		var way: Vector3 = s[1]
		var x := Basis(Vector3.UP, float(s[3])) * (s[4] as Vector3)
		var basis := Basis(x, Vector3.UP, x.cross(Vector3.UP))
		var xf := Transform3D(basis, at - Vector3(0, size.y * 0.5, 0))
		kit.bevel_box(InteriorKit.Batch.SOLID, xf, size, 0.07, SpacePalette.shade(cut, (k * 2 + 1) % SpacePalette.SHADES.size()))
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		var c := CollisionShape3D.new()
		c.shape = box_shape
		c.transform = xf
		body.add_child(c)
		meta.append([at, way])
	var tris0: PackedInt32Array = RockMesh.sphere(TALUS_DETAIL)[1]
	var tris1: PackedInt32Array = RockMesh.sphere(LEDGE_DETAIL)[1]
	for i in rocks.size():
		var r: Array = rocks[i]
		var shape: int = r[0]
		var place: Transform3D = r[1]
		var detail: int = r[4]
		var tris := tris1 if detail == LEDGE_DETAIL else tris0
		var dirs: PackedVector3Array = RockMesh.sphere(detail)[0]
		var verts := RockMesh.cut_vertices(shape, detail)
		var own: int = r[3]
		for t in range(0, tris.size(), 3):
			var a := place * verts[tris[t]]
			var b := place * verts[tris[t + 1]]
			var c := place * verts[tris[t + 2]]
			var n := (b - a).cross(c - a).normalized()
			if n.dot((a + b + c) / 3.0 - place.origin) < 0.0:
				n = -n
			# Each cut facet its own shade, so neighbouring planes read apart.
			var facet := RockMesh.cut_index(shape, (dirs[tris[t]] + dirs[tris[t + 1]] + dirs[tris[t + 2]]).normalized())
			var k := own if facet < 0 else (facet + own) % SpacePalette.SHADES.size()
			kit.tri(InteriorKit.Batch.SOLID, a, b, c, n, SpacePalette.shade(base, k))
		if i < boulders:
			var hull := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for p in RockMesh.hull_points(shape, detail):
				points.append(place.basis * p)
			hull.points = points
			var collider := CollisionShape3D.new()
			collider.shape = hull
			collider.position = place.origin
			body.add_child(collider)
	for m in kit.commit():
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.set_meta(&"steps", meta)
	node.set_meta(&"landing", stair["landing"])
	node.set_meta(&"boulders", boulders)
	node.set_meta(&"talus", rocks.size() - boulders)
	return node
