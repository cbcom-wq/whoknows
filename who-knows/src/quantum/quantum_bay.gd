class_name QuantumBay
extends StowPoint

## The quantum machine's bay (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §6.3, §7.1): a stow point, so Grasp's
## stow-on-drop feeds it like any other, where the item floats at the bay's
## centre rather than sitting on its base.
##
## A stub for now: it takes any item, one at a time. Task 6 gives it its
## rules -- a value, the largest side at most 0.55 m, under the 40 kg lift
## limit -- and turns what it holds.
##
## Knows nothing about ships. Its origin is the recess's centre, where the
## item's centre goes, with the machine's axes.

const ACCEPTS := &"any"

func _init() -> void:
	super()
	accepts = ACCEPTS

func fits(candidate: Item) -> bool:
	return is_free() and candidate != null

## Floating at the centre, whatever its size.
func item_transform(_candidate: Item) -> Transform3D:
	return global_transform
