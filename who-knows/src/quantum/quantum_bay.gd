class_name QuantumBay
extends StowPoint

## The quantum machine's bay (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §6.3, §7.1): a stow point, so Grasp's
## stow-on-drop feeds it like any other, where the item floats at the bay's
## centre rather than sitting on its base, turning slowly.
##
## It takes one item at a time, of any stow class, that the machine can
## convert: one with a value (never an EVA tool, spec §4.3), whose largest
## side is at most MAX_SIDE, and that one person can lift (a crate or a
## toolbox fits). Until converted, the item is simply stowed; its own prompt
## takes it back out.
##
## Knows nothing about ships. Its origin is the recess's centre, where the
## item's centre goes, with the machine's axes.

const ACCEPTS := &"any"
## The largest side an item may have and still go in (spec §7.1).
const MAX_SIDE := 0.55
## How fast whatever floats in the bay turns about its up, degrees a second
## (spec §6.3).
const TURN_RATE := 10.0

## True while the machine is converting or making: the bay takes nothing new
## then, even while it looks empty (the plant sets it).
var busy := false

var _angle := 0.0

func _init() -> void:
	super()
	accepts = ACCEPTS

func fits(candidate: Item) -> bool:
	return not busy and is_free() and candidate != null and takes(candidate.definition)

## Whether an item of this kind may go in the bay at all (spec §7.1): it has
## a value and is no EVA tool, its largest side is at most MAX_SIDE, and it
## is within the lift limit.
static func takes(def: ItemDefinition) -> bool:
	if def == null or def.eva_tool or def.quantum_value <= 0:
		return false
	var size := def.size
	return maxf(size.x, maxf(size.y, size.z)) <= MAX_SIDE + 1e-6 and def.mass_kg <= Item.LIFT_LIMIT_KG

## Floating at the centre, whatever its size, turned as far as the bay has
## turned so far.
func item_transform(_candidate: Item) -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, _angle), Vector3.ZERO)

## Turns what the bay holds on by `delta` seconds at TURN_RATE. The plant
## calls it every physics tick.
func hold_turn(delta: float) -> void:
	_angle = fposmod(_angle + deg_to_rad(TURN_RATE) * delta, TAU)
	if not is_free():
		item.global_transform = item_transform(item)
