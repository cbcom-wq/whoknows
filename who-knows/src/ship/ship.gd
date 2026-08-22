class_name Ship
extends Node3D

## Owns one ship's two representations. In Slice 1 the geometry under
## each is hand-authored; from Task 15 both are generated from a ShipGrid.

const SLOT_SPACING := 10000.0

@export var interior_slot: int = 0

@onready var exterior: RigidBody3D = $Exterior
@onready var interior: Node3D = $Interior

func _ready() -> void:
	exterior.gravity_scale = 0.0
	exterior.linear_damp = 0.0
	exterior.angular_damp = 0.0
	exterior.can_sleep = false
	interior.global_position = interior_slot_origin()

func interior_slot_origin() -> Vector3:
	return Vector3(interior_slot * SLOT_SPACING, 0.0, 0.0)
