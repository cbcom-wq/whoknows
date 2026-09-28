class_name RingLook
extends MultiMeshInstance3D

## A planet's ring seen from afar (the system skeleton spec §7.5): chunky
## flat slabs scattered through its annulus, in rock colours, a child of the
## planet's proxy so it is placed and scaled with it. Up close each slab
## dithers out as the ring's real rocks fade in, by the material's built-in
## distance fade: no new shader, and nothing pops.

## Slabs in a ring, and their size: across, and thick.
const SLABS := 128
const SLAB_ACROSS := Vector2(150.0, 300.0)
const SLAB_THICK := 30.0
## A slab is gone within FADE_GONE of the camera and whole beyond FADE_WHOLE:
## about where the ring's mid-size rocks fade in.
const FADE_GONE := 2000.0
const FADE_WHOLE := 3000.0

static var _material: StandardMaterial3D

func setup(body: SystemBody) -> void:
	name = "Ring"
	layers = 1
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = material()
	var ring := body.ring
	var across := ring.normal.cross(Vector3.RIGHT)
	if across.length() < 0.1:
		across = ring.normal.cross(Vector3.FORWARD)
	across = across.normalized()
	var sideways := ring.normal.cross(across)
	var rng := WorldSeed.rng(body.seed, &"ring_look")
	var buf := PackedFloat32Array()
	for i in SLABS:
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf_range(ring.inner * ring.inner, ring.outer * ring.outer))
		var h := rng.randf_range(-ring.half_thickness, ring.half_thickness) * 0.5
		var at := (across * cos(angle) + sideways * sin(angle)) * r + ring.normal * h
		var size := rng.randf_range(SLAB_ACROSS.x, SLAB_ACROSS.y)
		var spin := Basis(ring.normal, rng.randf() * TAU)
		var lay := Basis(across, sideways, ring.normal).orthonormalized()
		var shape := spin * lay * Basis.from_scale(Vector3(size, size * rng.randf_range(0.5, 1.0), SLAB_THICK))
		var colour: Color = SpacePalette.ROCKS[rng.randi_range(0, SpacePalette.ROCKS.size() - 1)]
		buf = AsteroidStream.pack(buf, Transform3D(shape, at), colour)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = RockMesh.mesh(RockMesh.Shape.SHARD, 1)
	mm.instance_count = SLABS
	mm.buffer = buf
	multimesh = mm

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
