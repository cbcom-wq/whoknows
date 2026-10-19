extends Behaviour

## A limpet within reach of quantum energy stays and drains it (docs/superpowers/
## specs/2026-10-10-rock-creatures-design.md §6.1, §6.2): the body does the
## draining when it sees the `sip` action (Npc.sip); its crystal facets
## brighten (LimpetLook). Fed, its appetite eases. Done once out of reach.

const Creep := preload("res://src/npc/behaviours/creep.gd")

func _init() -> void:
	min_time = 1.0

func score(ctx: NpcContext) -> float:
	return 0.9 if Creep.in_reach(ctx) else 0.0

func think(ctx: NpcContext) -> Intent:
	ctx.ease(&"appetite", 0.02)
	return Intent.idle(&"sip")

func done(ctx: NpcContext) -> bool:
	return not Creep.in_reach(ctx)
