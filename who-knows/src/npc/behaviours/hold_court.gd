extends Behaviour

## The queen before her hall (Wadoo spec §4): she stands at the head of the north
## court, facing it, and looks over her people now one way, now the other.

const WALK := 0.5
const ARRIVED := 0.3
const LOOK_EVERY := 30.0
const LOOK_FOR := 6.0
const LOOK_ASIDE := 0.6

func _init() -> void:
	min_time = 5.0

func score(ctx: NpcContext) -> float:
	return 0.5 if ctx.extra.get(&"town") != null else 0.0

func think(ctx: NpcContext) -> Intent:
	var town := ctx.extra.get(&"town") as WadooSite
	var spot := town.spot(&"court", "court:queen")
	if spot.is_empty():
		return Intent.idle()
	var at: Vector3 = spot["at"]
	var face: Vector3 = spot["face"]
	if flat_distance(ctx.position, at) > ARRIVED:
		return Intent.go(at, WALK)
	var phase := fposmod(ctx.time, LOOK_EVERY)
	if phase < LOOK_FOR:
		var side := 1.0 if int(ctx.time / LOOK_EVERY) % 2 == 0 else -1.0
		face = at + (face - at).rotated(Vector3.UP, side * LOOK_ASIDE)
	return Intent.idle().facing(face)
