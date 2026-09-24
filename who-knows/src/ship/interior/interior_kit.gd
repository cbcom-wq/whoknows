class_name InteriorKit
extends RefCounted

## A mesh toolkit for stylized interiors (docs/superpowers/specs/
## 2026-09-23-ship-interior-redesign-design.md §3.2, §4): bevelled boxes,
## tubes, rings, discs and animated screens, accumulated into one SurfaceTool
## per material and committed as one merged mesh each -- so a cabin full of
## props costs a handful of draw calls. It also makes the lights and colliders
## props ask for, to the interior's conventions: render layer 2, light cull
## mask 2, no shadows, colliders tagged GROUP.
##
## Knows nothing about ships. Give it a node to build under and, if anything
## should be solid, a physics body; any generator can build with it.

## Carried by every collider a kit adds, so a builder can tell dressing
## colliders from its own structure.
const GROUP := &"interior_dressing"

## One merged mesh per batch, each with its own material. PORTAL is window
## glass that shows the real view outside; its material is supplied by
## whoever owns that view (InteriorDressing.portal_material).
enum Batch { SOLID, GLOW, SCREEN, GLASS, PORTAL }
const BATCH_NAMES := ["DressingSolid", "DressingGlow", "DressingScreens", "DressingGlass",
	"DressingPortals"]

## screen.gdshader's modes, carried in vertex colour red as mode / 4.
enum Screen { BARS, WAVE, DOTS }

## Interior render layer and light cull mask (project.godot 3d_render/layer_2).
const LAYER := 2

const SEGMENTS := 24
const TUBE_SEGMENTS := 8

const _BOX_FACES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
]
const _UNIT_UVS: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]

var root: Node3D
var body: CollisionObject3D
## Render layers for what this kit draws, and the cull mask of the lights it
## makes. The interior's by default; the airlock's copy on the hull builds on
## the own-hull layer (airlock spec §7.2).
var layer := LAYER
var light_mask := LAYER
## The PORTAL batch's material; null uses InteriorMaterials.portal_fallback().
var portal_material: Material
var _tools: Dictionary = {}   # Batch -> SurfaceTool

func _init(root_node: Node3D, collision_body: CollisionObject3D = null,
		portal: Material = null) -> void:
	root = root_node
	body = collision_body
	portal_material = portal

## A translation-only frame, for placing a piece inside a prop's frame.
static func at(offset: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, offset)

## A palette colour as a vertex colour. Vertex colours reach the materials
## untouched, so they are stored linear.
static func solid(color: Color) -> Color:
	return color.srgb_to_linear()

## A lit piece's vertex colour: the colour pre-scaled by its share of
## InteriorMaterials.GLOW_ENERGY, so one merged glow mesh can hold lights of
## different strengths. `blink_phase` below 1 makes it blink, at that phase.
static func lit(color: Color, energy: float, blink_phase := 1.0) -> Color:
	var l := color.srgb_to_linear()
	var k := energy / InteriorMaterials.GLOW_ENERGY
	return Color(minf(l.r * k, 1.0), minf(l.g * k, 1.0), minf(l.b * k, 1.0), blink_phase)

## One triangle facing `normal`. Godot treats clockwise-seen-from-the-front as
## front-facing -- the front of (a, b, c) is the side (b - a) x (c - a) points
## away from -- so winding is fixed here, once, and no caller has to care.
func tri(batch: Batch, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	var st := _tool(batch)
	for v in [[a, ua], [b, ub], [c, uc]]:
		st.set_normal(normal)
		st.set_color(color)
		st.set_uv(v[1])
		st.add_vertex(v[0])

## A quad a-b-c-d, in order round its edge. UVs run (0,1) at a round to (0,0)
## at d, so a screen quad given bottom-left first reads upright.
func quad(batch: Batch, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3,
		color: Color) -> void:
	tri(batch, a, b, c, normal, color, _UNIT_UVS[0], _UNIT_UVS[1], _UNIT_UVS[2])
	tri(batch, a, c, d, normal, color, _UNIT_UVS[0], _UNIT_UVS[2], _UNIT_UVS[3])

## A plain box, for strips and slabs too thin to bevel.
func box(batch: Batch, xf: Transform3D, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	for f in _BOX_FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := n * h
		var du := u * h
		var dv := v * h
		quad(batch, xf * (c - du - dv), xf * (c + du - dv), xf * (c + du + dv), xf * (c - du + dv),
			(xf.basis * n).normalized(), color)

## A box with every edge chamfered by `bevel`, flat-shaded: the low-poly,
## slightly toy-like block every chunky prop is made of. 6 faces, 12 edge
## strips, 8 corner triangles.
func bevel_box(batch: Batch, xf: Transform3D, size: Vector3, bevel: float, color: Color) -> void:
	var e := size * 0.5 - Vector3.ONE * bevel
	e = Vector3(maxf(e.x, 0.0), maxf(e.y, 0.0), maxf(e.z, 0.0))
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for a in 3:
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		var ax: Vector3 = axes[a]
		var bx: Vector3 = axes[b]
		var cx: Vector3 = axes[c]
		for sa in [-1.0, 1.0]:
			var o: Vector3 = ax * sa * (e[a] + bevel)
			quad(batch, xf * (o - bx * e[b] - cx * e[c]), xf * (o + bx * e[b] - cx * e[c]),
				xf * (o + bx * e[b] + cx * e[c]), xf * (o - bx * e[b] + cx * e[c]),
				(xf.basis * (ax * sa)).normalized(), color)
			for sb in [-1.0, 1.0]:
				var p1: Vector3 = ax * sa * (e[a] + bevel) + bx * sb * e[b]
				var p2: Vector3 = ax * sa * e[a] + bx * sb * (e[b] + bevel)
				quad(batch, xf * (p1 - cx * e[c]), xf * (p1 + cx * e[c]), xf * (p2 + cx * e[c]),
					xf * (p2 - cx * e[c]), (xf.basis * (ax * sa + bx * sb)).normalized(), color)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var k := Vector3(sx, sy, sz)
				tri(batch, xf * (k * e + Vector3(sx * bevel, 0, 0)), xf * (k * e + Vector3(0, sy * bevel, 0)),
					xf * (k * e + Vector3(0, 0, sz * bevel)), (xf.basis * k).normalized(), color)

## An open-ended faceted tube along the frame's local x axis.
func tube_x(batch: Batch, xf: Transform3D, radius: float, length: float, color: Color) -> void:
	var half := Vector3(length * 0.5, 0.0, 0.0)
	for i in TUBE_SEGMENTS:
		var a0 := TAU * float(i) / TUBE_SEGMENTS
		var a1 := TAU * float(i + 1) / TUBE_SEGMENTS
		var d0 := Vector3(0.0, cos(a0), sin(a0)) * radius
		var d1 := Vector3(0.0, cos(a1), sin(a1)) * radius
		quad(batch, xf * (d0 - half), xf * (d0 + half), xf * (d1 + half), xf * (d1 - half),
			(xf.basis * (d0 + d1)).normalized(), color)

## A tube from a to b (both in the kit's space), for rails that follow a curve.
func tube_between(batch: Batch, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	tube_x(batch, Transform3D(Basis(dir, up, dir.cross(up)), (a + b) * 0.5), radius,
		a.distance_to(b) + radius, color)

static func _ring_dir(i: int) -> Vector3:
	var a := TAU * float(i) / SEGMENTS
	return Vector3(cos(a), sin(a), 0.0)

## A thick ring in the frame's xy plane, facing +z: front annulus at z_front,
## the bore from z_back to z_front, and the outer rim from 0 to z_front.
func ring(batch: Batch, xf: Transform3D, r_in: float, r_out: float, z_back: float, z_front: float,
		color: Color) -> void:
	var front := (xf.basis * Vector3.BACK).normalized()
	var zb := Vector3(0, 0, z_back)
	var zf := Vector3(0, 0, z_front)
	for i in SEGMENTS:
		var d0 := _ring_dir(i)
		var d1 := _ring_dir(i + 1)
		var out := (xf.basis * (d0 + d1)).normalized()
		quad(batch, xf * (d0 * r_in + zf), xf * (d1 * r_in + zf), xf * (d1 * r_out + zf),
			xf * (d0 * r_out + zf), front, color)
		quad(batch, xf * (d0 * r_in + zb), xf * (d1 * r_in + zb), xf * (d1 * r_in + zf),
			xf * (d0 * r_in + zf), -out, color)
		quad(batch, xf * (d0 * r_out), xf * (d1 * r_out), xf * (d1 * r_out + zf),
			xf * (d0 * r_out + zf), out, color)

## A flat ring in the frame's xy plane, facing +z.
func annulus(batch: Batch, xf: Transform3D, r_in: float, r_out: float, color: Color) -> void:
	var n := (xf.basis * Vector3.BACK).normalized()
	for i in SEGMENTS:
		var d0 := _ring_dir(i)
		var d1 := _ring_dir(i + 1)
		quad(batch, xf * (d0 * r_in), xf * (d1 * r_in), xf * (d1 * r_out), xf * (d0 * r_out), n, color)

## A flat disc in the frame's xy plane, facing +z.
func disc(batch: Batch, xf: Transform3D, radius: float, color: Color) -> void:
	var n := (xf.basis * Vector3.BACK).normalized()
	var centre := xf * Vector3.ZERO
	for i in SEGMENTS:
		tri(batch, centre, xf * (_ring_dir(i) * radius), xf * (_ring_dir(i + 1) * radius), n, color)

## An animated screen in the frame's xy plane, facing +z. `variety` (0..1)
## seeds what it shows, so neighbouring screens differ.
func screen(xf: Transform3D, size: Vector2, mode: Screen, variety: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	quad(Batch.SCREEN, xf * Vector3(-hx, -hy, 0), xf * Vector3(hx, -hy, 0), xf * Vector3(hx, hy, 0),
		xf * Vector3(-hx, hy, 0), (xf.basis * Vector3.BACK).normalized(),
		Color(float(mode) * 0.25, variety, 0.0, 1.0))

## A warm interior light. `role` is kept in meta so callers and tests can
## tell ceiling lights from console spill and door lights.
func light(pos: Vector3, color: Color, energy: float, range_m: float, role: StringName) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.light_cull_mask = light_mask
	l.shadow_enabled = false
	l.set_meta(&"role", role)
	root.add_child(l)
	return l

## A box collider for a piece a player could walk into. It goes straight on
## the body, because a CollisionShape3D only registers as the body's direct
## child.
func collider(xf: Transform3D, size: Vector3) -> CollisionShape3D:
	if body == null:
		push_error("InteriorKit.collider: this kit was given no physics body")
		return null
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.shape = shape
	c.transform = xf
	c.add_to_group(GROUP)
	body.add_child(c)
	return c

## A standalone mesh (not batched) under the kit's root, on the interior layer.
func add_mesh(mesh: Mesh, material: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.layers = layer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

## Commits every batch as one merged mesh with its material.
func commit() -> Array[MeshInstance3D]:
	var materials: Array[Material] = [InteriorMaterials.props(), InteriorMaterials.glow(),
		InteriorMaterials.screen(), InteriorMaterials.glass(),
		portal_material if portal_material != null else InteriorMaterials.portal_fallback()]
	var out: Array[MeshInstance3D] = []
	for batch: int in _tools:
		var st: SurfaceTool = _tools[batch]
		out.append(add_mesh(st.commit(), materials[batch], BATCH_NAMES[batch]))
	_tools.clear()
	return out

func _tool(batch: Batch) -> SurfaceTool:
	if not _tools.has(batch):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[batch] = st
	return _tools[batch]
