extends GutTest

## Items break (ship weapons spec §6.6): enough hits and a loose item bursts
## and is gone, through Item.consume, so the salvage ledger and the strays let
## it go; tools and packages never break; what it took is saved.

var _world: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)

func _item(unbreakable := false) -> Item:
	var d := ItemDefinition.new()
	d.id = &"crate"
	d.display_name = "Crate"
	d.size = Vector3(0.5, 0.5, 0.5)
	d.look = &"crate"
	d.unbreakable = unbreakable
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.set_loose()
	return item

func _hit(amount: float) -> Hit:
	var h := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.DOWN, Vector3.ZERO, null)
	h.damage = amount
	return h

func test_three_light_bolts_break_a_crate():
	var item := _item()
	var gone := []
	item.consumed.connect(func() -> void: gone.append(1))
	item.receive_hit(_hit(15.0))
	item.receive_hit(_hit(15.0))
	assert_true(is_instance_valid(item))
	item.receive_hit(_hit(15.0))
	assert_eq(gone.size(), 1, "consumed: the ledger and the strays let it go")
	assert_null(item.get_parent(), "out of the world at once")
	assert_true(item.is_queued_for_deletion())
	item.receive_hit(_hit(15.0))
	assert_eq(gone.size(), 1, "a broken item breaks once")
	await wait_frames(2)
	assert_false(is_instance_valid(item))

func test_an_unbreakable_item_takes_nothing():
	var item := _item(true)
	for i in 10:
		item.receive_hit(_hit(50.0))
	assert_true(is_instance_valid(item))
	assert_eq(item.damage_taken, 0.0)

func test_a_stowed_item_takes_nothing():
	var item := _item()
	item.set_stowed(null)
	item.receive_hit(_hit(100.0))
	assert_true(is_instance_valid(item))

func test_the_tools_and_packages_are_unbreakable():
	var cat := ItemCatalog.load_from_dir("res://data/items")
	for id in [&"plasma_pistol", &"repair_torch", &"datapad", &"hose_nozzle", &"hub_package", &"drill_package",
			&"store_package"]:
		var def := cat.get_def(id)
		assert_true(def != null and (def.unbreakable or def.eva_tool), "%s never breaks" % id)
	assert_almost_eq(cat.get_def(&"crate").hp, 40.0, 0.001)

func test_what_it_took_is_saved():
	var cat := ItemCatalog.load_from_dir("res://data/items")
	var item := Item.new()
	item.setup(cat.get_def(&"crate"))
	_world.add_child(item)
	item.set_loose()
	item.receive_hit(_hit(15.0))
	var d := item.to_dict(Transform3D.IDENTITY)
	assert_almost_eq(float(d["hurt"]), 15.0, 0.001)
	var again := Item.from_dict(d, cat)
	assert_almost_eq(again.damage_taken, 15.0, 0.001)
	again.free()
