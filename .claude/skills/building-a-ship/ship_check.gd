extends SceneTree

# The rules on one ship file, fast, with no scene and no window: the designer's
# loop (docs/superpowers/specs/2026-10-02-ship-library-design.md §4.3).
#
#   godot --headless --path who-knows --script <abs path>/ship_check.gd -- <ship .json>
#
# The ship file is an absolute path or a res:// one, named for its id. Prints
# each rule broken, with its cell, then the notes, then a lift line (vertical
# thrust over mass, against a 7 m/s2 world), then a ramp line per airlock
# (its landing ramp, or NOT BOARDABLE ON A WORLD: AirlockAlcove.way_up_for says
# NONE, and that airlock refuses the step out on a world), measured over the
# plane its landing legs stand on, then a legs line (how many fit -- 4 wanted,
# ONLY n FIT under that -- each mount and length, and the feet's plane), then a
# doors line (every room's doorway a body-wide way through, or BLOCKED); exits 0
# when no rule is broken and no doorway blocked, and 1 when one is or the file
# will not load.

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
	# Lift off a world (desert world phase 0): vertical thrust over mass, against
	# the heaviest planet's pull. The CANNOT_LIFT rule fails it; this shows by how much.
	var catalog := BlockCatalog.load_from_dir("res://data/blocks")
	var stats := ShipStats.compute(grid, catalog)
	var pull: float = WorldRecipe.GRAVITY[WorldRecipe.Kind.PLANET].y
	var lift: float = stats.thrust_budget[&"vertical"] / maxf(stats.total_mass_kg, 1.0)
	print("lift    %.1f m/s2 up, %.2f× a %.0f m/s2 world's pull (needs ×%.1f)" % [
		lift, lift / pull, pull, ShipRules.LIFT_MARGIN])
	# Boardable on a world (desert world phase 0, Task 14): the landing ramp each
	# airlock's outer hatch needs, or why it has none, measured to where its legs
	# stand. The NOT_BOARDABLE rule fails one with no way up; this prints the numbers.
	var stance := Ship.stance_depth_of(grid, catalog)
	for c: Vector3i in grid.coords():
		if grid.get_block(c).block_id == AirlockSite.AIRLOCK_ID:
			var words := "no outer hatch (it cannot cycle)" if AirlockSite.hatch_normal(grid, c) == Vector3i.ZERO \
				else AirlockAlcove.ramp_words(AirlockAlcove.ramp_plan(grid, c, stance))
			print("ramp    airlock %s: %s" % [c, words])
	# Landing legs (desert world phase 0, Task 15): four, one per quadrant, clear
	# of every ramp's path and every engine and downward thruster; their feet set
	# the plane the ramps above are measured to, deep enough that the lowest
	# hanging look (a belly turret parked, a flood's housing) clears the ground
	# by LandingLegs.HANG_CLEAR (the owner, 2026-11-05). FEW_LEGS fails fewer than four; this prints them.
	print("legs    %s" % LandingLegs.plan_words(grid, LandingLegs.plan(grid, NAN, catalog)))
	_doors.call_deferred(grid, catalog, found["rules"].is_empty())

## Every room's doorway leaves a body-wide way through it
## (InteriorBuilder.blocked_doorways; the Warden's bunk room did not, 2026-11-07).
## The interior must be in the tree to be measured, so this runs a frame on.
## A blocked doorway fails the check like a broken rule.
func _doors(grid: ShipGrid, catalog: BlockCatalog, rules_ok: bool) -> void:
	var builder := InteriorBuilder.new()
	root.add_child(builder)
	builder.bind(grid, catalog)
	builder.rebuild()
	var blocked := builder.blocked_doorways()
	print("doors   %d rooms, every doorway %.1f m clear%s" % [builder.layout().rooms().size(),
		InteriorBuilder.DOORWAY_CLEAR_WIDTH, "" if blocked.is_empty() else "  <-- BLOCKED %s" % [
			blocked.map(func(b): return "%s %s by %s" % [b["coord"], b["normal"], b["by"].get_parent().name])]])
	builder.free()
	quit(0 if rules_ok and blocked.is_empty() else 1)
