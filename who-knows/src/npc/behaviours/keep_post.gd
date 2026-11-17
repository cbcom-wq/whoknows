extends Behaviour

## A Sunguard keeps their post (Wadoo spec §4, §5): stands at it, arms folded,
## facing what they guard, and now and then looks about. Kesh walks the breach
## from one end to the other instead.

const WALK := 0.45
const ARRIVED := 0.3
## A walking post's leg, s: walk to one end, watch, walk back.
const LEG := 30.0
## A look about: every this long, for this long, this far to a side, rad.
const LOOK_EVERY := 40.0
const LOOK_FOR := 4.0
const LOOK_ASIDE := 0.9

func _init() -> void:
	min_time = 5.0

func score(ctx: NpcContext) -> float:
	return 0.5 if ctx.extra.get(&"town") != null and str(WadooErrand.person(ctx).get("post", "")) != "" else 0.0

func think(ctx: NpcContext) -> Intent:
	var town := ctx.extra.get(&"town") as WadooSite
	var post := str(WadooErrand.person(ctx).get("post", ""))
	var spot := town.spot(&"post", "post:%s" % post)
	if spot.is_empty():
		var end := int(ctx.time / LEG) % 2
		spot = town.spot(&"post", "post:%s:%d" % [post, end])
	if spot.is_empty():
		return Intent.idle()
	var at: Vector3 = spot["at"]
	var face: Vector3 = spot["face"]
	if flat_distance(ctx.position, at) > ARRIVED:
		return Intent.go(at, WALK)
	var phase := fposmod(ctx.time + WadooErrand.roll(ctx, 6) * LOOK_EVERY, LOOK_EVERY)
	if phase < LOOK_FOR:
		var side := 1.0 if int(ctx.time / LOOK_EVERY) % 2 == 0 else -1.0
		var ahead := face - at
		face = at + ahead.rotated(Vector3.UP, side * LOOK_ASIDE)
	return Intent.idle(&"watch").facing(face)
