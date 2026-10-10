class_name Seat
extends StaticBody3D

## Anything you sit in (ship bridge spec §3.2): its eye, where you stand up
## to, the prompt, and the hand-off to the camera director. Only a seat that
## flies (PilotSeat) takes the ship's controls; the others are for looking
## round from, and for a job one day (SeatJob).

## Where you stand up to, in the seat's frame (its fixture frame: origin on
## the floor under it, -z the way it faces), best first: a step straight back
## out of the chair, clear of its backrest; back to either side; beside it; a
## longer step back.
const STAND_SPOTS: Array[Vector3] = [
	Vector3(0, 0, 1.3), Vector3(0.75, 0, 1.3), Vector3(-0.75, 0, 1.3),
	Vector3(1.1, 0, 0.3), Vector3(-1.1, 0, 0.3), Vector3(0, 0, 1.9),
]
## The box you look at to sit, in the seat's frame.
const BOX_SIZE := Vector3(1.0, 1.4, 1.0)
const BOX_AT := Vector3(0, 0.7, 0.2)

var flies := false
## The seat's block, so a save can find it again.
var cell := Vector3i.ZERO
## What the seat is for, or null (spec §3.3).
var job: SeatJob
## The game's one camera director, handed over by the flight scene, or found
## by its group when a ship builds the seat later.
var director: CameraDirector
## Where the seated camera ends up, and which way it faces.
var eye: Node3D

func _ready() -> void:
	add_to_group("interactable")
	if eye == null:
		eye = get_node_or_null("Eye")

func prompt_text() -> String:
	return "Sit down"

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

func interact(_avatar: Avatar) -> void:
	var d := director
	if d == null and is_inside_tree():
		d = get_tree().get_first_node_in_group(CameraDirector.GROUP) as CameraDirector
	if d != null:
		d.sit(self)

## Someone sat down here (the director calls it).
func sat(avatar: Avatar) -> void:
	if job != null:
		job.sat(avatar)

## Someone stood up from here.
func stood(avatar: Avatar) -> void:
	if job != null:
		job.stood(avatar)

## A seat of `script` at `frame` for block `coord`, as a ship builds one: its
## box on the interactable layer (2) and its eye at InteriorProps.SEATED_EYE.
static func build(script: GDScript, frame: Transform3D, coord: Vector3i) -> Seat:
	var s: Seat = script.new()
	s.name = "Seat_%d_%d_%d" % [coord.x, coord.y, coord.z]
	s.transform = frame
	s.cell = coord
	s.collision_layer = 2
	s.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BOX_SIZE
	shape.shape = box
	shape.position = BOX_AT
	s.add_child(shape)
	var e := Node3D.new()
	e.name = "Eye"
	e.position = InteriorProps.SEATED_EYE
	s.add_child(e)
	s.eye = e
	return s
