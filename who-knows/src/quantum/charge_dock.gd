class_name ChargeDock
extends Area3D

## The quantum machine's charge plate (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §6.3, §7.3): a round hand plate the
## Interactor finds like any interactable, lit QUANTUM when it is ready.
## Pressing it says who pressed it and nothing more, and it offers itself only
## to someone within REACH, while its prompt source has something to say.
## Whoever owns it -- the ship's QuantumPlant -- charges that actor's suit
## while they stay within REACH, and shows the charge on it with set_readout.
##
## Knows nothing about ships, like ReadoutPanel. Its frame: origin at the
## plate's centre on the surface it is mounted on, +z out of that surface.

signal pressed(actor: Node)

## How far from the plate you may stand and still charge (spec §7.3), metres
## from your head.
const REACH := 1.2
## The glow swelling over the plate while a charge runs.
const FILL_ENERGY := 2.2

## Returns the prompt, or "" when pressing would do nothing.
var prompt_source: Callable

var _lit: MeshInstance3D
var _dark: MeshInstance3D
var _fill: MeshInstance3D
var _percent := -1

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
	var fill_kit := _kit(render_layer)
	fill_kit.disc(InteriorKit.Batch.GLOW, InteriorKit.at(Vector3(0, 0, 0.016)), radius,
		InteriorKit.lit(InteriorPalette.QUANTUM, FILL_ENERGY))
	_fill = fill_kit.commit()[0]
	_fill.name = "PlateFill"
	set_lit(true)
	set_readout(-1)

## Lit QUANTUM when it is ready to charge; dark QUANTUM_DEEP when not.
func set_lit(on: bool) -> void:
	_lit.visible = on
	_dark.visible = not on

func is_lit() -> bool:
	return _lit.visible

## Shows a charge running with the suit `percent` full (0-100): a brighter
## disc swelling from the plate's centre to its rim as the suit fills. -1
## shows none. By scale, so no material is touched.
func set_readout(percent: int) -> void:
	_percent = percent
	_fill.visible = percent > 0
	var k := clampf(percent / 100.0, 0.001, 1.0)
	_fill.scale = Vector3(k, k, 1.0)

## The charge shown, or -1 for none.
func readout_percent() -> int:
	return _percent

## True while `actor` is within REACH of the plate, measured from its head
## where it has one (the avatar's), else from its origin.
func within_reach(actor: Node3D) -> bool:
	var head := actor.get(&"head") as Node3D
	var from := head.global_position if head != null else actor.global_position
	return from.distance_to(global_position) <= REACH

func prompt_text() -> String:
	return prompt_source.call() if prompt_source.is_valid() else ""

## Offered only to someone within REACH, and only while pressing it would do
## something. The Interactor's ray reaches further than the plate does, so
## from beyond REACH it passes the plate over: F is never offered where it
## would start a charge that ends at once.
func can_interact(actor: Node) -> bool:
	return actor is Node3D and within_reach(actor) and prompt_text() != ""

## Says who pressed it -- if it is offered to them.
func interact(actor: Node) -> void:
	if can_interact(actor):
		pressed.emit(actor)

func _kit(render_layer: int) -> InteriorKit:
	var kit := InteriorKit.new(self)
	kit.layer = render_layer
	kit.light_mask = render_layer
	return kit
