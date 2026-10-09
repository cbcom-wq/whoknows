extends RefCounted

## The owner's rule (2026-10-02) played in the real flight scene: `grid`
## spawned 300 m off the starter, F8 aboard, a burn moves it and not the
## starter, you stand and walk, and a save to `save_path` brings it back as it
## was, named `ship_name`, with you aboard. Shared by test_ship_catalog.gd
## (every library ship) and test_big_ship.gd (the 600-block fixture). `t` is
## the calling test; `label` starts each of its messages.

const SCENE := "res://scenes/flight_test.tscn"

static func use(t: GutTest, grid: ShipGrid, ship_name: String, save_path: String, label: String) -> void:
	var root := _scene(t, save_path)
	await t.wait_process_frames(2)
	var starter: Ship = root.get_node("Ship")
	var place := Transform3D(starter.exterior.global_basis, starter.exterior.global_position + Vector3(300, 0, 0))
	var ship: Ship = root.fleet.spawn(grid, place, true, "", ShipBlueprint.from_grid(grid, ship_name))
	await t.wait_physics_frames(2)
	t.assert_true(root.board_nearest(), "%s: F8 boards it" % label)
	t.assert_same(root.aboard, ship, "%s: aboard it" % label)
	var starter_at := starter.exterior.global_position
	var ship_at := ship.exterior.global_position
	Input.action_press(&"move_forward")
	await t.wait_physics_frames(60)
	Input.action_release(&"move_forward")
	t.assert_gt(ship.exterior.global_position.distance_to(ship_at), 1.0, "%s: a burn moves it" % label)
	t.assert_almost_eq(starter.exterior.global_position, starter_at, Vector3.ONE * 0.5, "%s: and not the starter" % label)
	# Let the controls see the key go before standing: a burn held as you stand
	# latches on, by design.
	await t.wait_physics_frames(2)
	var director: CameraDirector = root.get_node("CameraDirector")
	director.stand()
	await t.wait_for_signal(director.transition_finished, 3)
	var avatar: Avatar = root.get_tree().get_first_node_in_group(Avatar.GROUP)
	var from := avatar.global_position
	Input.action_press(&"move_back")
	await t.wait_physics_frames(60)
	Input.action_release(&"move_back")
	t.assert_gt(from.distance_to(avatar.global_position), 1.0, "%s: you stand and walk" % label)
	t.assert_same(avatar.get_parent(), ship.interior, "%s: aboard it" % label)
	t.assert_true(root.save_now(), "%s: it saves" % label)
	var saved_name := ship.name
	_drop(t, root)
	var again := _scene(t, save_path)
	await t.wait_process_frames(2)
	var back: Ship = again.fleet.named(saved_name)
	t.assert_not_null(back, "%s: the save brings it back" % label)
	if back != null:
		t.assert_eq(ShipLibrary.rows_text(back.grid), ShipLibrary.rows_text(grid), "%s: as it was built" % label)
		t.assert_eq(back.launch_blueprint.ship_name, ship_name, "%s: with its name" % label)
		t.assert_same(again.aboard, back, "%s: and you aboard it" % label)
	_drop(t, again)

static func _scene(t: GutTest, save_path: String) -> Node:
	var root: Node = load(SCENE).instantiate()
	root.save_enabled = true
	root.save_path = save_path
	t.add_child(root)
	return root

static func _drop(t: GutTest, root: Node) -> void:
	t.remove_child(root)
	root.free()
