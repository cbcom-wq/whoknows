extends GutTest

## The ship library (docs/superpowers/specs/2026-10-02-ship-library-design.md
## §3): ships as JSON files, what a broken file is told, and a written file
## read back.

const FIXTURES := "res://test/fixtures/ships"
const OUT := "user://test_ship_library"

func before_each():
	DirAccess.make_dir_recursive_absolute(OUT)

func after_each():
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT.path_join(f))

func _grid(rows: Array) -> ShipGrid:
	var g := ShipGrid.new()
	for r in rows:
		var i := BlockInstance.new()
		i.block_id = r[3]
		i.orientation = r[4]
		g.set_block(Vector3i(r[0], r[1], r[2]), i)
	return g

func _error_for(lib: ShipLibrary, file: String) -> String:
	for e in lib.errors:
		if e.begins_with(file + ":"):
			return e
	return ""

func _same(a: ShipGrid, b: ShipGrid) -> bool:
	if a.size() != b.size():
		return false
	for c in a.coords():
		if not b.has_block(c) or b.get_block(c).block_id != a.get_block(c).block_id \
				or b.get_block(c).orientation != a.get_block(c).orientation:
			return false
	return true

func test_good_files_load_in_order():
	var lib := ShipLibrary.load_from_dir(FIXTURES)
	assert_eq(lib.ids(), [&"alpha", &"tiny"] as Array[StringName])
	assert_eq(lib.name_of(&"alpha"), "Alpha")
	assert_eq(lib.description_of(&"tiny"), "One block.")
	var g := lib.grid(&"alpha")
	assert_eq(g.size(), 2)
	assert_eq(g.get_block(Vector3i(0, 0, 1)).block_id, &"hull")
	assert_eq(g.get_block(Vector3i(0, 0, 1)).orientation, 4)
	assert_eq(g.get_block(Vector3i(0, 0, 1)).damage, 0.0, "a library ship is intact")
	assert_eq(lib.grid(&"tiny").get_block(Vector3i(-2, 3, 1)).orientation, 17, "any storey")

func test_each_broken_file_is_named_with_its_reason_and_left_out():
	var lib := ShipLibrary.load_from_dir(FIXTURES)
	var why := {
		"bad_json.json": "bad JSON",
		"newer.json": "newer",
		"four_values.json": "row 1 is not",
		"wrong_id.json": "is not its file's name",
		"twice.json": "second block at (0, 0, 0)",
		"half.json": "row 1 is not",
		"turned.json": "row 1 is not",
	}
	for file in why:
		var e := _error_for(lib, file)
		assert_string_contains(e, why[file], "%s says why" % file)
		assert_false(lib.has(StringName(file.get_basename())), "%s is left out" % file)
	assert_eq(lib.errors.size(), why.size())

func test_an_unknown_id_has_no_grid():
	assert_null(ShipLibrary.load_from_dir(FIXTURES).grid(&"nothing"))

func test_a_grid_is_fresh_each_call():
	var lib := ShipLibrary.load_from_dir(FIXTURES)
	lib.grid(&"alpha").clear_block(Vector3i(0, 0, 0))
	lib.grid(&"alpha").get_block(Vector3i(0, 0, 1)).damage = 50.0
	var again := lib.grid(&"alpha")
	assert_eq(again.size(), 2)
	assert_eq(again.get_block(Vector3i(0, 0, 1)).damage, 0.0)

func test_write_then_read_gives_back_the_same_ship():
	var g := _grid([[3, 0, -1, "hull", 9], [-3, -1, 2, "rcs", 20], [0, 2, 0, "core", 0]])
	var path := OUT.path_join("sample.json")
	assert_eq(ShipLibrary.write(path, &"sample", "A \"quoted\" name", "One line.", g), OK)
	var back := ShipLibrary.read(path)
	assert_false(back.has("error"), str(back.get("error", "")))
	assert_eq(back["id"], &"sample")
	assert_eq(back["name"], "A \"quoted\" name")
	assert_eq(back["description"], "One line.")
	assert_true(_same(back["grid"], g), "block for block")

func test_a_written_file_has_one_row_per_line_in_order():
	var g := _grid([[3, 0, -1, "hull", 9], [-3, -1, 2, "rcs", 20], [-3, -1, 1, "core", 0]])
	var path := OUT.path_join("rows.json")
	ShipLibrary.write(path, &"rows", "Rows", "", g)
	var rows := Array(FileAccess.get_file_as_string(path).split("\n")).filter(
		func(line: String) -> bool: return line.strip_edges().begins_with("["))
	assert_eq(rows.size(), 3)
	assert_eq(rows[0].strip_edges(), "[-3, -1, 1, \"core\", 0],")
	assert_eq(rows[1].strip_edges(), "[-3, -1, 2, \"rcs\", 20],")
	assert_eq(rows[2].strip_edges(), "[3, 0, -1, \"hull\", 9]")

func test_reading_a_missing_file_says_so():
	assert_string_contains(ShipLibrary.read(OUT.path_join("nope.json")).get("error", ""), "no such file")
