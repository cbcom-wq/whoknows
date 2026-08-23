class_name DebrisField
extends MultiMeshInstance3D

## Scatters a fixed field of low-poly rocks through the exterior arena, so
## the hull has something to fly past. Added after the Phase A walkthrough
## found that flight is invisible: stars sit at infinity and never
## parallax, so flying past nothing looks exactly like sitting still.
##
## Deterministic from `seed` alone -- same seed, same field, every run, so
## a tester comparing two sessions is comparing the same debris, not two
## different random draws.
##
## No collision: these exist to be looked at, not flown into. A hull that
## clips a rock at 100 m/s during a feel test teaches nothing except
## annoyance -- Slice 2 is where debris impacts get interesting.
## MultiMeshInstance3D carries no collision shape of its own, so this is
## true by construction; nothing here adds one.
##
## Render layer 1 (exterior) only, so the directional light lights these
## and the interior practicals (layer 2, 5 km away besides) never can.

## Rock diameter range in metres. _build_rock_mesh() below builds a base
## mesh with a true unit diameter (vertices at radius ~0.5, not ~1 -- see
## its own comment), so the per-instance uniform scale applied to it in
## _build_multimesh() equals this directly. Measured, not assumed: see
## task-6c-report.md for the built mesh's actual AABB at both ends.
const MIN_ROCK_METRES := 5.0
const MAX_ROCK_METRES := 40.0

## Nothing scatters closer to the field's centre than this. `Ship.exterior`
## spawns at the world origin (Task 2), so keeping this clearance around
## the origin -- comfortably past the hull's half-diagonal (~7.3 m for the
## 8x4x12 box) plus the largest possible rock radius (MAX_ROCK_METRES / 2 =
## 20 m) -- keeps a rock from ever landing on top of the ship at spawn.
const CLEARANCE_METRES := 80.0

## How much the base rock shape's vertices are pushed in/out from a unit
## sphere, so the shared mesh reads as an irregular rock rather than a
## faceted ball.
const ROCK_JITTER := 0.35

@export var seed: int = 1337
@export var count: int = 700
@export var radius: float = 1500.0

func _ready() -> void:
	layers = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	multimesh = _build_multimesh(rng)

func _build_multimesh(rng: RandomNumberGenerator) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _build_rock_mesh(rng)
	mm.instance_count = count
	for i in count:
		var position := _scatter_point(rng)
		var rotation := Basis.from_euler(Vector3(
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)
		))
		var rock_scale := rng.randf_range(MIN_ROCK_METRES, MAX_ROCK_METRES)
		mm.set_instance_transform(i, Transform3D(rotation.scaled(Vector3.ONE * rock_scale), position))
	return mm

## Uniform-in-a-sphere via rejection sampling (reject points outside the
## unit ball, then scale by `radius`), with `CLEARANCE_METRES` rejected
## around the centre so nothing spawns on the hull. The rejection rate is
## the clearance sphere's tiny share of the unit ball's volume, so this
## resolves in a handful of iterations in practice; the bounded loop (with
## a logged fallback) is only there so a misconfigured `radius` smaller
## than `CLEARANCE_METRES` fails loudly instead of hanging forever.
func _scatter_point(rng: RandomNumberGenerator) -> Vector3:
	for _attempt in 10000:
		var p := Vector3(
			rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)
		)
		if p.length_squared() > 1.0:
			continue
		var point := p * radius
		if point.length() < CLEARANCE_METRES:
			continue
		return point
	push_error("DebrisField: radius %f leaves no room outside CLEARANCE_METRES %f" % [radius, CLEARANCE_METRES])
	return Vector3(radius, 0.0, 0.0)

## One low-poly rock, shared by every instance via MultiMesh: a
## unit-diameter icosahedron with each vertex's radius jittered outward or
## inward, built with hard per-face normals (three unique vertices per
## triangle, all sharing that triangle's own normal) so it renders
## flat-shaded with hard edges -- the same look Task 6b's interior shell
## uses, no textures.
func _build_rock_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var corners := [
		Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1),
	]
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]

	# 0.5 so the base shape's diameter (not radius) is ~1: MIN/MAX_ROCK_METRES
	# are a diameter range, and the per-instance scale in _build_multimesh()
	# is applied directly to this mesh, so a unit-diameter base makes that
	# scale equal the rock's final diameter in metres -- verified by
	# measuring the built mesh's AABB, not assumed (task-6c-report.md).
	var jittered: Array[Vector3] = []
	for corner in corners:
		var jitter := 1.0 + rng.randf_range(-ROCK_JITTER, ROCK_JITTER)
		jittered.append(corner.normalized() * jitter * 0.5)

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	for face in faces:
		var a: Vector3 = jittered[face[0]]
		var b: Vector3 = jittered[face[1]]
		var c: Vector3 = jittered[face[2]]
		var face_normal := (b - a).cross(c - a).normalized()
		positions.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([face_normal, face_normal, face_normal]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _rock_material())
	return mesh

func _rock_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.2, 0.19)
	mat.roughness = 1.0
	return mat
