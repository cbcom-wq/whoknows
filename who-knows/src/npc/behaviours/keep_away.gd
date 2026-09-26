extends Behaviour

## Frightened, it keeps to rooms you are not in (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §14.3) until its fear fades.

const SPEED := 0.7
const ARRIVED := 0.3

var _to: Variant = null

func _init() -> void:
	min_time = 6.0

func score(ctx: NpcContext) -> float:
	return Curves.ramp(ctx.need(&"fear"), 0.4, 0.9)

func start(ctx: NpcContext) -> void:
	super(ctx)
	var yours: StringName = ctx.extra.get(&"player_zone", &"")
	var you: Variant = player_at(ctx)
	var away: Array = []
	for r: Array in ctx.extra.get(&"rooms", []):
		if r[1] != yours:
			away.append(r[0])
	_to = farthest_from(away, you, ctx.position) if you != null else (away[0] if not away.is_empty() else null)

func think(ctx: NpcContext) -> Intent:
	ctx.ease(&"fear", 0.05)
	if _to == null or flat_distance(ctx.position, _to) < ARRIVED:
		return Intent.idle()
	return Intent.go(_to, SPEED)

func done(ctx: NpcContext) -> bool:
	return ctx.need(&"fear") < 0.2
