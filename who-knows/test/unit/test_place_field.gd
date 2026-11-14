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
