extends Behaviour

## TEMPLATE: copy to who-knows/src/npc/behaviours/<id>.gd -- the file name is
## the id a species lists. Replace every CHANGE, delete what you don't use,
## and write a doc comment saying what it does and citing its spec section.
##
## Behaviours never see a scene: read only `ctx` (needs, memory through
## ctx.recent, what the site put in ctx.places / ctx.extra, the player if
## seen). Points are in the site's frame.

## CHANGE: speeds are fractions of species.top_speed.
const SPEED := 0.3
const THERE := 1.0

var _to: Variant = null

func _init() -> void:
	# CHANGE: a reflex interrupts anything once score >= threshold. Anything
	# that must break into a job in progress has to be a reflex.
	reflex = false
	threshold = 0.5
	min_time = 3.0

## 0..1. Build it from Curves on needs and recent percepts.
func score(ctx: NpcContext) -> float:
	# CHANGE: e.g. hungry and not afraid.
	return Curves.ramp(ctx.need(&"hunger"), 0.2, 0.8) * (1.0 - ctx.need(&"fear"))

func start(ctx: NpcContext) -> void:
	super(ctx)
	# CHANGE: choose where to go once, here, not every think.
	_to = ctx.places.get(&"shelter")

func think(ctx: NpcContext) -> Intent:
	if _to == null:
		return Intent.idle()
	if ctx.position.distance_to(_to) > THERE:
		return Intent.go(_to, SPEED)
	# CHANGE: arrived: an action the look plays, a need eased, maybe a sound.
	ctx.ease(&"hunger", 0.1)
	return Intent.idle(&"graze")

func done(ctx: NpcContext) -> bool:
	# CHANGE: when it has finished; a finished behaviour that still wins restarts.
	return ctx.need(&"hunger") < 0.1
