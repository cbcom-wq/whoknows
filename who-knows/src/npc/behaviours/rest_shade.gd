extends WadooErrand

## Rests on a bench under a shade sail (Wadoo spec §5): sits, and talks with
## whoever sits under the same sail; gets up (Sitting_Exit) before going on.

const RISE := 1.4
## Talking and quiet by turns, this long each, s.
const TURN := 6.0

var _rising := -1.0

func _init() -> void:
	min_time = 8.0
	span = Vector2(30.0, 60.0)
	need = &"rest"
	rate = 0.025

func score(ctx: NpcContext) -> float:
	return Curves.ramp(ctx.need(&"rest"), 0.3, 0.9) * (1.0 - ctx.need(&"fear"))

func start(ctx: NpcContext) -> void:
	_rising = -1.0
	super(ctx)

func choose(ctx: NpcContext) -> Dictionary:
	return town.take_spot(&"shade", who(ctx), ctx.position, ctx.record.seed + int(ctx.time))

func think(ctx: NpcContext) -> Intent:
	if _rising >= 0.0:
		if ctx.time - _rising >= RISE:
			_finished = true
			if town != null:
				town.release(who(ctx))
				town.mark(who(ctx), &"")
		return Intent.idle(&"rise")
	var i := super(ctx)
	if acting() and town != null:
		town.mark(who(ctx), &"seated")
	return i

## Seated, it gets up before it lets the seat go.
func finish(ctx: NpcContext) -> void:
	if acting():
		_rising = ctx.time
	else:
		super(ctx)

## Sitting, and talking by turns when someone else sits under the same sail.
func action(ctx: NpcContext) -> StringName:
	if town == null:
		return &"sit"
	var parts := String(spot["key"]).split(":")
	var sail := int(parts[1]) / 2
	var company := false
	for b in [sail * 2, sail * 2 + 1]:
		for k in 2:
			var holder: Variant = town.holder_of("shade:%d:%d" % [b, k])
			if holder != null and holder != who(ctx):
				company = true
	if company and int((ctx.time + roll(ctx, 4) * TURN) / TURN) % 2 == 0:
		return &"sit_talk"
	return &"sit"
