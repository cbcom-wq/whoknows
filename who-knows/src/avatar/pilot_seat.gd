class_name PilotSeat
extends StaticBody3D

## The flight station. Sitting here hands ship control to the pilot and
## moves the camera into the cockpit without a cut.

@export var camera_director_path: NodePath

## Where the seated camera ends up, and which way it faces.
@onready var eye: Node3D = $Eye

func _ready() -> void:
	add_to_group("interactable")

func prompt_text() -> String:
	return "Take the controls"

func interact(avatar: Avatar) -> void:
	var director: CameraDirector = get_node(camera_director_path)
	director.sit(self)
	# `avatar` is unused here; the director owns the handoff. Kept in the
	# signature because every interactable receives it.
