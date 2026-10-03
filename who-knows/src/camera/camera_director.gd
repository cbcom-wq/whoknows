class_name CameraDirector
extends Node

## Owns all four views and, critically, the continuous move between
## standing and sitting. The transition happens entirely inside interior
## space, so it is a plain interpolation of one camera's transform —
## there is no world switch and therefore nothing to hide with a fade.
##
## Seated flying input -- the stick, the keys, point mode -- is PilotControls'
## (flight controls spec §7); this node only says when you sit and stand.

signal transition_finished

## Emitted when control of the ship is taken or given up. Anything that cares
## about "is the player flying right now" listens here rather than polling
## `is_seated`, so the moment is defined in exactly one place.
signal piloting_changed(piloting: bool)

## Emitted when the view changes, and when a sit or stand camera move starts
## (`moving` true) -- the hands and the reticle hide for the move.
signal view_changed(view: View, moving: bool)

## Emitted when you step up to a computer station or leave it (computer mode
## spec §3): the station, or null.
signal station_changed(station: ComputerStation)

enum View { COCKPIT, CHASE, FOOT_FIRST, FOOT_THIRD, STATION }

const SIT_DURATION := 0.75
## The group the game's one director is in: a computer station finds it here
## (computer mode spec §3.1), since tables are rebuilt and ships come and go.
const GROUP := &"camera_director"
const THIRD_PERSON_OFFSET := Vector3(0.5, 0.4, 2.5)

@export var avatar_path: NodePath
@export var flight_computer_path: NodePath
@export var interior_camera_path: NodePath
@export var chase_camera_path: NodePath

var view: View = View.FOOT_FIRST
var is_seated: bool = false
var is_at_station: bool = false

var _seat: PilotSeat = null
var _station: ComputerStation = null
var _tween: Tween = null

@onready var _avatar: Avatar = get_node(avatar_path)
@onready var _flight: FlightComputer = get_node(flight_computer_path)
@onready var _interior_cam: Camera3D = get_node(interior_camera_path)
@onready var _chase_cam: Camera3D = get_node(chase_camera_path)

func _ready() -> void:
	add_to_group(GROUP)
	_apply_view()

## The station you are at, or null.
func station() -> ComputerStation:
	return _station if is_at_station else null

## The one interior camera, which is also the station's.
func camera() -> Camera3D:
	return _interior_cam

## Steps you up to a computer (computer mode spec §3.1): your body stays where
## it stood, the camera glides to the station's eye, the mouse is free.
func use_station(station: ComputerStation) -> void:
	if station == null or is_seated or is_at_station or _tween != null or _avatar.mode == Avatar.Mode.SUIT:
		return
	_station = station
	is_at_station = true
	_avatar.set_control_enabled(false)
	_avatar.set_at_station(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_move_camera_to(station.eye_transform())
	station_changed.emit(station)

## Back to your head (spec §3.4), the same move as standing up.
func leave_station() -> void:
	if not is_at_station or _tween != null:
		return
	_end_station()
	_move_camera_to(_avatar.head.global_transform)

func _end_station() -> void:
	is_at_station = false
	if is_instance_valid(_station):
		_station.left()
	_station = null
	_avatar.set_at_station(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	station_changed.emit(null)

## Whether you can still use the station (spec §3.5): its table is there, and
## you are awake and standing aboard its ship. A blackout, or a hole that puts
## you outside, changes you under the camera.
func _station_usable() -> bool:
	return is_instance_valid(_station) and _station.is_inside_tree() 		and _avatar.downed == null and _avatar.mode == Avatar.Mode.PLATING 		and ship_of(_station) == ship_of(_avatar)

## The station can no longer be used: back to your head at once, with no move.
## Only what the station took comes back. Your controls do too, unless a
## blackout holds them: waking gives them back.
func _drop_station() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_end_station()
	_interior_cam.reparent(_avatar.head, false)
	_interior_cam.transform = Transform3D.IDENTITY
	if _avatar.downed == null:
		_avatar.set_control_enabled(true)
	view = View.FOOT_FIRST
	_apply_view()

## At a station the camera follows its eye, which orbits as you drag.
func _process(_delta: float) -> void:
	if not is_at_station:
		return
	if not _station_usable():
		_drop_station()
		return
	if _tween == null:
		_interior_cam.global_transform = _station.eye_transform()

func sit(seat: PilotSeat) -> void:
	if is_seated or is_at_station or _tween != null or _avatar.mode == Avatar.Mode.SUIT:
		return
	_seat = seat
	is_seated = true
	_avatar.set_control_enabled(false)
	_move_camera_to(seat.eye.global_transform)
	piloting_changed.emit(true)

## Seats you at once, with no camera move (saving spec §6.3): a loaded game
## that was saved at the helm.
func sit_now(seat: PilotSeat) -> void:
	if is_seated or is_at_station or _tween != null or _avatar.mode == Avatar.Mode.SUIT:
		return
	_seat = seat
	is_seated = true
	_avatar.set_control_enabled(false)
	_interior_cam.reparent(seat.eye, false)
	_interior_cam.transform = Transform3D.IDENTITY
	view = View.COCKPIT
	piloting_changed.emit(true)
	_apply_view()

## True while a sit or stand camera move is running: a save waits (saving
## spec §5).
func is_moving() -> bool:
	return _tween != null

## The ship whose seat you sit in, or null standing (many ships spec §3.2):
## every ship's controls ask, and take the stick only for their own.
func seat_ship() -> Ship:
	return ship_of(_seat) if is_seated else null

## The Ship `node` is part of, or null.
static func ship_of(node: Node) -> Ship:
	while node != null and not (node is Ship):
		node = node.get_parent()
	return node as Ship

## Points the views at `ship` (many ships spec §4.1): the flight computer you
## let go of when you stand, and the chase camera C switches to.
func bind(ship: Ship) -> void:
	_flight = ship.flight_computer
	if _chase_cam == ship.chase_camera:
		return
	var chasing := view == View.CHASE
	_chase_cam.current = false
	_chase_cam = ship.chase_camera
	if chasing:
		_chase_cam.current = true

## Stands you up at once, with no camera move (many ships spec §4.3): F8's hop
## to another helm. The camera goes straight back to your head.
func stand_now() -> void:
	if not is_seated or _tween != null:
		return
	is_seated = false
	piloting_changed.emit(false)
	_flight.clear_pilot_input()
	_avatar.place(_seat.stand_spot(_avatar))
	_interior_cam.reparent(_avatar.head, false)
	_interior_cam.transform = Transform3D.IDENTITY
	_avatar.set_control_enabled(true)
	view = View.FOOT_FIRST
	_apply_view()

func stand() -> void:
	if not is_seated or _tween != null:
		return
	is_seated = false
	piloting_changed.emit(false)
	_flight.clear_pilot_input()
	# Get up out of the chair to somewhere the avatar fits, then fly the camera
	# back to its head.
	_avatar.place(_seat.stand_spot(_avatar))
	_move_camera_to(_avatar.head.global_transform)

func _move_camera_to(target: Transform3D) -> void:
	view_changed.emit(view, true)
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
	elif is_at_station:
		view = View.STATION
	else:
		_interior_cam.reparent(_avatar.head, true)
		_interior_cam.transform = Transform3D.IDENTITY
		_avatar.set_control_enabled(true)
		view = View.FOOT_FIRST
	_apply_view()
	transition_finished.emit()

func cycle_view() -> void:
	if _tween != null or is_at_station:
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
		View.STATION:
			_interior_cam.current = true
			_chase_cam.current = false
	view_changed.emit(view, false)

func _unhandled_input(event: InputEvent) -> void:
	# At a station F and Esc leave it, and nothing else of the director's
	# applies: V would throw the camera off the station's eye.
	if is_at_station:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			leave_station()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cycle_camera"):
		cycle_view()
	elif event.is_action_pressed("interact") and is_seated:
		stand()
