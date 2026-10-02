class_name BeltLook
extends MultiMeshInstance3D

## A belt seen from afar (the system skeleton spec §7.5): chunky slabs along
## its centre circle, each placed by the proxy rule on its own (BodyProxy), so
## from across the system a belt reads as a broken band. Close by, slabs
## dither out as the belt's real giants fade in, by the material's built-in
## distance fade.
##
## The floating origin (CLAUDE.md): a member of Universe.EXTERIOR_SPACE whose
## parent never moves, its slabs placed from their UniversePoints. They are
## placed again only once the focus has moved REWORK_AFTER: from 350 km, that
## is a fraction of a pixel. Between times the shift moves the node with
## everything else.

const SLABS := 320
## A slab's size: across, and thick. Each stands for tens of kilometres of a
## belt 40-80 km wide (the world scale spec §3.5); tuned at the renders.
const SLAB_ACROSS := Vector2(8000.0, 16000.0)
const SLAB_THICK := 1500.0
## Slabs spread this far through the belt's cross-section, as a share of it.
const SPREAD := 0.7
## A slab is gone within FADE_GONE of the camera and whole beyond FADE_WHOLE:
## the giant rocks' own fade (20 to 25 km) takes over there.
const FADE_GONE := 22000.0
const FADE_WHOLE := 26000.0
const REWORK_AFTER := 250.0
## At warp no giant loads to take a slab's place, so every slab shows (the
## warp spec §5.2): only one right on the canopy dithers out.
const WHOLE_GONE := 40.0
const WHOLE_NEAR := 120.0

var belt: AsteroidShapes.Belt
## Each slab's place in the universe, its turn and size, and its colour.
var points: Array[UniversePoint] = []
var shapes: Array[Basis] = []
var colours: Array[Color] = []

var _buf := PackedFloat32Array()
var _anchor: UniversePoint

static var _material: StandardMaterial3D
static var _whole_material: StandardMaterial3D

func setup(p_belt: AsteroidShapes.Belt, seed: int) -> void:
	belt = p_belt
	layers = 1
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = material()
	add_to_group(Universe.EXTERIOR_SPACE)
	var across := belt.normal.cross(Vector3.RIGHT)
	if across.length() < 0.1:
		across = belt.normal.cross(Vector3.FORWARD)
	across = across.normalized()
	var sideways := belt.normal.cross(across)
	var rng := WorldSeed.rng(seed, &"belt_look")
	for i in SLABS:
		var angle := (i + rng.randf()) / SLABS * TAU
		var out := across * cos(angle) + sideways * sin(angle)
		var r := belt.radius + rng.randf_range(-SPREAD, SPREAD) * belt.half_width
		var h := rng.randf_range(-SPREAD, SPREAD) * belt.half_thickness
		points.append(belt.centre.plus(out * r + belt.normal * h))
		var size := rng.randf_range(SLAB_ACROSS.x, SLAB_ACROSS.y)
		var turn := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		shapes.append(turn * Basis.from_scale(Vector3(size, SLAB_THICK, size * rng.randf_range(0.5, 1.0))))
		colours.append(SpacePalette.ROCKS[rng.randi_range(0, SpacePalette.ROCKS.size() - 1)])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = RockMesh.mesh(RockMesh.Shape.BOULDER, 1)
	mm.instance_count = SLABS
	multimesh = mm
	_buf.resize(SLABS * 16)

## Places every slab for `focus`: the node at the focus, each slab by the
## proxy rule.
func place(universe: Universe, focus: UniversePoint) -> void:
	if _anchor != null and focus.minus(_anchor).length() < REWORK_AFTER:
		return
	_anchor = focus
	global_transform = Transform3D(Basis.IDENTITY, universe.to_engine(focus))
	for i in points.size():
		var off := points[i].minus(focus)
		var d := off.length()
		var s := 1.0 if d <= BodyProxy.PROXY_AT else BodyProxy.PROXY_AT / d
		AsteroidStream.write(_buf, i, shapes[i] * s, off * s, colours[i])
	multimesh.buffer = _buf

## Every slab shown, near or far, while a warp carries you; the giants' own
## fade otherwise.
func set_whole(on: bool) -> void:
	material_override = whole_material() if on else material()
	rework()

## Forgets where the slabs were placed, so the next place() does it.
func rework() -> void:
	_anchor = null

static func whole_material() -> StandardMaterial3D:
	if _whole_material == null:
		_whole_material = material().duplicate()
		_whole_material.distance_fade_min_distance = WHOLE_GONE
		_whole_material.distance_fade_max_distance = WHOLE_NEAR
	return _whole_material

## Rock colour times each slab's instance colour, dithering out close in.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0
		_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		_material.distance_fade_min_distance = FADE_GONE
		_material.distance_fade_max_distance = FADE_WHOLE
	return _material
