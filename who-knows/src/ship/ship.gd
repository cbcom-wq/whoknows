class_name Ship
extends Node3D

## Owns one ship's two representations. In Slice 1 the geometry under
## each is hand-authored; from Task 15 both are generated from a ShipGrid.

const SLOT_SPACING := 2000.0
const INTERIOR_WORLD_BASE := Vector3(0.0, -5000.0, 0.0)

@export var interior_slot: int = 0

@onready var exterior: RigidBody3D = $Exterior
@onready var interior: Node3D = $Interior

func _ready() -> void:
	exterior.gravity_scale = 0.0
	exterior.linear_damp = 0.0
	exterior.angular_damp = 0.0
	exterior.can_sleep = false
	exterior.collision_layer = 1
	exterior.collision_mask = 1
	interior.global_position = interior_slot_origin()

func interior_slot_origin() -> Vector3:
	# Interior space sits well clear of the combat arena so the walkable
	# interior can never intersect a flying hull. Collision layers enforce
	# the same separation independently.
	return INTERIOR_WORLD_BASE + Vector3(interior_slot * SLOT_SPACING, 0.0, 0.0)
