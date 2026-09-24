extends GutTest

## ThrusterFlame: how big a flame is at a given throttle, and the one mesh
## every flame draws from.

func test_no_throttle_no_flame():
	assert_eq(ThrusterFlame.size_for(0.0), Vector2.ZERO)
	assert_eq(ThrusterFlame.size_for(-1.0), Vector2.ZERO, "a negative share is no thrust")

func test_the_flame_grows_with_throttle():
	var last := Vector2.ZERO
	for throttle in [0.1, 0.25, 0.5, 1.0, FlightComputer.BOOST_MULTIPLIER]:
		var size := ThrusterFlame.size_for(throttle)
		assert_gt(size.x, last.x, "longer at throttle %s" % throttle)
		assert_gt(size.y, last.y, "wider at throttle %s" % throttle)
		last = size

func test_boost_stretches_the_flame_well_past_full_throttle():
	var full := ThrusterFlame.size_for(1.0)
	var boost := ThrusterFlame.size_for(FlightComputer.BOOST_MULTIPLIER)
	assert_gt(boost.x, full.x * 1.4, "boost reads as a much longer flame")

## The shader only shrinks the mesh, so it must stay within the size it was
## authored at -- the bounds culling uses.
func test_the_flame_never_outgrows_its_mesh():
	var huge := ThrusterFlame.size_for(1000.0)
	assert_true(huge.x <= 1.0 and huge.y <= 1.0, "size %s" % huge)

func test_every_flame_shares_one_mesh():
	assert_same(ThrusterFlame.mesh(), ThrusterFlame.mesh())

func test_the_mesh_is_a_plume_and_a_core_in_the_flame_material():
	var mesh := ThrusterFlame.mesh()
	assert_eq(mesh.get_surface_count(), 1)
	var material := mesh.surface_get_material(0) as ShaderMaterial
	assert_not_null(material)
	assert_eq(material.shader.resource_path, "res://data/materials/thruster_flame.gdshader")
	var shells := {}
	for uv in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
		shells[uv.x] = true
	assert_eq(shells.keys().size(), 2, "every vertex is on the plume (0) or the core (1)")

func test_the_mesh_points_aft_from_the_nozzle():
	var arrays := ThrusterFlame.mesh().surface_get_arrays(0)
	for v in arrays[Mesh.ARRAY_VERTEX]:
		assert_between(v.z, -0.0001, ThrusterFlame.MAX_LENGTH + 0.0001)
	var aabb := ThrusterFlame.mesh().get_aabb()
	assert_almost_eq(aabb.position.z, 0.0, 0.0001, "the flame starts at the nozzle")
	assert_almost_eq(aabb.end.z, ThrusterFlame.MAX_LENGTH, 0.0001)

## An inside-out flame still draws, just wrongly, so nothing else would catch
## it. Rebuild the same triangles with no normals and let Godot derive them
## from the winding: they must point the same way as the mesh's own.
func test_the_mesh_faces_outward():
	var arrays := ThrusterFlame.mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # flat: each triangle's normal comes from its own winding
	for v in vertices:
		st.add_vertex(v)
	st.generate_normals()
	var derived: PackedVector3Array = st.commit_to_arrays()[Mesh.ARRAY_NORMAL]
	var disagreeing := 0
	for i in vertices.size():
		# Degenerate tip triangles have no winding to derive from.
		if derived[i].length_squared() > 0.5 and derived[i].dot(normals[i]) < 0.0:
			disagreeing += 1
	assert_eq(disagreeing, 0, "faces wound against their normals")
