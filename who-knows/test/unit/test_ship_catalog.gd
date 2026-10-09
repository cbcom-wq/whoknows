extends GutTest

## Every ship in data/ships (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §7.1): it loads, breaks no rule, has its
## note, and is usable -- the owner's rule, 2026-10-02: boarded, flown, walked
## and saved, in the real flight scene. A new ship is checked here without
## anyone writing a test for it.

const ShipUse := preload("res://test/unit/helpers/ship_use.gd")
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
		await ShipUse.use(self, _library.grid(id), _library.name_of(id), PATH, String(id))
