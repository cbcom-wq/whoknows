extends GutTest

## SalvageField (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §10.1-§10.3): the near cloud behind the stern, the same from the seed and
## its id every time; its items loaded near it and freed far from it, each one
## a floating-origin member of its own; and what is taken, remembered.

const SEED := 1337
## A stern somewhere out in the universe, turned, so nothing passes by being
## at the origin: +z is aft.
var _stern := Transform3D(Basis(Vector3(0.3, 1.0, -0.2).normalized(), 0.8), Vector3(40.0, -12.0, 300.0))

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
	_focus.position = _stern.origin
	_universe.set_focus(_focus)
	_outside = Node3D.new()
	add_child_autofree(_outside)
	_field = _new_field(SEED)

func _new_field(world_seed: int) -> SalvageField:
	var field := SalvageField.new()
	_outside.add_child(field)
	field.set_physics_process(false)
	field.setup(_universe, ItemCatalog.load_from_dir(), world_seed)
	return field

func _near() -> Array[Item]:
	return _field.loaded_items(SalvageField.NEAR)

## Where the cloud's entry `e` puts its item, in engine space.
func _at(field: SalvageField, e: Dictionary) -> Vector3:
	return _universe.to_engine(field.centre(SalvageField.NEAR)) + (e["pose"] as Transform3D).origin

func test_the_near_cloud_is_12_items_12_to_40_m_aft_of_the_stern():
	_field.add_near_cloud(_stern)
	var entries := _field.cloud_items(SalvageField.NEAR)
	assert_eq(entries.size(), 12)
	var aft := _stern.affine_inverse()
	for e in entries:
		var local := aft * _at(_field, e)
		assert_between(local.z, 12.0, 40.0, "item %d is 12-40 m aft (%s)" % [e["index"], local])
		assert_lte(local.length(), 40.0, "and no more than 40 m from the stern")

func test_its_centre_is_on_the_airlocks_line():
	_field.add_near_cloud(_stern)
	var centre := _stern.affine_inverse() * _universe.to_engine(_field.centre(SalvageField.NEAR))
	assert_almost_eq(centre.x, 0.0, 0.001)
	assert_almost_eq(centre.y, 0.0, 0.001)
	assert_between(centre.z, 12.0, 40.0)

func test_the_same_seed_and_id_give_the_same_cloud():
	var a := _field.cloud_items(SalvageField.NEAR)
	var b := _new_field(SEED).cloud_items(SalvageField.NEAR)
	var c := _new_field(SEED + 1).cloud_items(SalvageField.NEAR)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i]["index"], i)
		assert_eq(a[i]["kind"], b[i]["kind"])
		assert_eq(a[i]["pose"], b[i]["pose"])
		assert_eq(a[i]["tumble"], b[i]["tumble"])
	assert_ne(a.map(func(e): return e["pose"]), c.map(func(e): return e["pose"]), "another seed, another cloud")

func test_every_item_is_a_salvage_kind_from_the_mix():
	var kinds := {}
	for e in _field.cloud_items(SalvageField.NEAR):
		kinds[e["kind"]] = true
		assert_true(e["kind"] in [&"rock_chunk", &"scrap_plate", &"ice_chunk", &"wire_coil", &"broken_module"],
			"%s is in the near cloud's mix" % e["kind"])
	assert_gte(kinds.size(), 3, "a mix, not one kind")

func test_the_mix_is_weighted_rock_4_scrap_3_ice_3_wire_2_module_1():
	var count := {}
	var n := 0
	for s in 400:
		for e in _new_field(s).cloud_items(SalvageField.NEAR):
			count[e["kind"]] = count.get(e["kind"], 0) + 1
			n += 1
	var weights := {&"rock_chunk": 4, &"scrap_plate": 3, &"ice_chunk": 3, &"wire_coil": 2, &"broken_module": 1}
	for kind in weights:
		assert_almost_eq(float(count.get(kind, 0)) / n, weights[kind] / 13.0, 0.02, "%s's share" % kind)

func test_items_tumble_no_faster_than_20_deg_s_and_sit_apart():
	var entries := _field.cloud_items(SalvageField.NEAR)
	for e in entries:
		var spin: Vector3 = e["tumble"]
		assert_gt(spin.length(), 0.0, "item %d tumbles" % e["index"])
		assert_lte(spin.length(), deg_to_rad(20.0) + 0.00001)
	for i in entries.size():
		for j in range(i + 1, entries.size()):
			var gap := (entries[i]["pose"] as Transform3D).origin.distance_to((entries[j]["pose"] as Transform3D).origin)
			assert_gte(gap, SalvageField.MIN_GAP, "items %d and %d clear of each other" % [i, j])

func test_a_near_cloud_loads_at_once_as_floating_origin_members():
	_field.add_near_cloud(_stern)
	var items := _near()
	assert_eq(items.size(), 12)
	assert_false(_field.is_in_group(Universe.EXTERIOR_SPACE), "the field is never a member")
	assert_eq(_field.transform, Transform3D.IDENTITY)
	var entries := _field.cloud_items(SalvageField.NEAR)
	for i in items.size():
		var item := items[i]
		var e: Dictionary = entries[i]
		assert_eq(item.get_parent(), _field, "directly under the field")
		assert_true(item.is_in_group(Universe.EXTERIOR_SPACE), "a member itself")
		assert_true(item.in_space)
		assert_eq(item.collision_mask, AsteroidBody.MASK)
		assert_eq(item.definition.id, e["kind"])
		assert_almost_eq(item.global_position, _at(_field, e), Vector3.ONE * 0.001, "at its seeded place")
		assert_eq(item.linear_velocity, Vector3.ZERO, "it does not drift")
		assert_eq(item.angular_velocity, e["tumble"])
		assert_false(item.can_sleep, "it never stops tumbling")

func test_items_tumble_in_place():
	_field.add_near_cloud(_stern)
	var item := _near()[0]
	var at := item.global_position
	var turned := item.global_basis
	for i in 30:
		await get_tree().physics_frame
	assert_almost_eq(item.global_position, at, Vector3.ONE * 0.0001, "in place")
	assert_false(item.global_basis.is_equal_approx(turned), "turning")

func test_beyond_4_km_they_are_freed_with_no_orphans_and_back_within_3_km():
	_field.add_near_cloud(_stern)
	var centre := _universe.to_engine(_field.centre(SalvageField.NEAR))
	_focus.position = centre + Vector3(0, 0, 3900)
	_field.update()
	assert_eq(_near().size(), 12, "between 3 and 4 km, loaded ones stay")
	_focus.position = centre + Vector3(0, 0, 4100)
	_field.update()
	assert_eq(_near().size(), 0, "freed beyond 4 km")
	assert_eq(_field.get_child_count(), 0, "none left under the field")
	assert_eq(get_tree().get_nodes_in_group(Universe.EXTERIOR_SPACE).size(), 0, "none left in the group")
	assert_no_new_orphans()
	_focus.position = centre + Vector3(0, 0, 3100)
	_field.update()
	assert_eq(_near().size(), 0, "between 4 and 3 km, freed ones stay freed")
	_focus.position = centre + Vector3(0, 0, 2900)
	_field.update()
	assert_eq(_near().size(), 12, "back within 3 km")

func test_a_cloud_far_away_is_not_loaded():
	_focus.position = _stern.origin + Vector3(0, 5000, 0)
	_field.add_near_cloud(_stern)
	assert_false(_field.is_loaded(SalvageField.NEAR))
	assert_eq(_field.get_child_count(), 0)

func test_a_swallowed_item_is_recorded_once_and_left_out_when_the_cloud_reloads():
	_field.add_near_cloud(_stern)
	var victim := _near()[4]
	var index := 4
	Item.consume(victim)
	assert_true(_field.ledger.is_taken(SalvageField.NEAR, index))
	assert_eq(_field.ledger.remaining(SalvageField.NEAR, 12), 11, "recorded once")
	assert_eq(_near().size(), 11)
	assert_eq(get_tree().get_nodes_in_group(Universe.EXTERIOR_SPACE).size(), 11)
	var centre := _universe.to_engine(_field.centre(SalvageField.NEAR))
	_focus.position = centre + Vector3(4100, 0, 0)
	_field.update()
	_focus.position = centre
	_field.update()
	var back := _near()
	assert_eq(back.size(), 11, "the taken one stays gone")
	var entries := _field.cloud_items(SalvageField.NEAR)
	for item in back:
		assert_false(item.global_position.is_equal_approx(_at(_field, entries[index])), "not at the taken one's place")
	assert_eq(_field.ledger.remaining(SalvageField.NEAR, 12), 11)
	assert_no_new_orphans()

func test_something_pushed_but_not_taken_returns_to_its_place_on_reload():
	_field.add_near_cloud(_stern)
	var pushed := _near()[2]
	pushed.global_position += Vector3(3, 0, 0)
	var centre := _universe.to_engine(_field.centre(SalvageField.NEAR))
	_focus.position = centre + Vector3(4100, 0, 0)
	_field.update()
	_focus.position = centre
	_field.update()
	var entries := _field.cloud_items(SalvageField.NEAR)
	assert_almost_eq(_near()[2].global_position, _at(_field, entries[2]), Vector3.ONE * 0.001)

func test_the_cloud_is_where_it_was_after_a_shift():
	_field.add_near_cloud(_stern)
	var item := _near()[0]
	var offset := item.global_position - _focus.global_position
	_universe.shift(Vector3(0, 0, 2000))
	_focus.global_position -= Vector3(0, 0, 2000)
	assert_almost_eq(item.global_position - _focus.global_position, offset, Vector3.ONE * 0.001, "moved with the shift")
	_field.update()
	assert_eq(_near()[0], item, "a shift reloads nothing")
	assert_eq(_field.transform, Transform3D.IDENTITY, "the field itself never moves")
