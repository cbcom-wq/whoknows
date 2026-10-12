extends GutTest

## What turrets may shoot (ship weapons spec §4): the TARGETS group, the ids,
## where a target is and how it moves, and what is never one.

var _world: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)

func after_each():
	Weapons.hostile_rule = Callable()

func _body(id: StringName, at := Vector3.ZERO) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.gravity_scale = 0.0
	_world.add_child(b)
	b.global_position = at
	Weapons.join(b, id)
	return b

func test_join_find_and_leave():
	var b := _body(&"ship:Ship2")
	assert_eq(Weapons.id_of(b), &"ship:Ship2")
	assert_same(Weapons.find(get_tree(), &"ship:Ship2"), b)
	Weapons.leave(b)
	assert_null(Weapons.find(get_tree(), &"ship:Ship2"))

func test_a_freed_target_is_not_found():
	var b := _body(&"item:1")
	b.free()
	assert_null(Weapons.find(get_tree(), &"item:1"))

func test_kinds():
	assert_eq(Weapons.kind_of(&"ship:Ship2"), &"ship")
	assert_eq(Weapons.kind_of(&"npc:skitter:rock:3"), &"npc")
	assert_eq(Weapons.kind_of(&"nothing"), &"")

func test_where_a_body_is_and_how_it_moves():
	var b := _body(&"item:2", Vector3(5, 0, 0))
	b.linear_velocity = Vector3(0, 3, 0)
	assert_almost_eq(Weapons.point_of(b), Vector3(5, 0, 0), Vector3.ONE * 0.001)
	assert_almost_eq(Weapons.velocity_of(b), Vector3(0, 3, 0), Vector3.ONE * 0.001)
	b.freeze = true
	assert_eq(Weapons.velocity_of(b), Vector3.ZERO, "a base stands still")

func test_own_and_hostile():
	var ship := Node.new()
	add_child_autofree(ship)
	var hull := _body(&"ship:A")
	hull.set_meta(&"ship", ship)
	assert_true(Weapons.is_own(ship, hull))
	assert_false(Weapons.is_own(ship, _body(&"ship:B")))
	assert_false(Weapons.is_hostile(hull), "nothing is hostile in this project")
	Weapons.hostile_rule = func(n: Node) -> bool: return n == hull
	assert_true(Weapons.is_hostile(hull))

func test_an_item_outside_is_a_target_and_aboard_is_not():
	var d := ItemDefinition.new()
	d.id = &"crate"
	d.display_name = "Crate"
	d.size = Vector3(0.5, 0.5, 0.5)
	d.look = &"crate"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.set_space(true)
	assert_true(item.is_in_group(Weapons.TARGETS))
	assert_eq(Weapons.kind_of(Weapons.id_of(item)), &"item")
	assert_eq(Weapons.label_of(item), "CRATE")
	item.set_space(false)
	assert_false(item.is_in_group(Weapons.TARGETS))

func test_target_contacts_lists_other_ships_in_range():
	var universe := Universe.new()
	_world.add_child(universe)
	var own := _body(&"ship:Own")
	var near := _body(&"ship:Near", Vector3(0, 0, -800))
	_body(&"ship:Far", Vector3(0, 0, -9000))
	_body(&"item:9", Vector3(0, 0, -50))
	var source := TargetContacts.new(own, universe)
	var found := source.contacts(universe.to_universe(Vector3.ZERO), 10000.0, 0.0)
	assert_eq(found.size(), 1, "only the near ship: not itself, not past 5 km, not an item")
	if found.size() == 1:
		assert_eq(found[0].id, &"ship:Near")
		assert_eq(found[0].kind, &"ship")
	assert_not_null(source.contact(&"ship:Near", universe.to_universe(Vector3.ZERO), 0.0))
	assert_null(source.contact(&"ship:Own", universe.to_universe(Vector3.ZERO), 0.0))
	near.free()
