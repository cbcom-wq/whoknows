class_name MachineCycle
extends RefCounted

## The quantum machine's state and rules (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §7.1-§7.4), as a pure state machine
## like AirlockCycle: its buttons press(), the plant step()s it once a physics
## tick with what is in the bay, the store and the list of what it can make,
## and reads back the cues that fired, the prompts, the three screen lines and
## the big button's colour. It touches no nodes, so every rule is testable
## headless.
##
## It reads the store and never changes it: the plant credits on &"credited"
## and debits on &"make_start", which is where QE actually moves.
##
## The rules it keeps:
## - with an item in the bay, the big button converts it: 1.2 s, the item
##   shrinking to a point, then a bead running the last 0.6 s to the core,
##   the credit landing as it arrives -- refused, STORE FULL, if the value
##   will not fit (§7.1);
## - with the bay empty, it makes whatever ◀/▶ have selected: the cost at
##   once, the item swelling into the bay over 1.5 s -- refused with NOT
##   ENOUGH QE, or MAKE · LOW POWER in low power; a make that would drop the
##   ship into low power warns (→ LOW POWER, AMBER) and still makes (§7.2);
## - converting works in low power (§8.3); nothing is pressed mid-cycle.

enum Stage { IDLE, CONVERTING, MAKING }

const CONVERT_TIME := 1.2
## The last part of a convert: the bead's run from the bay to the core.
const BEAD_TIME := 0.6
const MAKE_TIME := 1.5

## The big button's colours (spec §7.4), named as InteriorPalette names them;
## "" is dark. SIGNAL_GO when pressing will do something; AMBER while
## working, and for a make that will drop the ship into low power; CORAL
## when refused.
const GO := &"SIGNAL_GO"
const WORKING := &"AMBER"
const REFUSED := &"CORAL"

## Timing slack, so a run of equal steps lands a cue on the step that
## reaches its time rather than one step late.
const _EPSILON := 1e-6

var stage: Stage = Stage.IDLE
## Which of the make list ◀ and ▶ have selected, cheapest first.
var selected := 0
## Seconds into the convert or make under way.
var elapsed := 0.0
## The convert under way: what it is and what it is worth; for a make, what
## it costs.
var converting: StringName = &""
var value := 0
## The make under way.
var making: ItemDefinition = null

var _pending: StringName = &""
var _bead_sent := false
## What step() last saw, for the prompts and the screen.
var _bay_id: StringName = &""
var _bay_value := 0
var _store: QuantumStore = null
var _makeable: Array = []

## A button was pressed: &"big", &"prev" or &"next". Acted on at the next
## step().
func press(button: StringName) -> void:
	_pending = button

## Advances by `delta` seconds. `bay_item_id` and `bay_value` say what is
## stowed in the bay (&"" and 0 when it is empty); `makeable` is the make
## list, QuantumValues.makeable()'s order. Returns the cues that fired, in
## order (spec §7.4): &"convert_start", &"bead", &"credited"; &"make_start",
## &"materialized"; &"refused".
func step(delta: float, bay_item_id: StringName, bay_value: int, store: QuantumStore,
		makeable: Array) -> Array[StringName]:
	_bay_id = bay_item_id
	_bay_value = bay_value
	_store = store
	_makeable = makeable
	if not makeable.is_empty():
		selected = posmod(selected, makeable.size())
	var cues: Array[StringName] = []
	if _pending != &"":
		_handle_press(_pending, cues)
		_pending = &""
	match stage:
		Stage.CONVERTING:
			elapsed += delta
			if not _bead_sent and elapsed >= CONVERT_TIME - BEAD_TIME - _EPSILON:
				_bead_sent = true
				cues.append(&"bead")
			if elapsed >= CONVERT_TIME - _EPSILON:
				stage = Stage.IDLE
				cues.append(&"credited")
		Stage.MAKING:
			elapsed += delta
			if elapsed >= MAKE_TIME - _EPSILON:
				stage = Stage.IDLE
				cues.append(&"materialized")
	return cues

## The make list's selected entry, or null if there is nothing to make.
func selected_def() -> ItemDefinition:
	return null if _makeable.is_empty() else _makeable[posmod(selected, _makeable.size())]

## What pressing `button` would do now, or "" if nothing. A refused big
## button still says why, so it can be pressed and heard to refuse.
func prompt(button: StringName) -> String:
	if _store == null or stage != Stage.IDLE:
		return ""
	match button:
		&"big":
			if _bay_id != &"":
				if _bay_value > _store.room():
					return "Store full"
				return "Convert %s (+%d QE)" % [_name(_bay_id), _bay_value]
			var def := selected_def()
			if def == null:
				return ""
			var cost := QuantumValues.make_cost(def)
			match _make_state():
				&"low_power":
					return "Low power"
				&"short":
					return "Not enough QE"
				&"warn":
					return "Make %s (%d QE) · low power" % [def.display_name, cost]
			return "Make %s (%d QE)" % [def.display_name, cost]
		&"prev":
			return "Previous" if _browsing() else ""
		&"next":
			return "Next" if _browsing() else ""
	return ""

## The screen's three lines (spec §7.1-§7.2, style guide §2.8).
func screen() -> PackedStringArray:
	if _store == null:
		return PackedStringArray()
	var store_line := "STORE %d QE" % _store.amount
	if stage == Stage.CONVERTING:
		return PackedStringArray(["CONVERT · %s" % _name(converting).to_upper(), "+%d QE" % value, store_line])
	if stage == Stage.MAKING:
		return PackedStringArray(["MAKE · %s" % making.display_name.to_upper(), "COST %d QE" % value, store_line])
	if _bay_id != &"":
		return PackedStringArray(["CONVERT · %s" % _name(_bay_id).to_upper(), "+%d QE" % _bay_value,
			"STORE FULL" if _bay_value > _store.room() else store_line])
	var def := selected_def()
	if def == null:
		return PackedStringArray(["NOTHING TO MAKE", "", store_line])
	var heading := "MAKE · %s" % def.display_name.to_upper()
	var cost_line := "COST %d QE" % QuantumValues.make_cost(def)
	match _make_state():
		&"low_power":
			return PackedStringArray(["MAKE · LOW POWER", store_line, "FULL POWER %d QE" % _store.line()])
		&"short":
			return PackedStringArray([heading, cost_line, "NOT ENOUGH QE"])
		&"warn":
			return PackedStringArray([heading, cost_line, "→ LOW POWER"])
	return PackedStringArray([heading, cost_line, store_line])

## The big button's colour now: GO, WORKING, REFUSED or "" (dark).
func button_colour() -> StringName:
	if _store == null:
		return &""
	if stage != Stage.IDLE:
		return WORKING
	if _bay_id != &"":
		return REFUSED if _bay_value > _store.room() else GO
	if selected_def() == null:
		return &""
	match _make_state():
		&"low_power", &"short":
			return REFUSED
		&"warn":
			return WORKING
	return GO

func _handle_press(button: StringName, cues: Array[StringName]) -> void:
	if stage != Stage.IDLE:
		return
	match button:
		&"big":
			if _bay_id != &"":
				if _bay_value > _store.room():
					cues.append(&"refused")
					return
				stage = Stage.CONVERTING
				elapsed = 0.0
				_bead_sent = false
				converting = _bay_id
				value = _bay_value
				cues.append(&"convert_start")
				return
			var def := selected_def()
			if def == null:
				return
			if _make_state() == &"low_power" or _make_state() == &"short":
				cues.append(&"refused")
				return
			stage = Stage.MAKING
			elapsed = 0.0
			making = def
			value = QuantumValues.make_cost(def)
			cues.append(&"make_start")
		&"prev", &"next":
			if _browsing():
				selected = posmod(selected + (1 if button == &"next" else -1), _makeable.size())

## Whether ◀ and ▶ do anything: the bay empty, a list to step through, and
## the ship at full power.
func _browsing() -> bool:
	return stage == Stage.IDLE and _bay_id == &"" and _makeable.size() > 1 and not _store.is_low_power()

## Making the selected item right now: &"low_power" (refused), &"short"
## (refused: costs more than the store holds), &"warn" (would drop the ship
## below the line) or &"go".
func _make_state() -> StringName:
	if _store.is_low_power():
		return &"low_power"
	var cost := QuantumValues.make_cost(selected_def())
	if cost > _store.amount:
		return &"short"
	if _store.amount - cost < _store.line():
		return &"warn"
	return &"go"

## An item's name, from the make list, which holds every kind with a value.
func _name(id: StringName) -> String:
	for def: ItemDefinition in _makeable:
		if def.id == id:
			return def.display_name
	return String(id).capitalize()
