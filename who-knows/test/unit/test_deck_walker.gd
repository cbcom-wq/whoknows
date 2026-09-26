extends GutTest

## The droid walks the real starter (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §5.5): along its map, through doors that
## open for it, never into the airlock or the helm, holding its line against a
## burn's shove and sliding under a harder one.

var _root: Node
var _ship: Ship
var _droid: Npc

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	await wait_physics_frames(3)
	# Its own brain would set its intent, and step aside for you; these tests
	# set it by hand, so you stand out of its way, in the bunk room.
	_droid = _ship.npc_director.live.values()[0]
	_ship.npc_director.set_physics_process(false)
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	avatar.place(_ship.interior.global_transform * Transform3D(Basis.IDENTITY,
		DeckPaths.floor_point(Vector3i(-1, 0, 1)) + Vector3(0, 0.05, 0)))

## The felt gravity, held: MotionCoupling would set it back every tick.
func _hold_felt(felt: Vector3) -> void:
	_root.get_node("Ship/MotionCoupling").set_physics_process(false)
	_ship.interior_builder.felt_gravity.set_felt(felt)

func test_it_wakes_at_its_dock_in_the_closet():
	assert_eq(DeckPaths.cell_at(_droid.local_position()), Vector3i(1, 0, 2))
	assert_true(_droid.active is DeckWalker)

func test_it_walks_from_the_closet_to_the_bridge_through_the_door():
	var goal := DeckPaths.floor_point(Vector3i(-1, 0, -1))
	_droid.intent = Intent.go(goal, 1.0)
	var doors := _root.find_children("*", "SlidingDoor", true, false)
	var opened := {}
	var arrived := false
	for i in 60 * 12:
		await wait_physics_frames(1)
		for door: SlidingDoor in doors:
			if door.is_open:
				opened[door] = true
		var cell := DeckPaths.cell_at(_droid.local_position())
		assert_ne(cell, Vector3i(0, 0, 3), "never in the airlock")
		assert_ne(cell, Vector3i(0, 0, -3), "never in the helm's cell")
		if _droid.local_position().distance_to(goal) < 0.3:
			arrived = true
			break
	assert_true(arrived, "arrived: %s from %s" % [_droid.local_position(), goal])
	assert_gt(opened.size(), 0, "a door opened for it on the way out of the closet")

func test_a_shove_past_its_grip_slides_it():
	_hold_felt(Vector3.DOWN * 9.8 + Vector3(0, 0, -12))
	var was := _droid.local_position()
	await wait_physics_frames(30)
	assert_gt(was.z - _droid.local_position().z, 0.05, "it slid forward with the shove")

func test_braced_it_holds_against_a_burn():
	_hold_felt(Vector3.DOWN * 9.8 + Vector3(0, 0, -9))
	_droid.intent = Intent.idle(&"brace")
	await wait_physics_frames(5)
	var was := _droid.local_position()
	await wait_physics_frames(60)
	assert_lt(was.distance_to(_droid.local_position()), 0.05)
