extends GutTest

## The Interactor sees items (hands-and-items spec §7.2, as amended
## 2026-09-24): it reaches the items layer, forgives an aim that is a little
## off, hides what cannot be taken, and never reports what you hold.

var _world: Node3D
var _avatar: Avatar
var _interactor: Interactor

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_avatar = load("res://scenes/avatar.tscn").instantiate()
	_interactor = Interactor.new()
	_interactor.name = "Interactor"
	_avatar.get_node("Head").add_child(_interactor)
	_interactor.owner = _avatar
	_world.add_child(_avatar)
	_avatar.grasp.world_root = _world
	_avatar.set_physics_process(false)

func _item(at: Vector3) -> Item:
	var d := ItemDefinition.new()
	d.id = &"mug"
	d.display_name = "Mug"
	d.size = Vector3(0.3, 0.3, 0.3)
	d.grip = ItemDefinition.Grip.WIELD
	d.look = &"mug"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_stowed(null)
	return item

func test_reaches_items_and_interior_geometry():
	assert_eq(_interactor.collision_mask, 2 | 32)

func test_the_avatar_finds_its_interactor():
	assert_eq(_avatar.interactor, _interactor)

func test_offers_an_item_in_front_of_you():
	var item := _item(Vector3(0, 1.6, -1.5))
	watch_signals(_interactor)
	await wait_physics_frames(3)
	assert_eq(_interactor.current(), item)
	assert_signal_emitted_with_parameters(_interactor, "prompt_changed", ["[F] Take Mug"])

func test_hides_an_item_you_cannot_take():
	_item(Vector3(0, 1.6, -1.5))
	_avatar.take_item(_item(Vector3(3, 1.6, 0)))
	await wait_physics_frames(3)
	assert_null(_interactor.current(), "hands full")

func test_never_reports_what_you_hold():
	var item := _item(Vector3(0, 1.6, -1.5))
	await wait_physics_frames(3)
	_avatar.take_item(item)
	await wait_physics_frames(3)
	assert_ne(_interactor.current(), item)

func _wall(z: float) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.global_position = Vector3(0, 1.6, z)

func _small(at: Vector3) -> Item:
	var d := ItemDefinition.new()
	d.id = &"mug"
	d.display_name = "Mug"
	d.size = Vector3(0.09, 0.1, 0.09)
	d.grip = ItemDefinition.Grip.WIELD
	d.look = &"mug"
	var item := Item.new()
	item.setup(d)
	_world.add_child(item)
	item.global_position = at
	item.set_stowed(null)
	return item

func test_offers_a_small_item_the_ray_just_misses():
	var eye := _interactor.global_position
	var item := _small(eye + Vector3(0.14, -0.08, -1.5))
	await wait_physics_frames(3)
	assert_false(_interactor.is_colliding(), "the thin ray misses it")
	assert_eq(_interactor.current(), item, "but it is close enough to the line of sight")

func test_prefers_the_item_nearest_the_line_of_sight():
	var eye := _interactor.global_position
	_small(eye + Vector3(0.2, 0, -1.5))
	var nearer := _small(eye + Vector3(-0.08, 0, -1.5))
	await wait_physics_frames(3)
	assert_eq(_interactor.current(), nearer)

func test_does_not_offer_an_item_well_off_to_the_side():
	var eye := _interactor.global_position
	_small(eye + Vector3(0.9, 0, -1.5))
	await wait_physics_frames(3)
	assert_null(_interactor.current())

func test_does_not_offer_an_item_out_of_reach():
	var eye := _interactor.global_position
	_small(eye + Vector3(0.05, 0, -3.5))
	await wait_physics_frames(3)
	assert_null(_interactor.current())

func test_does_not_offer_an_item_behind_a_wall():
	var eye := _interactor.global_position
	_wall(eye.z - 1.0)
	_small(eye + Vector3(0.12, 0, -1.6))
	await wait_physics_frames(3)
	assert_null(_interactor.current())
