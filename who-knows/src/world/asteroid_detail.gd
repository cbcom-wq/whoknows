class_name AsteroidDetail
extends StaticBody3D

## A big rock up close (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §18): drawn in detail -- fine facets, craters, boulders -- and solid exactly
## as drawn, so you can fly into a crater or bump a boulder on a spacewalk.
## Fixed where it is: a big rock barely moved when rammed, and fixed, its
## collision can follow every hollow.

var rock: AsteroidRock
var data: RockDetail

## Becomes `p_rock` in detail, from `p_data` built on a worker. `material`
## takes its colours from the vertices (and the boulders' instance colours).
func setup(p_rock: AsteroidRock, p_data: RockDetail, material: Material) -> void:
	rock = p_rock
	data = p_data
	var id := rock.id()
	name = "BigRock_%d_%d_%d_%d" % [id.x, id.y, id.z, id.w]
	collision_layer = AsteroidBody.LAYER
	collision_mask = 0
	add_to_group(Universe.EXTERIOR_SPACE)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.positions
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var look := MeshInstance3D.new()
	look.name = "Look"
	look.mesh = mesh
	look.material_override = material
	look.layers = 1
	add_child(look)
	for shape in [RockMesh.Shape.BOULDER, RockMesh.Shape.SHARD]:
		var mine := data.boulders.filter(func(b: Array) -> bool: return b[1] == shape)
		if mine.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = RockMesh.mesh(shape, 1)
		mm.instance_count = mine.size()
		for i in mine.size():
			mm.set_instance_transform(i, mine[i][0])
			mm.set_instance_color(i, mine[i][2])
		var boulders := MultiMeshInstance3D.new()
		boulders.name = "Boulders%d" % shape
		boulders.multimesh = mm
		boulders.material_override = material
		boulders.layers = 1
		add_child(boulders)
	var hull := ConcavePolygonShape3D.new()
	hull.set_faces(data.faces)
	var solid := CollisionShape3D.new()
	solid.name = "Solid"
	solid.shape = hull
	add_child(solid)
