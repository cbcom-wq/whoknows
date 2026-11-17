class_name WadooState
extends RefCounted

## What Wadoo knows of you (docs/superpowers/specs/2026-11-16-wadoo-design.md §6-§9),
## saved with the game as the part "wadoo": how well they think of you (regard,
## 0 to REGARD_MAX, one for each thing you did for them), which of the three
## things you did, whether you have met the queen, what you told her of the hunt,
## and whether you ever hurt one of them (for good). Also how often each of them
## has spoken to you, so a speaker with several lines goes through them in turn.

signal changed

const REGARD_MAX := 3
## The three things to do (§7).
const TASKS: Array[StringName] = [&"pump", &"armlet", &"lilies"]
## The lilies at the memorial: one for each you bring, up to this.
const LILIES_MAX := 6
## What you told the queen of the hunt.
const HUNT_NONE := &""
const HUNT_LATER := &"later"
const HUNT_ACCEPTED := &"accepted"

var regard := 0
## Each task's progress: &"pump" and &"armlet" true once done, &"lilies" a count.
var tasks := {}
var met_queen := false
var hunt: StringName = HUNT_NONE
var hostile := false
## How many times each speaker (a record id) has spoken to you.
var heard := {}

## True once the task is done (the lilies: once one is laid).
func did(task: StringName) -> bool:
	if task == &"lilies":
		return int(tasks.get(task, 0)) > 0
	return bool(tasks.get(task, false))

## Marks `task` done (a lily laid, for &"lilies"): the first time each raises
## regard by one. False if there was nothing to do (done, or all six laid).
func do_task(task: StringName) -> bool:
	if not TASKS.has(task):
		return false
	var first := not did(task)
	if task == &"lilies":
		var n := int(tasks.get(task, 0))
		if n >= LILIES_MAX:
			return false
		tasks[task] = n + 1
	elif not first:
		return false
	else:
		tasks[task] = true
	if first:
		regard = mini(regard + 1, REGARD_MAX)
	changed.emit()
	return true

## How many of the three are done.
func tasks_done() -> int:
	var n := 0
	for t in TASKS:
		if did(t):
			n += 1
	return n

## Oru steps aside and the hall's door opens (§8): regard 1 and never hurt.
func door_open() -> bool:
	return regard >= 1 and not hostile

func meet_queen() -> void:
	if not met_queen:
		met_queen = true
		changed.emit()

func answer_hunt(answer: StringName) -> void:
	if hunt == HUNT_ACCEPTED or answer == hunt:
		return
	hunt = answer
	changed.emit()

## One counted wound (§9): the village is hostile for good.
func turn_hostile() -> void:
	if not hostile:
		hostile = true
		changed.emit()

## Does what a line's `then` names, if it is the village's own: "meet_queen",
## "hunt_accepted", "hunt_later". False for anything else (the scene's to do).
func apply(then: String) -> bool:
	match then:
		"meet_queen":
			meet_queen()
		"hunt_accepted":
			answer_hunt(HUNT_ACCEPTED)
		"hunt_later":
			answer_hunt(HUNT_LATER)
		_:
			return false
	return true

## Counts one more time `speaker` spoke; returns how many times before this.
func heard_from(speaker: StringName) -> int:
	var n := int(heard.get(speaker, 0))
	heard[speaker] = n + 1
	return n

## The facts lines are chosen by (WadooLines), as plain values.
func facts() -> Dictionary:
	var f := {"regard": regard, "met_queen": met_queen, "hunt": String(hunt), "hostile": hostile,
		"door": door_open(), "tasks_done": tasks_done(), "lilies": int(tasks.get(&"lilies", 0))}
	for t in TASKS:
		f["task:%s" % t] = did(t)
	return f

func to_dict() -> Dictionary:
	var t := {}
	for k: StringName in tasks:
		t[String(k)] = tasks[k]
	var h := {}
	for k: StringName in heard:
		h[String(k)] = heard[k]
	return {"regard": regard, "tasks": t, "met_queen": met_queen, "hunt": String(hunt), "hostile": hostile,
		"heard": h}

static func from_dict(d: Dictionary) -> WadooState:
	var s := WadooState.new()
	s.regard = clampi(int(d.get("regard", 0)), 0, REGARD_MAX)
	var t: Dictionary = d.get("tasks", {})
	for k: String in t:
		if TASKS.has(StringName(k)):
			s.tasks[StringName(k)] = int(t[k]) if k == "lilies" else bool(t[k])
	s.met_queen = bool(d.get("met_queen", false))
	var h := StringName(str(d.get("hunt", "")))
	s.hunt = h if h in [HUNT_NONE, HUNT_LATER, HUNT_ACCEPTED] else HUNT_NONE
	s.hostile = bool(d.get("hostile", false))
	var heard_d: Dictionary = d.get("heard", {})
	for k: String in heard_d:
		s.heard[StringName(k)] = int(heard_d[k])
	return s
