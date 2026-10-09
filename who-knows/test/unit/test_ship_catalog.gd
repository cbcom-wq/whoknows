extends GutTest

## Every ship in data/ships (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §7.1): it loads, breaks no rule, has its
## note, and is usable -- the owner's rule, 2026-10-02: boarded, flown, walked
## and saved, in the real flight scene. A new ship is checked here without
## anyone writing a test for it.

const SCENE := "res://scenes/flight_test.tscn"
const PATH := "user://test_ship_catalog/game.json"

var _library: ShipLibrary
var _cat: BlockCatalog
var _real_save_time := 0

func before_all():
	_library = ShipLibrary.load_from_dir()
	_cat = BlockCatalog.load_from_dir("res://data/blocks")
	_real_save_time = _modified(SaveGame.DEFAULT_PATH)

func after_all():
	assert_eq(_modified(SaveGame.DEFAULT_PATH), _real_save_time, "the owner's real save is untouched")

func after_each():
	for action in [&"move_forward", &"move_back"]:
		Input.action_release(action)
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

static func _modified(file_path: String) -> int:
	return FileAccess.get_modified_time(file_path) if FileAccess.file_exists(file_path) else 0

func _scene() -> Node:
	var root: Node = load(SCENE).instantiate()
	root.save_enabled = true
	root.save_path = PATH
	add_child(root)
	return root

func _drop(root: Node) -> void:
	remove_child(root)
	root.free()

func test_every_ship_loads():
	assert_eq(_library.errors, [] as Array[String])
	assert_gt(_library.ids().size(), 0)

func test_every_ship_breaks_no_rule():
	for id in _library.ids():
		var found := ShipRules.check(_library.grid(id), _cat)
		assert_eq(found["rules"], [], "%s breaks: %s" % [id, found["rules"]])

func test_every_ship_has_its_note():
	for id in _library.ids():
		assert_true(FileAccess.file_exists("%s/%s.md" % [ShipLibrary.DIR, id]), "data/ships/%s.md explains it" % id)

func test_every_ship_is_usable():
	for id in _library.ids():
		await _use(id)

## Spawned 300 m off the starter: F8 boards it, a burn moves it and not the
## starter, you stand and walk, and a save brings it back as it was.
func _use(id: StringName) -> void:
	var root := _scene()
	await wait_process_frames(2)
	var starter: Ship = root.get_node("Ship")
	var place := Transform3D(starter.exterior.global_basis, starter.exterior.global_position + Vector3(300, 0, 0))
	var grid := _library.grid(id)
	var ship: Ship = root.fleet.spawn(grid, place, true, "", ShipBlueprint.from_grid(grid, _library.name_of(id)))
	await wait_physics_frames(2)
	assert_true(root.board_nearest(), "%s: F8 boards it" % id)
	assert_same(root.aboard, ship, "%s: aboard it" % id)
	var starter_at := starter.exterior.global_position
	var ship_at := ship.exterior.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(60)
	Input.action_release(&"move_forward")
	assert_gt(ship.exterior.global_position.distance_to(ship_at), 1.0, "%s: a burn moves it" % id)
	assert_almost_eq(starter.exterior.global_position, starter_at, Vector3.ONE * 0.5, "%s: and not the starter" % id)
	# Let the controls see the key go before standing: a burn held as you stand
	# latches on, by design.
	await wait_physics_frames(2)
	var director: CameraDirector = root.get_node("CameraDirector")
	director.stand()
	await wait_for_signal(director.transition_finished, 3)
	var avatar: Avatar = root.get_tree().get_first_node_in_group(Avatar.GROUP)
	var from := avatar.global_position
	Input.action_press(&"move_back")
	await wait_physics_frames(60)
	Input.action_release(&"move_back")
	assert_gt(from.distance_to(avatar.global_position), 1.0, "%s: you stand and walk" % id)
	assert_same(avatar.get_parent(), ship.interior, "%s: aboard it" % id)
	assert_true(root.save_now(), "%s: it saves" % id)
	var ship_name := ship.name
	_drop(root)
	var again := _scene()
	await wait_process_frames(2)
	var back: Ship = again.fleet.named(ship_name)
	assert_not_null(back, "%s: the save brings it back" % id)
	if back != null:
		assert_eq(ShipLibrary.rows_text(back.grid), ShipLibrary.rows_text(grid), "%s: as it was built" % id)
		assert_eq(back.launch_blueprint.ship_name, _library.name_of(id), "%s: with its name" % id)
		assert_same(again.aboard, back, "%s: and you aboard it" % id)
	_drop(again)
