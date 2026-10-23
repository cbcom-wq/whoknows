extends Behaviour

## A bump or a tremor sends a Delver under at once, to the burrow point farthest
## from where it was (docs/superpowers/specs/2026-10-10-rock-creatures-design.md
## §5.3): a reflex, since it must interrupt a feed. It feels the rock shake (a
## vibration, through its own rock only, while it grips) or a touch (you ran into
## it, a thing struck it). Done once it has come up since it began, as `delve`.
## The mind only asks for the burrow; the burrower does the digging.

const SPEED := 1.0
## It dives from a vibration or touch noted this recently, seconds, and at least
## this sure: the far hum of a drill (0.2) is felt and ignored, a bump or a
## thruster burn (0.6) is not.
const FRESH := 1.0
## (FELT sits above the hum's strength, HabitatValues.HUM_STRENGTH 0.2.)
const FELT := 0.25

func _init() -> void:
	reflex = true
	threshold = 0.5
	min_time = 3.0

func score(ctx: NpcContext) -> float:
	if not ctx.grounded or not ctx.extra.has(&"burrows"):
		return 0.0
	for kind in [Stimulus.VIBRATION, Stimulus.TOUCH]:
		var p := ctx.recent(kind, FRESH)
		if p != null and p.sure >= FELT:
			return 1.0
	return 0.0

func think(ctx: NpcContext) -> Intent:
	if not ctx.extra.has(&"burrows"):
		return Intent.idle()
	var to := farthest_from(ctx.extra[&"burrows"], ctx.position, ctx.position)
	return Intent.go(to, SPEED, &"burrow")

func done(ctx: NpcContext) -> bool:
	return float(ctx.extra.get(&"surfaced_ago", INF)) < running(ctx)
