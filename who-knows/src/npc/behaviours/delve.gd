extends Behaviour

## A fed Delver, its cycle up, goes under and comes up at the next point of its
## round (docs/superpowers/specs/2026-10-10-rock-creatures-design.md §5.3): its
## site gives it places[&"burrow"] (the next one round after the crystal it is
## at) and extra[&"cycle"] (3-6 minutes of its rock's live time, its own); the
## body tells the mind how long ago it last came up (extra[&"surfaced_ago"]).
## The mind only asks for the burrow; the burrower does the digging. Done once it
## has come up since it began. A Delver with no round, or hungry, does not delve.

const SPEED := 1.0
const SCORE := 0.7
## Hungrier than this and it feeds first.
const FED := 0.3

func _init() -> void:
	min_time = 3.0

func score(ctx: NpcContext) -> float:
	if not ctx.places.has(&"burrow") or not ctx.extra.has(&"cycle"):
		return 0.0
	if ctx.need(&"hunger") >= FED:
		return 0.0
	return SCORE if float(ctx.extra.get(&"surfaced_ago", 0.0)) >= float(ctx.extra[&"cycle"]) else 0.0

func think(ctx: NpcContext) -> Intent:
	if not ctx.places.has(&"burrow"):
		return Intent.idle()
	return Intent.go(ctx.places[&"burrow"], SPEED, &"burrow")

func done(ctx: NpcContext) -> bool:
	return float(ctx.extra.get(&"surfaced_ago", INF)) < running(ctx)
