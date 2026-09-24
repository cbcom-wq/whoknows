extends GutTest

## Ships arrive stocked (hands-and-items spec §5.3): every stocked stow point
## gets its item once, rebuilds keep stowed items where they were, and an item
## whose stow point disappears comes loose.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func _items() -> Array:
	return _ship.items.get_children().filter(func(n): return n is Item)

func _with_id(id: StringName) -> Array:
	return _items().filter(func(i): return i.definition.id == id)

func test_items_live_under_the_interior():
	assert_eq(_ship.items.get_parent(), _ship.interior)
	assert_eq(String(_ship.items.name), "Items")

func test_every_stocked_point_holds_its_item():
	var stocked := 0
	for p in _ship.interior_builder.stow_points():
		if p.stock == &"":
			continue
		stocked += 1
		assert_false(p.is_free(), "%s is stocked" % p.stock)
		assert_eq(p.item.definition.id, p.stock)
		assert_eq(p.item.state, Item.State.STOWED)
	assert_gt(stocked, 0)
	assert_eq(_items().size(), stocked)

func test_the_weapon_rack_holds_two_plasma_pistols():
	assert_eq(_with_id(&"plasma_pistol").size(), 2)

func test_a_rebuild_neither_duplicates_nor_loses_items():
	var before := _items().size()
	_ship.set_grid(_ship.grid)
	assert_eq(_items().size(), before)
	for item in _items():
		assert_eq(item.state, Item.State.STOWED, "%s was re-seated" % item.name)
	for p in _ship.interior_builder.stow_points():
		if p.stock != &"":
			assert_false(p.is_free())

func test_a_stowed_item_whose_point_vanishes_comes_loose():
	var room := Vector3i.ZERO
	for coord in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"weapon_room":
			room = coord
	var deck := BlockInstance.new()
	deck.block_id = &"deck"
	_ship.grid.set_block(room, deck)
	var pistols := _with_id(&"plasma_pistol")
	assert_eq(pistols.size(), 2)
	for p in pistols:
		assert_eq(p.state, Item.State.LOOSE)
