extends GutTest

## The 400-block fixture (docs/superpowers/specs/2026-10-09-ship-designer-design.md
## §7.4, §9): the biggest a ship may be passes the rules and is usable, and
## stays within what was measured on 2026-10-09 (the rules 0.3 s, a spawn
## 1.2 s, a save 42 KB), each pinned with room to spare. The spawn's freeze is
## accepted for now (the owner, 2026-10-09); this guard fails if it grows.

const ShipUse := preload("res://test/unit/helpers/ship_use.gd")
const PLAN := "res://test/fixtures/ships/big.plan"
const FILE := "res://test/fixtures/ships/big.json"
const SAVE := "user://test_big_ship/game.json"
const RULES_MS := 3000
const SPAWN_MS := 3000
const SAVE_BYTES := 256 * 1024

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func after_each():
	for action in [&"move_forward", &"move_back"]:
		Input.action_release(action)
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)

func _grid() -> ShipGrid:
	return ShipLibrary.read(FILE)["grid"]

func test_it_is_as_big_as_a_ship_may_be_and_its_plan():
	var ship := ShipLibrary.read(FILE)
	assert_false(ship.has("error"), str(ship.get("error", "")))
	assert_eq((ship["grid"] as ShipGrid).size(), ShipRules.MOST_BLOCKS)
	var plan := ShipPlan.parse(FileAccess.get_file_as_string(PLAN), _cat, "big.plan")
	assert_eq(ShipLibrary.rows_text(plan["grid"]), ShipLibrary.rows_text(ship["grid"]), "big.json is big.plan")

func test_its_plan_prints_back_exactly():
	var text := FileAccess.get_file_as_string(PLAN).replace("\r\n", "\n")
	var plan := ShipPlan.parse(text, _cat, "big.plan")
	assert_eq(ShipPlan.to_text(plan["id"], plan["name"], plan["description"], plan["grid"]), text)

func test_it_breaks_no_rule_in_time():
	var t := Time.get_ticks_msec()
	var found := ShipRules.check(_grid(), _cat)
	var ms := Time.get_ticks_msec() - t
	assert_eq(found["rules"], [])
	assert_lt(ms, RULES_MS, "the rules took %d ms" % ms)

func test_one_more_block_is_too_big():
	var grid := _grid()
	var inst := BlockInstance.new()
	inst.block_id = &"hull"
	grid.set_block(Vector3i(3, 1, 0), inst)
	var codes := []
	for r in ShipRules.check(grid, _cat)["rules"]:
		codes.append(r["code"])
	assert_has(codes, &"TOO_BIG")

func test_it_spawns_in_time_and_saves_small():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	await wait_process_frames(2)
	var t := Time.get_ticks_msec()
	var ship: Ship = root.fleet.spawn(_grid(), Transform3D(Basis.IDENTITY, Vector3(0, 0, 600)))
	var ms := Time.get_ticks_msec() - t
	assert_lt(ms, SPAWN_MS, "the spawn took %d ms" % ms)
	await wait_physics_frames(2)
	var bytes := JSON.stringify(ship.to_dict(root.get_node("Universe"))).length()
	assert_lt(bytes, SAVE_BYTES, "its save is %d bytes" % bytes)

func test_it_is_usable():
	await ShipUse.use(self, _grid(), "Big", SAVE, "big")
