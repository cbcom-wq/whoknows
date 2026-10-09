extends SceneTree

# A ship as a deck plan and back (docs/superpowers/specs/
# 2026-10-09-ship-designer-design.md §4.3): the ship designer's drawing tool.
#
#   godot --headless --path who-knows --script <abs path>/ship_plan.gd -- to-json <plan> <out.json>
#   godot --headless --path who-knows --script <abs path>/ship_plan.gd -- to-plan <id or ship .json> <out.plan>
#
# Paths are absolute or res://. to-json refuses a plan it cannot read, naming
# the line and column, and an out file not named for the plan's id; it does
# not judge whether the ship flies: run ship_check.gd on what it writes.
# to-plan prints any ship in default tokens. Exits 0 when it wrote the file.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or not args[0] in ["to-json", "to-plan"]:
		print("usage   ship_plan.gd -- to-json <plan> <out.json> | to-plan <id or ship .json> <out.plan>")
		quit(1)
		return
	quit(_to_json(args[1], args[2]) if args[0] == "to-json" else _to_plan(args[1], args[2]))

func _to_json(plan_path: String, out: String) -> int:
	if not FileAccess.file_exists(plan_path):
		print("plan    %s: no such file" % plan_path)
		return 1
	var plan := ShipPlan.parse(FileAccess.get_file_as_string(plan_path),
		BlockCatalog.load_from_dir("res://data/blocks"), plan_path.get_file())
	if plan.has("error"):
		print("plan    %s" % plan["error"])
		return 1
	for n in plan["notes"]:
		print("note    %s" % n)
	if out.get_file().get_basename() != String(plan["id"]):
		print("plan    write it to %s.json: a ship file is named for its id" % plan["id"])
		return 1
	var err := ShipLibrary.write(out, plan["id"], plan["name"], plan["description"], plan["grid"])
	if err != OK:
		print("plan    cannot write %s (%s)" % [out, error_string(err)])
		return 1
	print("plan    wrote %s: %d blocks" % [out, (plan["grid"] as ShipGrid).size()])
	return 0

func _to_plan(what: String, out: String) -> int:
	var ship := ShipLibrary.resolve(what)
	if ship.has("error"):
		print("plan    %s" % ship["error"])
		return 1
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		print("plan    cannot write %s (%s)" % [out, error_string(FileAccess.get_open_error())])
		return 1
	f.store_string(ShipPlan.to_text(ship["id"], ship["name"], ship["description"], ship["grid"]))
	f.close()
	print("plan    wrote %s" % out)
	return 0
