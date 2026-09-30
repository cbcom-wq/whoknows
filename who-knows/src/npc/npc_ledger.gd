class_name NpcLedger
extends RefCounted

## What happened to NPCs that must stick (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §6; NPC foundation spec §4.5): the
## dead, never made live again, and the wounds of the living, kept while they
## sleep. Records are made afresh by their recipes, so nothing can live on a
## record: NpcDirector.amend() reads this instead. One per game, given to
## every director, and saved.

var _dead := {}     # StringName id -> true
var _health := {}   # StringName id -> hp

func mark_dead(id: StringName) -> void:
	_dead[id] = true
	_health.erase(id)

func is_dead(id: StringName) -> bool:
	return _dead.has(id)

## Remembers `hp` for `id`, or forgets it when it is full.
func set_health(id: StringName, hp: float, max_hp: float) -> void:
	if hp >= max_hp:
		_health.erase(id)
	else:
		_health[id] = hp

## `id`'s health, or `max_hp` if it was never hurt.
func health_of(id: StringName, max_hp: float) -> float:
	return float(_health.get(id, max_hp))

func dead_count() -> int:
	return _dead.size()

func to_dict() -> Dictionary:
	var hurt := {}
	for id: StringName in _health:
		hurt[String(id)] = _health[id]
	return {"dead": _dead.keys().map(func(id: StringName) -> String: return String(id)), "hurt": hurt}

func from_dict(d: Dictionary) -> void:
	_dead.clear()
	_health.clear()
	for id in d.get("dead", []):
		_dead[StringName(id)] = true
	var hurt: Dictionary = d.get("hurt", {})
	for id in hurt:
		_health[StringName(id)] = float(hurt[id])
