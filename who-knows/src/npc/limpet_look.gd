class_name LimpetLook
extends Node3D

## The limpet as you see it (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §6, §9; foundation spec §13.4): a low
## flat cone of chunky facets in its rock's colour, a lavender underside
## showing round its foot, and nothing else. Sipping brightens the lavender to
## the palette's brightest shade, with no glow. Flat-shaded, no texture,
## colours from SpacePalette only; it fades in with distance as the rocks do.
## Silent. Nearly still, so it has nothing to pose and no _process.

## Built 1 m across and 0.5 m high; NpcLooks scales it to the species.
const SIDES := 8
const FOOT_RADIUS := 0.5
const FOOT_HEIGHT := 0.16
const SKIRT_RADIUS := 0.44
const SHOULDER_RADIUS := 0.34
const SHOULDER_HEIGHT := 0.34
const APEX_HEIGHT := 0.5

var action: StringName = &""
var fade := Vector2(70, 95)
var _crystal: MeshInstance3D
var _resting: ArrayMesh
var _sipping: ArrayMesh

## Builds it in `colour` (its rock's), with `variety` turning its facets so no
## two are quite alike.
func build(variety: float, colour: Color, p_fade: Vector2) -> void:
	fade = p_fade
	var material := _material()
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = shell_mesh(colour, variety)
	shell.material_override = material
	add_child(shell)
	_resting = underside_mesh(variety, false)
	_sipping = underside_mesh(variety, true)
	_crystal = MeshInstance3D.new()
	_crystal.name = "Underside"
	_crystal.mesh = _resting
	_crystal.material_override = material
	add_child(_crystal)

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

## What it is doing: &"sip" brightens its crystal facets; anything else, and
## they go back.
func act(p_action: StringName) -> void:
	if p_action == action:
		return
	action = p_action
	_crystal.mesh = _sipping if p_action == &"sip" else _resting

## The shell: a foot ring, a shoulder ring and an apex, each side a facet in
## one of the rock's shades. A veined rock is white in the material (its own
## vertex colours show), so its limpets take the ash the rest of it is.
static func shell_mesh(colour: Color, variety: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := SpacePalette.ASH if colour == SpacePalette.UNTINTED else colour
	var turn := variety * TAU / float(SIDES)
	var foot: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	for i in SIDES:
		var a := TAU * float(i) / float(SIDES) + turn
		foot.append(Vector3(sin(a) * FOOT_RADIUS, FOOT_HEIGHT, cos(a) * FOOT_RADIUS))
		shoulder.append(Vector3(sin(a + 0.2) * SHOULDER_RADIUS, SHOULDER_HEIGHT, cos(a + 0.2) * SHOULDER_RADIUS))
	var apex := Vector3(sin(turn) * 0.04, APEX_HEIGHT, cos(turn) * 0.04)
	for i in SIDES:
		var j := (i + 1) % SIDES
		var shade := SpacePalette.shade(base, i % SpacePalette.SHADES.size())
		_tri(st, foot[i], foot[j], shoulder[j], shade)
		_tri(st, foot[i], shoulder[j], shoulder[i], shade)
		_tri(st, shoulder[i], shoulder[j], apex, SpacePalette.shade(base, (i + 1) % SpacePalette.SHADES.size()))
	return st.commit()

## The underside: a skirt from the foot ring in to a smaller ring on the
## ground, and the flat under it, all crystal; `bright` is the brightest shade
## of it (sipping).
static func underside_mesh(variety: float, bright: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crystal := SpacePalette.shade(SpacePalette.CRYSTAL, SpacePalette.SHADES.size() - 1) \
		if bright else SpacePalette.CRYSTAL
	var turn := variety * TAU / float(SIDES)
	var foot: Array[Vector3] = []
	var ground: Array[Vector3] = []
	for i in SIDES:
		var a := TAU * float(i) / float(SIDES) + turn
		foot.append(Vector3(sin(a) * FOOT_RADIUS, FOOT_HEIGHT, cos(a) * FOOT_RADIUS))
		ground.append(Vector3(sin(a) * SKIRT_RADIUS, 0.0, cos(a) * SKIRT_RADIUS))
	for i in SIDES:
		var j := (i + 1) % SIDES
		_tri(st, ground[i], ground[j], foot[j], crystal)
		_tri(st, ground[i], foot[j], foot[i], crystal)
		_tri(st, ground[j], ground[i], Vector3.ZERO, crystal)
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	# Godot's front faces wind clockwise seen from the front.
	var n := (c - a).cross(b - a).normalized()
	if n.dot((a + b + c) / 3.0 - Vector3(0, 0.2, 0)) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	for p in [a, b, c]:
		st.set_color(colour)
		st.set_normal(n)
		st.add_vertex(p)
