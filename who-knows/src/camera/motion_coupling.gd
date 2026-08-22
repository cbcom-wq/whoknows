class_name MotionCoupling
extends Node

## Pipes the hull's real motion into interior space as felt effects.
##
## The interior never moves, so nothing here is simulated — it is authored.
## That is the entire advantage of the split: these are tuning knobs, not
## physics we have to fight.

## How much of the hull's acceleration the avatar feels, as a fraction.
## 1.0 is physically honest and violently unpleasant. Start at 0.35.
@export var shove_scale: float = 0.35
@export var shake_scale: float = 0.05
@export var shake_frequency: float = 18.0

@export var hull_path: NodePath
@export var avatar_path: NodePath
@export var interior_sky_path: NodePath

var _last_velocity: Vector3 = Vector3.ZERO
var _shake_phase: float = 0.0

@onready var _hull: RigidBody3D = get_node(hull_path)
@onready var _avatar: Avatar = get_node(avatar_path)
@onready var _sky: Node3D = get_node(interior_sky_path)

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	var velocity := _hull.linear_velocity
	var accel_world := (velocity - _last_velocity) / delta
	_last_velocity = velocity

	# Express the hull's acceleration in the hull's own frame, then apply it
	# in the interior's frame. The interior is axis-aligned with the hull by
	# construction, so this is a straight basis change.
	var accel_local := _hull.global_transform.basis.inverse() * accel_world

	# A ship accelerating forward throws you backward. Negate.
	_avatar.external_accel = -accel_local * shove_scale

	_apply_shake(accel_local, delta)
	_sync_sky()

func _apply_shake(accel_local: Vector3, delta: float) -> void:
	_shake_phase += delta * shake_frequency
	var magnitude := accel_local.length() * shake_scale
	if magnitude < 0.001:
		_avatar.head.position.x = 0.0
		return
	# Deliberately cheap: a single axis wobble reads as engine rumble.
	_avatar.head.position.x = sin(_shake_phase) * magnitude * 0.01

func _sync_sky() -> void:
	# The interior's starfield inherits the hull's orientation, so rolling
	# the ship rolls the stars past the windows even though the room is
	# bolted to the floor of the universe.
	_sky.global_basis = _hull.global_transform.basis
