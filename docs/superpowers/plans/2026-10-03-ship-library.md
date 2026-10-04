# Ship Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ships become files in `data/ships/` (the starter moved there), one set of rules
(`ShipRules`) holds every ship to the owner's "usable" bar through a catalog test, the probe and a
fast `ship_check.gd`, and an F6 panel spawns a library ship near you, arriving out of warp.

**Architecture:** `ShipLibrary` reads and writes JSON ship files; `ShipRules` is a pure checker
built on the planners the game already has (`InteriorLayout`, `HullLayout`, `DeckPaths`,
`ShipStats`, `ShipDamage`, `ShipCrew`). `WarpArrival` is a reusable node that flies a ghosted hull
in and frees itself; `SpawnSpot` picks a clear spot; `SpawnPanel` is a `Label` that only asks, and
the flight scene does the work through `Fleet`.

**Tech Stack:** Godot 4.5.1 (GDScript), GUT 9.5 (headless), PowerShell on Windows.

**Spec:** `docs/superpowers/specs/2026-10-02-ship-library-design.md`, as amended in its §11 on
2026-10-03. Read §11 first: it changes the F-key, `NO_STAND`, `CUT_OFF`'s start, replaces `FRAGILE`
with `NO_PIECES`, and corrects three broken copies.

## Global Constraints

- **Where:** branch `ship-library` in `D:/git/whoknows-ship-library` (`main` merged at `15c1bb1`).
  Never work in `D:/git/whoknows`. Godot is
  `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe`
  (`$godot` below). The `.godot` import cache exists (imported 2026-10-03).
- **Running tests:** targeted files only while building (the owner's rule); ask the owner before
  any full-suite run. `-gtest` runs the whole suite with this `.gutconfig.json`; use `-gselect`.
  Every test step uses the helper written in Task 1 Step 0: `& $env:TEMP\sl_run.ps1 <names>`,
  which passes only when every file's GUT run exits 0, prints `All tests passed` and ran at least
  one test. Read any `SCRIPT ERROR` lines it prints.
- **A ship file** is `data/ships/<id>.json` plus `data/ships/<id>.md`: keys `id`, `name`,
  `description`, `format` (1), `cells`; each row `[x, y, z, block, orientation]` on its own line,
  sorted by x, then y, then z; no damage column; `y` any integer; the id is the file's name.
- **Rule codes, exactly:** `UNKNOWN_BLOCK`, `VALIDATOR`, `POWER_MARGIN`, `CANNOT_THRUST`,
  `CANNOT_BRAKE`, `NO_AUTHORITY`, `UNBALANCED`, `CRIPPLED`, `NO_POD`, `NO_STAND`, `NO_AIRLOCK`,
  `CUT_OFF`, `WINDOW_UNMATCHED`, `DROID`, `NO_PIECES`. Notes: `RCS_BLOCKED`, `FEEL`, `SIZE`. Power
  made must be > power drawn × 1.1; imbalance under a full burn < 5% of that axis's authority.
- **The spawn:** F6 toggles the panel; 1–9 spawn; Delete removes. `SpawnSpot`: 200 m, then 400 m;
  45° steps; 60 m clear of every ship; rocks by `WarpPlan.rock_near`; led by your velocity ×
  `WarpArrival.DURATION`. Panel strings, exactly: `SPAWNED <ship> · <library name> · <n> m away`,
  `WARP ENGAGED`, `A SHIP IS ARRIVING`, `THE FLEET IS FULL`, `NO CLEAR SPOT NEAR`,
  `REMOVED <ship> · <library name>`, `NO SPAWNED SHIP`, `YOU ARE ABOARD IT`.
- **The arrival:** `DURATION` 1.5 s, `FROM` 2000 m, distance `FROM × (1 − t)³`, `WAKE_WIDTH` 0.6 m,
  `WAKE_SECONDS` 0.15 s, flash 1.0 → 1.6 of the hull's bounds over `FLASH_TIME` 0.4 s. Engine
  `StandardMaterial3D`, unshaded, additive; colour `SpacePalette.WARP`; render layer 1; children
  of the hull; the hull ghosted (frozen kinematic, layer and mask 0) until it stops. Busy reason
  `"a ship arriving"`.
- **Style guide (binding):** colours only from the palettes (no `Color(` or `Color.X` in
  `src/flight/warp_arrival.gd`, which joins `PAINTING_FILES`); no new shader; judge looks by
  rendering the real scene and showing the owner.
- **Floating origin:** anything outside joins `Universe.EXTERIOR_SPACE` or is a child of something
  that does; an engine position kept across frames follows the shift.
- **Every ship is usable:** a library ship must board, fly, walk and save (`test_ship_catalog.gd`).
- **Windowed scripts** that load `flight_test.tscn` set `save_enabled = false` before `add_child`.
- **No `#` comments in `.tscn`/`.tres`** (this plan edits none).
- **Comments and names** read like the code round them: `##` doc comments in plain sentences,
  spec sections cited.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **The floating origin shifts mid-arrival** (you drift across a 2 km line on a spacewalk, or fly
   fast as it spawns): the ship must still land on its spot in the world, not 2 km off. Pinned by
   Task 6's `test_a_shift_mid_arrival_carries_the_spot`.
2. **A spawn while cruising:** at 120 m/s you cover 180 m in the 1.5 s arrival; the ship must land
   ahead of where you will be, not in your path. Task 9's
   `test_spawned_while_cruising_it_lands_ahead_of_where_you_will_be`.
3. **A held or doubled number key:** key repeats must not spawn more ships, and a second press
   while one arrives is refused with `A SHIP IS ARRIVING`. Task 9's `test_a_held_1_spawns_one_ship`
   and `test_a_second_spawn_waits_for_the_first_to_arrive`.
4. **An agent-written file with a repeated cell, a fractional number or an orientation of 24:** a
   load error naming the file and row, never a silently overwritten block or a crash in
   `BlockOrientation`. Task 1's fixtures `twice`, `half` and `turned`.
5. **Delete on a spacewalk when the only spawned ship is your suit's:** `YOU ARE ABOARD IT`, and
   the ship under you is never freed. Task 9's
   `test_on_a_spacewalk_tied_to_the_only_spawned_ship_delete_says_so`.

---

## File map

| File | Does | Task |
|---|---|---|
| `who-knows/src/ship/ship_library.gd` (new) | reads, lists and writes ship files | 1 |
| `who-knows/test/fixtures/ships/*.json` (new) | good and broken files for the library test | 1 |
| `who-knows/test/unit/test_ship_library.gd` (new) | the library | 1, 2 |
| `who-knows/data/ships/starter.json`, `starter.md` (new) | the starter, and why it is built so | 2 |
| `who-knows/scenes/flight_test.gd` | `library`; `_starter_grid()` reads it; spawn and remove; F6 wiring | 2, 7, 9 |
| `who-knows/test/unit/test_starter_shuttle.gd` | pins the starter file | 2 |
| `who-knows/src/ship/ship_rules.gd` (new) | the rules and notes | 3 |
| `who-knows/test/unit/test_ship_rules.gd` (new) | the starter passes; a broken copy per rule | 3 |
| `.claude/skills/building-a-ship/ship_check.gd` (new) | the rules on one file, headless | 4 |
| `.claude/skills/building-a-ship/ship_probe.gd` | the `rules` and `note` lines | 4 |
| `who-knows/test/unit/test_ship_catalog.gd` (new) | every library ship: loads, no rules, a note, usable | 5 |
| `who-knows/src/world/space_palette.gd` | `WARP` | 6 |
| `who-knows/src/flight/warp_arrival.gd` (new) | the arrival | 6 |
| `who-knows/test/unit/test_warp_arrival.gd` (new) | the arrival | 6 |
| `who-knows/test/unit/test_visual_style_rules.gd` | `warp_arrival.gd` in `PAINTING_FILES` | 6 |
| `who-knows/src/ship/fleet.gd` | `arriving`, `busy`; `nearest` and sleep skip arrivals | 7 |
| `who-knows/src/ship/suit_tie.gd` | the tie skips arrivals | 7 |
| `who-knows/test/unit/test_fleet.gd`, `test_floating_origin_scene.gd` | arrivals in the fleet; covered | 7 |
| `who-knows/src/ship/spawn_spot.gd` (new), `test/unit/test_spawn_spot.gd` (new) | where a spawn lands | 8 |
| `who-knows/src/ui/spawn_panel.gd` (new), `test/unit/test_spawn_panel.gd` (new) | the F6 panel | 9 |
| `who-knows/test/probes/fleet_play.gd` | spawns through the panel | 10 |
| `who-knows/test/probes/arrival_render.gd` (new) | the arrival's renders and fps | 10 |
| skill `SKILL.md`, `reference.md`; `CLAUDE.md`; `docs/design/visual-style.md`; the spec | upkeep | 11 |

---

### Task 1: `ShipLibrary`

**Files:**
- Create: `who-knows/src/ship/ship_library.gd`
- Create: `who-knows/test/fixtures/ships/{alpha,tiny,bad_json,newer,four_values,wrong_id,twice,half,turned}.json`
- Test: `who-knows/test/unit/test_ship_library.gd`

**Interfaces:**
- Consumes: `ShipGrid`, `BlockInstance`, `ShipBlueprint.from_grid(grid, name)` (sorted coords),
  `BlockOrientation.COUNT` (24).
- Produces (later tasks rely on these exact names):
  - `class_name ShipLibrary extends RefCounted`
  - `const STARTER := &"starter"`, `const FORMAT := 1`, `const DIR := "res://data/ships"`
  - `var errors: Array[String]`
  - `static func load_from_dir(path: String = DIR) -> ShipLibrary`
  - `static func read(path: String) -> Dictionary` → `{"id": StringName, "name": String,
    "description": String, "grid": ShipGrid}` or `{"error": String}`
  - `func ids() -> Array[StringName]` (sorted, starter first), `func has(id: StringName) -> bool`,
    `func name_of(id: StringName) -> String`, `func description_of(id: StringName) -> String`,
    `func grid(id: StringName) -> ShipGrid` (fresh each call; null for an unknown id)
  - `static func write(path: String, id: StringName, ship_name: String, description: String,
    grid: ShipGrid) -> Error`
  - `static func rows_text(grid: ShipGrid, indent := "") -> String` (the rows as written, joined
    `",\n"`)

- [ ] **Step 0: Write the targeted-test helper (outside the repo)**

Write `$env:TEMP\sl_run.ps1`:

```powershell
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Names)
# Runs each named GUT file on its own (-gselect) and passes only when every run
# exits 0, says "All tests passed" and ran at least one test.
$fail = 0
foreach ($n in $Names) {
    $log = Join-Path $env:TEMP "sl_$n.log"
    & D:\git\whoknows-ship-library\who-knows\run_tests.ps1 "-gselect=$n.gd" *> $log
    $code = $LASTEXITCODE
    $text = Get-Content $log -Raw
    $ran = [regex]::Match($text, '(?m)^Tests\s+(\d+)').Groups[1].Value
    $ok = $code -eq 0 -and $text -match 'All tests passed' -and [int]("0$ran") -gt 0
    $errors = ([regex]::Matches($text, 'SCRIPT ERROR|Parse Error')).Count
    "{0}: {1} (exit {2}, {3} tests, {4} script errors) log {5}" -f $n, $(if ($ok) { 'PASS' } else { 'FAIL' }), $code, $ran, $errors, $log
    if (-not $ok) {
        $fail = 1
        Select-String -Path $log -Pattern '\[Failed\]|FAILED|SCRIPT ERROR|Parse Error' -Context 0, 3 | Select-Object -First 20
    }
}
exit $fail
```

Run: `& $env:TEMP\sl_run.ps1 test_deck_paths`
Expected: `test_deck_paths: PASS (exit 0, 11 tests, 0 script errors)`.

- [ ] **Step 1: Write the fixtures**

`who-knows/test/fixtures/ships/alpha.json`:

```json
{
	"id": "alpha",
	"name": "Alpha",
	"description": "Two blocks, for the library's tests.",
	"format": 1,
	"cells": [
		[0, 0, 0, "core", 0],
		[0, 0, 1, "hull", 4]
	]
}
```

`tiny.json`:

```json
{
	"id": "tiny",
	"name": "Tiny",
	"description": "One block.",
	"format": 1,
	"cells": [
		[-2, 3, 1, "deck", 17]
	]
}
```

`bad_json.json` (cut off on purpose):

```json
{"id": "bad_json", "format": 1, "cells": [[0, 0, 0, "core", 0]
```

`newer.json`: `{"id": "newer", "name": "Newer", "format": 2, "cells": []}`

`four_values.json`: `{"id": "four_values", "format": 1, "cells": [[0, 0, 0, "core"]]}`

`wrong_id.json`: `{"id": "someone_else", "format": 1, "cells": []}`

`twice.json`: `{"id": "twice", "format": 1, "cells": [[0, 0, 0, "core", 0], [0, 0, 0, "hull", 0]]}`

`half.json`: `{"id": "half", "format": 1, "cells": [[0.5, 0, 0, "core", 0]]}`

`turned.json`: `{"id": "turned", "format": 1, "cells": [[0, 0, 0, "core", 24]]}`

- [ ] **Step 2: Write the failing test**

`who-knows/test/unit/test_ship_library.gd`:

```gdscript
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
```

- [ ] **Step 3: Run it to watch it fail**

Run: `& $env:TEMP\sl_run.ps1 test_ship_library`
Expected: FAIL, with `Identifier "ShipLibrary" not declared` (a parse error; the helper flags it).

- [ ] **Step 4: Write `ShipLibrary`**

`who-knows/src/ship/ship_library.gd`:

```gdscript
class_name ShipLibrary
extends RefCounted

## Every ship in the game as a file (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §3): data/ships/<id>.json, one row per
## block, with a Markdown note beside it holding the reasoning. Loaded as
## NpcCatalog loads species. It only reads and writes: whether a ship's blocks
## exist, and whether it flies, is ShipRules'.

## The starter shuttle: first in ids(), and the ship a new game builds.
const STARTER := &"starter"
## The newest file format this game reads.
const FORMAT := 1
const DIR := "res://data/ships"

## Each file that would not load, and why. Those files are left out.
var errors: Array[String] = []

var _ships := {}   # StringName -> {id, name, description, grid}

static func load_from_dir(path: String = DIR) -> ShipLibrary:
	var library := ShipLibrary.new()
	var dir := DirAccess.open(path)
	if dir == null:
		library.errors.append("%s: cannot open the folder" % path)
		return library
	var files := dir.get_files()
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var ship := read(path.path_join(file))
		if ship.has("error"):
			library.errors.append(ship["error"])
		else:
			library._ships[ship["id"]] = ship
	return library

## One ship file: {id, name, description, grid}, or {error} saying what is
## wrong with it (spec §3.2). Its id must be its file's name.
static func read(path: String) -> Dictionary:
	var file := path.get_file()
	if not FileAccess.file_exists(path):
		return {"error": "%s: no such file" % path}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"error": "%s: bad JSON at line %d (%s)" % [file, json.get_error_line(), json.get_error_message()]}
	var d: Variant = json.data
	if not (d is Dictionary):
		return {"error": "%s: not a ship (the file is not one JSON object)" % file}
	var format: Variant = d.get("format")
	if not _whole(format) or int(format) < 1:
		return {"error": "%s: no format (it must say \"format\": %d)" % [file, FORMAT]}
	if int(format) > FORMAT:
		return {"error": "%s: format %d is newer than this game reads (%d)" % [file, int(format), FORMAT]}
	var id := str(d.get("id", ""))
	if id != file.get_basename():
		return {"error": "%s: its id \"%s\" is not its file's name" % [file, id]}
	var cells: Variant = d.get("cells")
	if not (cells is Array):
		return {"error": "%s: no cells" % file}
	var grid := ShipGrid.new()
	for i in (cells as Array).size():
		var row: Variant = cells[i]
		if not _is_row(row):
			return {"error": "%s: row %d is not [x, y, z, block, orientation] (whole numbers, a block name, an orientation 0-%d)"
				% [file, i + 1, BlockOrientation.COUNT - 1]}
		var coord := Vector3i(int(row[0]), int(row[1]), int(row[2]))
		if grid.has_block(coord):
			return {"error": "%s: row %d puts a second block at %s" % [file, i + 1, coord]}
		var inst := BlockInstance.new()
		inst.block_id = StringName(row[3])
		inst.orientation = int(row[4])
		grid.set_block(coord, inst)
	return {"id": StringName(id), "name": str(d.get("name", id)), "description": str(d.get("description", "")),
		"grid": grid}

## Every ship's id, sorted, the starter first.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_ships.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		if a == STARTER or b == STARTER:
			return a == STARTER and b != STARTER
		return String(a) < String(b))
	return out

func has(id: StringName) -> bool:
	return _ships.has(id)

func name_of(id: StringName) -> String:
	return _ships[id]["name"] if has(id) else ""

func description_of(id: StringName) -> String:
	return _ships[id]["description"] if has(id) else ""

## A fresh grid of ship `id`, every block intact, so building a ship never
## touches the library's copy; null for an id it does not have.
func grid(id: StringName) -> ShipGrid:
	if not has(id):
		return null
	var src: ShipGrid = _ships[id]["grid"]
	var out := ShipGrid.new()
	for coord in src.coords():
		out.set_block(coord, src.get_block(coord).duplicate_instance())
	return out

## Writes `grid` to `path` as a ship file (spec §3.1): a row per block on a
## line of its own, sorted as ShipBlueprint sorts, so a diff shows exactly the
## blocks that changed. No damage: a library ship is new.
static func write(path: String, id: StringName, ship_name: String, description: String,
		grid: ShipGrid) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string("{\n\t\"id\": %s,\n\t\"name\": %s,\n\t\"description\": %s,\n\t\"format\": %d,\n\t\"cells\": [\n%s\n\t]\n}\n" % [
		JSON.stringify(String(id)), JSON.stringify(ship_name), JSON.stringify(description), FORMAT,
		rows_text(grid, "\t\t")])
	f.close()
	return OK

## The grid's rows as a ship file writes them, `indent` before each, joined by
## a comma and a new line. The starter's pin hashes this.
static func rows_text(grid: ShipGrid, indent := "") -> String:
	var bp := ShipBlueprint.from_grid(grid, "")
	var lines := PackedStringArray()
	for i in bp.coords.size():
		var c := bp.coords[i]
		lines.append("%s[%d, %d, %d, %s, %d]" % [indent, c.x, c.y, c.z, JSON.stringify(String(bp.block_ids[i])),
			bp.orientations[i]])
	return ",\n".join(lines)

static func _is_row(row: Variant) -> bool:
	if not (row is Array) or (row as Array).size() != 5:
		return false
	for k in [0, 1, 2, 4]:
		if not _whole(row[k]):
			return false
	return row[3] is String and row[3] != "" and int(row[4]) >= 0 and int(row[4]) < BlockOrientation.COUNT

## A JSON number with nothing after the point (JSON numbers arrive as floats).
static func _whole(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v))
```

- [ ] **Step 5: Run it to watch it pass**

Run: `& $env:TEMP\sl_run.ps1 test_ship_library`
Expected: `test_ship_library: PASS (exit 0, 7 tests, 0 script errors)`.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/ship/ship_library.gd who-knows/src/ship/ship_library.gd.uid who-knows/test/fixtures/ships who-knows/test/unit/test_ship_library.gd who-knows/test/unit/test_ship_library.gd.uid
git commit -m "feat: ShipLibrary -- ships as JSON files, one row per block, and what a broken file is told"
```

(Godot writes the `.uid` files on the next run; add whichever exist. The same holds for every new
script below.)

---

### Task 2: The starter moves to `data/ships/`

**Files:**
- Create: `who-knows/data/ships/starter.json` (written by `ShipLibrary.write`), `who-knows/data/ships/starter.md`
- Modify: `who-knows/scenes/flight_test.gd` (header doc, `_ready`, `_starter_grid()`, drop the
  `O_*` constants and `_put`)
- Test: `who-knows/test/unit/test_ship_library.gd`, `who-knows/test/unit/test_starter_shuttle.gd`

**Interfaces:**
- Consumes: Task 1's `ShipLibrary`.
- Produces: `flight_test.gd`'s `var library: ShipLibrary` (loaded first thing in `_ready`, or by
  `_starter_grid()` on a bare instance); `_starter_grid() -> ShipGrid` unchanged in name and
  result.

- [ ] **Step 1: Write the failing tests (the library holds the starter, the code's own)**

Append to `test_ship_library.gd`:

```gdscript
func test_the_library_holds_the_starter_first():
	var lib := ShipLibrary.load_from_dir()
	assert_eq(lib.errors, [] as Array[String])
	assert_eq(lib.ids()[0], ShipLibrary.STARTER)
	assert_eq(lib.name_of(ShipLibrary.STARTER), "Starter shuttle")

## Build order step 1 (spec §3.3): the file is the code's starter, block for
## block. This lives only until _starter_grid() reads the file.
func test_the_library_starter_is_the_code_starter():
	var boot: Node = load("res://scenes/flight_test.gd").new()
	var code: ShipGrid = boot._starter_grid()
	boot.free()
	var file := ShipLibrary.load_from_dir().grid(ShipLibrary.STARTER)
	assert_not_null(file)
	if file != null:
		assert_true(_same(file, code), "the same blocks, turned the same way, and nothing else")
```

Run: `& $env:TEMP\sl_run.ps1 test_ship_library`
Expected: FAIL: `test_the_library_holds_the_starter_first` (`res://data/ships: cannot open the folder`)
and `test_the_library_starter_is_the_code_starter` (null).

- [ ] **Step 2: Write `starter.json` from the code, once**

Write `$env:TEMP\write_starter.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/ships")
	var boot: Node = load("res://scenes/flight_test.gd").new()
	var err := ShipLibrary.write("res://data/ships/starter.json", ShipLibrary.STARTER, "Starter shuttle",
		"Two decks: a bridge with a cockpit pod, five rooms, an airlock aft.", boot._starter_grid())
	boot.free()
	print("starter.json: %s" % error_string(err))
	quit()
```

Run (from `D:\git\whoknows-ship-library`):
`& $godot --headless --path who-knows --script "$env:TEMP\write_starter.gd"`
Expected: `starter.json: OK`; `who-knows/data/ships/starter.json` has 110 rows, the first
`[-3, 0, 1, "hull", 0],`.

Run: `& $env:TEMP\sl_run.ps1 test_ship_library`
Expected: PASS, 9 tests.

- [ ] **Step 3: Pin the file in the starter's own test**

Write `$env:TEMP\starter_hash.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	var g := ShipLibrary.load_from_dir().grid(ShipLibrary.STARTER)
	print("blocks %d hash %s" % [g.size(), ShipLibrary.rows_text(g).sha256_text()])
	quit()
```

Run: `& $godot --headless --path who-knows --script "$env:TEMP\starter_hash.gd"`
Expected: `blocks 110 hash <64 hex digits>`. Put that hash in place of `HASH` below, and append to
`test_starter_shuttle.gd`:

```gdscript
## The starter is a file now (ship library spec §3.3), and this pins it:
## changing the starter means changing these on purpose, with the reason in
## data/ships/starter.md.
func test_the_starter_file_is_pinned():
	assert_eq(_grid.size(), 110)
	assert_eq(ShipLibrary.rows_text(_grid).sha256_text(), "HASH")
```

Run: `& $env:TEMP\sl_run.ps1 test_starter_shuttle`
Expected: PASS (it still reads the code's starter, which the file matches).

- [ ] **Step 4: Commit the file while both exist**

```bash
git add who-knows/data/ships/starter.json who-knows/test/unit/test_ship_library.gd who-knows/test/unit/test_starter_shuttle.gd
git commit -m "feat: the starter shuttle as data/ships/starter.json, matched block for block to the code"
```

- [ ] **Step 5: Write `starter.md`**

`who-knows/data/ships/starter.md` (the reasoning that was `_starter_grid()`'s comments):

```markdown
# Starter shuttle (`starter.json`)

The ship every new game starts in: 110 blocks, 104.7 t. Two decks, the cabin at y = 0 and a solid
equipment deck at y = +1, with fairings outside both. −Z is the bow, +X starboard, +Y up.
`test_starter_shuttle.gd` pins the file and its figures: changing a block means changing that pin
on purpose, with the reason here.

## The cabin (y = 0; art direction spec §3.1)

- **The bridge**, x −1..1 by z −3..−1, behind a canopy row at z = −4, hull wedges on its front
  corners. The helm (`pilot_seat`) sits in the front row facing the windshield, so the cockpit pod
  juts out through the canopy face ahead of it (cockpit pod spec §7).
- **The bridge computer** (`computer`, facing aft) in the port front corner beside the helm: you
  stand aft of it and look forward over the holo, out of the shoulder window (bridge computer spec
  §3.2, as amended 2026-09-27). The corner's console goes to the back corner
  (`InteriorLayout._handed_consoles`). It replaced a 0.4 t deck cell with a 0.3 t table.
- **The quantum core** at the bridge's centre, straight behind the helm, facing aft so its gauge
  faces the corridor; **the quantum machine** in the starboard back corner, facing forward with its
  back to the galley's wall (quantum energy spec §5.3). With the core behind the helm you stand up
  to the helm's starboard side (`NO_STAND`).
- **A corridor** down the centreline, z 0..2, with rooms either side (interior redesign spec §7.5):
  a two-cell bunk room and a bathroom to port; a galley, a weapon room and the closet (the droid's
  dock) to starboard. Room blocks weigh and draw what deck does, so the rooms never moved the
  balance.
- **The airlock** at the stern, z = 3, between two bulkheads: its outer hatch faces aft onto space,
  its inner hatch the corridor.

## The engine pods (y = 0, x = ±3)

Two pods of hull beside the cabin's aft half, each with a main `thruster` at its stern (z = 3).

## The equipment deck and roof (y = +1; art direction spec §3.2)

- **The ship core** at (0, 1, −1), hull round it.
- **Three quantum cells** across z = 0. The spec placed two; a third at x = 0 was added for pitch
  balance (below). They were reactors; the quantum core makes the power now, and the cells keep
  their mass and hp, storing QE (quantum energy spec §5.1, §5.3).
- **Grav plating** at (±1, 1, 1).
- **A second thruster bank** on the stern roof, x −1..1 at z = 3, where the spec had plain hull
  (pitch balance, below). Hull wedges taper the nose and the stern corners.

## RCS (art direction §3 placed none)

As specified the ship had thrust only along −Z, so no turning authority at all: the flight computer
could not turn it. Eight `rcs` sit in cells the nose taper left empty, each touching a placed
block, in **opposed pairs** (an axis counts its weaker direction):

- **Yaw:** a lateral pair at the nose, (−1, 1, −4) thrusting +X and (1, 1, −4) thrusting −X.
- **Pitch and roll:** four vertical units, UP at z = −3 and DOWN at z = −4, mirrored port and
  starboard; fired differentially across the 8 m between them they roll the ship both ways. An
  earlier layout had one UP and one DOWN on opposite sides: both rolled it the same way, so it had
  no roll.
- **Braking:** every main engine faces aft, so reverse thrust was 0 and the ship could never slow
  down. The retro pair at (±2, 1, −2) thrusts +Z: 500 kN, stopping the 2-second sprint speed of
  32 m/s in about 6 s, and giving the assist something to cancel drift along Z with.

Six of the eight fire into a neighbour, so their puffs never show (`ship_check.gd`'s
`RCS_BLOCKED` notes); only the pitch-down pair is seen, and none from the seat.

## Pitch balance

Both pod thrusters at y = 0 with the equipment deck's mass at y = +1 put the centre of mass above
the thrust line: with thrust at y = 0 only, a full burn pitched the ship with 686,582 N·m against
160,000 of authority. The stern roof's three hull cells became the second thruster bank, which
brought it to −14,371 N·m, and the nose RCS trimmed the rest. The quantum core's 5 t at cabin level
then pulled the centre of mass down to about the thrust's 1.2 m average height; the fairings' 6.0 t
above the cabin (and 1.8 t of keel below) raised it 9 cm again. **A full burn now pitches it with
151,289 N·m, 4.91% of its authority, against the 5% limit (`UNBALANCED`).** Leave headroom: a little
more mass above the thrust line breaks it. Yaw is 0.3% (the machine and the table stand off the
centreline); roll 0.

## Power

The five main thrusters drew 9 MW more than the art direction's two-reactor estimate, which
assumed four; three reactors restored the margin. The quantum core now makes all 36.0 MW alone,
and the machine adds 0.5 MW of draw: **36.0 MW made, 31.3 MW drawn**, past the 34.4 MW that
`POWER_MARGIN`'s 10% asks for.

## The shape (ship exterior spec §8)

26 fairings, 0.3 t each, all outside the cabin row so nothing inside moves: a dorsal spine a metre
high (half blocks at y = 2 over z −1..2, ramped by long low slopes at z = −2 and z = 3); a fin
rising aft on each engine pod (slopes at (±3, 1, 1)); and a keel of half blocks under the
centreline (y = −1, z −3..2) for the floods to hang from. They added 7.8 t and no power draw. Every
hull section has plating or fairings outside the cabin to lose (`NO_PIECES`): 3 a side at the bow,
6 midships and 12 at the stern.

## The numbers (`ShipStats`, `data/blocks`)

110 blocks, 104,700 kg, centre of mass (0.004, 1.301, 0.160); inertia (2065526, 2865503, 1175422);
torque authority (3080229, 2040115, 2174785), imbalance under a full burn (151289, −5731, 0).
Thrust forward / reverse / lateral / vertical 1500 / 500 / 500 / 1000 kN. Turning 1.49 / 0.71 /
1.85 rad/s² (pitch / yaw / roll); forward 14.3, brake and side 4.8, vertical 9.6 m/s². 1,200 QE:
14,500 km of warp on a full store. No validator issues; no rule broken.
```

- [ ] **Step 6: Make `_starter_grid()` read the library**

In `who-knows/scenes/flight_test.gd`:

1. Replace the header doc comment's first paragraph (lines 3–6) with:

```gdscript
## Builds the starter shuttle from the ship library (data/ships/starter.json;
## docs/superpowers/specs/2026-10-02-ship-library-design.md §3), so
## flight_test.tscn always has a ship.
```

2. Add beside the other state, after `var suit_tie: SuitTie`:

```gdscript
## Every ship the game can build, from data/ships (ship library spec §3.2):
## loaded first in _ready, or by _starter_grid() on a bare instance.
var library: ShipLibrary
```

3. Make `_load_library()` the first line of `_ready()`, and add the function after `_ready`:

```gdscript
## The ship library (ship library spec §3.2). A file that would not load is an
## error in the output, and left out.
func _load_library() -> void:
	library = ShipLibrary.load_from_dir()
	for e in library.errors:
		push_error("ShipLibrary: " + e)
```

4. Replace the whole of `_starter_grid()` (its body and every comment in it) with:

```gdscript
## The starter shuttle, from data/ships/starter.json; why each block is where it
## is: data/ships/starter.md. Most tests call this on a flight_test.gd that
## never entered the tree, so it loads the library itself.
func _starter_grid() -> ShipGrid:
	if library == null:
		library = ShipLibrary.load_from_dir()
	return library.grid(ShipLibrary.STARTER)
```

5. Delete the `O_*` block (the comment `## BlockOrientation values used below...` through
   `const O_KEEL := 2 ...`) and `func _put(...)` at the end of the file: nothing else uses them
   (`grep -rn "O_FORWARD\|O_RCS\|_put(" who-knows/scenes` finds only `flight_test.gd`).

- [ ] **Step 7: Drop the match test, now vacuous**

Delete `test_the_library_starter_is_the_code_starter` (and its doc comment) from
`test_ship_library.gd`: both sides read the file now. The pin in `test_starter_shuttle.gd` guards
the starter from here on.

- [ ] **Step 8: Run the starter's tests and a spread of `_starter_grid()` callers**

Run: `& $env:TEMP\sl_run.ps1 test_ship_library test_starter_shuttle test_deck_paths test_ship_crew test_hull_windows test_interior_layout test_boarding_scene test_save_scene`
Expected: every file PASS, 0 script errors.

- [ ] **Step 9: Commit**

```bash
git add who-knows/data/ships/starter.md who-knows/scenes/flight_test.gd who-knows/test/unit/test_ship_library.gd
git commit -m "feat: the starter is read from the ship library; its reasoning moves to starter.md"
```

---

### Task 3: `ShipRules`

**Files:**
- Create: `who-knows/src/ship/ship_rules.gd`
- Test: `who-knows/test/unit/test_ship_rules.gd`

**Interfaces:**
- Consumes: `ShipLibrary.load_from_dir().grid(ShipLibrary.STARTER)` (Task 2);
  `ShipValidator.validate(grid, catalog) -> Array` of `Issue {severity, code, message, coord}`;
  `ShipStats.compute` (`power_gen`, `power_draw`, `thrust_budget[&"forward"|&"reverse"|&"lateral"|&"vertical"]`,
  `torque_budget`, `torque_imbalance`, `inertia`, `total_mass_kg`, `quantum_capacity`, `crippled`,
  `crippled_reason`, `center_of_mass`); `DeckGraph.build(grid, catalog).walkable_coords()`;
  `InteriorLayout.plan(grid, catalog, walkable)` (`pods()`, `fixtures()`, `airlocks()`,
  `walkable_coords()`, `facing(orientation)`, `HELM_ID`); `DeckPaths.build(layout)` (`has`,
  `cells`, `distances`); `HullLayout.plan(grid, catalog, layout).unmatched`;
  `ShipCrew.MIN_CELLS`, `dock`, `NO_DOCK`, `work_spots`, `reachable_spots`;
  `ShipDamage.build(grid, catalog, held).pieces`, `ShipDamage.SECTIONS`, `SECTION_LABELS`;
  `Ship.inner_of(grid, catalog)`; `RcsShow.gather(grid, catalog, centre_of_mass)` (`coord`,
  `force`); `WarpPlan.WARP_BASE`, `WARP_M_PER_QE`.
- Produces:
  - `class_name ShipRules extends RefCounted`
  - `static func check(grid: ShipGrid, catalog: BlockCatalog) -> Dictionary` →
    `{"rules": Array, "notes": Array}`, each item `{"code": StringName, "text": String, "cell":
    Vector3i or null}`
  - `static func item(code: StringName, text: String, cell: Variant = null) -> Dictionary`
  - `static func stand_cell(helm: Vector3i, facing: Vector3i, paths: DeckPaths) -> Variant`
  - `const IMBALANCE_MOST := 0.05`, `const POWER_HEADROOM := 1.1`

- [ ] **Step 1: Write the failing test**

Every broken copy below was checked on the real starter while planning (spec §11).

`who-knows/test/unit/test_ship_rules.gd`:

```gdscript
extends GutTest

## ShipRules (docs/superpowers/specs/2026-10-02-ship-library-design.md §4):
## the starter breaks none, and each rule is broken by a copy of the starter
## broken just that way (spec §11 says how each was chosen). Notes never count.

var _cat: BlockCatalog
var _g: ShipGrid

func before_all():
	_cat = BlockCatalog.load_from_dir("res://data/blocks")

func before_each():
	_g = ShipLibrary.load_from_dir().grid(ShipLibrary.STARTER)

func _put(coord: Vector3i, id: StringName, o := 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = o
	_g.set_block(coord, i)

static func _codes(items: Array) -> Array:
	return items.map(func(i: Dictionary) -> StringName: return i["code"])

## The first rule broken with `code`, after asserting there is one.
func _breaks(code: StringName) -> Dictionary:
	var found := ShipRules.check(_g, _cat)
	assert_has(_codes(found["rules"]), code, "breaks %s (found %s)" % [code, found["rules"]])
	for i in found["rules"]:
		if i["code"] == code:
			return i
	return {"text": "", "cell": null}

func test_the_starter_breaks_no_rule():
	var found := ShipRules.check(_g, _cat)
	assert_eq(found["rules"], [], "broken: %s" % [found["rules"]])

func test_notes_never_count_as_rules():
	var notes: Array = ShipRules.check(_g, _cat)["notes"]
	assert_eq(_codes(notes).count(&"RCS_BLOCKED"), 6, "six of the starter's eight rcs fire into a neighbour")
	assert_has(_codes(notes), &"FEEL")
	assert_has(_codes(notes), &"SIZE")

func test_an_unknown_block_is_named_and_nothing_else_is_checked():
	_put(Vector3i(0, 0, 0), &"warp_banana")
	var rules: Array = ShipRules.check(_g, _cat)["rules"]
	assert_eq(_codes(rules), [&"UNKNOWN_BLOCK"])
	assert_eq(rules[0]["cell"], Vector3i(0, 0, 0))
	assert_string_contains(rules[0]["text"], "warp_banana")

func test_the_validator_speaks_through_its_rule():
	_g.clear_block(Vector3i(0, 1, -1))
	assert_string_contains(_breaks(&"VALIDATOR")["text"], "SINGLE_CORE")

func test_power_needs_ten_percent_to_spare():
	_put(Vector3i(0, 2, 3), &"thruster")
	_breaks(&"POWER_MARGIN")
	assert_does_not_have(_codes(ShipRules.check(_g, _cat)["rules"]), &"VALIDATOR",
		"inside the validator's own margin")

func test_with_no_main_thruster_it_cannot_thrust():
	for c in _g.coords():
		if _g.get_block(c).block_id == &"thruster":
			_put(c, &"hull")
	_breaks(&"CANNOT_THRUST")

func test_without_the_retro_pair_it_cannot_brake():
	_g.clear_block(Vector3i(-2, 1, -2))
	_g.clear_block(Vector3i(2, 1, -2))
	_breaks(&"CANNOT_BRAKE")

func test_without_the_nose_pair_it_cannot_yaw():
	_g.clear_block(Vector3i(-1, 1, -4))
	_g.clear_block(Vector3i(1, 1, -4))
	assert_string_contains(_breaks(&"NO_AUTHORITY")["text"], "yaw")

func test_the_stern_bank_a_deck_down_pitches_it_under_burn():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 1, 3), &"hull")
		_put(Vector3i(x, -1, 3), &"thruster")
	assert_string_contains(_breaks(&"UNBALANCED")["text"], "pitch")

func test_every_thruster_wrecked_it_is_crippled():
	var hp := _cat.get_def(&"thruster").hp
	for c in _g.coords():
		if _g.get_block(c).block_id == &"thruster":
			_g.get_block(c).damage = hp * BlockDamage.WRECKED_AT
	_breaks(&"CRIPPLED")

func test_with_the_canopy_row_made_hull_there_is_no_pod():
	for x in [-1, 0, 1]:
		_put(Vector3i(x, 0, -4), &"hull")
	_breaks(&"NO_POD")

func test_boxed_in_you_cannot_stand_up_from_the_helm():
	for c in [Vector3i(0, 0, -2), Vector3i(-1, 0, -3), Vector3i(1, 0, -3)]:
		_put(c, &"hull")
	assert_eq(_breaks(&"NO_STAND")["cell"], Vector3i(0, 0, -3), "at the helm")

func test_with_the_airlock_made_deck_nothing_cycles():
	_put(Vector3i(0, 0, 3), &"deck")
	_breaks(&"NO_AIRLOCK")

func test_a_wall_across_the_corridor_cuts_off_the_stern():
	_put(Vector3i(0, 0, 1), &"hull")
	var cut := _breaks(&"CUT_OFF")
	assert_string_contains(cut["text"], "can't be reached on foot")
	assert_eq(cut["cell"], Vector3i(-1, 0, 2), "the first of them")

func test_a_deck_upstairs_is_cut_off_until_ladders_climb():
	_put(Vector3i(0, 2, 0), &"deck")
	_put(Vector3i(0, 2, 1), &"deck")
	var found: Array = ShipRules.check(_g, _cat)["rules"].filter(
		func(i: Dictionary) -> bool: return i["code"] == &"CUT_OFF")
	assert_eq(found.size(), 1)
	assert_string_contains(found[0]["text"], "storey 2")
	assert_string_contains(found[0]["text"], "ladders don't climb yet")
	assert_eq(found[0]["cell"], Vector3i(0, 2, 0))

func test_a_shaped_block_beside_a_porthole_leaves_it_no_window():
	_put(Vector3i(-2, 0, -2), &"fairing_slope_long_low", 8)
	assert_eq(_breaks(&"WINDOW_UNMATCHED")["cell"], Vector3i(-1, 0, -2))

func test_a_closet_in_a_pocket_of_its_own_strands_the_droid():
	_put(Vector3i(1, 0, 2), &"bulkhead")
	_put(Vector3i(3, 0, 0), &"closet")
	assert_string_contains(_breaks(&"DROID")["text"], "dock at (3, 0, 0)")

func test_a_bow_with_nothing_to_lose_never_shows_a_hole():
	var held := Ship.inner_of(_g, _cat)
	var d := ShipDamage.build(_g, _cat, held)
	for c: Vector3i in d.sections_of:
		if (d.sections_of[c] as Array).has(&"starboard_bow") and not held.has(c) \
				and ShipDamage.STRUCTURE.has(_g.get_block(c).block_id):
			_put(c, &"grav_plating")
	assert_string_contains(_breaks(&"NO_PIECES")["text"], "starboard bow")
```

- [ ] **Step 2: Run it to watch it fail**

Run: `& $env:TEMP\sl_run.ps1 test_ship_rules`
Expected: FAIL with `Identifier "ShipRules" not declared`.

- [ ] **Step 3: Write `ShipRules`**

`who-knows/src/ship/ship_rules.gd`:

```gdscript
class_name ShipRules
extends RefCounted

## The rules every ship in the game must pass (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §4): one checker for the catalog test,
## the ship probe and ship_check.gd, the designer's tool. A rule broken means
## the ship must not be given to the player; a note is worth knowing and never
## fails. Each finding is {code, text, cell}: cell is a Vector3i, or null when
## no one cell is to blame.
##
## Pure: it plans the interior, the hull, the droid's paths, the damage
## sections and the stats itself, from the grid, touching no nodes.

## The largest imbalance under a full burn, as a share of an axis's authority
## (the ship skill's step 6).
const IMBALANCE_MOST := 0.05
## Power made must beat power drawn by this much, so a ship we give the player
## never browns out at its first addition.
const POWER_HEADROOM := 1.1
## The validator's issues that name a cell.
const _CELL_ISSUES: Array[StringName] = [&"ALL_CONNECTED", &"MOUNTS_REACHABLE", &"AIRLOCK_HATCH"]
const _AXES: Array[String] = ["pitch", "yaw", "roll"]
const _TURNS: Array[String] = ["pitches", "yaws", "rolls"]

static func check(grid: ShipGrid, catalog: BlockCatalog) -> Dictionary:
	var rules: Array = []
	var notes: Array = []
	var coords: Array = grid.coords()
	coords.sort()
	for coord: Vector3i in coords:
		var id := grid.get_block(coord).block_id
		if not catalog.has(id):
			rules.append(item(&"UNKNOWN_BLOCK", "no block called \"%s\" in data/blocks" % id, coord))
	if not rules.is_empty():
		return {"rules": rules, "notes": notes}
	for issue in ShipValidator.validate(grid, catalog):
		var cell: Variant = null
		if _CELL_ISSUES.has(issue.code):
			cell = issue.coord
		rules.append(item(&"VALIDATOR", "%s: %s" % [issue.code, issue.message], cell))
	var stats := ShipStats.compute(grid, catalog)
	_check_flight(stats, rules)
	var layout := InteriorLayout.plan(grid, catalog, DeckGraph.build(grid, catalog).walkable_coords())
	var paths := DeckPaths.build(layout)
	_check_cabin(layout, paths, rules)
	_check_droid(layout, paths, rules)
	for w in HullLayout.plan(grid, catalog, layout).unmatched:
		rules.append(item(&"WINDOW_UNMATCHED", "the window in %s's wall toward %s has no place outside"
			% [w["coord"], w["normal"]], w["coord"]))
	_check_pieces(grid, catalog, rules)
	_note(grid, catalog, stats, notes)
	return {"rules": rules, "notes": notes}

## One finding.
static func item(code: StringName, text: String, cell: Variant = null) -> Dictionary:
	return {"code": code, "text": text, "cell": cell}

## Where you stand up to from a helm at `helm` facing `facing`: the first of
## the cell behind it and the two beside it (where PilotSeat.STAND_SPOTS lie)
## that is open floor, or null. Stricter than the seat, which can also step
## past a quiet fixture.
static func stand_cell(helm: Vector3i, facing: Vector3i, paths: DeckPaths) -> Variant:
	var side := Vector3i(-facing.z, 0, facing.x)
	for c: Vector3i in [helm - facing, helm + side, helm - side]:
		if paths.has(c):
			return c
	return null

## Power, thrust both ways, turning on every axis, balance under a burn, and
## not crippled as built.
static func _check_flight(s: ShipStats, rules: Array) -> void:
	if s.power_gen <= s.power_draw * POWER_HEADROOM:
		rules.append(item(&"POWER_MARGIN", "%.1f MW made for %.1f MW drawn: it needs %.1f, 10%% to spare"
			% [s.power_gen, s.power_draw, s.power_draw * POWER_HEADROOM]))
	if s.thrust_budget[&"forward"] <= 0.0:
		rules.append(item(&"CANNOT_THRUST", "no forward thrust: no main thruster pushes it forward"))
	if s.thrust_budget[&"reverse"] <= 0.0:
		rules.append(item(&"CANNOT_BRAKE", "no reverse thrust: it can never slow down (give it a retro pair)"))
	for axis in 3:
		var authority: float = s.torque_budget[axis]
		if authority <= 0.0:
			rules.append(item(&"NO_AUTHORITY", "no %s authority: rcs in opposed pairs turn it both ways" % _AXES[axis]))
		elif absf(s.torque_imbalance[axis]) >= authority * IMBALANCE_MOST:
			rules.append(item(&"UNBALANCED", "a full burn %s it with %.1f%% of its %s authority: keep it under %d%%"
				% [_TURNS[axis], absf(s.torque_imbalance[axis]) / authority * 100.0, _AXES[axis],
				roundi(IMBALANCE_MOST * 100.0)]))
	if s.crippled:
		rules.append(item(&"CRIPPLED", "crippled as built: %s" % s.crippled_reason))

## The pod, standing up from the helm, an airlock that cycles, and every cell
## reachable on foot from the helm.
static func _check_cabin(layout: InteriorLayout, paths: DeckPaths, rules: Array) -> void:
	if layout.pods().is_empty():
		rules.append(item(&"NO_POD", "no helm looks straight at a canopy, so there is no cockpit pod"))
	var helm: Variant = null
	var start: Variant = null
	for f in layout.fixtures():
		if f["id"] == InteriorLayout.HELM_ID:
			helm = f["coord"]
			start = stand_cell(f["coord"], InteriorLayout.facing(f["orientation"]), paths)
			break
	if helm != null and start == null:
		rules.append(item(&"NO_STAND", "nowhere to stand up from the helm: behind it and beside it is no open floor", helm))
	var wanted := paths.cells()
	var cycles := false
	for lock in layout.airlocks():
		if lock["door_normal"] == Vector3i.ZERO:
			continue
		cycles = true
		var inside: Vector3i = lock["coord"] + lock["door_normal"]
		if not wanted.has(inside):
			wanted.append(inside)
	if not cycles:
		rules.append(item(&"NO_AIRLOCK", "no airlock that cycles with a way in through its inner hatch"))
	if start == null:
		return
	var reach := paths.distances(start)
	var missing := {}   # storey -> the cells on it out of reach
	for c in wanted:
		if not reach.has(c):
			missing.get_or_add(c.y, []).append(c)
	var storeys := missing.keys()
	storeys.sort()
	for y: int in storeys:
		var cells: Array = missing[y]
		cells.sort()
		if y == helm.y:
			rules.append(item(&"CUT_OFF", "%d cells can't be reached on foot from the helm, the first %s"
				% [cells.size(), cells[0]], cells[0]))
		else:
			rules.append(item(&"CUT_OFF", "cells on storey %d can't be reached from the helm: ladders don't climb yet"
				% y, cells[0]))

## The maintenance droid (NPC foundation spec §14): on a ship big enough to
## have one, a dock, and every job it tends reachable from there.
static func _check_droid(layout: InteriorLayout, paths: DeckPaths, rules: Array) -> void:
	if layout.walkable_coords().size() < ShipCrew.MIN_CELLS:
		return
	var dock := ShipCrew.dock(layout, paths)
	if dock == ShipCrew.NO_DOCK:
		rules.append(item(&"DROID", "the maintenance droid has nowhere to dock"))
		return
	var reachable := ShipCrew.reachable_spots(layout, paths)
	var lost: Array = []
	for spot in ShipCrew.work_spots(layout, paths):
		if not reachable.has(spot):
			lost.append(spot)
	if not lost.is_empty():
		rules.append(item(&"DROID", "the droid can't walk from its dock at %s to %d of its jobs, the first %s"
			% [dock, lost.size(), lost[0]["key"]], lost[0]["cell"]))

## Every hull section has pieces to lose (ship damage sections spec §4), or a
## hit there never shows a hole.
static func _check_pieces(grid: ShipGrid, catalog: BlockCatalog, rules: Array) -> void:
	var damage := ShipDamage.build(grid, catalog, Ship.inner_of(grid, catalog))
	for id: StringName in ShipDamage.SECTIONS:
		if (damage.pieces[id] as Array).is_empty():
			rules.append(item(&"NO_PIECES", "the %s has no plating or fairing outside the cabin to lose: it never shows a hole"
				% String(ShipDamage.SECTION_LABELS[id]).to_lower()))

## Worth knowing, never failing: rcs whose puffs are hidden, how it flies, and
## its size.
static func _note(grid: ShipGrid, catalog: BlockCatalog, s: ShipStats, notes: Array) -> void:
	for b in RcsShow.gather(grid, catalog, s.center_of_mass):
		var into: Vector3i = b["coord"] - Vector3i((b["force"] as Vector3).normalized().round())
		if grid.has_block(into):
			notes.append(item(&"RCS_BLOCKED", "the rcs at %s fires into the block at %s: its puffs never show"
				% [b["coord"], into], b["coord"]))
	var kg := maxf(s.total_mass_kg, 1.0)
	notes.append(item(&"FEEL", "turns %.2f / %.2f / %.2f rad/s2 (pitch / yaw / roll); side %.1f, vertical %.1f, brake %.1f, forward %.1f m/s2" % [
		s.torque_budget.x / maxf(s.inertia.x, 1.0), s.torque_budget.y / maxf(s.inertia.y, 1.0),
		s.torque_budget.z / maxf(s.inertia.z, 1.0), s.thrust_budget[&"lateral"] / kg,
		s.thrust_budget[&"vertical"] / kg, s.thrust_budget[&"reverse"] / kg, s.thrust_budget[&"forward"] / kg]))
	notes.append(item(&"SIZE", "%d blocks, %.1f t; %.1f MW made, %.1f drawn; %d QE, %.0f km of warp on a full store" % [
		grid.size(), s.total_mass_kg / 1000.0, s.power_gen, s.power_draw, s.quantum_capacity,
		maxf(s.quantum_capacity - WarpPlan.WARP_BASE, 0) * WarpPlan.WARP_M_PER_QE / 1000.0]))
```

- [ ] **Step 4: Run it to watch it pass**

Run: `& $env:TEMP\sl_run.ps1 test_ship_rules`
Expected: PASS, 18 tests, 0 script errors. If a broken copy does not break its rule, fix the rule's
code, not the copy: each copy was checked against the definitions above.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_rules.gd who-knows/src/ship/ship_rules.gd.uid who-knows/test/unit/test_ship_rules.gd who-knows/test/unit/test_ship_rules.gd.uid
git commit -m "feat: ShipRules -- the rules every ship must pass, each broken by its own copy of the starter"
```

---

### Task 4: `ship_check.gd` and the probe's `rules` line

**Files:**
- Create: `.claude/skills/building-a-ship/ship_check.gd`
- Modify: `.claude/skills/building-a-ship/ship_probe.gd` (header comment; `_run` after the `rcs` line)

**Interfaces:**
- Consumes: `ShipLibrary.read(path)` (Task 1), `ShipRules.check` (Task 3).
- Produces: the command `& $godot --headless --path who-knows --script <abs>/ship_check.gd -- <ship .json>`,
  exit 0 with no rule broken, 1 otherwise or on a load error. Output lines: `ship    ...`,
  `rules   N broken`, `  <--   CODE text at (x, y, z)`, `note    CODE text`, or `load    <error>`.

- [ ] **Step 1: Write `ship_check.gd`**

```gdscript
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
```

- [ ] **Step 2: Run it on the starter**

Run (from `D:\git\whoknows-ship-library`):
`& $godot --headless --path who-knows --script "$PWD\.claude\skills\building-a-ship\ship_check.gd" -- res://data/ships/starter.json; "exit $LASTEXITCODE"`
Expected: `ship    starter: Starter shuttle, 110 blocks`, `rules   0 broken`, six `note    RCS_BLOCKED`
lines, a `FEEL` line with `1.49 / 0.71 / 1.85`, a `SIZE` line with `110 blocks, 104.7 t`, then
`exit 0`. It should take a few seconds.

- [ ] **Step 3: Run it on a broken copy, a missing file and a relative path**

```powershell
New-Item -ItemType Directory -Force "$env:TEMP\sl_check" | Out-Null
(Get-Content who-knows\data\ships\starter.json) | Where-Object { $_ -notmatch '"core"' } | Set-Content "$env:TEMP\sl_check\starter.json"
& $godot --headless --path who-knows --script "$PWD\.claude\skills\building-a-ship\ship_check.gd" -- "$env:TEMP\sl_check\starter.json"; "exit $LASTEXITCODE"
& $godot --headless --path who-knows --script "$PWD\.claude\skills\building-a-ship\ship_check.gd" -- "$env:TEMP\sl_check\nothing.json"; "exit $LASTEXITCODE"
& $godot --headless --path who-knows --script "$PWD\.claude\skills\building-a-ship\ship_check.gd" -- ships\starter.json; "exit $LASTEXITCODE"
```

Expected, in order: `rules   1 broken` (or more) with `<--   VALIDATOR SINGLE_CORE: Ship has no Ship Core.`
and `exit 1`; `load    ...nothing.json: no such file` and `exit 1`; `load    ships\starter.json: give
an absolute path or a res:// one` and `exit 1`. (Removing the `"core"` row also removes the comma
of the row before it only if it was the last row; it is not, so the JSON stays valid.)

- [ ] **Step 4: Add the probe's `rules` line**

In `ship_probe.gd`, add to the header comment's list of what it prints, after "Every ship gets
probe_hull_* ...": `It prints the rules line (ShipRules: every rule broken, or 0) and the notes.`
Then in `_run`, right after the `print("rcs     ...")` statement:

```gdscript
	# The rules every ship must pass (ship library spec §4): the checker the
	# catalog test and ship_check.gd use.
	var found := ShipRules.check(ship.grid, ship.catalog)
	print("rules   %d broken" % found["rules"].size())
	for r in found["rules"]:
		print("        <-- %s %s" % [r["code"], r["text"]])
	for n in found["notes"]:
		print("note    %s %s" % [n["code"], n["text"]])
```

The probe runs windowed with the renders in Task 10, which checks this line.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/building-a-ship/ship_check.gd .claude/skills/building-a-ship/ship_probe.gd
git commit -m "feat: ship_check.gd -- the rules on one ship file in seconds; the probe prints them too"
```

---

### Task 5: The catalog test

**Files:**
- Test: `who-knows/test/unit/test_ship_catalog.gd`

**Interfaces:**
- Consumes: `ShipLibrary` (`load_from_dir`, `errors`, `ids`, `grid`, `name_of`, `DIR`,
  `rows_text`), `ShipRules.check`, `Fleet.spawn(grid, place, stock, ship_name, launch)`,
  `flight_test.board_nearest()`, `save_now()`, `save_enabled`, `save_path`, `fleet.named(name)`,
  `CameraDirector.stand()` and `transition_finished`, `Avatar.GROUP`, `SaveGame.DEFAULT_PATH`.
- Produces: nothing other tasks call.

- [ ] **Step 1: Write the test**

`who-knows/test/unit/test_ship_catalog.gd`:

```gdscript
extends GutTest

## Every ship in data/ships (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §7.1): it loads, breaks no rule, has its
## note, and is usable -- the owner's rule, 2026-10-02: boarded, flown, walked
## and saved, in the real flight scene. A new ship is checked here without
## anyone writing a test for it.

const SCENE := "res://scenes/flight_test.tscn"
const PATH := "user://test_ship_catalog/game.json"

var _library: ShipLibrary
var _cat: BlockCatalog
var _real_save_time := 0

func before_all():
	_library = ShipLibrary.load_from_dir()
	_cat = BlockCatalog.load_from_dir("res://data/blocks")
	_real_save_time = _modified(SaveGame.DEFAULT_PATH)

func after_all():
	assert_eq(_modified(SaveGame.DEFAULT_PATH), _real_save_time, "the owner's real save is untouched")

func after_each():
	for action in [&"move_forward", &"move_back"]:
		Input.action_release(action)
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

static func _modified(file_path: String) -> int:
	return FileAccess.get_modified_time(file_path) if FileAccess.file_exists(file_path) else 0

func _scene() -> Node:
	var root: Node = load(SCENE).instantiate()
	root.save_enabled = true
	root.save_path = PATH
	add_child(root)
	return root

func _drop(root: Node) -> void:
	remove_child(root)
	root.free()

func test_every_ship_loads():
	assert_eq(_library.errors, [] as Array[String])
	assert_gt(_library.ids().size(), 0)

func test_every_ship_breaks_no_rule():
	for id in _library.ids():
		var found := ShipRules.check(_library.grid(id), _cat)
		assert_eq(found["rules"], [], "%s breaks: %s" % [id, found["rules"]])

func test_every_ship_has_its_note():
	for id in _library.ids():
		assert_true(FileAccess.file_exists("%s/%s.md" % [ShipLibrary.DIR, id]), "data/ships/%s.md explains it" % id)

func test_every_ship_is_usable():
	for id in _library.ids():
		await _use(id)

## Spawned 300 m off the starter: F8 boards it, a burn moves it and not the
## starter, you stand and walk, and a save brings it back as it was.
func _use(id: StringName) -> void:
	var root := _scene()
	await wait_process_frames(2)
	var starter: Ship = root.get_node("Ship")
	var place := Transform3D(starter.exterior.global_basis, starter.exterior.global_position + Vector3(300, 0, 0))
	var grid := _library.grid(id)
	var ship: Ship = root.fleet.spawn(grid, place, true, "", ShipBlueprint.from_grid(grid, _library.name_of(id)))
	await wait_physics_frames(2)
	assert_true(root.board_nearest(), "%s: F8 boards it" % id)
	assert_same(root.aboard, ship, "%s: aboard it" % id)
	var starter_at := starter.exterior.global_position
	var ship_at := ship.exterior.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(60)
	Input.action_release(&"move_forward")
	assert_gt(ship.exterior.global_position.distance_to(ship_at), 1.0, "%s: a burn moves it" % id)
	assert_almost_eq(starter.exterior.global_position, starter_at, Vector3.ONE * 0.5, "%s: and not the starter" % id)
	# Let the controls see the key go before standing: a burn held as you stand
	# latches on, by design.
	await wait_physics_frames(2)
	var director: CameraDirector = root.get_node("CameraDirector")
	director.stand()
	await wait_for_signal(director.transition_finished, 3)
	var avatar: Avatar = root.get_tree().get_first_node_in_group(Avatar.GROUP)
	var from := avatar.global_position
	Input.action_press(&"move_back")
	await wait_physics_frames(60)
	Input.action_release(&"move_back")
	assert_gt(from.distance_to(avatar.global_position), 1.0, "%s: you stand and walk" % id)
	assert_same(avatar.get_parent(), ship.interior, "%s: aboard it" % id)
	assert_true(root.save_now(), "%s: it saves" % id)
	var ship_name := ship.name
	_drop(root)
	var again := _scene()
	await wait_process_frames(2)
	var back: Ship = again.fleet.named(ship_name)
	assert_not_null(back, "%s: the save brings it back" % id)
	if back != null:
		assert_eq(ShipLibrary.rows_text(back.grid), ShipLibrary.rows_text(grid), "%s: as it was built" % id)
		assert_eq(back.launch_blueprint.ship_name, _library.name_of(id), "%s: with its name" % id)
		assert_same(again.aboard, back, "%s: and you aboard it" % id)
	_drop(again)
```

- [ ] **Step 2: Run it**

Run: `& $env:TEMP\sl_run.ps1 test_ship_catalog`
Expected: PASS, 4 tests. (It tests data and code that already exist, so it passes first time; the
next step proves it can fail.)

- [ ] **Step 3: Prove it bites**

```powershell
(Get-Content who-knows\data\ships\starter.json) -replace '"id": "starter"', '"id": "broken"' | Where-Object { $_ -notmatch '"core"' } | Set-Content who-knows\data\ships\broken.json
& $env:TEMP\sl_run.ps1 test_ship_catalog
Remove-Item who-knows\data\ships\broken.json
& $env:TEMP\sl_run.ps1 test_ship_catalog
```

Expected: the first run FAILs on `test_every_ship_breaks_no_rule` (`broken breaks: ...SINGLE_CORE...`),
`test_every_ship_has_its_note` (`data/ships/broken.md explains it`) and the usable test for
`broken`; after the file is removed, PASS again. Check `git status` shows no `broken.json`.

- [ ] **Step 4: Commit**

```bash
git add who-knows/test/unit/test_ship_catalog.gd
git commit -m "test: the ship catalog -- every library ship loads, breaks no rule, has its note, and is usable"
```

---

### Task 6: `WarpArrival` and `SpacePalette.WARP`

**Files:**
- Create: `who-knows/src/flight/warp_arrival.gd`
- Modify: `who-knows/src/world/space_palette.gd` (after `AMBIENT`)
- Modify: `who-knows/test/unit/test_visual_style_rules.gd` (`PAINTING_FILES`)
- Test: `who-knows/test/unit/test_warp_arrival.gd`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `class_name WarpArrival extends Node3D`, `signal arrived`
  - `const DURATION := 1.5`, `FROM := 2000.0`, `WAKE_WIDTH := 0.6`, `WAKE_SECONDS := 0.15`,
    `FLASH_SCALE := Vector2(1.0, 1.6)`, `FLASH_TIME := 0.4`
  - `static func play(hull: RigidBody3D, at: Transform3D, end_velocity := Vector3.ZERO) -> WarpArrival`
  - `static func of(hull: Node) -> WarpArrival` (the arrival still flying in, or null; one that
    has stopped and is only fading its flash does not count)
  - `static func distance_at(t: float) -> float`
  - `var elapsed: float`; manual stepping in tests: `set_physics_process(false)` then
    `_physics_process(delta)`
  - `SpacePalette.WARP: Color`

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_warp_arrival.gd`:

```gdscript
extends GutTest

## WarpArrival (docs/superpowers/specs/2026-10-02-ship-library-design.md §6):
## where the hull goes, what it is while it arrives, and what it leaves
## behind. A bare body with one box stands in for a hull; each arrival is
## stepped by hand.

const STEP := 1.0 / 60.0

var _hull: RigidBody3D
var _spot: Transform3D

func before_each():
	_hull = _body()
	add_child_autofree(_hull)
	_spot = Transform3D(Basis(Vector3.UP, 0.4), Vector3(50, -20, 300))

func _body() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = 5
	body.collision_mask = 7
	body.gravity_scale = 0.0
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 3, 16)
	mesh.mesh = box
	body.add_child(mesh)
	return body

func _play(end_velocity := Vector3.ZERO) -> WarpArrival:
	var a := WarpArrival.play(_hull, _spot, end_velocity)
	a.set_physics_process(false)
	return a

func _run(a: WarpArrival, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001 and is_instance_valid(a):
		a._physics_process(STEP)
		t += STEP

func test_it_starts_from_back_along_the_nose():
	_play()
	assert_almost_eq(_hull.global_position, _spot.origin + _spot.basis.z * WarpArrival.FROM, Vector3.ONE * 0.01)
	assert_almost_eq(_hull.global_basis.z, _spot.basis.z, Vector3.ONE * 0.0001, "already facing its way")

func test_most_of_the_way_goes_in_the_first_third():
	assert_lt(WarpArrival.distance_at(WarpArrival.DURATION / 3.0), WarpArrival.FROM * 0.3)
	assert_eq(WarpArrival.distance_at(WarpArrival.DURATION), 0.0)

func test_it_ends_exactly_at_the_spot_moving_as_asked():
	var a := _play(Vector3(0, 0, -120))
	_run(a, WarpArrival.DURATION + 0.05)
	assert_almost_eq(_hull.global_position, _spot.origin, Vector3.ONE * 0.001)
	assert_almost_eq(_hull.global_basis.z, _spot.basis.z, Vector3.ONE * 0.0001)
	assert_eq(_hull.linear_velocity, Vector3(0, 0, -120))
	assert_eq(_hull.angular_velocity, Vector3.ZERO)

func test_its_layer_mask_and_freeze_come_back():
	var a := _play()
	_run(a, WarpArrival.DURATION + 0.05)
	assert_eq(_hull.collision_layer, 5)
	assert_eq(_hull.collision_mask, 7)
	assert_false(_hull.freeze)
	assert_eq(_hull.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)

func test_it_is_ghosted_all_the_way_in():
	var a := _play()
	while a.elapsed < WarpArrival.DURATION - STEP * 1.5:
		assert_eq(_hull.collision_layer, 0)
		assert_eq(_hull.collision_mask, 0)
		assert_true(_hull.freeze)
		assert_eq(_hull.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)
		a._physics_process(STEP)

func test_arrived_fires_once_at_the_stop():
	var a := _play()
	watch_signals(a)
	_run(a, WarpArrival.DURATION - 0.1)
	assert_signal_not_emitted(a, "arrived")
	_run(a, 0.2)
	assert_signal_emit_count(a, "arrived", 1)
	_run(a, WarpArrival.FLASH_TIME * 0.5)
	assert_signal_emit_count(a, "arrived", 1)

func test_it_counts_as_arriving_until_it_stops():
	var a := _play()
	assert_same(WarpArrival.of(_hull), a)
	_run(a, WarpArrival.DURATION + 0.05)
	assert_null(WarpArrival.of(_hull), "its flash still fades, but it has arrived")

func test_the_wake_is_long_while_fast_and_gone_at_the_stop():
	var a := _play()
	_run(a, 0.1)
	var wake := a.get_child(0) as MeshInstance3D
	assert_true(wake.visible)
	assert_gt(wake.scale.z, 100.0, "hundreds of metres long at the start")
	_run(a, WarpArrival.DURATION - 0.15)
	assert_lt(wake.scale.z, 10.0, "a few metres as it eases onto the spot")
	_run(a, 0.1)
	assert_false(wake.visible, "none once it has stopped")

func test_the_wake_and_flash_are_gone_after():
	var a := _play()
	_run(a, WarpArrival.DURATION + WarpArrival.FLASH_TIME + 0.05)
	await wait_process_frames(1)
	assert_false(is_instance_valid(a))
	assert_eq(_hull.find_children("*", "MeshInstance3D", true, false).size(), 1, "only its own box")

func test_a_shift_mid_arrival_carries_the_spot():
	var a := _play()
	_run(a, 0.5)
	# What Universe.shift does to a hull in EXTERIOR_SPACE.
	_hull.global_position -= Vector3(1000, 0, 0)
	_run(a, WarpArrival.DURATION)
	assert_almost_eq(_hull.global_position, _spot.origin - Vector3(1000, 0, 0), Vector3.ONE * 0.001)

func test_a_hull_freed_mid_arrival_takes_it_along():
	var body := _body()
	add_child(body)
	var a := WarpArrival.play(body, _spot)
	a.set_physics_process(false)
	a._physics_process(0.3)
	body.free()
	assert_false(is_instance_valid(a))
```

Add `"res://src/flight/warp_arrival.gd",` to `PAINTING_FILES` in `test_visual_style_rules.gd`,
after `"res://src/flight/rcs_show.gd",`.

- [ ] **Step 2: Run them to watch them fail**

Run: `& $env:TEMP\sl_run.ps1 test_warp_arrival test_visual_style_rules`
Expected: `test_warp_arrival` FAIL (`Identifier "WarpArrival" not declared`); `test_visual_style_rules`
FAIL (it cannot read `res://src/flight/warp_arrival.gd`).

- [ ] **Step 3: Add the colour**

In `who-knows/src/world/space_palette.gd`, after `const AMBIENT := ...`:

```gdscript
## A ship arriving out of warp (ship library spec §6.2): its wake and the flash
## as it stops. A warm white near the hull's work lights, so bloom halos it
## against the dark. Tuned at the renders.
const WARP := Color("fff3e0")
```

- [ ] **Step 4: Write `WarpArrival`**

`who-knows/src/flight/warp_arrival.gd`:

```gdscript
class_name WarpArrival
extends Node3D

## A ship arriving as if out of warp (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §6): its hull rushes in along its nose
## from FROM back, braking hard onto `at`, a wake streaming behind it; a flash
## as it stops; then it moves at `end_velocity`. Anything that brings a ship in
## uses it: a spawn now, NPC ships and wingmen one day.
##
## While it arrives the hull is ghosted, as a ship at warp is (the warp spec
## §5): frozen kinematic, on no collision layer or mask, so it passes through
## rocks and ships. Its layer, mask and freeze come back at the stop. The wake
## and the flash are the engine's StandardMaterial3D, unshaded and additive, in
## SpacePalette.WARP: no new shader (style guide §2.5). They are its children,
## and it is the hull's, so the floating origin carries them and a ship removed
## mid-arrival takes its arrival with it.

signal arrived

const DURATION := 1.5
const FROM := 2000.0
const WAKE_WIDTH := 0.6
const WAKE_SECONDS := 0.15
const WAKE_ALPHA := 0.8
## The flash grows from x to y times the hull's bounds while it fades.
const FLASH_SCALE := Vector2(1.0, 1.6)
const FLASH_TIME := 0.4
const FLASH_ALPHA := 0.7
## Moved farther than this between two placings, the hull was shifted by the
## floating origin, which moves it by Universe.STEP at least.
const SHIFTED := 1.0

var hull: RigidBody3D
var at: Transform3D
var end_velocity := Vector3.ZERO
## Seconds since it began.
var elapsed := 0.0

var _layer := 0
var _mask := 0
var _freeze := false
var _freeze_mode := RigidBody3D.FREEZE_MODE_STATIC
var _placed := Vector3.ZERO
var _has_placed := false
var _stopped := false
var _bounds := AABB()
var _wake: MeshInstance3D
var _flash: MeshInstance3D

## Starts `p_hull` arriving at `p_at`, to move at `p_end_velocity` once it has.
static func play(p_hull: RigidBody3D, p_at: Transform3D, p_end_velocity := Vector3.ZERO) -> WarpArrival:
	var a := WarpArrival.new()
	a.name = "WarpArrival"
	a.hull = p_hull
	a.at = p_at
	a.end_velocity = p_end_velocity
	a._bounds = bounds_of(p_hull)
	p_hull.add_child(a)
	return a

## The arrival `p_hull` is flying in now, or null. One that has stopped, its
## flash still fading, has arrived.
static func of(p_hull: Node) -> WarpArrival:
	if p_hull == null:
		return null
	for child in p_hull.get_children():
		var a := child as WarpArrival
		if a != null and not a._stopped and not a.is_queued_for_deletion():
			return a
	return null

## How far from its spot the hull is `t` seconds in: FROM × (1 − t)³ of the
## way, so it covers most of it in the first third and eases on.
static func distance_at(t: float) -> float:
	return FROM * pow(1.0 - clampf(t / DURATION, 0.0, 1.0), 3.0)

## The box round every mesh under `body`, in its own frame.
static func bounds_of(body: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var to_body := body.global_transform.affine_inverse()
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var b := (to_body * mesh.global_transform) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(WAKE_WIDTH, WAKE_WIDTH, 1.0)
	_wake = _glow(box, WAKE_ALPHA)
	var shell := SphereMesh.new()
	shell.radius = 0.5
	shell.height = 1.0
	shell.radial_segments = 16
	shell.rings = 8
	_flash = _glow(shell, FLASH_ALPHA)
	_flash.visible = false
	_ghost()
	_place()

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not _stopped:
		if elapsed < DURATION:
			_place()
		else:
			_stop()
		return
	var f := (elapsed - DURATION) / FLASH_TIME
	if f >= 1.0:
		queue_free()
		return
	_fade(_flash, FLASH_ALPHA * (1.0 - f))
	_flash.scale = _bounds.size * lerpf(FLASH_SCALE.x, FLASH_SCALE.y, f)

## Out of every collision, and moved only by this arrival.
func _ghost() -> void:
	_layer = hull.collision_layer
	_mask = hull.collision_mask
	_freeze = hull.freeze
	_freeze_mode = hull.freeze_mode
	hull.collision_layer = 0
	hull.collision_mask = 0
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	hull.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	hull.freeze = true

## The hull distance_at(elapsed) back from the spot along its line, and the
## wake behind its stern as long as the way it came in the last WAKE_SECONDS.
func _place() -> void:
	_follow_shift()
	var d := distance_at(elapsed)
	hull.global_transform = Transform3D(at.basis, at.origin + at.basis.z * d)
	_placed = hull.global_position
	_has_placed = true
	var length := distance_at(elapsed - WAKE_SECONDS) - d
	_wake.visible = length > 0.01
	_wake.scale = Vector3(1.0, 1.0, maxf(length, 0.01))
	var centre := _bounds.get_center()
	_wake.position = Vector3(centre.x, centre.y, _bounds.end.z + length * 0.5)

## The floating origin moves a ghosted hull and nothing else does, so whatever
## moved it since it was last placed moved the spot too.
func _follow_shift() -> void:
	if not _has_placed:
		return
	var moved := hull.global_position - _placed
	if moved.length() > SHIFTED:
		at.origin += moved

## On the spot: everything the hull was, back, moving at end_velocity; the
## wake gone and the flash begun.
func _stop() -> void:
	_stopped = true
	_follow_shift()
	hull.global_transform = at
	hull.freeze = _freeze
	hull.freeze_mode = _freeze_mode
	hull.collision_layer = _layer
	hull.collision_mask = _mask
	hull.linear_velocity = end_velocity
	hull.angular_velocity = Vector3.ZERO
	_wake.visible = false
	_flash.visible = true
	_flash.position = _bounds.get_center()
	_flash.scale = _bounds.size * FLASH_SCALE.x
	arrived.emit()

## `mesh` under this arrival in SpacePalette.WARP at `alpha`: unshaded, added
## to what is behind it, both faces, on render layer 1, casting no shadow.
func _glow(mesh: Mesh, alpha: float) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fade(mi, alpha)
	return mi

static func _fade(mi: MeshInstance3D, alpha: float) -> void:
	var c := SpacePalette.WARP
	c.a = alpha
	(mi.material_override as StandardMaterial3D).albedo_color = c
```

- [ ] **Step 5: Run them to watch them pass**

Run: `& $env:TEMP\sl_run.ps1 test_warp_arrival test_visual_style_rules`
Expected: both PASS (11 arrival tests), 0 script errors.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/flight/warp_arrival.gd who-knows/src/flight/warp_arrival.gd.uid who-knows/src/world/space_palette.gd who-knows/test/unit/test_warp_arrival.gd who-knows/test/unit/test_warp_arrival.gd.uid who-knows/test/unit/test_visual_style_rules.gd
git commit -m "feat: WarpArrival -- a ship rushes in out of warp, a wake behind it and a flash as it stops"
```

---

### Task 7: The fleet knows a ship is arriving

**Files:**
- Modify: `who-knows/src/ship/fleet.gd` (`nearest`, `check_sleep`; new `arriving`, `busy`)
- Modify: `who-knows/src/ship/suit_tie.gd` (`check`)
- Modify: `who-knows/scenes/flight_test.gd` (`_fleet_busy`)
- Test: `who-knows/test/unit/test_fleet.gd`, `who-knows/test/unit/test_floating_origin_scene.gd`

**Interfaces:**
- Consumes: `WarpArrival.play`, `WarpArrival.of`, `WarpArrival.DURATION` (Task 6).
- Produces: `Fleet.arriving(ship: Ship) -> bool`; `Fleet.busy() -> String` (`"a ship arriving"`
  or `""`); `Fleet.nearest` skips arriving ships; `Fleet.check_sleep` never sleeps one;
  `SuitTie.check` never ties to one; `flight_test._fleet_busy()` says `"a ship arriving"` first.

- [ ] **Step 1: Write the failing tests**

Append to `test_fleet.gd`:

```gdscript
## Ship library spec §6.3: a ship arriving out of warp is not yet one to use.
## The arrival is stepped by hand.
func _arriving(off := OFF) -> Array:
	var ship := _spawn(off)
	var a := WarpArrival.play(ship.exterior, ship.exterior.global_transform)
	a.set_physics_process(false)
	return [ship, a]

func test_a_ship_is_arriving_until_it_stops():
	var pair := _arriving()
	assert_true(_fleet.arriving(pair[0]))
	assert_false(_fleet.arriving(_starter))
	(pair[1] as WarpArrival)._physics_process(WarpArrival.DURATION + 0.01)
	assert_false(_fleet.arriving(pair[0]))

func test_f8_skips_a_ship_still_arriving():
	var pair := _arriving()
	assert_null(_fleet.nearest(_starter.exterior.global_position, _starter))
	assert_false(_root.board_nearest())
	(pair[1] as WarpArrival)._physics_process(WarpArrival.DURATION + 0.01)
	assert_same(_fleet.nearest(_starter.exterior.global_position, _starter), pair[0])

func test_a_ship_arriving_never_sleeps():
	var pair := _arriving(Vector3(0, 0, 25000))
	_fleet.check_sleep()
	assert_false(_fleet.sleeping(pair[0]))

func test_the_save_waits_for_an_arrival():
	var pair := _arriving()
	assert_eq(_fleet.busy(), "a ship arriving")
	assert_eq(_root._fleet_busy(), "a ship arriving")
	(pair[1] as WarpArrival)._physics_process(WarpArrival.DURATION + 0.01)
	assert_eq(_fleet.busy(), "")

func test_the_suit_is_not_tied_to_a_ship_still_arriving():
	var pair := _arriving(Vector3(0, 0, -600))
	var a: WarpArrival = pair[1]
	a._physics_process(WarpArrival.DURATION - 0.1)
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var near_it := (pair[0] as Ship).exterior.global_position + Vector3(20, 0, 0)
	avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis.IDENTITY, near_it), Vector3.ZERO, _starter.exterior)
	_root.suit_tie.check()
	assert_same(_root.aboard, _starter, "not tied to it while it arrives")
	a._physics_process(0.2)
	_root.suit_tie.check()
	assert_same(_root.aboard, pair[0], "tied to it once it has arrived")
```

Append to `test_floating_origin_scene.gd`:

```gdscript
## Ship library spec §6.2: a ship arriving out of warp, its wake and its flash,
## is covered.
func test_a_ship_arriving_is_covered():
	var place := Transform3D(Basis.IDENTITY, _ship.exterior.global_position + Vector3(300, 0, 0))
	var ship: Ship = _root.fleet.spawn(_root._starter_grid(), place)
	var a := WarpArrival.play(ship.exterior, place)
	a.set_physics_process(false)
	a._physics_process(0.3)
	assert_eq(_uncovered(), [], "flying in, its wake behind it")
	a._physics_process(WarpArrival.DURATION)
	assert_eq(_uncovered(), [], "and its flash")
```

- [ ] **Step 2: Run them to watch them fail**

Run: `& $env:TEMP\sl_run.ps1 test_fleet test_floating_origin_scene`
Expected: `test_fleet` FAIL (`Invalid call... 'arriving'` and the F8, sleep, busy and suit tests);
`test_floating_origin_scene` PASS (the arrival's pieces are already the hull's children: this pins
it).

- [ ] **Step 3: Teach the fleet**

In `fleet.gd`, after `func sleeping(...)`:

```gdscript
## True while `ship` arrives out of warp (ship library spec §6.3): not yet a
## ship to board, remove, sleep, tie a suit to or save.
func arriving(ship: Ship) -> bool:
	return WarpArrival.of(ship.exterior) != null

## Why a save must wait on the fleet itself, or "": a ship still arriving.
func busy() -> String:
	for ship in awake():
		if arriving(ship):
			return "a ship arriving"
	return ""
```

In `nearest`, change its doc comment's first line to `## The awake ship whose hull is nearest
\`point\`, other than \`except\` and any still arriving; null if` and its skip to:

```gdscript
		if ship == except or arriving(ship):
			continue
```

In `check_sleep`, after the `if ship == mine:` block's `continue`, add:

```gdscript
		if arriving(ship):
			continue
```

In `suit_tie.gd`'s `check()`, replace `var ships := fleet.awake()` with:

```gdscript
	# A ship still arriving out of warp is no ship to belong to yet.
	var ships: Array[Ship] = []
	for ship in fleet.awake():
		if not fleet.arriving(ship):
			ships.append(ship)
```

In `flight_test.gd`'s `_fleet_busy()`, first lines of the body:

```gdscript
	var arriving := fleet.busy()
	if arriving != "":
		return arriving
```

- [ ] **Step 4: Run them to watch them pass**

Run: `& $env:TEMP\sl_run.ps1 test_fleet test_floating_origin_scene test_suit_tie test_boarding_scene`
Expected: all PASS, 0 script errors.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/fleet.gd who-knows/src/ship/suit_tie.gd who-knows/scenes/flight_test.gd who-knows/test/unit/test_fleet.gd who-knows/test/unit/test_floating_origin_scene.gd
git commit -m "feat: a ship arriving out of warp is skipped by F8 and the suit, never sleeps, and holds the save"
```

---

### Task 8: `SpawnSpot`

**Files:**
- Create: `who-knows/src/ship/spawn_spot.gd`
- Test: `who-knows/test/unit/test_spawn_spot.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name SpawnSpot extends RefCounted`; `const AHEAD := 200.0`, `FARTHER := 400.0`,
  `STEP_DEG := 45.0`, `CLEAR := 60.0`, `STEPS: Array[int]`;
  `static func find(from: Transform3D, ships: Array[Vector3], rock_near: Callable) -> Variant`
  (a `Transform3D`, or null). `rock_near` takes an engine `Vector3` and returns `bool`.

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_spawn_spot.gd`:

```gdscript
extends GutTest

## SpawnSpot (docs/superpowers/specs/2026-10-02-ship-library-design.md §5):
## straight ahead when clear, the next step round you when not, farther out
## after that, never into a rock or a ship, and always facing you.

var _from: Transform3D
var _no_rocks := func(_p: Vector3) -> bool: return false
var _no_ships: Array[Vector3] = []

func before_each():
	_from = Transform3D(Basis(Vector3.UP, 0.7), Vector3(10, 5, -30))

func _ahead() -> Vector3:
	return -_from.basis.z

func _angle_off_ahead(spot: Transform3D) -> float:
	return rad_to_deg((spot.origin - _from.origin).angle_to(_ahead()))

func test_clear_it_is_straight_ahead():
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, _no_rocks)
	assert_almost_eq(spot.origin, _from.origin + _ahead() * SpawnSpot.AHEAD, Vector3.ONE * 0.001)

func test_it_faces_you_upright():
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, _no_rocks)
	assert_almost_eq((-spot.basis.z).dot((_from.origin - spot.origin).normalized()), 1.0, 0.0001)
	assert_almost_eq(spot.basis.y.dot(_from.basis.y), 1.0, 0.0001)

func test_a_rock_ahead_moves_it_one_step_round():
	var blocked := _from.origin + _ahead() * SpawnSpot.AHEAD
	var rocks := func(p: Vector3) -> bool: return p.distance_to(blocked) < 1.0
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, rocks)
	assert_almost_eq(_angle_off_ahead(spot), SpawnSpot.STEP_DEG, 0.01)
	assert_almost_eq(spot.origin.distance_to(_from.origin), SpawnSpot.AHEAD, 0.001)

func test_a_ship_ahead_moves_it_too():
	var ships: Array[Vector3] = [_from.origin + _ahead() * (SpawnSpot.AHEAD + SpawnSpot.CLEAR - 5.0)]
	var spot: Transform3D = SpawnSpot.find(_from, ships, _no_rocks)
	assert_almost_eq(_angle_off_ahead(spot), SpawnSpot.STEP_DEG, 0.01)

func test_blocked_all_round_it_goes_farther_out():
	var rocks := func(p: Vector3) -> bool: return p.distance_to(_from.origin) < SpawnSpot.AHEAD + 1.0
	var spot: Transform3D = SpawnSpot.find(_from, _no_ships, rocks)
	assert_almost_eq(spot.origin, _from.origin + _ahead() * SpawnSpot.FARTHER, Vector3.ONE * 0.001)

func test_with_nothing_clear_it_refuses():
	assert_null(SpawnSpot.find(_from, _no_ships, func(_p: Vector3) -> bool: return true))
```

- [ ] **Step 2: Run it to watch it fail**

Run: `& $env:TEMP\sl_run.ps1 test_spawn_spot`
Expected: FAIL with `Identifier "SpawnSpot" not declared`.

- [ ] **Step 3: Write `SpawnSpot`**

`who-knows/src/ship/spawn_spot.gd`:

```gdscript
class_name SpawnSpot
extends RefCounted

## Where a ship spawned for you arrives (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §5): AHEAD in front of you, turned to face
## you, clear of rocks as a warp's drop-out is and CLEAR of every other ship.
## Blocked, it tries the same distance in STEP_DEG steps round you, the ones
## nearest the way you face first, then FARTHER out the same way. Pure: rocks
## are asked through a callable.

const AHEAD := 200.0
const FARTHER := 400.0
const STEP_DEG := 45.0
const CLEAR := 60.0
## The steps round you in the order tried: ahead, then each side, behind last.
const STEPS: Array[int] = [0, 1, -1, 2, -2, 3, -3, 4]

## The spot, or null when nowhere is clear. `from` is where you look from, its
## -z the way you face; `ships` every other ship's hull position; `rock_near`
## takes an engine position and says whether a rock is too near it.
static func find(from: Transform3D, ships: Array[Vector3], rock_near: Callable) -> Variant:
	var up := from.basis.y.normalized()
	var ahead := -from.basis.z.normalized()
	for distance: float in [AHEAD, FARTHER]:
		for step in STEPS:
			var dir := ahead.rotated(up, deg_to_rad(STEP_DEG * step))
			var p := from.origin + dir * distance
			if rock_near.call(p) or _near_a_ship(p, ships):
				continue
			return Transform3D(Basis.looking_at(-dir, up), p)
	return null

static func _near_a_ship(p: Vector3, ships: Array[Vector3]) -> bool:
	for s in ships:
		if p.distance_to(s) < CLEAR:
			return true
	return false
```

- [ ] **Step 4: Run it to watch it pass**

Run: `& $env:TEMP\sl_run.ps1 test_spawn_spot`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/spawn_spot.gd who-knows/src/ship/spawn_spot.gd.uid who-knows/test/unit/test_spawn_spot.gd who-knows/test/unit/test_spawn_spot.gd.uid
git commit -m "feat: SpawnSpot -- 200 m ahead, facing you, stepping round rocks and ships"
```

---

### Task 9: The F6 spawn panel

**Files:**
- Create: `who-knows/src/ui/spawn_panel.gd`
- Modify: `who-knows/scenes/flight_test.gd` (`spawn_panel`; `_wire_spawn`, `spawn_from_library`,
  `remove_nearest_spawned`, `_spawn_view`, `_spawn_velocity`, `_rock_near`)
- Test: `who-knows/test/unit/test_spawn_panel.gd`

**Interfaces:**
- Consumes: `library` (Task 2); `WarpArrival.play`, `of`, `DURATION` (Task 6);
  `Fleet.arriving`, `busy` (Task 7); `SpawnSpot.find`, `AHEAD` (Task 8); `WarpPlan.rock_near(recipe,
  upoint)`; `_stream.recipe`; `_universe.to_universe`; `Avatar.Mode.SUIT`, `_avatar.camera`,
  `_avatar.velocity`; `fleet.max_ships`; `ship.warp.is_spinning()`; `ship.launch_blueprint.ship_name`.
- Produces:
  - `class_name SpawnPanel extends Label`; `signal spawn_asked(index: int)`; `signal remove_asked`;
    `const KEY := KEY_F6`; `const MOST := 9`; `var entries: Array[String]`; `func say(text: String)`
  - `flight_test.spawn_panel: SpawnPanel`; `flight_test.spawn_from_library(id: StringName) -> String`;
    `flight_test.remove_nearest_spawned() -> String`; `flight_test._rock_near(p: Vector3) -> bool`

- [ ] **Step 1: Write the failing test**

`who-knows/test/unit/test_spawn_panel.gd`:

```gdscript
extends GutTest

## The spawn panel in the real flight scene (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §5, §6.3): F6, a number to spawn a library
## ship ahead of you out of warp, Delete to take one away, and every refusal.
## Arrivals are stepped by hand.

var _root: Node
var _panel: SpawnPanel
var _starter: Ship
var _fleet: Fleet

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_panel = _root.spawn_panel
	_starter = _root.get_node("Ship")
	_fleet = _root.fleet
	await wait_process_frames(2)

func after_each():
	if is_instance_valid(_starter):
		_starter.warp.stage = WarpDrive.Stage.IDLE

func _key(code: Key, echo := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	_panel._unhandled_key_input(ev)

func _open_and_spawn() -> Ship:
	_key(KEY_F6)
	_key(KEY_1)
	return _newest()

func _newest() -> Ship:
	var ships := _fleet.ships()
	return ships[ships.size() - 1]

## Steps `ship`'s arrival to its stop.
func _land(ship: Ship) -> void:
	var a := WarpArrival.of(ship.exterior)
	if a != null:
		a._physics_process(WarpArrival.DURATION + 0.01)

func _last_line() -> String:
	var lines := _panel.text.split("\n")
	return lines[lines.size() - 1]

func test_f6_opens_and_shuts_it():
	assert_false(_panel.visible)
	_key(KEY_F6)
	assert_true(_panel.visible)
	assert_string_contains(_panel.text, "1  Starter shuttle")
	assert_string_contains(_panel.text, "Del  remove the nearest spawned ship")
	_key(KEY_F6)
	assert_false(_panel.visible)

func test_shut_1_and_delete_do_nothing():
	_key(KEY_1)
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 1)
	assert_false(_panel.visible)

func test_1_spawns_the_starter_ahead_arriving_out_of_warp():
	var view := _starter.exterior.global_transform
	var expected: Transform3D = SpawnSpot.find(view, [view.origin] as Array[Vector3], Callable(_root, "_rock_near"))
	var ship := _open_and_spawn()
	assert_eq(_fleet.ships().size(), 2)
	assert_true(_fleet.arriving(ship), "it arrives out of warp")
	assert_eq(ship.launch_blueprint.ship_name, "Starter shuttle")
	assert_eq(_last_line(), "SPAWNED %s · Starter shuttle · %d m away" % [ship.name,
		roundi(view.origin.distance_to(expected.origin))])
	_land(ship)
	assert_almost_eq(ship.exterior.global_position, expected.origin, Vector3.ONE * 0.01)
	assert_eq(ship.exterior.linear_velocity, Vector3.ZERO, "at rest")
	var nose := -ship.exterior.global_basis.z
	assert_gt(nose.dot((view.origin - ship.exterior.global_position).normalized()), 0.999, "facing you")

func test_spawned_while_cruising_it_lands_ahead_of_where_you_will_be():
	_starter.exterior.linear_velocity = -_starter.exterior.global_basis.z * 120.0
	var view := _starter.exterior.global_transform
	var led := view.translated(_starter.exterior.linear_velocity * WarpArrival.DURATION)
	var expected: Transform3D = SpawnSpot.find(led, [view.origin] as Array[Vector3], Callable(_root, "_rock_near"))
	var ship := _open_and_spawn()
	_land(ship)
	assert_almost_eq(ship.exterior.global_position, expected.origin, Vector3.ONE * 0.01)

func test_on_a_spacewalk_it_lands_ahead_of_your_view():
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var out := _starter.exterior.global_position + _starter.exterior.global_basis.x * 40.0
	avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis(Vector3.UP, 1.2), out), Vector3.ZERO, _starter.exterior)
	var view := avatar.camera.global_transform
	var expected: Transform3D = SpawnSpot.find(view, [_starter.exterior.global_position] as Array[Vector3],
		Callable(_root, "_rock_near"))
	var ship := _open_and_spawn()
	_land(ship)
	assert_almost_eq(ship.exterior.global_position, expected.origin, Vector3.ONE * 0.01)

func test_a_held_1_spawns_one_ship():
	_open_and_spawn()
	_key(KEY_1, true)
	_key(KEY_1, true)
	assert_eq(_fleet.ships().size(), 2)

func test_a_second_spawn_waits_for_the_first_to_arrive():
	var first := _open_and_spawn()
	_key(KEY_1)
	assert_eq(_fleet.ships().size(), 2)
	assert_eq(_last_line(), "A SHIP IS ARRIVING")
	_land(first)
	_key(KEY_1)
	assert_eq(_fleet.ships().size(), 3)

func test_f8_skips_it_while_it_arrives_and_boards_it_after():
	var ship := _open_and_spawn()
	assert_false(_root.board_nearest())
	_land(ship)
	assert_true(_root.board_nearest())
	assert_same(_root.aboard, ship)

func test_refused_when_the_fleet_is_full():
	_fleet.max_ships = 1
	_open_and_spawn()
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "THE FLEET IS FULL")

func test_refused_during_a_warp():
	_starter.warp.stage = WarpDrive.Stage.SPOOLING
	_open_and_spawn()
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "WARP ENGAGED")

func test_delete_removes_the_nearest_spawned_ship():
	var ship := _open_and_spawn()
	_land(ship)
	var ship_name := ship.name
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "REMOVED %s · Starter shuttle" % ship_name)

func test_delete_never_takes_the_starter():
	_key(KEY_F6)
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 1)
	assert_eq(_last_line(), "NO SPAWNED SHIP")

func test_delete_skips_a_ship_still_arriving():
	_open_and_spawn()
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 2)
	assert_eq(_last_line(), "NO SPAWNED SHIP")

func test_on_a_spacewalk_tied_to_the_only_spawned_ship_delete_says_so():
	var ship := _open_and_spawn()
	_land(ship)
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var beside := ship.exterior.global_position + ship.exterior.global_basis.x * 25.0
	avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis.IDENTITY, beside), Vector3.ZERO, _starter.exterior)
	_root.suit_tie.check()
	assert_same(_root.aboard, ship, "your suit is its")
	_key(KEY_DELETE)
	assert_eq(_fleet.ships().size(), 2)
	assert_eq(_last_line(), "YOU ARE ABOARD IT")

func test_the_save_waits_for_an_arrival():
	var ship := _open_and_spawn()
	assert_eq(_root._fleet_busy(), "a ship arriving")
	_land(ship)
	assert_eq(_root._fleet_busy(), "")
```

- [ ] **Step 2: Run it to watch it fail**

Run: `& $env:TEMP\sl_run.ps1 test_spawn_panel`
Expected: FAIL (`Identifier "SpawnPanel" not declared`).

- [ ] **Step 3: Write `SpawnPanel`**

`who-knows/src/ui/spawn_panel.gd`:

```gdscript
class_name SpawnPanel
extends Label

## The spawn panel (docs/superpowers/specs/2026-10-02-ship-library-design.md
## §5), a debug tool in the plain style of the F3 readout: F6 opens and shuts
## it; while it is open 1-9 ask for that ship and Delete asks to remove the
## nearest spawned one. Shut, those keys do nothing, and a held key's repeats
## never do. It only asks: the flight scene does the work and says how it went
## on the last line, so src/ui never learns about Fleet or Ship.

signal spawn_asked(index: int)
signal remove_asked

const KEY := KEY_F6
## The number keys 1-9: the most ships the panel lists.
const MOST := 9
## Below the F3 readout, so both can be open.
const AT := Vector2(16, 140)

## One line per library ship, in the library's order.
var entries: Array[String] = []:
	set(value):
		entries = value
		_redraw()
var _said := ""

func _ready() -> void:
	position = AT
	visible = false
	_redraw()

## Shows `text` on the last line: what the last ask came to.
func say(text: String) -> void:
	_said = text
	_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY:
		visible = not visible
	elif not visible:
		return
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var i: int = key.keycode - KEY_1
		if i >= mini(entries.size(), MOST):
			return
		spawn_asked.emit(i)
	elif key.keycode == KEY_DELETE:
		remove_asked.emit()
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _redraw() -> void:
	var lines := PackedStringArray(["SPAWN                F6 closes"])
	for i in mini(entries.size(), MOST):
		lines.append("%d  %s" % [i + 1, entries[i]])
	lines.append("Del  remove the nearest spawned ship")
	if _said != "":
		lines.append(_said)
	text = "\n".join(lines)
```

- [ ] **Step 4: Wire it into the flight scene**

In `flight_test.gd`, add beside `var warp_panel: WarpPanel`:

```gdscript
## The spawn panel (ship library spec §5): F6.
var spawn_panel: SpawnPanel
```

Call `_wire_spawn()` in `_ready()` right after `_wire_warp()`. Add, after `warp_busy_for`:

```gdscript
## The spawn panel (ship library spec §5): F6 lists the library; a number
## spawns that ship ahead of you, arriving out of warp; Delete removes the
## nearest spawned one.
func _wire_spawn() -> void:
	spawn_panel = SpawnPanel.new()
	spawn_panel.name = "SpawnPanel"
	var lines: Array[String] = []
	for id in library.ids():
		lines.append("%s   %s" % [library.name_of(id), library.description_of(id)])
	spawn_panel.entries = lines
	spawn_panel.spawn_asked.connect(func(i: int) -> void:
		spawn_panel.say(spawn_from_library(library.ids()[i])))
	spawn_panel.remove_asked.connect(func() -> void: spawn_panel.say(remove_nearest_spawned()))
	$Prompt.add_child(spawn_panel)

## Spawns library ship `id` ahead of you, arriving out of warp (§5, §6), as the
## panel's number keys do: ahead of where you will be when it lands, so a spawn
## while cruising does not land in your path. Says what it did, or why not.
func spawn_from_library(id: StringName) -> String:
	if not library.has(id):
		return "NO SHIP CALLED %s" % id
	for ship in fleet.ships():
		if ship.warp.is_spinning():
			return "WARP ENGAGED"
	if fleet.busy() != "":
		return "A SHIP IS ARRIVING"
	if fleet.ships().size() >= fleet.max_ships:
		return "THE FLEET IS FULL"
	var view := _spawn_view()
	var others: Array[Vector3] = []
	for ship in fleet.awake():
		others.append(ship.exterior.global_position)
	var spot: Variant = SpawnSpot.find(view.translated(_spawn_velocity() * WarpArrival.DURATION), others, _rock_near)
	if spot == null:
		return "NO CLEAR SPOT NEAR"
	var place: Transform3D = spot
	var grid := library.grid(id)
	var ship := fleet.spawn(grid, place, true, "", ShipBlueprint.from_grid(grid, library.name_of(id)))
	WarpArrival.play(ship.exterior, place)
	return "SPAWNED %s · %s · %d m away" % [ship.name, library.name_of(id), roundi(view.origin.distance_to(place.origin))]

## Removes the nearest spawned ship (any but the starter, awake and arrived)
## other than the one you are aboard, as the panel's Delete does (§5). Says
## what it did, or why not.
func remove_nearest_spawned() -> String:
	var here := _spawn_view().origin
	var spawned := 0
	var best: Ship = null
	for ship in fleet.awake():
		if ship.name == Fleet.STARTER or fleet.arriving(ship):
			continue
		spawned += 1
		if ship == aboard:
			continue
		if best == null or here.distance_to(ship.exterior.global_position) < here.distance_to(best.exterior.global_position):
			best = ship
	if spawned == 0:
		return "NO SPAWNED SHIP"
	if best == null:
		return "YOU ARE ABOARD IT"
	var what := "%s · %s" % [best.name, best.launch_blueprint.ship_name]
	fleet.remove(best)
	return "REMOVED " + what

## Where you look from: the hull you are aboard, or your view on a spacewalk.
func _spawn_view() -> Transform3D:
	return _avatar.camera.global_transform if _avatar.mode == Avatar.Mode.SUIT else aboard.exterior.global_transform

func _spawn_velocity() -> Vector3:
	return _avatar.velocity if _avatar.mode == Avatar.Mode.SUIT else aboard.exterior.linear_velocity

## True when a rock is too near `p` for a ship to arrive there, as for a
## warp's drop-out (§5).
func _rock_near(p: Vector3) -> bool:
	return WarpPlan.rock_near(_stream.recipe, _universe.to_universe(p))
```

- [ ] **Step 5: Run it to watch it pass, with its neighbours**

Run: `& $env:TEMP\sl_run.ps1 test_spawn_panel test_fleet test_boarding_scene test_save_scene test_input_map test_controls_card`
Expected: all PASS, 0 script errors.

- [ ] **Step 6: Commit**

```bash
git add who-knows/src/ui/spawn_panel.gd who-knows/src/ui/spawn_panel.gd.uid who-knows/scenes/flight_test.gd who-knows/test/unit/test_spawn_panel.gd who-knows/test/unit/test_spawn_panel.gd.uid
git commit -m "feat: F6 spawn panel -- a number brings a library ship in out of warp; Delete takes one away"
```

---

### Task 10: Through the panel in real time; renders and fps

**Files:**
- Modify: `who-knows/test/probes/fleet_play.gd` (`_run`'s spawn)
- Create: `who-knows/test/probes/arrival_render.gd`

**Interfaces:**
- Consumes: `spawn_panel`, `spawn_from_library`, `remove_nearest_spawned`, `fleet.arriving` (Tasks
  7, 9); `ShipLights.FLOOD`, `ShipLights.FORWARD`, `ship.lights.set_group`; `CameraDirector.sit_now`,
  `cycle_view`; `RockContacts.RANGE`, `RockContacts.KIND`, `ship.sensors.contacts`; `AsteroidBody.LAYER`.
- Produces: renders in an out directory; the owner sees them.

- [ ] **Step 1: `fleet_play.gd` spawns through the panel**

Add a helper after `_check`:

```gdscript
## A key as the player presses it: down and up, through the engine's input.
func _press(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
	await _frames(2)
```

In `_run`, replace `var second := fleet.spawn(scene.call("_starter_grid"), stern_to_stern)` and the
`await _frames(5)` after it with:

```gdscript
	# Through the spawn panel (ship library spec §7.2): F6, 1, and it arrives out
	# of warp ahead of the starter; then it is parked stern to stern for the trip.
	await _press(KEY_F6)
	await _press(KEY_1)
	var second: Ship = fleet.ships()[fleet.ships().size() - 1]
	_check(fleet.ships().size() == 2 and fleet.arriving(second), "F6, 1: %s arrives out of warp" % second.name)
	_check(await _until(func() -> bool: return not fleet.arriving(second), 3.0), "%s has arrived" % second.name)
	await _press(KEY_F6)
	await _frames(30)
	second.exterior.global_transform = stern_to_stern
	second.exterior.linear_velocity = Vector3.ZERO
	await _frames(5)
```

Also add to the header comment's first sentence: "a second starter spawned through the F6 panel,
arriving out of warp, then parked stern to stern with the first;".

Run (windowed, from `D:\git\whoknows-ship-library`):

```powershell
New-Item -ItemType Directory -Force "$env:TEMP\sl_play" | Out-Null
& $godot --path who-knows --resolution 1280x720 --script "$PWD\who-knows\test\probes\fleet_play.gd" -- "$env:TEMP\sl_play" 2>&1 | Select-String '^(ok|FAILED|play|render)'
```

Expected: every line `ok` (18 now: the two new ones and the trip's 16), no `FAILED`, no `TIMED OUT`.

- [ ] **Step 2: Write the arrival's render probe**

`who-knows/test/probes/arrival_render.gd`:

```gdscript
extends SceneTree

# A ship arriving out of warp, for the owner's eyes (docs/superpowers/specs/
# 2026-10-02-ship-library-design.md §6, §7.2): from the starter's seat and
# from the chase view, 0.2, 0.6 and 1.0 s into an arrival and after it; the
# spawn panel open in the cockpit; and the frame rate in the worst view (seated
# by a big rock's night side, both light groups on) with and without a ship
# arriving. Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 \
#     --script <abs path>/test/probes/arrival_render.gd -- <abs out dir>
#
# Saving is off before the scene enters the tree, so the owner's game is never
# touched.

var _out := ""

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	root.add_child(scene)
	# A script error mid-run stops _run without quitting: never hang.
	create_timer(120.0).timeout.connect(func() -> void:
		print("arrival TIMED OUT")
		quit(1))
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## The frame as it is now, with no frames waited: an arrival does not wait.
func _grab(shot_name: String) -> void:
	var file := "%s/arrival_%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _fps(seconds: float) -> float:
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < seconds * 1e6:
		await process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - start) / 1e6)

func _press(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
	await _frames(2)

## One arrival seen from wherever the view is now: shots 0.2, 0.6 and 1.0 s in
## and a second after it stops; then it is removed again.
func _watch(scene: Node, tag: String) -> void:
	var fleet: Fleet = scene.get("fleet")
	var start := Time.get_ticks_msec()
	var said: String = scene.call("spawn_from_library", ShipLibrary.STARTER)
	print("arrival %s: %s" % [tag, said])
	if not said.begins_with("SPAWNED"):
		return
	var ship: Ship = fleet.ships()[fleet.ships().size() - 1]
	for t: float in [0.2, 0.6, 1.0]:
		while (Time.get_ticks_msec() - start) / 1000.0 < t:
			await process_frame
		_grab("%s_%.1f" % [tag, t])
	while fleet.arriving(ship):
		await process_frame
	await _frames(60)
	_grab("%s_after" % tag)
	var starter: Ship = scene.get_node("Ship")
	print("arrival %s: at rest %.2f m/s, %.0f m from the starter" % [tag, ship.exterior.linear_velocity.length(),
		ship.exterior.global_position.distance_to(starter.exterior.global_position)])
	print("arrival %s: %s" % [tag, scene.call("remove_nearest_spawned")])
	await _frames(5)

## Nose on to a big rock's night side, `gap` off its surface, as ship_probe.gd
## parks for its worst view. False with no big rock in sensor range.
func _park_by_a_rock(scene: Node, ship: Ship, gap: float) -> bool:
	var universe: Universe = scene.get_node("Universe")
	var best: Contact = null
	for c in ship.sensors.contacts(RockContacts.RANGE):
		if c.kind == RockContacts.KIND:
			best = c
			break
	if best == null:
		return false
	var light_goes := -(scene.get_node("DirectionalLight3D") as DirectionalLight3D).global_basis.z
	var rock := universe.to_engine(best.point)
	var at := rock + light_goes * (best.radius + gap)
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.exterior.global_transform = Transform3D(Basis.looking_at(rock - at, Vector3.UP), at)
	await _frames(90)
	await physics_frame
	var space := ship.exterior.get_world_3d().direct_space_state
	var from := rock + light_goes * (best.radius * 1.5 + 200.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, rock, AsteroidBody.LAYER))
	var surface := best.radius if hit.is_empty() else (hit["position"] as Vector3).distance_to(rock)
	at = rock + light_goes * (surface + gap)
	var dir := (rock - at).normalized()
	ship.exterior.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT), at)
	await _frames(30)
	return true

func _run(scene: Node) -> void:
	await _frames(3)
	var starter: Ship = scene.get_node("Ship")
	var director: CameraDirector = scene.get_node("CameraDirector")
	director.sit_now(starter.seat)
	await _frames(30)
	await _press(KEY_F6)
	await _frames(5)
	_grab("panel")
	await _press(KEY_F6)
	await _watch(scene, "seat")
	director.cycle_view()
	await _frames(30)
	await _watch(scene, "chase")
	director.cycle_view()
	await _frames(10)
	starter.lights.set_group(ShipLights.FLOOD, true)
	starter.lights.set_group(ShipLights.FORWARD, true)
	if await _park_by_a_rock(scene, starter, 60.0):
		print("fps     %.0f seated by a rock, both groups on" % await _fps(2.0))
		var said: String = scene.call("spawn_from_library", ShipLibrary.STARTER)
		print("fps     %.0f the same, a ship arriving (%s)" % [await _fps(1.4), said])
	else:
		print("fps     no big rock in range")
	quit(0)
```

- [ ] **Step 3: Render, probe and look**

```powershell
New-Item -ItemType Directory -Force "$env:TEMP\sl_arrival", "$env:TEMP\sl_probe" | Out-Null
& $godot --path who-knows --resolution 1280x720 --script "$PWD\who-knows\test\probes\arrival_render.gd" -- "$env:TEMP\sl_arrival" 2>&1 | Select-String '^(arrival|fps|render)'
& $godot --path who-knows --resolution 1280x720 --script "$PWD\.claude\skills\building-a-ship\ship_probe.gd" -- "$env:TEMP\sl_probe" 2>&1 | Select-String '^(rules|note|ISSUE|grid|balance|fps|walked|board|fleet|SHADER)'
```

Expected: `arrival seat: SPAWNED Ship2 · Starter shuttle · 200 m away` (or a step round a rock),
`at rest 0.00 m/s`, `REMOVED Ship2 · Starter shuttle`; the same for `chase` with `Ship3`; two `fps`
lines, the arriving one within ~10% of the other (the starter held ~130 in this view before); the
probe's `rules   0 broken` with six `note    RCS_BLOCKED` lines, a `FEEL` and a `SIZE` line, no
`SHADER ERROR`, `walked` with no `STUCK`.

Open every `arrival_*.png` with the Read tool and judge them against the style guide: a thin warm
wake (not a beam that whites out the view), a soft flash that halos and fades, nothing outside the
palette. If the look is wrong, tune only `SpacePalette.WARP`, `WAKE_ALPHA`, `FLASH_ALPHA`,
`WAKE_WIDTH` or the flash scale, re-render, and record each change for the owner.

- [ ] **Step 4: Show the owner**

Send the eight arrival frames (`seat_0.2`, `seat_0.6`, `seat_1.0`, `seat_after`, the same four for
`chase`) and `arrival_panel.png` with `SendUserFile`, and say the two fps figures. The arrival's look
needs the owner's approval (style guide §6); record what they say in the spec's *What was built*.

- [ ] **Step 5: Commit**

```bash
git add who-knows/test/probes/fleet_play.gd who-knows/test/probes/arrival_render.gd who-knows/test/probes/arrival_render.gd.uid who-knows/src/world/space_palette.gd who-knows/src/flight/warp_arrival.gd
git commit -m "test: fleet_play spawns through the F6 panel; the arrival's renders and fps"
```

---

### Task 11: The skill, `CLAUDE.md`, the style guide and the spec

**Files:**
- Modify: `.claude/skills/building-a-ship/SKILL.md`, `.claude/skills/building-a-ship/reference.md`
- Modify: `CLAUDE.md`, `docs/design/visual-style.md` (§3.8)
- Modify: `docs/superpowers/specs/2026-10-02-ship-library-design.md` (status line; §12)

**Interfaces:** none (documentation). Every name written here must exist: grep for it.

- [ ] **Step 1: The skill's `SKILL.md`**

- **Overview:** replace "The worked example is the starter shuttle: `_starter_grid()` in
  `who-knows/scenes/flight_test.gd`. Its comments explain every block that isn't obvious." with
  "The worked example is the starter shuttle: `who-knows/data/ships/starter.json`, with
  `starter.md` beside it explaining every block that isn't obvious."
- **A new step 0 at the top of the checklist:**
  "0. **A ship is a file** (`docs/superpowers/specs/2026-10-02-ship-library-design.md`):
  `who-knows/data/ships/<id>.json` plus `<id>.md` beside it, the id the file's name, one row
  `[x, y, z, block, orientation]` per line (`ShipLibrary.write` writes the form). Run `ship_check.gd`
  on it until it exits 0; it runs every rule (`ShipRules`) in seconds. `test_ship_catalog.gd` then
  holds it to the rules and to being usable, with no test of its own. F6 in the game spawns it."
- **Step 9 (probe):** add "the `rules` line (`0 broken`, or each `<-- CODE`) and the notes;".
- **Mistakes already made**, new rows:
  - "A rule that failed the starter | `NO_STAND` as first written wanted the cell behind the helm
    free, but the starter's quantum core stands there; the seat stands you up beside it | Check a
    new rule on the starter first; `ShipRules.stand_cell` is where you stand up to"
  - "Testing a rule with a broken copy that cannot break it | Two solid cells behind a porthole
    remove the porthole rather than leave it unmatched | Check each broken copy breaks its rule on
    the real starter before writing the test"
  - "`-gtest=` to run one test file | With this `.gutconfig.json` it ran the whole suite | `-gselect=<file>.gd`"
- **Not built yet:** "**Multi-level ships**: written and checked now, usable once ladders climb:
  `CUT_OFF` names every storey the helm can't reach ('ladders don't climb yet'). The climbing
  project gives `DeckPaths` its vertical links, and the same rule then passes."

- [ ] **Step 2: The skill's `reference.md`**

Add a section after "Many ships":

```markdown
## The ship library and the rules (`docs/superpowers/specs/2026-10-02-ship-library-design.md`)

**A ship file**, `who-knows/data/ships/<id>.json`, named for its id, with `<id>.md` beside it:

    {
    	"id": "starter",
    	"name": "Starter shuttle",
    	"description": "One line.",
    	"format": 1,
    	"cells": [
    		[-3, 0, 1, "hull", 0],
    		...
    	]
    }

Rows are `[x, y, z, block, orientation]`, sorted by x, y, z, one per line; no damage; `y` any
storey. A load error names the file and row: bad JSON, a newer format, a row that is not five
values (whole numbers, a block name, orientation 0–23), two rows in one cell, an id that is not the
file's name.

| `ShipLibrary` (`src/ship/ship_library.gd`) | |
|---|---|
| `load_from_dir(path := "res://data/ships")`, `errors` | every `*.json`; broken files are in `errors` and left out |
| `read(path)` | one file: `{id, name, description, grid}` or `{error}` |
| `ids()`, `has`, `name_of`, `description_of`, `grid(id)` | sorted, the starter first; a fresh intact grid each call |
| `write(path, id, name, description, grid)`, `rows_text(grid)` | the one-row-per-line form; the starter's pin hashes `rows_text` |
| `STARTER`, `FORMAT`, `DIR` | `&"starter"`, 1, `res://data/ships` |

**`ShipRules.check(grid, catalog)`** → `{rules, notes}`, each `{code, text, cell}`. A library ship
breaks no rule:

| Code | Broken when |
|---|---|
| `UNKNOWN_BLOCK` | a block id is not in `data/blocks` (nothing else is checked) |
| `VALIDATOR` | `ShipValidator.validate` reports anything, warnings too |
| `POWER_MARGIN` | power made ≤ drawn × 1.1 |
| `CANNOT_THRUST`, `CANNOT_BRAKE` | no forward, or no reverse, thrust |
| `NO_AUTHORITY` | no pitch, yaw or roll authority |
| `UNBALANCED` | a full burn's imbalance ≥ 5% of an axis's authority |
| `CRIPPLED` | crippled as built |
| `NO_POD` | no helm looks straight at a canopy |
| `NO_STAND` | none of the cells behind and beside the helm is open floor (`ShipRules.stand_cell`) |
| `NO_AIRLOCK` | no airlock cycles with a way through its inner hatch |
| `CUT_OFF` | a walkable cell (not a fixture or the airlock), or an airlock's inner cell, can't be reached on foot from where you stand up; another storey says "ladders don't climb yet" |
| `WINDOW_UNMATCHED` | an inside window has no place outside (`HullLayout.unmatched`) |
| `DROID` | 12+ walkable cells and no dock, or a job the droid can't reach from it |
| `NO_PIECES` | a hull section has no plating or fairing outside the shell to lose |

Notes, never failing: `RCS_BLOCKED` (per block), `FEEL`, `SIZE`.

**`ship_check.gd`** (beside the probe): `godot --headless --path who-knows --script <abs>/ship_check.gd -- <abs or res:// path>.json`.
Prints `rules   N broken`, each `<--   CODE text at (x, y, z)`, then `note` lines; exits 0 with
none broken, 1 otherwise or on `load` errors. A few seconds.

**The F6 panel** (`src/ui/spawn_panel.gd`; the flight scene's `spawn_from_library(id)` and
`remove_nearest_spawned()`): 1–9 spawn that library ship 200 m ahead of where you will be in
1.5 s, facing you (`SpawnSpot`: 45° steps round rocks, `WarpPlan.rock_near`, and ships 60 m, then
400 m); Delete removes the nearest spawned ship but yours. Refusals: `WARP ENGAGED`,
`A SHIP IS ARRIVING`, `THE FLEET IS FULL`, `NO CLEAR SPOT NEAR`, `NO SPAWNED SHIP`,
`YOU ARE ABOARD IT`. A spawned ship's `launch_blueprint.ship_name` is its library name.

**`WarpArrival.play(hull, at, end_velocity := ZERO)`** (`src/flight/warp_arrival.gd`): 1.5 s in
from 2 km back along the nose (distance `(1 − t)³`), a wake and a flash in `SpacePalette.WARP`,
ghosted (frozen kinematic, layer and mask 0) until it stops, then `arrived`. `WarpArrival.of(hull)`
is the arrival still flying in; `Fleet.arriving(ship)` is true meanwhile: F8, Delete and the suit
skip it, it never sleeps, and `Fleet.busy()` holds the save (`"a ship arriving"`). Anything that sets
a hull's layer, mask or freeze must check this as it does `warp.travelling()`.
```

In the **Commands** section, add the `ship_check.gd` line and:
`run one test file: .\run_tests.ps1 '-gselect=test_x.gd'` (from `who-knows`; `-gtest` runs the whole
suite with this config).

- [ ] **Step 3: `CLAUDE.md`**

In "Ship building: keep the `building-a-ship` skill current", after its first paragraph, add:
"**Every ship lives in `data/ships/`** (`<id>.json` plus `<id>.md`) and passes `ShipRules`:
`test_ship_catalog.gd` checks every one, and `.claude/skills/building-a-ship/ship_check.gd` checks a
draft in seconds (`docs/superpowers/specs/2026-10-02-ship-library-design.md`)."

In "Every ship is usable", change "any other is `fleet.spawn(grid, place)`" to "any other is
`fleet.spawn(grid, place)`, from the library (F6 in the game) or a save".

- [ ] **Step 4: The style guide, §3.8**

At the end of §3.8 "The hull's outside" in `docs/design/visual-style.md`, add:

"**A ship arriving out of warp** (`WarpArrival`, ship library spec §6) is the one effect outside
that is not a light: a thin wake (0.6 m across) behind its stern, as long as the way it came in the
last 0.15 s, and a soft shell of light round the hull as it stops, growing from 1.0 to 1.6 of its
bounds over 0.4 s while it fades. Both are engine `StandardMaterial3D`, unshaded and additive, in
`SpacePalette.WARP`, a warm white near the work lights that bloom halos. No new shader. Approved by
the owner from renders on <date>." (Fill in the date and any tuning from Task 10 Step 4.)

- [ ] **Step 5: The spec**

Change the status line to "Designed with the owner on 2026-10-02; amended while planning
2026-10-03 (§11); built <date> (§12)." Append `## 12. What was built`: the files (Task list),
any rulings made while building, the arrival's tuned values and the owner's verdict on the renders,
the fps figures from Task 10, the probe's `rules` line, and the deferred minors.

- [ ] **Step 6: Check every name the docs use exists**

```powershell
foreach ($n in 'ShipLibrary','ShipRules','stand_cell','rows_text','spawn_from_library','remove_nearest_spawned','SpawnSpot','SpawnPanel','WarpArrival','arriving','SpacePalette.WARP','ship_check.gd') { "{0}: {1}" -f $n, (Get-ChildItem -Recurse who-knows\src, who-knows\scenes, .claude\skills -Include *.gd | Select-String -SimpleMatch $n -List).Count }
```

Expected: every count ≥ 1.

- [ ] **Step 7: Run the touched tests once more, then commit**

Run: `& $env:TEMP\sl_run.ps1 test_ship_library test_starter_shuttle test_ship_rules test_ship_catalog test_warp_arrival test_visual_style_rules test_fleet test_floating_origin_scene test_spawn_spot test_spawn_panel test_suit_tie test_boarding_scene test_save_scene`
Expected: all PASS.

```bash
git add .claude/skills/building-a-ship CLAUDE.md docs/design/visual-style.md docs/superpowers/specs/2026-10-02-ship-library-design.md
git commit -m "docs: the ship library as built -- the skill, CLAUDE.md, the arrival in the style guide"
```

Then ask the owner whether to run the full suite (about 8 minutes, in the background, logged) before
the branch is finished.
