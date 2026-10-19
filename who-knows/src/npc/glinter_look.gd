class_name GlinterLook
extends Node3D

## The glinter as you see it (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §4.2, §9): a hoarder -- a domed shell of
## big flat facets in scrap colours, slate with patches of rust, a blunt head
## and six short two-jointed legs, so it is a creature and not a stone. Shut,
## it sits low among the salvage it lies with; sprung, two pale SKITTER_EYE
## facets show on its face. It wears the same glint as salvage
## (ItemLooks.glint) and that is its lure: its tell is the rhythm, one shared
## beat for the whole nest (BEAT), where real salvage flashes at its own 2-4 s.
## Flat-shaded, no texture, colours from SpacePalette only; it fades in with
## distance as the rocks do. Silent. At most 120 triangles.

## Built 1 m long and 0.72 m high; NpcLooks scales it to the species.
const LENGTH := 1.0
## A nest's shared flash beat, seconds: quicker than any salvage glint
## (ItemLooks.GLINT_EVERY).
const BEAT := 1.6
## The shell: a ring of six at the base and another higher, narrower, then the
## apex; its middle is a little behind the body's middle, the head in front.
const SIDES := 6
const BASE_HEIGHT := 0.2
const BASE_RADIUS := Vector2(0.36, 0.38)
const TOP_HEIGHT := 0.5
const TOP_RADIUS := Vector2(0.24, 0.26)
const APEX_HEIGHT := 0.62
const SHELL_Z := 0.06
## The head: from the front, this long and this wide and tall.
const HEAD_FRONT := -0.5
const HEAD_BACK := -0.28
const HEAD_HALF_WIDTH := 0.14
const HEAD_BOTTOM := 0.2
const HEAD_TOP := 0.42
## The eyes on its face: apart, how high, and each this wide and tall.
const EYE_APART := 0.065
const EYE_HEIGHT := 0.34
const EYE_SIZE := Vector2(0.07, 0.05)
## Six legs, three a side: where each hangs along the body, and the hip, knee
## and foot, as x for the right side (mirrored) and height.
const LEG_Z: Array[float] = [-0.18, 0.06, 0.3]
const HIP := Vector2(0.3, 0.22)
const KNEE := Vector2(0.46, 0.26)
const FOOT := Vector2(0.5, 0.0)
const THIGH_THICKNESS := 0.07
const SHIN_THICKNESS := 0.05

var action: StringName = &""
var fade := Vector2(110, 140)
## The glint on its back; its beat is set by set_group_seed.
var glint: ItemLooks.Glint
## The two pale facets, shown only when it springs.
var eyes: MeshInstance3D

## Builds it, `variety` picking which facets are rust. Its colours are scrap
## whatever its rock: `colour` is the rock's, which a nest does not borrow.
func build(variety: float, _colour: Color, p_fade: Vector2) -> void:
	fade = p_fade
	var material := _material()
	_part("Shell", shell_mesh(variety), material)
	_part("Head", head_mesh(), material)
	_part("Legs", legs_mesh(), material)
	eyes = _part("Eyes", eyes_mesh(), material)
	eyes.visible = false
	glint = ItemLooks.glint(self, variety)
	glint.position = Vector3(0, APEX_HEIGHT + 0.04, SHELL_Z)

func _part(part_name: String, mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)
	return mi

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = SpacePalette.UNTINTED
	m.roughness = 1.0
	if fade.y > 0.0:
		# Reversed (min beyond max): whole within fade.x, gone past fade.y.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = fade.y
		m.distance_fade_max_distance = fade.x
	return m

## What it is doing: springing or biting shows its eyes; anything else (shut,
## hiding, still) closes them.
func act(p_action: StringName) -> void:
	if p_action == action:
		return
	action = p_action
	eyes.visible = p_action == &"leap" or p_action == &"bite"

## Puts its glint on its nest's beat (rock creatures spec §4.2). The glint
## reads the engine's clock, so every Glinter of one `seed` flashes together
## however long ago each was built, and nests flash apart.
func set_group_seed(s: int) -> void:
	glint.period = BEAT
	glint.clock_phase = fposmod(float(s & 0xFFFF) / 65535.0, 1.0) * BEAT
	glint.visible = glint.lit_at(Time.get_ticks_msec() / 1000.0)

## A point on the shell's ring at `k` of SIDES, `ring` the half-widths and
## `height` up.
static func _ring(k: float, ring: Vector2, height: float) -> Vector3:
	var a := TAU * k / float(SIDES) + PI / float(SIDES)
	return Vector3(sin(a) * ring.x, height, cos(a) * ring.y + SHELL_Z)

## The shell: a dome of big flat facets, each one of three slate shades, two
## opposite ones across the top rust, and a darker underside.
static func shell_mesh(variety: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0, APEX_HEIGHT, SHELL_Z)
	var under := Vector3(0, BASE_HEIGHT - 0.04, SHELL_Z)
	var inside := Vector3(0, 0.3, SHELL_Z)
	var patch := int(variety * float(SIDES)) % SIDES
	var shades := SpacePalette.SHADES.size()
	for i in SIDES:
		var rust := i == patch or i == (patch + SIDES / 2) % SIDES
		var low_a := _ring(i, BASE_RADIUS, BASE_HEIGHT)
		var low_b := _ring(i + 1, BASE_RADIUS, BASE_HEIGHT)
		var high_a := _ring(i, TOP_RADIUS, TOP_HEIGHT)
		var high_b := _ring(i + 1, TOP_RADIUS, TOP_HEIGHT)
		var side := SpacePalette.shade(SpacePalette.SLATE, i % shades)
		_tri(st, low_a, low_b, high_b, side, inside)
		_tri(st, low_a, high_b, high_a, side, inside)
		var top := SpacePalette.shade(SpacePalette.RUST if rust else SpacePalette.SLATE, (i + 1) % shades)
		_tri(st, high_a, high_b, apex, top, inside)
		_tri(st, low_b, low_a, under, SpacePalette.scree(SpacePalette.SLATE), inside)
	return st.commit()

## The head: a blunt block in dark rust, in front of the shell.
static func head_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_block(st, Vector3(-HEAD_HALF_WIDTH, HEAD_BOTTOM, HEAD_FRONT), Vector3(HEAD_HALF_WIDTH, HEAD_TOP, HEAD_BACK),
		SpacePalette.scree(SpacePalette.RUST))
	return st.commit()

## The six legs, each a thigh out from the shell and a shin down to a point,
## in the dark slate of the underside.
static func legs_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colour := SpacePalette.scree(SpacePalette.SLATE)
	for side in [-1.0, 1.0]:
		for z in LEG_Z:
			var hip := Vector3(side * HIP.x, HIP.y, z)
			var knee := Vector3(side * KNEE.x, KNEE.y, z * 1.1)
			var foot := Vector3(side * FOOT.x, FOOT.y, z * 1.15)
			_limb(st, hip, knee, THIGH_THICKNESS, SHIN_THICKNESS, colour)
			_limb(st, knee, foot, SHIN_THICKNESS, 0.0, colour)
	return st.commit()

## The two pale facets on its face: a quad each, a hair proud of the head.
static func eyes_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := HEAD_FRONT - 0.003
	var inside := Vector3(0, EYE_HEIGHT, HEAD_BACK)
	for side in [-1.0, 1.0]:
		var x: float = side * EYE_APART
		var a := Vector3(x - EYE_SIZE.x * 0.5, EYE_HEIGHT - EYE_SIZE.y * 0.5, z)
		var b := Vector3(x + EYE_SIZE.x * 0.5, EYE_HEIGHT - EYE_SIZE.y * 0.5, z)
		var c := Vector3(x + EYE_SIZE.x * 0.5, EYE_HEIGHT + EYE_SIZE.y * 0.5, z)
		var d := Vector3(x - EYE_SIZE.x * 0.5, EYE_HEIGHT + EYE_SIZE.y * 0.5, z)
		_tri(st, a, b, c, SpacePalette.SKITTER_EYE, inside)
		_tri(st, a, c, d, SpacePalette.SKITTER_EYE, inside)
	return st.commit()

## A box from `low` to `high`, twelve triangles.
static func _block(st: SurfaceTool, low: Vector3, high: Vector3, colour: Color) -> void:
	var inside := (low + high) * 0.5
	var c: Array[Vector3] = []
	for x in [low.x, high.x]:
		for y in [low.y, high.y]:
			for z in [low.z, high.z]:
				c.append(Vector3(x, y, z))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f in faces:
		_tri(st, c[f[0]], c[f[1]], c[f[2]], colour, inside)
		_tri(st, c[f[0]], c[f[2]], c[f[3]], colour, inside)

## A three-sided limb from `a` (thickness `ra`) to `b` (`rb`, 0 for a point).
static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, colour: Color) -> void:
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var near: Array[Vector3] = []
	var far: Array[Vector3] = []
	for k in 3:
		var turn := u * cos(TAU * k / 3.0) + v * sin(TAU * k / 3.0)
		near.append(a + turn * ra)
		far.append(b + turn * rb)
	var inside := (a + b) * 0.5
	for k in 3:
		var j := (k + 1) % 3
		if rb <= 0.0:
			_tri(st, near[k], near[j], b, colour, inside)
		else:
			_tri(st, near[k], near[j], far[j], colour, inside)
			_tri(st, near[k], far[j], far[k], colour, inside)

## A triangle facing away from `inside`. Godot's front faces wind clockwise
## seen from the front.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, inside: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	for p in [a, b, c]:
		st.set_color(colour)
		st.set_normal(n)
		st.add_vertex(p)
