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

func test_the_readout_starts_hidden():
	var label := _root.get_node_or_null("Prompt/UniverseReadout") as Label
	assert_not_null(label)
	if label != null:
		assert_false(label.visible)
