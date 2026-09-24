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

## A word the prompt shows after the item's name -- "on", "burning" -- or "".
func status() -> String:
	return ""

## How hard using it kicks the hand back, 0 to 1. Only a gun kicks.
func recoil() -> float:
	return 0.0
