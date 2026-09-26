extends Behaviour

## Trundles off to another room and looks about (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §14.3): what it does when nothing else
## needs doing.

const SPEED := 0.55
const ARRIVED := 0.3
## It roams somewhere at least this far away.
const FAR_ENOUGH := 3.0

var _to: Variant = null

func _init() -> void:
	min_time = 8.0

func score(_ctx: NpcContext) -> float:
	return 0.15

func start(ctx: NpcContext) -> void:
	super(ctx)
	var choices: Array = []
	for r: Array in ctx.extra.get(&"rooms", []):
		if flat_distance(r[0], ctx.position) > FAR_ENOUGH:
			choices.append(r[0])
	_to = null
	if not choices.is_empty():
		var pick := int(fposmod(ctx.time * 7.13 + float(ctx.record.seed if ctx.record != null else 0), float(choices.size())))
		_to = choices[pick]

func think(_ctx: NpcContext) -> Intent:
	return Intent.go(_to, SPEED) if _to != null else Intent.idle()

func done(ctx: NpcContext) -> bool:
	return _to == null or flat_distance(ctx.position, _to) < ARRIVED
