class_name WeaponsPage
extends ComputerPage

## The bridge computer's WEAPONS page and the weapons station's board (ship
## weapons spec §7.4): the orders, the list -- each entry's label, distance, and
## NO ARC while no turret can bear -- and each turret's state. prev and next
## pick an entry, RANGE drops it, the big button switches the orders. Marking
## is done where you can see: the helm and the gun camera.
##
## Every line is fitted to the screen it is for: PAGE_COLUMNS on the table's
## small screen, BOARD_COLUMNS on the station's wide one (the tests measure both
## in metres). A crowded list shows the selected entry first and counts the
## rest ("+2"); crowded turrets are counted by state.

## How many characters a line may have on the table's screen (0.5 m wide).
const PAGE_COLUMNS := 30
## And on the weapons station's board (1.2 m wide).
const BOARD_COLUMNS := 78
## The longest label an entry shows.
const LABEL_MOST := 10

var selected := 0

func title() -> String:
	return "WEAPONS"

func lines(ctx: ComputerContext) -> PackedStringArray:
	return board_lines(ctx.fire_control if ctx != null else null, selected)

## The board's three lines, each at most `columns` characters; `p_selected` < 0
## marks none.
static func board_lines(fc: FireControl, p_selected: int, columns := PAGE_COLUMNS) -> PackedStringArray:
	if fc == null or fc.turrets.is_empty():
		return PackedStringArray(["NO WEAPONS"])
	var n := fc.turrets.size()
	var head := "%s · %d TURRET%s" % ["ENGAGE" if fc.orders == FireControl.Orders.ENGAGE else "HOLD", n,
		"" if n == 1 else "S"]
	return PackedStringArray([_fit(head, columns), _list_line(fc, p_selected, columns), _states_line(fc, columns)])

## The list on one line: from the selected entry (or the first) as many as fit,
## then how many are left out.
static func _list_line(fc: FireControl, p_selected: int, columns: int) -> String:
	if fc.entries.is_empty():
		return _fit("NO TARGETS · T TO MARK", columns)
	var first := clampi(p_selected, 0, fc.entries.size() - 1)
	var listed := PackedStringArray()
	for i in range(first, fc.entries.size()):
		var e: Dictionary = fc.entries[i]
		var d: float = e["distance"]
		var far := "--" if d < 0.0 else (("%.1f KM" % (d / 1000.0)) if d >= 1000.0 else ("%d M" % roundi(d)))
		listed.append("%s%d %s %s%s" % [">" if i == p_selected else "", i + 1, String(e["label"]).left(LABEL_MOST), far,
			"" if e["bearing"] else " NO ARC"])
	for shown in range(listed.size(), 0, -1):
		var line := " · ".join(listed.slice(0, shown))
		if shown < listed.size():
			line += " +%d" % (listed.size() - shown)
		if line.length() <= columns:
			return line
	return _fit(listed[0], columns)

## Each turret's state, or when those do not fit how many are in each state.
static func _states_line(fc: FireControl, columns: int) -> String:
	var pips := fc.pips()
	var each := PackedStringArray()
	var counts := {}
	for i in pips.size():
		var word := String(pips[i]).to_upper().replace("_", " ")
		each.append("T%d %s" % [i + 1, word])
		counts[word] = int(counts.get(word, 0)) + 1
	var line := " · ".join(each)
	if line.length() <= columns:
		return line
	var grouped := PackedStringArray()
	for word: String in counts:
		grouped.append("%d %s" % [counts[word], word])
	return _fit(" · ".join(grouped), columns)

static func _fit(text: String, columns: int) -> String:
	return text if text.length() <= columns else text.left(columns - 2) + ".."

func lit(ctx: ComputerContext) -> Array[StringName]:
	var fc := ctx.fire_control if ctx != null else null
	if fc == null or fc.turrets.is_empty():
		return []
	if fc.list.is_empty():
		return [&"big"]
	return [&"range", &"prev", &"big", &"next"]

func big_colour(ctx: ComputerContext) -> StringName:
	var fc := ctx.fire_control if ctx != null else null
	if fc == null or fc.turrets.is_empty():
		return &"dark"
	return &"go" if fc.orders == FireControl.Orders.ENGAGE else &"amber"

func prompt(button: StringName, ctx: ComputerContext) -> String:
	var fc := ctx.fire_control if ctx != null else null
	match button:
		&"big":
			return "Hold fire" if fc != null and fc.orders == FireControl.Orders.ENGAGE else "Engage"
		&"prev":
			return "Previous target"
		&"next":
			return "Next target"
		&"range":
			return "Drop target"
	return ""

func press(button: StringName, ctx: ComputerContext) -> void:
	var fc := ctx.fire_control if ctx != null else null
	if fc == null:
		return
	match button:
		&"big":
			fc.toggle_orders()
		&"prev":
			selected = posmod(selected - 1, maxi(fc.list.size(), 1))
		&"next":
			selected = posmod(selected + 1, maxi(fc.list.size(), 1))
		&"range":
			if selected < fc.list.size():
				fc.unmark(fc.list[selected])
				selected = clampi(selected, 0, maxi(fc.list.size() - 1, 0))

func save() -> Dictionary:
	return {"selected": selected}

func restore(state: Dictionary) -> void:
	selected = int(state.get("selected", 0))
