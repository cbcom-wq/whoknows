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
