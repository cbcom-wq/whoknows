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
