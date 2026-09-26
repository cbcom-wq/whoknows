extends Behaviour

## Tends a job aboard (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §14.2-§14.3): walks to the one done longest ago -- less for being far, never
## the one you stand at -- works at it a few seconds, and chirps when done.

const SPEED := 0.55
const ARRIVED := 0.2
const WORK_MIN := 4.0
const WORK_MAX := 8.0
## Each metre away counts as this many seconds more recent.
const PER_METRE := 0.1
## A job within this of the player is left alone.
const NOT_BY_YOU := 1.5

var _spot: Dictionary = {}
var _working_since := -1.0
var _work_for := 0.0
var _finished := false

func _init() -> void:
	min_time = 6.0

func score(ctx: NpcContext) -> float:
	if ctx.spots.is_empty():
		return 0.0
	return Curves.ramp(ctx.need(&"duty"), 0.2, 0.8) * (1.0 - ctx.need(&"fear"))

func start(ctx: NpcContext) -> void:
	super(ctx)
	_spot = choose(ctx)
	_working_since = -1.0
	_finished = _spot.is_empty()
	_work_for = WORK_MIN + fposmod(float(ctx.record.seed if ctx.record != null else 0) * 0.618 + ctx.time * 0.37,
		1.0) * (WORK_MAX - WORK_MIN)

## The job to do next.
static func choose(ctx: NpcContext) -> Dictionary:
	var you: Variant = player_at(ctx)
	var best := {}
	var best_score := -INF
	for spot in ctx.spots:
		var at: Vector3 = spot["at"]
		if you != null and flat_distance(at, you) < NOT_BY_YOU:
			continue
		var s := float(spot["since"]) - PER_METRE * flat_distance(at, ctx.position)
		if s > best_score:
			best = spot
			best_score = s
	return best

func think(ctx: NpcContext) -> Intent:
	if _spot.is_empty():
		return Intent.idle()
	var at: Vector3 = _spot["at"]
	if _working_since < 0.0 and flat_distance(ctx.position, at) > ARRIVED:
		return Intent.go(at, SPEED)
	if _working_since < 0.0:
		_working_since = ctx.time
	ctx.ease(&"duty", 0.15)
	if ctx.time - _working_since >= _work_for:
		_finished = true
		var told: Variant = ctx.extra.get(&"tended")
		if told is Callable:
			(told as Callable).call(_spot["key"], ctx.time)
		ctx.voice = &"droid_chirp"
	return Intent.idle(_spot["action"]).facing(at + Vector3(_spot["facing"]))

func done(_ctx: NpcContext) -> bool:
	return _finished
