class_name AirlockCycle
extends RefCounted

## An airlock's state and its cycle (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §4), as a pure state machine: panels press(),
## the owner step()s it once a physics frame with who is where, and reads back
## the pressure, how far each hatch's leaves and bolts are, and the cues that
## fired. It touches no nodes, so every rule is testable headless.
##
## The rules it keeps:
## - a hatch opens bolts first, then leaves; it seals leaves first, then bolts;
## - at most one hatch is ever open, and never while the pressure is changing,
##   so an open inner hatch always has air behind it and an open outer hatch
##   vacuum;
## - a hatch never closes on anyone: sealing waits for its doorway to clear;
## - an open hatch closes itself once the room and both doorways have been
##   empty for AUTO_CLOSE;
## - pressing the room panel mid-cycle reverses it.

enum Stage { IDLE, SEALING, CYCLING, OPENING }
## A hatch: named Door because Godot's global scope already has a Side enum.
enum Door { NONE, INNER, OUTER }

## Normal air, kPa.
const ATMOSPHERE := 101.0
## Leaves shut (0.5 s), then bolts home (0.2 s).
const LEAF_CLOSE_TIME := 0.5
const BOLT_HOME_TIME := 0.2
const SEAL_TIME := LEAF_CLOSE_TIME + BOLT_HOME_TIME
const CYCLE_TIME := 2.8
## Bolts out (0.3 s), then leaves open (0.9 s).
const BOLT_OUT_TIME := 0.3
const LEAF_OPEN_TIME := 0.9
const OPEN_TIME := BOLT_OUT_TIME + LEAF_OPEN_TIME
const AUTO_CLOSE := 2.0
## The motion warning's thresholds (§4.4): amber, then coral.
const WARN_SPEED := 0.5
const WARN_TURN := 2.0
const ALARM_SPEED := 3.0
const ALARM_TURN := 10.0

var stage: Stage = Stage.IDLE
var pressure := ATMOSPHERE
## How far each hatch's leaves are open (0 shut .. 1 open), and how far its
## bolts are drawn (0 home across the seam .. 1 clear).
var inner_open := 0.0
var outer_open := 0.0
var inner_bolts := 0.0
var outer_bolts := 0.0
## The hatch the latest cue was about, for whoever plays its sound.
var cue_side: Door = Door.NONE
## True while sealing is held up by someone in the doorway.
var blocked := false

var _pending: StringName = &""
## The hatch being sealed or opened in SEALING or OPENING.
var _moving: Door = Door.NONE
## What happens once SEALING ends: a cycle, or nothing (a plain close).
var _then_cycle := false
## The hatch a cycle opens at the end, and the one it came through.
var _target: Door = Door.NONE
var _came_from: Door = Door.NONE
var _p_start := ATMOSPHERE
var _p_goal := ATMOSPHERE
var _cycle_time := 0.0
var _cycle_duration := CYCLE_TIME
var _reversing := false
var _empty_time := 0.0
var _said_blocked := false

## A panel was pressed: &"room", &"inner" (the corridor side) or &"outer"
## (the hull side). Acted on at the next step().
func press(panel: StringName) -> void:
	_pending = panel

## Advances by `delta` seconds. `clear_inner` and `clear_outer` say whether
## each hatch's doorway is empty; `room_empty` whether anyone is inside.
## Returns the cues that fired, in order.
func step(delta: float, clear_inner: bool, clear_outer: bool, room_empty: bool) -> Array[StringName]:
	var cues: Array[StringName] = []
	if _pending != &"":
		_handle_press(_pending, cues)
		_pending = &""
	match stage:
		Stage.SEALING:
			_step_sealing(delta, clear_inner if _moving == Door.INNER else clear_outer, cues)
		Stage.CYCLING:
			_step_cycling(delta, cues)
		Stage.OPENING:
			_step_opening(delta, cues)
		Stage.IDLE:
			_step_idle(delta, clear_inner and clear_outer and room_empty, cues)
	return cues

func pressurized() -> bool:
	return pressure > ATMOSPHERE * 0.5

## Which hatch is open, if any, once nothing is moving.
func open_side() -> Door:
	if inner_open > 0.0:
		return Door.INNER
	if outer_open > 0.0:
		return Door.OUTER
	return Door.NONE

## True while the pressure is heading down: the fog of going out, not the
## steam of coming in.
func going_out() -> bool:
	return _p_goal < _p_start

## Seconds into the current CYCLING run, and that run's length.
func cycle_time() -> float:
	return _cycle_time

func cycle_duration() -> float:
	return _cycle_duration

## What pressing `panel` would do now, or "" if nothing.
func prompt(panel: StringName) -> String:
	match panel:
		&"room":
			if stage == Stage.IDLE:
				return "Depressurize" if pressurized() else "Pressurize"
			if (stage == Stage.SEALING and _then_cycle) or stage == Stage.CYCLING:
				return "" if _reversing else "Reverse"
		&"inner":
			if stage == Stage.IDLE:
				if not pressurized():
					return "Pressurize"
				return "Close hatch" if inner_open > 0.0 else "Open hatch"
		&"outer":
			if stage == Stage.IDLE:
				if pressurized():
					return "Depressurize"
				return "Close hatch" if outer_open > 0.0 else "Open hatch"
	return ""

func status() -> String:
	if blocked:
		return "CLEAR THE HATCH"
	if stage != Stage.IDLE:
		return "CYCLING"
	return "READY" if pressurized() else "VACUUM"

## The motion warning (§4.4) for a hull moving at `speed` m/s and turning at
## `turn_rate_deg` degrees a second: {level: 0, 1 (amber) or 2 (coral), text}.
static func motion_warning(speed: float, turn_rate_deg: float) -> Dictionary:
	var by_speed := 2 if speed > ALARM_SPEED else (1 if speed > WARN_SPEED else 0)
	var by_turn := 2 if turn_rate_deg > ALARM_TURN else (1 if turn_rate_deg > WARN_TURN else 0)
	var level := maxi(by_speed, by_turn)
	if level == 0:
		return {"level": 0, "text": ""}
	if by_speed >= by_turn:
		return {"level": level, "text": "SHIP MOVING · %.1f M/S" % speed}
	return {"level": level, "text": "SHIP TURNING · %d°/S" % roundi(turn_rate_deg)}

func _handle_press(panel: StringName, cues: Array[StringName]) -> void:
	match stage:
		Stage.IDLE:
			match panel:
				&"room":
					_start_cycle(Door.OUTER if pressurized() else Door.INNER, cues)
				&"inner":
					_press_side(Door.INNER, pressurized(), cues)
				&"outer":
					_press_side(Door.OUTER, not pressurized(), cues)
		Stage.SEALING:
			# The room panel reverses a cycle before it starts; the hatch's own
			# panel stops a plain close. Either way the hatch reopens.
			var own := &"inner" if _moving == Door.INNER else &"outer"
			if (panel == &"room" and _then_cycle) or (panel == own and not _then_cycle):
				cues.append(&"reversed")
				_begin_opening(_moving, cues)
		Stage.CYCLING:
			if panel == &"room" and not _reversing:
				_reversing = true
				_p_goal = _p_start
				_p_start = pressure
				_cycle_duration = maxf(_cycle_time, 0.01)
				_cycle_time = 0.0
				_target = _came_from
				cues.append(&"reversed")

## An outside panel pressed while idle: if its side already has the right
## pressure it opens or closes its hatch; otherwise it calls the room over.
func _press_side(side: Door, matches: bool, cues: Array[StringName]) -> void:
	if not matches:
		_start_cycle(side, cues)
	elif (inner_open if side == Door.INNER else outer_open) > 0.0:
		_begin_sealing(side, false, cues)
	else:
		_begin_opening(side, cues)

## A cycle that ends by opening `target`: seal whatever is open first.
func _start_cycle(target: Door, cues: Array[StringName]) -> void:
	_target = target
	_came_from = open_side()
	_reversing = false
	if _came_from != Door.NONE:
		_begin_sealing(_came_from, true, cues)
	else:
		_begin_cycling(cues)

func _begin_sealing(side: Door, then_cycle: bool, cues: Array[StringName]) -> void:
	stage = Stage.SEALING
	_moving = side
	_then_cycle = then_cycle
	_said_blocked = false
	cue_side = side
	cues.append(&"leaves_closing")

func _begin_cycling(cues: Array[StringName]) -> void:
	stage = Stage.CYCLING
	_p_start = pressure
	_p_goal = ATMOSPHERE if _target == Door.INNER else 0.0
	_cycle_time = 0.0
	_cycle_duration = CYCLE_TIME
	cue_side = Door.NONE
	cues.append(&"cycle_start")
	if not going_out():
		cues.append(&"steam_jets")

func _begin_opening(side: Door, cues: Array[StringName]) -> void:
	stage = Stage.OPENING
	_moving = side
	blocked = false
	cue_side = side
	if _bolts(side) < 1.0:
		cues.append(&"bolts_out")
	else:
		cues.append(&"leaves_opening")

func _step_sealing(delta: float, clear: bool, cues: Array[StringName]) -> void:
	var side := _moving
	if _leaves(side) > 0.0:
		if not clear:
			blocked = true
			if not _said_blocked:
				_said_blocked = true
				cues.append(&"blocked")
			return
		blocked = false
		_set_leaves(side, move_toward(_leaves(side), 0.0, delta / LEAF_CLOSE_TIME))
		if _leaves(side) <= 0.0:
			cue_side = side
			cues.append(&"leaves_shut")
		return
	_set_bolts(side, move_toward(_bolts(side), 0.0, delta / BOLT_HOME_TIME))
	if _bolts(side) <= 0.0:
		cue_side = side
		cues.append(&"bolts_home")
		if _then_cycle:
			_begin_cycling(cues)
		else:
			stage = Stage.IDLE

func _step_cycling(delta: float, cues: Array[StringName]) -> void:
	_cycle_time = minf(_cycle_time + delta, _cycle_duration)
	var u := _cycle_time / _cycle_duration
	pressure = _p_goal + (_p_start - _p_goal) * (1.0 - u) * (1.0 - u)
	if _cycle_time >= _cycle_duration:
		pressure = _p_goal
		_reversing = false
		if _target == Door.NONE:
			stage = Stage.IDLE
		else:
			_begin_opening(_target, cues)

func _step_opening(delta: float, cues: Array[StringName]) -> void:
	var side := _moving
	if _bolts(side) < 1.0:
		_set_bolts(side, move_toward(_bolts(side), 1.0, delta / BOLT_OUT_TIME))
		if _bolts(side) >= 1.0:
			cue_side = side
			cues.append(&"leaves_opening")
		return
	_set_leaves(side, move_toward(_leaves(side), 1.0, delta / LEAF_OPEN_TIME))
	if _leaves(side) >= 1.0:
		cue_side = side
		cues.append(&"leaves_open")
		stage = Stage.IDLE
		_empty_time = 0.0

func _step_idle(delta: float, everyone_gone: bool, cues: Array[StringName]) -> void:
	var side := open_side()
	if side == Door.NONE or not everyone_gone:
		_empty_time = 0.0
		return
	_empty_time += delta
	if _empty_time >= AUTO_CLOSE:
		_empty_time = 0.0
		cues.append(&"auto_close")
		_begin_sealing(side, false, cues)

func _leaves(side: Door) -> float:
	return inner_open if side == Door.INNER else outer_open

func _set_leaves(side: Door, amount: float) -> void:
	if side == Door.INNER:
		inner_open = amount
	else:
		outer_open = amount

func _bolts(side: Door) -> float:
	return inner_bolts if side == Door.INNER else outer_bolts

func _set_bolts(side: Door, amount: float) -> void:
	if side == Door.INNER:
		inner_bolts = amount
	else:
		outer_bolts = amount
