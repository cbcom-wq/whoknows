class_name CreaturePanel
extends Label

## The creature panel (docs/superpowers/specs/2026-10-18-rock-creatures-design.md
## §7.2), the F10 twin of the F6 spawn panel: F10 opens and shuts it; while it
## is open 1-9 ask for that creature. Shut, those keys do nothing, and a held
## key's repeats never do. It only asks: the flight scene does the work and
## says how it went on the last line, so src/ui never learns about rocks.
## Opening it shuts the other dev panel, and the other way round: they sit in
## the same place.

signal creature_asked(index: int)

const KEY := KEY_F10
## Every dev panel joins this group; opening one shuts the rest.
const GROUP := &"dev_panels"
## The number keys 1-9: the most creatures the panel lists.
const MOST := 9
## The same place as the spawn panel's: only one is open at a time.
const AT := Vector2(16, 140)
## The order the flight scene lists the species its catalog has.
const ORDER: Array[StringName] = [&"skitter", &"glinter", &"delver", &"limpet", &"maintenance_droid"]

## One line per creature, in ORDER.
var entries: Array[String] = []:
	set(value):
		entries = value
		_redraw()
var _said := ""

func _ready() -> void:
	add_to_group(GROUP)
	position = AT
	visible = false
	_redraw()

## Shows `text` on the last line: what the last ask came to.
func say(text: String) -> void:
	_said = text
	_redraw()

## Shuts every other dev panel; `me` is the one that just opened.
static func shut_others(me: Node) -> void:
	if not me.is_inside_tree():
		return
	for other in me.get_tree().get_nodes_in_group(GROUP):
		if other != me and other is CanvasItem:
			(other as CanvasItem).visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY:
		visible = not visible
		if visible:
			shut_others(self)
	elif not visible:
		return
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var i: int = key.keycode - KEY_1
		if i >= mini(entries.size(), MOST):
			return
		creature_asked.emit(i)
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _redraw() -> void:
	var lines := PackedStringArray(["CREATURES            F10 closes"])
	for i in mini(entries.size(), MOST):
		lines.append("%d  %s" % [i + 1, entries[i]])
	if _said != "":
		lines.append(_said)
	text = "\n".join(lines)
