extends GutTest

## Starting aboard another ship (docs/superpowers/specs/
## 2026-10-09-ship-designer-design.md §7.2): how the probe and the renders work
## on any ship. Never the player's: anything but the starter saves nothing.

const BIG := "res://test/fixtures/size/big.json"
const SAVE := "user://test_starter_ship/game.json"

func after_each():
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)

func _scene(ship: String, saving := false) -> Node:
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = saving
	root.save_path = SAVE
	if ship != "":
		root.starter_ship = ship
	add_child_autofree(root)
	return root

func test_by_default_you_start_in_the_starter():
	var root := _scene("")
	await wait_process_frames(2)
	assert_eq(ShipLibrary.rows_text(root.aboard.grid), ShipLibrary.rows_text(ShipLibrary.load_from_dir().grid(&"starter")))

func test_you_can_start_aboard_another_ship():
	var root := _scene(BIG)
	await wait_process_frames(2)
	assert_eq(ShipLibrary.rows_text(root.aboard.grid), ShipLibrary.rows_text(ShipLibrary.read(BIG)["grid"]))
	assert_eq(root.aboard.launch_blueprint.ship_name, "Big")
	var avatar: Avatar = root.get_tree().get_first_node_in_group(Avatar.GROUP)
	assert_same(avatar.get_parent(), root.aboard.interior, "you are inside it")
	assert_almost_eq(avatar.position, root._deck_spot(root.aboard).origin, Vector3.ONE * 0.1, "on its deck")

func test_a_library_id_works_too():
	var root := _scene("starter")
	await wait_process_frames(2)
	assert_eq(root.aboard.grid.size(), 110)

func test_another_ship_turns_saving_off():
	var root := _scene(BIG, true)
	await wait_process_frames(2)
	assert_false(root.save_enabled, "a probe never writes the owner's game")

func test_the_starter_keeps_saving_on():
	var root := _scene("starter", true)
	await wait_process_frames(2)
	assert_true(root.save_enabled)

func test_an_unknown_ship_starts_you_in_the_starter():
	var root := _scene("nope")
	await wait_process_frames(2)
	assert_push_error("no library ship called \"nope\"")
	assert_eq(root.aboard.grid.size(), 110)

func test_keep_saving_keeps_saving_on():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = true
	root.keep_saving = true
	root.save_path = SAVE
	root.starter_ship = BIG
	add_child_autofree(root)
	await wait_process_frames(2)
	assert_true(root.save_enabled)
