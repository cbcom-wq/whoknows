extends GutTest

## The creature panel (rock creatures spec §7.2), the F10 twin of the F6 spawn
## panel: it opens and shuts, asks for an entry by number once however long
## the key is held, and shuts the other dev panel when it opens.

var _panel: CreaturePanel
var _asked: Array[int] = []

func before_each():
	_asked.clear()
	_panel = CreaturePanel.new()
	add_child_autofree(_panel)
	_panel.entries = ["Skitter", "Maintenance droid"]
	_panel.creature_asked.connect(func(i: int) -> void: _asked.append(i))

func _key(panel: Node, code: Key, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	panel._unhandled_key_input(ev)

func test_f10_opens_and_shuts_it():
	assert_false(_panel.visible)
	_key(_panel, KEY_F10)
	assert_true(_panel.visible)
	assert_eq(_panel.text.split("\n")[0], "CREATURES            F10 closes")
	assert_string_contains(_panel.text, "1  Skitter")
	assert_string_contains(_panel.text, "2  Maintenance droid")
	_key(_panel, KEY_F10)
	assert_false(_panel.visible)

func test_shut_the_number_keys_do_nothing():
	_key(_panel, KEY_1)
	_key(_panel, KEY_2)
	assert_eq(_asked, [] as Array[int])
	assert_false(_panel.visible)

func test_open_2_asks_for_the_second_entry_once_even_held():
	_key(_panel, KEY_F10)
	_key(_panel, KEY_2)
	_key(_panel, KEY_2, true)
	_key(_panel, KEY_2, true)
	assert_eq(_asked, [1] as Array[int])

func test_a_number_past_the_entries_asks_nothing():
	_key(_panel, KEY_F10)
	_key(_panel, KEY_3)
	assert_eq(_asked, [] as Array[int])

func test_say_shows_on_the_last_line():
	_panel.say("Skitter x3 on the rock")
	var lines := _panel.text.split("\n")
	assert_eq(lines[lines.size() - 1], "Skitter x3 on the rock")

func test_opening_one_dev_panel_shuts_the_other():
	var spawn := SpawnPanel.new()
	add_child_autofree(spawn)
	var asked_ships: Array[int] = []
	spawn.spawn_asked.connect(func(i: int) -> void: asked_ships.append(i))
	spawn.entries = ["Starter shuttle"]
	_key(spawn, KEY_F6)
	assert_true(spawn.visible)
	_key(_panel, KEY_F10)
	assert_true(_panel.visible)
	assert_false(spawn.visible, "opening the creatures shut the spawn panel")
	_key(spawn, KEY_1)
	_key(_panel, KEY_1)
	assert_eq(asked_ships, [] as Array[int], "the shut panel asks nothing")
	assert_eq(_asked, [0] as Array[int])
	_key(spawn, KEY_F6)
	assert_true(spawn.visible)
	assert_false(_panel.visible, "and the other way round")
