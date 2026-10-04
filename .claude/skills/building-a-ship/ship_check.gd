extends SceneTree

# The rules on one ship file, fast, with no scene and no window: the designer's
# loop (docs/superpowers/specs/2026-10-02-ship-library-design.md §4.3).
#
#   godot --headless --path who-knows --script <abs path>/ship_check.gd -- <ship .json>
#
# The ship file is an absolute path or a res:// one, named for its id. Prints
# each rule broken, with its cell, then the notes; exits 0 when no rule is
# broken, and 1 when one is or the file will not load.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage   ship_check.gd -- <absolute or res:// path to a ship .json>")
		quit(1)
		return
	var path: String = args[0]
	if not path.begins_with("res://") and not path.is_absolute_path():
		print("load    %s: give an absolute path or a res:// one" % path)
		quit(1)
		return
	var ship := ShipLibrary.read(path)
	if ship.has("error"):
		print("load    %s" % ship["error"])
		quit(1)
		return
	var grid: ShipGrid = ship["grid"]
	print("ship    %s: %s, %d blocks" % [ship["id"], ship["name"], grid.size()])
	var found := ShipRules.check(grid, BlockCatalog.load_from_dir("res://data/blocks"))
	print("rules   %d broken" % found["rules"].size())
	for r in found["rules"]:
		print("  <--   %s %s%s" % [r["code"], r["text"], "" if r["cell"] == null else " at %s" % [r["cell"]]])
	for n in found["notes"]:
		print("note    %s %s" % [n["code"], n["text"]])
	quit(0 if found["rules"].is_empty() else 1)
