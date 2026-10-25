extends GutTest

## FireControl (ship weapons spec §5.1): orders, a list of three in priority
## order, a target for each turret every 0.2 s -- the first it can engage,
## else the nearest hostile it can -- and entries that leave once gone.

class StubTurret extends Node3D:
	var target: Node3D
	var no_arc := false
	var state: StringName = &"idle"
	var reach: Array = []
	func can_engage(node: Node3D) -> bool:
		return reach.has(node)
	func muzzle() -> Vector3:
		return global_position

var _world: Node3D
var _fc: FireControl
var _ship: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_ship = Node3D.new()
	_ship.name = "Own"
	_world.add_child(_ship)
	_fc = FireControl.new()
	_fc.ship = _ship
	_world.add_child(_fc)

func after_each():
	Weapons.hostile_rule = Callable()

func _target(id: StringName, at := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	_world.add_child(n)
	n.global_position = at
	Weapons.join(n, id)
	return n

func _turret(reach: Array) -> StubTurret:
	var t := StubTurret.new()
	t.reach = reach
	_world.add_child(t)
	_fc.turrets.append(t)
	return t

func test_hold_gives_nothing():
	var a := _target(&"ship:A")
	var t := _turret([a])
	_fc.mark(&"ship:A")
	_fc.assign(0.2)
	assert_null(t.target, "a new ship holds fire")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_same(t.target, a)

func test_each_turret_takes_the_first_it_can_engage():
	var a := _target(&"ship:A")
	var b := _target(&"ship:B")
	var port := _turret([a, b])
	var starboard := _turret([b])
	_fc.mark(&"ship:A")
	_fc.mark(&"ship:B")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_same(port.target, a, "#1 where it can")
	assert_same(starboard.target, b, "#2 where #1 is out of its arc")

func test_marking_orders_the_list():
	for id in [&"ship:A", &"ship:B", &"ship:C"]:
		_fc.mark(id)
	assert_eq(_fc.list, [&"ship:A", &"ship:B", &"ship:C"] as Array[StringName], "in the order marked")
	_fc.mark(&"ship:D")
	assert_eq(_fc.list, [&"ship:A", &"ship:B", &"ship:D"] as Array[StringName], "a fourth takes the last place")
	_fc.mark(&"ship:B")
	assert_eq(_fc.list, [&"ship:B", &"ship:A", &"ship:D"] as Array[StringName], "marked again, to the top")

func test_its_own_ship_is_never_marked_or_shot():
	assert_false(_fc.mark(Weapons.ship_id(_ship)))
	var hull := _target(Weapons.ship_id(_ship))
	hull.set_meta(&"ship", _ship)
	var t := _turret([hull])
	_fc.list.append(Weapons.ship_id(_ship))
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_null(t.target)

func test_after_the_list_the_nearest_hostile():
	var near := _target(&"npc:a", Vector3(0, 0, -100))
	var far := _target(&"npc:b", Vector3(0, 0, -900))
	var t := _turret([near, far])
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_null(t.target, "nothing is hostile")
	Weapons.hostile_rule = func(_s: Node, n: Node) -> bool: return n == near or n == far
	_fc.assign(0.2)
	assert_same(t.target, near)

func test_a_freed_target_is_dropped_without_error():
	var a := _target(&"ship:A")
	var b := _target(&"ship:B")
	var t := _turret([a, b])
	_fc.mark(&"ship:A")
	_fc.mark(&"ship:B")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	a.free()
	_fc.assign(0.2)
	assert_same(t.target, b, "straight on to the next")
	for i in 8:
		_fc.assign(0.2)
	assert_true(_fc.list.has(&"ship:A"), "kept through its grace")
	_fc.assign(0.4)
	assert_false(_fc.list.has(&"ship:A"), "gone for 2 s: dropped")

func test_no_arc_when_engaged_with_nothing_it_can_reach():
	_target(&"ship:A")
	var t := _turret([])
	_fc.mark(&"ship:A")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	_fc.assign(0.2)
	assert_true(t.no_arc)

func test_mark_nearest_picks_inside_the_cone():
	_target(&"ship:Wide", Vector3(300, 0, -300))
	_target(&"ship:Ahead", Vector3(20, 0, -1000))
	assert_eq(_fc.mark_nearest(Vector3.ZERO, Vector3.FORWARD, WeaponValues.MARK_CONE, 5000.0), &"ship:Ahead")
	assert_eq(_fc.mark_nearest(Vector3.ZERO, Vector3.BACK, WeaponValues.MARK_CONE, 5000.0), &"")

func test_rotate_and_unmark():
	for id in [&"ship:A", &"ship:B", &"ship:C"]:
		_fc.mark(id)
	_fc.rotate_list()
	assert_eq(_fc.list, [&"ship:B", &"ship:C", &"ship:A"] as Array[StringName])
	_fc.unmark(&"ship:C")
	assert_eq(_fc.list, [&"ship:B", &"ship:A"] as Array[StringName])

func test_it_round_trips():
	_fc.mark(&"ship:A")
	_fc.mark(&"base:b1")
	_fc.set_orders(FireControl.Orders.ENGAGE)
	var again := FireControl.new()
	again.from_dict(_fc.to_dict())
	assert_eq(again.orders, FireControl.Orders.ENGAGE)
	assert_eq(again.list, [&"ship:A", &"base:b1"] as Array[StringName])
	again.free()
