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

var cell := Vector3i.ZERO
var holo: HoloVolume
var panels: Dictionary = {}   # StringName -> ReadoutPanel
var pages: Array[ComputerPage] = []
var page_index := 0
var ctx := ComputerContext.new()

var _label: Label3D
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

func press(button: StringName) -> void:
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

## What pressing `button` would do, or "" when it would do nothing: the
## Interactor passes over a dark button.
func prompt(button: StringName) -> String:
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
	if _seen():
		update(_unseen_for)
		_unseen_for = 0.0
	if _hum.stream == null:
		_hum.stream = Synth.sound(&"holo_hum")
	if _hum.stream != null and not _hum.playing and _hum.is_inside_tree():
		_hum.play()

## Redraws the holo and the rim, `delta` seconds since the last time.
func update(delta: float) -> void:
	page().holo(holo, ctx, delta)
	_refresh()

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
