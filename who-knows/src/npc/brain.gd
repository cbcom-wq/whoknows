class_name Brain
extends RefCounted

## Needs and scored behaviours (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §7): needs rise by themselves; each
## think every behaviour scores itself; a reflex over its threshold runs at
## once; otherwise the best runs, the current one scoring STICK times higher so
## a near tie never flips it. It writes one intent a think. It never touches
## physics and never reads the world: only its needs and its NPC's memory.

const STICK := 1.25

var needs := {}
var rises := {}
var behaviours: Array[Behaviour] = []
var current: Behaviour
## When the current behaviour started.
var since := 0.0
## Last think's scores, by id, for the overlay.
var scores := {}
var intent := Intent.idle()

func setup(species: NpcSpecies, rng: RandomNumberGenerator) -> void:
	rises = species.needs.duplicate()
	needs.clear()
	for n: StringName in species.needs:
		var start: Vector2 = species.need_start.get(n, Vector2.ZERO)
		needs[n] = rng.randf_range(start.x, start.y)
	behaviours.clear()
	for id: StringName in species.behaviours:
		var b := NpcBehaviours.make(id)
		if b == null:
			push_error("Brain: %s names no behaviour called %s" % [species.id, id])
			continue
		b.weight = float(species.behaviour_weights.get(id, 1.0))
		behaviours.append(b)
	current = null
	since = 0.0

func think(ctx: NpcContext) -> Intent:
	for n: StringName in needs:
		needs[n] = clampf(needs[n] + float(rises.get(n, 0.0)) * ctx.dt, 0.0, 1.0)
	ctx.needs = needs
	scores.clear()
	var finished := current != null and current.done(ctx)
	var next := _choose(ctx)
	if next != current or (finished and next != null):
		current = next
		since = ctx.time
		if current != null:
			current.start(ctx)
	intent = current.think(ctx) if current != null else Intent.idle()
	return intent

func _choose(ctx: NpcContext) -> Behaviour:
	var held := current != null and ctx.time - since < current.min_time and not current.done(ctx)
	var reflex: Behaviour = null
	var best: Behaviour = null
	var best_score := 0.0
	for b in behaviours:
		var s := b.score(ctx) * b.weight
		scores[b.id] = s
		if b.reflex:
			if s >= b.threshold and (reflex == null or s > float(scores[reflex.id])):
				reflex = b
		else:
			var judged := s * (STICK if b == current else 1.0)
			if judged > best_score:
				best = b
				best_score = judged
	if held and (current.reflex or reflex == null):
		return current
	if reflex != null:
		return reflex
	return best
