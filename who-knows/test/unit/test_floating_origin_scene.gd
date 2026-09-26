extends GutTest

## The floating origin in the real flight scene (docs/superpowers/specs/
## 2026-09-24-asteroids-design.md §4): who it follows, what it moves, and the
## rule that everything outside is covered.

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _universe: Universe
var _outside: Node3D

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_universe = _root.get_node_or_null("Universe") as Universe
	_outside = _root.get_node("Outside")

func _out(at: Vector3) -> void:
	_avatar.enter_suit(_outside, Transform3D(Basis.IDENTITY, at), Vector3.ZERO, _ship.exterior)

func _back_in() -> void:
	_avatar.enter_plating(_ship.interior, Transform3D(Basis.IDENTITY, _ship.interior.to_global(Vector3(0, -0.95, 6))),
		0.0, Vector3.ZERO, Quaternion.IDENTITY)

## A node is covered if it, or something above it, is shifted.
func _covered(node: Node) -> bool:
	while node != null:
		if node.is_in_group(Universe.EXTERIOR_SPACE):
			return true
		node = node.get_parent()
	return false

func _uncovered() -> Array:
	var out := []
	for n in _root.find_children("*", "Node3D", true, false):
		if not (n is PhysicsBody3D or n is GeometryInstance3D):
			continue
		if _ship.interior.is_ancestor_of(n):
			continue
		if not _covered(n):
			out.append(str(_root.get_path_to(n)))
	return out

func test_the_universe_survived_the_parse():
	assert_true(_universe is Universe, "FlightTest/Universe is a Universe")

func test_aboard_the_focus_is_the_hull():
	assert_eq(_universe.focus, _ship.exterior)
	assert_true(_ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))

func test_on_a_spacewalk_the_focus_is_you_and_back_aboard_the_hull():
	_out(Vector3(0, 0, 12))
	assert_eq(_universe.focus, _avatar)
	assert_true(_avatar.is_in_group(Universe.EXTERIOR_SPACE))
	_back_in()
	assert_eq(_universe.focus, _ship.exterior)
	assert_false(_avatar.is_in_group(Universe.EXTERIOR_SPACE), "aboard, you never move")

func test_a_shift_moves_the_hull_and_leaves_the_interior():
	var interior_at := _ship.interior.global_position
	var avatar_at := _avatar.global_position
	_ship.exterior.global_position = Vector3(2500, 0, -40)
	assert_true(_universe.check())
	assert_eq(_ship.exterior.global_position, Vector3(-500, 0, -40))
	assert_eq(_ship.interior.global_position, interior_at)
	assert_eq(_avatar.global_position, avatar_at)

func test_a_spacewalk_across_a_shift_keeps_you_beside_your_ship():
	_ship.exterior.global_position = Vector3(0, 0, -2490)
	_out(Vector3(3, 1, -2478))
	var offset := _avatar.global_position - _ship.exterior.global_position
	_avatar.global_position += Vector3(0, 0, -20)
	offset += Vector3(0, 0, -20)
	assert_true(_universe.check())
	assert_almost_eq(_avatar.global_position - _ship.exterior.global_position, offset, Vector3.ONE * 0.0001)

func test_everything_outside_is_covered():
	assert_eq(_uncovered(), [], "every body and mesh outside the interior shifts")

func test_everything_outside_is_covered_on_a_spacewalk():
	_out(Vector3(0, 0, 12))
	assert_eq(_uncovered(), [])

func _salvage() -> SalvageField:
	return _outside.get_node_or_null("SalvageField") as SalvageField

## Quantum energy spec §10.1, §10.2: the near cloud is out behind the stern
## from the first frame, each item a member of its own under a field that is
## never moved and never a member, so the walk below covers them.
func test_the_near_cloud_is_loaded_behind_the_stern_from_the_start():
	var field := _salvage()
	assert_not_null(field, "Outside/SalvageField")
	if field == null:
		return
	assert_false(field.is_in_group(Universe.EXTERIOR_SPACE))
	assert_eq(field.global_transform, Transform3D.IDENTITY)
	var items := field.loaded_items(SalvageField.NEAR)
	assert_eq(items.size(), 12)
	var hatch: Transform3D = (_ship.airlocks.values()[0] as Airlock).alcove.outer_hatch.global_transform
	for item in items:
		assert_true(item.is_in_group(Universe.EXTERIOR_SPACE))
		var aft := _ship.exterior.global_transform.affine_inverse() * item.global_position \
			- _ship.exterior.global_transform.affine_inverse() * hatch.origin
		assert_between(aft.z, 12.0, 40.0, "%s is aft of the stern" % item.name)
	assert_eq(_uncovered(), [], "and every one of them is covered")

func test_a_shift_moves_the_salvage_with_the_hull():
	var items := _salvage().loaded_items(SalvageField.NEAR)
	assert_eq(items.size(), 12)
	_ship.exterior.global_position = Vector3(2500, 0, -40)
	var offsets := items.map(func(i: Item) -> Vector3: return i.global_position - _ship.exterior.global_position)
	assert_true(_universe.check())
	for k in items.size():
		assert_almost_eq(items[k].global_position - _ship.exterior.global_position, offsets[k], Vector3.ONE * 0.001)
	assert_eq(_salvage().global_transform, Transform3D.IDENTITY)

func test_the_readout_starts_hidden():
	var label := _root.get_node_or_null("Prompt/UniverseReadout") as Label
	assert_not_null(label)
	if label != null:
		assert_false(label.visible)

func test_the_hull_and_a_spacewalker_touch_rocks():
	assert_true(_ship.exterior.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_eq(_ship.exterior.collision_mask, 1 | 64)
	assert_true(_ship.exterior.continuous_cd)
	assert_gt(float(_ship.exterior.get_meta(AsteroidStream.ANCHOR_RADIUS)), 7.0)
	_out(Vector3(0, 0, 12))
	assert_true(_avatar.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_eq(_avatar.collision_mask, 1 | 32 | 64)
	_back_in()
	assert_false(_avatar.is_in_group(AsteroidStream.SPACE_ANCHOR))

func test_the_cameras_outside_see_as_far_as_rocks_are_drawn():
	# Godot's default is 4 km: past that, no big rock was ever drawn.
	var far := AsteroidStream.FADE_END[AsteroidRecipe.Tier.GIANT]
	for path in ["Ship/Exterior/ChaseCamera", "Ship/Canopy/CanopyCam"]:
		assert_gte((_root.get_node(path) as Camera3D).far, far, path)
	assert_gte(_avatar.camera.far, far, "on a spacewalk")

func test_the_sun_throws_shadows_far_enough_to_shape_a_big_rock():
	var sun: DirectionalLight3D = _root.get_node("DirectionalLight3D")
	assert_gte(sun.directional_shadow_max_distance, AsteroidStream.SHADOW_REACH)

