class_name BodyLook
extends RefCounted

## What a star, planet or moon looks like from afar (the system skeleton spec
## §7.2; the world scale spec §5.1): a faceted icosphere, flat-shaded, each
## face one colour. A world's far mesh is sampled from its WorldTerrain -- the
## same heights, patterns and craters its surface has up close -- so the
## hand-over to the surface changes a pixel or two. The star is one colour of
## its palette in broad shade patches. No texture, no noise on the surface
## itself: shape and flat colour carry it.
##
## Meshes are radius one; a proxy scales them.

## Subdivisions: a world from afar (1,280 faces), up close until the surface
## replaces it (5,120), and the star (1,280).
const FAR_DETAIL := 3
const NEAR_DETAIL := 4
const STAR_DETAIL := 3
## How finely the star's shade patches vary over it.
const SHADE_SCALE := 2.2

static var _materials := {}

## The mesh for `body` at `detail` subdivisions, radius one.
static func mesh(body: SystemBody, detail: int) -> ArrayMesh:
	var sphere := RockMesh.sphere(detail)
	var dirs: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	var terrain: WorldTerrain = WorldTerrain.new(body.recipe) if body.recipe != null else null
	var shades := _star_shades(body) if terrain == null else null
	var lifted := PackedVector3Array()
	lifted.resize(dirs.size())
	for i in dirs.size():
		lifted[i] = dirs[i] if terrain == null else dirs[i] * (1.0 + terrain.height_at(dirs[i]) / terrain.radius)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for t in range(0, faces.size(), 3):
		var a := lifted[faces[t]]
		var b := lifted[faces[t + 1]]
		var c := lifted[faces[t + 2]]
		var cross := (b - a).cross(c - a)
		if cross.dot(a + b + c) > 0.0:
			# Godot draws the side (b - a) x (c - a) points away from.
			var swap := b
			b = c
			c = swap
			cross = -cross
		var n := -cross.normalized()
		var mid := (a + b + c).normalized()
		var colour: Color
		if terrain == null:
			colour = _star_colour(body, shades, mid)
		else:
			var patch := (a - b).length() * terrain.radius * WorldTerrain.PATCH_QUADS
			colour = terrain.colour_at(mid, n.angle_to(mid), patch)
		positions.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
		colours.append_array(PackedColorArray([colour, colour, colour]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## The shell's distinct points at `detail`, radius one: the near collision
## hull, until the surface's own collision replaces it.
static func points(detail: int) -> PackedVector3Array:
	return RockMesh.sphere(detail)[0]

## The material every world shares: its vertex colours, lit by the sun. The
## star's is unshaded: it is the light, and is never in shadow.
static func material(star: bool) -> StandardMaterial3D:
	if not _materials.has(star):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		if star:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[star] = m
	return _materials[star]

static func _star_shades(body: SystemBody) -> FastNoiseLite:
	var shades := FastNoiseLite.new()
	shades.seed = WorldSeed.noise_seed(WorldSeed.sub(body.seed, &"shades"))
	shades.noise_type = FastNoiseLite.TYPE_CELLULAR
	shades.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	shades.frequency = 1.0
	shades.fractal_type = FastNoiseLite.FRACTAL_NONE
	return shades

static func _star_colour(body: SystemBody, shades: FastNoiseLite, d: Vector3) -> Color:
	var base: Color = SpacePalette.STARS[body.star_palette][&"body"]
	var cell := (shades.get_noise_3dv(d * SHADE_SCALE) + 1.0) * 0.5
	return SpacePalette.shade(base, clampi(floori(cell * SpacePalette.SHADES.size()), 0, SpacePalette.SHADES.size() - 1))
