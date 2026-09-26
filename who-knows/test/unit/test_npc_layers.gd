extends GutTest

## Every physics mask the NPC layer changes (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.1), read back from the real scene.

var _root: Node
var _ship: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")

func test_the_droid_is_on_the_npc_layer_and_meets_the_interior():
	await wait_physics_frames(3)
	assert_eq(_ship.npc_director.live.size(), 1)
	var droid: Npc = _ship.npc_director.live.values()[0]
	assert_eq(droid.collision_layer, 128)
	assert_eq(droid.collision_mask, 2 | 4 | 32)
	assert_false(droid.is_in_group(Universe.EXTERIOR_SPACE))

func test_everything_that_should_meet_an_npc_does():
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	assert_true(avatar.collision_mask & Npc.LAYER != 0, "the avatar aboard")
	assert_true(Avatar.SUIT_MASK & Npc.LAYER != 0, "the avatar on a spacewalk")
	assert_true(_ship.exterior.collision_mask & Npc.LAYER != 0, "the hull")
	assert_true(Item.MASK & Npc.LAYER != 0, "items")
	assert_true(AsteroidBody.MASK & Npc.LAYER != 0, "rock bodies")
	assert_true(PlasmaBolt.RAY_MASK & Npc.LAYER != 0, "a bolt")
	assert_true(PlasmaEmitter.RAY_MASK & Npc.LAYER != 0, "the pistol's aim")
	var doors := _root.find_children("*", "SlidingDoor", true, false)
	assert_gt(doors.size(), 0)
	for door in doors:
		var trigger := door.get_node("Trigger") as Area3D
		assert_true(trigger.collision_mask & Npc.LAYER != 0, "%s opens for NPCs" % door.name)
