extends GutTest

## ShipPlan (docs/superpowers/specs/2026-10-09-ship-designer-design.md §4):
## a ship drawn as a deck plan and back, exactly.

var _cat: BlockCatalog

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func test_every_block_has_one_base_token():
	var ids: Array = _cat.ids()
	for id in ids:
		assert_true(ShipPlan.BASE.has(StringName(id)), "%s has a base token" % id)
	for block in ShipPlan.BASE:
		assert_true(_cat.has(block), "%s, a base token's block, is in data/blocks" % block)
	var tokens := {}
	for block in ShipPlan.BASE:
		assert_false(tokens.has(ShipPlan.BASE[block]), "%s is one block's token" % ShipPlan.BASE[block])
		tokens[ShipPlan.BASE[block]] = true

func test_every_pair_has_exactly_one_token():
	for block in ShipPlan.BASE:
		for o in BlockOrientation.COUNT:
			var token := ShipPlan.default_token(block, o)
			assert_eq(ShipPlan.default_pair(token), [block, o], "%s %d is %s and back" % [block, o, token])

func test_the_rcs_arrows():
	assert_eq(ShipPlan.default_token(&"rcs", 8), "R<")
	assert_eq(ShipPlan.default_token(&"rcs", 12), "R>")
	assert_eq(ShipPlan.default_token(&"rcs", 16), "R^")
	assert_eq(ShipPlan.default_token(&"rcs", 20), "Rv")
	assert_eq(ShipPlan.default_token(&"rcs", 4), "Rb")
	assert_eq(ShipPlan.default_token(&"rcs", 0), "R")
	assert_eq(ShipPlan.default_token(&"rcs", 9), "R9")

func test_a_numbered_arrow_is_not_a_token_and_hints_the_arrow():
	assert_eq(ShipPlan.default_pair("R8"), [])
	assert_eq(ShipPlan.hint("R8"), "R<")

func test_orientation_zero_is_never_written():
	assert_eq(ShipPlan.default_pair("W0"), [])
	assert_eq(ShipPlan.hint("W0"), "W")
	assert_eq(ShipPlan.default_token(&"hull_wedge", 3), "W3")

func test_nonsense_is_no_token_and_no_hint():
	assert_eq(ShipPlan.default_pair("Zz"), [])
	assert_eq(ShipPlan.hint("Zz"), "")
	assert_eq(ShipPlan.default_pair("H24"), [])

const HEAD := "ship   small\nname   Small\ndesc   A test.\n"

## `body` under the three header lines: its first line is line 4.
func _parse(body: String) -> Dictionary:
	return ShipPlan.parse(HEAD + body, _cat)

func _block(grid: ShipGrid, c: Vector3i) -> Array:
	var b := grid.get_block(c)
	return [b.block_id, b.orientation]

func _refused(found: Dictionary, at: String, says: String) -> void:
	assert_true(found.has("error"), "refused")
	if found.has("error"):
		assert_string_starts_with(found["error"], at)
		assert_string_contains(found["error"], says)

func test_a_small_plan_reads():
	var found := _parse("\ndeck y=0    x: 0 .. 2\nz -1  .  R<  W3\nz 0   H  D   .\n")
	assert_false(found.has("error"), str(found.get("error", "")))
	assert_eq(found["id"], &"small")
	assert_eq(found["name"], "Small")
	assert_eq(found["description"], "A test.")
	var grid: ShipGrid = found["grid"]
	assert_eq(grid.size(), 4)
	assert_eq(_block(grid, Vector3i(1, 0, -1)), [&"rcs", 8])
	assert_eq(_block(grid, Vector3i(2, 0, -1)), [&"hull_wedge", 3])
	assert_eq(_block(grid, Vector3i(0, 0, 0)), [&"hull", 0])
	assert_eq(_block(grid, Vector3i(1, 0, 0)), [&"deck", 0])

func test_two_storeys():
	var found := _parse("deck y=1  x: 1 .. 1\nz 0  K\ndeck y=0  x: 0 .. 2\nz 0  H D H\n")
	assert_eq((found["grid"] as ShipGrid).size(), 4)
	assert_eq(_block(found["grid"], Vector3i(1, 1, 0)), [&"core", 0])

func test_comments_and_blank_lines_are_ignored():
	var found := _parse("# the hold\n\ndeck y=0  x: 0 .. 1   # one storey\nz 0  H D  # bow\n")
	assert_eq((found["grid"] as ShipGrid).size(), 2)

func test_crlf_and_tabs_read_the_same():
	var lf := _parse("deck y=0  x: 0 .. 1\nz 0  H  D\n")
	var crlf := ShipPlan.parse((HEAD + "deck y=0\tx: 0 .. 1\nz 0\tH\tD\n").replace("\n", "\r\n"), _cat)
	assert_false(crlf.has("error"), str(crlf.get("error", "")))
	assert_eq(ShipLibrary.rows_text(crlf["grid"]), ShipLibrary.rows_text(lf["grid"]))
	assert_eq(crlf["description"], "A test.")

func test_an_empty_row_is_fine():
	var found := _parse("deck y=0  x: 0 .. 1\nz 0  H D\nz 1  . .\nz 2  H D\n")
	assert_eq((found["grid"] as ShipGrid).size(), 4)

func test_a_legend_adds_a_token():
	var found := _parse("legend\n  X  fairing_half 2\ndeck y=0  x: 0 .. 1\nz 0  H X\n")
	assert_eq(_block(found["grid"], Vector3i(1, 0, 0)), [&"fairing_half", 2])
	assert_eq(found["notes"], [] as Array[String])

func test_a_legend_override_is_said():
	var found := _parse("legend\n  H  armour\ndeck y=0  x: 0 .. 0\nz 0  H\n")
	assert_eq(_block(found["grid"], Vector3i(0, 0, 0)), [&"armour", 0])
	assert_eq(found["notes"].size(), 1)
	assert_string_contains(found["notes"][0], "H is armour 0 here, not hull 0")

func test_a_hash_in_the_name_is_kept():
	var found := ShipPlan.parse("ship   s2\nname   Ship #2\ndesc   Two # three\ndeck y=0  x: 0 .. 0\nz 0  H\n", _cat)
	assert_eq(found["name"], "Ship #2")
	assert_eq(found["description"], "Two # three")

func test_an_unknown_token_is_refused_with_a_hint():
	_refused(_parse("deck y=0  x: 0 .. 1\nz 0  H  R8\n"), "plan:5:9:", "unknown token R8 (write R<)")

func test_an_unknown_token_with_no_hint():
	_refused(_parse("deck y=0  x: 0 .. 1\nz 0  H  Zz\n"), "plan:5:9:", "unknown token Zz")

func test_too_many_cells_is_refused():
	_refused(_parse("deck y=0  x: 0 .. 1\nz 0  H D H\n"), "plan:5:10:", "3 cells for x 0 .. 1, which is 2 wide")

func test_too_few_cells_is_refused():
	_refused(_parse("deck y=0  x: 0 .. 2\nz 0  H D\n"), "plan:5:9:", "2 cells for x 0 .. 2, which is 3 wide")

func test_a_skipped_z_is_refused():
	_refused(_parse("deck y=0  x: 0 .. 0\nz 0  H\nz 2  H\n"), "plan:6:3:", "z 2 skips z 1")

func test_a_repeated_z_is_refused():
	_refused(_parse("deck y=0  x: 0 .. 0\nz 0  H\nz 0  H\n"), "plan:6:3:", "z 0 comes after z 0")

func test_a_storey_drawn_twice_is_refused():
	_refused(_parse("deck y=0  x: 0 .. 0\nz 0  H\ndeck y=0  x: 0 .. 0\nz 1  H\n"), "plan:6:1:", "y=0 is drawn twice: first at line 4")

func test_a_bad_deck_line_is_refused():
	_refused(_parse("deck 0\n"), "plan:4:1:", "deck y=<n>  x: <from> .. <to>")

func test_a_backwards_deck_is_refused():
	_refused(_parse("deck y=0  x: 2 .. 0\n"), "plan:4:1:", "2 .. 0 is backwards")

func test_a_row_before_any_deck_is_refused():
	_refused(_parse("z 0  H\n"), "plan:4:1:", "a row before any deck line")

func test_a_legend_naming_no_block_is_refused():
	_refused(_parse("legend\n  X  nope\n"), "plan:5:6:", "no block called nope in data/blocks")

func test_a_legend_orientation_outside_0_to_23_is_refused():
	_refused(_parse("legend\n  X  hull 24\n"), "plan:5:11:", "orientation 24 is not 0-23")

func test_a_token_twice_in_the_legend_is_refused():
	_refused(_parse("legend\n  X  hull\n  X  deck\n"), "plan:6:3:", "X is in the legend twice")

func test_a_missing_header_is_refused():
	_refused(ShipPlan.parse("ship   s\nname   S\ndeck y=0  x: 0 .. 0\nz 0  H\n", _cat), "plan:1:1:", "no desc line")

func test_a_bad_id_is_refused():
	_refused(ShipPlan.parse("ship   Big Ship\nname   S\ndesc   D\n", _cat), "plan:1:1:", "an id is lower case letters, digits and _")

func test_the_header_comes_first():
	_refused(_parse("deck y=0  x: 0 .. 0\nname   Again\n"), "plan:5:1:", "the header (ship, name, desc) comes before the legend and the decks")

func test_the_file_names_itself_in_errors():
	_refused(ShipPlan.parse(HEAD + "z 0  H\n", _cat, "hauler.plan"), "hauler.plan:4:1:", "a row before any deck line")
