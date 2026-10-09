class_name InteriorSlots
extends RefCounted

## One pool of interior slots for ships and bases (docs/superpowers/specs/
## 2026-09-26-habitat-modules-design.md §9.3). Interiors stand
## Ship.SLOT_SPACING apart on x: slot 15 is 30 km out, where a float still
## holds about 2 mm, so there are MAX of them. Slot 0 is the starter's.

const MAX := 16

var _held := {}   # int -> true

## The lowest free slot, now held; -1 when every slot is held.
func claim() -> int:
	for slot in MAX:
		if not _held.has(slot):
			_held[slot] = true
			return slot
	return -1

## Holds `slot` itself (the starter's 0). False if it is out of range or held.
func take(slot: int) -> bool:
	if slot < 0 or slot >= MAX or _held.has(slot):
		return false
	_held[slot] = true
	return true

func release(slot: int) -> void:
	_held.erase(slot)

func is_held(slot: int) -> bool:
	return _held.has(slot)

func free_count() -> int:
	return MAX - _held.size()
