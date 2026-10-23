extends Behaviour

## A hungry Delver goes to the crystal and eats it (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §5.3): its site gives it the burrow point it
## is nearest as places[&"crystal"]. There it stays, its snout bright (the look's
## `eat`), and its hunger eases; done once it is fed. A Delver with no crystal
## has nothing to go to.

const SPEED := 0.5
## Hungrier than this and it feeds (the score ramps from here to 0.8).
const HUNGRY := 0.3
const FULL := 0.1
## It eats this near the crystal, metres, and its hunger eases this fast, per
## second.
const THERE := 1.0
const EATING := 0.05

func _init() -> void:
	min_time = 3.0

func score(ctx: NpcContext) -> float:
	if not ctx.places.has(&"crystal"):
		return 0.0
	return Curves.ramp(ctx.need(&"hunger"), HUNGRY, 0.8)

func think(ctx: NpcContext) -> Intent:
	if not ctx.places.has(&"crystal"):
		return Intent.idle()
	var crystal: Vector3 = ctx.places[&"crystal"]
	if ctx.position.distance_to(crystal) > THERE:
		return Intent.go(crystal, SPEED)
	ctx.ease(&"hunger", EATING)
	return Intent.idle(&"eat")

func done(ctx: NpcContext) -> bool:
	return ctx.need(&"hunger") < FULL
