extends Behaviour

## A hungry limpet crawls toward quantum energy (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §6.2): your suit within 20 m, or a base
## on its rock, whichever its site has put in places[&"quantum"]. Slow: 0.2 m/s
## at its top speed of 0.25. It is done once the source is within drain_reach,
## when `sip` takes over.

const SPEED := 0.8

func _init() -> void:
	min_time = 5.0

func score(ctx: NpcContext) -> float:
	if not ctx.places.has(&"quantum"):
		return 0.0
	return Curves.ramp(ctx.need(&"appetite"), 0.3, 0.8)

func think(ctx: NpcContext) -> Intent:
	if not ctx.places.has(&"quantum"):
		return Intent.idle()
	return Intent.go(ctx.places[&"quantum"], SPEED)

func done(ctx: NpcContext) -> bool:
	return not ctx.places.has(&"quantum") or in_reach(ctx)

## The source is within the distance it can sip from: its species' drain_reach,
## or the shorter one its site gives (a base is sipped only from near a module).
static func in_reach(ctx: NpcContext) -> bool:
	if not ctx.places.has(&"quantum"):
		return false
	var reach: float = ctx.extra.get(&"quantum_reach", ctx.species.drain_reach)
	return ctx.position.distance_to(ctx.places[&"quantum"]) <= reach
