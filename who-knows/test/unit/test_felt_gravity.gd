extends GutTest

## FeltGravity (hands-and-items spec §6): plating gravity plus the hull's shove,
## applied by the engine to every loose item inside, and a net for any item
## that tunnels out.

var _field: FeltGravity

func before_each():
	_field = FeltGravity.new()
	add_child_autofree(_field)
	_field.set_cells([Vector3(0, 1.3, 0)], Vector3(2, 2.6, 2))

func _item_at(pos: Vector3) -> Item:
	var d := ItemDefinition.new()
	d.id = &"crate"
	d.display_name = "Crate"
	d.size = Vector3(0.2, 0.2, 0.2)
	d.look = &"crate"
	var item := Item.new()
	item.setup(d)
	add_child_autofree(item)
	item.global_position = pos
	item.set_loose()
	return item

func test_one_box_per_cell_replaced_on_every_call():
	_field.set_cells([Vector3.ZERO, Vector3(2, 0, 0), Vector3(4, 0, 0)], Vector3(2, 2.6, 2))
	assert_eq(_field.cell_count(), 3)
	_field.set_cells([Vector3.ZERO], Vector3(2, 2.6, 2))
	assert_eq(_field.cell_count(), 1, "rebuilding replaces the boxes instead of adding to them")

func test_only_items_feel_it():
	assert_eq(_field.collision_layer, 0)
	assert_eq(_field.collision_mask, Item.LAYER)
	assert_eq(_field.gravity_space_override, Area3D.SPACE_OVERRIDE_REPLACE)
	assert_false(_field.gravity_point)

func test_set_felt_sets_the_engines_gravity():
	var felt := Vector3(0, -9.8, 3.0)
	_field.set_felt(felt)
	assert_almost_eq(_field.gravity, felt.length(), 0.0001)
	assert_almost_eq(_field.gravity_direction, felt.normalized(), Vector3.ONE * 0.0001)
	assert_eq(_field.felt, felt)

func test_a_loose_item_falls_along_the_felt_vector():
	_field.set_felt(Vector3(0, 0, 5))
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(12)
	assert_gt(item.linear_velocity.z, 0.3, "pushed along the felt vector")
	assert_almost_eq(item.linear_velocity.y, 0.0, 0.01, "and nothing else: project gravity is zero")

func test_a_resting_item_wakes_when_the_felt_changes():
	_field.set_felt(Vector3.ZERO)
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(3)
	item.sleeping = true
	_field.set_felt(Vector3(0, 0, 3))
	assert_false(item.sleeping, "a change of 3 m/s² wakes it")

func test_a_small_change_lets_it_sleep():
	_field.set_felt(Vector3.ZERO)
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(3)
	item.sleeping = true
	_field.set_felt(Vector3(0, 0, 0.2))
	assert_true(item.sleeping)

func test_a_loose_item_that_leaves_is_put_back():
	_field.set_felt(Vector3.ZERO)
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(3)
	item.global_position = Vector3(10, 1.3, 0)
	await wait_physics_frames(4)
	assert_almost_eq(item.global_position, Vector3(0, 1.3, 0), Vector3.ONE * 0.05)

func test_a_held_item_that_leaves_is_not():
	_field.set_felt(Vector3.ZERO)
	var item := _item_at(Vector3(0, 1.3, 0))
	await wait_physics_frames(3)
	item.set_held()
	item.global_position = Vector3(10, 1.3, 0)
	await wait_physics_frames(4)
	assert_gt(item.global_position.x, 9.0)
