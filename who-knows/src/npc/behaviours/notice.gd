extends Behaviour

## Looks at you when you stop near it (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §14.3): turns its eye to you, tilts,
## chirps.

const NEAR := 3.0
const STILL_FOR := 1.0
const LOOKS_FOR := 3.0

var _still_since := -1.0

func _init() -> void:
	min_time = 2.0

func score(ctx: NpcContext) -> float:
	if ctx.player == null or flat_distance(ctx.player, ctx.position) > NEAR:
		_still_since = -1.0
		return 0.0
	if ctx.player_moving or _still_since < 0.0:
		_still_since = ctx.time
	if ctx.time - _still_since < STILL_FOR:
		return 0.0
	return Curves.ramp(ctx.need(&"curiosity"), 0.2, 0.7)

func start(ctx: NpcContext) -> void:
	super(ctx)
	ctx.voice = &"droid_chirp"

func think(ctx: NpcContext) -> Intent:
	ctx.ease(&"curiosity", 0.3)
	var i := Intent.idle(&"notice")
	var you: Variant = player_at(ctx, 1.0)
	if you != null:
		i.facing(you)
	return i

func done(ctx: NpcContext) -> bool:
	return running(ctx) >= LOOKS_FOR
