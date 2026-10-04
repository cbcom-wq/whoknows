class_name ShipComputer
extends Node3D

## One bridge computer's table
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §3, §10): its
## screen, five buttons, holo and pages, built by the dressing at the table's
## frames. The ship binds it to a ComputerContext after every rebuild, and
## saves and restores its state around the rebuild, so a page, a range and a
## selection survive one.
##
## Knows nothing about ships: it takes a frame and a context.

const BUTTONS: Array[StringName] = [&"page", &"range", &"prev", &"big", &"next"]
const BUTTON_SIZE := Vector3(0.09, 0.09, 0.03)
## The ReadoutPanel state each page colour lights.
const PANEL_STATE := {&"go": &"go", &"amber": &"cycling", &"dark": &""}
const SCREEN_SIZE := Vector3(0.5, 0.15, 0.012)
const SCREEN_PIXEL := 0.00105
const HUM_DB := -30.0
const BLIP_DB := -14.0
## Farther than this from the camera, the holo is not worth redrawing.
const SEEN_WITHIN := 12.0
## Picking with the mouse (computer mode spec §4.5): how far from a mark on
## screen a click still takes it, and the gap inside which the nearer to the
## camera wins.
const PICK_RADIUS := 24.0
const PICK_TIE := 2.0

var cell := Vector3i.ZERO
var holo: HoloVolume
var station: ComputerStation
var panels: Dictionary = {}   # StringName -> ReadoutPanel
var pages: Array[ComputerPage] = []
var page_index := 0
var ctx := ComputerContext.new()
## The contact under the cursor at a station, for the overlay's tag.
var hovered: StringName = &""
## The operator's spin of the holo at a station (spec §4.4).
var spin := 0.0:
	set(value):
		spin = value
		if holo != null:
			holo.set_spin(value)

var _label: Label3D
## A damaged table's screens glitch now and then (ship damage sections spec §7).
const GLITCH_EVERY := Vector2(1.0, 3.0)
const GLITCH_FOR := 0.15
var _glitch_in := 1.0
var _glitching := 0.0
var _unseen_for := 0.0
var _hum: AudioStreamPlayer3D
var _blip: AudioStreamPlayer3D

## Builds the table's moving parts at `f`, the table's fixture frame in this
## node's parent's space. Call once, before it enters the tree.
func setup(f: Transform3D, render_layer := InteriorKit.LAYER) -> void:
	pages = [MapPage.new(), StatusPage.new()]
	holo = HoloVolume.new()
	holo.name = "Holo"
	# Turned with the ship, not the table (spec §5.1): only the origin moves.
	holo.position = f * InteriorProps.holo_table_volume().origin
	holo.setup(render_layer)
	add_child(holo)

	var screen := Node3D.new()
	screen.name = "Screen"
	screen.transform = f * InteriorProps.holo_table_screen()
	add_child(screen)
	var kit := InteriorKit.new(screen)
	kit.layer = render_layer
	kit.light_mask = render_layer
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 0, SCREEN_SIZE.z * 0.5)), SCREEN_SIZE, 0.004,
		InteriorKit.solid(InteriorPalette.SCREEN_BACK))
	kit.commit()
	_label = ReadoutPanel.make_readout(render_layer, 450.0)
	_label.pixel_size = SCREEN_PIXEL
	_label.position = Vector3(0, 0, SCREEN_SIZE.z + 0.002)
	screen.add_child(_label)

	var frames := InteriorProps.holo_table_buttons()
	for i in BUTTONS.size():
		var button: StringName = BUTTONS[i]
		var panel := ReadoutPanel.new()
		panel.setup(button, InteriorKit.LAYER, render_layer, BUTTON_SIZE, false)
		panel.transform = f * frames[i]
		panel.prompt_source = prompt.bind(button)
		panel.pressed.connect(_on_pressed.bind(panel))
		add_child(panel)
		panels[button] = panel

	station = ComputerStation.new()
	station.setup(self, InteriorKit.LAYER)
	station.transform = f
	add_child(station)

	_hum = _player("Hum", holo.position, HUM_DB)
	_blip = _player("Blip", screen.transform.origin, BLIP_DB)
	_refresh()

func page() -> ComputerPage:
	return pages[page_index]

## Binds the table to its ship's context: after every rebuild, and whoever
## was operating it stays the operator.
func bind(context: ComputerContext) -> void:
	var operator := ctx.operator
	ctx = context
	if ctx.operator == null:
		ctx.operator = operator
	holo.clear_miniature()
	_refresh()

## Wrecked, the table is dark (ship damage sections spec §2.2).
func offline() -> bool:
	return ctx.computer_stage() == BlockDamage.Stage.WRECKED

func press(button: StringName) -> void:
	if offline():
		return
	if button == &"page":
		if pages.size() > 1:
			page_index = (page_index + 1) % pages.size()
			page().opened(ctx)
			_play(&"page")
	elif page().lit(ctx).has(button):
		var course_before: StringName = ctx.sensors.course if ctx.sensors != null else &""
		page().press(button, ctx)
		if button == &"range":
			_play(&"page")
		elif button == &"big" and ctx.sensors != null and ctx.sensors.course != course_before:
			_play(&"course_clear" if ctx.sensors.course.is_empty() else &"course_set")
	_refresh()

## The id of the target nearest `screen`, as `camera` sees the holo, within
## PICK_RADIUS; "" when there is none or the page is not the map.
func mark_at(screen: Vector2, camera: Camera3D) -> StringName:
	var map := page() as MapPage
	if map == null or camera == null:
		return &""
	var best: StringName = &""
	var best_off := INF
	var best_depth := INF
	for m: Dictionary in map.placed_marks:
		var at := holo.marks_to_global(m["position"])
		if camera.is_position_behind(at):
			continue
		var off := camera.unproject_position(at).distance_to(screen)
		if off > PICK_RADIUS:
			continue
		var depth := camera.global_position.distance_to(at)
		if off < best_off - PICK_TIE or (absf(off - best_off) <= PICK_TIE and depth < best_depth):
			best = m["id"]
			best_off = off
			best_depth = depth
	return best

## Selects the mark under `screen`, if there is one; returns its id or "".
func pick(screen: Vector2, camera: Camera3D) -> StringName:
	var id := mark_at(screen, camera)
	if id != &"":
		select(id)
	return id

## Names the mark under `screen` in `hovered`, "" when there is none.
func hover(screen: Vector2, camera: Camera3D) -> StringName:
	hovered = mark_at(screen, camera)
	return hovered

## Selects contact `id` on the map: a click in the holo or on the overlay's list.
## Between about 1,200 km and 9,000 km the list shows the whole system while a
## distant world can lie outside the holo, where it is no target and the next
## frame's reselect would undo the choice. So a contact that is not on the map
## first takes the map out to the whole system (it glides there), where every
## world is a target; one that is not a target even then (a contact that is not
## a world) is left alone, and the scale with it.
func select(id: StringName) -> void:
	var map := page() as MapPage
	if map == null:
		return
	if id != &"" and not _is_target(map, id):
		var was := map.scale_m
		map.scale_m = MapPage.STOPS[MapPage.SYSTEM_RANGE]
		if not _is_target(map, id):
			map.scale_m = was
			return
	map.selected = id
	if ctx.sensors != null:
		ctx.sensors.forget_arrival()
	_refresh()

func _is_target(map: MapPage, id: StringName) -> bool:
	return map.targets(ctx).any(func(c: Contact) -> bool: return c.id == id)

## What the big button would do (spec §5.3).
func act() -> void:
	press(&"big")

## Zooms the map by `notches` of the wheel; any other page ignores it.
func zoom(notches: float) -> void:
	var map := page() as MapPage
	if map != null:
		map.zoom(notches, ctx)
		_refresh()

## Opens page `index`: the overlay's tabs.
func tab(index: int) -> void:
	if index == page_index or index < 0 or index >= pages.size():
		return
	page_index = index
	page().opened(ctx)
	_play(&"page")
	_refresh()

## Opens the next page, as the PAGE button does.
func next_tab() -> void:
	press(&"page")

## What pressing `button` would do, or "" when it would do nothing: the
## Interactor passes over a dark button.
func prompt(button: StringName) -> String:
	if offline():
		return "Offline"
	if button == &"page":
		return "Next page" if pages.size() > 1 else ""
	if not page().lit(ctx).has(button):
		return ""
	return page().prompt(button, ctx)

func screen_text() -> String:
	return _label.text

func save() -> Dictionary:
	var saved := []
	for p in pages:
		saved.append(p.save())
	return {"page": page_index, "pages": saved}

func restore(state: Dictionary) -> void:
	page_index = clampi(int(state.get("page", 0)), 0, pages.size() - 1)
	var saved: Array = state.get("pages", [])
	for i in mini(saved.size(), pages.size()):
		pages[i].restore(saved[i])
	_refresh()

func _on_pressed(role: StringName, panel: ReadoutPanel) -> void:
	if panel.last_actor != null:
		ctx.operator = panel.last_actor
	press(role)

func _process(delta: float) -> void:
	ctx.time += delta
	_unseen_for += delta
	_glitch(delta)
	if _seen():
		update(_unseen_for)
		_unseen_for = 0.0
	if _hum.stream == null:
		_hum.stream = Synth.sound(&"holo_hum")
	if _hum.stream != null and not _hum.playing and _hum.is_inside_tree():
		_hum.play()

## Redraws the holo and the rim, `delta` seconds since the last time.
func update(delta: float) -> void:
	if not offline():
		page().holo(holo, ctx, delta)
	_refresh()

## Damaged, now and then the screen jumps for GLITCH_FOR to another page's
## title and lines, scrambled.
func _glitch(delta: float) -> void:
	if ctx.computer_stage() != BlockDamage.Stage.DAMAGED:
		_glitching = 0.0
		return
	if _glitching > 0.0:
		_glitching -= delta
		if _glitching <= 0.0:
			_refresh()
		return
	_glitch_in -= delta
	if _glitch_in > 0.0:
		return
	_glitch_in = randf_range(GLITCH_EVERY.x, GLITCH_EVERY.y)
	_glitching = GLITCH_FOR
	var other := pages[randi() % pages.size()]
	var shown := PackedStringArray([other.title()])
	shown.append_array(other.lines(ctx))
	var text := "\n".join(shown)
	for i in text.length():
		if text[i] != "\n" and text[i] != " " and randf() < 0.3:
			text[i] = char(33 + randi() % 60)
	_label.text = text

## Whether anyone can see the table: the holo and the rim are redrawn only
## then. The 30 km map places hundreds of marks, and nobody at the helm or
## outside needs them. With no camera (a headless test), always.
func _seen() -> bool:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null or not is_inside_tree():
		return true
	var at := holo.global_position
	if cam.global_position.distance_to(at) > SEEN_WITHIN:
		return false
	for corner in [Vector3.ZERO, Vector3(HoloVolume.RADIUS, 0, 0), Vector3(-HoloVolume.RADIUS, 0, 0),
			Vector3(0, 0, HoloVolume.RADIUS), Vector3(0, 0, -HoloVolume.RADIUS)]:
		if cam.is_position_in_frustum(at + corner):
			return true
	return false

func _refresh() -> void:
	holo.visible = not offline()
	if offline():
		_label.text = ""
		for button: StringName in BUTTONS:
			panels[button].set_readout(PackedStringArray(), &"")
		return
	var p := page()
	var shown := PackedStringArray([p.title()])
	shown.append_array(p.lines(ctx))
	_label.text = "\n".join(shown)
	var lit := p.lit(ctx)
	for button: StringName in BUTTONS:
		var state: StringName = &""
		if button == &"page":
			state = &"go" if pages.size() > 1 else &""
		elif button == &"big":
			state = PANEL_STATE[p.big_colour(ctx)] if lit.has(&"big") else &""
		elif lit.has(button):
			state = &"go"
		panels[button].set_readout(PackedStringArray(), state)

func _player(player_name: String, at: Vector3, db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.bus = AudioBuses.SHIP
	player.volume_db = db
	player.position = at
	add_child(player)
	return player

func _play(sound: StringName) -> void:
	var s := Synth.sound(sound)
	if s != null and is_inside_tree():
		_blip.stream = s
		_blip.play()
