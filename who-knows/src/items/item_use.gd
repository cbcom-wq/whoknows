class_name ItemUse
extends Node3D

## What an item does when its holder uses it (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.4). An Item instantiates its
## definition's `use` script as a child named "Use", at the item's origin, so
## anything it builds -- a lamp's beam, a flare's light, a datapad's screen --
## moves with the item. This base does nothing.

## `aim` is the holder's eye: origin at the eye, -z along the view. `world` is
## where anything the use spawns goes. `holder` is left out of anything the use
## casts. Returns true when the use happened.
func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
	return false

## Held down (health and damage spec §8.3): called every physics tick while
## `use` is held, after use() on the press. Returns true while it is doing
## something. This base does nothing, so a press-only item needs nothing.
func hold(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D, _delta: float) -> bool:
	return false

## What the item says about what it is aimed at while held, for the prompt,
## or "" (the torch: what it would mend, and its feed).
func aim_text(_item: Item, _aim: Transform3D, _holder: CollisionObject3D) -> String:
	return ""

## Why a save must wait while it is in use, or "" (saving spec §5).
func busy() -> String:
	return ""

## A word the prompt shows after the item's name -- "on", "burning" -- or "".
func status() -> String:
	return ""

## What a save keeps of this use (saving spec §6.5), or {}.
func save() -> Dictionary:
	return {}

## Takes back what save() gave, before or after entering the tree.
func restore(_state: Dictionary) -> void:
	pass

## How hard using it kicks the hand back, 0 to 1. Only a gun kicks.
func recoil() -> float:
	return 0.0
