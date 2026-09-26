class_name RockHerds
extends RefCounted

## Herds of skitters on the big rocks (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §4.4, §13).

## A big rock's name as a place: the same rock, the same name, every load.
static func site_of(rock: AsteroidRock) -> StringName:
	var id := rock.id()
	return StringName("rock:%d_%d_%d_%d" % [id.x, id.y, id.z, id.w])
