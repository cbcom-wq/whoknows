extends GutTest

## DestroyObjective (hostile ships spec §5.5): fight the target while it is in
## contact, pursue it for a minute when it leaves, give up after that; if it is
## destroyed or freed, take the nearest crew ship in contact, else hold station.
## Light hulls in Weapons.TARGETS, each with a bare Ship for its side.

var _root: Node3D
var _target: Node3D
var _from := Vector3(100.0, -50.0, 20.0)

func before_each():
	_root = Node3D.new()
	add_child_autofree(_root)
	_target = _hull(&"A", Sides.CREW, _from + Vector3(0, 0, -2000.0))

## A hull standing for ship `name`: in TARGETS as ship:<name>, its ship on `side`.
func _hull(name: StringName, side: StringName, at: Vector3) -> Node3D:
	var ship: Ship = autofree(Ship.new())
	ship.name = String(name)
	ship.side = side
	var hull := Node3D.new()
	hull.set_meta(&"ship", ship)
	_root.add_child(hull)
	hull.global_position = at
	Weapons.join(hull, Weapons.ship_id(ship))
	return hull

func _objective() -> DestroyObjective:
	var o := DestroyObjective.new(&"ship:A")
	o.to_universe = func(p: Vector3) -> UniversePoint: return UniversePoint.at(5000, 0, 0).plus(p)
	return o

func test_fights_while_in_contact():
	var o := _objective()
	o.step(_from, get_tree(), 0.2)
	assert_eq(o.target_id(), &"ship:A")
	assert_eq(o.target(get_tree(), _from), _target)
	assert_false(o.pursuing())
	assert_false(o.done())
	var seen := o.last_seen()
	assert_almost_eq(seen["dir"], Vector3(0, 0, -1), Vector3.ONE * 0.001, "toward it")
	assert_eq(seen["speed"], Vector3.ZERO)
	var at: UniversePoint = seen["at"]
	assert_true(at.is_equal_approx(UniversePoint.at(5000, 0, 0).plus(_target.global_position)),
		"where it was, as a universe point")

func test_pursues_out_of_contact_then_gives_up():
	var o := _objective()
	o.step(_from, get_tree(), 0.2)
	_target.global_position = _from + Vector3(6000.0, 0, 0)
	o.step(_from, get_tree(), 0.2)
	assert_null(o.target(get_tree(), _from), "past contact range")
	assert_true(o.pursuing())
	assert_almost_eq(o.last_seen()["dir"], Vector3(0, 0, -1), Vector3.ONE * 0.001,
		"it keeps the last direction it saw")
	for i in 59:
		o.step(_from, get_tree(), 1.0)
	assert_false(o.done(), "about 59 s out of contact")
	o.step(_from, get_tree(), 1.0)
	o.step(_from, get_tree(), 1.0)
	assert_true(o.done(), "61 s: it gives up")
	assert_false(o.pursuing(), "and stops pursuing")

func test_contact_again_resets_the_clock():
	var o := _objective()
	o.step(_from, get_tree(), 0.2)
	_target.global_position = _from + Vector3(6000.0, 0, 0)
	for i in 50:
		o.step(_from, get_tree(), 1.0)
	_target.global_position = _from + Vector3(4000.0, 0, 0)
	o.step(_from, get_tree(), 1.0)
	assert_false(o.pursuing(), "back in contact")
	assert_almost_eq(o.last_seen()["dir"], Vector3(1, 0, 0), Vector3.ONE * 0.001)
	_target.global_position = _from + Vector3(6000.0, 0, 0)
	for i in 50:
		o.step(_from, get_tree(), 1.0)
	assert_true(o.pursuing())
	assert_false(o.done(), "50 s since contact, not 100")

func test_a_given_up_target_is_engaged_again_in_contact():
	var o := _objective()
	o.step(_from, get_tree(), 0.2)
	_target.global_position = _from + Vector3(6000.0, 0, 0)
	for i in 61:
		o.step(_from, get_tree(), 1.0)
	assert_true(o.done())
	_target.global_position = _from + Vector3(3000.0, 0, 0)
	o.step(_from, get_tree(), 0.2)
	assert_false(o.done(), "still hostile: it engages again within 5 km (spec §5.5)")
	assert_false(o.pursuing())
	assert_eq(o.target_id(), &"ship:A")

func test_a_freed_target_is_let_go():
	var other := _hull(&"B", Sides.CREW, _from + Vector3(0, 3000.0, 0))
	var far := _hull(&"C", Sides.CREW, _from + Vector3(0, -4000.0, 0))
	var o := _objective()
	o.step(_from, get_tree(), 0.2)
	_target.free()
	o.step(_from, get_tree(), 0.2)
	assert_eq(o.target_id(), &"ship:B", "the nearest crew ship in contact")
	assert_false(o.done())
	assert_false(o.pursuing())
	assert_eq(o.target(get_tree(), _from), other)
	assert_almost_eq(o.last_seen()["dir"], Vector3(0, 1, 0), Vector3.ONE * 0.001)
	other.free()
	far.free()
	o.step(_from, get_tree(), 0.2)
	assert_true(o.done(), "nobody left in contact: it holds station")
	assert_null(o.target(get_tree(), _from))
	o.step(_from, get_tree(), 0.2)
	assert_true(o.done(), "and stepping on is quiet")

func test_a_freed_target_with_nobody_else_is_done():
	var o := _objective()
	o.step(_from, get_tree(), 0.2)
	_target.free()
	o.step(_from, get_tree(), 0.2)
	assert_true(o.done())
	assert_false(o.pursuing())

func test_never_retargets_a_hostile():
	_hull(&"H", Sides.HOSTILE, _from + Vector3(0, 0, 1000.0))
	var o := _objective()
	o.step(_from, get_tree(), 0.2)
	_target.free()
	assert_false(o.retarget(get_tree(), _from))
	o.step(_from, get_tree(), 0.2)
	assert_true(o.done(), "the only other ship is hostile")

func test_round_trips():
	var o := _objective()
	o.step(_from, get_tree(), 0.2)
	_target.global_position = _from + Vector3(6000.0, 0, 0)
	o.step(_from, get_tree(), 12.5)
	var back := PilotObjective.from_dict(JSON.parse_string(JSON.stringify(o.to_dict())))
	assert_true(back is DestroyObjective)
	assert_eq(back.target_id(), &"ship:A")
	assert_true(back.pursuing())
	assert_false(back.done())
	assert_almost_eq(back.last_seen()["dir"], Vector3(0, 0, -1), Vector3.ONE * 0.001)
	var at: UniversePoint = back.last_seen()["at"]
	assert_true(at.is_equal_approx(o.last_seen()["at"]))
	back.step(_from, get_tree(), PilotValues.PURSUE_FOR - 12.5 - 1.0)
	assert_false(back.done(), "the clock came back")
	back.step(_from, get_tree(), 2.0)
	assert_true(back.done())
	assert_null(PilotObjective.from_dict({"kind": "nonsense"}), "an unknown kind reads as none")
