extends GutTest

## The save file (docs/superpowers/specs/2026-09-26-saving-design.md §8, §9):
## written safely, read with a fallback, a newer format left alone, and never
## the owner's real save in a test.

const DIR := "user://test_save_game"
const PATH := DIR + "/game.json"

func before_each():
	_clear()

func after_each():
	_clear()

func _clear() -> void:
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

func _write_text(file_path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_headless_runs_save_nothing_by_default():
	assert_false(SaveGame.enabled_by_default())

func test_a_missing_save_reads_as_a_new_game():
	var sg := SaveGame.new(PATH)
	assert_false(sg.exists())
	assert_eq(sg.read(), {})
	assert_eq(sg.status, &"missing")

func test_what_is_written_reads_back_with_its_header():
	var sg := SaveGame.new(PATH)
	assert_eq(sg.write({"world": {"seed": 99}}, 12.5), OK)
	var data := SaveGame.new(PATH).read()
	assert_eq(int(data["world"]["seed"]), 99)
	assert_eq(int(data["format"]), SaveGame.FORMAT)
	assert_eq(float(data["play_time"]), 12.5)
	assert_eq(int(data["generators"]["asteroids"]), AsteroidRecipe.VERSION)
	assert_eq(int(data["generators"]["salvage"]), SalvageField.VERSION)
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "the temp file became the save")

func test_the_save_before_is_kept_as_a_backup():
	var sg := SaveGame.new(PATH)
	sg.write({"n": 1}, 0.0)
	sg.write({"n": 2}, 0.0)
	assert_true(FileAccess.file_exists(PATH + ".bak"))
	assert_eq(int(SaveGame._parse(PATH + ".bak")["n"]), 1)
	assert_eq(int(sg.read()["n"]), 2)

func test_a_truncated_save_falls_back_to_its_backup():
	var sg := SaveGame.new(PATH)
	sg.write({"n": 1}, 0.0)
	sg.write({"n": 2}, 0.0)
	_write_text(PATH, "{\"n\": 3, \"wor")
	var data := SaveGame.new(PATH).read()
	assert_eq(int(data["n"]), 1)
	assert_push_error("will not parse")

func test_two_bad_files_start_a_new_game_and_stay_on_disk():
	_write_text(PATH, "not json")
	_write_text(PATH + ".bak", "nor this")
	var sg := SaveGame.new(PATH)
	assert_eq(sg.read(), {})
	assert_eq(sg.status, &"unreadable")
	assert_true(FileAccess.file_exists(PATH))
	assert_true(FileAccess.file_exists(PATH + ".bak"))
	assert_push_error(2, "both files fail to parse")

func test_a_newer_format_is_refused_and_never_written_over():
	_write_text(PATH, JSON.stringify({"format": SaveGame.FORMAT + 1, "n": 7}))
	var sg := SaveGame.new(PATH)
	assert_eq(sg.read(), {})
	assert_eq(sg.status, &"newer")
	assert_true(sg.locked)
	assert_eq(sg.write({"n": 8}, 0.0), ERR_FILE_NO_PERMISSION)
	assert_eq(int(SaveGame._parse(PATH)["n"]), 7, "left alone")
	assert_push_error("newer than this game")

## Many ships (docs/superpowers/specs/2026-10-02-many-ships-design.md §6.1):
## format 1's one ship becomes the first of a list, named Ship, with you
## aboard it.
func test_a_format_1_save_becomes_one_ship_named_ship_with_you_aboard():
	var old := {"format": 1, "ship": {"layout": {"cells": []}, "hull": {}}, "avatar": {"mode": "walking"}}
	var now := SaveGame.migrate(old)
	assert_eq(int(now["format"]), 2)
	assert_false(now.has("ship"))
	assert_eq(now["ships"].size(), 1)
	assert_eq(now["ships"][0]["name"], "Ship")
	assert_eq(now["ships"][0]["hull"], {})
	assert_eq(now["aboard"], "Ship")
	assert_eq(now["fleet"], {"next": 2})
	assert_eq(now["avatar"], old["avatar"], "the rest untouched")
	assert_true(old.has("ship"), "the dictionary passed in is not changed")

func test_a_format_2_save_is_left_as_it_is():
	var d := {"format": 2, "ships": [], "aboard": "Ship", "fleet": {"next": 2}}
	assert_eq(SaveGame.migrate(d), d)

func test_starting_over_sets_the_save_aside():
	var sg := SaveGame.new(PATH)
	sg.write({"n": 1}, 0.0)
	sg.write({"n": 2}, 0.0)
	sg.set_aside()
	assert_false(sg.exists())
	assert_eq(int(SaveGame._parse(PATH + ".old")["n"]), 2)
