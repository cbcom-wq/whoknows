extends Behaviour

## Grazes the lavender veins where its herd is on its round
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §13.2): walks
## there, spread out a little from the others, and nibbles.

const SPEED := 0.3
const THERE := 2.0
const SPREAD := 1.5

func _init() -> void:
	min_time = 8.0

func score(ctx: NpcContext) -> float:
	if not ctx.extra.has(&"graze"):
		return 0.0
	return Curves.ramp(ctx.need(&"hunger"), 0.2, 0.8) * (1.0 - ctx.need(&"fear"))

func think(ctx: NpcContext) -> Intent:
	var at := spot(ctx, ctx.extra[&"graze"], SPREAD)
	if ctx.position.distance_to(at) > THERE:
		return Intent.go(at, SPEED)
	ctx.ease(&"hunger", 0.08)
	return Intent.idle(&"graze")

func done(ctx: NpcContext) -> bool:
	return ctx.need(&"hunger") < 0.1

## Its own place `spread` metres from `centre`, across the surface, chosen by
## its seed so a herd fans out.
static func spot(ctx: NpcContext, centre: Vector3, spread: float) -> Vector3:
	var seed := ctx.record.seed if ctx.record != null else 0
	var a := float(seed & 0xFFFF) / 65535.0 * TAU
	var side := Vector3(cos(a), 0.37, sin(a))
	side -= ctx.up * side.dot(ctx.up)
	if side.length() < 0.01:
		return centre
	return centre + side.normalized() * spread
