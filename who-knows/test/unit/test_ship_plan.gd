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
