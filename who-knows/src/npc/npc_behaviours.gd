class_name NpcBehaviours
extends RefCounted

## Behaviour ids, as species name them, to behaviours (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §8). Each NPC gets its own instances.

const _DIR := "res://src/npc/behaviours/%s.gd"

## A new behaviour called `id`, or null if there is none.
static func make(id: StringName) -> Behaviour:
	var path := _DIR % id
	if not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	var b := script.new() as Behaviour
	if b != null:
		b.id = id
	return b

static func exists(id: StringName) -> bool:
	return ResourceLoader.exists(_DIR % id)
