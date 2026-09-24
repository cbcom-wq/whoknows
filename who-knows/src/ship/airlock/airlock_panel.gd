class_name AirlockPanel
extends Area3D

## An airlock control panel (docs/superpowers/specs/2026-09-24-airlock-design.md
## §3.4): one big lit button and a small readout of live state -- the first
## screen in the game that shows real numbers. The Interactor finds it like any
## interactable; pressing it says which panel was pressed and nothing more.
## Whoever owns the airlock decides what that means, and what the readout and
## the prompt say.
##
## Knows nothing about ships. Its frame: origin at the panel's centre on the
## wall surface, +z out of the wall.

signal pressed(role: StringName)

const SIZE := Vector3(0.34, 0.5, 0.06)
const BUTTON_STATES := [&"go", &"cycling", &"vacuum"]

## &"room", &"inner" (the corridor side) or &"outer" (the hull side).
var role: StringName = &""
## Returns the prompt, or "" when pressing would do nothing.
var prompt_source: Callable

var _label: Label3D
var _buttons: Dictionary = {}   # StringName -> MeshInstance3D

## Builds the panel on physics layer bits `layer_bits` and render layer
## `render_layer`. Call once, before it enters the tree.
func setup(panel_role: StringName, layer_bits: int, render_layer := InteriorKit.LAYER) -> void:
	role = panel_role
	name = "Panel_%s" % panel_role
	collision_layer = layer_bits
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")

	var shape := BoxShape3D.new()
	shape.size = SIZE + Vector3(0, 0, 0.04)
	var hit := CollisionShape3D.new()
	hit.shape = shape
	hit.position = Vector3(0, 0, SIZE.z * 0.5)
	add_child(hit)

	var look := Node3D.new()
	look.name = "Look"
	add_child(look)
	var kit := _kit(look, render_layer)
	var front := SIZE.z
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 0, front * 0.5)), SIZE, 0.025,
		InteriorKit.solid(InteriorPalette.TRIM))
	kit.bevel_box(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, 0.1, front + 0.004)), Vector3(0.28, 0.2, 0.01),
		0.004, InteriorKit.solid(InteriorPalette.SCREEN_BACK))
	kit.annulus(InteriorKit.Batch.SOLID, InteriorKit.at(Vector3(0, -0.12, front + 0.004)), 0.06, 0.085,
		InteriorKit.solid(InteriorPalette.WALL_LOW))
	kit.commit()
	var colours := {&"go": InteriorPalette.SIGNAL_GO, &"cycling": InteriorPalette.AMBER,
		&"vacuum": InteriorPalette.CORAL}
	for state: StringName in BUTTON_STATES:
		var button_kit := _kit(look, render_layer)
		button_kit.disc(InteriorKit.Batch.GLOW, InteriorKit.at(Vector3(0, -0.12, front + 0.012)), 0.06,
			InteriorKit.lit(colours[state], 2.0))
		var mesh: MeshInstance3D = button_kit.commit()[0]
		mesh.name = "Button_%s" % state
		_buttons[state] = mesh

	_label = Label3D.new()
	_label.name = "Readout"
	_label.position = Vector3(0, 0.1, front + 0.012)
	_label.pixel_size = 0.0011
	_label.font_size = 26
	_label.outline_size = 0
	_label.modulate = InteriorPalette.LIGHT_WARM
	_label.shaded = false
	_label.layers = render_layer
	_label.width = 240.0
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	look.add_child(_label)
	set_readout(PackedStringArray(), &"go")

func prompt_text() -> String:
	return prompt_source.call() if prompt_source.is_valid() else ""

func interact(_actor: Node) -> void:
	pressed.emit(role)

## Shows `lines` on the readout and the button lit as `state` (&"go",
## &"cycling" or &"vacuum").
func set_readout(lines: PackedStringArray, state: StringName) -> void:
	_label.text = "\n".join(lines)
	for key: StringName in _buttons:
		_buttons[key].visible = key == state

func readout_text() -> String:
	return _label.text

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
