extends Behaviour

## The hunt accepted (Wadoo spec §8): the Sunguard, all but the queen's door warden,
## gather inside the breach and wait there, looking out at the dunes, Kesh at the
## front. Each has their own place (WadooSite's gather spots, by WadooCast.gather_slot).

const WALK := 0.8
const ARRIVED := 0.35

func _init() -> void:
	min_time = 5.0

func score(ctx: NpcContext) -> float:
	var village := ctx.extra.get(&"village") as WadooState
	if village == null or village.hunt != WadooState.HUNT_ACCEPTED or village.hostile:
		return 0.0
	return 0.9 if WadooCast.gather_slot(WadooErrand.person(ctx)) >= 0 else 0.0

func think(ctx: NpcContext) -> Intent:
	var town := ctx.extra.get(&"town") as WadooSite
	var spot := town.spot(&"gather", "gather:%d" % WadooCast.gather_slot(WadooErrand.person(ctx)))
	if spot.is_empty():
		return Intent.idle()
	var at: Vector3 = spot["at"]
	if flat_distance(ctx.position, at) > ARRIVED:
		return Intent.go(at, WALK)
	return Intent.idle(&"watch").facing(spot["face"])
