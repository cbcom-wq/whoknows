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

## The ring of grass round a pool at `f` (its centre, on the ground): tufts
## from `water_radius` + `inner` (the water edge and a bank) out to the
## ellipse `axes` (half its width along the frame x, and along its z), as
## one MultiMesh with no collision. `floor_of(x, z)` is the ground height in
## the frame's own terms, where each tuft stands. No tuft stands within an
## `avoid` circle (x, z in the frame, radius): a bed, the pump, a stone.
static func grass_ring(f: Transform3D, axes: Vector2, water_radius: float, inner: float,
		seed: int, floor_of: Callable, avoid: Array[Vector3] = []) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var keep_out := water_radius + inner
	var area := PI * axes.x * axes.y - PI * keep_out * keep_out
	var transforms: Array[Transform3D] = []
	var colours: Array[Color] = []
	var feet := PackedVector3Array()
	for i in int(maxf(area, 0.0) * TUFTS_PER_M2):
		var rho := sqrt(rng.randf())
		var theta := rng.randf() * TAU
		var offset := Vector3(axes.x * rho * cos(theta), 0.0, axes.y * rho * sin(theta))
		var yaw := rng.randf() * TAU
		var height := rng.randf_range(TUFT_HEIGHT.x, TUFT_HEIGHT.y)
		var width := rng.randf_range(0.9, 1.4)
		var k := rng.randi_range(0, SpacePalette.SHADES.size() - 1)
		if Vector2(offset.x, offset.z).length() <= keep_out:
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
		transforms.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(width, height, width)), at))
		colours.append(SpacePalette.shade(OasisPalette.GRASS, k))
		feet.append(at)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = GroundCover.grass_mesh()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colours[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = "GrassRing"
	inst.multimesh = mm
	## Where each tuft stands, kept here too: a MultiMesh reads back nothing
	## without a renderer (the headless tests).
	inst.set_meta(&"tufts", feet)
	inst.material_override = CoverField.grass_material()
	inst.layers = WORLD_LAYER
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst

## A garden at `f`: a low raised bed of `size` (x and z, m) of soil with rows
## of crops, green, or collapsed and dry when `dried`.
static func garden(kit: InteriorKit, f: Transform3D, size: Vector2, dried: bool, variety: float) -> void:
	kit.bevel_box(InteriorKit.Batch.SOLID, f * InteriorKit.at(Vector3(0, 0.1, 0)),
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
