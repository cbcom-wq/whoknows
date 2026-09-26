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
##
## It keeps the airlock's first refusal in open space (quantum energy spec
## §9): the room panel will not depressurize while the one aboard holds a suit
## under SuitCell.GO_OUT_MIN. And it tells whoever goes out where home is --
## for the HUD's beacon, and for a dry suit's emergency cell.

## A cue from the cycle (AirlockCycle.step), and which hatch it was about.
signal cue(name: StringName, door: AirlockCycle.Door)
## Someone crossed the outer hatch's threshold (§7): out onto a spacewalk, or
## back aboard.
signal crossed(avatar: Avatar, outward: bool)

## How close to a hatch's plane counts as standing in its doorway: the body's
## radius and a margin, so closing leaves never touch anyone.
const DOORWAY_DEPTH := 0.45
const BODY_RADIUS := 0.35
## Where you land coming back in: this far into the room from the outer hatch,
## and no further across than this, so your body clears the hatch frame.
const ENTRY_DEPTH := 0.45
const ENTRY_SIDEWAYS := 0.15
## Where a dry suit holds you, this far outside the outer hatch (quantum
## energy spec §9).
const HOME_OUT := 1.5

var coord := Vector3i.ZERO
var cycle := AirlockCycle.new()
var room: AirlockRoom
## The copy of the room on the hull (airlock spec §7.2).
var alcove: AirlockAlcove
## The motion warning (AirlockCycle.motion_warning) as of the last step.
var warning := {"level": 0, "text": ""}
## The room's steam, haze and light (§5), rebuilt with each room.
var show: AirlockShow

var _ship: Ship
## While the viewer's camera is in the room it wears a copy of its own
## environment with the haze in it; the original is put back on leaving.
var _hazed_camera: Camera3D
var _saved_environment: Environment
var _haze_environment: Environment
## Positional players in the room (§6), one per place a sound comes from.
var _players: Dictionary = {}   # StringName -> AudioStreamPlayer3D
## True while this airlock is setting how much air carries sound.
var _owns_air := false
## True while this airlock has the canopy view showing the own hull.
var _owns_portal := false

func setup(ship: Ship, at: Vector3i) -> void:
	_ship = ship
	coord = at
	name = "Airlock_%d_%d_%d" % [at.x, at.y, at.z]

## Takes over a freshly built room (and, once the hull has one, its copy).
func bind(new_room: AirlockRoom, new_alcove: AirlockAlcove = null) -> void:
	_restore_environment()
	room = new_room
	alcove = new_alcove
	show = AirlockShow.new()
	room.add_child(show)
	show.setup(room.room_frame, room.nozzles, room.ceiling_light, InteriorKit.LAYER)
	_make_players()
	for panel in panels():
		panel.prompt_source = prompt.bind(panel.role)
		if not panel.pressed.is_connected(_on_pressed):
			panel.pressed.connect(_on_pressed)
	_apply()

## What pressing panel `role` would do now, or "": the cycle's prompt, unless
## the room panel is refusing to let an empty suit out.
func prompt(role: StringName) -> String:
	if role == &"room" and must_charge():
		return "Charge suit first"
	return cycle.prompt(role)

## True while the room panel refuses to depressurize (quantum energy spec §9):
## the room is idle and pressurized -- pressing would take you out -- and
## the one aboard holds a suit under SuitCell.GO_OUT_MIN. Coming in, and a
## cycle already running, are never refused.
func must_charge() -> bool:
	if cycle.stage != AirlockCycle.Stage.IDLE or not cycle.pressurized():
		return false
	var avatar := _avatar()
	return avatar != null and _ship != null and avatar.get_parent() == _ship.interior \
		and avatar.suit_cell.charge < SuitCell.GO_OUT_MIN

## Every panel this airlock has right now.
func panels() -> Array[AirlockPanel]:
	var out: Array[AirlockPanel] = []
	if is_instance_valid(room):
		for panel in [room.room_panel, room.corridor_panel]:
			if panel != null:
				out.append(panel)
	if is_instance_valid(alcove) and alcove.hull_panel != null:
		out.append(alcove.hull_panel)
	return out

## Advances the airlock by `delta`. Called every physics frame; tests call it
## directly.
func tick(delta: float) -> void:
	if not is_instance_valid(room):
		return
	_watch_threshold()
	var who := occupancy()
	var cues := cycle.step(delta, who["clear_inner"], who["clear_outer"], who["room_empty"])
	_update_warning()
	_apply()
	show.apply(cycle, delta)
	_update_haze()
	_update_air()
	_update_portal()
	for c in cues:
		cue.emit(c, cycle.cue_side)
		_sound(c, cycle.cue_side)
		# Whatever fog is left puffs out into space as the outer hatch parts.
		if c == &"leaves_opening" and cycle.cue_side == AirlockCycle.Door.OUTER and show.haze > 0.05 \
				and is_instance_valid(alcove):
			alcove.show.burst_out()

func _physics_process(delta: float) -> void:
	tick(delta)

## Where the avatar is, as the cycle needs it: {room_empty, clear_inner,
## clear_outer}. Aboard it is looked for in the room; on a spacewalk, in the
## room's copy on the hull -- so the outer hatch closes behind you once you
## float clear, and never on you.
func occupancy() -> Dictionary:
	var who := {"room_empty": true, "clear_inner": true, "clear_outer": true}
	var avatar := _avatar()
	if avatar == null or _ship == null:
		return who
	if avatar.mode == Avatar.Mode.PLATING and avatar.get_parent() == _ship.interior:
		var points := _body_points(avatar, _ship.interior.global_transform.affine_inverse())
		who["room_empty"] = not points.any(func(p): return in_room(p, room.room_frame))
		who["clear_outer"] = not points.any(func(p): return in_doorway(p, room.outer_frame))
		if room.inner_hatch != null:
			who["clear_inner"] = not points.any(func(p): return in_doorway(p, room.inner_frame))
	elif avatar.mode == Avatar.Mode.SUIT and is_instance_valid(alcove) and avatar.hull == _ship.exterior:
		var points := _body_points(avatar, _ship.exterior.global_transform.affine_inverse())
		who["room_empty"] = not points.any(func(p): return in_room(p, alcove.room_frame))
		who["clear_outer"] = not points.any(func(p): return in_doorway(p, alcove.outer_frame))
	return who

## The avatar's feet, middle and head, in the frame `to_local` maps into: a
## floating body can be any way up, so all three are checked.
static func _body_points(avatar: Avatar, to_local: Transform3D) -> Array:
	var up := avatar.global_basis.y
	var feet := avatar.global_position
	return [to_local * feet, to_local * (feet + up * Avatar.STAND_HEIGHT * 0.5),
		to_local * (feet + up * (Avatar.STAND_HEIGHT - 0.1))]

## Crossing the outer hatch's plane, either way, while it is fully open (§7):
## out into the world onto a spacewalk, or back into the room aboard.
func _watch_threshold() -> void:
	var avatar := _avatar()
	if avatar == null or _ship == null or not is_instance_valid(alcove) or cycle.outer_open < 1.0:
		return
	var hull := _ship.exterior
	var interior := _ship.interior
	var offset := InteriorBuilder.storey_offset(coord.y)
	if avatar.mode == Avatar.Mode.PLATING:
		if avatar.get_parent() != interior:
			return
		var local := room.outer_frame.affine_inverse() * avatar.position
		if not _in_opening(local) or not Threshold.crossed_out(local.z):
			return
		var world := Threshold.to_world(interior.global_transform, hull.global_transform, avatar.global_transform, offset)
		var v := Threshold.carry_velocity_out(_hull_velocity_at(world.origin), hull.global_basis, avatar.velocity)
		_restore_environment()   # the avatar keeps the cabin's own mood, not the haze copy
		avatar.enter_suit(_ship.outside, world, v, hull)
		avatar.beacon_source = beacon
		avatar.home_source = home
		crossed.emit(avatar, true)
	elif avatar.hull == hull:
		var local := alcove.outer_frame.affine_inverse() * (hull.global_transform.affine_inverse() * avatar.global_position)
		if not _in_opening(local) or not Threshold.crossed_in(local.z) or local.z > ShipGrid.CELL_SIZE:
			return
		var view := Threshold.to_interior(interior.global_transform, hull.global_transform, avatar.head.global_transform, offset)
		var up := Threshold.upright(view.basis)
		# Stand just inside the hatch, clear of its frame, where you came
		# through; the view starts at your eye and eases to your head.
		var stand := room.outer_frame * Vector3(clampf(local.x, -ENTRY_SIDEWAYS, ENTRY_SIDEWAYS), 0.0, ENTRY_DEPTH)
		var feet := interior.global_transform * stand
		var v := Threshold.carry_velocity_in(avatar.velocity, _hull_velocity_at(avatar.global_position), hull.global_basis)
		avatar.enter_plating(interior, Transform3D(up["body"], feet), up["pitch"], v, up["righting"], view.origin)
		crossed.emit(avatar, false)

## The way home for someone outside: the middle of the outer hatch on the hull.
func beacon() -> Vector3:
	if not is_instance_valid(alcove):
		return Vector3.ZERO
	return alcove.outer_hatch.global_transform * Vector3(0, InteriorProps.HATCH_HEIGHT * 0.5, 0)

## Where a dry suit brings the middle of you (quantum energy spec §9): level
## with the outer hatch's middle, HOME_OUT outside it, and held there. Once
## the hatch is opening or open, ENTRY_DEPTH inside it instead, so the
## emergency cell floats you in across the threshold -- you still press the
## hull panel yourself. It sets off as the bolts draw, not once the leaves
## have parted, so you are in the doorway well before an empty airlock would
## close itself (AirlockCycle.AUTO_CLOSE); and a closing hatch sends you back
## out rather than into its leaves. Non-finite with no hatch on the hull to
## go home to.
func home() -> Vector3:
	if not is_instance_valid(alcove):
		return Vector3.INF
	var coming_in := cycle.outer_open >= 1.0 \
		or (cycle.stage == AirlockCycle.Stage.OPENING and cycle.outer_bolts > 0.0)
	var depth := ENTRY_DEPTH if coming_in else -HOME_OUT
	return alcove.outer_hatch.global_transform * Vector3(0, InteriorProps.HATCH_HEIGHT * 0.5, depth)

## Inside the opening, across and up, in a hatch frame.
static func _in_opening(local: Vector3) -> bool:
	return absf(local.x) < InteriorProps.DOOR_WIDTH * 0.5 and local.y > -0.5 \
		and local.y < InteriorProps.HATCH_HEIGHT + 0.5

func _hull_velocity_at(p: Vector3) -> Vector3:
	var hull := _ship.exterior
	var com := hull.global_transform * (hull.center_of_mass
		if hull.center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM else Vector3.ZERO)
	return Threshold.point_velocity(hull.linear_velocity, hull.angular_velocity, com, p)

## While the viewer stands in the room with the outer hatch open, the canopy
## view includes the own hull (§7.3); the inner hatch is shut then, so no other
## window can be seen from here.
func _update_portal() -> void:
	var portal := _ship.get_node_or_null("CanopyPortal") as CanopyPortal if _ship != null else null
	if portal == null:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var inside := cam != null and _ship.interior.is_ancestor_of(cam) \
		and in_room(_ship.interior.to_local(cam.global_position), room.room_frame)
	if inside and cycle.outer_open > 0.0:
		portal.include_hull = true
		_owns_portal = true
	elif _owns_portal:
		portal.include_hull = false
		_owns_portal = false

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

## Puts the haze on the camera looking out from inside the room, and takes it
## off again when that camera leaves.
func _update_haze() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var inside := cam != null and _ship != null and _ship.interior.is_ancestor_of(cam) \
		and in_room(_ship.interior.to_local(cam.global_position), room.room_frame)
	if not inside:
		_restore_environment()
		return
	if cam != _hazed_camera:
		_restore_environment()
		if cam.environment == null:
			return
		_hazed_camera = cam
		_saved_environment = cam.environment
		_haze_environment = _saved_environment.duplicate()
		cam.environment = _haze_environment
	show.tint(_haze_environment)

func _restore_environment() -> void:
	if is_instance_valid(_hazed_camera) and _hazed_camera.environment == _haze_environment:
		_hazed_camera.environment = _saved_environment
	_hazed_camera = null

## A panel pressed: the cycle acts on it at its next step, and the panel beeps
## where it is -- or, refusing an empty suit, sounds the warning instead.
func _on_pressed(role: StringName) -> void:
	for panel in panels():
		if panel.role == role and _players.has(&"panel"):
			var beep: AudioStreamPlayer3D = _players[&"panel"]
			beep.global_position = panel.global_position
	if role == &"room" and must_charge():
		cue.emit(&"refused", AirlockCycle.Door.NONE)
		_play(&"panel", &"warning_chime")
		return
	cycle.press(role)
	cue.emit(&"panel_beep", AirlockCycle.Door.NONE)
	_play(&"panel", &"panel_beep")

## The positional player for `key` (&"inner_motor", &"inner_bolt",
## &"outer_motor", &"outer_bolt", &"room", &"panel").
func player(key: StringName) -> AudioStreamPlayer3D:
	return _players.get(key)

func _make_players() -> void:
	_players.clear()
	var up := Vector3(0, InteriorProps.HATCH_HEIGHT * 0.7, 0)
	var spots := {&"outer_motor": room.outer_frame.origin + up, &"outer_bolt": room.outer_frame.origin + up,
		&"room": room.room_frame.origin + Vector3(0, 1.2, 0), &"panel": room.room_frame.origin}
	if room.inner_hatch != null:
		spots[&"inner_motor"] = room.inner_frame.origin + up
		spots[&"inner_bolt"] = room.inner_frame.origin + up
	for key: StringName in spots:
		var p := AudioStreamPlayer3D.new()
		p.name = "Sound_%s" % key
		p.bus = AudioBuses.SHIP
		p.unit_size = 3.0
		p.max_distance = 30.0
		p.position = spots[key]
		room.add_child(p)
		_players[key] = p

func _play(key: StringName, sound_name: StringName) -> void:
	var p: AudioStreamPlayer3D = _players.get(key)
	var s := Synth.sound(sound_name)
	if p == null or s == null:
		return
	p.stream = s
	p.play()

## Each cue's sound, from the hatch it was about.
func _sound(c: StringName, door: AirlockCycle.Door) -> void:
	var side := &"inner" if door == AirlockCycle.Door.INNER else &"outer"
	match c:
		&"leaves_closing", &"leaves_opening":
			_play(StringName(side + "_motor"), &"hatch_motor")
		&"bolts_home", &"bolts_out":
			_play(StringName(side + "_bolt"), &"bolt_clunk")
		&"leaves_shut":
			_play(StringName(side + "_bolt"), &"seal_thump")
		&"cycle_start":
			if cycle.going_out():
				_play(&"room", &"hiss_out")
		&"steam_jets":
			_play(&"room", &"steam_in")

## While the listener is in the room, air carries sound only as well as the
## room's pressure lets it; leaving hands the air back.
func _update_air() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var inside := cam != null and _ship != null and _ship.interior.is_ancestor_of(cam) \
		and in_room(_ship.interior.to_local(cam.global_position), room.room_frame)
	if inside:
		AudioBuses.set_air(cycle.pressure / AirlockCycle.ATMOSPHERE)
		_owns_air = true
	elif _owns_air:
		AudioBuses.set_air(1.0)
		_owns_air = false

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
	var refusing := must_charge()
	var lines := PackedStringArray(["PRESSURE %d kPa" % roundi(cycle.pressure),
		"CHARGE SUIT" if refusing else cycle.status()])
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
					# CORAL while it refuses, as the machine's button is.
					state = &"vacuum" if refusing else &"go"
		panel.set_readout(lines, state)

## The outer hatch in the room and, once built, its copy on the hull.
func _outer_hatches() -> Array[AirlockHatch]:
	var out: Array[AirlockHatch] = []
	if room.outer_hatch != null:
		out.append(room.outer_hatch)
	if is_instance_valid(alcove) and alcove.outer_hatch != null:
		out.append(alcove.outer_hatch)
	return out

func _avatar() -> Avatar:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(Avatar.GROUP) as Avatar
