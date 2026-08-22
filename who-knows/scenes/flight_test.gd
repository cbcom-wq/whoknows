extends Node3D

@onready var _fc: FlightComputer = $Ship/FlightComputer

func _ready() -> void:
	# This temporary driver borrows the same WASD actions the avatar walks
	# with. Without this, W would walk the avatar AND fire the engines.
	# Task 5 replaces the whole arrangement with the pilot seat, which hands
	# control back and forth properly.
	$Ship/Interior/Avatar.set_control_enabled(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_assist"):
		_fc.assist_enabled = not _fc.assist_enabled
		print("Flight assist: ", "ON" if _fc.assist_enabled else "OFF")

func _process(_delta: float) -> void:
	var translate := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("crouch", "sprint"),
		Input.get_axis("move_forward", "move_back"),
	)
	var mouse := Vector2.ZERO  # replaced by real mouse look in Task 5
	var rotate := Vector3(
		mouse.y, mouse.x, Input.get_axis("roll_left", "roll_right")
	)
	_fc.set_pilot_input(translate, rotate, Input.is_action_pressed("boost"))
