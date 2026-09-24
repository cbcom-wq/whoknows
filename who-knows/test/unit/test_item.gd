extends GutTest

## Item (hands-and-items spec §4.4): a rigid body built from a definition
## alone -- no grid, no ship -- in three states, talking to whoever takes it
## only through take_item and can_take_item.

class Lit extends ItemUse:
	func status() -> String:
		return "burning"

class Actor extends Node:
	var taken: Item = null
	var allowed := true
	func take_item(item: Item) -> void:
		taken = item
	func can_take_item(_item: Item) -> bool:
		return allowed

func _def(grip := ItemDefinition.Grip.CARRY, mass := 4.0) -> ItemDefinition:
	var d := ItemDefinition.new()
	d.id = &"canister"
	d.display_name = "Canister"
	d.mass_kg = mass
	d.size = Vector3(0.16, 0.34, 0.16)
	d.grip = grip
	d.stow_class = &"small"
	d.look = &"canister"
	return d

func _item(def: ItemDefinition = null) -> Item:
	var item := Item.new()
	item.setup(def if def != null else _def())
	add_child_autofree(item)
	return item

func test_builds_from_a_definition_alone():
	var item := _item()
	assert_eq(item.mass, 4.0)
	var shapes := item.get_children().filter(func(n): return n is CollisionShape3D)
	assert_eq(shapes.size(), 1, "one box collider")
	assert_eq((shapes[0].shape as BoxShape3D).size, Vector3(0.16, 0.34, 0.16))
	assert_eq(item.shape(), shapes[0].shape)
	assert_gt(item.find_children("*", "MeshInstance3D", true, false).size(), 0, "it has a look")

func test_lives_on_the_items_layer():
	var item := _item()
	assert_eq(item.collision_layer, 32)
	assert_eq(item.collision_mask, 2 | 4 | 32)
	assert_true(item.continuous_cd, "thrown items must not tunnel through 0.1 m walls")
	assert_true(item.is_in_group(&"interactable"))

func test_its_look_is_on_the_interior_layer():
	for mi in _item().find_children("*", "MeshInstance3D", true, false):
		assert_eq(mi.layers, 2)

func test_loose_is_dynamic():
	var item := _item()
	item.set_loose()
	assert_eq(item.state, Item.State.LOOSE)
	assert_false(item.freeze)

func test_stowed_is_frozen_static():
	var item := _item()
	item.set_stowed(null)
	assert_eq(item.state, Item.State.STOWED)
	assert_true(item.freeze)
	assert_eq(item.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
	assert_eq(item.collision_layer, 32, "you can still bump into it")

func test_held_is_frozen_static_and_leaves_the_physics_world():
	for grip in [ItemDefinition.Grip.WIELD, ItemDefinition.Grip.CARRY]:
		var item := _item(_def(grip))
		item.set_held()
		assert_eq(item.state, Item.State.HELD)
		assert_true(item.freeze)
		# Static, not kinematic: the engine steps a kinematic body and writes
		# its stale position back over the hand's, a frame behind.
		assert_eq(item.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
		assert_eq(item.collision_layer, 0)
		assert_eq(item.collision_mask, 0)

func test_letting_go_restores_the_layers():
	var item := _item(_def(ItemDefinition.Grip.WIELD))
	item.set_held()
	item.set_loose()
	assert_eq(item.collision_layer, 32)
	assert_eq(item.collision_mask, 38)
	assert_false(item.freeze)

func test_prompts_name_the_item():
	var item := _item()
	item.set_loose()
	assert_eq(item.prompt_text(), "Pick up Canister")
	item.set_stowed(null)
	assert_eq(item.prompt_text(), "Take Canister")
	assert_eq(_item(_def(ItemDefinition.Grip.CARRY, 60.0)).prompt_text(), "Too heavy")

func test_asks_the_actor_before_offering_itself():
	var actor: Actor = autofree(Actor.new())
	var item := _item()
	assert_true(item.can_interact(actor))
	actor.allowed = false
	assert_false(item.can_interact(actor))
	actor.allowed = true
	item.set_held()
	assert_false(item.can_interact(actor), "never while held")

func test_interacting_hands_it_to_the_actor():
	var actor: Actor = autofree(Actor.new())
	var item := _item()
	item.interact(actor)
	assert_eq(actor.taken, item)

func test_an_item_with_no_use_does_nothing_when_used():
	var item := _item()
	assert_null(item.use_node)
	assert_false(item.use(Transform3D.IDENTITY, null, null))

func test_a_use_can_add_a_status_to_the_prompt():
	var item := _item()
	var lit := Lit.new()
	item.use_node = lit
	item.add_child(lit)
	item.set_loose()
	assert_eq(item.prompt_text(), "Pick up Canister (burning)")
	item.set_stowed(null)
	assert_eq(item.prompt_text(), "Take Canister (burning)")

func test_a_use_sits_on_the_item():
	var d := _def()
	d.use = load("res://src/items/item_use.gd")
	var item := _item(d)
	assert_true(item.use_node is Node3D, "so what it makes -- lights, screens -- moves with the item")
