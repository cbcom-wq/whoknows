extends Behaviour

## A Glinter springs (docs/superpowers/specs/2026-10-10-rock-creatures-design.md
## §4.3, §4.4): you within AMBUSH and it is not afraid -- not recently bitten
## and gone to ground -- it leaps at your suit (the crawler's leap, aimed at the
## avatar's layer), and once within its bite reach asks for one bite
## (`&"bite"`: the body does it, Npc.bite), then raises its own fear to
## AFTER_FEAR, which sends it to ground (`hide`) until the fear fades and the
## nest re-arms. A reflex: it pre-empts the quiet `lure`. If the leap misses it
## chases along the surface, and gives up after GIVE_UP.

## You are this near, metres, and it springs.
const AMBUSH := 5.0
## Afraid at or over this, it does not spring.
const CALM := 0.4
## Its fear once it has bitten.
const AFTER_FEAR := 0.8
## Seconds before it gives up a spring that has not landed a bite.
const GIVE_UP := 4.0
## Added to the species' bite reach when deciding to bite: the body's own
## check (from its middle to the suit) has the last word.
const SLACK := 0.3

var _sprung := false
var _bitten := false

func _init() -> void:
	reflex = true
	threshold = 0.5
	min_time = 0.5

func score(ctx: NpcContext) -> float:
	if ctx.player == null:
		return 0.0
	if ctx.position.distance_to(ctx.player) > AMBUSH or ctx.need(&"fear") >= CALM:
		return 0.0
	return 1.0

func start(ctx: NpcContext) -> void:
	super(ctx)
	_sprung = false
	_bitten = false

func think(ctx: NpcContext) -> Intent:
	var at: Variant = player_at(ctx)
	if at == null:
		return Intent.idle()
	var you: Vector3 = at
	if not _sprung:
		_sprung = true
		var i := Intent.idle(&"leap")
		i.leap_to = you
		return i
	if ctx.position.distance_to(you) <= ctx.species.bite_reach + SLACK:
		_bitten = true
		ctx.raise(&"fear", AFTER_FEAR)
		return Intent.go(you, 1.0, &"bite")
	return Intent.go(you, 1.0, &"lunge")

func done(ctx: NpcContext) -> bool:
	return _bitten or running(ctx) >= GIVE_UP
