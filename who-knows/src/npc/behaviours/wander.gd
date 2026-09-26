extends Behaviour

## Ambles along its herd's round (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.2, §4.4): what a calm skitter does.

const SPEED := 0.3
const THERE := 2.0

func _init() -> void:
	min_time = 10.0

func score(ctx: NpcContext) -> float:
	return 0.15 if ctx.places.has(&"round") else 0.0

func think(ctx: NpcContext) -> Intent:
	var at: Vector3 = load("res://src/npc/behaviours/graze.gd").spot(ctx, ctx.places[&"round"], 2.5)
	return Intent.go(at, SPEED) if ctx.position.distance_to(at) > THERE else Intent.idle()

func done(ctx: NpcContext) -> bool:
	return not ctx.places.has(&"round")
