extends GutTest

## The place field in the real flight scene (desert world phase 3): the oasis on
## p3 loads near you and frees far off, stands on the floor, holds its pool's
## water at its level, and follows the floating origin as one node.
##
## The starter is held (frozen) over the oasis rather than landed on the pad:
## nothing here is about touching down, only about where the place is.

var _root: Node
var _ship: Ship
var _universe: Universe
var _body: SystemBody
var _place: PlaceDesign
var _terrain: WorldTerrain

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	await wait_physics_frames(3)
	var system: SystemRecipe = _root.system
	_place = system.places()[0]
	_body = system.body(_place.body_id)
	_terrain = _root.star_system.whereabouts.terrain_of(_body)

## Holds the starter `height` m over the ground `east`, `north` m from the place.
func _hold_over(east: float, north: float, height: float) -> void:
	var d := _place.local_dir(east, north, _body.radius)
	var at := _body.point.plus(d * (_body.radius + _terrain.height_at(d) + height))
	_ship.exterior.freeze = true
	_ship.exterior.linear_velocity = Vector3.ZERO
	_ship.exterior.global_position = _universe.to_engine(at)
	await wait_physics_frames(3)

func _oasis() -> Node3D:
	return _root.places.loaded(&"oasis")

func test_the_oasis_loads_near_and_frees_far():
	await _hold_over(0, 0, 60.0)
	assert_not_null(_oasis(), "loaded at the place")
	assert_eq(_root.places.get_child_count(), 1, "one place")
	assert_eq(_oasis().name, &"Place_oasis")
	await _hold_over(7000, 0, 200.0)
	assert_not_null(_oasis(), "still there 7 km off")
	await _hold_over(11000, 0, 200.0)
	assert_null(_oasis(), "freed at 11 km")
	await wait_physics_frames(2)
	assert_eq(_root.places.get_child_count(), 0, "and gone from the tree")
	await _hold_over(0, 0, 60.0)
	assert_not_null(_oasis(), "back when you are")

func test_the_place_sits_on_the_ground():
	await _hold_over(0, 0, 60.0)
	var here := _universe.to_universe(_oasis().global_position).minus(_body.point)
	var floor_h := PlaceField.floor_height(_terrain, _place.dir())
	assert_almost_eq(here.length() - _body.radius, floor_h, 0.02, "on the oasis floor")
	assert_almost_eq(here.normalized().dot(_place.dir()), 1.0, 1e-6, "at the place")
	assert_true(_oasis().global_basis.is_equal_approx(_place.frame()), "in the place's frame")
	assert_lt(_terrain.height_at(_place.dir()), floor_h - 1.0, "the pool is dug under the floor")

func test_the_water_lies_at_its_level():
	await _hold_over(0, 0, 60.0)
	var mesh := _oasis().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var centre := _oasis().to_local(mesh.global_transform * mesh.get_aabb().get_center())
	assert_almost_eq(centre.y, -0.3, 0.01, "0.3 m under the floor")
	assert_eq(mesh.layers, 1, "drawn on the world's layer")
	assert_almost_eq(mesh.get_aabb().size.y, 0.0, 0.001, "flat")
	var radius := mesh.get_aabb().size.x * 0.5
	assert_between(radius, 14.0, 18.5, "about the pool's size")

func test_place_follows_a_shift():
	await _hold_over(0, 0, 60.0)
	var node := _oasis()
	var before := _universe.to_universe(node.global_position)
	var shift := Vector3(2000, 1000, -3000)
	_universe.shift(shift)
	assert_almost_eq(node.global_position, _universe.to_engine(before), Vector3.ONE * 0.001, "moved with the origin")
	var after := _universe.to_universe(node.global_position)
	assert_true(after.is_equal_approx(before), "the same point in the universe")
	assert_true(node.is_in_group(Universe.EXTERIOR_SPACE))

func test_only_the_place_is_a_member():
	await _hold_over(0, 0, 60.0)
	var count := 0
	for n in _oasis().find_children("*", "", true, false):
		count += 1
		assert_false(n.is_in_group(Universe.EXTERIOR_SPACE), "%s" % n.name)
		assert_false(n.is_in_group(Universe.HOLDS_SHIFT), "%s" % n.name)
	assert_gt(count, 2, "it has pieces")

func test_on_ground_is_in_the_places_frame_and_on_the_terrain():
	var pad := PlaceField.on_ground(_place, _terrain, -80.0, -40.0)
	var d := _place.local_dir(-80.0, -40.0, _body.radius)
	var from_centre := _place.frame() * pad + PlaceField.origin_of(_place, _terrain)
	assert_almost_eq(from_centre.length() - _body.radius, _terrain.height_at(d), 0.01)
	assert_almost_eq(pad.x, -80.0, 0.1)
	assert_almost_eq(pad.z, 40.0, 0.1)
	# The pad stands 0.15 m over its own level; the floor rolls, so that level is the
	# pad stamp's, not the bank's. The world curves about 0.18 m away at 90 m.
	var pad_over_bank := 0.15
	for s in _terrain.stamps:
		if s.id == &"pad":
			pad_over_bank += s.level
		elif s.id == &"pool_bank":
			pad_over_bank -= s.level
	assert_almost_eq(pad.y, pad_over_bank - 0.18, 0.2, "the pad, over the pool's bank less the curve at 90 m")

## The layout points of `key` in oasis.json: arrays of [east, north].
func _layout_points(key: String) -> Array:
	return _place.layout().get(key, [])

func test_palms_stand_on_the_ground():
	await _hold_over(0, 0, 60.0)
	var palms := _oasis().get_node("Palms") as StaticBody3D
	var points := _layout_points("palms")
	assert_eq(points.size(), 7, "seven palms")
	assert_eq(palms.get_child_count(), points.size(), "a trunk each")
	for i in points.size():
		var c := palms.get_child(i) as CollisionShape3D
		var shape := c.shape as CapsuleShape3D
		var foot := c.transform.origin - c.transform.basis.y * shape.height * 0.5
		var want := PlaceField.on_ground(_place, _terrain, float(points[i][0]), float(points[i][1]))
		assert_lt(foot.distance_to(want), 0.05, "palm %d's foot is on the ground" % i)

func test_palm_trunks_are_solid():
	await _hold_over(0, 0, 60.0)
	var palms := _oasis().get_node("Palms") as StaticBody3D
	assert_eq(palms.collision_layer, BodyProxy.LAYER, "on the terrain's layer")
	var at: Array = _layout_points("palms")[3]
	var foot := PlaceField.on_ground(_place, _terrain, float(at[0]), float(at[1]))
	var from := _oasis().to_global(foot + Vector3(-4.0, 1.2, 0.0))
	var to := _oasis().to_global(foot + Vector3(4.0, 1.2, 0.0))
	var query := PhysicsRayQueryParameters3D.create(from, to, BodyProxy.LAYER)
	var hit := _oasis().get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "a ray at chest height hits something")
	if not hit.is_empty():
		assert_eq(hit["collider"], palms, "the palms")
		assert_lt(_oasis().to_local(hit["position"]).distance_to(foot + Vector3(0, 1.2, 0)), 0.7, "at the trunk")

func test_the_green_ring_and_the_village_pieces_are_one_kit_and_one_multimesh():
	await _hold_over(0, 0, 60.0)
	var meshes := _oasis().find_children("*", "MultiMeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, "one MultiMesh for all the grass")
	var village := _oasis().get_node("Village")
	var solids := village.get_children().filter(func(n): return n is MeshInstance3D and n.name == &"DressingSolid")
	assert_eq(solids.size(), 1, "one kit's solids")

func test_the_grass_stays_out_of_the_water():
	await _hold_over(0, 0, 60.0)
	var ring := _oasis().find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
	var pool := _oasis().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var edge := pool.get_aabb().size.x * 0.5
	var tufts: PackedVector3Array = ring.get_meta(&"tufts")
	assert_gt(tufts.size(), 500)
	for i in tufts.size():
		var at := tufts[i]
		assert_gt(Vector2(at.x, at.z).length(), edge - PlaceField.SHORE_LAP + 1.5 - 0.01, "tuft %d" % i)
