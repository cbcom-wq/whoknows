extends Behaviour

## Meeting you (Wadoo spec §5): a Wadee who sees you near for the first time in a
## while turns, looks at you and nods, then goes back to what they were doing. A
## shy one steps back to keep SHY from you. Seated or indoors, they let you be.

const NEAR := 8.0
const AGAIN := 60.0
const FOR := 2.5
const SHY := 3.0
const BACK_OFF := 0.75

var _last := -INF

func _init() -> void:
	reflex = true
	threshold = 0.7
	min_time = 1.0

func score(ctx: NpcContext) -> float:
	if ctx.player == null or ctx.extra.get(&"indoors", false) or ctx.extra.get(&"state", &"") == &"seated":
		return 0.0
	if ctx.time - _last < AGAIN:
		return 0.0
	return 0.8 if flat_distance(ctx.player, ctx.position) <= NEAR else 0.0

func start(ctx: NpcContext) -> void:
	super(ctx)
	_last = ctx.time

func think(ctx: NpcContext) -> Intent:
	var you: Variant = player_at(ctx, 2.0)
	if you == null:
		return Intent.idle()
	if _shy(ctx) and flat_distance(you, ctx.position) < SHY:
		return Intent.go(farthest_from(ctx.extra.get(&"nearby", []), you, ctx.position), BACK_OFF).facing(you)
	var t := running(ctx)
	return Intent.idle(&"nod" if t > 0.5 and t < 1.7 else &"").facing(you)

func done(ctx: NpcContext) -> bool:
	if running(ctx) < FOR:
		return false
	if _shy(ctx) and ctx.player != null and flat_distance(ctx.player, ctx.position) < SHY:
		return running(ctx) > FOR * 2.0
	return true

static func _shy(ctx: NpcContext) -> bool:
	return bool(WadooErrand.person(ctx).get("shy", false))
