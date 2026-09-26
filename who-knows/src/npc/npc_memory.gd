class_name NpcMemory
extends RefCounted

## What an NPC has perceived (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §6.3): what, where (site-local), when
## and how sure. Sureness halves every half_life seconds; a percept is
## forgotten below FORGET. The brain reads this, never the world, so an NPC
## can be wrong: it flees from where it last saw you. Lasts only while the NPC
## is live.

const FORGET := 0.05

class Percept:
	var kind: StringName
	## The node's instance id, or 0 for no one in particular.
	var source_id := 0
	var where := Vector3.ZERO
	var at := 0.0
	var sure := 1.0

var half_life := 6.0
var percepts: Array[Percept] = []

## Remembers `kind` from `source_id` at `where`: refreshes what it already
## remembers of that source, or adds it.
func note(kind: StringName, source_id: int, where: Vector3, sure: float, time: float) -> void:
	for p in percepts:
		if p.kind == kind and p.source_id == source_id and source_id != 0:
			p.sure = maxf(sure, sure_of(p, time))
			p.where = where
			p.at = time
			return
	var p := Percept.new()
	p.kind = kind
	p.source_id = source_id
	p.where = where
	p.sure = sure
	p.at = time
	percepts.append(p)

func sure_of(p: Percept, time: float) -> float:
	return p.sure * pow(0.5, (time - p.at) / half_life)

func forget_faded(time: float) -> void:
	percepts.assign(percepts.filter(func(p: Percept) -> bool: return sure_of(p, time) >= FORGET))

## The surest percept of `kind` now, or null.
func surest(kind: StringName, time: float) -> Percept:
	var best: Percept = null
	for p in percepts:
		if p.kind == kind and (best == null or sure_of(p, time) > sure_of(best, time)):
			best = p
	return best

func clear() -> void:
	percepts.clear()
