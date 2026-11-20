extends WadooErrand

## Goes to one of their jobs (Wadoo spec §5): a garden, the glassworks (before
## its door or, since stage 5, inside at the kiln, the bench or the sand bins),
## the breach's rubble, Halla's dead garden, the pool's bank to wash, or the
## pump. At the pump they work the handle a few seconds, then carry the water
## home: to their door, or, if their home has a room, in to its water jar, where
## they pour it (§10).

const PUMP_SPAN := Vector2(6.0, 9.0)
## Pouring the water into the jar, s.
const POUR := 3.0

var _kind: StringName = &""
var _home: Dictionary = {}
var _jar: Dictionary = {}
var _carrying := false
var _poured := -1.0

func _init() -> void:
	min_time = 8.0
	span = Vector2(25.0, 45.0)
	need = &"work"
	rate = 0.03

func score(ctx: NpcContext) -> float:
	if (person(ctx).get("jobs", []) as Array).is_empty():
		return 0.0
	return Curves.ramp(ctx.need(&"work"), 0.2, 0.8) * (1.0 - ctx.need(&"fear"))

func start(ctx: NpcContext) -> void:
	_kind = &""
	_carrying = false
	_poured = -1.0
	_jar = {}
	super(ctx)
	if _kind == &"pump":
		_for = lerpf(PUMP_SPAN.x, PUMP_SPAN.y, roll(ctx, 2))
		var shell := str(person(ctx).get("home", ""))
		_home = town.door_of(shell) if town != null else {}
		_jar = town.spot_in(&"jar", shell) if town != null else {}

## One of their jobs whose spot is free, starting from one the seed and clock pick.
func choose(ctx: NpcContext) -> Dictionary:
	var jobs: Array = person(ctx).get("jobs", [])
	var first := int(roll(ctx, 3) * jobs.size())
	for i in jobs.size():
		var kind := StringName(jobs[(first + i) % jobs.size()])
		var s := town.take_spot(kind, who(ctx), ctx.position, ctx.record.seed + int(ctx.time))
		if not s.is_empty():
			_kind = kind
			return s
	return {}

func think(ctx: NpcContext) -> Intent:
	if _carrying:
		var to: Vector3 = _jar["at"] if not _jar.is_empty() else _home["at"]
		if _poured < 0.0 and flat_distance(ctx.position, to) > ARRIVED and running(ctx) < GIVE_UP:
			return Intent.go(to, WALK, &"carry")
		if not _jar.is_empty() and running(ctx) < GIVE_UP:
			if _poured < 0.0:
				if not facing(ctx, _jar["face"]):
					return Intent.idle().facing(_jar["face"])
				_poured = ctx.time
			if ctx.time - _poured < POUR:
				return Intent.idle(&"interact").facing(_jar["face"])
		_carrying = false
		_finished = true
		return Intent.idle()
	var i := super(ctx)
	if _finished and _kind == &"pump" and not _home.is_empty() and acting():
		_finished = false
		_carrying = true
	return i
