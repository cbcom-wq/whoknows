extends GutTest

## StowPoint (hands-and-items spec §5.1): secures one item of its class, base
## down on its origin, frozen so no burn can move it.

func _item(stow_class := &"small") -> Item:
	var d := ItemDefinition.new()
	d.id = &"thing"
	d.display_name = "Thing"
	d.size = Vector3(0.1, 0.2, 0.1)
	d.stow_class = stow_class
	d.look = &"crate"
	var item := Item.new()
	item.setup(d)
	add_child_autofree(item)
	return item

func _point(accepts := &"small") -> StowPoint:
	var p := StowPoint.new()
	p.accepts = accepts
	add_child_autofree(p)
	return p

func test_joins_the_stow_point_group():
	assert_true(_point().is_in_group(StowPoint.GROUP))

func test_accepts_only_its_class():
	var p := _point(&"sidearm")
	assert_false(p.fits(_item(&"small")))
	assert_true(p.fits(_item(&"sidearm")))

func test_holds_one_item():
	var p := _point()
	p.secure(_item())
	assert_false(p.is_free())
	assert_false(p.fits(_item()))

func test_secure_puts_the_items_base_on_the_point():
	var p := _point()
	p.position = Vector3(1, 2, 3)
	p.rotation = Vector3(0, 0.5, 0)
	var item := _item()
	p.secure(item)
	assert_almost_eq(item.global_position, p.global_transform * Vector3(0, 0.1, 0), Vector3.ONE * 0.0001)
	assert_true(item.global_basis.is_equal_approx(p.global_basis))
	assert_eq(item.state, Item.State.STOWED)
	assert_true(item.freeze)
	assert_eq(item.stow_point, p)

func test_release_lets_it_loose():
	var p := _point()
	var item := _item()
	p.secure(item)
	assert_eq(p.release(), item)
	assert_eq(item.state, Item.State.LOOSE)
	assert_false(item.freeze)
	assert_true(p.is_free())

func test_a_freed_item_frees_its_point():
	var p := _point()
	var item := Item.new()
	var d := ItemDefinition.new()
	d.look = &"crate"
	item.setup(d)
	add_child(item)
	p.secure(item)
	remove_child(item)
	item.free()
	assert_true(p.is_free())
