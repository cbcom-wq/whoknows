class_name ComputerOverlay
extends CanvasLayer

## What you read and click at a bridge computer
## (docs/superpowers/specs/2026-09-30-computer-mode-design.md §5): the tabs, the
## list, the selected target's card and its action, a tag for the mark under
## the cursor, and the hints, round the holo, which stays in the room in the
## middle. In the table's look, not the flight HUD's: LIGHT_WARM on screen
## black, accents by kind, from InteriorPalette alone. It keeps no state of
## its own: each frame it reads the station's computer and its page.
##
## Every button here is built by _button, with no keyboard focus: the mode
## reads R, Tab and Enter in _unhandled_input, and a focused Button would take
## Tab and Enter as ui_focus_next and ui_accept before it could.

const FONT_SIZE := 18
const SMALL_SIZE := 14
const PANEL_ALPHA := 0.85
const LIST_WIDTH := 320.0
const CARD_WIDTH := 360.0
const MARGIN := 24.0
const CARD_LINES := 4
const TAG_OFFSET := Vector2(16, -24)
const HINTS := "DRAG ORBIT · SCROLL ZOOM · R RECENTRE · TAB PAGE · ENTER ACT"

var station: ComputerStation
var tabs: Array[Button] = []
var list_box: VBoxContainer
var list_title: Label
var card_lines: Array[Label] = []
var action: Button
var tag: Label
var scale_label: Label

var _list_panel: PanelContainer

func _ready() -> void:
	layer = 2
	_build()
	visible = false

## Shows the overlay for `s`, or hides it for null.
func show_for(s: ComputerStation) -> void:
	station = s
	visible = s != null
	if visible:
		refresh()

func _process(_delta: float) -> void:
	if visible and is_instance_valid(station):
		refresh()

func refresh() -> void:
	var computer := station.computer
	var ctx := computer.ctx
	var page := computer.page()
	for i in tabs.size():
		tabs[i].button_pressed = i == computer.page_index
	var map := page as MapPage
	_list_panel.visible = map != null
	if map != null:
		var system := ctx.sensors.system if ctx.sensors != null else null
		var far := MapPage.system_weight(map.scale_m) > 0.5 and system != null
		list_title.text = "SYSTEM · %s" % system.name.to_upper() if far else "NEARBY"
		_fill_list(list_rows(map, ctx))
		scale_label.text = map.title().trim_prefix("MAP · ")
	else:
		scale_label.text = ""
	var lines := page.lines(ctx)
	for i in CARD_LINES:
		card_lines[i].text = lines[i] if i < lines.size() else ""
	action.visible = map != null
	var lit := page.lit(ctx).has(&"big")
	action.disabled = not lit
	action.text = page.prompt(&"big", ctx).to_upper() if lit else "NO ACTION"
	_refresh_tag(computer)

## The list's rows (spec §5.2): far out, the system -- the star, each planet
## with its moons under it, each cluster; near in, what is on the map at full
## size, nearest first, with its distance.
static func list_rows(map: MapPage, ctx: ComputerContext) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var system := ctx.sensors.system if ctx.sensors != null else null
	if MapPage.system_weight(map.scale_m) > 0.5 and system != null:
		out.append(_row(map, ctx, BodyContacts.id_of(system.star), system.star.name, &"body", 0))
		for planet in system.bodies:
			if planet.kind != SystemBody.Kind.PLANET:
				continue
			out.append(_row(map, ctx, BodyContacts.id_of(planet), planet.name, &"body", 0))
			for moon in system.bodies:
				if moon.kind == SystemBody.Kind.MOON and moon.parent_id == planet.id:
					out.append(_row(map, ctx, BodyContacts.id_of(moon), moon.name, &"moon", 1))
		for t in system.clusters:
			out.append(_row(map, ctx, t.contact_id(), t.name, &"cluster", 0))
		return out
	for c in map.targets(ctx):
		out.append(_row(map, ctx, c.id, ContactText.line(c, ctx.relative(c.point).length()), c.kind, 0))
	return out

static func _row(map: MapPage, ctx: ComputerContext, id: StringName, text: String, kind: StringName,
		indent: int) -> Dictionary:
	var colour := MapPage.colour_for(kind)
	var c := MapPage.contact_by_id(ctx, id)
	if c != null:
		colour = map.reach_colour(ctx, c)
	if ctx.sensors != null and ctx.sensors.course == id:
		colour = InteriorPalette.AMBER
	return {"id": id, "text": text.to_upper(), "colour": colour, "indent": indent, "selected": map.selected == id}

## One button per row, reused from frame to frame.
func _fill_list(rows: Array[Dictionary]) -> void:
	while list_box.get_child_count() - 1 < rows.size():
		var b := _button("")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_row_pressed.bind(b))
		list_box.add_child(b)
	for i in range(1, list_box.get_child_count()):
		var b: Button = list_box.get_child(i)
		var shown := i - 1 < rows.size()
		b.visible = shown
		if not shown:
			continue
		var row: Dictionary = rows[i - 1]
		b.set_meta(&"id", row["id"])
		b.text = "%s%s %s" % ["    " if row["indent"] > 0 else "", "▸" if row["selected"] else " ", row["text"]]
		b.add_theme_color_override("font_color", row["colour"])
		b.add_theme_color_override("font_hover_color", row["colour"])

func _on_row_pressed(b: Button) -> void:
	if is_instance_valid(station):
		station.computer.select(b.get_meta(&"id"))

func _refresh_tag(computer: ShipComputer) -> void:
	var c := MapPage.contact_by_id(computer.ctx, computer.hovered) if computer.hovered != &"" else null
	tag.visible = c != null and computer.page() is MapPage
	if tag.visible:
		tag.text = ContactText.line(c, computer.ctx.relative(c.point).length()).to_upper()
		tag.position = get_viewport().get_mouse_position() + TAG_OFFSET

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.position = Vector2(MARGIN, MARGIN)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	for i in 2:
		var t := _button("MAP" if i == 0 else "STATUS")
		t.toggle_mode = true
		t.pressed.connect(func() -> void:
			if is_instance_valid(station):
				station.computer.tab(i))
		top.add_child(t)
		tabs.append(t)
	var leave := _label("ESC  LEAVE", SMALL_SIZE)
	leave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leave.position = Vector2(-MARGIN - 120.0, MARGIN)
	root.add_child(leave)

	_list_panel = _panel()
	_list_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_list_panel.offset_left = MARGIN
	_list_panel.offset_top = MARGIN * 3.0
	_list_panel.offset_bottom = -MARGIN * 3.0
	_list_panel.custom_minimum_size.x = LIST_WIDTH
	root.add_child(_list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_panel.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	list_title = _label("", SMALL_SIZE)
	list_box.add_child(list_title)

	var card := _panel()
	card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	card.offset_left = -CARD_WIDTH - MARGIN
	card.offset_right = -MARGIN
	card.custom_minimum_size.x = CARD_WIDTH
	root.add_child(card)
	var card_box := VBoxContainer.new()
	card.add_child(card_box)
	for i in CARD_LINES:
		var l := _label("", FONT_SIZE if i == 0 else SMALL_SIZE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_box.add_child(l)
		card_lines.append(l)
	action = _button("")
	action.pressed.connect(func() -> void:
		if is_instance_valid(station):
			station.computer.act())
	card_box.add_child(action)

	var hints := _label(HINTS, SMALL_SIZE)
	hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hints.position = Vector2(MARGIN, -MARGIN - 20.0)
	root.add_child(hints)
	scale_label = _label("", FONT_SIZE)
	scale_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	scale_label.position = Vector2(-MARGIN - 160.0, -MARGIN - 24.0)
	root.add_child(scale_label)
	tag = _label("", SMALL_SIZE)
	tag.visible = false
	root.add_child(tag)

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(InteriorPalette.SCREEN_BACK, PANEL_ALPHA)
	box.border_color = _alpha(InteriorPalette.TRIM, 0.4)
	box.set_border_width_all(1)
	box.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", InteriorPalette.LIGHT_WARM)
	return l

## Every button here comes from this: no keyboard focus, so Tab and Enter reach
## the mode's _unhandled_input.
func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", SMALL_SIZE)
	b.add_theme_color_override("font_color", InteriorPalette.LIGHT_WARM)
	b.add_theme_color_override("font_pressed_color", InteriorPalette.AMBER)
	b.add_theme_color_override("font_disabled_color", InteriorPalette.HOLO_DIM)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = _alpha(InteriorPalette.SCREEN_BACK, 0.0 if state == "normal" else 0.6)
		box.border_color = _alpha(InteriorPalette.TRIM, 0.5 if state == "pressed" else 0.0)
		box.set_border_width_all(1)
		box.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, box)
	return b

## `c` at alpha `a`: the palette has no alpha of its own to give.
static func _alpha(c: Color, a: float) -> Color:
	c.a = a
	return c
