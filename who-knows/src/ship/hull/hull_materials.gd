class_name HullMaterials
extends RefCounted

## The hull's outside materials (ship exterior spec §3.3, §5.1, §6.4). Engine
## materials and new instances of the interior's glow shader; no new shader
## (style guide §2.5).

const LIVERY: ShaderMaterial = preload("res://data/materials/hull_livery.tres")
## The windows' glow at full power, as glow.gdshader's energy.
const WINDOW_ENERGY := 2.4
## A beam's strength at the lens, before it fades along its length.
const BEAM_ALPHA := 0.012
## How much of that is left halfway along a beam (a stop in its fade).
const BEAM_MID_ALPHA := 0.2

static var _cache: Dictionary = {}

## The plating: the livery the hull has always had, stripe and all.
static func livery() -> ShaderMaterial:
	return LIVERY

## Trim, frames, bells and housings: flat vertex colour, a little glossier
## than a cabin's, no rim.
static func trim() -> StandardMaterial3D:
	if not _cache.has(&"trim"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.6
		_cache[&"trim"] = m
	return _cache[&"trim"]

## Window glass from outside: opaque, glossy, coloured by the vertices.
static func window_glass() -> StandardMaterial3D:
	if not _cache.has(&"window_glass"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.15
		m.metallic = 0.3
		_cache[&"window_glass"] = m
	return _cache[&"window_glass"]

## A glow material of its own, so its energy can change alone: a ship's
## windows, or one light group's lenses.
static func glow_instance(energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = InteriorMaterials.GLOW_SHADER
	m.set_shader_parameter(&"energy", energy)
	return m

## A light's beam (spec §6.4): added light, unshaded, fading from the lens
## (v = 1) to nothing (v = 0), and softly wherever it meets rock or hull.
static func beam(colour: Color) -> StandardMaterial3D:
	var key := "beam:%s" % colour.to_html()
	if not _cache.has(key):
		var clear := colour
		clear.a = 0.0
		var full := colour
		full.a = 1.0
		# Alpha 0 / 0.2 / 1 at v 0 / 0.5 / 1: a shaft strong at the lens that
		# is mostly gone by halfway, not a solid that stops at its far end.
		var mid := colour
		mid.a = BEAM_MID_ALPHA
		var gradient := Gradient.new()
		gradient.set_color(0, clear)
		gradient.set_color(1, full)
		gradient.add_point(0.5, mid)
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.width = 4
		tex.height = 64
		var tint := colour
		tint.a = BEAM_ALPHA
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = tint
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Outside faces only: both faces would add the shaft twice over.
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 4.0
		# Near opaque, far gone: min above max fades out with distance.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 400.0
		m.distance_fade_max_distance = 150.0
		_cache[key] = m
	return _cache[key]
