class_name ItemDefinition
extends Resource

## Describes one *kind* of item (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.1). One .tres per kind in
## res://data/items/.
##
## Item-local frame: origin at the collider's centre, +y up, -z forward (a
## muzzle points along -z).

enum Grip {
	WIELD,  ## held in the right hand, tracking the aim exactly
	CARRY,  ## held out front in both hands by a force-limited physics hold
}

@export var id: StringName
@export var display_name: String = ""
@export var mass_kg: float = 1.0
## The one box collider. The look is built to fit inside it.
@export var size: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var grip: Grip = Grip.CARRY
## Which stow points accept it (StowPoint.accepts).
@export var stow_class: StringName = &"small"
## The ItemLooks builder that draws it.
@export var look: StringName
## What using it does: a script extending ItemUse, or null.
@export var use: Script
## WIELD: the item-local point the palm closes on.
@export var grip_point: Vector3 = Vector3.ZERO
## The item-local point a use comes out of: the pistol's muzzle.
@export var use_point: Vector3 = Vector3.ZERO
## How the item is turned in the hands, in degrees about x, y and z: a
## one-handed item pivots on its grip point, a two-handed one on its centre.
## The datapad is tilted toward you, the flare held up like a torch; zero holds
## an item as it lies.
@export var hold_rotation: Vector3 = Vector3.ZERO
## What this kind is worth in quantum energy (quantum energy spec §4.2), set
## by hand on each item .tres following the rule of thumb in §4.1. 0 means
## the item has no value yet (a hand-built test definition; every catalogue
## item on disk has one).
@export var quantum_value: int = 0
## An EVA tool (the hose nozzle, spec §11): never converted or made, however
## it fills quantum_value (spec §4.2's table).
@export var eva_tool: bool = false
