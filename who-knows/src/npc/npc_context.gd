class_name NpcContext
extends RefCounted

## All a behaviour may read (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §7.2). Behaviours never see a scene, so
## each can be tested with a context made up in the test. Points are
## site-local.

var record: NpcRecord
var species: NpcSpecies
var needs: Dictionary = {}
var memory: NpcMemory
var time := 0.0
## Seconds since the last think.
var dt := 0.2
var position := Vector3.ZERO
var forward := Vector3.FORWARD
var up := Vector3.UP
## A light is on it now.
var lit := false
## Standing on a floor or gripping a surface, not drifting.
var grounded := true
## Herd mates' positions.
var mates: Array[Vector3] = []
## Named places the site offers: &"dock", &"shelter", &"round" ...
var places: Dictionary = {}
## Work spots, for a crew site: {cell, facing, action, key, at: Vector3, since: float}.
var spots: Array[Dictionary] = []
## The player's position if seen this think, else null; and whether they
## moved since the last.
var player: Variant = null
var player_moving := false
## Anything the site or perception adds for one behaviour.
var extra: Dictionary = {}
## Set by a behaviour to ask the body for a sound (&"chirp", &"beep").
var voice: StringName = &""

func need(n: StringName) -> float:
	return float(needs.get(n, 0.0))

## Lowers need `n` at `rate` per second over this think.
func ease(n: StringName, rate: float) -> void:
	if needs.has(n):
		needs[n] = clampf(needs[n] - rate * dt, 0.0, 1.0)

func raise(n: StringName, amount: float) -> void:
	if needs.has(n):
		needs[n] = clampf(needs[n] + amount, 0.0, 1.0)

## The strongest percept of `kind` noted within the last `seconds`, or null.
func recent(kind: StringName, seconds: float) -> NpcMemory.Percept:
	if memory == null:
		return null
	var best: NpcMemory.Percept = null
	for p in memory.percepts:
		if p.kind == kind and time - p.at <= seconds and (best == null or p.sure > best.sure):
			best = p
	return best
