extends Behaviour

## Talking with you (Wadoo spec §6): while you speak with them, they stop what
## they were doing, face you and talk (seated, they talk where they sit). Set by
## the site (WadooSite.talking): ctx.extra.talking.

func _init() -> void:
	reflex = true
	threshold = 0.85
	min_time = 0.5

func score(ctx: NpcContext) -> float:
	return 1.0 if ctx.extra.get(&"talking", false) else 0.0

func think(ctx: NpcContext) -> Intent:
	if ctx.extra.get(&"state", &"") == &"seated":
		return Intent.idle(&"sit_talk")
	var you: Variant = player_at(ctx, 4.0)
	var said := Intent.idle(&"talk")
	return said.facing(you) if you != null else said

func done(ctx: NpcContext) -> bool:
	return not ctx.extra.get(&"talking", false)
