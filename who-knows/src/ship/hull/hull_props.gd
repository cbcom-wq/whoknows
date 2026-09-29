class_name HullProps
extends RefCounted

## The hull's outside, piece by piece (docs/superpowers/specs/
## 2026-09-28-ship-exterior-design.md §3.3): plates, chamfers, corner facets,
## the faces of shaped blocks, bells, RCS pods, running strips, and (later
## tasks) windows, the pod shell, light fixtures and beams. Each builds from a
## kit, a frame and plain values, and never sees the grid: HullDressing
## decides where.
##
## The skin frame: origin on the surface, +z out of the hull, +y up the face
## (toward the bow on a roof or belly), +x across. Plating goes in the HULL
## batch (the livery), trim and seams in SOLID, anything lit in GLOW.

const HULL := InteriorKit.Batch.HULL
const SOLID := InteriorKit.Batch.SOLID
const GLOW := InteriorKit.Batch.GLOW
const GLASS := InteriorKit.Batch.GLASS

## The skin's numbers (spec §3.2).
const CHAMFER := 0.4
const PLATE_PROUD := 0.05
const PLATE_BEVEL := 0.04
const PLATE_GAP := 0.04
## A running strip's width across its chamfer (spec §5.4).
const RUNNING_WIDTH := 0.06

static func _at(offset: Vector3) -> Transform3D:
	return InteriorKit.at(offset)

static func _plate_colour() -> Color:
	return InteriorKit.solid(HullPalette.PLATE)

static func _seam() -> Color:
	return InteriorKit.solid(HullPalette.PANEL_LINE)

static func _trim() -> Color:
	return InteriorKit.solid(HullPalette.TRIM)

static func _dark() -> Color:
	return InteriorKit.solid(HullPalette.NOZZLE_DARK)

## One face's plate, `size` across, centred on the frame: the seam colour
## flush on the face, and a bevelled panel standing PLATE_PROUD in front of it,
## PLATE_GAP smaller, so the seam shows round it as a panel line.
static func plate(kit: InteriorKit, f: Transform3D, size: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var n := (f.basis * Vector3.BACK).normalized()
	kit.quad(SOLID, f * Vector3(-hx, -hy, 0), f * Vector3(hx, -hy, 0), f * Vector3(hx, hy, 0),
		f * Vector3(-hx, hy, 0), n, _seam())
	var panel := Vector3(maxf(size.x - PLATE_GAP, 0.01), maxf(size.y - PLATE_GAP, 0.01), PLATE_PROUD * 2.0)
	kit.bevel_box(HULL, f, panel, PLATE_BEVEL, _plate_colour())

## A chamfer along a convex edge, in an edge frame: +x along the edge, +y and
## +z the two faces' normals, the solid where y and z are negative. It runs
## from `from` to `to`; a capped end closes the notch against a neighbour that
## is not chamfered.
static func chamfer_strip(kit: InteriorKit, f: Transform3D, from: float, to: float, cap_from: bool,
		cap_to: bool) -> void:
	var a0 := f * Vector3(from, 0, -CHAMFER)
	var a1 := f * Vector3(to, 0, -CHAMFER)
	var b1 := f * Vector3(to, -CHAMFER, 0)
	var b0 := f * Vector3(from, -CHAMFER, 0)
	kit.quad(HULL, a0, a1, b1, b0, (f.basis * Vector3(0, 1, 1)).normalized(), _plate_colour())
	if cap_from:
		kit.tri(HULL, a0, b0, f * Vector3(from, 0, 0), (f.basis * Vector3.RIGHT).normalized(), _plate_colour())
	if cap_to:
		kit.tri(HULL, a1, b1, f * Vector3(to, 0, 0), (f.basis * Vector3.LEFT).normalized(), _plate_colour())

## Where three chamfers meet, in a corner frame: each axis along one open
## face's normal, the solid where all three are negative.
static func corner_facet(kit: InteriorKit, f: Transform3D) -> void:
	kit.tri(HULL, f * Vector3(0, -CHAMFER, -CHAMFER), f * Vector3(-CHAMFER, 0, -CHAMFER),
		f * Vector3(-CHAMFER, -CHAMFER, 0), (f.basis * Vector3.ONE).normalized(), _plate_colour())

## One face of a shaped block, in the block's cell frame, `points` round it.
## A four-sided face (a slope) gets a seam and a proud panel like a cube's
## plate; a triangle lies flat in the livery.
static func facet(kit: InteriorKit, f: Transform3D, points: PackedVector3Array, normal: Vector3) -> void:
	var n := (f.basis * normal).normalized()
	var p := PackedVector3Array()
	for q in points:
		p.append(f * q)
	if p.size() != 4:
		for i in range(1, p.size() - 1):
			kit.tri(HULL, p[0], p[i], p[i + 1], n, _plate_colour())
		return
	kit.quad(SOLID, p[0], p[1], p[2], p[3], n, _seam())
	var centre := (p[0] + p[1] + p[2] + p[3]) * 0.25
	var top := PackedVector3Array()
	var foot := PackedVector3Array()
	for q in p:
		var inset := q + (centre - q).normalized() * PLATE_GAP
		foot.append(inset)
		top.append(inset + n * PLATE_PROUD)
	kit.quad(HULL, top[0], top[1], top[2], top[3], n, _plate_colour())
	for i in 4:
		var j := (i + 1) % 4
		var side := ((top[i] + top[j]) * 0.5 - (centre + n * PLATE_PROUD)).normalized()
		kit.quad(HULL, foot[i], foot[j], top[j], top[i], side, _plate_colour())

## A main engine's bell on its exhaust face: a chunky ring with a dark throat
## and a cyan glow ring inside, like the old thruster mesh.
static func thruster_bell(kit: InteriorKit, f: Transform3D) -> void:
	kit.ring(SOLID, f, 0.62, 0.8, -0.05, 0.5, _trim())
	kit.disc(SOLID, f * _at(Vector3(0, 0, 0.06)), 0.62, _dark())
	kit.annulus(GLOW, f * _at(Vector3(0, 0, 0.08)), 0.3, 0.42, InteriorKit.lit(HullPalette.RUNNING_LIGHT, 1.4))

## An RCS block's pod on its exhaust face: a bevelled block with one round
## nozzle, where RcsShow's puffs come from.
static func rcs_pod(kit: InteriorKit, f: Transform3D) -> void:
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0, 0.1)), Vector3(0.9, 0.9, 0.2), 0.06, _trim())
	kit.ring(SOLID, f * _at(Vector3(0, 0, 0.2)), 0.16, 0.26, 0.0, 0.14, _trim())
	kit.disc(SOLID, f * _at(Vector3(0, 0, 0.21)), 0.16, _dark())

## A cyan running strip along the middle of a chamfer (spec §5.4), in the
## chamfer's edge frame, from `from` to `to`. Glow only: it lights nothing.
static func running_strip(kit: InteriorKit, f: Transform3D, from: float, to: float) -> void:
	var out := Vector3(0, 1, 1).normalized()
	var basis := Basis(Vector3.RIGHT, out.cross(Vector3.RIGHT), out)
	var at := Vector3((from + to) * 0.5, -CHAMFER * 0.5, -CHAMFER * 0.5) + out * 0.012
	kit.box(GLOW, f * Transform3D(basis, at), Vector3(maxf(to - from - 0.1, 0.05), RUNNING_WIDTH, 0.02),
		InteriorKit.lit(HullPalette.RUNNING_LIGHT, 2.2))

## A window frame's bar width.
const FRAME := 0.1
## Windows sit in front of the plating, which stands PLATE_PROUD proud: the glass
## a little beyond it, or the plate would hide the glass.
const GLASS_Z := PLATE_PROUD + 0.02
## How far the pod shell stands outside the interior pod's outline.
const POD_SKIN := 0.08
## How far below the pod's floor its shell's belly goes.
const POD_BELOW := 0.12
## The pod roof's thickness and its lip beyond the walls.
const POD_ROOF_THICK := 0.1
const POD_LIP := 0.1

static func _glass() -> Color:
	return InteriorKit.solid(HullPalette.WINDOW_GLASS)

static func _band() -> Color:
	return InteriorKit.lit(HullPalette.WINDOW_LIGHT, InteriorMaterials.GLOW_ENERGY)

## A porthole from outside (spec §5.1), in a skin frame at its centre: a
## chunky trim ring, dark amber glass, and two warm bands behind it.
static func window_porthole(kit: InteriorKit, f: Transform3D, radius: float) -> void:
	kit.ring(SOLID, f, radius, radius + FRAME * 1.6, -0.02, GLASS_Z + 0.05, _trim())
	kit.disc(GLASS, f * _at(Vector3(0, 0, GLASS_Z)), radius, _glass())
	for y in [0.35 * radius, -0.2 * radius]:
		var w := 2.0 * sqrt(radius * radius - y * y) * 0.8
		kit.box(GLOW, f * _at(Vector3(0, y, GLASS_Z + 0.005)), Vector3(w, 0.04, 0.004), _band())

## A rectangular window from outside, `size` across and up its face: a
## bevelled trim frame, glass, and three warm bands.
static func window_rect(kit: InteriorKit, f: Transform3D, size: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var n := (f.basis * Vector3.BACK).normalized()
	kit.quad(GLASS, f * Vector3(-hx, -hy, GLASS_Z), f * Vector3(hx, -hy, GLASS_Z), f * Vector3(hx, hy, GLASS_Z),
		f * Vector3(-hx, hy, GLASS_Z), n, _glass())
	for k in [-0.5, 0.05, 0.55]:
		kit.box(GLOW, f * _at(Vector3(0, k * hy, GLASS_Z + 0.005)), Vector3(size.x * 0.86, 0.045, 0.004), _band())
	for s in [-1.0, 1.0]:
		kit.bevel_box(SOLID, f * _at(Vector3(s * (hx + FRAME * 0.5), 0, GLASS_Z * 0.5 + 0.03)),
			Vector3(FRAME, size.y + FRAME * 2.0, GLASS_Z + 0.06), 0.02, _trim())
		kit.bevel_box(SOLID, f * _at(Vector3(0, s * (hy + FRAME * 0.5), GLASS_Z * 0.5 + 0.03)),
			Vector3(size.x, FRAME, GLASS_Z + 0.06), 0.02, _trim())

## The interior pod's outline grown by POD_SKIN, as (x, z) in the pod frame.
## The mouth's two ends stay on the canopy plane.
static func _pod_outline(grow: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var centre := Vector2(0, -0.9)
	for p: Vector2 in InteriorProps.POD_OUTLINE:
		if is_zero_approx(p.y):
			out.append(p + Vector2(signf(p.x) * grow, 0))
		else:
			out.append(p + (p - centre).normalized() * grow)
	return out

static func _wall(kit: InteriorKit, batch: InteriorKit.Batch, f: Transform3D, a: Vector3, b: Vector3,
		y0: float, y1: float, n: Vector3, colour: Color) -> void:
	kit.quad(batch, f * (a + Vector3.UP * y0), f * (b + Vector3.UP * y0), f * (b + Vector3.UP * y1),
		f * (a + Vector3.UP * y1), n, colour)

## The cockpit pod from outside (spec §5.2), in the interior's pod frame:
## origin at the mouth's floor centre on the canopy plane, -z out into the pod,
## +x across, +y up. The interior pod grown by POD_SKIN: livery below the
## sill, glass with warm bands to the glass top, a band to the roof, the jambs
## solid, a roof with a lip, and a belly. The mouth is left open: the hull
## closes it.
static func pod_shell(kit: InteriorKit, f: Transform3D) -> void:
	var outline := _pod_outline(POD_SKIN)
	var low := -POD_BELOW
	var sill := InteriorProps.POD_SILL
	var glass_top := InteriorProps.POD_GLASS_TOP
	var roof := InteriorProps.POD_ROOF + POD_ROOF_THICK
	var last := outline.size() - 1
	for i in last:
		var p0 := outline[i]
		var p1 := outline[i + 1]
		var d := p1 - p0
		var n := (f.basis * Vector3(d.y, 0, -d.x)).normalized()
		var a := Vector3(p0.x, 0, p0.y)
		var b := Vector3(p1.x, 0, p1.y)
		if i == 0 or i == last - 1:
			_wall(kit, HULL, f, a, b, low, roof, n, _plate_colour())
			continue
		_wall(kit, HULL, f, a, b, low, sill, n, _plate_colour())
		_wall(kit, GLASS, f, a, b, sill, glass_top, n, _glass())
		_wall(kit, HULL, f, a, b, glass_top, roof, n, _plate_colour())
		var inset := (b - a).normalized() * 0.06
		var out := f.basis.inverse() * n * 0.01
		for k in [0.35, 0.7]:
			var y := lerpf(sill, glass_top, k)
			_wall(kit, GLOW, f, a + inset + out, b - inset + out, y - 0.025, y + 0.025, n, _band())
	for i in range(1, last):
		var p := outline[i]
		kit.bevel_box(SOLID, f * _at(Vector3(p.x, (sill + glass_top) * 0.5, p.y)),
			Vector3(0.08, glass_top - sill, 0.08), 0.02, _trim())
	# The roof, with a lip beyond the walls, and the belly.
	var lip := _pod_outline(POD_SKIN + POD_LIP)
	var roof_centre := Vector3(0, roof, -0.9)
	var floor_centre := Vector3(0, low, -0.9)
	for i in last:
		var r0 := Vector3(lip[i].x, roof, lip[i].y)
		var r1 := Vector3(lip[i + 1].x, roof, lip[i + 1].y)
		kit.tri(HULL, f * roof_centre, f * r0, f * r1, (f.basis * Vector3.UP).normalized(), _plate_colour())
		var d := lip[i + 1] - lip[i]
		var n := (f.basis * Vector3(d.y, 0, -d.x)).normalized()
		_wall(kit, HULL, f, Vector3(lip[i].x, 0, lip[i].y), Vector3(lip[i + 1].x, 0, lip[i + 1].y),
			roof - POD_ROOF_THICK, roof, n, _plate_colour())
		var g0 := Vector3(outline[i].x, low, outline[i].y)
		var g1 := Vector3(outline[i + 1].x, low, outline[i + 1].y)
		kit.tri(HULL, f * floor_centre, f * g0, f * g1, (f.basis * Vector3.DOWN).normalized(), _plate_colour())
	# The fans close across the mouth, as the interior pod's do: only the
	# vertical mouth wall stays open.
	kit.tri(HULL, f * roof_centre, f * Vector3(lip[last].x, roof, lip[last].y), f * Vector3(lip[0].x, roof, lip[0].y),
		(f.basis * Vector3.UP).normalized(), _plate_colour())
	kit.tri(HULL, f * floor_centre, f * Vector3(outline[last].x, low, outline[last].y),
		f * Vector3(outline[0].x, low, outline[0].y), (f.basis * Vector3.DOWN).normalized(), _plate_colour())

## A flood's housing and lens (spec §6.1), in a frame at its mount with +z
## along its aim: a chunky bevelled box and a round lens. The lens goes in
## `lens`'s glow, whose material ShipLights turns up and down.
static func flood_fixture(kit: InteriorKit, lens: InteriorKit, f: Transform3D) -> void:
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0, 0.1)), Vector3(0.56, 0.56, 0.32), 0.06, _trim())
	kit.ring(SOLID, f * _at(Vector3(0, 0, 0.26)), 0.2, 0.26, 0.0, 0.06, _trim())
	kit.disc(SOLID, f * _at(Vector3(0, 0, 0.265)), 0.2, _dark())
	lens.disc(GLOW, f * _at(Vector3(0, 0, 0.27)), 0.2, InteriorKit.lit(HullPalette.WORK_LIGHT, InteriorMaterials.GLOW_ENERGY))

## A forward light (spec §6.1): a recessed lamp in a round bezel, in a frame
## at its mount with +z along its aim.
static func forward_fixture(kit: InteriorKit, lens: InteriorKit, f: Transform3D) -> void:
	kit.ring(SOLID, f, 0.2, 0.32, -0.08, 0.08, _trim())
	kit.disc(SOLID, f * _at(Vector3(0, 0, 0.0)), 0.2, _dark())
	lens.disc(GLOW, f * _at(Vector3(0, 0, 0.01)), 0.19, InteriorKit.lit(HullPalette.WORK_LIGHT, InteriorMaterials.GLOW_ENERGY))
