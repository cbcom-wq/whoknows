extends WadooErrand

## Kneels at the memorial (Wadoo spec §4, §5): only those who lost someone to the
## beast. Their grief rises with the rest of their needs and is eased here.

func _init() -> void:
	min_time = 10.0
	span = Vector2(30.0, 60.0)
	need = &"grief"
	rate = 0.02

func score(ctx: NpcContext) -> float:
	if not bool(person(ctx).get("grief", false)):
		return 0.0
	return Curves.ramp(ctx.need(&"grief"), 0.3, 0.9) * (1.0 - ctx.need(&"fear"))

func choose(ctx: NpcContext) -> Dictionary:
	return town.take_spot(&"memorial", who(ctx), ctx.position, ctx.record.seed + int(ctx.time))
