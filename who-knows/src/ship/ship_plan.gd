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
