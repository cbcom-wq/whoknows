class_name DialogPanel
extends CanvasLayer

## Talking with someone (docs/superpowers/specs/2026-11-16-wadoo-design.md §6): a
## panel low in the middle of the screen, in the computer's look (LIGHT_WARM on
## screen black, InteriorPalette), with the speaker's name, one page of what they
## say, and the keys. A line may end in one choice: its question and two answers,
## picked with 1 or 2; an answer may have a reply, shown before the panel shuts.
##
## F, Space or Enter turns the page; on the last it shuts. Esc shuts it at once.
## It knows nothing of who is speaking: it shows text and says how it ended.

## Shut: `answer` is the index of the answer picked, or -1.
signal finished(answer: int)

const WIDTH := 760.0
## Its bottom edge this far over the screen's bottom (clear of the HUD's band).
const LIFT := 150.0
const NAME_SIZE := 20
const TEXT_SIZE := 18
const SMALL_SIZE := 14
const PANEL_ALPHA := 0.88
const OUTLINE := 4
const NEXT_HINT := "F NEXT · ESC LEAVE"
const LAST_HINT := "F CLOSE"
const CHOOSE_HINT := "1 / 2 ANSWER · ESC LEAVE"

var speaker := ""
var pages: Array[String] = []
var page := 0
var choice := {}
## What is showing: &"pages", &"choice" or &"reply".
var stage: StringName = &"pages"
var answer := -1

var name_label: Label
var text_label: Label
var answer_labels: Array[Label] = []
var hint_label: Label
var _box: PanelContainer
var _opened_frame := -1

func _ready() -> void:
	layer = 3
	_build()
	visible = false

## Shows `p_pages` said by `p_speaker`, then `p_choice` ({ask, answers: [{say,
## reply}]}) if it is not empty.
func open(p_speaker: String, p_pages: Array, p_choice := {}) -> void:
	speaker = p_speaker
	pages.clear()
	for p in p_pages:
		pages.append(str(p))
	choice = p_choice
	answer = -1
	page = 0
	stage = &"pages"
	if pages.is_empty() and not choice.is_empty():
		stage = &"choice"
	_opened_frame = Engine.get_process_frames()
	visible = true
	_show()

func is_open() -> bool:
	return visible

## The next page, the choice, or shut.
func next() -> void:
	if not visible or stage == &"choice":
		return
	if page + 1 < pages.size():
		page += 1
	elif stage == &"pages" and not choice.is_empty():
		stage = &"choice"
	else:
		close()
		return
	_show()

## Picks answer `i` of the choice: its reply, or shut.
func pick(i: int) -> void:
	var answers: Array = choice.get("answers", [])
	if not visible or stage != &"choice" or i < 0 or i >= answers.size():
		return
	answer = i
	var reply: Array = (answers[i] as Dictionary).get("reply", [])
	if reply.is_empty():
		close()
		return
	pages.clear()
	for p in reply:
		pages.append(str(p))
	page = 0
	stage = &"reply"
	_show()

func close() -> void:
	if not visible:
		return
	visible = false
	finished.emit(answer)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	var key := event as InputEventKey
	if event.is_action_pressed(&"ui_cancel"):
		close()
	elif key != null and key.pressed and not key.echo and key.keycode in [KEY_1, KEY_2]:
		pick(key.keycode - KEY_1)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		next()
	else:
		return
	get_viewport().set_input_as_handled()

func _show() -> void:
	name_label.text = speaker.to_upper()
	var answers: Array = choice.get("answers", [])
	var choosing := stage == &"choice"
	text_label.text = str(choice.get("ask", "")) if choosing else (pages[page] if page < pages.size() else "")
	for i in answer_labels.size():
		answer_labels[i].visible = choosing and i < answers.size()
		if i < answers.size():
			answer_labels[i].text = "%d   %s" % [i + 1, (answers[i] as Dictionary).get("say", "")]
	var last := page + 1 >= pages.size() and (stage == &"reply" or choice.is_empty())
	hint_label.text = CHOOSE_HINT if choosing else (LAST_HINT if last else NEXT_HINT)

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_box = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _alpha(InteriorPalette.SCREEN_BACK, PANEL_ALPHA)
	style.border_color = _alpha(InteriorPalette.TRIM, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	_box.add_theme_stylebox_override("panel", style)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = -WIDTH * 0.5
	_box.offset_right = WIDTH * 0.5
	_box.offset_bottom = -LIFT
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_box.add_child(column)
	name_label = _label(NAME_SIZE, InteriorPalette.AMBER)
	column.add_child(name_label)
	text_label = _label(TEXT_SIZE, InteriorPalette.LIGHT_WARM)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(WIDTH - 36.0, 0.0)
	column.add_child(text_label)
	for i in 2:
		var a := _label(TEXT_SIZE, InteriorPalette.AMBER)
		a.visible = false
		answer_labels.append(a)
		column.add_child(a)
	hint_label = _label(SMALL_SIZE, InteriorPalette.HOLO_DIM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(hint_label)

static func _alpha(c: Color, a: float) -> Color:
	c.a = a
	return c

func _label(size: int, colour: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", InteriorPalette.SCREEN_BACK)
	l.add_theme_constant_override("outline_size", OUTLINE)
	return l
