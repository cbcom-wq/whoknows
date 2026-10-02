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
## A change of felt shove bigger than this in one tick, m/s^2, is a shake.
const SHAKE_AT := 3.0
## Head lurch per m/s^2 of shove over the cap, metres; at most JOLT_MAX.
const JOLT_PER_ACCEL := 0.0015
const JOLT_MAX := 0.06
const JOLT_DECAY := 8.0

@export var hull_path: NodePath
## The ship's Interior: you are shoved only while you stand in it (many ships
## spec §3.2).
@export var interior_path: NodePath
## The InteriorBuilder whose FeltGravity loose items feel (hands-and-items
## spec §6). Optional: with none, only the avatar is shoved.
@export var interior_builder_path: NodePath

var _last_velocity: Vector3 = Vector3.ZERO
var _shake_phase: float = 0.0
var _last_shove := Vector3.ZERO
## Where a crash has thrown the head, dying away.
var jolt := Vector3.ZERO
var _avatar: Avatar

## The plating gravity loose items feel when no one is about to read it from:
## the avatar's own default grav_strength.
const PLATING_GRAVITY := 9.8

@onready var _hull: RigidBody3D = get_node(hull_path)
@onready var _interior: Node3D = get_node_or_null(interior_path) if not interior_path.is_empty() else null
@onready var _builder: InteriorBuilder = (
	get_node_or_null(interior_builder_path) if not interior_builder_path.is_empty() else null)

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	# At warp (docs/superpowers/specs/2026-09-28-warp-design.md §5.2) nothing
	# is felt aboard: the frozen hull's velocity is only its placing, origin
	# shifts included. The warp's own velocity is kept, so the drop-out, at
	# the same 120 m/s, is no jolt either.
	var warp := _warp()
	if warp != null and warp.travelling():
		_last_velocity = warp.velocity()
		_last_shove = Vector3.ZERO
		drive_felt_gravity(Vector3.ZERO)
		if _you_aboard():
			_you().external_accel = Vector3.ZERO
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
	# (airlock spec §7.4). Nor is someone in another ship.
	if _you_aboard():
		_you().external_accel = shove
		_apply_shake(accel_local, delta)

## You, wherever you are: a ship's scene holds no path to you, so you are found
## by group, as the airlock finds you.
func _you() -> Avatar:
	if not is_instance_valid(_avatar) and is_inside_tree():
		_avatar = get_tree().get_first_node_in_group(Avatar.GROUP) as Avatar
	return _avatar

## True while you stand in this ship's interior: only then are you shoved.
func _you_aboard() -> bool:
	var you := _you()
	return you != null and you.mode == Avatar.Mode.PLATING \
		and (_interior == null or you.get_parent() == _interior)

## The ship's warp drive, when this couples a ship's hull.
func _warp() -> WarpDrive:
	var ship := get_parent() as Ship
	return ship.warp if ship != null else null

## The shove you actually feel: capped.
static func felt(shove: Vector3) -> Vector3:
	return shove.limit_length(SHOVE_CAP)

func _apply_shake(accel_local: Vector3, delta: float) -> void:
	_shake_phase += delta * shake_frequency
	# The rumble is capped with the shove; a crash is the jolt's job.
	var magnitude := minf(accel_local.length(), SHOVE_CAP / shove_scale) * shake_scale
	# Deliberately cheap: a single axis wobble reads as engine rumble.
	var sway := sin(_shake_phase) * magnitude * 0.01 if magnitude >= 0.001 else 0.0
	_you().head.position.x = sway + jolt.x
	_you().head.position.z = jolt.z

## Sets the interior's felt gravity to exactly what the avatar integrates
## (Avatar._physics_process): plating gravity plus the shove, so you and a
## loose crate beside you feel the same thing.
func drive_felt_gravity(shove: Vector3) -> void:
	if _builder == null or _builder.felt_gravity == null:
		return
	var you := _you()
	var g := you.grav_strength if you != null else PLATING_GRAVITY
	_builder.felt_gravity.set_felt(Vector3.DOWN * g + shove)
	# A sudden change -- a burn starting, a hull strike -- is a shake the whole
	# interior feels (NPC foundation spec §6.1).
	if (shove - _last_shove).length() > SHAKE_AT:
		StimulusBus.send(_builder.felt_gravity, Stimulus.make(Stimulus.SHAKE, Vector3.ZERO,
			clampf(shove.length() / SHOVE_CAP, 0.3, 1.0), 0.0, _builder), 0.3)
	_last_shove = shove
