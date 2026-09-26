class_name SaveGame
extends RefCounted

## The one saved game on disk (docs/superpowers/specs/2026-09-26-saving-design.md
## §8): a JSON file with a header -- the format, the world generators'
## versions, when it was saved and how long you have played -- around the
## parts the scene collects (flight_test.gd capture() and restore()).
##
## Written safely: a .tmp, then the old save becomes .bak, then the .tmp
## becomes the save, so a crash at any point leaves one whole file. Read
## safely: a save that will not parse falls back to .bak, and a bad pair is
## left on disk, never overwritten until a new save succeeds. A format newer
## than this game refuses to load and locks the file against autosaves.

## The shape of the file. Bump it, and add a step to migrate(), whenever a
## part's dictionary changes shape.
const FORMAT := 1
const DEFAULT_PATH := "user://save/game.json"

## Why the last read() came back empty: &"" (it loaded), &"missing",
## &"unreadable" (neither the save nor its .bak parsed) or &"newer".
var status: StringName = &""
## True once a file from a newer game has been seen: write() then refuses.
var locked := false
var path := DEFAULT_PATH

func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path

## Saving is on in the real game and off in headless runs -- tests, probes and
## `--headless` scene loads -- which must never touch the owner's game (§9).
static func enabled_by_default() -> bool:
	return DisplayServer.get_name() != "headless"

## True when the game was launched to start over (`-- --new-game`).
static func new_game_asked() -> bool:
	return OS.get_cmdline_user_args().has("--new-game")

## The generators whose output a save depends on (§8.1).
static func generators() -> Dictionary:
	return {"asteroids": AsteroidRecipe.VERSION, "salvage": SalvageField.VERSION}

func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

## Wraps `parts` in the header and writes it safely. OK, or why not.
func write(parts: Dictionary, play_time: float) -> Error:
	if locked:
		return ERR_FILE_NO_PERMISSION
	var data := parts.duplicate()
	data["format"] = FORMAT
	data["generators"] = generators()
	data["saved_at"] = Time.get_datetime_string_from_system(true)
	data["play_time"] = play_time
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", false, true))
	file.flush()
	var write_err := file.get_error()
	file.close()
	if write_err != OK:
		return write_err
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		err = DirAccess.rename_absolute(path, path + ".bak")
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp, path)

## The saved game, migrated to FORMAT, or {} with `status` saying why not.
func read() -> Dictionary:
	status = &""
	if not exists():
		status = &"missing"
		return {}
	for candidate in [path, path + ".bak"]:
		var data := _parse(candidate)
		if data.is_empty():
			if FileAccess.file_exists(candidate):
				push_error("SaveGame: %s will not parse" % candidate)
			continue
		var format := int(data.get("format", 0))
		if format > FORMAT:
			push_error("SaveGame: %s is format %d, newer than this game's %d; it is left alone" % [
				candidate, format, FORMAT])
			status = &"newer"
			locked = true
			return {}
		return migrate(data)
	status = &"unreadable"
	return {}

## Sets the save aside as .old so the next launch starts over (§9). Nothing in
## the game deletes a save.
func set_aside() -> void:
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".old"):
			DirAccess.remove_absolute(path + ".old")
		DirAccess.rename_absolute(path, path + ".old")
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")

## Brings an older format up to FORMAT, one step at a time. Format 1 is the
## first, so there is nothing to do yet.
static func migrate(data: Dictionary) -> Dictionary:
	return data

static func _parse(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	# An instance parse, so a bad file is our error to report, not the engine's.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
