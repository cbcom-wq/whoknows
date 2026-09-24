class_name BlockDefinition
extends Resource

## Describes one *kind* of block. One .tres per type in res://data/blocks/.

enum Category { STRUCTURE, SYSTEMS, INTERIOR }
enum Occupancy {
	SOLID,   ## machinery and armour; fills the cell; not walkable
	DECK,    ## open volume with a floor; walkable
	MOUNT,   ## a fixture occupying its own cell; walkable
}

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.STRUCTURE
@export var occupancy: Occupancy = Occupancy.SOLID

@export_group("Physical")
@export var mass_t: float = 1.0        ## tonnes
@export var hp: int = 100

@export_group("Power")
@export var power_gen: float = 0.0     ## MW
@export var power_draw: float = 0.0    ## MW

@export_group("Propulsion")
@export var thrust_kn: float = 0.0     ## kN, acting along block-local -Z
## Where the exhaust leaves the block, block-local, and the nozzle's radius
## there. A block with a nozzle draws a flame from it along +Z, the opposite
## way to its thrust, sized by how hard it fires (ThrusterFlame). Zero radius
## means no flame: the RCS boxes have no nozzle to draw one from.
@export var nozzle_position: Vector3 = Vector3.ZERO
@export var nozzle_radius: float = 0.0     ## m

@export_group("Habitation")
## Radius in metres over which Grav Plating confers gravity on walkable cells.
@export var grav_radius: float = 0.0

@export_group("Presentation")
@export var mesh: Mesh
@export var icon: Texture2D

func is_walkable() -> bool:
	return occupancy == Occupancy.DECK or occupancy == Occupancy.MOUNT
