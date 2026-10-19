extends GutTest

## A placed salvage cloud (rock-creatures spec, a nest's salvage): the items'
## poses are chosen by the caller instead of seeded in a ball, and load, free,
## shift and are taken like any cloud's. Placed clouds are not saved; the
## ledger of what was taken from them is.

const SEED := 1337
const NEST := &"nest:test"

var _universe: Universe
var _focus: Node3D
var _outside: Node3D
var _field: SalvageField

func before_each():
	_universe = Universe.new()
	_universe.origin = UniversePoint.at(123000, -45000, 6789000)
	add_child_autofree(_universe)
	_universe.set_physics_process(false)
	_focus = Node3D.new()
	add_child_autofree(_focus)
	_focus.position = Vector3(40.0, -12.0, 300.0)
	_universe.set_focus(_focus)
	_outside = Node3D.new()
	add_child_autofree(_outside)
	_field = SalvageField.new()
	_outside.add_child(_field)
	_field.set_physics_process(false)
	_field.setup(_universe, ItemCatalog.load_from_dir(), SEED)

## Two entries, 40 m apart, the second turned.
func _entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"index": 0, "kind": &"rock_chunk", "variety": 0.25,
		"pose": Transform3D(Basis.IDENTITY, Vector3(2, 1, -3))})
	out.append({"index": 1, "kind": &"scrap_plate", "variety": 0.75,
		"pose": Transform3D(Basis(Vector3.UP, 0.6), Vector3(-5, 0.5, 4))})
	return out

## Registers the cloud 20 m from the focus.
func _place() -> Vector3:
	var centre := _focus.position + Vector3(0, 0, 20)
	_field.add_placed_cloud(NEST, centre, _entries())
	return centre

func _items() -> Array[Item]:
	return _field.loaded_items(NEST)

func _away_and_back() -> void:
	var centre := _universe.to_engine(_field.centre(NEST))
	_focus.position = centre + Vector3(4100, 0, 0)
	_field.update()
	_focus.position = centre
	_field.update()

func test_placed_items_load_where_they_were_put_and_at_rest():
	var centre := _place()
	assert_true(_field.is_placed(NEST))
	assert_false(_field.is_placed(SalvageField.NEAR))
	assert_true(_field.is_loaded(NEST), "loads at once, the focus being near")
	var items := _items()
	assert_eq(items.size(), 2)
	var entries := _entries()
	for i in items.size():
		var item := items[i]
		var pose: Transform3D = entries[i]["pose"]
		assert_almost_eq(item.global_position, centre + pose.origin, Vector3.ONE * 0.001, "item %d at its pose" % i)
		assert_true(item.global_basis.is_equal_approx(pose.basis), "turned as posed")
		assert_eq(item.angular_velocity, Vector3.ZERO, "at rest, no tumble")
		assert_eq(item.linear_velocity, Vector3.ZERO)
		assert_eq(item.definition.id, entries[i]["kind"])
		assert_eq(item.get_parent(), _field)
		assert_true(item.is_in_group(Universe.EXTERIOR_SPACE))
		assert_true(item.in_space)
	for e in _field.cloud_items(NEST):
		assert_eq(e["tumble"], Vector3.ZERO)

func test_a_placed_cloud_frees_and_loads_by_the_same_distances():
	var centre := _place()
	_focus.position = centre + Vector3(0, 0, 3900)
	_field.update()
	assert_eq(_items().size(), 2, "between 3 and 4 km, loaded ones stay")
	_focus.position = centre + Vector3(0, 0, 4100)
	_field.update()
	assert_eq(_items().size(), 0, "freed beyond 4 km")
	assert_eq(_field.get_child_count(), 0)
	assert_no_new_orphans()
	_focus.position = centre + Vector3(0, 0, 3100)
	_field.update()
	assert_eq(_items().size(), 0, "freed ones stay freed until within 3 km")
	_focus.position = centre + Vector3(0, 0, 2900)
	_field.update()
	assert_eq(_items().size(), 2)

func test_a_placed_cloud_far_away_is_stored_not_loaded():
	_field.add_placed_cloud(NEST, _focus.position + Vector3(0, 5000, 0), _entries())
	assert_true(_field.is_placed(NEST))
	assert_false(_field.is_loaded(NEST))
	assert_eq(_field.get_child_count(), 0)

func test_a_nest_registered_again_loads_once_and_keeps_what_was_taken():
	var centre := _place()
	Item.consume(_items()[0])
	assert_true(_field.ledger.is_taken(NEST, 0))
	var live := _items()
	assert_eq(live.size(), 1)
	_field.add_placed_cloud(NEST, centre, _entries())
	assert_eq(_items(), live, "a loaded cloud keeps its live items")
	assert_eq(_field.get_child_count(), 1, "and gains no second set")
	_away_and_back()
	var back := _items()
	assert_eq(back.size(), 1, "one item, never two")
	assert_almost_eq(back[0].global_position, centre + (_entries()[1]["pose"] as Transform3D).origin,
		Vector3.ONE * 0.001, "index 1, the one not taken")
	assert_no_new_orphans()

func test_registering_again_replaces_the_stored_centre_and_entries():
	_place()
	var moved := _focus.position + Vector3(0, 0, 60)
	var one: Array[Dictionary] = [{"index": 0, "kind": &"ice_chunk", "variety": 0.5,
		"pose": Transform3D(Basis.IDENTITY, Vector3(1, 0, 0))}]
	_field.add_placed_cloud(NEST, moved, one)
	assert_eq(_field.cloud_items(NEST).size(), 1)
	assert_eq(_items().size(), 2, "the live ones stay as they are")
	_away_and_back()
	var back := _items()
	assert_eq(back.size(), 1)
	assert_eq(back[0].definition.id, &"ice_chunk")
	assert_almost_eq(back[0].global_position, moved + Vector3(1, 0, 0), Vector3.ONE * 0.001)

func test_registering_one_that_is_not_loaded_just_stores_it():
	var far := _focus.position + Vector3(0, 5000, 0)
	_field.add_placed_cloud(NEST, far, _entries())
	_field.add_placed_cloud(NEST, far, _entries())
	assert_false(_field.is_loaded(NEST))
	assert_eq(_field.get_child_count(), 0)
	assert_eq(_field.cloud_items(NEST).size(), 2)

func test_placed_clouds_are_not_saved_but_their_ledger_is():
	_place()
	_field.add_near_cloud(Transform3D(Basis.IDENTITY, _focus.position))
	Item.consume(_items()[0])
	var d := _field.to_dict()
	var centres: Dictionary = d["centres"]
	assert_false(centres.has(String(NEST)), "no centre for the placed id")
	assert_true(centres.has(String(SalvageField.NEAR)), "the near cloud is still saved")
	var taken: Dictionary = d["taken"]
	assert_eq(taken[String(NEST)], [0], "but what was taken from it is kept")
	var fresh := SalvageField.new()
	_outside.add_child(fresh)
	fresh.set_physics_process(false)
	fresh.setup(_universe, ItemCatalog.load_from_dir(), SEED)
	fresh.from_dict(d)
	assert_false(fresh.is_placed(NEST))
	assert_null(fresh.centre(NEST))
	assert_true(fresh.ledger.is_taken(NEST, 0), "the ledger comes back, for when the rock does")

func test_a_cloud_that_is_neither_near_nor_placed_is_still_an_error():
	_place()
	var none := _field.cloud_items(&"no_such_cloud")
	assert_push_error("no cloud called")
	assert_eq(none.size(), 0)

func test_a_placed_cloud_keeps_its_place_through_a_shift():
	var centre := _place()
	var item := _items()[0]
	var offset := item.global_position - _focus.global_position
	var upoint := _field.centre(NEST)
	_universe.shift(Vector3(0, 0, 2000))
	_focus.global_position -= Vector3(0, 0, 2000)
	assert_almost_eq(item.global_position - _focus.global_position, offset, Vector3.ONE * 0.001, "moved with the shift")
	_field.update()
	assert_eq(_items()[0], item, "a shift reloads nothing")
	assert_eq(_field.centre(NEST), upoint, "the centre is a universe point, not shifted by hand")
	_away_and_back()
	var back := _items()
	assert_eq(back.size(), 2)
	var shifted_centre := _universe.to_engine(_field.centre(NEST))
	assert_almost_eq(shifted_centre, centre - Vector3(0, 0, 2000), Vector3.ONE * 0.01)
	assert_almost_eq(back[0].global_position, shifted_centre + (_entries()[0]["pose"] as Transform3D).origin,
		Vector3.ONE * 0.001, "and reloads at the same place in the world")
