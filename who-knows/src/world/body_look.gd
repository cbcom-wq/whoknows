class_name BodyLook
extends RefCounted

## What a star, planet or moon looks like (the system skeleton spec §7.2):
## a faceted icosphere, flat-shaded, each face one colour of its world's
## palette in one of SpacePalette.SHADES. Shades come in broad patches, the
## same at every detail, never triangle by triangle: faces read as big flat
## pieces and never as noise (style guide §3.5). The pattern follows the archetype --
## patches for ROLLING, bands for RIDGED, plateaus for MESA, big dark craters
## for CRATERED -- so it reads as a little world, not a ball. No texture, no
## noise on the surface itself: shape and flat colour carry it.
##
## Meshes are radius one; a proxy scales them. The shell is the icosphere
## itself, so its convex collision hull is exactly the world you see.

## Subdivisions: from afar (320 faces), up close (5,120), and the star (1,280).
const FAR_DETAIL := 2
const NEAR_DETAIL := 4
const STAR_DETAIL := 3
## How finely the pattern varies over the sphere.
const PATTERN_SCALE := 1.6
## Craters: how many, and how wide, in radians round the sphere.
const CRATERS := Vector2i(5, 9)
const CRATER_SIZE := Vector2(0.12, 0.35)
## Of a crater's width, the dark floor; the rest is its light rim.
const CRATER_FLOOR := 0.78
## Ridged bands: how many round the sphere.
const BANDS := 9.0
## How finely the shade patches vary over the sphere.
const SHADE_SCALE := 2.2

static var _materials := {}

## The mesh for `body` at `detail` subdivisions, radius one.
static func mesh(body: SystemBody, detail: int) -> ArrayMesh:
	var sphere := RockMesh.sphere(detail)
	var dirs: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	var pattern := _Pattern.new(body)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for t in range(0, faces.size(), 3):
		var a := dirs[faces[t]]
		var b := dirs[faces[t + 1]]
		var c := dirs[faces[t + 2]]
		var cross := (b - a).cross(c - a)
		if cross.dot(a + b + c) > 0.0:
			# Godot draws the side (b - a) x (c - a) points away from.
			var swap := b
			b = c
			c = swap
			cross = -cross
		var n := -cross.normalized()
		var colour := pattern.colour((a + b + c).normalized())
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

## The shell's distinct points at `detail`, radius one: its collision hull.
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

## One body's pattern, drawn from its own seed.
class _Pattern:
	var kind: SystemBody.Kind
	var archetype := WorldRecipe.Archetype.ROLLING
	var palette: Dictionary
	var star_colour: Color
	var noise := FastNoiseLite.new()
	var band_axis := Vector3.UP
	## [centre direction, angular radius] per crater.
	var craters: Array = []
	var shades := FastNoiseLite.new()

	func _init(body: SystemBody) -> void:
		kind = body.kind
		shades.seed = WorldSeed.noise_seed(WorldSeed.sub(body.seed, &"shades"))
		shades.noise_type = FastNoiseLite.TYPE_CELLULAR
		shades.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
		shades.frequency = 1.0
		shades.fractal_type = FastNoiseLite.FRACTAL_NONE
		if body.kind == SystemBody.Kind.STAR:
			star_colour = SpacePalette.STARS[body.star_palette][&"body"]
			return
		archetype = body.recipe.archetype
		palette = SpacePalette.WORLDS[body.recipe.palette]
		noise.seed = WorldSeed.noise_seed(WorldSeed.sub(body.seed, &"look"))
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 1.0
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 2
		var rng := WorldSeed.rng(body.seed, &"marks")
		band_axis = _direction(rng)
		if archetype == WorldRecipe.Archetype.CRATERED:
			for i in rng.randi_range(CRATERS.x, CRATERS.y):
				craters.append([_direction(rng), rng.randf_range(CRATER_SIZE.x, CRATER_SIZE.y)])

	## The colour of the face facing `d`: its ground, in its patch's shade.
	func colour(d: Vector3) -> Color:
		var base: Color
		if kind == SystemBody.Kind.STAR:
			base = star_colour
		else:
			base = palette[_ground(d)]
		var cell := (shades.get_noise_3dv(d * SHADE_SCALE) + 1.0) * 0.5
		return SpacePalette.shade(base, clampi(floori(cell * SpacePalette.SHADES.size()), 0, SpacePalette.SHADES.size() - 1))

	## Which of the palette's grounds the face facing `d` is.
	func _ground(d: Vector3) -> StringName:
		var n := noise.get_noise_3dv(d * PATTERN_SCALE)
		match archetype:
			WorldRecipe.Archetype.RIDGED:
				var band := sin(d.dot(band_axis) * BANDS + n * 2.5)
				if band > 0.75:
					return &"rock"
				return &"ground_high" if band > 0.05 else &"ground_low"
			WorldRecipe.Archetype.MESA:
				if absf(n - 0.05) < 0.06:
					return &"rock"
				return &"ground_high" if n > 0.05 else &"ground_low"
			WorldRecipe.Archetype.CRATERED:
				for c: Array in craters:
					var angle := d.angle_to(c[0])
					if angle < c[1] * CRATER_FLOOR:
						return &"rock"
					if angle < c[1]:
						return &"ground_high"
				return &"dust" if n > 0.2 else &"ground_low"
		if n < -0.45:
			return &"rock"
		return &"ground_high" if n > 0.1 else &"ground_low"

	static func _direction(rng: RandomNumberGenerator) -> Vector3:
		while true:
			var v := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if v.length() > 0.2 and v.length() <= 1.0:
				return v.normalized()
		return Vector3.UP
