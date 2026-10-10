extends GutTest

## A big rock as ground (habitat modules spec §5.1), on the start's rock.

var _root: Node
var _rock: AsteroidDetail

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	var stream: AsteroidStream = _root.get_node("AsteroidStream")
	_rock = stream.details.nearest(_root.get_node("Ship").exterior.global_position)

func test_the_start_rock_is_ground():
	assert_not_null(_rock, "the start's rock is in detail")
	var s := RockSurface.new(_rock)
	assert_true(s.fixed())
	assert_eq(s.site_id(), RockHerds.site_of(_rock.rock))
	var toward: Vector3 = (_rock.global_position - _root.get_node("Ship").exterior.global_position).normalized()
	var from: Vector3 = _root.get_node("Ship").exterior.global_position
	await wait_physics_frames(2)
	var hit := s.cast(from, toward, 2000.0)
	assert_false(hit.is_empty(), "a ray toward the rock lands on it")
	var up := s.up_at(hit["position"])
	assert_gt(up.dot(-toward), 0.0, "its up points back out")
	var high := Transform3D(Basis.IDENTITY, hit["position"] + up * 20.0)
	assert_false(s.blocked(high, Vector3(6, 4, 4)), "20 m out is clear")
	var low := Transform3D(Basis.IDENTITY, hit["position"] - up * 3.0)
	assert_true(s.blocked(low, Vector3(6, 4, 4)), "half in the rock is blocked")
