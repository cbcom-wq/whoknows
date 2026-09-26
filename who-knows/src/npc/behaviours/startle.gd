extends Behaviour

## Backs away from whatever bumped it or banged near it
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §14.3), with a
## worried beep, and is a little warier after.

const LOUD := 0.6
const FRESH := 0.3
const SPEED := 1.0
const LASTS := 1.2

var _to: Variant = null

func _init() -> void:
	reflex = true
	threshold = 0.5
	min_time = LASTS

func score(ctx: NpcContext) -> float:
	var touch := ctx.recent(Stimulus.TOUCH, FRESH)
	var sound := ctx.recent(Stimulus.SOUND, FRESH)
	var s := touch.sure if touch != null else 0.0
	if sound != null and sound.sure >= LOUD:
		s = maxf(s, sound.sure)
	return s

func start(ctx: NpcContext) -> void:
	super(ctx)
	var touch := ctx.recent(Stimulus.TOUCH, FRESH)
	var from := touch.where if touch != null else ctx.position - ctx.forward
	if touch == null:
		var sound := ctx.recent(Stimulus.SOUND, FRESH)
		if sound != null:
			from = sound.where
	_to = farthest_from(ctx.extra.get(&"nearby", []), from, ctx.position)
	ctx.raise(&"fear", 0.3)
	ctx.voice = &"droid_beep"

func think(_ctx: NpcContext) -> Intent:
	return Intent.go(_to, SPEED, &"startle") if _to != null else Intent.idle(&"startle")

func done(ctx: NpcContext) -> bool:
	return running(ctx) >= LASTS
