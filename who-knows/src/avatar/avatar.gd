class_name Avatar
extends CharacterBody3D

## Walks in interior space. Interior geometry never moves, so this is an
## ordinary character controller. All felt motion from the ship arrives
## through `external_accel`, written by MotionCoupling (Task 6).

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const ACCEL := 30.0
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := deg_to_rad(89.0)
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0

## Local gravity, supplied by Grav Plating. Zero means the cell is unplated.
var grav_strength: float = 9.8

## Acceleration felt from the hull, in interior-space metres per second squared.
var external_accel: Vector3 = Vector3.ZERO

var _control_enabled: bool = true
var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var head: Node3D = $Head
@onready var _collider: CollisionShape3D = $Collider

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not _control_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		rotation.y = _yaw
		head.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	# Gravity plus whatever the hull is doing to us. Both are just
	# accelerations; the avatar cannot tell them apart, which is the point.
	velocity += (Vector3.DOWN * grav_strength + external_accel) * delta

	if _control_enabled:
		var crouching := Input.is_action_pressed("crouch")
		_apply_height(CROUCH_HEIGHT if crouching else STAND_HEIGHT)

		var speed := CROUCH_SPEED if crouching else (
			SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
		)
		var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var wish := (transform.basis * Vector3(input_2d.x, 0.0, input_2d.y)).normalized()
		var target := wish * speed
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	move_and_slide()

func _apply_height(height: float) -> void:
	var capsule := _collider.shape as CapsuleShape3D
	capsule.height = height
	_collider.position.y = height * 0.5
	head.position.y = height - 0.2
