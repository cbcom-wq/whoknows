class_name Airlock
extends Node

## Drives one airlock (docs/superpowers/specs/2026-09-24-airlock-design.md §4):
## gathers who is where, steps its AirlockCycle once a physics frame, and shows
## the result on everything the cycle owns -- both copies of each hatch, the
## strips and warning lamps, the panels' readouts and prompts. It emits the
## cycle's cues for whatever plays the sound and the steam. Nothing else runs
## the airlock's timing.
##
## One per airlock cell, under Ship/Airlocks, kept across rebuilds: a rebuild
## frees the room it drives and builds a new one, and bind() hands it over
## without resetting the pressure or moving a hatch.

## A cue from the cycle (AirlockCycle.step), and which hatch it was about.
signal cue(name: StringName, door: AirlockCycle.Door)

## How close to a hatch's plane counts as standing in its doorway: the body's
## radius and a margin, so closing leaves never touch anyone.
const DOORWAY_DEPTH := 0.45
const BODY_RADIUS := 0.35

var coord := Vector3i.ZERO
var cycle := AirlockCycle.new()
var room: AirlockRoom
## The copy of the room on the hull (airlock spec §7.2), once built.
var alcove: Node
## The motion warning (AirlockCycle.motion_warning) as of the last step.
var warning := {"level": 0, "text": ""}

var _ship: Ship

func setup(ship: Ship, at: Vector3i) -> void:
	_ship = ship
	coord = at
	name = "Airlock_%d_%d_%d" % [at.x, at.y, at.z]

## Takes over a freshly built room (and, once the hull has one, its copy).
func bind(new_room: AirlockRoom, new_alcove: Node = null) -> void:
	room = new_room
	alcove = new_alcove
	for panel in panels():
		panel.prompt_source = cycle.prompt.bind(panel.role)
		if not panel.pressed.is_connected(_on_pressed):
			panel.pressed.connect(_on_pressed)
	_apply()

## Every panel this airlock has right now.
func panels() -> Array[AirlockPanel]:
	var out: Array[AirlockPanel] = []
	if is_instance_valid(room):
		for panel in [room.room_panel, room.corridor_panel]:
			if panel != null:
				out.append(panel)
	if is_instance_valid(alcove) and "hull_panel" in alcove and alcove.hull_panel != null:
		out.append(alcove.hull_panel)
	return out

## Advances the airlock by `delta`. Called every physics frame; tests call it
## directly.
func tick(delta: float) -> void:
	if not is_instance_valid(room):
		return
	var who := occupancy()
	var cues := cycle.step(delta, who["clear_inner"], who["clear_outer"], who["room_empty"])
	_update_warning()
	_apply()
	for c in cues:
		cue.emit(c, cycle.cue_side)

func _physics_process(delta: float) -> void:
	tick(delta)

## Where the avatar is, as the cycle needs it: {room_empty, clear_inner,
## clear_outer}.
func occupancy() -> Dictionary:
	var who := {"room_empty": true, "clear_inner": true, "clear_outer": true}
	var avatar := _avatar()
	if avatar == null or _ship == null or avatar.get_parent() != _ship.interior:
		return who
	var p := avatar.position
	who["room_empty"] = not in_room(p, room.room_frame)
	who["clear_outer"] = not in_doorway(p, room.outer_frame)
	if room.inner_hatch != null:
		who["clear_inner"] = not in_doorway(p, room.inner_frame)
	return who

## True if `p` (in the room's parent frame) is inside the airlock's cell.
static func in_room(p: Vector3, room_frame: Transform3D) -> bool:
	var local := room_frame.affine_inverse() * p
	var half := ShipGrid.CELL_SIZE * 0.5
	return absf(local.x) < half and absf(local.z) < half and local.y > -0.5 and local.y < ShipGrid.CELL_SIZE

## True if `p` is close enough to the hatch at `hatch_frame` that closing it
## could touch whoever is there.
static func in_doorway(p: Vector3, hatch_frame: Transform3D) -> bool:
	var local := hatch_frame.affine_inverse() * p
	return absf(local.z) < DOORWAY_DEPTH \
		and absf(local.x) < InteriorProps.DOOR_WIDTH * 0.5 + BODY_RADIUS \
		and local.y > -0.5 and local.y < InteriorProps.HATCH_HEIGHT

func _on_pressed(role: StringName) -> void:
	cycle.press(role)
	cue.emit(&"panel_beep", AirlockCycle.Door.NONE)

func _update_warning() -> void:
	if _ship == null or _ship.exterior == null:
		return
	var hull := _ship.exterior
	warning = AirlockCycle.motion_warning(hull.linear_velocity.length(),
		rad_to_deg(hull.angular_velocity.length()))

## Shows the cycle's state on everything it owns.
func _apply() -> void:
	if not is_instance_valid(room):
		return
	var idle := cycle.stage == AirlockCycle.Stage.IDLE
	var air := cycle.pressurized()
	if room.inner_hatch != null:
		room.inner_hatch.open_amount = cycle.inner_open
		room.inner_hatch.bolts_out = cycle.inner_bolts
		room.inner_hatch.set_strip(&"cycling" if not idle else (&"go" if air else &"vacuum"))
		room.inner_hatch.set_warning(not idle)
	var outer_strip := &"cycling" if not idle else (&"vacuum" if air else &"go")
	for hatch in _outer_hatches():
		hatch.open_amount = cycle.outer_open
		hatch.bolts_out = cycle.outer_bolts
		hatch.set_strip(outer_strip)
		hatch.set_warning(not idle or warning["level"] > 0)
	var lines := PackedStringArray(["PRESSURE %d kPa" % roundi(cycle.pressure), cycle.status()])
	if warning["level"] > 0:
		lines.append(warning["text"])
	for panel in panels():
		var state := &"cycling"
		if idle:
			match panel.role:
				&"inner":
					state = &"go" if air else &"vacuum"
				&"outer":
					state = &"vacuum" if air else &"go"
				_:
					state = &"go"
		panel.set_readout(lines, state)

## The outer hatch in the room and, once built, its copy on the hull.
func _outer_hatches() -> Array[AirlockHatch]:
	var out: Array[AirlockHatch] = []
	if room.outer_hatch != null:
		out.append(room.outer_hatch)
	if is_instance_valid(alcove) and "outer_hatch" in alcove and alcove.outer_hatch != null:
		out.append(alcove.outer_hatch)
	return out

func _avatar() -> Avatar:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(Avatar.GROUP) as Avatar
