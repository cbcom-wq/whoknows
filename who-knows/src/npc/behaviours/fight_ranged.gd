extends Behaviour

## The Sunguard fight (Wadoo spec §9). The town has turned on you: while you are on
## your feet within the walls they keep FIGHT_NEAR to FIGHT_FAR off
## (WadooSite.fire_spot), run between places in cover with a clear line to you,
## and from each throw a bolt of sun every 1.5 to 2.5 s, each in their own
## rhythm (the body sends it: WadooSite.shoot). Aimed at, now and then they roll
## aside. You down, or gone from the walls, they stop and go back to their posts
## (keep_post), still hostile; back on your feet, you have GRACE to get clear.

## A run, of top speed: 4.3 m/s at 1.8.
const RUN := 2.4
const ARRIVED := 0.6
## Between shots, s: each Sunguard's own, somewhere in here, a little off each time.
const EVERY := Vector2(1.5, 2.5)
const JITTER := 0.2
## The first shot after they turn to you, s.
const FIRST := Vector2(0.8, 1.6)
## A new place to fight from every so often, s.
const MOVE_EVERY := Vector2(5.0, 9.0)
## You back on your feet, they let you be this long, s.
const GRACE := 8.0
## A roll aside: this far, at this share of top speed, this long (the clip), at
## most once in ROLL_EVERY, and on ROLL_CHANCE of the times you aim at them.
const ROLL := 2.5
const ROLL_SPEED := 1.0
const ROLL_FOR := 1.4
const ROLL_EVERY := 4.0
const ROLL_CHANCE := 0.5
## Closing in when there is no place with a line to you, until this near, m.
const CLOSE_TO := 15.0

var _spot: Variant = null
var _next_move := 0.0
var _next_shot := 0.0
var _next_roll := 0.0
var _roll_until := -1.0
var _roll_to := Vector3.ZERO
var _turns := 0
## Their own dice for a fight: when to roll and which way, the jitter on a shot.
## Seeded from who they are and when the fight began, so a test is repeatable.
var _dice := RandomNumberGenerator.new()

func _init() -> void:
	reflex = true
	threshold = 0.9
	min_time = 1.0

func score(ctx: NpcContext) -> float:
	var village := ctx.extra.get(&"village") as WadooState
	if village == null or not village.hostile or ctx.extra.get(&"town") == null:
		return 0.0
	return 1.0 if fighting(ctx.extra.get(&"you", {})) else 0.0

## You are someone to fight: on your feet on the ground, within the walls, and
## up for GRACE since you were last down.
static func fighting(you: Dictionary) -> bool:
	return not you.is_empty() and bool(you["on_foot"]) and not bool(you["down"]) and bool(you["in_town"]) \
		and float(you["up_for"]) >= GRACE

func start(ctx: NpcContext) -> void:
	super(ctx)
	_spot = null
	_next_move = 0.0
	_next_shot = ctx.time + lerpf(FIRST.x, FIRST.y, nature(ctx, 2))
	_roll_until = -1.0
	_dice.seed = hash([ctx.record.seed if ctx.record != null else 0, int(ctx.time * 10.0)])
	var town := ctx.extra.get(&"town") as WadooSite
	town.release(WadooErrand.who(ctx))
	town.mark(WadooErrand.who(ctx), &"")

func think(ctx: NpcContext) -> Intent:
	var town := ctx.extra.get(&"town") as WadooSite
	var you: Dictionary = ctx.extra.get(&"you", {})
	var at: Vector3 = you["at"]
	if ctx.time < _roll_until:
		return Intent.go(_roll_to, ROLL_SPEED, &"roll")
	if ctx.extra.get(&"aimed_at", false) and ctx.time >= _next_roll:
		_next_roll = ctx.time + ROLL_EVERY
		_turns += 1
		if _dice.randf() < ROLL_CHANCE:
			var aside: Variant = _aside(ctx, at)
			if aside != null:
				_roll_to = aside
				_roll_until = ctx.time + ROLL_FOR
				return Intent.go(_roll_to, ROLL_SPEED, &"roll")
	var off := flat_distance(at, ctx.position)
	var spot_bad := _spot == null or flat_distance(_spot, at) < WadooSite.FIGHT_NEAR - 2.0 \
		or flat_distance(_spot, at) > WadooSite.FIGHT_FAR + 3.0
	if spot_bad or ctx.time >= _next_move:
		_turns += 1
		_spot = town.fire_spot(ctx.position, you, int(ctx.record.seed if ctx.record != null else 0) + _turns * 97)
		_next_move = ctx.time + _dice.randf_range(MOVE_EVERY.x, MOVE_EVERY.y)
	if _spot != null and flat_distance(ctx.position, _spot) > ARRIVED:
		return Intent.go(_spot, RUN, &"armed")
	if not town.clear_shot(ctx.position, you):
		if _spot == null and off > CLOSE_TO:
			return Intent.go(at, RUN, &"armed")
		# no line from here: find another place next think
		_next_move = ctx.time
		return Intent.idle(&"aim").facing(at)
	if ctx.time >= _next_shot:
		var every := lerpf(EVERY.x, EVERY.y, nature(ctx, 3))
		_next_shot = ctx.time + clampf(every + _dice.randf_range(-JITTER, JITTER), EVERY.x, EVERY.y)
		return Intent.idle(&"shoot").facing(at)
	return Intent.idle(&"aim").facing(at)

## A place ROLL to one side of the line to you, on open ground near them; null if
## neither side is open.
func _aside(ctx: NpcContext, you_at: Vector3) -> Variant:
	var to := Vector2(you_at.x - ctx.position.x, you_at.z - ctx.position.z).normalized()
	var side := Vector2(-to.y, to.x)
	var first := 1.0 if _dice.randf() < 0.5 else -1.0
	var town := ctx.extra.get(&"town") as WadooSite
	var here := WadooSite.flat(ctx.position)
	for s: float in [first, -first]:
		var p := here + Vector2(side.x, -side.y) * ROLL * s
		if town.open(p) and town.paths.clear_line(here, p):
			return town.ground(p)
	return null

## A number in [0, 1) that is this one's own, always (their rhythm, their first
## shot): from their seed alone.
static func nature(ctx: NpcContext, salt: int) -> float:
	var s := ctx.record.seed if ctx.record != null else 0
	return fposmod(float(s % 10007) * 0.618034 + salt * 0.291, 1.0)
