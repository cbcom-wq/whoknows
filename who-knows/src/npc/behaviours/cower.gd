extends Behaviour

## Caught in the open (Wadoo spec §9): the town has turned on you, you stand
## between a villager and their door, near: they crouch where they are, facing
## you, and stay down until you are CLEAR off, then run for it (flee_home).

## You this near, and nearer their door than they are, they are cornered, m.
const CORNERED := 7.0
## They stay down until you are this far, m.
const CLEAR := 12.0

var _down := false

func _init() -> void:
	reflex = true
	threshold = 0.9
	min_time = 3.0

func score(ctx: NpcContext) -> float:
	var village := ctx.extra.get(&"village") as WadooState
	var town := ctx.extra.get(&"town") as WadooSite
	var you: Dictionary = ctx.extra.get(&"you", {})
	if village == null or not village.hostile or town == null or ctx.extra.get(&"indoors", false) \
			or you.is_empty() or not bool(you["in_town"]):
		_down = false
		return 0.0
	var d := flat_distance(you["at"], ctx.position)
	if _down and d < CLEAR:
		return 1.0
	var door := town.door_of(str(WadooErrand.person(ctx).get("home", "")))
	if door.is_empty():
		return 1.0 if d < CLEAR else 0.0
	var cornered := d < CORNERED and flat_distance(you["at"], door["door"]) < flat_distance(ctx.position, door["door"])
	return 1.0 if cornered else 0.0

func start(ctx: NpcContext) -> void:
	super(ctx)
	_down = true
	var town := ctx.extra.get(&"town") as WadooSite
	town.release(WadooErrand.who(ctx))
	town.end_pair(WadooErrand.who(ctx))
	town.mark(WadooErrand.who(ctx), &"")

func think(ctx: NpcContext) -> Intent:
	var you: Dictionary = ctx.extra.get(&"you", {})
	if you.is_empty():
		return Intent.idle(&"cower")
	return Intent.idle(&"cower").facing(you["at"])

func done(ctx: NpcContext) -> bool:
	var you: Dictionary = ctx.extra.get(&"you", {})
	if you.is_empty() or not bool(you["in_town"]) or flat_distance(you["at"], ctx.position) >= CLEAR:
		_down = false
		return true
	return false
