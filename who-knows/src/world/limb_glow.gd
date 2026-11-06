class_name LimbGlow
extends MeshInstance3D

## The glow round the edge of a world with air, seen from outside (desert-world
## spec §6.2 stage 1, §6.3): a ring in the sky colour of the world's palette,
## brightest at the limb and fading outward, lit on the sun's side and dim on
## the night side.
##
## Geometry with an engine material and no shader (the interior's shader budget
## is spent, visual-style.md §2): a flat ring in the limb's plane, the plane
## where the eye's tangent lines touch the sphere, R^2/d from the centre toward
## the eye. Three rows of vertices, ROWS of the way from the inner edge to the
## outer one, their vertex alpha ROW_ALPHA, added to what is behind. The planet
## in front hides the inner inset; the rim is the only part that shows.
##
## It is built in its proxy's local frame in true metres: BodyProxy scales the
## whole proxy down beyond PROXY_AT, so the angles stay exact at any distance.
## Far off, the outer edge is the air shell's silhouette; inside the air it is
## a band over the limb, continuous across the air top; the limb's dip under
## the horizontal fades it near the ground, where the sky's own horizon takes
## over.
##
## It redraws only once the eye has turned or the distance changed enough to
## show, and is hidden when there is nothing to draw.
##
## The floating origin (CLAUDE.md): a child of the world's BodyProxy, which is
## a member of Universe.EXTERIOR_SPACE; it remembers no engine position.

const SEGMENTS := 96
## Where each row sits from the inner (0) to the outer (1) edge, and its alpha.
const ROWS: Array[float] = [0.0, 0.25, 1.0]
const ROW_ALPHA: Array[float] = [1.0, 0.6, 0.0]
const RIM_ALPHA := 0.8
## Its strength on the night side, against 1 on the sun's.
const RIM_NIGHT := 0.2
## The inner edge lies this far inside the limb, behind the planet's body.
const INNER_INSET_DEG := 0.5
## Inside the air the band reaches this far outside the limb.
const BAND_INSIDE_DEG := 6.0
## Never beyond the horizontal.
const MAX_ANGLE_DEG := 89.5
## The limb's dip under the horizontal: gone below DIP_GONE_DEG, full from
## DIP_FULL_DEG.
const DIP_GONE_DEG := 2.0
const DIP_FULL_DEG := 8.0
## The glow fades out as the air where you are thickens, from this to this.
const AIR_FADE_FROM := 0.3
const AIR_FADE_TO := 0.8
## It redraws after the eye turns more than this about the centre, or d
## changes by more than this share of itself.
const REDRAW_TURN_DEG := 0.25
const REDRAW_NEAR := 0.005

var _radius := 0.0
var _top := 0.0
var _colour := SpacePalette.UNTINTED
var _axis := Vector3.ZERO
var _d := 0.0
var _strength := 0.0
var _sun := Vector3.ZERO
var _material: StandardMaterial3D

## The ring's inner and outer edges as angles from the line from the eye to the
## centre, for a world of radius `radius` with air to `top` over it, the eye
## `d` from the centre.
static func angles(radius: float, top: float, d: float) -> Vector2:
	var limb := asin(minf(radius / d, 1.0))
	var inner := limb - deg_to_rad(INNER_INSET_DEG)
	var outer := minf(asin(minf((radius + top) / d, 1.0)),
		minf(limb + deg_to_rad(BAND_INSIDE_DEG), deg_to_rad(MAX_ANGLE_DEG)))
	return Vector2(inner, outer)

## How much of it shows: nothing while the limb dips under the horizontal by
## less than DIP_GONE_DEG, and nothing in thick air where you are.
static func strength(radius: float, d: float, air_here: float) -> float:
	var dip := acos(minf(radius / d, 1.0))
	return smoothstep(deg_to_rad(DIP_GONE_DEG), deg_to_rad(DIP_FULL_DEG), dip) \
		* (1.0 - smoothstep(AIR_FADE_FROM, AIR_FADE_TO, air_here))

## How lit the rim is in direction `dir` from the centre, with the sun in
## `sun_dir`.
static func lit(dir: Vector3, sun_dir: Vector3) -> float:
	return lerpf(RIM_NIGHT, 1.0, smoothstep(-0.3, 0.3, dir.dot(sun_dir)))

func setup(body: SystemBody) -> void:
	name = "LimbGlow"
	_radius = body.radius
	_top = body.recipe.air_top()
	var sky: Color = SpacePalette.WORLDS[body.recipe.palette][&"sky"]
	_colour = sky
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The haze never dims the glow itself.
	_material.disable_fog = true
	material_override = _material
	layers = 1
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

## For the eye at `eye_local` from the world's centre (true metres, the
## proxy's local frame), the sun toward `sun_dir`, and `air_here` where the eye
## is.
func place(eye_local: Vector3, sun_dir: Vector3, air_here: float) -> void:
	var d := eye_local.length()
	var s := strength(_radius, d, air_here) if d > _radius else 0.0
	if s <= 0.0:
		visible = false
		return
	var axis := eye_local / d
	if visible and _axis != Vector3.ZERO and _sun_unchanged(sun_dir) \
			and axis.angle_to(_axis) <= deg_to_rad(REDRAW_TURN_DEG) \
			and absf(d - _d) <= REDRAW_NEAR * d and absf(s - _strength) < 0.01:
		return
	_axis = axis
	_d = d
	_strength = s
	_sun = sun_dir
	mesh = _ring(axis, d, sun_dir, s)
	visible = true

## How strong it was drawn at the last place(); 0 while hidden.
func drawn_strength() -> float:
	return _strength if visible else 0.0

func _sun_unchanged(sun_dir: Vector3) -> bool:
	return sun_dir.angle_to(_sun) <= deg_to_rad(REDRAW_TURN_DEG)

func _ring(axis: Vector3, d: float, sun_dir: Vector3, s: float) -> ArrayMesh:
	var a := angles(_radius, _top, d)
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.99 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var centre := axis * (_radius * _radius / d)
	var reach := d - _radius * _radius / d
	var rings: Array[PackedVector3Array] = []
	var tints: Array[PackedColorArray] = []
	for row in ROWS.size():
		var r := reach * tan(lerpf(a.x, a.y, ROWS[row]))
		var pts := PackedVector3Array()
		var cols := PackedColorArray()
		for i in SEGMENTS + 1:
			var t := TAU * (i % SEGMENTS) / SEGMENTS
			var p := centre + (u * cos(t) + v * sin(t)) * r
			pts.append(p)
			var c := _colour
			c.a = RIM_ALPHA * ROW_ALPHA[row] * s * lit(p.normalized(), sun_dir)
			cols.append(c)
		rings.append(pts)
		tints.append(cols)
	var verts := PackedVector3Array()
	var colours := PackedColorArray()
	for row in ROWS.size() - 1:
		for i in SEGMENTS:
			var q := [rings[row][i], rings[row][i + 1], rings[row + 1][i + 1], rings[row + 1][i]]
			var k := [tints[row][i], tints[row][i + 1], tints[row + 1][i + 1], tints[row + 1][i]]
			for n in [0, 1, 2, 0, 2, 3]:
				verts.append(q[n])
				colours.append(k[n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colours
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
