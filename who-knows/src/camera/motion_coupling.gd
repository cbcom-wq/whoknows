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

## The hardest shove you feel, m/s^2: well over a full burn (about 5.7 felt),
## so flying is untouched, but a crash cannot fling you across the room
## (asteroids spec §7.5). The rest becomes a jolt of the head.
const SHOVE_CAP := 12.0
## Head lurch per m/s^2 of shove over the cap, metres; at most JOLT_MAX.
const JOLT_PER_ACCEL := 0.0015
const JOLT_MAX := 0.06
const JOLT_DECAY := 8.0

@export var hull_path: NodePath
@export var avatar_path: NodePath
## The InteriorBuilder whose FeltGravity loose items feel (hands-and-items
## spec §6). Optional: with none, only the avatar is shoved.
@export var interior_builder_path: NodePath

var _last_velocity: Vector3 = Vector3.ZERO
var _shake_phase: float = 0.0
## Where a crash has thrown the head, dying away.
var jolt := Vector3.ZERO

@onready var _hull: RigidBody3D = get_node(hull_path)
@onready var _avatar: Avatar = get_node(avatar_path)
@onready var _builder: InteriorBuilder = (
	get_node_or_null(interior_builder_path) if not interior_builder_path.is_empty() else null)

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
	var shove := -accel_local * shove_scale
	var over := shove.length() - SHOVE_CAP
	if over > 0.0:
		var lurch := shove.normalized() * minf(JOLT_MAX, over * JOLT_PER_ACCEL)
		if lurch.length() > jolt.length():
			jolt = lurch
	shove = felt(shove)
	jolt *= exp(-JOLT_DECAY * delta)
	drive_felt_gravity(shove)
	# A spacewalker is not aboard: the hull's motion is only the ship's
	# (airlock spec §7.4).
	if _avatar.mode == Avatar.Mode.PLATING:
		_avatar.external_accel = shove
		_apply_shake(accel_local, delta)

## The shove you actually feel: capped.
static func felt(shove: Vector3) -> Vector3:
	return shove.limit_length(SHOVE_CAP)

func _apply_shake(accel_local: Vector3, delta: float) -> void:
	_shake_phase += delta * shake_frequency
	# The rumble is capped with the shove; a crash is the jolt's job.
	var magnitude := minf(accel_local.length(), SHOVE_CAP / shove_scale) * shake_scale
	# Deliberately cheap: a single axis wobble reads as engine rumble.
	var sway := sin(_shake_phase) * magnitude * 0.01 if magnitude >= 0.001 else 0.0
	_avatar.head.position.x = sway + jolt.x
	_avatar.head.position.z = jolt.z

## Sets the interior's felt gravity to exactly what the avatar integrates
## (Avatar._physics_process): plating gravity plus the shove, so you and a
## loose crate beside you feel the same thing.
func drive_felt_gravity(shove: Vector3) -> void:
	if _builder == null or _builder.felt_gravity == null:
		return
	_builder.felt_gravity.set_felt(Vector3.DOWN * _avatar.grav_strength + shove)
