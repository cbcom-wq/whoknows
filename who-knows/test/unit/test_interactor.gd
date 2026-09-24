extends GutTest

## The Interactor sees items (hands-and-items spec §7.2): it reaches the items
## layer, hides what cannot be taken, and never reports what you hold.

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
