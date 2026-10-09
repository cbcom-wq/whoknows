# Ship Designer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `ship-designer` agent that designs, builds and proves a usable ship from a description or "be creative", drawing it as a deck plan that a new tool turns into the library's JSON.

**Architecture:** `ShipPlan` (pure, `src/ship/`) parses a deck plan into a `ShipGrid` and prints a grid back, exactly; `ship_plan.gd` is its command-line tool beside `ship_check.gd`. `flight_test.gd`'s `starter_ship` (and `--ship` on the probe and the arrival render) lets every existing proof run on any ship. A 600-block fixture proves the size limit, held by a new `TOO_BIG` rule. The judgment lives in prose: the `designing-a-ship` skill and the agent file.

**Tech Stack:** Godot 4.5.1 GDScript, GUT 9.5, Claude Code subagent and skill files.

**Spec:** `docs/superpowers/specs/2026-10-09-ship-designer-design.md` (approved 2026-10-09; §9 holds the planning amendments).

## Global Constraints

- **Existing blocks only:** no new `.tres` in `data/blocks/`, no new meshes or props.
- **Up to 400 blocks:** `ShipRules.MOST_BLOCKS := 400` (600 at planning; lowered by the owner at Task 7, spec §9); a ship over it breaks `TOO_BIG`. Where a later task's text says 600, read the limit.
- **The JSON is canonical:** every ship file is written by `ShipLibrary.write`; a plan is scratch.
- **Every ship is usable** (CLAUDE.md): boarded, flown and saved; ships only through `Fleet`.
- **Saving is off whenever `starter_ship` is not the starter**, so no probe touches the owner's game.
- **The spawn freeze is accepted:** pin a 600-block spawn under 3000 ms; do not optimise builds here.
- **`#` starts a comment** in a plan except on the `ship`, `name` and `desc` lines.
- **Tests:** run one file with `who-knows/run_tests.ps1 '-gselect=<file>.gd'` from the `who-knows` folder; GUT exits 0 on a parse error, so read the summary (`All tests passed`, and a test count). After adding a `class_name`, run `godot --headless --path who-knows --import` or the class is not found. Run only the files a task names; the full suite (about 17 minutes now) is the owner's call at the end.
- **Godot:** `D:\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe` (`$env:GODOT_BIN` overrides it, as in `run_tests.ps1`). Below it is written `godot`.
- **The worktree guard:** this session cannot run `git -C`, bash heredocs or commands naming another checkout. Use the Write/Edit tools for files, plain `git` from the worktree root `D:\git\whoknows-ship-designer`.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **No visual change** to the game in this project; the style guide is unaffected.

## Review Focus

1. **A plan saved with Windows line endings or drawn with tabs** (the agent writes on Windows): it reads exactly as the same plan with `\n` and spaces. Task 2's `test_crlf_and_tabs_read_the_same`.
2. **A name or description with `#` or letters outside ASCII** ("Élan #2"): it round-trips through plan and JSON unchanged. Task 3's `test_a_name_with_a_hash_and_an_accent_round_trips`.
3. **A ship of 601 blocks:** refused by the rules (`TOO_BIG`), so it can never reach the library, whoever wrote it. Task 5's `test_one_more_block_is_too_big`.
4. **`--ship` naming no ship** (a typo, a deleted file): the scene starts in the starter with an error in the output, and the probe exits 1 before rendering anything. Task 6's `test_an_unknown_ship_starts_you_in_the_starter` and Task 7's run.
5. **A deck with an empty row inside it, or a row with too few cells:** the empty row (all dots) is accepted; a short row is refused naming its line and the end of it, never padded silently. Task 2's `test_an_empty_row_is_fine` and `test_too_few_cells_is_refused`.

---

## File map

| File | Task | What |
|---|---|---|
| `who-knows/src/ship/ship_plan.gd` (new) | 1–3 | `ShipPlan`: tokens, `parse`, `to_text` |
| `who-knows/test/unit/test_ship_plan.gd` (new) | 1–3 | its tests |
| `who-knows/src/ship/ship_library.gd` | 4 | `resolve(what, library)` |
| `who-knows/test/unit/test_ship_library.gd` | 4 | resolve's tests |
| `.claude/skills/building-a-ship/ship_plan.gd` (new) | 4 | the CLI |
| `who-knows/src/ship/ship_rules.gd` | 5 | `MOST_BLOCKS`, `TOO_BIG` |
| `who-knows/test/unit/helpers/ship_use.gd` (new) | 5 | the usable check, shared |
| `who-knows/test/unit/test_ship_catalog.gd` | 5 | uses the helper |
| `who-knows/test/fixtures/ships/big.plan`, `big.json` (new) | 5 | the 600-block fixture |
| `who-knows/test/unit/test_big_ship.gd` (new) | 5 | its tests |
| `who-knows/scenes/flight_test.gd` | 6 | `starter_ship` |
| `who-knows/test/unit/test_starter_ship.gd` (new) | 6 | its tests |
| `who-knows/test/probes/probe_args.gd` (new) | 7 | `ProbeArgs` |
| `who-knows/test/unit/test_probe_args.gd` (new) | 7 | its tests |
| `.claude/skills/building-a-ship/ship_probe.gd` | 7 | `--ship`; the starter as the second ship |
| `who-knows/test/probes/arrival_render.gd` | 7 | `--ship` |
| `.claude/skills/designing-a-ship/SKILL.md` (new) | 8 | the design skill |
| `.claude/agents/ship-designer.md` (new) | 9 | the agent |
| `.claude/skills/building-a-ship/SKILL.md`, `reference.md`, `CLAUDE.md`, the spec | 10 | docs |

---

### Task 1: ShipPlan's tokens

**Files:**
- Create: `who-knows/src/ship/ship_plan.gd`
- Test: `who-knows/test/unit/test_ship_plan.gd`

**Interfaces:**
- Consumes: `BlockCatalog.load_from_dir(path) -> BlockCatalog`, `BlockCatalog.ids() -> Array`, `BlockOrientation.COUNT` (24).
- Produces: `ShipPlan.BASE: Dictionary` (StringName block → String token), `ShipPlan.ARROWS: Dictionary` (int → String), `ShipPlan.EMPTY := "."`, `static func default_token(block: StringName, orientation: int) -> String` (`""` for a block with no token), `static func default_pair(token: String) -> Array` (`[StringName, int]` or `[]`), `static func hint(token: String) -> String` (the default token a near miss means, or `""`).

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_ship_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run them to watch them fail**

Run: `./run_tests.ps1 '-gselect=test_ship_plan.gd'` (from `who-knows`)
Expected: a parse error, `Identifier "ShipPlan" not declared` (GUT still exits 0: read the log).

- [ ] **Step 3: Write the tokens**

Create `who-knows/src/ship/ship_plan.gd`:

```gdscript
class_name ShipPlan
extends RefCounted

## A ship drawn as a deck plan (docs/superpowers/specs/
## 2026-10-09-ship-designer-design.md §4): one map per storey seen from above,
## bow up, port on the left, a token per 2 m cell. The ship-designer agent
## draws in it; ShipLibrary's JSON stays the one canonical file, and parse()
## and to_text() convert between them exactly, so the two never drift.
##
## Every block and orientation has exactly one default token: the block's base
## token, followed by the orientation unless it is 0 (W3, Fh2); the rcs pushes
## are arrows instead (R<, R>, R^, Rv, Rb).

## Each block's base token: that block at orientation 0.
const BASE := {
	&"hull": "H", &"deck": "D", &"core": "K", &"pilot_seat": "S", &"canopy": "C",
	&"airlock": "A", &"bulkhead": "B", &"door": "O", &"thruster": "T", &"rcs": "R",
	&"hull_wedge": "W", &"bunk_room": "Bk", &"galley": "Gy", &"bathroom": "Ba",
	&"weapon_room": "Wr", &"closet": "Cl", &"computer": "Cp", &"quantum_core": "Qk",
	&"quantum_machine": "Qm", &"quantum_cell": "Qc", &"grav_plating": "G", &"armour": "Ar",
	&"ladder": "L", &"fairing_slope": "Fs", &"fairing_half": "Fh",
	&"fairing_corner_in": "Fi", &"fairing_corner_out": "Fo",
	&"fairing_slope_long_high": "Fl", &"fairing_slope_long_low": "Fk",
}
## The rcs pushes drawn as arrows, standing in for R4, R8, R12, R16 and R20:
## aft (a retro), to port, to starboard, up and down.
const ARROWS := {4: "Rb", 8: "R<", 12: "R>", 16: "R^", 20: "Rv"}
## An empty cell.
const EMPTY := "."

## The default token for `block` at `orientation`, or "" for a block with no
## base token.
static func default_token(block: StringName, orientation: int) -> String:
	if block == &"rcs" and ARROWS.has(orientation):
		return ARROWS[orientation]
	if not BASE.has(block):
		return ""
	return BASE[block] + ("" if orientation == 0 else str(orientation))

## The [block, orientation] default token `token` stands for, or [] when it
## stands for none: never two tokens for one pair, so R8 (write R<) and W0
## (write W) are not tokens.
static func default_pair(token: String) -> Array:
	var near := _near(token)
	if near.is_empty() or default_token(near[0], near[1]) != token:
		return []
	return near

## The default token a near miss like R8 or W0 means, or "".
static func hint(token: String) -> String:
	var near := _near(token)
	return "" if near.is_empty() else default_token(near[0], near[1])

## The pair `token` would be read as, letters then digits, whether or not it
## is written as the default token is; [] when it is no block's.
static func _near(token: String) -> Array:
	for o in ARROWS:
		if ARROWS[o] == token:
			return [&"rcs", o]
	var i := token.length()
	while i > 0 and token[i - 1].is_valid_int():
		i -= 1
	var base := token.substr(0, i)
	var digits := token.substr(i)
	var o := 0 if digits == "" else digits.to_int()
	if o >= BlockOrientation.COUNT:
		return []
	for block in BASE:
		if BASE[block] == base:
			return [block, o]
	return []
```

- [ ] **Step 4: Import, run, watch them pass**

Run: `godot --headless --path . --import` then `./run_tests.ps1 '-gselect=test_ship_plan.gd'`
Expected: `6/6 passed`, `All tests passed`.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_plan.gd who-knows/src/ship/ship_plan.gd.uid who-knows/test/unit/test_ship_plan.gd
git commit -m "feat: ShipPlan's tokens -- one default token for every block and orientation"
```

---

### Task 2: ShipPlan.parse

**Files:**
- Modify: `who-knows/src/ship/ship_plan.gd`
- Test: `who-knows/test/unit/test_ship_plan.gd`

**Interfaces:**
- Consumes: Task 1's `default_pair`, `hint`, `EMPTY`; `ShipGrid.new()`, `set_block(coord, inst)`, `get_block(coord)`, `size()`; `BlockInstance.new()` with `block_id`, `orientation`; `BlockCatalog.has(id)`.
- Produces: `static func parse(plan: String, catalog: BlockCatalog, file := "plan") -> Dictionary`: `{id: StringName, name: String, description: String, grid: ShipGrid, notes: Array[String]}`, or `{error: String}` shaped `"<file>:<line>:<column>: <what>"` (1-based).

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_ship_plan.gd`:

```gdscript
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
```

- [ ] **Step 2: Run them to watch them fail**

Run: `./run_tests.ps1 '-gselect=test_ship_plan.gd'`
Expected: a parse error, `Static function "parse()" not found in base "ShipPlan"` (read the log).

- [ ] **Step 3: Write parse**

Append to `who-knows/src/ship/ship_plan.gd`:

```gdscript
## The ship `plan` draws: {id, name, description, grid, notes}, or {error}
## naming `file`, the line and the column (spec §4.3). `catalog` says which
## blocks exist. A note says where the plan's legend overrides a default token.
## Whether the ship flies is ShipRules', not this.
static func parse(plan: String, catalog: BlockCatalog, file := "plan") -> Dictionary:
	var deck_line := RegEx.create_from_string(
		"^\\s*deck\\s+y\\s*=\\s*(-?\\d+)\\s+x\\s*:\\s*(-?\\d+)\\s*\\.\\.\\s*(-?\\d+)\\s*$")
	var id_ok := RegEx.create_from_string("^[a-z0-9_]+$")
	var header := {}
	var legend := {}     # token -> [block, orientation]
	var notes: Array[String] = []
	var grid := ShipGrid.new()
	var section := ""    # "", "legend" or "deck"
	var deck := {}       # y, x0, x1, last_z
	var drawn := {}      # y -> the line its deck was drawn at
	var lines := plan.replace("\r", "").split("\n")
	for i in lines.size():
		var n := i + 1
		var raw: String = lines[i]
		var head := raw.strip_edges()
		var word := head.replace("\t", " ").get_slice(" ", 0)
		if word in ["ship", "name", "desc"]:
			if section != "":
				return _error(file, n, 1, "the header (ship, name, desc) comes before the legend and the decks")
			if header.has(word):
				return _error(file, n, 1, "a second %s line" % word)
			header[word] = head.substr(word.length()).strip_edges()
			continue
		var line := _uncommented(raw)
		var toks := _tokens(line)
		if toks.is_empty():
			continue
		var first: String = toks[0][0]
		if first == "legend":
			if toks.size() > 1 or section != "":
				return _error(file, n, toks[0][1], "legend comes once, on a line of its own, before the first deck")
			section = "legend"
		elif first == "deck":
			var m := deck_line.search(line)
			if m == null:
				return _error(file, n, toks[0][1], "a deck line is: deck y=<n>  x: <from> .. <to>")
			var y := m.get_string(1).to_int()
			var x0 := m.get_string(2).to_int()
			var x1 := m.get_string(3).to_int()
			if drawn.has(y):
				return _error(file, n, toks[0][1], "y=%d is drawn twice: first at line %d" % [y, drawn[y]])
			if x1 < x0:
				return _error(file, n, toks[0][1], "x runs port to starboard: %d .. %d is backwards" % [x0, x1])
			drawn[y] = n
			deck = {"y": y, "x0": x0, "x1": x1, "last_z": null}
			section = "deck"
		elif first == "z":
			if section != "deck":
				return _error(file, n, toks[0][1], "a row before any deck line")
			var refused := _row(toks, raw, n, file, deck, legend, catalog, grid)
			if refused != "":
				return {"error": refused}
		elif section == "legend":
			var refused := _legend_line(toks, n, file, legend, notes, catalog)
			if refused != "":
				return {"error": refused}
		else:
			return _error(file, n, toks[0][1], "expected ship, name, desc, legend, deck or a z row, found %s" % first)
	for key in ["ship", "name", "desc"]:
		if not header.has(key):
			return _error(file, 1, 1, "no %s line: a plan starts ship <id>, name <name>, desc <description>" % key)
	if id_ok.search(header["ship"]) == null:
		return _error(file, 1, 1, "an id is lower case letters, digits and _: \"%s\" is not" % header["ship"])
	return {"id": StringName(header["ship"]), "name": header["name"], "description": header["desc"],
		"grid": grid, "notes": notes}

## One row, `z <n>` and a token per cell, into `grid`; "" or why not.
static func _row(toks: Array, raw: String, n: int, file: String, deck: Dictionary, legend: Dictionary,
		catalog: BlockCatalog, grid: ShipGrid) -> String:
	if toks.size() < 2 or not (toks[1][0] as String).is_valid_int():
		return _error(file, n, toks[0][1], "a row is: z <n>, then one token per cell")["error"]
	var z := (toks[1][0] as String).to_int()
	if deck["last_z"] != null:
		var last: int = deck["last_z"]
		if z <= last:
			return _error(file, n, toks[1][1], "z %d comes after z %d: rows run bow to stern, each z once" % [z, last])["error"]
		if z != last + 1:
			return _error(file, n, toks[1][1], "z %d skips z %d: draw an empty row as dots" % [z, last + 1])["error"]
	deck["last_z"] = z
	var cells := toks.slice(2)
	var width: int = deck["x1"] - deck["x0"] + 1
	if cells.size() != width:
		var col: int = cells[width][1] if cells.size() > width else _uncommented(raw).strip_edges(false, true).length() + 1
		return _error(file, n, col, "%d cells for x %d .. %d, which is %d wide"
			% [cells.size(), deck["x0"], deck["x1"], width])["error"]
	for k in width:
		var tok: String = cells[k][0]
		if tok == EMPTY:
			continue
		var pair: Array = legend[tok] if legend.has(tok) else default_pair(tok)
		if pair.is_empty():
			var near := hint(tok)
			return _error(file, n, cells[k][1], "unknown token %s%s" % [tok, "" if near == "" else " (write %s)" % near])["error"]
		if not catalog.has(pair[0]):
			return _error(file, n, cells[k][1], "%s is %s, which is not in data/blocks" % [tok, pair[0]])["error"]
		var inst := BlockInstance.new()
		inst.block_id = pair[0]
		inst.orientation = pair[1]
		grid.set_block(Vector3i(deck["x0"] + k, deck["y"], z), inst)
	return ""

## One legend line, `<token> <block> [orientation]`, into `legend`; "" or why not.
static func _legend_line(toks: Array, n: int, file: String, legend: Dictionary, notes: Array[String],
		catalog: BlockCatalog) -> String:
	if toks.size() < 2 or toks.size() > 3:
		return _error(file, n, toks[0][1], "a legend line is: <token> <block> [orientation]")["error"]
	var tok: String = toks[0][0]
	if tok in [EMPTY, "z", "deck", "legend"]:
		return _error(file, n, toks[0][1], "%s cannot be a token" % tok)["error"]
	if legend.has(tok):
		return _error(file, n, toks[0][1], "%s is in the legend twice" % tok)["error"]
	var block := StringName(toks[1][0])
	if not catalog.has(block):
		return _error(file, n, toks[1][1], "no block called %s in data/blocks" % block)["error"]
	var o := 0
	if toks.size() == 3:
		var s: String = toks[2][0]
		if not s.is_valid_int() or s.to_int() < 0 or s.to_int() >= BlockOrientation.COUNT:
			return _error(file, n, toks[2][1], "orientation %s is not 0-%d" % [s, BlockOrientation.COUNT - 1])["error"]
		o = s.to_int()
	var standing := default_pair(tok)
	if not standing.is_empty() and standing != [block, o]:
		notes.append("%s:%d: %s is %s %d here, not %s %d" % [file, n, tok, block, o, standing[0], standing[1]])
	legend[tok] = [block, o]
	return ""

static func _error(file: String, line: int, column: int, what: String) -> Dictionary:
	return {"error": "%s:%d:%d: %s" % [file, line, column, what]}

## `line` up to a #.
static func _uncommented(line: String) -> String:
	var i := line.find("#")
	return line if i < 0 else line.substr(0, i)

## The words of `line`, split on spaces and tabs: [text, 1-based column].
static func _tokens(line: String) -> Array:
	var out := []
	var start := -1
	for i in line.length() + 1:
		var gap := i == line.length() or line[i] == " " or line[i] == "\t"
		if gap and start >= 0:
			out.append([line.substr(start, i - start), start + 1])
			start = -1
		elif not gap and start < 0:
			start = i
	return out
```

- [ ] **Step 4: Run, watch them pass**

Run: `./run_tests.ps1 '-gselect=test_ship_plan.gd'`
Expected: `31/31 passed`. A column that is off by one in an expected string is a test typo only if you can point at the character: count it in the test's own text (`z 0  H  R8`: R is column 9).

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_plan.gd who-knows/test/unit/test_ship_plan.gd
git commit -m "feat: ShipPlan.parse -- a deck plan to a grid, refusing with line and column"
```

---

### Task 3: ShipPlan.to_text and the exact round trip

**Files:**
- Modify: `who-knows/src/ship/ship_plan.gd`
- Test: `who-knows/test/unit/test_ship_plan.gd`

**Interfaces:**
- Consumes: Task 2's `parse`; `ShipLibrary.load_from_dir()`, `name_of`, `description_of`, `grid(id)`, `static write(path, id, ship_name, description, grid) -> Error`; `ShipGrid.coords()`, `has_block`.
- Produces: `static func to_text(id: StringName, ship_name: String, description: String, grid: ShipGrid) -> String`: the header, a blank line before each storey, storeys from the top down, each cropped to its extent, every z a row, tokens padded to the storey's widest, `\n` line ends and a final `\n`.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_ship_plan.gd`:

```gdscript
const OUT_DIR := "user://test_ship_plan"

## The starter as to_text prints it: the design skill's worked example.
const STARTER_PLAN := """ship   starter
name   Starter shuttle
desc   Two decks: a bridge with a cockpit pod, five rooms, an airlock aft.

deck y=2    x: -1 .. 1
z -2  Fk  Fk  Fk
z -1  Fh  Fh  Fh
z 0   Fh  Fh  Fh
z 1   Fh  Fh  Fh
z 2   Fh  Fh  Fh
z 3   Fk4 Fk4 Fk4

deck y=1    x: -3 .. 3
z -4  .  Rv R> W  R< Rv .
z -3  .  R^ W  H  W  R^ .
z -2  .  Rb H  H  H  Rb .
z -1  .  H  H  K  H  H  .
z 0   .  H  Qc Qc Qc H  .
z 1   Fs H  G  H  G  H  Fs
z 2   .  H  H  H  H  H  .
z 3   .  W4 T  T  T  W4 .

deck y=0    x: -3 .. 3
z -4  .   .   C   C   C   .   .
z -3  .   W3  Cp4 S   D   W1  .
z -2  .   H   D   Qk4 D   H   .
z -1  .   H   D   D   Qm  H   .
z 0   .   H   Bk  D   Gy  H   .
z 1   H   H   Bk  D   Wr  H   H
z 2   H   H   Ba  D   Cl  H   H
z 3   T   H   B   A   B   H   T

deck y=-1    x: 0 .. 0
z -3  Fh2
z -2  Fh2
z -1  Fh2
z 0   Fh2
z 1   Fh2
z 2   Fh2
"""

func _lf(s: String) -> String:
	return s.replace("\r\n", "\n")

func _starter_text() -> String:
	var lib := ShipLibrary.load_from_dir()
	return ShipPlan.to_text(&"starter", lib.name_of(&"starter"), lib.description_of(&"starter"), lib.grid(&"starter"))

func test_the_starter_prints_as_the_skill_shows_it():
	assert_eq(_starter_text(), STARTER_PLAN)

func test_the_starter_round_trips_byte_for_byte():
	var back := ShipPlan.parse(_starter_text(), _cat)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out := OUT_DIR + "/starter.json"
	assert_eq(ShipLibrary.write(out, back["id"], back["name"], back["description"], back["grid"]), OK)
	assert_eq(_lf(FileAccess.get_file_as_string(out)), _lf(FileAccess.get_file_as_string("res://data/ships/starter.json")))

func test_storeys_of_different_extents_print_back():
	var text := HEAD + "\ndeck y=1    x: 1 .. 1\nz 0  K\n\ndeck y=0    x: 0 .. 2\nz -1  . C .\nz 0   H D H\n"
	var found := ShipPlan.parse(text, _cat)
	var printed := ShipPlan.to_text(found["id"], found["name"], found["description"], found["grid"])
	assert_eq(printed, text)

func test_a_name_with_a_hash_and_an_accent_round_trips():
	var grid: ShipGrid = ShipPlan.parse(HEAD + "deck y=0  x: 0 .. 0\nz 0  H\n", _cat)["grid"]
	var text := ShipPlan.to_text(&"elan", "Élan #2", "Fast — and #1", grid)
	var back := ShipPlan.parse(text, _cat)
	assert_eq(back["name"], "Élan #2")
	assert_eq(back["description"], "Fast — and #1")
```

- [ ] **Step 2: Run them to watch them fail**

Run: `./run_tests.ps1 '-gselect=test_ship_plan.gd'`
Expected: a parse error, `Static function "to_text()" not found in base "ShipPlan"`.

- [ ] **Step 3: Write to_text**

Append to `who-knows/src/ship/ship_plan.gd`:

```gdscript
## `grid` drawn as a plan in default tokens under its header: every storey from
## the top down, cropped to the ship's extent on it, every z in that a row,
## the tokens padded into columns. parse() reads it back to the same grid.
static func to_text(id: StringName, ship_name: String, description: String, grid: ShipGrid) -> String:
	var lines := PackedStringArray(["ship   %s" % id, "name   %s" % ship_name, "desc   %s" % description])
	var storeys := {}
	for c: Vector3i in grid.coords():
		storeys[c.y] = true
	var ys: Array = storeys.keys()
	ys.sort()
	ys.reverse()
	for y: int in ys:
		var first := true
		var x0 := 0
		var x1 := 0
		var z0 := 0
		var z1 := 0
		var width := 1
		for c: Vector3i in grid.coords():
			if c.y != y:
				continue
			if first:
				x0 = c.x
				x1 = c.x
				z0 = c.z
				z1 = c.z
				first = false
			x0 = mini(x0, c.x)
			x1 = maxi(x1, c.x)
			z0 = mini(z0, c.z)
			z1 = maxi(z1, c.z)
			width = maxi(width, _token_at(grid, c).length())
		var label := 0
		for z in range(z0, z1 + 1):
			label = maxi(label, ("z %d" % z).length())
		lines.append("")
		lines.append("deck y=%d    x: %d .. %d" % [y, x0, x1])
		for z in range(z0, z1 + 1):
			var row := PackedStringArray()
			for x in range(x0, x1 + 1):
				row.append(_token_at(grid, Vector3i(x, y, z)).rpad(width))
			lines.append((("z %d" % z).rpad(label) + "  " + " ".join(row)).strip_edges(false, true))
	return "\n".join(lines) + "\n"

static func _token_at(grid: ShipGrid, c: Vector3i) -> String:
	if not grid.has_block(c):
		return EMPTY
	var b := grid.get_block(c)
	var token := default_token(b.block_id, b.orientation)
	if token == "":
		push_error("ShipPlan: %s has no token" % b.block_id)
		return "?"
	return token
```

- [ ] **Step 4: Run, watch them pass**

Run: `./run_tests.ps1 '-gselect=test_ship_plan.gd'`
Expected: `35/35 passed`. If `test_the_starter_prints_as_the_skill_shows_it` fails, diff the two strings: the expected text is the spec's format (blank line before each deck, `deck y=N    x: A .. B`, labels padded to the storey's widest `z n` then two spaces, tokens padded to the storey's widest token, one space between, trailing spaces stripped). Fix `to_text`, not the constant.

- [ ] **Step 5: Commit**

```bash
git add who-knows/src/ship/ship_plan.gd who-knows/test/unit/test_ship_plan.gd
git commit -m "feat: ShipPlan.to_text -- any ship as a deck plan, round-tripping byte for byte"
```

---

### Task 4: ShipLibrary.resolve and the ship_plan.gd tool

**Files:**
- Modify: `who-knows/src/ship/ship_library.gd`
- Test: `who-knows/test/unit/test_ship_library.gd`
- Create: `.claude/skills/building-a-ship/ship_plan.gd`

**Interfaces:**
- Consumes: Tasks 2–3's `parse`, `to_text`; `ShipLibrary.read`, `load_from_dir`, `write`.
- Produces: `static func resolve(what: String, library: ShipLibrary = null) -> Dictionary` on `ShipLibrary`: `{id, name, description, grid}` for a library id or a path ending `.json`, else `{error}`. The CLI `ship_plan.gd -- to-json <plan> <out.json>` and `-- to-plan <id or ship .json> <out.plan>`, printing `plan    ...` lines, exiting 0 or 1.

- [ ] **Step 1: Write the failing tests**

Append to `who-knows/test/unit/test_ship_library.gd`:

```gdscript
func test_resolve_finds_a_library_id():
	var found := ShipLibrary.resolve("starter")
	assert_eq(found.get("id"), &"starter")
	assert_eq(found.get("name"), "Starter shuttle")
	assert_eq((found["grid"] as ShipGrid).size(), 110)

func test_resolve_reads_a_ship_file():
	var found := ShipLibrary.resolve("res://test/fixtures/ships/alpha.json")
	assert_eq(found.get("id"), &"alpha")
	assert_false(found.has("error"))

func test_resolve_says_when_it_names_no_ship():
	assert_eq(ShipLibrary.resolve("nope").get("error"), "no library ship called \"nope\"")
	assert_string_contains(ShipLibrary.resolve("res://nowhere/nope.json").get("error", ""), "no such file")
```

- [ ] **Step 2: Run them to watch them fail**

Run: `./run_tests.ps1 '-gselect=test_ship_library.gd'`
Expected: a parse error, `Static function "resolve()" not found`.

- [ ] **Step 3: Write resolve**

Add to `who-knows/src/ship/ship_library.gd`, after `read()`:

```gdscript
## The ship `what` names (ship designer spec §7.2): a library id, or a res://
## or absolute path to a ship file, read as read() reads one; {error} when it
## names none. `library` is asked for ids, loaded from DIR when not given.
static func resolve(what: String, library: ShipLibrary = null) -> Dictionary:
	if what.ends_with(".json"):
		return read(what)
	if library == null:
		library = load_from_dir()
	var id := StringName(what)
	if not library.has(id):
		return {"error": "no library ship called \"%s\"" % what}
	return {"id": id, "name": library.name_of(id), "description": library.description_of(id),
		"grid": library.grid(id)}
```

- [ ] **Step 4: Run, watch them pass**

Run: `./run_tests.ps1 '-gselect=test_ship_library.gd'`
Expected: `11/11 passed`.

- [ ] **Step 5: Write the tool**

Create `.claude/skills/building-a-ship/ship_plan.gd`:

```gdscript
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
```

- [ ] **Step 6: Run the tool both ways on the starter**

With `$s` a scratch folder of your own (outside the repo) and `$tool = "D:\git\whoknows-ship-designer\.claude\skills\building-a-ship\ship_plan.gd"`, from `who-knows`:

Run: `godot --headless --path . --script $tool -- to-plan starter "$s\starter.plan"`
Expected: `plan    wrote ...\starter.plan`; the file's text is Task 3's `STARTER_PLAN`.

Run: `godot --headless --path . --script $tool -- to-json "$s\starter.plan" "$s\starter.json"` then `fc.exe /b "$s\starter.json" data\ships\starter.json`
Expected: `plan    wrote ...\starter.json: 110 blocks`; `FC: no differences encountered`.

Run: `godot --headless --path . --script $tool -- to-json "$s\starter.plan" "$s\other.json"`
Expected: `plan    write it to starter.json: a ship file is named for its id`, exit code 1.

Run: `godot --headless --path . --script $tool -- to-plan nope "$s\x.plan"`
Expected: `plan    no library ship called "nope"`, exit code 1.

- [ ] **Step 7: Commit**

```bash
git add who-knows/src/ship/ship_library.gd who-knows/test/unit/test_ship_library.gd .claude/skills/building-a-ship/ship_plan.gd
git commit -m "feat: ship_plan.gd -- draw a ship as a deck plan, turn it into the library's JSON"
```

---

### Task 5: TOO_BIG and the 600-block fixture

**Files:**
- Modify: `who-knows/src/ship/ship_rules.gd:25-40`
- Create: `who-knows/test/unit/helpers/ship_use.gd`
- Modify: `who-knows/test/unit/test_ship_catalog.gd`
- Create: `who-knows/test/fixtures/ships/big.plan`, `who-knows/test/fixtures/ships/big.json`
- Test: `who-knows/test/unit/test_big_ship.gd`

**Interfaces:**
- Consumes: Task 4's tool; `ShipRules.check`; `Fleet.spawn(grid, place, stock, ship_name, launch)`; `Ship.to_dict(universe)`; the flight scene's `fleet`, `board_nearest()`, `aboard`, `save_now()`.
- Produces: `ShipRules.MOST_BLOCKS := 600` and rule `TOO_BIG`; the helper `static func use(t: GutTest, grid: ShipGrid, ship_name: String, save_path: String, label: String)` (a coroutine: `await` it); the fixture `res://test/fixtures/ships/big.json` (id `big`, name `Big`, 600 blocks), used by Task 6 and Task 7.

- [ ] **Step 1: Write the fixture plan**

Create `who-knows/test/fixtures/ships/big.plan` with exactly this text. It is the starter stretched by 35 rows (bunk, galley, bathroom and weapon rooms down a corridor, quantum cells and some grav plating above), with a second quantum core at (−1, 0, 17): one core's 36 MW cannot feed 600 blocks (spec §9).

```
ship   big
name   Big
desc   A stretched starter.

deck y=2    x: -1 .. 1
z -2  Fk  Fk  Fk
z -1  Fh  Fh  Fh
z 0   Fh  Fh  Fh
z 1   Fh  Fh  Fh
z 2   Fh  Fh  Fh
z 3   Fh  Fh  Fh
z 4   Fh  Fh  Fh
z 5   Fh  Fh  Fh
z 6   Fh  Fh  Fh
z 7   Fh  Fh  Fh
z 8   Fh  Fh  Fh
z 9   Fh  Fh  Fh
z 10  Fh  Fh  Fh
z 11  Fh  Fh  Fh
z 12  Fh  Fh  Fh
z 13  Fh  Fh  Fh
z 14  Fh  Fh  Fh
z 15  Fh  Fh  Fh
z 16  Fh  Fh  Fh
z 17  Fh  Fh  Fh
z 18  Fh  Fh  Fh
z 19  Fh  Fh  Fh
z 20  Fh  Fh  Fh
z 21  Fh  Fh  Fh
z 22  Fh  Fh  Fh
z 23  Fh  Fh  Fh
z 24  Fh  Fh  Fh
z 25  Fh  Fh  Fh
z 26  Fh  Fh  Fh
z 27  Fh  Fh  Fh
z 28  Fh  Fh  Fh
z 29  Fh  Fh  Fh
z 30  Fh  Fh  Fh
z 31  Fh  Fh  Fh
z 32  Fh  Fh  Fh
z 33  Fh  Fh  Fh
z 34  Fh  Fh  Fh
z 35  Fh  Fh  Fh
z 36  Fh  Fh  Fh
z 37  Fh  Fh  Fh
z 38  Fk4 Fk4 Fk4

deck y=1    x: -3 .. 3
z -4  .  Rv R> W  R< Rv .
z -3  .  R^ W  H  W  R^ .
z -2  .  Rb H  H  H  Rb .
z -1  .  H  H  K  H  H  .
z 0   .  H  Qc Qc Qc H  .
z 1   .  H  H  H  H  H  .
z 2   .  H  H  H  H  H  .
z 3   .  H  H  H  H  H  .
z 4   .  H  H  H  H  H  .
z 5   .  H  G  H  G  H  .
z 6   .  H  Qc Qc Qc H  .
z 7   .  H  H  H  H  H  .
z 8   .  H  H  H  H  H  .
z 9   .  H  H  H  H  H  .
z 10  .  H  H  H  H  H  .
z 11  .  H  G  H  G  H  .
z 12  .  H  Qc Qc Qc H  .
z 13  .  H  H  H  H  H  .
z 14  .  H  H  H  H  H  .
z 15  .  H  H  H  H  H  .
z 16  .  H  H  H  H  H  .
z 17  .  H  G  H  G  H  .
z 18  .  H  Qc Qc Qc H  .
z 19  .  H  H  H  H  H  .
z 20  .  H  H  H  H  H  .
z 21  .  H  H  H  H  H  .
z 22  .  H  H  H  H  H  .
z 23  .  H  G  H  G  H  .
z 24  .  H  Qc Qc Qc H  .
z 25  .  H  H  H  H  H  .
z 26  .  H  H  H  H  H  .
z 27  .  H  H  H  H  H  .
z 28  .  H  H  H  H  H  .
z 29  .  H  G  H  G  H  .
z 30  .  H  Qc Qc Qc H  .
z 31  .  H  H  H  H  H  .
z 32  .  H  H  H  H  H  .
z 33  .  H  H  H  H  H  .
z 34  .  H  H  H  H  H  .
z 35  .  H  Qc Qc Qc H  .
z 36  Fs H  G  H  G  H  Fs
z 37  .  H  H  H  H  H  .
z 38  .  W4 T  T  T  W4 .

deck y=0    x: -3 .. 3
z -4  .   .   C   C   C   .   .
z -3  .   W3  Cp4 S   D   W1  .
z -2  .   H   D   Qk4 D   H   .
z -1  .   H   D   D   Qm  H   .
z 0   .   H   Bk  D   Gy  H   .
z 1   .   H   Ba  D   Wr  H   .
z 2   .   H   D   D   D   H   .
z 3   .   H   Bk  D   Gy  H   .
z 4   .   H   Ba  D   Wr  H   .
z 5   .   H   D   D   D   H   .
z 6   .   H   Bk  D   Gy  H   .
z 7   .   H   Ba  D   Wr  H   .
z 8   .   H   D   D   D   H   .
z 9   .   H   Bk  D   Gy  H   .
z 10  .   H   Ba  D   Wr  H   .
z 11  .   H   D   D   D   H   .
z 12  .   H   Bk  D   Gy  H   .
z 13  .   H   Ba  D   Wr  H   .
z 14  .   H   D   D   D   H   .
z 15  .   H   Bk  D   Gy  H   .
z 16  .   H   Ba  D   Wr  H   .
z 17  .   H   Qk4 D   D   H   .
z 18  .   H   Bk  D   Gy  H   .
z 19  .   H   Ba  D   Wr  H   .
z 20  .   H   D   D   D   H   .
z 21  .   H   Bk  D   Gy  H   .
z 22  .   H   Ba  D   Wr  H   .
z 23  .   H   D   D   D   H   .
z 24  .   H   Bk  D   Gy  H   .
z 25  .   H   Ba  D   Wr  H   .
z 26  .   H   D   D   D   H   .
z 27  .   H   Bk  D   Gy  H   .
z 28  .   H   Ba  D   Wr  H   .
z 29  .   H   D   D   D   H   .
z 30  .   H   Bk  D   Gy  H   .
z 31  .   H   Ba  D   Wr  H   .
z 32  .   H   D   D   D   H   .
z 33  .   H   Bk  D   Gy  H   .
z 34  .   H   Ba  D   Wr  H   .
z 35  .   H   Bk  D   Gy  H   .
z 36  H   H   Bk  D   Wr  H   H
z 37  H   H   Ba  D   Cl  H   H
z 38  T   H   B   A   B   H   T

deck y=-1    x: 0 .. 0
z -3  Fh2
z -2  Fh2
z -1  Fh2
z 0   Fh2
z 1   Fh2
z 2   Fh2
z 3   Fh2
z 4   Fh2
z 5   Fh2
z 6   Fh2
z 7   Fh2
z 8   Fh2
z 9   Fh2
z 10  Fh2
z 11  Fh2
z 12  Fh2
z 13  Fh2
z 14  Fh2
z 15  Fh2
z 16  Fh2
z 17  Fh2
z 18  Fh2
z 19  Fh2
z 20  Fh2
z 21  Fh2
z 22  Fh2
z 23  Fh2
z 24  Fh2
z 25  Fh2
z 26  Fh2
z 27  Fh2
z 28  Fh2
z 29  Fh2
z 30  Fh2
z 31  Fh2
z 32  Fh2
z 33  Fh2
z 34  Fh2
z 35  Fh2
z 36  Fh2
z 37  Fh2
```

- [ ] **Step 2: Turn it into the fixture and check it**

From `who-knows`, with `$tool = "D:\git\whoknows-ship-designer\.claude\skills\building-a-ship\ship_plan.gd"`, run: `godot --headless --path . --script $tool -- to-json "$PWD\test\fixtures\ships\big.plan" "$PWD\test\fixtures\ships\big.json"` then `godot --headless --path . --script ..\.claude\skills\building-a-ship\ship_check.gd -- res://test/fixtures/ships/big.json`
Expected: `plan    wrote ...big.json: 600 blocks`; `ship    big: Big, 600 blocks`, `rules   0 broken`, and a `SIZE` note of `600 blocks, 515.3 t; 72.0 MW made, 56.7 drawn`.

- [ ] **Step 3: Extract the usable check into a helper**

Create `who-knows/test/unit/helpers/ship_use.gd` (not named `test_`, so GUT never runs it as a test):

```gdscript
extends RefCounted

## The owner's rule (2026-10-02) played in the real flight scene: `grid`
## spawned 300 m off the starter, F8 aboard, a burn moves it and not the
## starter, you stand and walk, and a save to `save_path` brings it back as it
## was, named `ship_name`, with you aboard. Shared by test_ship_catalog.gd
## (every library ship) and test_big_ship.gd (the 600-block fixture). `t` is
## the calling test; `label` starts each of its messages.

const SCENE := "res://scenes/flight_test.tscn"

static func use(t: GutTest, grid: ShipGrid, ship_name: String, save_path: String, label: String) -> void:
	var root := _scene(t, save_path)
	await t.wait_process_frames(2)
	var starter: Ship = root.get_node("Ship")
	var place := Transform3D(starter.exterior.global_basis, starter.exterior.global_position + Vector3(300, 0, 0))
	var ship: Ship = root.fleet.spawn(grid, place, true, "", ShipBlueprint.from_grid(grid, ship_name))
	await t.wait_physics_frames(2)
	t.assert_true(root.board_nearest(), "%s: F8 boards it" % label)
	t.assert_same(root.aboard, ship, "%s: aboard it" % label)
	var starter_at := starter.exterior.global_position
	var ship_at := ship.exterior.global_position
	Input.action_press(&"move_forward")
	await t.wait_physics_frames(60)
	Input.action_release(&"move_forward")
	t.assert_gt(ship.exterior.global_position.distance_to(ship_at), 1.0, "%s: a burn moves it" % label)
	t.assert_almost_eq(starter.exterior.global_position, starter_at, Vector3.ONE * 0.5, "%s: and not the starter" % label)
	# Let the controls see the key go before standing: a burn held as you stand
	# latches on, by design.
	await t.wait_physics_frames(2)
	var director: CameraDirector = root.get_node("CameraDirector")
	director.stand()
	await t.wait_for_signal(director.transition_finished, 3)
	var avatar: Avatar = root.get_tree().get_first_node_in_group(Avatar.GROUP)
	var from := avatar.global_position
	Input.action_press(&"move_back")
	await t.wait_physics_frames(60)
	Input.action_release(&"move_back")
	t.assert_gt(from.distance_to(avatar.global_position), 1.0, "%s: you stand and walk" % label)
	t.assert_same(avatar.get_parent(), ship.interior, "%s: aboard it" % label)
	t.assert_true(root.save_now(), "%s: it saves" % label)
	var saved_name := ship.name
	_drop(t, root)
	var again := _scene(t, save_path)
	await t.wait_process_frames(2)
	var back: Ship = again.fleet.named(saved_name)
	t.assert_not_null(back, "%s: the save brings it back" % label)
	if back != null:
		t.assert_eq(ShipLibrary.rows_text(back.grid), ShipLibrary.rows_text(grid), "%s: as it was built" % label)
		t.assert_eq(back.launch_blueprint.ship_name, ship_name, "%s: with its name" % label)
		t.assert_same(again.aboard, back, "%s: and you aboard it" % label)
	_drop(t, again)

static func _scene(t: GutTest, save_path: String) -> Node:
	var root: Node = load(SCENE).instantiate()
	root.save_enabled = true
	root.save_path = save_path
	t.add_child(root)
	return root

static func _drop(t: GutTest, root: Node) -> void:
	t.remove_child(root)
	root.free()
```

In `who-knows/test/unit/test_ship_catalog.gd`: add `const ShipUse := preload("res://test/unit/helpers/ship_use.gd")` under the other consts; replace the body of `test_every_ship_is_usable` with

```gdscript
func test_every_ship_is_usable():
	for id in _library.ids():
		await ShipUse.use(self, _library.grid(id), _library.name_of(id), PATH, String(id))
```

and delete `_use`, `_scene` and `_drop` (nothing else in the file calls them; check with a search before deleting). Its doc comment above `_use` moves into the helper, as written.

- [ ] **Step 4: Run the catalog test: still green after the move**

Run: `./run_tests.ps1 '-gselect=test_ship_catalog.gd'`
Expected: `4/4 passed`.

- [ ] **Step 5: Write the big ship's failing tests**

Create `who-knows/test/unit/test_big_ship.gd`:

```gdscript
extends GutTest

## The 600-block fixture (docs/superpowers/specs/2026-10-09-ship-designer-design.md
## §7.4, §9): the biggest a ship may be passes the rules and is usable, and
## stays within what was measured on 2026-10-09 (the rules 0.6 s, a spawn
## 1.9 s, a save 63 KB), each pinned with room to spare. The spawn's freeze is
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

func test_it_is_600_blocks_and_its_plan():
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
```

- [ ] **Step 6: Run them to watch the size rule fail**

Run: `./run_tests.ps1 '-gselect=test_big_ship.gd'`
Expected: a parse error, `Cannot find member "MOST_BLOCKS" in base "ShipRules"`. Then add only `const MOST_BLOCKS := 600` (Step 7's constant, without the rule) and run again: `test_one_more_block_is_too_big` FAILS (`TOO_BIG` not in the codes); the other five pass.

- [ ] **Step 7: Write the rule**

In `who-knows/src/ship/ship_rules.gd`, beside `POWER_HEADROOM`:

```gdscript
## The most blocks a ship may have (ship designer spec §2.6): the owner's first
## limit, "and see how that goes".
const MOST_BLOCKS := 600
```

and in `check()`, straight after the `UNKNOWN_BLOCK` early return:

```gdscript
	if grid.size() > MOST_BLOCKS:
		rules.append(item(&"TOO_BIG", "%d blocks: a ship may have %d" % [grid.size(), MOST_BLOCKS]))
```

- [ ] **Step 8: Run, watch them pass, and the rules test too**

Run: `./run_tests.ps1 '-gselect=test_big_ship.gd'` then `./run_tests.ps1 '-gselect=test_ship_rules.gd'`
Expected: `6/6 passed` (read the spawn's ms in the log if it fails: a spawn over 3000 ms is a finding, not a number to raise); `18/18 passed`.

- [ ] **Step 9: Commit**

```bash
git add who-knows/src/ship/ship_rules.gd who-knows/test/unit/helpers who-knows/test/unit/test_ship_catalog.gd who-knows/test/fixtures/ships/big.plan who-knows/test/fixtures/ships/big.json who-knows/test/unit/test_big_ship.gd
git commit -m "feat: TOO_BIG and a 600-block fixture -- usable, its rules, spawn and save pinned"
```

---

### Task 6: starter_ship

**Files:**
- Modify: `who-knows/scenes/flight_test.gd` (vars near `library`; `_ready` before `_read_save()` and at `_starter.set_grid`; `_starter_grid()`)
- Test: `who-knows/test/unit/test_starter_ship.gd`

**Interfaces:**
- Consumes: Task 4's `ShipLibrary.resolve`; Task 5's `res://test/fixtures/ships/big.json`.
- Produces: `var starter_ship := String(ShipLibrary.STARTER)` on the flight scene (a library id or a ship file path, set before it enters the tree); `func _starter_file() -> Dictionary` (`{id, name, description, grid}`, the starter's on an error); `_starter_grid()` unchanged in signature.

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_starter_ship.gd`:

```gdscript
extends GutTest

## Starting aboard another ship (docs/superpowers/specs/
## 2026-10-09-ship-designer-design.md §7.2): how the probe and the renders work
## on any ship. Never the player's: anything but the starter saves nothing.

const BIG := "res://test/fixtures/ships/big.json"
const SAVE := "user://test_starter_ship/game.json"

func after_each():
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)

func _scene(ship: String, saving := false) -> Node:
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.save_enabled = saving
	root.save_path = SAVE
	if ship != "":
		root.starter_ship = ship
	add_child_autofree(root)
	return root

func test_by_default_you_start_in_the_starter():
	var root := _scene("")
	await wait_process_frames(2)
	assert_eq(ShipLibrary.rows_text(root.aboard.grid), ShipLibrary.rows_text(ShipLibrary.load_from_dir().grid(&"starter")))

func test_you_can_start_aboard_another_ship():
	var root := _scene(BIG)
	await wait_process_frames(2)
	assert_eq(ShipLibrary.rows_text(root.aboard.grid), ShipLibrary.rows_text(ShipLibrary.read(BIG)["grid"]))
	assert_eq(root.aboard.launch_blueprint.ship_name, "Big")
	var avatar: Avatar = root.get_tree().get_first_node_in_group(Avatar.GROUP)
	assert_same(avatar.get_parent(), root.aboard.interior, "you are inside it")
	assert_almost_eq(avatar.position, root._deck_spot(root.aboard).origin, Vector3.ONE * 0.1, "on its deck")

func test_a_library_id_works_too():
	var root := _scene("starter")
	await wait_process_frames(2)
	assert_eq(root.aboard.grid.size(), 110)

func test_another_ship_turns_saving_off():
	var root := _scene(BIG, true)
	await wait_process_frames(2)
	assert_false(root.save_enabled, "a probe never writes the owner's game")

func test_the_starter_keeps_saving_on():
	var root := _scene("starter", true)
	await wait_process_frames(2)
	assert_true(root.save_enabled)

func test_an_unknown_ship_starts_you_in_the_starter():
	var root := _scene("nope")
	await wait_process_frames(2)
	assert_push_error("no library ship called \"nope\"")
	assert_eq(root.aboard.grid.size(), 110)
```

- [ ] **Step 2: Run them to watch them fail**

Run: `./run_tests.ps1 '-gselect=test_starter_ship.gd'`
Expected: `Invalid assignment of property or key 'starter_ship'` errors; the default and `the_starter_keeps_saving_on` tests may pass, the others FAIL.

- [ ] **Step 3: Write starter_ship**

In `who-knows/scenes/flight_test.gd`, under `var library: ShipLibrary`:

```gdscript
## Which ship you start aboard (ship designer spec §7.2): a library id, or a
## res:// or absolute path to a ship file. Anything but the starter is for a
## probe or a render, so it turns saving off: the owner's game is never
## touched. Set before the scene enters the tree.
var starter_ship := String(ShipLibrary.STARTER)
```

In `_ready()`, between `_load_library()` and `var saved := _read_save()`:

```gdscript
	if starter_ship != String(ShipLibrary.STARTER):
		save_enabled = false
```

and replace the line `_starter.set_grid(layout if resumed else _starter_grid(), not resumed)` with (one `_starter_file()` call, so an unknown ship pushes one error, not two):

```gdscript
	var chosen := {} if resumed else _starter_file()
	if not resumed and starter_ship != String(ShipLibrary.STARTER):
		_starter.launch_blueprint = ShipBlueprint.from_grid(chosen["grid"], chosen["name"])
	_starter.set_grid(layout if resumed else chosen["grid"], not resumed)
```

Replace `_starter_grid()` and its comment with:

```gdscript
## The ship starter_ship names, {id, name, description, grid}; the starter's,
## with an error in the output, when it names none. The starter's file is
## data/ships/starter.json, why each block is where it is data/ships/starter.md.
## Most tests call _starter_grid() on a flight_test.gd that never entered the
## tree, so it loads the library itself.
func _starter_file() -> Dictionary:
	if library == null:
		library = ShipLibrary.load_from_dir()
	var found := ShipLibrary.resolve(starter_ship, library)
	if found.has("error"):
		push_error("FlightTest: %s; starting in the starter" % found["error"])
		found = ShipLibrary.resolve(String(ShipLibrary.STARTER), library)
	return found

func _starter_grid() -> ShipGrid:
	return _starter_file()["grid"]
```

- [ ] **Step 4: Run, watch them pass, and the starter's own tests**

Run: `./run_tests.ps1 '-gselect=test_starter_ship.gd'` then `./run_tests.ps1 '-gselect=test_starter_shuttle.gd'` then `./run_tests.ps1 '-gselect=test_save_scene.gd'`
Expected: `6/6 passed`; `16/16 passed`; `17/17 passed`.

- [ ] **Step 5: Commit**

```bash
git add who-knows/scenes/flight_test.gd who-knows/test/unit/test_starter_ship.gd
git commit -m "feat: starter_ship -- start aboard any library ship or ship file, saving off"
```

---

### Task 7: --ship on the probe and the arrival render

**Files:**
- Create: `who-knows/test/probes/probe_args.gd`
- Test: `who-knows/test/unit/test_probe_args.gd`
- Modify: `.claude/skills/building-a-ship/ship_probe.gd:1-46` (header comment and `_initialize`), `:271` (the second ship)
- Modify: `who-knows/test/probes/arrival_render.gd:1-28` (header and `_initialize`), `:65`, `:155`

**Interfaces:**
- Consumes: Task 6's `starter_ship`; Task 4's `ShipLibrary.resolve`; the flight scene's `library`, `spawn_from_library(id: StringName) -> String`.
- Produces: `ProbeArgs.ship(args: PackedStringArray) -> String` (the value after `--ship`, or `""`), `ProbeArgs.positional(args: PackedStringArray) -> PackedStringArray` (the args without the `--ship` pair).

- [ ] **Step 1: Write the failing tests**

Create `who-knows/test/unit/test_probe_args.gd`:

```gdscript
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
```

- [ ] **Step 2: Run them to watch them fail**

Run: `./run_tests.ps1 '-gselect=test_probe_args.gd'`
Expected: a parse error, `Identifier "ProbeArgs" not declared`.

- [ ] **Step 3: Write ProbeArgs**

Create `who-knows/test/probes/probe_args.gd`:

```gdscript
class_name ProbeArgs
extends RefCounted

## The command line a probe or render script reads (ship designer spec §7.2):
## its own positional arguments, and `--ship <id or ship file>` anywhere among
## them, naming the ship to probe instead of the starter.

## The ship --ship names, or "" when there is none.
static func ship(args: PackedStringArray) -> String:
	var i := args.find("--ship")
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""

## `args` without --ship and its value.
static func positional(args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var skip := false
	for a in args:
		if skip:
			skip = false
		elif a == "--ship":
			skip = true
		else:
			out.append(a)
	return out
```

- [ ] **Step 4: Import, run, watch them pass**

Run: `godot --headless --path . --import` then `./run_tests.ps1 '-gselect=test_probe_args.gd'`
Expected: `4/4 passed`.

- [ ] **Step 5: --ship on the probe**

In `.claude/skills/building-a-ship/ship_probe.gd`, the run line in the header comment becomes:

```
#   godot --path who-knows --resolution 1280x720 \
#     --script <abs path>/ship_probe.gd -- <abs out dir> [scene path] [--ship <id or ship .json>]
#
# --ship probes that ship instead of the starter (ship designer spec §7.2): a
# library id, or a ship file, such as a draft not yet in the library.
```

`_initialize()` becomes:

```gdscript
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var given := ProbeArgs.positional(args)
	_out = given[0]
	# Vsync would cap the frame rate at the monitor's; measure the real one.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var path := given[1] if given.size() > 1 else "res://scenes/flight_test.tscn"
	var scene: Node = load(path).instantiate()
	if &"save_enabled" in scene:
		scene.save_enabled = false
	var ship := ProbeArgs.ship(args)
	if ship != "":
		var found := ShipLibrary.resolve(ship)
		if found.has("error"):
			print("ship    %s" % found["error"])
			quit(1)
			return
		scene.starter_ship = ship
		print("ship    probing %s: %s" % [found["id"], found["name"]])
	root.add_child(scene)
	_run.call_deferred(scene)
```

At the two-ship pass (`var second := fleet.spawn(scene.call("_starter_grid"), ...)`), the second ship is the real starter:

```gdscript
	var second := fleet.spawn(scene.library.grid(ShipLibrary.STARTER), Transform3D(first.exterior.global_basis, behind))
```

- [ ] **Step 6: --ship on the arrival render**

In `who-knows/test/probes/arrival_render.gd`, the header's run line gains ` [--ship <library id>]` and the sentence `--ship brings that library ship in instead of the starter (ship designer spec §7.1): a library id, since it spawns through the F6 path.` Add `var _ship := ShipLibrary.STARTER` under `var _out := ""`, and `_initialize()` begins:

```gdscript
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = ProbeArgs.positional(args)[0]
	var ship := ProbeArgs.ship(args)
	if ship != "":
		if not ShipLibrary.load_from_dir().has(StringName(ship)):
			print("arrival no library ship called \"%s\"" % ship)
			quit(1)
			return
		_ship = StringName(ship)
```

(the rest of `_initialize` unchanged). Both `scene.call("spawn_from_library", ShipLibrary.STARTER)` lines (65 and 155) become `scene.call("spawn_from_library", _ship)`.

- [ ] **Step 7: Probe the 600-block fixture, windowed**

From `who-knows`: `godot --path . --resolution 1280x720 --script ..\.claude\skills\building-a-ship\ship_probe.gd -- <abs out dir> --ship res://test/fixtures/ships/big.json`, logged to a file (it takes minutes).
Expected: `ship    probing big: Big`; `rules   0 broken`; no `STUCK`, no `SHADER ERROR`; every `fps` line ≥ 120 (the worst view is seated by a rock with both light groups on). Look at the `probe_hull_*` and inside renders yourself: a long box is expected, not a design. **If any fps line is under 120, stop:** the spec (§7.4) makes lowering the limit the owner's call; report the figures.

Then: the same command with `--ship nope`. Expected: `ship    no library ship called "nope"`, exit code 1, no window left open.

Then: `godot --path . --resolution 1280x720 --script test\probes\arrival_render.gd -- <abs out dir> --ship starter`. Expected: as before this task (every shot written, `arrival` lines, no `TIMED OUT`). And `--ship big`: `arrival no library ship called "big"`, exit 1.

- [ ] **Step 8: Commit**

```bash
git add who-knows/test/probes/probe_args.gd who-knows/test/probes/probe_args.gd.uid who-knows/test/unit/test_probe_args.gd .claude/skills/building-a-ship/ship_probe.gd who-knows/test/probes/arrival_render.gd
git commit -m "feat: --ship on the probe and the arrival render -- every proof runs on any ship"
```

Record the 600-block probe's fps lines in the ledger: Task 10 writes them into the spec.

---

### Task 8: The design skill

**Files:**
- Create: `.claude/skills/designing-a-ship/SKILL.md`

**Interfaces:**
- Consumes: Tasks 1–7's tools and their commands; `building-a-ship`'s `SKILL.md` and `reference.md`.
- Produces: the skill the agent (Task 9) loads by name, `designing-a-ship`.

- [ ] **Step 1: Write the skill**

Create `.claude/skills/designing-a-ship/SKILL.md` with exactly this content:

````markdown
---
name: designing-a-ship
description: Use when designing a new ship for the who-knows Godot project, or reshaping a library ship, from a description or "be creative" - choosing its role, size, decks, rooms and flight feel, and drawing it as a deck plan. The ship-designer agent runs on it; building-a-ship then builds and proves the result.
---

# Designing a ship

## Overview

This is the judgment half of making a ship: a brief becomes **numbers to hit** and a **deck plan**.
`building-a-ship` (beside this skill) is how to build and prove one, its checklist and its
*Mistakes already made*. Read both; this skill never repeats that one. The spec is
`docs/superpowers/specs/2026-10-09-ship-designer-design.md`.

**Existing blocks only** (`who-knows/data/blocks/`). A ship that wants a block the game lacks says
so in its report ("blocks I wished for"); never add one. **Every ship is usable:** boarded, flown,
walked and saved. **At most 600 blocks** (`ShipRules.TOO_BIG`).

## The tools

From the worktree's `who-knows` folder, with `godot` the console exe (`run_tests.ps1` has its
path) and `$k = <worktree>\.claude\skills\building-a-ship`:

| Do | Command |
|---|---|
| Print a ship as a plan | `godot --headless --path . --script $k\ship_plan.gd -- to-plan <id or ship .json> <abs out.plan>` |
| Plan to ship file | `godot --headless --path . --script $k\ship_plan.gd -- to-json <abs plan> <abs out\<id>.json>` |
| Check it (about 2 s) | `godot --headless --path . --script $k\ship_check.gd -- <abs or res:// ship .json>` |
| Probe it, windowed | `godot --path . --resolution 1280x720 --script $k\ship_probe.gd -- <abs out dir> --ship <id>` |
| Watch it arrive | `godot --path . --resolution 1280x720 --script test\probes\arrival_render.gd -- <abs out dir> --ship <id>` |
| Prove it usable | `.\run_tests.ps1 '-gselect=test_ship_catalog.gd'` |

In a fresh worktree run `godot --headless --path . --import` once first, or every class is
"not declared".

## The plan

One map per storey, **seen from above, bow up, port on the left**: rows run z from the bow (−z) to
the stern, columns x from port (−x) to starboard. Each deck line gives its y and x range; each row
starts `z <n>` and holds one token per cell; `.` is empty. `#` starts a comment, except on the
`ship`, `name` and `desc` lines.

**Tokens.** Every block and orientation has one: the block's base token, then the orientation
unless it is 0 (`W3`, `Fh2`, `Cp4`).

| Token | Block | Token | Block | Token | Block |
|---|---|---|---|---|---|
| `H` | hull | `D` | deck | `K` | core |
| `S` | pilot_seat | `C` | canopy | `A` | airlock |
| `B` | bulkhead | `O` | door | `T` | thruster |
| `R` | rcs | `W` | hull_wedge | `Bk` | bunk_room |
| `Gy` | galley | `Ba` | bathroom | `Wr` | weapon_room |
| `Cl` | closet | `Cp` | computer | `Qk` | quantum_core |
| `Qm` | quantum_machine | `Qc` | quantum_cell | `G` | grav_plating |
| `Ar` | armour | `L` | ladder | `Fs` | fairing_slope |
| `Fh` | fairing_half | `Fi` | fairing_corner_in | `Fo` | fairing_corner_out |
| `Fl` | fairing_slope_long_high | `Fk` | fairing_slope_long_low | | |

The rcs pushes are arrows: `R<` to port (8), `R>` to starboard (12), `R^` up (16), `Rv` down (20),
`Rb` aft, a retro (4). `T` pushes forward (a main engine at the stern). Orientation codes are in
`building-a-ship/reference.md`. A `legend` section before the first deck can name its own tokens
(`X  fairing_half 2`).

## 1. The brief becomes numbers

Write the targets down **before** drawing, as `ship_check`'s `FEEL` and `SIZE` notes print them.
The starter is the yardstick: **110 blocks, 104.7 t; turns 1.49 / 0.71 / 1.85 rad/s² (pitch / yaw
/ roll); side 4.8, vertical 9.6, brake 4.8, forward 14.3 m/s²; 36 MW made, 31.3 drawn; 14,500 km
of warp.**

| The brief says | Means | Moved by |
|---|---|---|
| nimble, agile, a fighter | every turn above the starter's | rcs far from the centre of mass, less mass |
| heavy, a freighter | turns below 0.5, forward 3–8 | mass; but brake and side stay ≥ 2 or it can't stop or settle |
| fast | forward above 14 | thrusters (300 kN each) per tonne |
| steady, doesn't slide | side ≥ 5 | lateral rcs pairs (250 kN each) per tonne |
| long range | warp above 14,500 km | quantum cells (400 QE each) |
| roomy, comfortable | more rooms than the starter's five, windows | walkable cells, rooms at the hull |

A turn rate is `torque / inertia`: inertia grows with the **square** of length, so a long ship
turns slowly unless it has rcs at **both ends**.

## 2. Roles

| Role | Shape | Leans on | Watch for |
|---|---|---|---|
| shuttle | the starter: one cabin storey, an equipment storey over it | — | — |
| fighter | short, canopy forward, little inside | rcs, thrusters, a small cabin | too small for the airlock, the stand cell behind the helm and the droid's closet |
| hauler | long, a hold of open deck or rooms | quantum cells, lateral rcs | mass above the thrust line (pitch under burn); power for every walkable cell |
| explorer | bunks, galley, a computer, long reach | quantum cells, `Cp` facing a window | power |
| yacht | rooms with windows, comfort over speed | rooms at the hull, `Ba`, `Gy` | the droid reaching every porthole |

## 3. Be creative

Pick one role and one twist, say which, and read the `.md` of every ship in `data/ships/` first:
never the same pair as one already there.

Twists: a ventral bridge (the helm on a lower storey); twin engine pods on outriggers; a long spine
with the cabin at the bow; a stubby brick with huge engines; a ring of rooms round the quantum
core; a hammerhead bow wider than the hull; a stern bridge looking back over the ship; a ship that
is mostly hold; an asymmetric hull (and its balance fixed by mass, not by weaker rcs).

## 4. The method

Draw and check **one layer at a time** (`to-json`, then `ship_check`), never all at the end:

1. **The walkable storey:** the helm (`S`) looking at the canopy (`C`); the cell behind it walkable
   deck (you stand up into it); the corridor; the airlock (`A`) with one face to space and deck
   through its other; the rooms, each touching walkable space; a closet (`Cl`) for the droid; every
   porthole, console and fixture it tends reachable on foot. One walkable storey for now: ladders
   don't climb yet (`CUT_OFF`).
2. **The equipment storey** over or under it: the core (`K`), quantum cells, grav plating.
3. **Power** (§5).
4. **Engines and rcs** sized to the targets: main thrusters at the stern pushing forward, a retro
   pair, rcs in opposed pairs on every axis, port and starboard mirrored, every rcs's exhaust face
   open (the probe and `ship_check` say `RCS_BLOCKED`).
5. **The outside:** wedges and fairings outside the cabin row; the skin chamfers for free.
6. **Mirror port and starboard** unless the twist says otherwise.

## 5. Budgets

- **Power:** only `quantum_core` makes power, **36 MW** each, with 10% to spare (`POWER_MARGIN`).
  Draws: thruster 3, core 2, grav plating 1.5, rcs 1, airlock 0.6, pilot seat 0.5, quantum machine
  0.5, door 0.3, computer 0.3, **every walkable or room cell 0.1**. Hull, fairings, cells and
  armour draw nothing. **The starter already draws 31.3 of its core's 36 MW** (its five thrusters,
  eight rcs and two grav plates are most of it), so one core leaves room for about a dozen more
  cabin cells and nothing else: **most new ships need a second quantum core.** Put it on the
  walkable storey beside the corridor, never in it (a quiet fixture; `Qk4` faces aft). The quantum
  plant runs any number.
- **Mass** (t): quantum core and cell 5, core 4, armour 3, thruster 2.5, grav plating 1.5, airlock
  1.2, hull and rcs 1, bulkhead 0.8, door and wedge 0.6, canopy and seat 0.5, deck and rooms 0.4,
  fairings 0.3.
- **Size:** 600 blocks at most. A 600-block ship builds in about 1.9 s when it spawns, a freeze the
  owner accepted for now; its rules take 0.6 s.

## 6. Worked example: the starter

`to-plan starter` prints it:

```
ship   starter
name   Starter shuttle
desc   Two decks: a bridge with a cockpit pod, five rooms, an airlock aft.

deck y=2    x: -1 .. 1
z -2  Fk  Fk  Fk
z -1  Fh  Fh  Fh
z 0   Fh  Fh  Fh
z 1   Fh  Fh  Fh
z 2   Fh  Fh  Fh
z 3   Fk4 Fk4 Fk4

deck y=1    x: -3 .. 3
z -4  .  Rv R> W  R< Rv .
z -3  .  R^ W  H  W  R^ .
z -2  .  Rb H  H  H  Rb .
z -1  .  H  H  K  H  H  .
z 0   .  H  Qc Qc Qc H  .
z 1   Fs H  G  H  G  H  Fs
z 2   .  H  H  H  H  H  .
z 3   .  W4 T  T  T  W4 .

deck y=0    x: -3 .. 3
z -4  .   .   C   C   C   .   .
z -3  .   W3  Cp4 S   D   W1  .
z -2  .   H   D   Qk4 D   H   .
z -1  .   H   D   D   Qm  H   .
z 0   .   H   Bk  D   Gy  H   .
z 1   H   H   Bk  D   Wr  H   H
z 2   H   H   Ba  D   Cl  H   H
z 3   T   H   B   A   B   H   T

deck y=-1    x: 0 .. 0
z -3  Fh2
z -2  Fh2
z -1  Fh2
z 0   Fh2
z 1   Fh2
z 2   Fh2
```

- **y = 0, the cabin.** The canopy row (z −4) ahead of the helm `S`; the bridge computer `Cp4` to
  port facing aft; the quantum core `Qk4` straight behind the helm, so you stand up to its
  starboard side; the machine `Qm`; the corridor down x = 0 with a bunk room (two cells), bathroom,
  galley, weapon room and closet beside it; the airlock `A` at the stern between bulkheads; engine
  pods at x = ±3 with a thruster each.
- **y = 1, equipment and roof.** The core `K`, three quantum cells, grav plating, a roof thruster
  bank at the stern, the rcs at the bow.
- **y = 2 and y = −1:** a fairing spine above and a keel below.

`data/ships/starter.md` says why each block is where it is: read it before your first design.

## Mistakes already made (don't repeat)

| Mistake | What happened | Do instead |
|---|---|---|
| One quantum core for a big ship | A 600-block draft drew 92.8 MW against 36 made | Count power while drawing the cabin; a second `Qk` beside the corridor; grav plating sparingly (1.5 MW each) |
| RCS only at the bow of a long ship | The 43-row draft turned 0.06 / 0.03 / 0.42 rad/s² | Rcs pairs at both ends; the lever arm is free authority |
| Probing in a fresh worktree | Every class "not declared", no output at all | `godot --headless --path . --import` once first |
````

- [ ] **Step 2: Check every name in it exists**

For each block token row, the token must match `ShipPlan.BASE` (Task 1); for each command, run it once on the starter (`to-plan starter`, `ship_check` on `res://data/ships/starter.json`, the probe is Task 7's run). Check the worked example equals `test_ship_plan.gd`'s `STARTER_PLAN` (a diff of the two blocks).
Expected: no differences.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/designing-a-ship/SKILL.md
git commit -m "docs: the designing-a-ship skill -- brief to numbers to a deck plan"
```

---

### Task 9: The agent

**Files:**
- Create: `.claude/agents/ship-designer.md`

**Interfaces:**
- Consumes: Task 8's skill `designing-a-ship`; `building-a-ship`.
- Produces: the subagent `ship-designer`, dispatched by a session with the brief and, when the session has made it, the worktree path.

- [ ] **Step 1: Write the agent**

Create `.claude/agents/ship-designer.md` with exactly this content:

````markdown
---
name: ship-designer
description: Designs, builds and proves a new ship for the who-knows game (or reshapes a library ship) from a description or "be creative", start to finish, and reports back with renders and numbers. Use when the owner asks for a ship to be designed, made or reshaped.
tools: Read, Write, Edit, Glob, Grep, Bash, PowerShell
model: opus
---

You design ships for **who-knows**, a Godot 4.5 space game. You work alone from the brief to a
proven ship and report once, at the end. The owner judges the result; you never ask them
anything mid-run.

## Rules you cannot break

- **Existing blocks only** (`who-knows/data/blocks/`). Never add or change a block, a mesh, a
  shader or anything under `who-knows/src/`. A block you wished for goes in your report.
- **Every ship is usable:** boarded, flown, walked and saved. A ship that breaks a rule is not
  finished.
- **At most 600 blocks.**
- **Your ship's branch only.** You write `data/ships/<id>.json` and `data/ships/<id>.md`, and
  nothing else in the repository. You commit on branch `ship-<id>`; you never merge, push or
  touch `main`.
- **The style guide** (`docs/design/visual-style.md`) is binding on how a ship looks.
- **Never revise `starter`** unless the brief asks for it by name: its file is pinned by a test.

## Read first

`CLAUDE.md`; the `designing-a-ship` skill (`.claude/skills/designing-a-ship/SKILL.md`); the
`building-a-ship` skill and its `reference.md`; `data/ships/starter.md` and the `.md` of every
other ship in `data/ships/`.

## A run

1. **The brief.** From the description, or for "be creative" a role and a twist from the skill
   (§3), never a pair a library ship already has. Choose an id (lower case, digits, `_`; not one in
   `data/ships/` unless this is a revision the brief asked for) and a name. Write the **targets as
   numbers** (skill §1) before drawing anything.
2. **The worktree.** Work in the worktree the brief names. If it names none, create
   `D:/git/whoknows-ship-<id>` on a new branch `ship-<id>` from `main`
   (`git worktree add ../whoknows-ship-<id> -b ship-<id> main`, run from the main checkout), and
   run every later command in it. Run `godot --headless --path who-knows --import` there once. If
   the harness refuses a git command, stop and report the refusal word for word; never work round
   it. A revision starts with `to-plan <id>`.
3. **The design loop.** Draw the plan (keep it outside the repository, in a scratch folder),
   `to-json` it to `data/ships/<id>.json`, run `ship_check`, read every broken rule and the
   `FEEL` and `SIZE` notes, change the plan. One `ship_check` is one round. Done when no rule is
   broken and every target is met or its miss is explained. **At most 12 rounds.**
4. **Write `data/ships/<id>.md`:** the concept in a paragraph; the role and twist; the deck maps
   (paste the plan's decks); a table of each target against what `ship_check` says; why each
   unusual block is where it is, as `starter.md` does.
5. **Prove it**, in order, each passing before the next (a failure is a round back at step 3):
   1. `ship_check`: zero rules broken.
   2. `.\run_tests.ps1 '-gselect=test_ship_catalog.gd'`: all pass (it covers your ship by itself).
   3. The probe with `--ship <id>`, windowed, logged to a file: no `STUCK`, no `UNREACHABLE`, no
      `UNMATCHED`, no `SHADER ERROR`, every `fps` line ≥ 120.
   4. `arrival_render.gd --ship <id>`: your ship arriving out of warp.
6. **Look.** Open the probe's `probe_hull_*`, `probe_seated*`, `probe_stood*` and the arrival
   shots, and judge them against the style guide: chunky, warm and dim, the shape you meant, the
   windows where you meant them. Unhappy: back to step 3.
7. **Commit** the two files on `ship-<id>`, the message ending
   `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

**Stopping early.** Twelve rounds without zero broken rules, or a proof that keeps failing: commit
what you have with a subject starting `wip:` and report what blocks you. Cut off mid-run (a rate
limit, a crash), the branch and your plan are where you left them; told to resume, read them and
carry on.

## Your report

Your last message is the report the session relays to the owner:

- **The ship:** id, name, role and twist, blocks, tonnes, and the concept in two or three lines.
- **The decks:** the maps.
- **Targets:** a table, each target against the number reached.
- **Renders:** the absolute paths of the best six (hull quarters, seated, stood, arrival), for the
  session to send.
- **Gave up on:** anything not reached, and why.
- **Blocks I wished for:** what a missing block would have done for this ship.
- **Branch and commit.**
````

- [ ] **Step 2: Check it**

Check the frontmatter parses (the file starts `---`, the `name` is `ship-designer`, the tools are names this harness has) and that every path and command in it exists after Tasks 1–8 (`ship_plan.gd`, `ship_check.gd`, `ship_probe.gd --ship`, `arrival_render.gd --ship`, `test_ship_catalog.gd`).
Expected: all exist.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/ship-designer.md
git commit -m "feat: the ship-designer agent -- a ship from a brief, start to finish, on its own branch"
```

---

### Task 10: Docs

**Files:**
- Modify: `.claude/skills/building-a-ship/SKILL.md`, `.claude/skills/building-a-ship/reference.md`, `CLAUDE.md`, `docs/superpowers/specs/2026-10-09-ship-designer-design.md`

**Interfaces:**
- Consumes: everything above; the fps lines from Task 7's ledger entry.
- Produces: docs that name only things that exist.

- [ ] **Step 1: building-a-ship**

In `.claude/skills/building-a-ship/SKILL.md`:
- in *Overview*, after the worked-example sentence: `` `ship_plan.gd` (beside this file) prints any ship as a deck plan and turns a plan into a ship file; designing one from a brief is the `designing-a-ship` skill's. ``
- in step 9 (*Probe the real scene*), after the run sentence: `` `--ship <id or ship .json>` probes that ship instead of the starter (saving off); the two-ship pass then parks the real starter beside it. ``
- in *Mistakes already made*, the two rows from the design skill's table (one quantum core for a big ship; rcs only at the bow of a long ship).

In `.claude/skills/building-a-ship/reference.md`, a new section after the library section:

```markdown
## Deck plans (`ShipPlan`, `ship_plan.gd`)

`ShipPlan.parse(text, catalog, file) -> {id, name, description, grid, notes} | {error}` and
`ShipPlan.to_text(id, name, description, grid) -> String`, exact both ways
(`docs/superpowers/specs/2026-10-09-ship-designer-design.md` §4). The token table is
`ShipPlan.BASE`; the designing-a-ship skill prints it. `ShipLibrary.resolve(what)` reads a library
id or a ship file. `ShipRules.MOST_BLOCKS` is 600 (`TOO_BIG`). `flight_test.gd`'s `starter_ship`
starts you aboard any ship, saving off; `ProbeArgs` reads `--ship` for the probe and
`arrival_render.gd`.

| Command | |
|---|---|
| `ship_plan.gd -- to-plan <id or ship .json> <out.plan>` | print a ship as a plan |
| `ship_plan.gd -- to-json <plan> <out\<id>.json>` | a plan to a ship file, refusing with line:column |
| `ship_probe.gd -- <out dir> --ship <id or ship .json>` | the probe on that ship |
| `arrival_render.gd -- <out dir> --ship <id>` | that library ship arriving |

**Measured at 600 blocks** (`test/fixtures/ships/big.json`, `test_big_ship.gd`): rules 0.6 s, a
spawn 1.9 s (accepted, guard 3 s), a save 63 KB, probe fps <the Task 7 figures>.
```

with `<the Task 7 figures>` replaced by the fps lines recorded in Task 7.

- [ ] **Step 2: CLAUDE.md**

Under *Ship building*, after the `data/ships/` paragraph:

```markdown
**A new ship is designed by the `ship-designer` agent** (`.claude/agents/ship-designer.md`, with
the `designing-a-ship` skill): from a description or "be creative", start to finish, on its own
branch `ship-<id>` in `D:/git/whoknows-ship-<id>`, never merged by the agent
(`docs/superpowers/specs/2026-10-09-ship-designer-design.md`).
```

- [ ] **Step 3: The spec**

In `docs/superpowers/specs/2026-10-09-ship-designer-design.md`: the status line gains `; built <date> on branch ship-designer (§11)`, the date of this task's commit; add `## 11. What was built` at the end: one paragraph per task's deliverable, the probe's fps at 600 blocks, every ledger `Ruling:`, and `**Acceptance:** not yet run` (Task 11 fills it).

- [ ] **Step 4: Check names**

Search the three docs for every name they mention (`ShipPlan`, `to_text`, `resolve`, `MOST_BLOCKS`, `TOO_BIG`, `starter_ship`, `ProbeArgs`, `--ship`, `designing-a-ship`, `ship-designer`) and confirm each exists in the code or the files.
Expected: all exist.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/building-a-ship/SKILL.md .claude/skills/building-a-ship/reference.md CLAUDE.md docs/superpowers/specs/2026-10-09-ship-designer-design.md
git commit -m "docs: the ship designer as built -- the skills, CLAUDE.md, the spec"
```

---

### Task 11: Acceptance (after the final review)

Not part of the build's review: it runs after the whole-branch review and its fixes, before the owner merges.

- [ ] **Step 1: "Be creative"**

Make the worktree for it from the build branch (the agent needs this branch's tools; `main` lacks them until the merge): `git worktree add ../whoknows-ship-<id> -b ship-<id> ship-designer`, choosing a provisional id `creative1`. Dispatch the `ship-designer` agent (`subagent_type: ship-designer`) with: "Be creative. Work in D:/git/whoknows-ship-creative1 (branch ship-creative1); rename the id if you choose another, and say so." Wait for its report.

- [ ] **Step 2: The owner's description**

Ask the owner for a description. Make its worktree the same way, and dispatch the agent with the description and the path.

- [ ] **Step 3: Relay**

Send the owner each report and its renders (SendUserFile). Record what went wrong in a run (a round lost to the tools, a misleading line in either skill) as rows in the two skills' *Mistakes already made* on `ship-designer`, and the acceptance outcome in spec §11. Each ship's merge is the owner's call; the two ship branches are rebased onto `main` after `ship-designer` merges.

- [ ] **Step 4: Commit the lessons**

```bash
git add .claude/skills/designing-a-ship/SKILL.md .claude/skills/building-a-ship/SKILL.md docs/superpowers/specs/2026-10-09-ship-designer-design.md
git commit -m "docs: what the first two designed ships taught"
```
