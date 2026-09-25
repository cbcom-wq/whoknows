class_name PilotSeat
extends StaticBody3D

## The flight station. Sitting here hands ship control to the pilot and
## moves the camera into the cockpit without a cut.

## Where you stand up to, in the seat's frame (the chair's fixture frame:
## origin on the floor under the seat, -z the way it faces), best first: a
## step straight back out of the chair, clear of its backrest; back to either
## side; beside it; a longer step back.
const STAND_SPOTS: Array[Vector3] = [
	Vector3(0, 0, 1.3), Vector3(0.75, 0, 1.3), Vector3(-0.75, 0, 1.3),
	Vector3(1.1, 0, 0.3), Vector3(-1.1, 0, 0.3), Vector3(0, 0, 1.9),
]

@export var camera_director_path: NodePath

## Where the seated camera ends up, and which way it faces.
@onready var eye: Node3D = $Eye

func _ready() -> void:
	add_to_group("interactable")

func prompt_text() -> String:
	return "Take the controls"

## Where `avatar` gets up to: the first of STAND_SPOTS it fits at, facing the
## way the seat does -- or, with none clear, where it stands now, the spot it
## sat down from, so it is never left wedged against the chair or the glass.
func stand_spot(avatar: Avatar) -> Transform3D:
	var facing := global_basis.orthonormalized()
	for spot in STAND_SPOTS:
		var pose := Transform3D(facing, to_global(spot))
		if avatar.can_stand_at(pose):
			return pose
	return avatar.global_transform

func interact(avatar: Avatar) -> void:
	var director: CameraDirector = get_node(camera_director_path)
	director.sit(self)
	# `avatar` is unused here; the director owns the handoff. Kept in the
	# signature because every interactable receives it.
