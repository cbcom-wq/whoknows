extends WadooErrand

## Goes home for a while (Wadoo spec §5): walks to their door and in, out of
## sight (the town hides them), then comes out again.

## Within this of the door's middle, it is in.
const IN := 0.45

var _in := false

func _init() -> void:
	min_time = 10.0
	span = Vector2(40.0, 90.0)
	need = &"home"
	rate = 0.02

func score(ctx: NpcContext) -> float:
	if ctx.extra.get(&"indoors", false):
		# indoors it stays until its time is up
		return 1.0
	return Curves.ramp(ctx.need(&"home"), 0.5, 0.95) * (1.0 - ctx.need(&"fear"))

func start(ctx: NpcContext) -> void:
	_in = false
	super(ctx)

## The door's middle, facing in.
func choose(ctx: NpcContext) -> Dictionary:
	var door := town.door_of(str(person(ctx).get("home", "")))
	if door.is_empty():
		return {}
	return {"key": "", "at": door["door"], "face": door["door"], "action": &""}

func think(ctx: NpcContext) -> Intent:
	if spot.is_empty():
		return Intent.idle()
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
