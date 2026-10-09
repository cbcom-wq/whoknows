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
