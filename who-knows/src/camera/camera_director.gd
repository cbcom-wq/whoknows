class_name CameraDirector
extends Node

## Owns all four views and, critically, the continuous move between
## standing and sitting. The transition happens entirely inside interior
## space, so it is a plain interpolation of one camera's transform —
## there is no world switch and therefore nothing to hide with a fade.

signal transition_finished

enum View { COCKPIT, CHASE, FOOT_FIRST, FOOT_THIRD }

const SIT_DURATION := 0.75
const THIRD_PERSON_OFFSET := Vector3(0.5, 0.4, 2.5)

@export var avatar_path: NodePath
@export var flight_computer_path: NodePath
@export var interior_camera_path: NodePath
@export var chase_camera_path: NodePath

var view: View = View.FOOT_FIRST
var is_seated: bool = false

var _seat: PilotSeat = null
var _tween: Tween = null

@onready var _avatar: Avatar = get_node(avatar_path)
@onready var _flight: FlightComputer = get_node(flight_computer_path)
@onready var _interior_cam: Camera3D = get_node(interior_camera_path)
@onready var _chase_cam: Camera3D = get_node(chase_camera_path)

func _ready() -> void:
	_apply_view()

func sit(seat: PilotSeat) -> void:
	if is_seated or _tween != null:
		return
	_seat = seat
	is_seated = true
	_avatar.set_control_enabled(false)
	_move_camera_to(seat.eye.global_transform)

func stand() -> void:
	if not is_seated or _tween != null:
		return
	is_seated = false
	_flight.clear_pilot_input()
	# Put the avatar beside the seat, then fly the camera back to its head.
	_avatar.global_position = _seat.global_position + _seat.global_basis * Vector3(0.9, 0, 0)
	_move_camera_to(_avatar.head.global_transform)

func _move_camera_to(target: Transform3D) -> void:
	# Reparent the interior camera to the interior root so it can travel
	# freely between the avatar's head and the seat without inheriting
	# either one's motion mid-flight.
	var interior_root := _avatar.get_parent()
	var start := _interior_cam.global_transform
	if _interior_cam.get_parent() != interior_root:
		_interior_cam.reparent(interior_root, true)
	_interior_cam.global_transform = start
	_interior_cam.current = true
	_chase_cam.current = false

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_interior_cam, "global_transform", target, SIT_DURATION)
	_tween.finished.connect(_on_transition_finished)

func _on_transition_finished() -> void:
	_tween = null
	if is_seated:
		_interior_cam.reparent(_seat.eye, true)
		_interior_cam.transform = Transform3D.IDENTITY
		view = View.COCKPIT
	else:
		_interior_cam.reparent(_avatar.head, true)
		_interior_cam.transform = Transform3D.IDENTITY
		_avatar.set_control_enabled(true)
		view = View.FOOT_FIRST
	_apply_view()
	transition_finished.emit()

func cycle_view() -> void:
	if _tween != null:
		return
	if is_seated:
		view = View.CHASE if view == View.COCKPIT else View.COCKPIT
	else:
		view = View.FOOT_THIRD if view == View.FOOT_FIRST else View.FOOT_FIRST
	_apply_view()

func _apply_view() -> void:
	match view:
		View.COCKPIT, View.FOOT_FIRST:
			_interior_cam.current = true
			_chase_cam.current = false
			_interior_cam.position = Vector3.ZERO
		View.FOOT_THIRD:
			_interior_cam.current = true
			_chase_cam.current = false
			_interior_cam.position = THIRD_PERSON_OFFSET
		View.CHASE:
			_interior_cam.current = false
			_chase_cam.current = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_camera"):
		cycle_view()
	elif event.is_action_pressed("interact") and is_seated:
		stand()

func _process(_delta: float) -> void:
	if not is_seated:
		return
	var translate := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("crouch", "sprint"),
		Input.get_axis("move_forward", "move_back"),
	)
	var rotate := Vector3(0, 0, Input.get_axis("roll_left", "roll_right"))
	_flight.set_pilot_input(translate, rotate, Input.is_action_pressed("boost"))
	if Input.is_action_just_pressed("toggle_assist"):
		_flight.assist_enabled = not _flight.assist_enabled
