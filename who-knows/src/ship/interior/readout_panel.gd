class_name ReadoutPanel
extends Area3D

## A panel with one big lit button and, usually, a small readout of live state
## (docs/superpowers/specs/2026-09-24-airlock-design.md §3.4, style guide
## §2.8): the airlock's panels, lifted out of AirlockPanel so the quantum
## machine can share them (quantum energy spec §6.3, §14.1). The Interactor
## finds it like any interactable; pressing it says which panel was pressed and
## nothing more. Whoever owns it decides what that means, and what the readout
## and the prompt say.
##
## Its size is a parameter. Without a screen it is just a button, like the
## machine's arrows; such a button can be given a readout that stands apart
## from it (the machine's screen, above its bay), and set_readout writes there.
##
## Knows nothing about ships. Its frame: origin at the panel's centre on the
## surface it is mounted on, +z out of that surface.

signal pressed(role: StringName)

## The airlock panel's size, and the proportions every panel with a screen is
## laid out in.
const SIZE := Vector3(0.34, 0.5, 0.06)
const BUTTON_STATES := [&"go", &"cycling", &"vacuum"]

## Which panel this is, as its owner names it: &"room", &"inner" or &"outer"
## on the airlock; &"big", &"prev" or &"next" on the quantum machine.
var role: StringName = &""
## Returns the prompt, or "" when pressing would do nothing.
var prompt_source: Callable
## Where set_readout writes its lines: the panel's own screen, or one standing
## apart from it (make_readout), or null for a button that shows no lines.
var readout: Label3D

var _buttons: Dictionary = {}   # StringName -> MeshInstance3D

## Builds the panel on physics layer bits `layer_bits` and render layer
## `render_layer`, `size` across, with a screen above the button or, without
## one, the button alone in the middle. Call once, before it enters the tree.
func setup(panel_role: StringName, layer_bits: int, render_layer := InteriorKit.LAYER, size := SIZE,
		has_screen := true) -> void:
	role = panel_role
	name = "Panel_%s" % panel_role
	collision_layer = layer_bits
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")

	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0, 0, 0.04)
	var hit := CollisionShape3D.new()
	hit.shape = shape
	hit.position = Vector3(0, 0, size.z * 0.5)
	add_child(hit)

	# A panel with a screen keeps the airlock panel's proportions: the screen
	# across the top, the button below it. A button alone fills its face.
	var front := size.z
	var k := minf(size.x / SIZE.x, size.y / SIZE.y)
	var button_at := Vector3(0, -0.24 * size.y, 0) if has_screen else Vector3.ZERO
	var radius := 0.06 * k if has_screen else 0.3 * minf(size.x, size.y)
	var rim := 0.085 * k if has_screen else 0.4 * minf(size.x, size.y)

	var look := Node3D.new()
	look.name = "Look"
	add_child(look)
	var kit := _kit(look, render_layer)
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 0, front * 0.5)), size,
		minf(0.025, minf(size.x, size.y) * 0.15), InteriorKit.solid(InteriorPalette.TRIM))
	if has_screen:
		kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 0.2 * size.y, front + 0.004)),
			Vector3(size.x - 0.06, 0.4 * size.y, 0.01), 0.004, InteriorKit.solid(InteriorPalette.SCREEN_BACK))
	kit.annulus(InteriorKit.Batch.SOLID, InteriorKit.at(button_at + Vector3(0, 0, front + 0.004)), radius, rim,
		InteriorKit.solid(InteriorPalette.WALL_LOW))
	kit.commit()
	var colours := {&"go": InteriorPalette.SIGNAL_GO, &"cycling": InteriorPalette.AMBER,
		&"vacuum": InteriorPalette.CORAL}
	for state: StringName in BUTTON_STATES:
		var button_kit := _kit(look, render_layer)
		button_kit.disc(InteriorKit.Batch.GLOW, InteriorKit.at(button_at + Vector3(0, 0, front + 0.012)), radius,
			InteriorKit.lit(colours[state], 2.0))
		var mesh: MeshInstance3D = button_kit.commit()[0]
		mesh.name = "Button_%s" % state
		_buttons[state] = mesh

	if has_screen:
		readout = make_readout(render_layer, 240.0 * size.x / SIZE.x)
		readout.position = Vector3(0, 0.2 * size.y, front + 0.012)
		look.add_child(readout)
	set_readout(PackedStringArray(), &"go")

## A readout in the airlock panels' look (style guide §2.8): a few capitalised
## words in LIGHT_WARM, unshaded, on whatever screen black it is put in front
## of. For a screen that stands apart from its button.
static func make_readout(render_layer: int, width := 240.0) -> Label3D:
	var label := Label3D.new()
	label.name = "Readout"
	label.pixel_size = 0.0011
	label.font_size = 26
	label.outline_size = 0
	label.modulate = InteriorPalette.LIGHT_WARM
	label.shaded = false
	label.layers = render_layer
	label.width = width
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

func prompt_text() -> String:
	return prompt_source.call() if prompt_source.is_valid() else ""

## Offered only while pressing it would do something.
func can_interact(_actor: Node) -> bool:
	return prompt_text() != ""

func interact(_actor: Node) -> void:
	pressed.emit(role)

## Shows `lines` on the readout, if there is one, and the button lit as
## `state` (&"go", &"cycling" or &"vacuum"); any other state lights none.
func set_readout(lines: PackedStringArray, state: StringName) -> void:
	if readout != null:
		readout.text = "\n".join(lines)
	for key: StringName in _buttons:
		_buttons[key].visible = key == state

func readout_text() -> String:
	return readout.text if readout != null else ""

func button_state() -> StringName:
	for key: StringName in BUTTON_STATES:
		if _buttons[key].visible:
			return key
	return &""

static func _kit(root: Node3D, render_layer: int) -> InteriorKit:
	var kit := InteriorKit.new(root)
	kit.layer = render_layer
	kit.light_mask = render_layer
	return kit
