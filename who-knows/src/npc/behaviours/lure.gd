extends Behaviour

## A Glinter in its nest, sitting shut among the salvage (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §4.3): the quiet default -- the glint
## does the work. It never finishes; whatever scores higher (the ambush, the
## hiding after it) pre-empts it. While it sits, a fright wears off.

const SCORE := 0.2
## Fear eases by this a second while it sits.
const EASE := 0.05

func _init() -> void:
	min_time = 5.0

func score(_ctx: NpcContext) -> float:
	return SCORE

func think(ctx: NpcContext) -> Intent:
	ctx.ease(&"fear", EASE)
	return Intent.idle(&"shut")

func done(_ctx: NpcContext) -> bool:
	return false
