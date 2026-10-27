class_name PilotReadout
extends Label

## The pilot readout (docs/superpowers/specs/2026-10-24-hostile-ships-design.md
## §10.2), a debug overlay in the plain style of the F3 readout, for tuning: F2
## opens and shuts it; while it is open it shows a block for each other ship in
## contact, hostiles and crew, with what its pilot makes of the fight. `[` and
## `]` select one, S cycles its style choice, - and = take its skill down and
## up, H flips its side. It shuts the other dev panels and they shut it. Like
## the spawn panel it only asks: the flight scene fills the rows and does the
## work, so src/ui never learns about Fleet or Ship.

signal style_asked(id: StringName)
signal skill_asked(id: StringName, step: float)
signal side_asked(id: StringName)

const KEY := KEY_F2
## Its gap from the screen's top right corner: there, not where the other dev
## panels sit, so the controls card (on the left while you sit) never hides it.
const MARGIN := 16.0
## How far one press of - or = moves a pilot's skill.
const SKILL_STEP := 0.1

## Returns Array[Dictionary], one per ship in contact: {id, name, side, style,
## style_choice, skill, preferred, range, intent, qe, qe_max, hull, score}.
## Given by the flight scene.
var rows: Callable
## The selected row, kept in range as ships come and go.
var selected := 0
var _rows: Array = []

func _ready() -> void:
	add_to_group(CreaturePanel.GROUP)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -MARGIN
	offset_right = -MARGIN
	offset_top = MARGIN
	visible = false
	refresh()

func _process(_delta: float) -> void:
	if visible:
		refresh()

## Reads the rows again and redraws.
func refresh() -> void:
	_rows = rows.call() if rows.is_valid() else []
	selected = clampi(selected, 0, maxi(_rows.size() - 1, 0))
	text = describe(_rows, selected)

## What the readout says for `rows` with `selected` picked.
static func describe(rows_now: Array, picked: int) -> String:
	var lines := PackedStringArray(["PILOTS               F2 closes",
		"[ ] ship   S style   -/= skill   H side"])
	if rows_now.is_empty():
		lines.append("no ship in contact")
	for i in rows_now.size():
		var r: Dictionary = rows_now[i]
		lines.append("%s %s  %s" % [">" if i == picked else " ", String(r["side"]).to_upper(), r["name"]])
		lines.append("  %s (%s)   skill %.1f" % [r["style"], r["style_choice"], float(r["skill"])])
		lines.append("  range %d m   wants %d m   %s" % [roundi(float(r["range"])), roundi(float(r["preferred"])),
			_intent(r["intent"])])
		lines.append("  QE %d/%d   HULL %d%%   score %.2f" % [int(r["qe"]), int(r["qe_max"]),
			roundi(float(r["hull"]) * 100.0), float(r["score"])])
	return "\n".join(lines)

## &"holding_range" as HOLDING RANGE; nothing as -.
static func _intent(intent) -> String:
	var s := String(intent)
	return s.replace("_", " ").to_upper() if s != "" else "-"

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY:
		visible = not visible
		if visible:
			CreaturePanel.shut_others(self)
			refresh()
	elif not visible:
		return
	elif not _act(key.keycode):
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()

## One key while open. False when it is not one of the readout's.
func _act(code: Key) -> bool:
	refresh()
	var id: StringName = _rows[selected]["id"] if not _rows.is_empty() else &""
	match code:
		KEY_BRACKETLEFT:
			selected = wrapi(selected - 1, 0, maxi(_rows.size(), 1))
		KEY_BRACKETRIGHT:
			selected = wrapi(selected + 1, 0, maxi(_rows.size(), 1))
		KEY_S:
			if id != &"":
				style_asked.emit(id)
		KEY_MINUS:
			if id != &"":
				skill_asked.emit(id, -SKILL_STEP)
		KEY_EQUAL:
			if id != &"":
				skill_asked.emit(id, SKILL_STEP)
		KEY_H:
			if id != &"":
				side_asked.emit(id)
		_:
			return false
	refresh()
	return true
