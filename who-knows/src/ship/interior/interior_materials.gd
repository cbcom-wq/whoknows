class_name InteriorMaterials
extends RefCounted

## Builds the interior's materials, once each (spec §3.2). Structure and props
## are plain StandardMaterial3D in flat colour: the stylized look needs no
## texture work, and it keeps the GPU cost down. Only three things need
## custom shaders -- lit strips and indicators (glow), animated screens
## (screen), and the cockpit nose's projected windows (canopy_window).

const GLOW_SHADER: Shader = preload("res://data/materials/interior/glow.gdshader")
const SCREEN_SHADER: Shader = preload("res://data/materials/interior/screen.gdshader")
const CANOPY_SHADER: Shader = preload("res://data/materials/interior/canopy_window.gdshader")

## glow.gdshader's energy. InteriorKit.lit() pre-scales each lit piece's
## vertex colour by (its energy / GLOW_ENERGY), so one merged mesh holds lights
## of any strength up to this.
const GLOW_ENERGY := 2.4

static var _cache: Dictionary = {}

## A flat structure colour: floors, ceilings, walls. No rim -- rim light on a
## surface seen at a glancing angle, like the whole ceiling, blows it out.
static func flat(color: Color) -> StandardMaterial3D:
	var key := "flat:%s" % color.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_cache[key] = m
	return _cache[key]

## Every prop's solid geometry. Colour rides on the vertices, so one material
## serves the whole merged mesh; a faint rim keeps chunky shapes apart in dim
## light.
static func props() -> StandardMaterial3D:
	if not _cache.has(&"props"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		m.rim_enabled = true
		m.rim = 0.15
		m.rim_tint = 0.5
		_cache[&"props"] = m
	return _cache[&"props"]

static func glow() -> ShaderMaterial:
	if not _cache.has(&"glow"):
		var m := ShaderMaterial.new()
		m.shader = GLOW_SHADER
		m.set_shader_parameter(&"energy", GLOW_ENERGY)
		_cache[&"glow"] = m
	return _cache[&"glow"]

static func screen() -> ShaderMaterial:
	if not _cache.has(&"screen"):
		var m := ShaderMaterial.new()
		m.shader = SCREEN_SHADER
		m.set_shader_parameter(&"back_color", InteriorPalette.SCREEN_BACK)
		m.set_shader_parameter(&"color_a", InteriorPalette.AMBER)
		m.set_shader_parameter(&"color_b", InteriorPalette.LAVENDER)
		m.set_shader_parameter(&"color_c", InteriorPalette.SKY)
		m.set_shader_parameter(&"color_d", InteriorPalette.CORAL)
		_cache[&"screen"] = m
	return _cache[&"screen"]

## Porthole glass: tint and glint both come from vertex colour and alpha.
static func glass() -> StandardMaterial3D:
	if not _cache.has(&"glass"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.1
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[&"glass"] = m
	return _cache[&"glass"]

## The nose shell with no canopy view wired: the same shader with black
## windows. Used whenever InteriorBuilder.canopy_material is null -- every
## builder test -- so a headless rebuild never leaves a hole in the front.
static func canopy_fallback() -> ShaderMaterial:
	if not _cache.has(&"canopy_fallback"):
		var m := ShaderMaterial.new()
		m.shader = CANOPY_SHADER
		m.set_shader_parameter(&"shell_color", InteriorPalette.WALL)
		m.set_shader_parameter(&"frame_color", InteriorPalette.TRIM)
		_cache[&"canopy_fallback"] = m
	return _cache[&"canopy_fallback"]
