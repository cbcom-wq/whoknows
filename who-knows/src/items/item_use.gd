class_name ItemUse
extends Node

## What an item does when its holder uses it (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.4). An Item instantiates its
## definition's `use` script as a child named "Use". This base does nothing;
## PlasmaEmitter is the first real one.

## `aim` is the holder's eye: origin at the eye, -z along the view. `world` is
## where anything the use spawns goes. `holder` is left out of anything the use
## casts. Returns true when the use happened.
func use(_item: Item, _aim: Transform3D, _world: Node3D, _holder: CollisionObject3D) -> bool:
	return false
