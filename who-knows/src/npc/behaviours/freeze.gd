extends Behaviour

## Flattens to the rock and keeps still when a light is on it or something it
## fears moves near (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §13.2): a still skitter looks like a stone.

const NEAR := 15.0
const CALM_FOR := 2.0

var _calm_since := 0.0

func _init() -> void:
	reflex = true
	threshold = 0.5
	min_time = 1.5

func score(ctx: NpcContext) -> float:
	var s := 0.0
	if ctx.lit:
		s = 0.9 * clampf(-ctx.species.light_response if ctx.species != null else 1.0, 0.0, 1.0)
	if ctx.player != null and ctx.player_moving and ctx.position.distance_to(ctx.player) < NEAR:
		s = maxf(s, 0.7)
	if s > 0.0:
		_calm_since = ctx.time
	return s

func think(ctx: NpcContext) -> Intent:
	ctx.raise(&"fear", 0.05)
	return Intent.idle(&"freeze")

func done(ctx: NpcContext) -> bool:
	return ctx.time - _calm_since >= CALM_FOR
