class_name Puffs
extends RefCounted

## The chunky vapour puff, shared by everything that puffs: the airlock's
## steam, its burst onto the hull, and the RCS thrusters (flight controls spec
## §6.2). An 8-segment low-poly sphere in the palette's steam, faded near the
## camera. Built-in materials only, never a new shader (style guide §2.5).

const SEGMENTS := 8
const RINGS := 4
## Puffs closer to the camera than this fade away, so one drifting through your
## head never fills the screen.
const FADE_NEAR := 0.25
const FADE_FAR := 0.9

## One puff. `flat` puffs are unshaded: vapour out on the hull, not lit rock.
static func mesh(flat: bool) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = SEGMENTS
	m.rings = RINGS
	var material := StandardMaterial3D.new()
	material.albedo_color = InteriorPalette.STEAM
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	if flat:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.shadow_to_opacity = false
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = FADE_NEAR
	material.distance_fade_max_distance = FADE_FAR
	m.material = material
	return m

## Fades in, holds, fades out: steam in the palette's off-white.
static func fade(peak: float) -> GradientTexture1D:
	var clear := InteriorPalette.STEAM
	clear.a = 0.0
	var thick := InteriorPalette.STEAM
	thick.a = peak
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([clear, thick, thick, clear])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex

## Grows from `from` to `to` times its size over a puff's life.
static func grow(from: float, to: float) -> CurveTexture:
	var c := Curve.new()
	c.max_value = maxf(from, to)
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex
