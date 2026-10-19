class_name LimpetLook
extends Node3D

## The limpet as you see it (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §6, §9; foundation spec §13.4): a
## fluted shell like a real limpet's -- a raised apex nub, and eight ribs of
## lavender crystal running down from it to a scalloped rim, the shell between
## them in its rock's colour. So it belongs to its rock but carries crystal as
## the skitter's patches do, and its outline is not a stone's. Sipping
## brightens the ribs to the palette's brightest shade, with no glow, so the
## sip shows from above. Flat-shaded, no texture, colours from SpacePalette
## only; it fades in with distance as the rocks do. Silent. Nearly still, so it
## has nothing to pose and no _process.

## Built 1 m across and 0.58 m high; NpcLooks scales it to the species.
const RIBS := 8
## The rim: a rib's tip on the ground, the valley between two lifted and drawn
## in, so the edge scallops.
const TIP_RADIUS := 0.5
const VALLEY_RADIUS := 0.42
const VALLEY_HEIGHT := 0.1
## The apex nub: a ring, then its point.
const NUB_RADIUS := 0.13
const NUB_HEIGHT := 0.44
const APEX_HEIGHT := 0.58
## Where a rib's crest starts (by the nub) and ends (at the rim), as radius and
## height; the crest stands clear of the shell.
const CREST_START := Vector2(0.14, 0.55)
const CREST_END := Vector2(0.5, 0.15)
## How far along the shell's edges a rib's foot reaches each side of its crest,
## as a share of the way to the next valley.
const RIB_SPREAD := 0.7

var action: StringName = &""
var fade := Vector2(70, 95)
var _ribs: MeshInstance3D
var _resting: ArrayMesh
var _sipping: ArrayMesh

## Builds it in `colour` (its rock's), with `variety` turning its ribs so no
## two are quite alike.
func build(variety: float, colour: Color, p_fade: Vector2) -> void:
	fade = p_fade
	var material := _material()
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = shell_mesh(colour, variety)
	shell.material_override = material
	add_child(shell)
	_resting = ribs_mesh(variety, false)
	_sipping = ribs_mesh(variety, true)
	_ribs = MeshInstance3D.new()
	_ribs.name = "Ribs"
	_ribs.mesh = _resting
	_ribs.material_override = material
	add_child(_ribs)

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

## What it is doing: &"sip" brightens its ribs; anything else, and they go back.
func act(p_action: StringName) -> void:
	if p_action == action:
		return
	action = p_action
	_ribs.mesh = _sipping if p_action == &"sip" else _resting

## A point at `radius` and `height` on the way round at `k` of RIBS, turned by
## `turn`.
static func _at(k: float, radius: float, height: float, turn: float) -> Vector3:
	var a := TAU * k / float(RIBS) + turn
	return Vector3(sin(a) * radius, height, cos(a) * radius)

## The shell: the apex nub on a band of facets down to the scalloped rim, each
## in one of the rock's shades. A veined rock is white in the material (its own
## vertex colours show), so its limpets take the ash the rest of it is.
static func shell_mesh(colour: Color, variety: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := SpacePalette.ASH if colour == SpacePalette.UNTINTED else colour
	var turn := variety * TAU / float(RIBS)
	var shades := SpacePalette.SHADES.size()
	var apex := Vector3(0, APEX_HEIGHT, 0)
	for i in RIBS:
		var nub := _at(i, NUB_RADIUS, NUB_HEIGHT, turn)
		var next_nub := _at(i + 1, NUB_RADIUS, NUB_HEIGHT, turn)
		var tip := _at(i, TIP_RADIUS, 0.0, turn)
		var valley := _at(i + 0.5, VALLEY_RADIUS, VALLEY_HEIGHT, turn)
		var next_tip := _at(i + 1, TIP_RADIUS, 0.0, turn)
		_tri(st, nub, next_nub, apex, SpacePalette.shade(base, (i + 1) % shades))
		_tri(st, nub, tip, valley, SpacePalette.shade(base, i % shades))
		_tri(st, nub, valley, next_nub, SpacePalette.shade(base, (i + 1) % shades))
		_tri(st, next_nub, valley, next_tip, SpacePalette.shade(base, (i + 2) % shades))
	return st.commit()

## The ribs' crystal: the palette's darkest lavender step at rest and its
## brightest while sipping, so the sip reads from above.
static func rib_colour(bright: bool) -> Color:
	return SpacePalette.shade(SpacePalette.CRYSTAL, SpacePalette.SHADES.size() - 1 if bright else 0)

## The ribs: eight low tents of crystal, each from the nub down to a tip of the
## rim, standing on the shell. `bright` is sipping.
static func ribs_mesh(variety: float, bright: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crystal := rib_colour(bright)
	var turn := variety * TAU / float(RIBS)
	for i in RIBS:
		var nub := _at(i, NUB_RADIUS, NUB_HEIGHT, turn)
		var nub_l := nub.lerp(_at(i - 1, NUB_RADIUS, NUB_HEIGHT, turn), RIB_SPREAD)
		var nub_r := nub.lerp(_at(i + 1, NUB_RADIUS, NUB_HEIGHT, turn), RIB_SPREAD)
		var tip := _at(i, TIP_RADIUS, 0.0, turn)
		var foot_l := tip.lerp(_at(i - 0.5, VALLEY_RADIUS, VALLEY_HEIGHT, turn), RIB_SPREAD)
		var foot_r := tip.lerp(_at(i + 0.5, VALLEY_RADIUS, VALLEY_HEIGHT, turn), RIB_SPREAD)
		var crest_a := _at(i, CREST_START.x, CREST_START.y, turn)
		var crest_b := _at(i, CREST_END.x, CREST_END.y, turn)
		var inside := (nub_l + nub_r + foot_l + foot_r) * 0.25 + Vector3(0, 0.02, 0)
		_tri_out(st, nub_l, foot_l, crest_b, crystal, inside)
		_tri_out(st, nub_l, crest_b, crest_a, crystal, inside)
		_tri_out(st, nub_r, crest_a, crest_b, crystal, inside)
		_tri_out(st, nub_r, crest_b, foot_r, crystal, inside)
		_tri_out(st, foot_l, foot_r, crest_b, crystal, inside)
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	_tri_out(st, a, b, c, colour, Vector3(0, 0.2, 0))

## A triangle facing away from `inside`. Godot's front faces wind clockwise
## seen from the front.
static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, inside: Vector3) -> void:
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
