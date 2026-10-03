class_name MapPage
extends ComputerPage

## The map (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §5):
## what the ship's sensors know, shrunk into the holo and turned with the
## ship. The map is one continuous scale (computer mode spec §4), zoomed a
## notch of the wheel at a time, with RANGE stepping through the stops 2, 10,
## 50 and 500 km and the whole system. ◀ and ▶ pick a contact, nearest first;
## the big button sets or clears the course (§6) to a big rock or salvage. It
## shows only what the sensors report: a ping where the ping says, a region as
## its sphere, never the thing's true place.
##
## Zoomed out (docs/superpowers/specs/2026-09-28-warp-design.md §7) the centre
## slides from the ship to the star (§4.2) and it is drawn like an orrery: the
## ship's pip and heading, scale rings every 2,500 km, worlds by class, lit
## when your QE reaches them, each target's warp limit, and the charted warp's
## line; the big button charts a warp. What the ship's neighbours are leaves
## the map by shrinking as you zoom out (§4.3), and warp limits are drawn at
## any scale.
##
## Every kind the sensors know is drawn in its own colour: rocks SKY, salvage
## QUANTUM, signs of life SIGNAL_GO (the HUD's green), and the course AMBER.

## The map's stops (the world scale spec §3.5): what RANGE steps through, 2,
## 10, 50 and 500 km round the ship, and the whole system round the star.
const STOPS: Array[float] = [2000.0, 10000.0, 50000.0, 500000.0, 9000000.0]
## The last stop is the whole system (the system skeleton spec §10), drawn round
## the star out to SYSTEM_REACH (the warp spec §7.1). 500 km holds a planet and
## its moons.
const SYSTEM_RANGE := 4
const SYSTEM_REACH := 9000000.0
## How far in and out the map zooms (computer mode spec §4.1), and how much one
## notch of the wheel changes it.
const SCALE_MIN := 1000.0
const SCALE_MAX := SYSTEM_REACH
const ZOOM_STEP := 1.3
## How quickly the drawn scale catches up with the chosen one, seconds: RANGE
## glides between stops instead of cutting.
const GLIDE := 0.1
## What the sensors are asked for: the whole system (each source stops at its
## own reach).
const QUERY := 20000000.0
## The centre slides from the ship to the star between these scales (computer
## mode spec §4.2): your planet and its moons round you up to 500 km, the
## orrery from 3,000 km.
const SHIP_CENTRED := 500000.0
const STAR_CENTRED := 3000000.0
## Rings of faint ticks round the ship, every SCALE_RING out to the rim.
const SCALE_RING := 2500000.0
const SCALE_TICKS := 32
## Each warp target's limit, as a ring of faint ticks, at any scale.
const LIMIT_TICKS := 24
## The charted warp's line.
const LINE_TICKS := 24
const SHIP_PIP := 0.014
const HEADING_TICK := 0.025
## Mark sizes by class once the map is round the star (the warp spec §7.1).
const CLASS_SIZE := {&"star": 0.06, &"large": 0.04, &"medium": 0.03, &"small": 0.02, &"cluster": 0.01}
## A planet this big is large; this big, medium (the world scale spec §3.1).
const LARGE := 45000.0
const MEDIUM := 30000.0
## A cluster is drawn as a clump of three balls this far apart.
const CLUMP := 0.008
const MOON_SIZE := 0.012
const TARGET_KINDS: Array[StringName] = [&"body", &"moon", &"cluster"]
const OPEN_AT := 1
## Contacts that get a stalk, nearest first; the selected one always does.
const STALKS := 12
## What a course can be set to (spec §15): a big rock or a salvage cloud.
const COURSE_KINDS: Array[StringName] = [&"rock", &"salvage", &"body", &"moon", &"cluster"]
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
## Each belt's ring of ticks, once the scale is past 500 km.
const BELT_TICKS := 48
const PING_SIZE := 0.018
## A ping shrinks to this share of its size by its next refresh.
const PING_SHRINK := 0.4
const PIN_SIZE := 0.016
const TICK_SIZE := 0.01
const BRACKET_GAP := 0.012
## The bands things leave the map across as you zoom out (computer mode spec
## §4.3): full size up to x, gone by y.
const NEAR_BAND := Vector2(10000.0, 20000.0)
const ROCK_BAND := Vector2(50000.0, 100000.0)
## Belts and scale rings grow in across this band.
const WIDE_BAND := Vector2(500000.0, 1000000.0)
## A mark shrunk smaller than this is not placed.
const SMALLEST := 0.001

## The scale chosen: metres from the holo's centre to its edge.
var scale_m := STOPS[OPEN_AT]
## The nearest stop. Setting it jumps there with no glide (a restore, a test).
var range_index: int:
	get:
		return stop_index()
	set(value):
		scale_m = STOPS[clampi(value, 0, STOPS.size() - 1)]
		_shown_m = scale_m
## The scale the holo is drawn at, easing towards scale_m.
var _shown_m := STOPS[OPEN_AT]
var selected: StringName = &""

## What the last placing put in the holo that a click can take (computer mode
## spec §4.5): each target's {id, position}, in the frame the marks were
## placed in -- HoloVolume.marks_to_global finds it in the world. Only
## full-size targets: a mark still shrinking away is drawn but not pickable.
var placed_marks: Array[Dictionary] = []

var _targets: Array[Contact] = []
var _targets_key := []
var _shown: Array[Contact] = []
var _shown_key := []
## When the marks were last placed, what they were placed for, and the map's
## frame then.
var _placed_ago := INF
var _placed_for := []
var _placed_basis := Basis.IDENTITY

func range_m() -> float:
	return scale_m

func shown_m() -> float:
	return _shown_m

## How far the centre has slid from the ship to the star at `scale`: 0 up to
## SHIP_CENTRED, 1 from STAR_CENTRED, smooth in log scale between.
static func system_weight(scale: float) -> float:
	return smoothstep(log(SHIP_CENTRED), log(STAR_CENTRED), log(scale))

## 1 up to band.x, 0 from band.y, smooth in log scale between.
static func fade(scale: float, band: Vector2) -> float:
	return 1.0 - smoothstep(log(band.x), log(band.y), log(scale))

## How much of its size a contact's mark keeps at `scale`.
static func shrink(c: Contact, scale: float) -> float:
	match c.kind:
		&"salvage", &"life":
			return fade(scale, NEAR_BAND)
		&"rock":
			return fade(scale, ROCK_BAND)
	return 1.0

func title() -> String:
	if system_weight(scale_m) >= 1.0:
		return "MAP · SYSTEM"
	if scale_m < 2000.0:
		return "MAP · %.1f KM" % (scale_m / 1000.0)
	return "MAP · %d KM" % roundi(scale_m / 1000.0)

## The stop nearest the scale, in log terms.
func stop_index() -> int:
	var best := 0
	for i in STOPS.size():
		if absf(log(STOPS[i] / scale_m)) < absf(log(STOPS[best] / scale_m)):
			best = i
	return best

## Where RANGE goes next: the first stop above the scale, or back to the first.
func next_stop() -> int:
	for i in STOPS.size():
		if STOPS[i] > scale_m * 1.001:
			return i
	return 0

## Zooms by `notches` of the wheel: in for negative, out for positive. The
## selection stays while it is still on the map.
func zoom(notches: float, ctx: ComputerContext) -> void:
	scale_m = clampf(scale_m * pow(ZOOM_STEP, notches), SCALE_MIN, SCALE_MAX)
	if selected_contact(ctx) == null:
		reselect(ctx)

## Whether the drawn scale is still catching up with the chosen one.
func gliding() -> bool:
	return absf(log(_shown_m / scale_m)) > 0.001

func _glide(delta: float) -> void:
	if not gliding():
		_shown_m = scale_m
		return
	_shown_m = exp(lerpf(log(_shown_m), log(scale_m), 1.0 - exp(-delta / GLIDE)))

## The colour a contact of `kind` is drawn in.
static func colour_for(kind: StringName) -> Color:
	match kind:
		&"rock":
			return InteriorPalette.SKY
		&"salvage":
			return InteriorPalette.QUANTUM
		&"life":
			return InteriorPalette.SIGNAL_GO
		&"body", &"moon":
			return InteriorPalette.WORLD
		&"cluster":
			return InteriorPalette.SKY
	return InteriorPalette.LIGHT_WARM

## What ◀ and ▶ step through, and the overlay lists: the contacts inside the
## holo at full size, nearest the ship first. Once the map is round the star,
## worlds only. Worked out once a frame.
func targets(ctx: ComputerContext) -> Array[Contact]:
	var key := [Engine.get_process_frames(), scale_m, ctx.sensors]
	if key == _targets_key:
		return _targets
	_targets_key = key
	_targets = []
	if ctx.sensors == null:
		return _targets
	var frame := ctx.map_frame()
	var system_view := system_weight(scale_m) > 0.5
	var centre := _centre(ctx, frame, scale_m)
	for c in ctx.sensors.contacts(QUERY):
		if system_view and not TARGET_KINDS.has(c.kind):
			continue
		if shrink(c, scale_m) < 0.999:
			continue
		if (ctx.relative_in(frame, c.point) - centre).length() > scale_m + c.radius:
			continue
		_targets.append(c)
	return _targets

## What is drawn: every contact inside the holo at the scale shown that has
## not shrunk away, nearest the ship first. Wider than targets(), which is only
## what is at full size at the scale chosen, so a mark can be seen shrinking
## across its band (spec §4.3) without ever being something ◀ and ▶ stop at.
## Worked out once a frame.
func shown(ctx: ComputerContext) -> Array[Contact]:
	var key := [Engine.get_process_frames(), _shown_m, ctx.sensors]
	if key == _shown_key:
		return _shown
	_shown_key = key
	_shown = []
	if ctx.sensors == null:
		return _shown
	var frame := ctx.map_frame()
	var system_view := system_weight(_shown_m) > 0.5
	var centre := _centre(ctx, frame, _shown_m)
	for c in ctx.sensors.contacts(QUERY):
		if system_view and not TARGET_KINDS.has(c.kind):
			continue
		if shrink(c, _shown_m) <= 0.0:
			continue
		if (ctx.relative_in(frame, c.point) - centre).length() > _shown_m + c.radius:
			continue
		_shown.append(c)
	return _shown

## Contact `id` as the sensors know it, or null.
static func contact_by_id(ctx: ComputerContext, id: StringName) -> Contact:
	return ctx.sensors.contact(id) if ctx.sensors != null else null

func selected_contact(ctx: ComputerContext) -> Contact:
	for c in targets(ctx):
		if c.id == selected:
			return c
	return null

## After a change of page or scale: the course if it is among the targets,
## else the nearest.
func reselect(ctx: ComputerContext) -> void:
	_targets_key = []
	_shown_key = []
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
	var t := _warp_target(ctx)
	if t != null:
		return &"amber" if ctx.warp.charted == t.id else &"go"
	if not _can_steer(ctx):
		return &"dark"
	return &"amber" if ctx.sensors.course == selected else &"go"

func prompt(button: StringName, ctx: ComputerContext) -> String:
	match button:
		&"range":
			var next := next_stop()
			if next == SYSTEM_RANGE:
				return "Range system"
			return "Range %d km" % roundi(STOPS[next] / 1000.0)
		&"prev":
			return "Previous target"
		&"next":
			return "Next target"
		&"big":
			var t := _warp_target(ctx)
			if t != null:
				return "Clear warp" if ctx.warp.charted == t.id else "Chart warp"
			return "Clear course" if ctx.sensors.course == selected else "Set course"
	return ""

func press(button: StringName, ctx: ComputerContext) -> void:
	match button:
		&"range":
			scale_m = STOPS[next_stop()]
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
			var t := _warp_target(ctx)
			if t != null:
				if ctx.warp.charted == t.id:
					ctx.warp.clear_chart()
				else:
					ctx.warp.chart(t.id)
				return
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
	var t := _warp_target(ctx)
	if t != null:
		return warp_lines(ctx, t)
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
	volume.show_chevron(system_weight(_shown_m) <= 0.01)
	_glide(delta)
	if selected_contact(ctx) == null:
		reselect(ctx)
	var frame := ctx.map_frame()
	_placed_ago += delta
	var course_id: StringName = ctx.sensors.course if ctx.sensors != null else &""
	var placing_for := [_shown_m, selected, course_id, volume]
	if _placed_ago >= place_every() or placing_for != _placed_for:
		_place(volume, ctx, frame)
		_placed_ago = 0.0
		_placed_for = placing_for
		_placed_basis = frame.basis
	volume.set_turn(frame.basis * _placed_basis.inverse())

## How often the marks are placed afresh, seconds: every frame up close, twice
## a second further out, where there are hundreds (and a ship at 300 m/s moves
## a pip 2 mm a second at 50 km). In between they are only turned with the ship
## (HoloVolume.set_turn). Every frame too while the scale glides, since
## placing_for holds the drawn scale.
func place_every() -> float:
	return 0.0 if _shown_m <= STOPS[1] * 1.001 else 0.5

## Places every mark afresh, in the map's frame as it is now.
func _place(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D) -> void:
	var list: Array[Contact] = shown(ctx).duplicate()
	var course := ctx.sensors.course_contact() if ctx.sensors != null else null
	if course != null and not list.any(func(c: Contact) -> bool: return c.id == course.id):
		list.append(course)   # always shown, pinned if it must be
	var time := ctx.sensors.time if ctx.sensors != null else ctx.time
	var w := system_weight(_shown_m)
	var bracketed := false
	var target_ids := {}
	for t in targets(ctx):
		target_ids[t.id] = true
	volume.begin_marks()
	placed_marks.clear()
	for i in list.size():
		var c: Contact = list[i]
		var placed := _placed(ctx, frame, c.point)
		var at: Vector3 = placed["position"]
		var pinned: bool = placed["pinned"]
		var is_course := course != null and c.id == course.id
		# The course is always shown, so it never shrinks away.
		var size := PIN_SIZE if pinned else mark_size(c, _shown_m, time) * (1.0 if is_course else shrink(c, _shown_m))
		if size < SMALLEST:
			continue
		var colour := InteriorPalette.AMBER if is_course else reach_colour(ctx, c)
		if w > 0.5 and c.kind == &"cluster" and not pinned:
			for o in [Vector3(-CLUMP, 0, 0), Vector3(CLUMP, 0, 0), Vector3(0, 0, CLUMP)]:
				volume.add_mark(&"ball", colour, at + o, size)
		else:
			volume.add_mark(mark_shape(c, pinned), colour, at, size)
		if target_ids.has(c.id):
			placed_marks.append({"id": c.id, "position": at})
		if not pinned and (i < STALKS or c.id == selected):
			volume.add_mark(&"stalk", InteriorPalette.LIGHT_WARM, at, 0.0)
			volume.add_mark(&"tick", InteriorPalette.LIGHT_WARM, Vector3(at.x, 0.0, at.z), TICK_SIZE)
		if c.id == selected:
			volume.show_bracket(at, size + BRACKET_GAP, true)
			bracketed = true
	_place_belts(volume, ctx, frame)
	if w > 0.01:
		_place_ship(volume, ctx, frame)
	_place_rings(volume, ctx, frame)
	_place_limits(volume, ctx, frame, list)
	_place_chart(volume, ctx, frame)
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

## How big a contact's mark is at the scale `range_m` (spec §5.2). A ping is
## full size when it is taken and shrinks until the next: by scale, since the
## glow material is shared and one mark cannot fade on its own.
static func mark_size(c: Contact, range_m: float, time: float) -> float:
	var scale := HoloVolume.RADIUS / range_m
	if c.kind == &"body" or c.kind == &"moon" or c.kind == &"cluster":
		if system_weight(range_m) > 0.5:
			return MOON_SIZE if c.kind == &"moon" else CLASS_SIZE[size_class(c)]
		return clampf(c.radius * 2.0 * scale, BODY_MIN, BODY_MAX)
	match c.precision:
		Contact.PING:
			var age := clampf((time - c.taken) / maxf(c.fresh_for, 0.001), 0.0, 1.0)
			return PING_SIZE * lerpf(1.0, PING_SHRINK, age)
		Contact.REGION:
			return maxf(REGION_MIN, c.radius * 2.0 * scale)
	if range_m <= STOPS[0]:
		return maxf(ROCK_MIN_NEAR, c.radius * 2.0 * scale)
	if range_m <= STOPS[1]:
		return clampf(c.radius * 2.0 / ROCK_BIGGEST * ROCK_MAX_MID, ROCK_MIN_MID, ROCK_MAX_MID)
	return ROCK_FAR

## Each belt as a ring of ticks, growing in past 500 km.
func _place_belts(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D) -> void:
	var system := ctx.sensors.system if ctx.sensors != null else null
	var grow := 1.0 - fade(_shown_m, WIDE_BAND)
	if system == null or grow * TICK_SIZE < SMALLEST:
		return
	for belt in system.belts:
		for k in BELT_TICKS:
			var angle := TAU * k / BELT_TICKS
			var point := belt.centre.plus(Vector3(cos(angle), 0.0, sin(angle)) * belt.radius)
			var placed := _placed(ctx, frame, point)
			if not placed["pinned"]:
				volume.add_mark(&"tick", colour_for(&"rock"), placed["position"], TICK_SIZE * grow)

## A world's class, for its mark and the screen (the warp spec §7.1).
static func size_class(c: Contact) -> StringName:
	if c.kind == &"cluster":
		return &"cluster"
	if c.id == &"body:star":
		return &"star"
	return size_class_of_radius(c.radius)

static func size_class_of_radius(radius: float) -> StringName:
	if radius >= LARGE:
		return &"large"
	if radius >= MEDIUM:
		return &"medium"
	return &"small"

## Where `point` sits in the holo at the scale shown: round the ship up close,
## round the star far out, and between the two while the centre slides.
func holo_position(ctx: ComputerContext, frame: Transform3D, point: UniversePoint) -> Vector3:
	return _placed(ctx, frame, point)["position"]

## `point` from the holo's centre, in the map's frame, at `scale`: the centre
## slides from the ship to the star as the scale grows (spec §4.2).
func _from_centre(ctx: ComputerContext, frame: Transform3D, point: UniversePoint, scale: float) -> Vector3:
	return ctx.relative_in(frame, point) - _centre(ctx, frame, scale)

## Where the holo's centre is at `scale`, from the ship, in the map's frame:
## the ship's own place until the centre starts to slide, the star's at the end.
## Worked out once for a loop over contacts, not once for each.
func _centre(ctx: ComputerContext, frame: Transform3D, scale: float) -> Vector3:
	var system := ctx.sensors.system if ctx.sensors != null else null
	var w := system_weight(scale)
	if w > 0.0 and system != null:
		return ctx.relative_in(frame, system.star.point) * w
	return Vector3.ZERO

func _placed(ctx: ComputerContext, frame: Transform3D, point: UniversePoint) -> Dictionary:
	return HoloVolume.place(_from_centre(ctx, frame, point, _shown_m), _shown_m)

## Lit in the kind's colour if your QE reaches it, dim if not (the warp spec
## §7.1). Before the map is round the star, or without a drive, always lit.
func reach_colour(ctx: ComputerContext, c: Contact) -> Color:
	var lit := colour_for(c.kind)
	if system_weight(_shown_m) <= 0.5 or ctx.warp == null or ctx.store == null or ctx.sensors == null:
		return lit
	var t := ctx.warp.target_for(c.id)
	var focus := ctx.sensors.focus_point()
	if t == null or focus == null:
		return lit
	var travel := t.point.minus(focus).length() - t.limit
	return lit if WarpPlan.cost_of(travel) <= ctx.store.amount else InteriorPalette.HOLO_DIM

## The ship's pip and heading.
func _place_ship(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D) -> void:
	var focus := ctx.sensors.focus_point() if ctx.sensors != null else null
	if focus == null:
		return
	var pip: Vector3 = _placed(ctx, frame, focus)["position"]
	volume.add_mark(&"ball", InteriorPalette.LIGHT_WARM, pip, SHIP_PIP)
	volume.add_mark(&"tick", InteriorPalette.LIGHT_WARM, pip + Vector3(0, 0, -HEADING_TICK), TICK_SIZE)

## Faint rings round the ship every SCALE_RING, growing in past 500 km.
func _place_rings(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D) -> void:
	var focus := ctx.sensors.focus_point() if ctx.sensors != null else null
	var grow := 1.0 - fade(_shown_m, WIDE_BAND)
	if focus == null or grow * TICK_SIZE < SMALLEST:
		return
	var r := SCALE_RING
	while r <= SYSTEM_REACH * 2.0:
		for k in SCALE_TICKS:
			var a := TAU * k / SCALE_TICKS
			var placed := _placed(ctx, frame, focus.plus(frame.basis.inverse() * Vector3(cos(a), 0.0, sin(a)) * r))
			if not placed["pinned"]:
				volume.add_mark(&"tick", InteriorPalette.HOLO_DIM, placed["position"], TICK_SIZE * grow)
		r += SCALE_RING

## Each target's warp limit as a ring of ticks, at any scale; the blocker's in
## CORAL.
func _place_limits(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D, list: Array[Contact]) -> void:
	if ctx.warp == null:
		return
	var blocker: WarpTarget = ctx.warp.plan.blocker if ctx.warp.plan.status == WarpPlan.Status.BLOCKED else null
	for c in list:
		var t := ctx.warp.target_for(c.id)
		if t == null:
			continue
		var colour := InteriorPalette.CORAL if t == blocker else InteriorPalette.HOLO_DIM
		for k in LIMIT_TICKS:
			var a := TAU * k / LIMIT_TICKS
			var placed := _placed(ctx, frame, t.point.plus(frame.basis.inverse() * Vector3(cos(a), 0.0, sin(a)) * t.limit))
			if not placed["pinned"]:
				volume.add_mark(&"tick", colour, placed["position"], TICK_SIZE)

## The charted warp's line, from the ship to the drop-out point.
func _place_chart(volume: HoloVolume, ctx: ComputerContext, frame: Transform3D) -> void:
	if ctx.warp == null or ctx.warp.target() == null or ctx.sensors == null:
		return
	var focus := ctx.sensors.focus_point()
	var t := ctx.warp.target()
	if focus == null:
		return
	var line := t.point.minus(focus)
	var drop := focus.plus(line.normalized() * maxf(line.length() - t.limit, 0.0))
	for k in LINE_TICKS:
		var placed := _placed(ctx, frame, focus.plus(drop.minus(focus) * (float(k) + 0.5) / LINE_TICKS))
		if not placed["pinned"]:
			volume.add_mark(&"tick", InteriorPalette.AMBER, placed["position"], TICK_SIZE)

## The warp target selected once the map is round the star, if there is a drive.
func _warp_target(ctx: ComputerContext) -> WarpTarget:
	if system_weight(scale_m) <= 0.5 or ctx.warp == null:
		return null
	var c := selected_contact(ctx)
	return ctx.warp.target_for(c.id) if c != null else null

## The selected warp target's three lines (the warp spec §7.2): what and how
## big; how far, by flying and by warp; and what a warp there costs.
func warp_lines(ctx: ComputerContext, t: WarpTarget) -> PackedStringArray:
	var focus := ctx.sensors.focus_point()
	var d := t.point.minus(focus).length() if focus != null else 0.0
	var what := ""
	match t.kind:
		WarpTarget.Kind.STAR:
			what = "STAR · %d KM ACROSS" % roundi(t.radius * 2.0 / 1000.0)
		WarpTarget.Kind.CLUSTER:
			what = "BELT · %d KM ACROSS" % roundi(t.radius * 2.0 / 1000.0)
		WarpTarget.Kind.MOON:
			what = "MOON · %d KM ACROSS" % roundi(t.radius * 2.0 / 1000.0)
		_:
			var cls := String(size_class_of_radius(t.radius)).to_upper()
			what = "PLANET · %s · %d KM ACROSS" % [cls, roundi(t.radius * 2.0 / 1000.0)]
	var travel := d - t.limit
	var how := "%d KM · %s" % [roundi(d / 1000.0), flying_text(d)]
	if travel >= WarpPlan.MIN_TRAVEL:
		how += " · %d S WARP" % roundi(WarpDrive.SPOOL + WarpProfile.new(travel).duration)
	var cost := ""
	if ctx.warp.charted == t.id:
		cost = "WARP CHARTED"
	else:
		var p := WarpPlan.check(focus, Vector3.FORWARD, t, ctx.warp.system.warp_targets(), [], ctx.store)
		match p.status:
			WarpPlan.Status.CLOSE:
				cost = "FLY · TOO CLOSE TO WARP"
			WarpPlan.Status.BLOCKED:
				cost = "BLOCKED BY %s" % p.blocker.name
			WarpPlan.Status.LOW_POWER:
				cost = "WARP · LOW POWER"
			WarpPlan.Status.NO_QE:
				cost = "NEED %d QE · STORE %d" % [p.cost, ctx.store.amount]
			_:
				cost = "WARP %d QE · IN REACH" % p.cost
	return PackedStringArray(["%s · %s" % [t.name, what], how, cost])

## How long `metres` takes at the cruise ceiling: minutes, or hours past 90
## minutes -- most trips at the world scale are hours of flying, which is
## why you warp.
static func flying_text(metres: float) -> String:
	var minutes := metres / FlightComputer.CRUISE_LIMIT_MPS / 60.0
	if minutes > 90.0:
		return "%d H FLYING" % roundi(minutes / 60.0)
	return "%d MIN FLYING" % maxi(1, roundi(minutes))

func save() -> Dictionary:
	return {"scale": scale_m, "selected": String(selected)}

## A save from before the computer mode holds a stop's index as "range".
func restore(state: Dictionary) -> void:
	if state.has("scale"):
		scale_m = clampf(float(state["scale"]), SCALE_MIN, SCALE_MAX)
	else:
		scale_m = STOPS[clampi(int(state.get("range", OPEN_AT)), 0, STOPS.size() - 1)]
	_shown_m = scale_m
	selected = StringName(state.get("selected", ""))
	_targets_key = []
	_shown_key = []
	_placed_for = []

## Whether the big button does anything: a course can be set to, or cleared
## from, the selected contact.
func _can_steer(ctx: ComputerContext) -> bool:
	var c := selected_contact(ctx)
	return c != null and (COURSE_KINDS.has(c.kind) or ctx.sensors.course == c.id)
