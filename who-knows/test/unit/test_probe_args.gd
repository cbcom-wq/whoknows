extends GutTest

## A probe's command line (ship designer spec §7.2): its own arguments, and
## --ship <id or ship file> anywhere among them.

func test_no_ship():
	var args := PackedStringArray(["C:/out"])
	assert_eq(ProbeArgs.ship(args), "")
	assert_eq(ProbeArgs.positional(args), args)

func test_a_ship_after_the_out_folder():
	var args := PackedStringArray(["C:/out", "--ship", "hauler"])
	assert_eq(ProbeArgs.ship(args), "hauler")
	assert_eq(ProbeArgs.positional(args), PackedStringArray(["C:/out"]))

func test_a_ship_first():
	var args := PackedStringArray(["--ship", "res://test/fixtures/ships/big.json", "C:/out", "res://scenes/x.tscn"])
	assert_eq(ProbeArgs.ship(args), "res://test/fixtures/ships/big.json")
	assert_eq(ProbeArgs.positional(args), PackedStringArray(["C:/out", "res://scenes/x.tscn"]))

func test_a_dangling_ship_flag_names_nothing():
	var args := PackedStringArray(["C:/out", "--ship"])
	assert_eq(ProbeArgs.ship(args), "")
	assert_eq(ProbeArgs.positional(args), PackedStringArray(["C:/out"]))
