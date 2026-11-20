extends WadooErrand

## Goes home for a while (Wadoo spec §5, §10). A home with a room (home_4) is
## walked into: they take one of its spots (a stool at the table, the loom, a
## bedroll to tidy) and are seen there; at the table they sit, talking by turns
## with whoever else sits at it, and get up (Sitting_Exit) before they go on. Any
## other home, they walk to its door and in, out of sight (the town hides them),
## then come out again.

## Within this of the door's middle, it is in.
const IN := 0.45
const RISE := 1.4
## Talking and quiet by turns at the table, this long each, s.
const TURN := 6.0

var _in := false
## Their home has a room, and they are going to (or are at) a spot in it.
var _room := false
var _shell := ""
var _rising := -1.0

func _init() -> void:
	min_time = 10.0
	span = Vector2(40.0, 90.0)
	need = &"home"
	rate = 0.02

func score(ctx: NpcContext) -> float:
	if ctx.extra.get(&"indoors", false):
		# indoors it stays until its time is up
		return 1.0
	if _room and not _finished and (acting() or _rising >= 0.0):
		# so in its room: easing home would let a walk to mourn or talk pull a
		# sitter up after ten seconds
		return 1.0
	return Curves.ramp(ctx.need(&"home"), 0.5, 0.95) * (1.0 - ctx.need(&"fear"))

func start(ctx: NpcContext) -> void:
	_in = false
	_room = false
	_rising = -1.0
	_shell = str(person(ctx).get("home", ""))
	super(ctx)

## A spot in their home's room if it has one, else their door's middle, facing in.
func choose(ctx: NpcContext) -> Dictionary:
	var inside := town.take_spot(&"home", who(ctx), ctx.position, ctx.record.seed + int(ctx.time),
		"home:%s:" % _shell)
	if not inside.is_empty():
		_room = true
		return inside
	var door := town.door_of(_shell)
	if door.is_empty():
		return {}
	return {"key": "", "at": door["door"], "face": door["door"], "action": &""}

func think(ctx: NpcContext) -> Intent:
	if spot.is_empty():
		return Intent.idle()
	if _room:
		return _at_home(ctx)
	if not _in:
		if flat_distance(ctx.position, spot["at"]) > IN:
			if running(ctx) > GIVE_UP:
				_finished = true
			return Intent.go(spot["at"], WALK)
		_in = true
		_since = ctx.time
		town.hide(who(ctx), true)
	ctx.ease(need, rate)
	if ctx.time - _since >= _for:
		_in = false
		_finished = true
		town.hide(who(ctx), false)
	return Intent.idle()

## In the room: the errand at their spot, seated at the table (as on a bench).
func _at_home(ctx: NpcContext) -> Intent:
	if _rising >= 0.0:
		if ctx.time - _rising >= RISE:
			_finished = true
			town.release(who(ctx))
			town.mark(who(ctx), &"")
		return Intent.idle(&"rise")
	var i := super.think(ctx)
	if acting() and not _finished:
		town.mark(who(ctx), &"seated" if spot["action"] == &"sit" else &"home")
	return i

## Seated, they get up before letting the stool go.
func finish(ctx: NpcContext) -> void:
	if _room and acting() and spot["action"] == &"sit":
		_rising = ctx.time
		return
	super(ctx)
	if town != null:
		town.mark(who(ctx), &"")

## At the table, talking by turns with whoever else sits at it.
func action(ctx: NpcContext) -> StringName:
	if spot["action"] != &"sit" or town == null:
		return spot["action"]
	if town.company_in(&"home", _shell, &"sit", who(ctx)) and int((ctx.time + roll(ctx, 4) * TURN) / TURN) % 2 == 0:
		return &"sit_talk"
	return &"sit"
