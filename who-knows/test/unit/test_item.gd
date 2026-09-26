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

## Quantum energy spec §7.1, §11.4, §14: a converted or swallowed item says so
## through `consumed`, once, while it is still whole and in the tree, then is
## gone at once -- removed, then freed, never queued (SLICE-1-STATUS lessons).
func test_consume_says_so_once_then_frees_the_item():
	var holder := Node3D.new()
	add_child_autofree(holder)
	var item := Item.new()
	item.setup(_def())
	holder.add_child(item)
	var heard := []
	item.consumed.connect(func() -> void:
		heard.append([is_instance_valid(item), item.is_inside_tree(), item.get_parent() == holder]))
	Item.consume(item)
	assert_eq(heard, [[true, true, true]], "once, before it is freed")
	assert_freed(item, "the consumed item")
	assert_eq(holder.get_child_count(), 0, "out of the tree at once, not queued")
	assert_no_new_orphans()

func test_consume_frees_an_item_outside_the_tree_too():
	var item := Item.new()
	item.setup(_def())
	var heard := [0]
	item.consumed.connect(func() -> void: heard[0] += 1)
	Item.consume(item)
	assert_eq(heard[0], 1)
	assert_freed(item, "the consumed item")
	assert_no_new_orphans()

func _looks(item: Item) -> Array:
	return item.get_node("Look").find_children("*", "GeometryInstance3D", true, false)

## Quantum energy spec §10.1, §14.2: outside, an item is drawn on the world's
## layer, lit by the sun, and meets the hull, you, other items and rocks --
## AsteroidBody's own mask. Aboard again, both come back. Whoever parents it
## decides how it follows the floating origin, so its groups never change.
func test_set_space_puts_it_in_the_world_and_back_aboard():
	var item := _item()
	item.set_loose()
	var groups := item.get_groups()
	item.set_space(true)
	assert_true(item.in_space)
	assert_eq(item.collision_layer, 32)
	assert_eq(item.collision_mask, 1 | 4 | 32 | 64)
	assert_eq(item.collision_mask, AsteroidBody.MASK, "the mask a rock has")
	assert_gt(_looks(item).size(), 0, "the look was rebuilt")
	for g in _looks(item):
		assert_eq(g.layers, 1, "%s on the exterior layer" % g.name)
	assert_eq(item.get_node("Look").get_child_count(), _looks(item).size(), "one look, not two")
	assert_eq(item.get_groups(), groups, "no floating-origin group joined")
	item.set_space(false)
	assert_false(item.in_space)
	assert_eq(item.collision_mask, 2 | 4 | 32)
	for g in _looks(item):
		assert_eq(g.layers, 2, "%s back on the interior layer" % g.name)
	assert_eq(item.get_groups(), groups)

func test_set_space_rebuilds_the_kit_on_the_worlds_layer():
	var item := _item()
	item.set_space(true)
	var kit_meshes := item.get_node("Look").get_children().filter(func(n): return n is MeshInstance3D)
	assert_eq(kit_meshes.size(), 1, "the canister's one solid batch")
	assert_eq(kit_meshes[0].name, "DressingSolid")
	assert_eq(kit_meshes[0].layers, 1)

func test_set_space_frees_the_old_look_with_no_orphans():
	var item := _item()
	item.set_space(true)
	item.set_space(false)
	assert_eq(item.get_children().filter(func(n): return n.name == &"Look").size(), 1)
	assert_no_new_orphans()

func test_outside_letting_go_and_stowing_keep_the_worlds_mask():
	var item := _item()
	item.set_space(true)
	item.set_held()
	assert_eq(item.collision_mask, 0, "held, it is out of the physics world")
	item.set_loose()
	assert_eq(item.collision_mask, AsteroidBody.MASK)
	item.set_stowed(null)
	assert_eq(item.collision_mask, AsteroidBody.MASK)

func test_set_space_leaves_a_held_item_out_of_the_physics_world():
	var item := _item()
	item.set_held()
	item.set_space(true)
	assert_eq(item.collision_layer, 0)
	assert_eq(item.collision_mask, 0)

func test_only_salvage_glints_and_only_outside():
	var cat := ItemCatalog.load_from_dir()
	var rock := Item.new()
	rock.setup(cat.get_def(&"rock_chunk"), 0.3)
	add_child_autofree(rock)
	assert_null(rock.get_node("Look").get_node_or_null("Glint"), "aboard there is no sun to catch")
	rock.set_space(true)
	assert_not_null(rock.get_node("Look").get_node_or_null("Glint"), "outside, it catches the sun")
	rock.set_space(false)
	assert_null(rock.get_node("Look").get_node_or_null("Glint"))
	var mug := Item.new()
	mug.setup(cat.get_def(&"mug"))
	add_child_autofree(mug)
	mug.set_space(true)
	assert_null(mug.get_node("Look").get_node_or_null("Glint"), "a mug is not salvage")

func test_a_use_sits_on_the_item():
	var d := _def()
	d.use = load("res://src/items/item_use.gd")
	var item := _item(d)
	assert_true(item.use_node is Node3D, "so what it makes -- lights, screens -- moves with the item")
