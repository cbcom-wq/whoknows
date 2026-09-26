extends Behaviour

## Goes back among its herd when it has strayed (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §7.3).

const STRAYED := 6.0
const AMONG := 3.0
const SPEED := 0.4

func _init() -> void:
	min_time = 3.0

func score(ctx: NpcContext) -> float:
	if ctx.mates.is_empty() or nearest(ctx) <= STRAYED:
		return 0.0
	return Curves.ramp(ctx.need(&"company"), 0.3, 0.9)

func think(ctx: NpcContext) -> Intent:
	var centre := Vector3.ZERO
	for m in ctx.mates:
		centre += m
	centre /= float(ctx.mates.size())
	return Intent.go(centre, SPEED)

func done(ctx: NpcContext) -> bool:
	return ctx.mates.is_empty() or nearest(ctx) < AMONG

static func nearest(ctx: NpcContext) -> float:
	var best := INF
	for m in ctx.mates:
		best = minf(best, ctx.position.distance_to(m))
	return best
