class_name RockDetail
extends RefCounted

## A big rock up close (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §18): the same cut sphere as its picture, sampled finely, cut again by a
## finer set of planes into ledges and shelves, with craters and boulders
## half-sunk into its surface. Shape carries the detail -- flat facets, each one
## of three shades of the rock's colour, no texture.
##
## Pure data in the rock's own frame (its size applied, not its turn), built on
## a worker thread; call RockMesh.warm() on the main thread first. Everything
## stays inside the rock's bounding radius, so no rock of its swarm overlaps it.

## Icosphere subdivisions: 5,120 triangles.
const DETAIL := 4
## The finer cuts: planes that take up to this fraction off the surface.
const FINE_CUTS := 28
const FINE_NEAR := 0.9
const FINE_FAR := 0.985
const CRATERS_MIN := 5
const CRATERS_MAX := 10
## A crater's angular radius, radians: a tenth to a quarter of the rock across.
const CRATER_MIN := 0.1
const CRATER_MAX := 0.25
## Bowl depth and rim height per crater radius, in the unit sphere's terms.
const CRATER_DEPTH := 0.4
const RIM_HEIGHT := 0.08
const BOULDERS_MIN := 20
const BOULDERS_MAX := 60
## Boulders' size, metres, for a 400 m rock; scaled with the rock.
const BOULDER_MIN := 2.0
const BOULDER_MAX := 15.0
## How much of a boulder is sunk below the surface.
const BOULDER_SUNK := 0.3

var positions := PackedVector3Array()
var normals := PackedVector3Array()
var colours := PackedColorArray()
## Triangles of its exact collision: its surface, then its boulders.
var faces := PackedVector3Array()
## [transform in the rock's frame, shape, colour, diameter, unit direction]
var boulders: Array = []
## [unit direction, angular radius]
var craters: Array = []

var _shape: int
var _size: Vector3
var _fine: Array[Vector4] = []

## The detail of `rock`, the same every time.
static func build(rock: AsteroidRock, world_seed: int) -> RockDetail:
	var detail := RockDetail.new()
	detail._make(rock, world_seed)
	return detail

## How far out the surface is along unit direction `d`, in the uncut unit
## sphere's terms: the shape's cuts, the finer cuts, then the craters.
func radius_at(d: Vector3) -> float:
	var r := RockMesh.cut_radius(_shape, d)
	var fine := 1.0
	for p in _fine:
		var along := d.x * p.x + d.y * p.y + d.z * p.z
		if along > 0.05:
			fine = minf(fine, p.w / along)
	r *= fine
	for c in craters:
		var theta := acos(clampf(d.dot(c[0]), -1.0, 1.0))
		var a: float = c[1]
		if theta < a:
			r -= CRATER_DEPTH * a * (1.0 - (theta / a) * (theta / a))
		elif theta < 1.3 * a:
			r += RIM_HEIGHT * a * (1.0 - absf(theta - 1.15 * a) / (0.15 * a))
	return r

## The surface point along unit direction `d`, in the rock's frame, metres.
func surface_point(d: Vector3) -> Vector3:
	return d * radius_at(d) * 0.5 * RockMesh.stretch_of(_shape) * _size

func _make(rock: AsteroidRock, world_seed: int) -> void:
	_shape = rock.shape
	_size = rock.size
	var rng := RandomNumberGenerator.new()
	rng.seed = AsteroidRecipe.cell_seed(world_seed, 7, rock.cell) ^ rock.index
	while _fine.size() < FINE_CUTS:
		var n := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if n.length() < 0.2:
			continue
		n = n.normalized()
		_fine.append(Vector4(n.x, n.y, n.z, rng.randf_range(FINE_NEAR, FINE_FAR)))
	for i in rng.randi_range(CRATERS_MIN, CRATERS_MAX):
		craters.append([_random_direction(rng), rng.randf_range(CRATER_MIN, CRATER_MAX)])
	_surface(rock, rng)
	_boulders(rock, rng)

func _surface(rock: AsteroidRock, rng: RandomNumberGenerator) -> void:
	var sphere := RockMesh.sphere(DETAIL)
	var dirs: PackedVector3Array = sphere[0]
	var tris: PackedInt32Array = sphere[1]
	var verts := PackedVector3Array()
	verts.resize(dirs.size())
	for i in dirs.size():
		verts[i] = surface_point(dirs[i])
	for t in range(0, tris.size(), 3):
		var a := verts[tris[t]]
		var b := verts[tris[t + 1]]
		var c := verts[tris[t + 2]]
		var cross := (b - a).cross(c - a)
		if cross.dot(a + b + c) > 0.0:
			# Godot draws the side (b - a) x (c - a) points away from.
			var swap := b
			b = c
			c = swap
			cross = -cross
		var n := -cross.normalized()
		var base := rock.colour
		if rock.shape == RockMesh.Shape.VEINED:
			var d := (dirs[tris[t]] + dirs[tris[t + 1]] + dirs[tris[t + 2]]).normalized()
			base = SpacePalette.CRYSTAL if RockMesh.in_vein(d) else SpacePalette.ASH
		var colour := SpacePalette.shade(base, rng.randi_range(0, SpacePalette.SHADES.size() - 1))
		positions.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
		colours.append_array(PackedColorArray([colour, colour, colour]))
	faces.append_array(positions)

func _boulders(rock: AsteroidRock, rng: RandomNumberGenerator) -> void:
	var across := pow(rock.size.x * rock.size.y * rock.size.z, 1.0 / 3.0)
	var t := clampf((across - AsteroidRecipe.D_MIN[AsteroidRecipe.Tier.GIANT])
		/ (AsteroidRecipe.D_MAX[AsteroidRecipe.Tier.GIANT] - AsteroidRecipe.D_MIN[AsteroidRecipe.Tier.GIANT]), 0.0, 1.0)
	var count := roundi(lerpf(BOULDERS_MIN, BOULDERS_MAX, t))
	var scale := clampf(across / 400.0, 0.6, 1.3)
	var base := SpacePalette.ASH if rock.shape == RockMesh.Shape.VEINED else rock.colour
	var small: PackedInt32Array = RockMesh.sphere(0)[1]
	for i in count:
		var d := _random_direction(rng)
		var u := rng.randf()
		var diameter := lerpf(BOULDER_MIN, BOULDER_MAX, u * u) * scale
		var stretch := Vector3(rng.randf_range(AsteroidRecipe.STRETCH_MIN, AsteroidRecipe.STRETCH_MAX),
			rng.randf_range(AsteroidRecipe.STRETCH_MIN, AsteroidRecipe.STRETCH_MAX),
			rng.randf_range(AsteroidRecipe.STRETCH_MIN, AsteroidRecipe.STRETCH_MAX))
		var turn := Basis.from_euler(Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI)))
		var shape := RockMesh.Shape.BOULDER if rng.randf() < 0.55 else RockMesh.Shape.SHARD
		var colour := SpacePalette.shade(base, rng.randi_range(0, SpacePalette.SHADES.size() - 1))
		var surface := surface_point(d)
		var up := surface.normalized()
		# Keep the whole boulder inside the rock's bounds; shrink it to fit.
		var reach := AsteroidRecipe.BOUND * AsteroidRecipe.STRETCH_MAX
		var room := rock.radius - surface.length()
		diameter = minf(diameter, room / ((0.5 - BOULDER_SUNK) + reach))
		if diameter < BOULDER_MIN * 0.5:
			continue
		var centre := surface + up * diameter * (0.5 - BOULDER_SUNK)
		var basis := turn * Basis.from_scale(stretch * diameter)
		var place := Transform3D(basis, centre)
		boulders.append([place, shape, colour, diameter, d])
		var verts := RockMesh.cut_vertices(shape, 0)
		for k in range(0, small.size(), 3):
			faces.append_array(PackedVector3Array([place * verts[small[k]], place * verts[small[k + 1]],
				place * verts[small[k + 2]]]))

static func _random_direction(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		var l := v.length()
		if l > 0.2 and l <= 1.0:
			return v / l
	return Vector3.UP
