extends Behaviour

## Tired, it settles in shelter (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.2).

const SPEED := 0.3
const THERE := 2.0

func _init() -> void:
	min_time = 15.0

func score(ctx: NpcContext) -> float:
	return Curves.ramp(ctx.need(&"rest"), 0.6, 1.0) if ctx.places.has(&"shelter") else 0.0

func think(ctx: NpcContext) -> Intent:
	var at: Vector3 = ctx.places[&"shelter"]
	if ctx.position.distance_to(at) > THERE:
		return Intent.go(at, SPEED)
	ctx.ease(&"rest", 0.05)
	return Intent.idle(&"rest")

func done(ctx: NpcContext) -> bool:
	return ctx.need(&"rest") < 0.1
