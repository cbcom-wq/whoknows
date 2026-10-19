extends Behaviour

## A limpet on its bed, nearly still (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §6.2): the quiet default, the thing it
## does when nothing draws it. It never finishes; whatever scores higher
## (creeping to a source, sipping) pre-empts it.

const SCORE := 0.2

func _init() -> void:
	min_time = 5.0

func score(_ctx: NpcContext) -> float:
	return SCORE

func think(_ctx: NpcContext) -> Intent:
	return Intent.idle(&"cling")

func done(_ctx: NpcContext) -> bool:
	return false
