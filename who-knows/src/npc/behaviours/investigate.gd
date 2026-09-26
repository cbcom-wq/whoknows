extends Behaviour

## Curious and calm, it edges toward someone keeping still, and stops a few
## metres off to look (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.2).

const SPEED := 0.15
const STOP_AT := 6.0
const LOOKS_FOR := 6.0

func _init() -> void:
	min_time = 4.0

func score(ctx: NpcContext) -> float:
	if ctx.player == null or ctx.player_moving:
		return 0.0
	return Curves.ramp(ctx.need(&"curiosity"), 0.4, 0.9) * (1.0 - ctx.need(&"fear"))

func think(ctx: NpcContext) -> Intent:
	ctx.ease(&"curiosity", 0.1)
	var you: Variant = player_at(ctx, 1.0)
	if you == null:
		return Intent.idle()
	var to: Vector3 = you - ctx.position
	if to.length() <= STOP_AT:
		return Intent.idle().facing(you)
	return Intent.go(ctx.position + to.normalized() * (to.length() - STOP_AT), SPEED).facing(you)

func done(ctx: NpcContext) -> bool:
	return running(ctx) >= LOOKS_FOR or ctx.player_moving
