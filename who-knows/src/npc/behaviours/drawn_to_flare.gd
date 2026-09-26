extends Behaviour

## A still flare seen from afar draws it in, to the edge of the flare's light
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §13.2, §12.1):
## a flare thrown on the rock gathers them. Close, or moving, it frightens.

const SPEED := 0.3
const FAR := 12.0
const EDGE := 6.0
const FRESH := 1.0

func _init() -> void:
	min_time = 5.0

func score(ctx: NpcContext) -> float:
	var flare := ctx.recent(Perception.FLARE, FRESH)
	if flare == null or ctx.extra.get(&"flare_moving", false):
		return 0.0
	if ctx.position.distance_to(flare.where) <= FAR:
		return 0.0
	return 0.8 * (1.0 - ctx.need(&"fear"))

func think(ctx: NpcContext) -> Intent:
	var flare := ctx.recent(Perception.FLARE, FRESH)
	if flare == null:
		return Intent.idle()
	var from := ctx.position - flare.where
	var edge := flare.where + from.normalized() * EDGE
	if ctx.position.distance_to(edge) < 1.0:
		return Intent.idle().facing(flare.where)
	return Intent.go(edge, SPEED).facing(flare.where)

func done(ctx: NpcContext) -> bool:
	var flare := ctx.recent(Perception.FLARE, FRESH)
	return flare == null or ctx.extra.get(&"flare_moving", false)
