extends Behaviour

## The town has turned on you (Wadoo spec §9): while you are within the walls a
## villager runs home and goes in, out of sight, and stays in until you have been
## gone from the walls for STAY. One already indoors stays in. Cornered on the way
## (you between them and their door), they cower instead (cower, scoring higher).
## A home with a room (home_4, §10) has no out of sight: they run in to a corner at
## its back (a hide spot) and huddle there, crouched, facing the door, seen.

## A run, of top speed: 4.2 m/s at 1.6 (the look jogs past 2.4).
const RUN := 2.6
## Within this of the door's middle, they are in.
const IN := 0.45
## Out again this long after you have left the walls, s.
const STAY := 20.0
## Running longer than this, the way is blocked: they stop where they are.
const GIVE_UP := 60.0

var _in := false
var _left_at := -1.0
var _finished := false
## The corner of their home's room they huddle in, claimed; {} if their home has
## no room (they go in out of sight).
var _hide: Dictionary = {}

func _init() -> void:
	reflex = true
	threshold = 0.9
	min_time = 2.0

func score(ctx: NpcContext) -> float:
	var village := ctx.extra.get(&"village") as WadooState
	if village == null or not village.hostile or ctx.extra.get(&"town") == null:
		return 0.0
	if _in and not _finished:
		# in, they stay in until it is safe
		return 0.95
	var you: Dictionary = ctx.extra.get(&"you", {})
	if you.is_empty() or not bool(you["in_town"]):
		return 0.0
	return 0.95 if not _door(ctx).is_empty() else 0.0

func start(ctx: NpcContext) -> void:
	super(ctx)
	_finished = false
	_left_at = -1.0
	var town := ctx.extra.get(&"town") as WadooSite
	town.release(WadooErrand.who(ctx))
	town.end_pair(WadooErrand.who(ctx))
	town.mark(WadooErrand.who(ctx), &"")
	var home := str(WadooErrand.person(ctx).get("home", ""))
	_hide = town.take_spot(&"hide", WadooErrand.who(ctx), ctx.position, ctx.record.seed + int(ctx.time),
		"hide:%s:" % home) if ctx.record != null else {}
	# already in (gone home a while): they stay
	_in = town.hidden(WadooErrand.who(ctx))

func think(ctx: NpcContext) -> Intent:
	var town := ctx.extra.get(&"town") as WadooSite
	var you: Dictionary = ctx.extra.get(&"you", {})
	if not _in:
		var door := _door(ctx)
		if door.is_empty() or running(ctx) > GIVE_UP:
			_finished = true
			return Intent.idle()
		var to: Vector3 = _hide["at"] if not _hide.is_empty() else door["door"]
		if flat_distance(ctx.position, to) > IN:
			return Intent.go(to, RUN)
		_in = true
		if _hide.is_empty():
			town.hide(WadooErrand.who(ctx), true)
	if you.is_empty() or not bool(you["in_town"]):
		if _left_at < 0.0:
			_left_at = ctx.time
		if ctx.time - _left_at >= STAY:
			_in = false
			_finished = true
			if _hide.is_empty():
				town.hide(WadooErrand.who(ctx), false)
			else:
				town.release(WadooErrand.who(ctx))
	else:
		_left_at = -1.0
	if not _hide.is_empty() and not _finished:
		return Intent.idle(&"cower").facing(_hide["face"])
	return Intent.idle()

func done(_ctx: NpcContext) -> bool:
	return _finished

## Their home's door ({at, door, out}), or {}.
static func _door(ctx: NpcContext) -> Dictionary:
	var town := ctx.extra.get(&"town") as WadooSite
	return town.door_of(str(WadooErrand.person(ctx).get("home", ""))) if town != null else {}
