class_name PilotControls
extends Node

## The pilot's hands on the ship (docs/superpowers/specs/
## 2026-09-25-flight-controls-design.md §4, §7): the virtual stick and the
## arrow keys, point mode and the heading click, the speed lock and the assist
## toggle, turned into FlightComputer calls. While you sit it is the HUD's
## vehicle: its telemetry is the flight computer's, plus the stick and the
## pointer.

@export var flight_computer_path: NodePath
@export var camera_director_path: NodePath
@export var hull_path: NodePath
@export var interior_path: NodePath

var stick := PilotStick.new()
var seated := false
## Point mode (spec §4.2): the mouse moves a free pointer instead of the stick.
var pointing := false
## The pointer's offset from the centre of view, in fractions of the
## viewport's height, +y down.
var pointer := Vector2.ZERO

@onready var _flight: FlightComputer = get_node(flight_computer_path)
@onready var _hull: Node3D = get_node(hull_path)
@onready var _interior: Node3D = get_node(interior_path)

func _ready() -> void:
	var director: CameraDirector = get_node(camera_director_path)
	director.piloting_changed.connect(set_seated)

## Sitting down or standing up: the stick centres and point mode ends. A
## heading hold or a speed lock keeps running (spec §4.2).
func set_seated(on: bool) -> void:
	seated = on
	stick.centre()
	pointing = false
	pointer = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		handle(event)

## One input event, while seated. Split from _unhandled_input so tests can
## drive it: a headless run cannot capture the mouse.
func handle(event: InputEvent) -> void:
	if not seated:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var view := _view_size()
		if view.y <= 0.0:
			return
		if pointing:
			var half := Vector2(view.x / view.y * 0.5, 0.5)
			pointer = (pointer + motion.relative / view.y).clamp(-half, half)
		else:
			stick.move(motion.relative, view.y)
	elif event.is_action_pressed(&"point_mode"):
		pointing = true
		pointer = Vector2.ZERO
		stick.centre()
	elif event.is_action_released(&"point_mode"):
		# Back to the stick, centred, so the ship does not lurch.
		pointing = false
		stick.centre()
	elif event.is_action_pressed(&"set_heading"):
		if pointing:
			_flight.set_heading(pointer_direction())
	elif event.is_action_pressed(&"speed_lock"):
		_flight.toggle_speed_lock()
	elif event.is_action_pressed(&"toggle_assist"):
		_flight.assist_enabled = not _flight.assist_enabled

func _process(_delta: float) -> void:
	if not seated:
		return
	var keys := Vector2(
		Input.get_axis(&"pitch_down", &"pitch_up"),
		Input.get_axis(&"yaw_right", &"yaw_left"),
	)
	# Flying by hand takes the ship back from a heading hold (spec §4.2). Roll
	# does not: it turns about the nose and leaves the heading alone.
	if not stick.is_centred() or not keys.is_zero_approx():
		_flight.clear_heading()
	var steer := (stick.command() + keys).clamp(-Vector2.ONE, Vector2.ONE)
	var translate := Vector3(
		Input.get_axis(&"move_left", &"move_right"),
		Input.get_axis(&"crouch", &"sprint"),
		Input.get_axis(&"move_forward", &"move_back"),
	)
	var rotate := Vector3(steer.x, steer.y, Input.get_axis(&"roll_left", &"roll_right"))
	_flight.set_pilot_input(translate, rotate, Input.is_action_pressed(&"boost"))

## The world direction under the pointer (spec §4.2), seen through `cam`, or
## the camera you see through. Aboard, that camera is in interior space, which
## never moves and maps one to one onto the hull's axes. The canopy is a portal
## drawn from the same place with the same field of view, so the pointer lies
## over the same point outside.
func pointer_direction(cam: Camera3D = null) -> Vector3:
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return _hull.global_basis * Vector3.FORWARD
	var view := cam.get_viewport().get_visible_rect().size
	var ray := cam.project_ray_normal(view * 0.5 + pointer * view.y)
	if _interior.is_ancestor_of(cam):
		ray = _hull.global_basis * (_interior.global_basis.inverse() * ray)
	return ray.normalized()

## The flight computer's snapshot plus the pilot's hands, for the HUD.
func build_telemetry() -> VehicleTelemetry:
	var t := _flight.build_telemetry()
	t.stick = stick.offset
	t.stick_radius = PilotStick.RADIUS
	t.stick_deadzone = PilotStick.DEADZONE
	t.pointing = pointing
	t.pointer = pointer
	return t

func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size
