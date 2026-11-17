extends Behaviour

## The queen in her hall (Wadoo spec §4, §8): she sits on her throne looking down
## the hall to its door; when you come near she rises (Sitting_Exit) and stands
## before it to receive you, turned to you, and once you have gone she sits again.
## Without a throne (a layout with no hall) she stands at her court spot and looks
## over her people now one way, now the other.

const WALK := 0.5
const ARRIVED := 0.3
## She rises when you come within this of where she stands, and sits again once
## you are past SIT_AGAIN.
const RISE_NEAR := 4.5
const SIT_AGAIN := 7.0
## Rising takes this long (the clip).
const RISE := 1.4
const LOOK_EVERY := 30.0
const LOOK_FOR := 6.0
const LOOK_ASIDE := 0.6

var _receiving := false
var _rising := -1.0

func _init() -> void:
	min_time = 5.0

func score(ctx: NpcContext) -> float:
	return 0.5 if ctx.extra.get(&"town") != null else 0.0

func start(ctx: NpcContext) -> void:
	super(ctx)
	_rising = -1.0

func think(ctx: NpcContext) -> Intent:
	var town := ctx.extra.get(&"town") as WadooSite
	var stand := town.spot(&"court", "court:queen")
	if stand.is_empty():
		return Intent.idle()
	var throne := town.spot(&"court", "court:throne")
	var who := ctx.record.id if ctx.record != null else &""
	var seated: bool = ctx.extra.get(&"state", &"") == &"seated"
	if _rising >= 0.0:
		if ctx.time - _rising < RISE:
			return Intent.idle(&"rise")
		_rising = -1.0
		town.mark(who, &"")
		seated = false
	var you: Variant = ctx.player
	var near := you != null and flat_distance(you as Vector3, stand["at"]) < (SIT_AGAIN if _receiving else RISE_NEAR)
	_receiving = near
	if throne.is_empty() or near:
		if seated:
			_rising = ctx.time
			return Intent.idle(&"rise")
		var at: Vector3 = stand["at"]
		if flat_distance(ctx.position, at) > ARRIVED:
			return Intent.go(at, WALK)
		return Intent.idle().facing(you if near else _look_about(ctx, at, stand["face"]))
	var seat: Vector3 = throne["at"]
	if seated:
		return Intent.idle(&"sit").facing(throne["face"])
	if flat_distance(ctx.position, seat) > ARRIVED:
		return Intent.go(seat, WALK)
	if not WadooErrand.facing(ctx, throne["face"]):
		return Intent.idle().facing(throne["face"])
	town.mark(who, &"seated")
	return Intent.idle(&"sit").facing(throne["face"])

## Standing, she looks now one way, now the other.
static func _look_about(ctx: NpcContext, at: Vector3, face: Vector3) -> Vector3:
	var phase := fposmod(ctx.time, LOOK_EVERY)
	if phase < LOOK_FOR:
		var side := 1.0 if int(ctx.time / LOOK_EVERY) % 2 == 0 else -1.0
		return at + (face - at).rotated(Vector3.UP, side * LOOK_ASIDE)
	return face
