extends GutTest

## The bridge fixture (docs/superpowers/specs/2026-10-09-ship-bridge-design.md
## §7): no rule broken, usable as every ship is, and every seat sat in and
## stood up from, with somewhere to walk.

const ShipUse := preload("res://test/unit/helpers/ship_use.gd")
const BRIDGE := "res://test/fixtures/bridge/bridge.json"
const SAVE := "user://test_bridge_ship/game.json"

func after_each():
	for a in [&"move_forward", &"move_back"]:
		Input.action_release(a)
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)

func test_it_breaks_no_rule():
	var found := ShipRules.check(ShipLibrary.read(BRIDGE)["grid"], BlockCatalog.load_from_dir("res://data/blocks"))
	assert_eq(found["rules"], [])

func test_it_is_usable():
	await ShipUse.use(self, ShipLibrary.read(BRIDGE)["grid"], "Bridge test ship", SAVE, "bridge")

func test_you_stand_up_from_every_seat_and_walk():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.starter_ship = BRIDGE
	add_child_autofree(root)
	await wait_process_frames(2)
	var director: CameraDirector = root.get_node("CameraDirector")
	var avatar: Avatar = root.get_tree().get_first_node_in_group(Avatar.GROUP)
	for s: Seat in root.aboard.seats():
		director.sit(s)
		await wait_for_signal(director.transition_finished, 3)
		director.stand()
		await wait_for_signal(director.transition_finished, 3)
		await wait_physics_frames(10)
		assert_true(avatar.is_on_floor(), "standing from %s, on your feet" % s.cell)
		var from := avatar.global_position
		Input.action_press(&"move_back")
		await wait_physics_frames(45)
		Input.action_release(&"move_back")
		await wait_physics_frames(5)
		assert_gt(from.distance_to(avatar.global_position), 0.8, "and you can walk away from %s" % s.cell)
		avatar.place(root.aboard.interior.global_transform * root._deck_spot(root.aboard))
		await wait_physics_frames(5)
