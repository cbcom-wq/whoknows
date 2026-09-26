extends Behaviour

## Goes home to its dock and sits there until it is charged
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §14.3).

const SPEED := 0.55
const ARRIVED := 0.2
const CHARGES := 0.05

func _init() -> void:
	min_time = 10.0

func score(ctx: NpcContext) -> float:
	if not ctx.places.has(&"dock"):
		return 0.0
	return Curves.ramp(ctx.need(&"charge"), 0.5, 1.0)

func think(ctx: NpcContext) -> Intent:
	var dock: Vector3 = ctx.places[&"dock"]
	if flat_distance(ctx.position, dock) > ARRIVED:
		return Intent.go(dock, SPEED)
	ctx.ease(&"charge", CHARGES)
	return Intent.idle(&"dock")

func done(ctx: NpcContext) -> bool:
	return ctx.need(&"charge") < 0.05
