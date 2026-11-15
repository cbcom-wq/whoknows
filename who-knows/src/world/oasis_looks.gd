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
## The outline's wobble: [lobes round the ring, share of the ellipse's reach].
const GREEN_WOBBLE := [[3, 0.07], [5, 0.05], [8, 0.035]]

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
		var flat := Vector2(offset.x, offset.z)
		if flat.length() <= keep_out or flat.length() > green_reach(axes, flat.angle(), seed):
			continue
		var at: Vector3 = f * offset
		var blocked := false
		for a in avoid:
			if Vector2(at.x - a.x, at.z - a.y).length() < a.z:
				blocked = true
				break
		if blocked:
			continue
		at.y = float(floor_of.call(at.x, at.z))
		var tile := Vector2i(floori(offset.x / TUFT_TILE), floori(offset.z / TUFT_TILE))
		if not tiles.has(tile):
			tiles[tile] = [[], []]
		tiles[tile][0].append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(width, height, width)), at))
		tiles[tile][1].append(InteriorKit.solid(SpacePalette.shade(OasisPalette.GRASS, k)))
		feet.append(at)
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

## The green patch under a pool's grass ring: a flat, faceted carpet in
## OasisPalette.GREEN_PATCH, laid on `ground`, the ground's own triangles
## (each a PackedVector3Array of three points in the kit's space, y up, as the
## world draws them), PATCH_PROUD over them. Each triangle is cut to the
## green: inside its outline (green_reach on the ellipse `axes` round
## `centre`) and out of the water (`water_radius` + PATCH_SHORE from
## `centre`); a cut point lies on the triangle's own edge, so every vertex
## lies on the drawn ground. Its shade changes in broad patches by where each
## triangle lies. Returns every vertex laid, in the kit's space.
static func green_patch(kit: InteriorKit, ground: Array, centre: Vector3, axes: Vector2, water_radius: float,
		seed: int) -> PackedVector3Array:
	var shore := water_radius + PATCH_SHORE
	var phases := _wobble_phases(seed)
	var lift := Vector3(0.0, PATCH_PROUD, 0.0)
	var laid := PackedVector3Array()
	var colours := {}
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
		if not colours.has(k):
			colours[k] = InteriorKit.solid(SpacePalette.shade(OasisPalette.GREEN_PATCH, k))
		var colour: Color = colours[k]
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
	var crop := OasisPalette.CROP_DRY if dried else OasisPalette.CROP_GREEN
	var rows := maxi(int((size.y - 0.4) / 0.6) + 1, 1)
	var cols := maxi(int((size.x - 0.5) / 0.55) + 1, 1)
	for r in rows:
		for c in cols:
			var n := _noise(variety, c, r)
			var h := (0.15 + 0.1 * n) if dried else (0.28 + 0.2 * n)
			var at := Vector3(-size.x * 0.5 + 0.3 + c * 0.55, 0.28 + h * 0.5, -size.y * 0.5 + 0.3 + r * 0.6)
			kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(at), Vector3(0.3, h, 0.3), 0.06,
				InteriorKit.solid(SpacePalette.shade(crop, int(n * 2.99))))

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

# --- the outcrop ----------------------------------------------------------------

## The outcrop's stones are RockMesh's at this detail (80 faces), drawn and
## solid alike: a stone's collider is the hull of the very vertices drawn.
const OUTCROP_DETAIL := 1
## The big stones (6-12 m) of an outcrop 50 by 18 m: [x, z (m from its middle,
## scaled to its size), diameter, stretch, yaw, its top over the ground]. The
## first is the lookout, 8 m up; the others rise toward it from the west so
## the steps can climb their south flanks to it.
const OUTCROP_STONES := [
	[7.0, -1.0, 12.0, Vector3(1.0, 1.25, 0.85), 0.3, 8.0],
	[1.0, 0.0, 9.0, Vector3(1.0, 1.1, 0.95), 2.2, 6.8],
	[-5.0, 0.5, 10.0, Vector3(1.05, 0.95, 0.9), 1.1, 5.6],
	[-11.5, -0.5, 9.0, Vector3(1.0, 0.85, 1.0), 2.0, 4.3],
	[-18.0, 1.0, 7.0, Vector3(0.95, 0.8, 1.1), 0.7, 3.0],
	[-22.0, -2.5, 6.0, Vector3(1.0, 0.8, 1.0), 2.9, 2.2],
	[16.0, -2.0, 10.0, Vector3(1.05, 0.9, 0.9), 2.6, 5.2],
	[22.0, 2.0, 6.5, Vector3(1.0, 0.8, 1.0), 1.7, 3.0],
	[2.0, -6.0, 7.0, Vector3(1.0, 0.9, 1.0), 0.4, 4.0],
]
## The steps: squashed stones STEP_DIAMETER across, STEP_SPAN apart from west
## to east along the big stones' south flanks, each STEP_RISE at most over the
## last (a jump peaks at 0.89 m), its top STEP_PROUD over the rock or ground
## it rests on, up to the cap.
const STEP_DIAMETER := 2.0
const STEP_SQUASH := 0.45
const STEP_SPAN := 1.9
const STEP_RISE := 0.6
const STEP_PROUD := 0.5
## The lookout's own summit is a point (about 43 deg within 0.6 m of it), so
## what you stand on up there is the cap: the chain's last stone, a broad flat
## one CAP_DIAMETER across bedded on the summit, its top CAP_OVER over it. The
## chain's last steps close on it no more than CAP_REACH apart.
const CAP_DIAMETER := 2.8
const CAP_SQUASH := 0.35
const CAP_OVER := 0.3
const CAP_REACH := 2.2
## The first step's top over the floor, and how far under the ground a big
## stone's middle lies at least, m.
const STEP_FIRST := 0.55
const SUNK_MIDDLE := 0.3
## A step with too little rock under it stands on a pillar stone this wide
## (near the step's own width, so the two read as a stack, not a toadstool),
## its top this far under the step's.
const PILLAR_DIAMETER := 1.9
const PILLAR_HIDDEN := 0.35
## Two steps lie no more than this apart north to south.
const STEP_SWAY := 1.5

## A rock outcrop at `f` (on the ground, x along its length): big RockMesh
## stones in the world's `boulder` shades (from `palette`, as GroundCover takes
## them; the desert's when none is given), with smaller stones as steps up to
## a lookout about 8 m up and a flat cap on its summit to stand on. `size` is
## its length, height and depth (the stones are laid out for 50 x 9 x 18 m and
## scaled in x and z). `floor_of(x, z)` is
## the ground's height in f's terms (f's plane when none is given). One Node3D
## "Outcrop" holding one mesh and one StaticBody3D "Stones" on BodyProxy.LAYER,
## a convex hull per stone, as solid as the ground's boulders.
static func outcrop(f: Transform3D, size: Vector3, variety: float, floor_of := Callable(),
		palette: Dictionary = {}) -> Node3D:
	var land: Dictionary = palette if not palette.is_empty() else SpacePalette.WORLDS[SpacePalette.DESERT_PALETTE]
	var base: Color = land[&"boulder"]
	var node := Node3D.new()
	node.name = "Outcrop"
	node.transform = f
	var body := StaticBody3D.new()
	body.name = "Stones"
	body.collision_layer = BodyProxy.LAYER
	body.collision_mask = 0
	node.add_child(body)
	var kit := kit_under(node)
	var tris: PackedInt32Array = RockMesh.sphere(OUTCROP_DETAIL)[1]
	var dirs: PackedVector3Array = RockMesh.sphere(OUTCROP_DETAIL)[0]
	var stones := outcrop_stones(size, variety, floor_of)
	for i in stones.size():
		var stone: Array = stones[i]
		var shape: int = stone[0]
		var place: Transform3D = stone[1]
		var verts := RockMesh.cut_vertices(shape, OUTCROP_DETAIL)
		var own := int(_noise(variety, i, 50.0) * 2.99)
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
		var hull := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for p in RockMesh.hull_points(shape, OUTCROP_DETAIL):
			points.append(place.basis * p)
		hull.points = points
		var collider := CollisionShape3D.new()
		collider.shape = hull
		collider.position = place.origin
		body.add_child(collider)
	kit.commit()
	return node

## The outcrop's stones, in its own frame: [RockMesh shape, placement] each,
## the big stones first, then the steps from the floor up. A big stone is
## stretched up, if it must be, until its middle lies at least SUNK_MIDDLE
## under the ground, so its flanks rise from the ground with no overhang and
## a step can sit anywhere on them. Pure.
static func outcrop_stones(size: Vector3, variety: float, floor_of := Callable()) -> Array:
	var ground := func(x: float, z: float) -> float:
		return float(floor_of.call(x, z)) if floor_of.is_valid() else 0.0
	var scale := Vector2(size.x / 50.0, size.z / 18.0)
	var stones := []
	var surfaces := []
	for i in OUTCROP_STONES.size():
		var s: Array = OUTCROP_STONES[i]
		var shape := RockMesh.Shape.BOULDER if i % 3 != 2 else RockMesh.Shape.SHARD
		var turn := Basis(Vector3.UP, float(s[4]) + (variety - 0.5) * 0.6)
		var stretch: Vector3 = (s[3] as Vector3) * float(s[2])
		var rise := float(s[5])
		var top := _top_of(shape, turn * Basis.from_scale(stretch))
		if top.y < rise + SUNK_MIDDLE:
			stretch.y *= (rise + SUNK_MIDDLE) / top.y
		var basis := turn * Basis.from_scale(stretch)
		top = _top_of(shape, basis)
		var x := float(s[0]) * scale.x
		var z := float(s[1]) * scale.y
		var place := Transform3D(basis, Vector3(x, float(ground.call(x, z)) + rise - top.y, z))
		stones.append([shape, place])
		surfaces.append(_faces_of(shape, place))
	var lookout := _top_of(stones[0][0], (stones[0][1] as Transform3D).basis) + (stones[0][1] as Transform3D).origin
	var support := func(x: float, z: float) -> float:
		var h := float(ground.call(x, z))
		for faces: Array in surfaces:
			h = maxf(h, _surface(faces, x, z))
		return h
	# Steps from the west, along the south flanks, to one STEP_RISE under the
	# cap: the first on the floor at the south edge, each next STEP_RISE higher.
	var cap_top := lookout.y + CAP_OVER
	var target := cap_top - STEP_RISE
	var x := lookout.x - (ceili((target - float(ground.call(lookout.x, lookout.z))) / STEP_RISE) + 1) * STEP_SPAN
	var south := size.z * 0.5 - STEP_DIAMETER * 0.5
	var at_z := south
	var h := float(ground.call(x, south)) + STEP_FIRST
	var k := 0
	while k < 40:
		if k > 0:
			# Walk north from the south edge until the rock under this step's
			# top is high enough for it to stand STEP_PROUD over it; failing
			# that, onto the highest rock on the way.
			var z := south
			var found := NAN
			var best_z := south
			var best := -INF
			while z > -size.z * 0.5 + 0.5:
				var under_z := float(support.call(x, z))
				if under_z > best:
					best = under_z
					best_z = z
				if under_z >= h - STEP_PROUD:
					found = z
					break
				z -= 0.1
			at_z = clampf(best_z if is_nan(found) else found, at_z - STEP_SWAY, at_z + STEP_SWAY)
		_step(stones, support, Vector3(x, h, at_z), _step_basis(variety, k), variety, k)
		if h >= target - 0.01:
			break
		h = minf(h + STEP_RISE, target)
		x += STEP_SPAN
		k += 1
	# Then straight across the lookout's flank to its summit, no more than
	# CAP_REACH apart and rising evenly, and the cap bedded on the summit.
	var last := Vector3(x, h, at_z)
	var summit := Vector3(lookout.x, cap_top, lookout.z)
	var m := maxi(1, ceili(Vector2(summit.x - last.x, summit.z - last.z).length() / CAP_REACH))
	for i in range(1, m):
		k += 1
		_step(stones, support, last.lerp(summit, float(i) / m), _step_basis(variety, k), variety, k)
	var cap := Basis(Vector3.UP, _noise(variety, k + 1, 60.0) * TAU) 		* Basis.from_scale(Vector3(1.0, CAP_SQUASH, 1.0) * CAP_DIAMETER)
	var cap_peak := _top_of(RockMesh.Shape.BOULDER, cap)
	stones.append([RockMesh.Shape.BOULDER, Transform3D(cap, summit - cap_peak)])
	return stones

## A step stone's turn and squash, the `k`th from the floor.
static func _step_basis(variety: float, k: int) -> Basis:
	return Basis(Vector3.UP, _noise(variety, k, 60.0) * TAU) 		* Basis.from_scale(Vector3(1.0, STEP_SQUASH, 1.1) * STEP_DIAMETER)

## One step, its top at `at`, into `stones`; and, where too little rock lies
## under it (`support`), a pillar stone holding it up, its top hidden in the
## step.
static func _step(stones: Array, support: Callable, at: Vector3, basis: Basis, variety: float, k: int) -> void:
	var top := _top_of(RockMesh.Shape.BOULDER, basis)
	var under := float(support.call(at.x, at.z))
	# The stone's middle sits off its top by the top's own offset.
	stones.append([RockMesh.Shape.BOULDER, Transform3D(basis, at - top)])
	if at.y - under <= STEP_PROUD + 0.25:
		return
	var pillar := Basis(Vector3.UP, _noise(variety, k, 61.0) * TAU) 		* Basis.from_scale(Vector3(PILLAR_DIAMETER, 1.0, PILLAR_DIAMETER))
	var rise := _top_of(RockMesh.Shape.BOULDER, pillar)
	var low := _low_of(RockMesh.Shape.BOULDER, pillar)
	var tall := (at.y - PILLAR_HIDDEN) - (under - SUNK_MIDDLE)
	pillar = pillar * Basis.from_scale(Vector3(1.0, tall / (rise.y - low), 1.0))
	rise = _top_of(RockMesh.Shape.BOULDER, pillar)
	stones.append([RockMesh.Shape.BOULDER, Transform3D(pillar, at - Vector3(0.0, PILLAR_HIDDEN, 0.0) - rise)])

## The lowest vertex height of `shape` turned and scaled by `basis`.
static func _low_of(shape: int, basis: Basis) -> float:
	var low := INF
	for p in RockMesh.hull_points(shape, OUTCROP_DETAIL):
		low = minf(low, (basis * p).y)
	return low

## The highest vertex of `shape` turned and scaled by `basis`.
static func _top_of(shape: int, basis: Basis) -> Vector3:
	var top := Vector3(0, -INF, 0)
	for p in RockMesh.hull_points(shape, OUTCROP_DETAIL):
		var q := basis * p
		if q.y > top.y:
			top = q
	return top

## A stone's upward faces, placed: [its middle and reach across (x, z, m),
## three vertices a face].
static func _faces_of(shape: int, place: Transform3D) -> Array:
	var out := PackedVector3Array()
	var tris: PackedInt32Array = RockMesh.sphere(OUTCROP_DETAIL)[1]
	var verts := RockMesh.cut_vertices(shape, OUTCROP_DETAIL)
	var reach := 0.0
	for t in range(0, tris.size(), 3):
		var a := place * verts[tris[t]]
		var b := place * verts[tris[t + 1]]
		var c := place * verts[tris[t + 2]]
		for p in [a, b, c]:
			reach = maxf(reach, Vector2(p.x - place.origin.x, p.z - place.origin.z).length())
		if absf((b - a).cross(c - a).y) > 1e-6:
			out.append_array(PackedVector3Array([a, b, c]))
	return [Vector3(place.origin.x, reach, place.origin.z), out]

## The height of the top of a stone's `faces` (from _faces_of) over (x, z),
## or -INF off it.
static func _surface(faces: Array, x: float, z: float) -> float:
	var middle: Vector3 = faces[0]
	if Vector2(x - middle.x, z - middle.z).length() > middle.y:
		return -INF
	var tris: PackedVector3Array = faces[1]
	var best := -INF
	var from := Vector3(x, 1000.0, z)
	for t in range(0, tris.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, tris[t], tris[t + 1], tris[t + 2])
		if hit != null:
			best = maxf(best, (hit as Vector3).y)
	return best
