extends Behaviour

## Locks its wheels and rides out a shake: a burn starting, a hull strike
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §14.3).

const CALM_FOR := 0.8

func _init() -> void:
	reflex = true
	threshold = 0.3
	min_time = CALM_FOR

func score(ctx: NpcContext) -> float:
	var shake := ctx.recent(Stimulus.SHAKE, 0.3)
	return shake.sure if shake != null else 0.0

func think(_ctx: NpcContext) -> Intent:
	return Intent.idle(&"brace")

func done(ctx: NpcContext) -> bool:
	return ctx.recent(Stimulus.SHAKE, CALM_FOR) == null
