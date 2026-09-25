class_name ChargeDock
extends Area3D

## The quantum machine's charge plate (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §6.3, §7.3): a round hand plate the
## Interactor finds like any interactable, lit QUANTUM when it is ready. Its
## body only, for now: pressing it says who pressed it and nothing more, and
## it offers itself only while its prompt source has something to say. Task 7
## charges the suit from it.
##
## Knows nothing about ships, like ReadoutPanel. Its frame: origin at the
## plate's centre on the surface it is mounted on, +z out of that surface.

signal pressed(actor: Node)

## Returns the prompt, or "" when pressing would do nothing.
var prompt_source: Callable

var _lit: MeshInstance3D
var _dark: MeshInstance3D

## Builds a plate `radius` across on physics layer bits `layer_bits` and
## render layer `render_layer`. Call once, before it enters the tree.
func setup(radius: float, layer_bits: int, render_layer := InteriorKit.LAYER) -> void:
	name = "ChargeDock"
	collision_layer = layer_bits
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")

	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 2.0, radius * 2.0, 0.08)
	var hit := CollisionShape3D.new()
	hit.shape = shape
	hit.position = Vector3(0, 0, 0.02)
	add_child(hit)

	var plate := InteriorKit.at(Vector3(0, 0, 0.012))
	var dark_kit := _kit(render_layer)
	dark_kit.disc(InteriorKit.Batch.SOLID, plate, radius, InteriorKit.solid(InteriorPalette.QUANTUM_DEEP))
	_dark = dark_kit.commit()[0]
	_dark.name = "PlateDark"
	var lit_kit := _kit(render_layer)
	lit_kit.disc(InteriorKit.Batch.GLOW, plate, radius, InteriorKit.lit(InteriorPalette.QUANTUM, 1.1))
	lit_kit.annulus(InteriorKit.Batch.GLOW, plate * InteriorKit.at(Vector3(0, 0, 0.002)), radius * 0.55,
		radius * 0.62, InteriorKit.lit(InteriorPalette.QUANTUM, 1.6))
	_lit = lit_kit.commit()[0]
	_lit.name = "PlateLit"
	set_lit(true)

## Lit QUANTUM when it is ready to charge; dark QUANTUM_DEEP when not.
func set_lit(on: bool) -> void:
	_lit.visible = on
	_dark.visible = not on

func is_lit() -> bool:
	return _lit.visible

func prompt_text() -> String:
	return prompt_source.call() if prompt_source.is_valid() else ""

## Offered only while pressing it would do something.
func can_interact(_actor: Node) -> bool:
	return prompt_text() != ""

func interact(actor: Node) -> void:
	pressed.emit(actor)

func _kit(render_layer: int) -> InteriorKit:
	var kit := InteriorKit.new(self)
	kit.layer = render_layer
	kit.light_mask = render_layer
	return kit
