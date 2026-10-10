extends SceneTree
## Loads every game script and scene and reports the ones that fail to parse or
## load. play.bat runs it before the game starts, after the editor pass has
## rebuilt the global class cache:
##   Godot --headless --path <project> --script res://tools/check_scripts.gd
## Exits 0 when everything loads, 1 when anything fails. The test and addon
## folders are not shipped with the game, so they are not checked here.

const SKIPPED_FOLDERS := ["test", "addons"]


func _init() -> void:
	var failed := 0
	var files := _project_files("res://")
	for path in files:
		if path == get_script().resource_path:
			continue  # reloading this running script would break the check
		if not _loads(path):
			failed += 1
			printerr("CHECK FAILED: " + path)
	print("checked ", files.size(), " files, ", failed, " failed")
	quit(1 if failed > 0 else 0)


## A script with a parse error still loads as an object, so a .gd is checked by
## reloading it and reading the error. Scenes are checked by loading them.
func _loads(path: String) -> bool:
	if path.ends_with(".gd"):
		var script := load(path) as GDScript
		return script != null and script.reload() == OK
	return load(path) != null


## Every .gd and .tscn under dir, skipping hidden and skipped folders.
func _project_files(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd") or name.ends_with(".tscn"):
			found.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and not SKIPPED_FOLDERS.has(sub):
			found.append_array(_project_files(dir.path_join(sub)))
	return found
