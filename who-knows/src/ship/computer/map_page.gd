class_name MapPage
extends ComputerPage

## The map (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §5):
## what the ship's sensors know, shrunk into the holo and turned with the
## ship, at 2, 10 or 30 km. ◀ and ▶ pick a contact, nearest first; the big
## button sets or clears the course (§6) to a big rock or salvage. It shows
## only what the sensors report: a ping where the ping says, a region as its
## sphere, never the thing's true place.
##
## Every kind the sensors know is drawn in its own colour: rocks SKY, salvage
## QUANTUM, signs of life SIGNAL_GO (the HUD's green), and the course AMBER.

const RANGES: Array[float] = [2000.0, 10000.0, 30000.0, 300000.0]
## The last range is the whole system (the system skeleton spec §10).
const SYSTEM_RANGE := 3
const OPEN_AT := 1
## Contacts that get a stalk, nearest first; the selected one always does.
const STALKS := 12
## What a course can be set to (spec §15): a big rock or a salvage cloud.
const COURSE_KINDS: Array[StringName] = [&"rock", &"salvage", &"body"]
## Mark sizes, metres across in the holo (spec §5.2), tuned at the renders:
## the spec's first figures vanished at arm's length.
const ROCK_MIN_NEAR := 0.012
const ROCK_MIN_MID := 0.012
const ROCK_MAX_MID := 0.03
## A 600 m rock is the biggest; at 10 km it is ROCK_MAX_MID across.
const ROCK_BIGGEST := 600.0
const ROCK_FAR := 0.008
const REGION_MIN := 0.02
## A world's mark: sized by radius, but never lost nor overwhelming.
const BODY_MIN := 0.012
const BODY_MAX := 0.06
## Each belt's ring of ticks on the system range.
const BELT_TICKS := 48
const PING_SIZE := 0.018
## A ping shrinks to this share of its size by its next refresh.
const PING_SHRINK := 0.4
const PIN_SIZE := 0.016
const TICK_SIZE := 0.01
const BRACKET_GAP := 0.012
## How often the marks are placed afresh at each range, seconds; in between
## they are only turned with the ship (HoloVolume.set_turn). At 30 km there
## are hundreds, and a ship at 300 m/s moves a pip 2 mm a second there.
const PLACE_EVERY: Array[float] = [0.0, 0.0, 0.5, 0.5]

var range_index := OPEN_AT
var selected: StringName = &""

var _targets: Array[Contact] = []
var _targets_key := []
## When the marks were last placed, what they were placed for, and the map's
## frame then.
var _placed_ago := INF
var _placed_for := []
var _placed_basis := Basis.IDENTITY

func range_m() -> float:
	return RANGES[range_index]

func title() -> String:
	if range_index == SYSTEM_RANGE:
		return "MAP · SYSTEM"
	return "MAP · %d KM" % roundi(range_m() / 1000.0)

## The colour a contact of `kind` is drawn in.
static func colour_for(kind: StringName) -> Color:
	match kind:
		&"rock":
			return InteriorPalette.SKY
		&"salvage":
			return InteriorPalette.QUANTUM
		&"life":
			return InteriorPalette.SIGNAL_GO
		&"body":
			return InteriorPalette.WORLD
	return InteriorPalette.LIGHT_WARM

## What ◀ and ▶ step through: the contacts on this range, nearest first. The
## 30 km range shows big rocks and worlds only (§5.2), the system range worlds
## only (the system skeleton spec §10). Worked out once a frame.
func targets(ctx: ComputerContext) -> Array[Contact]:
	var key := [Engine.get_process_frames(), range_index, ctx.sensors]
	if key == _targets_key:
		return _targets
	_targets_key = key
	_targets = []
	if ctx.sensors == null:
		return _targets
	for c in ctx.sensors.contacts(range_m()):
		if range_index == SYSTEM_RANGE and c.kind != &"body":
			continue
		if range_index == SYSTEM_RANGE - 1 and c.kind != &"rock" and c.kind != &"body":
			continue
		_targets.append(c)
	return _targets

func selected_contact(ctx: ComputerContext) -> Contact:
	for c in targets(ctx):
		if c.id == selected:
			return c
	return null

## After a change of page or range: the course if it is on this range, else
## the nearest.
func reselect(ctx: ComputerContext) -> void:
	_targets_key = []
	var list := targets(ctx)
	selected = &""
	if list.is_empty():
		return
	for c in list:
		if c.id == ctx.sensors.course:
			selected = c.id
			return
	selected = list[0].id

func opened(ctx: ComputerContext) -> void:
	reselect(ctx)
	_placed_for = []

func lit(ctx: ComputerContext) -> Array[StringName]:
	if targets(ctx).is_empty():
		return [&"range"]
	var out: Array[StringName] = [&"range", &"prev", &"next"]
	if _can_steer(ctx):
		out.append(&"big")
	return out

func big_colour(ctx: ComputerContext) -> StringName:
	if not _can_steer(ctx):
		return &"dark"
	return &"amber" if ctx.sensors.course == selected else &"go"

func prompt(button: StringName, ctx: ComputerContext) -> String:
	match button:
		&"range":
			var next := (range_index + 1) % RANGES.size()
			if next == SYSTEM_RANGE:
				return "Range system"
			return "Range %d km" % roundi(RANGES[next] / 1000.0)
		&"prev":
			return "Previous target"
		&"next":
			return "Next target"
		&"big":
			return "Clear course" if ctx.sensors.course == selected else "Set course"
	return ""

func press(button: StringName, ctx: ComputerContext) -> void:
	match button:
		&"range":
			range_index = (range_index + 1) % RANGES.size()
			reselect(ctx)
		&"prev", &"next":
			var list := targets(ctx)
			if list.is_empty():
				return
			var at := -1
			for i in list.size():
				if list[i].id == selected:
					at = i
			var step := -1 if button == &"prev" else 1
			selected = list[posmod(at + step, list.size())].id if at >= 0 else list[0].id
			ctx.sensors.forget_arrival()
		&"big":
			if not _can_steer(ctx):
				return
			if ctx.sensors.course == selected:
				ctx.sensors.clear_course()
			else:
				ctx.sensors.set_course(selected)

func lines(ctx: ComputerContext) -> PackedStringArray:
	var c := selected_contact(ctx)
	if c == null:
		var where := ctx.sensors.whereabouts.text() if ctx.sensors != null and ctx.sensors.whereabouts != null else ""
		return PackedStringArray([where, "NO CONTACTS"])
	var action := ""
	if ctx.sensors.course == c.id:
		action = "COURSE SET"
	elif ctx.sensors.last_arrived == c.id:
		action = "ARRIVED"
	elif COURSE_KINDS.has(c.kind):
		action = "SET COURSE"
	return PackedStringArray([ContactText.line(c, ctx.relative(c.point).length()), action])

func holo(volume: HoloVolume, ctx: ComputerContext, delta: float) -> void:
	volume.clear_miniature()
	volume.show_map_frame(true)
	if selected_contact(ctx) == null:
		reselect(ctx)
	var frame := ctx.map_frame()
	_placed_ago += delta
	var course_id: StringName = ctx.sensors.course if ctx.sensors != null else &""
	var placing_for := [range_index, selected, course_id, volume]
	if _placed_ago >= PLACE_EVERY[range_index] or placing_for != _placed_for:
		_place(volume, ctx, frame)
		_placed_ago = 0.0
		_placed_for = placing_for
		_placed_basis = frame.basis
	volume.set_turn(frame.basis * _placed_basis.inverse())

## Places every mark afresh, in the map's frame as it is now.
func _place(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D) -> void:
	var list: Array[Contact] = targets(ctx).duplicate()
	var course := ctx.sensors.course_contact() if ctx.sensors != null else null
	if course != null and not list.any(func(c: Contact) -> bool: return c.id == course.id):
		list.append(course)   # always shown, pinned if it must be
	var time := ctx.sensors.time if ctx.sensors != null else ctx.time
	var bracketed := false
	volume.begin_marks()
	for i in list.size():
		var c: Contact = list[i]
		var placed := HoloVolume.place(ctx.relative_in(frame, c.point), range_m())
		var at: Vector3 = placed["position"]
		var pinned: bool = placed["pinned"]
		var size := PIN_SIZE if pinned else mark_size(c, range_m(), time)
		var colour := InteriorPalette.AMBER if course != null and c.id == course.id else colour_for(c.kind)
		volume.add_mark(mark_shape(c, pinned), colour, at, size)
		if not pinned and (i < STALKS or c.id == selected):
			volume.add_mark(&"stalk", InteriorPalette.LIGHT_WARM, at, 0.0)
			volume.add_mark(&"tick", InteriorPalette.LIGHT_WARM, Vector3(at.x, 0.0, at.z), TICK_SIZE)
		if c.id == selected:
			volume.show_bracket(at, size + BRACKET_GAP, true)
			bracketed = true
	if range_index == SYSTEM_RANGE:
		_place_belts(volume, ctx, frame)
	volume.end_marks()
	if not bracketed:
		volume.show_bracket(Vector3.ZERO, 0.0, false)

## A ball for anything exact (a big rock), a diamond for a ping, a sphere for
## a region, and a hollow pin for anything held at the edge.
static func mark_shape(c: Contact, pinned: bool) -> StringName:
	if pinned:
		return &"pin"
	match c.precision:
		Contact.PING:
			return &"diamond"
		Contact.REGION:
			return &"sphere"
	return &"ball"

## How big a contact's mark is at `range_m` (spec §5.2). A ping is full size
## when it is taken and shrinks until the next: by scale, since the glow
## material is shared and one mark cannot fade on its own.
static func mark_size(c: Contact, range_m: float, time: float) -> float:
	var scale := HoloVolume.RADIUS / range_m
	if c.kind == &"body":
		return clampf(c.radius * 2.0 * scale, BODY_MIN, BODY_MAX)
	match c.precision:
		Contact.PING:
			var age := clampf((time - c.taken) / maxf(c.fresh_for, 0.001), 0.0, 1.0)
			return PING_SIZE * lerpf(1.0, PING_SHRINK, age)
		Contact.REGION:
			return maxf(REGION_MIN, c.radius * 2.0 * scale)
	if range_m <= RANGES[0]:
		return maxf(ROCK_MIN_NEAR, c.radius * 2.0 * scale)
	if range_m <= RANGES[1]:
		return clampf(c.radius * 2.0 / ROCK_BIGGEST * ROCK_MAX_MID, ROCK_MIN_MID, ROCK_MAX_MID)
	return ROCK_FAR

## Each belt as a ring of ticks, on the system range.
func _place_belts(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D) -> void:
	var system := ctx.sensors.system if ctx.sensors != null else null
	if system == null:
		return
	for belt in system.belts:
		for k in BELT_TICKS:
			var angle := TAU * k / BELT_TICKS
			var point := belt.centre.plus(Vector3(cos(angle), 0.0, sin(angle)) * belt.radius)
			var placed := HoloVolume.place(ctx.relative_in(frame, point), range_m())
			if not placed["pinned"]:
				volume.add_mark(&"tick", colour_for(&"rock"), placed["position"], TICK_SIZE)

func save() -> Dictionary:
	return {"range": range_index, "selected": String(selected)}

func restore(state: Dictionary) -> void:
	range_index = clampi(int(state.get("range", OPEN_AT)), 0, RANGES.size() - 1)
	selected = StringName(state.get("selected", ""))
	_targets_key = []
	_placed_for = []

## Whether the big button does anything: a course can be set to, or cleared
## from, the selected contact.
func _can_steer(ctx: ComputerContext) -> bool:
	var c := selected_contact(ctx)
	return c != null and (COURSE_KINDS.has(c.kind) or ctx.sensors.course == c.id)
