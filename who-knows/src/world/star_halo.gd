class_name StarHalo
extends MeshInstance3D
## The soft glow round the sun seen through air (desert-world spec §6.2 stage
## 3, §6.3 "the star ... gets the soft halo"). The sky's own sun glow cannot
## give it: the engine hands the sky shader the light's way unturned while
## AirMood turns the sky onto the local up, so that glow sat as far off the
## star as the sky was turned (31 deg in descent_render's renders). AirMood
## takes the light out of the sky (SKY_MODE_LIGHT_ONLY) and this disc draws the
## glow instead.
##
## A disc on the star's proxy, facing the focus, reaching HALO_DEG from its
## middle to its rim at the star's distance -- as the sky's sun_angle_max
## measured its glow -- in the star palette's light: its vertex alpha 1 at the
## middle and 0 at the rim. Unshaded, added to what is behind it, never in the
## haze, on render layer 1. The star's body hides its middle. How strong it is
## AirMood sets: mood.halo_deg / HALO_DEG, and nothing with no air.
##
## The floating origin (CLAUDE.md): a child of the star's proxy, which is a
## member of Universe.EXTERIOR_SPACE; StarSystem places it afresh every tick.

const HALO_DEG := AirMood.HALO_DEG
## Steps round the rim.
const SEGMENTS := 48

var _material: StandardMaterial3D

## Builds the disc in `star`'s light (a SpacePalette.STARS entry).
func setup(star: Dictionary) -> void:
	name = "StarHalo"
	mesh = disc(star[&"light"])
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The haze never dims the light itself.
	_material.disable_fog = true
	material_override = _material
	layers = 1
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_strength(0.0)

## A unit disc in the xy plane, facing +z: `light` at the middle, fading to
## nothing at the rim.
static func disc(light: Color) -> ArrayMesh:
	var middle := light
	middle.a = 1.0
	var rim := light
	rim.a = 0.0
	var verts := PackedVector3Array()
	var colours := PackedColorArray()
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		verts.append_array([Vector3.ZERO, Vector3(cos(a1), sin(a1), 0.0), Vector3(cos(a0), sin(a0), 0.0)])
		colours.append_array([middle, rim, rim])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colours
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## 0 hides it; 1 is full.
func set_strength(strength: float) -> void:
	var c := SpacePalette.UNTINTED
	c.a = clampf(strength, 0.0, 1.0)
	_material.albedo_color = c
	visible = c.a > 0.0

func strength() -> float:
	return _material.albedo_color.a if visible else 0.0

## On the star's proxy at `at`, facing `focus` (engine positions), HALO_DEG
## from its middle to its rim at that distance.
func place(at: Vector3, focus: Vector3) -> void:
	var to_focus := focus - at
	var d := to_focus.length()
	if d < 1.0:
		return
	var up := Vector3.UP if absf(to_focus.y / d) < 0.99 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(-to_focus, up).scaled(Vector3.ONE * d * tan(deg_to_rad(HALO_DEG))), at)
