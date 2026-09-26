extends Behaviour

## Frightened, it goes to the nearest crater and keeps still there until its
## fear fades (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §13.2).

const SPEED := 0.8
const THERE := 2.0

func _init() -> void:
	min_time = 10.0

func score(ctx: NpcContext) -> float:
	return Curves.ramp(ctx.need(&"fear"), 0.4, 0.9) if ctx.places.has(&"shelter") else 0.0

func think(ctx: NpcContext) -> Intent:
	ctx.ease(&"fear", 0.04)
	var at: Vector3 = ctx.places[&"shelter"]
	if ctx.position.distance_to(at) > THERE:
		return Intent.go(at, SPEED)
	return Intent.idle(&"freeze")

func done(ctx: NpcContext) -> bool:
	return ctx.need(&"fear") < 0.2
