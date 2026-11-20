extends WadooErrand

## Drinks at the pool's bank (Wadoo spec §5).

func _init() -> void:
	min_time = 4.0
	span = Vector2(6.0, 9.0)
	need = &"thirst"
	rate = 0.15

func score(ctx: NpcContext) -> float:
	return Curves.ramp(ctx.need(&"thirst"), 0.4, 0.9) * (1.0 - ctx.need(&"fear"))

func choose(ctx: NpcContext) -> Dictionary:
	return town.take_spot(&"bank", who(ctx), ctx.position, ctx.record.seed + int(ctx.time))
