extends Behaviour

## Keeps out of your way (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §14.3): when you come toward it, it
## steps aside -- to the side of its cell, or into the next one -- turns to
## face you, and waits until you have passed.

const NEAR := 3.0
const TOO_CLOSE := 1.6
const PASSED := 2.5
const SPEED := 0.9

var _last_distance := INF
var _closing := false
var _to: Variant = null

func _init() -> void:
	min_time = 1.5

func score(ctx: NpcContext) -> float:
	if ctx.player == null:
		_last_distance = INF
		_closing = false
		return 0.0
	var d := flat_distance(ctx.player, ctx.position)
	_closing = d < _last_distance - 0.05
	_last_distance = d
	if d < TOO_CLOSE or (d < NEAR and _closing):
		return 0.9
	return 0.0

func start(ctx: NpcContext) -> void:
	super(ctx)
	_to = null
	var you: Variant = player_at(ctx)
	if you != null:
		_to = farthest_from(ctx.extra.get(&"nearby", []), you, ctx.position)

func think(ctx: NpcContext) -> Intent:
	var you: Variant = player_at(ctx, 1.0)
	var i := Intent.go(_to, SPEED) if _to != null else Intent.idle()
	if you != null:
		i.facing(you)
	return i

func done(ctx: NpcContext) -> bool:
	return ctx.player == null or (flat_distance(ctx.player, ctx.position) > PASSED and not _closing)
