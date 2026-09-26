class_name Behaviour
extends RefCounted

## One thing an NPC can do (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §7.2): it scores itself from the
## context, starts, writes an intent each think, and says when it is done.
## Small and scene-free, so each is tested with a made-up context.

var id: StringName
## A reflex pre-empts anything once its score reaches threshold.
var reflex := false
var threshold := 0.5
## Seconds it keeps running once chosen, unless done or a reflex fires.
var min_time := 1.0
## From the species; multiplies the score.
var weight := 1.0
## When it started, by the context's clock.
var started := 0.0

func score(_ctx: NpcContext) -> float:
	return 0.0

func start(ctx: NpcContext) -> void:
	started = ctx.time

func think(_ctx: NpcContext) -> Intent:
	return Intent.idle()

func done(_ctx: NpcContext) -> bool:
	return false

## Seconds since it started.
func running(ctx: NpcContext) -> float:
	return ctx.time - started

## The distance between two points, ignoring height.
static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Of `points`, the one farthest from `from` (ignoring height), or `fallback`.
static func farthest_from(points: Array, from: Vector3, fallback: Vector3) -> Vector3:
	var best := fallback
	var best_d := -1.0
	for p: Vector3 in points:
		var d := flat_distance(p, from)
		if d > best_d:
			best = p
			best_d = d
	return best

## Where the player is: seen this think, or last remembered within `seconds`;
## null if neither.
static func player_at(ctx: NpcContext, seconds := 5.0) -> Variant:
	if ctx.player != null:
		return ctx.player
	var p := ctx.recent(Perception.PLAYER, seconds)
	return p.where if p != null else null
