extends Behaviour

## Talks with someone (Wadoo spec §5): asks the town for a partner who wants
## company too, or answers one who asked; both meet halfway, face each other and
## talk by turns, nodding as they listen.

const WALK := 0.75
const ARRIVED := 0.3
const SPAN := Vector2(20.0, 40.0)
const RATE := 0.04
## Speaking and listening by turns, this long each, s.
const TURN := 4.5
## Finding no one, it does not ask again for this long, s.
const ALONE_FOR := 20.0

var _until := 0.0
var _finished := false
var _alone_until := -INF

func _init() -> void:
	min_time = 6.0

func score(ctx: NpcContext) -> float:
	if ctx.extra.get(&"indoors", false):
		return 0.0
	if not (ctx.extra.get(&"pair", {}) as Dictionary).is_empty():
		return 0.95
	if ctx.time < _alone_until:
		return 0.0
	return Curves.ramp(ctx.need(&"company"), 0.45, 0.9) * 0.9 * (1.0 - ctx.need(&"fear"))

func start(ctx: NpcContext) -> void:
	super(ctx)
	var town := ctx.extra.get(&"town") as WadooSite
	var pair: Dictionary = ctx.extra.get(&"pair", {})
	if pair.is_empty() and town != null:
		pair = town.ask_pair(WadooErrand.who(ctx))
		ctx.extra[&"pair"] = pair
	if town != null:
		town.mark(WadooErrand.who(ctx), &"")
	_finished = pair.is_empty()
	if _finished:
		_alone_until = ctx.time + ALONE_FOR
	_until = ctx.time + lerpf(SPAN.x, SPAN.y, WadooErrand.roll(ctx, 5))

func think(ctx: NpcContext) -> Intent:
	var pair: Dictionary = ctx.extra.get(&"pair", {})
	if pair.is_empty():
		_finished = true
		return Intent.idle()
	var at: Vector3 = pair["at"]
	var face: Vector3 = pair["face"]
	if flat_distance(ctx.position, at) > ARRIVED:
		if running(ctx) > WadooErrand.GIVE_UP:
			_end(ctx)
		return Intent.go(at, WALK).facing(face)
	ctx.ease(&"company", RATE)
	if ctx.time >= _until:
		_end(ctx)
	return Intent.idle(_action(ctx, pair)).facing(face)

func _end(ctx: NpcContext) -> void:
	_finished = true
	var town := ctx.extra.get(&"town") as WadooSite
	if town != null:
		town.end_pair(WadooErrand.who(ctx))

## Speaking on its turns; listening, with a nod now and then, on its partner's.
func _action(ctx: NpcContext, pair: Dictionary) -> StringName:
	var first := String(WadooErrand.who(ctx)) < String(pair["partner"])
	var turn := int(ctx.time / TURN)
	if (turn % 2 == 0) == first:
		return &"talk"
	return &"nod" if fposmod(ctx.time, TURN) < 1.2 and turn % 3 == 1 else &""

func done(_ctx: NpcContext) -> bool:
	return _finished
