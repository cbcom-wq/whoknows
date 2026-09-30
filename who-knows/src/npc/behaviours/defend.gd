extends Behaviour

## Bites back (docs/superpowers/specs/2026-09-29-health-and-damage-design.md
## §5.4): hurt with you close by, or badly frightened with you right on top
## of it, a skitter turns on you, lunges and bites, at most every BITE_EVERY.
## It gives up once you are GIVE_UP away or it calms down. Shot from further
## off it only scatters. The bite itself is the body's doing: this asks for
## it with the action &"bite" (the mind never touches the world).

const HURT_FRESH := 3.0
const GIVE_UP := 6.0
const CORNERED := 2.0
const CORNERED_FEAR := 0.7
const CALM_FEAR := 0.3
const BITE_REACH := 1.0
const BITE_EVERY := 1.5
const SPEED := 1.0
## Hurt with you near: over scatter's touch, with the species' weight.
const HURT_SCORE := 1.0
const CORNERED_SCORE := 0.8
## Already fighting and you are still near.
const ENGAGED_SCORE := 0.7

var _engaged := false
var _last_bite := -INF

func _init() -> void:
	reflex = true
	threshold = 0.6
	min_time = 1.0

func score(ctx: NpcContext) -> float:
	if ctx.player == null:
		return 0.0
	var d := ctx.position.distance_to(ctx.player)
	if float(ctx.extra.get(&"hurt_ago", INF)) <= HURT_FRESH and d <= GIVE_UP:
		return HURT_SCORE
	if ctx.need(&"fear") > CORNERED_FEAR and d <= CORNERED:
		return CORNERED_SCORE
	if _engaged and d <= GIVE_UP and ctx.need(&"fear") >= CALM_FEAR:
		return ENGAGED_SCORE
	return 0.0

func start(ctx: NpcContext) -> void:
	super(ctx)
	_engaged = true

func think(ctx: NpcContext) -> Intent:
	if ctx.player == null:
		return Intent.idle()
	var at: Vector3 = ctx.player
	if ctx.position.distance_to(at) <= BITE_REACH and ctx.time - _last_bite >= BITE_EVERY:
		_last_bite = ctx.time
		return Intent.go(at, SPEED, &"bite").facing(at)
	return Intent.go(at, SPEED, &"lunge").facing(at)

func done(ctx: NpcContext) -> bool:
	var over := ctx.player == null or ctx.position.distance_to(ctx.player) > GIVE_UP \
		or ctx.need(&"fear") < CALM_FEAR
	if over:
		_engaged = false
	return over
