class_name Avatar
extends CharacterBody3D

## Walks in interior space. Interior geometry never moves, so this is an
## ordinary character controller. All felt motion from the ship arrives
## through `external_accel`, written by MotionCoupling (Task 6).
##
## Its hands (docs/superpowers/specs/2026-09-23-hands-and-items-design.md §7)
## are a Grasp: take_item and can_take_item are the actor contract every Item
## talks to.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const ACCEL := 30.0
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := deg_to_rad(89.0)
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0
## How hard walking into a loose thing pushes it, at walking pace
## (hands-and-items spec §7.5).
const PUSH_FORCE := 150.0
## interior_geometry | items (project.godot 3d_physics layers 2 and 6).
const COLLISION_MASK := 2 | 32

## Local gravity, supplied by Grav Plating. Zero means the cell is unplated.
var grav_strength: float = 9.8

## Acceleration felt from the hull, in interior-space metres per second squared.
var external_accel: Vector3 = Vector3.ZERO

## What is in your hands.
var grasp: Grasp
## The ray that finds interactables, when the scene gives the head one.
var interactor: Interactor

var _control_enabled: bool = true
var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var _collider: CollisionShape3D = $Collider

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	collision_mask = COLLISION_MASK
	interactor = get_node_or_null("Head/Interactor") as Interactor
	grasp = Grasp.new()
	grasp.name = "Grasp"
	add_child(grasp)
	grasp.bind(self, head)

## The actor contract Item talks to.
func take_item(item: Item) -> void:
	grasp.take(item)

func can_take_item(item: Item) -> bool:
	return grasp.can_take(item)

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	grasp.set_enabled(enabled)
	if not enabled:
		velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capture is released and regained regardless of who currently has
	# control. This node captured the cursor, so it owns letting go of it --
	# and being unable to release it while seated would trap the player.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# The click only brings the mouse back. Nothing else may act on it --
		# it must not also fire whatever is in your hand.
		get_viewport().set_input_as_handled()
		return

	if not _control_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		rotation.y = _yaw
		head.rotation.x = _pitch

func _physics_process(delta: float) -> void:
	if not _control_enabled:
		# Parked — seated, or handed off to something else. Integrate
		# nothing: otherwise the body keeps accumulating gravity and
		# external_accel and slides off the seat while the pilot flies.
		return

	# Gravity plus whatever the hull is doing to us. Both are just
	# accelerations; the avatar cannot tell them apart, which is the point.
	velocity += (Vector3.DOWN * grav_strength + external_accel) * delta

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

	var pushing := velocity
	move_and_slide()
	_push_loose_things(pushing, delta)

## Nudges the loose things you walk into (hands-and-items spec §7.5), instead
## of stopping dead against them as if they were walls.
func _push_loose_things(pushing: Vector3, delta: float) -> void:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody3D
		if body == null or body.freeze:
			continue
		var into := -hit.get_normal()
		into.y = 0.0
		if into.length_squared() < 0.0001:
			continue
		into = into.normalized()
		var speed := pushing.dot(into)
		if speed <= 0.0:
			continue
		var force := PUSH_FORCE * clampf(speed / WALK_SPEED, 0.0, 1.0)
		body.apply_impulse(into * force * delta, hit.get_position() - body.global_position)

func _apply_height(height: float) -> void:
	var capsule := _collider.shape as CapsuleShape3D
	capsule.height = height
	_collider.position.y = height * 0.5
	head.position.y = height - 0.2
