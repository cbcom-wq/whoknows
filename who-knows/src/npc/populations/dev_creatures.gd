class_name DevCreatures
extends RefCounted

## The creatures F10 makes (docs/superpowers/specs/
## 2026-10-18-rock-creatures-design.md §7.2): a source of one director, offered
## like any other, for the session only. Nothing here is a place's recipe or
## is saved: an entry goes when its site does, or once its creature has been
## live and no longer is (demoted, or dead), so a spawn is never owed back.

## [record, site, seen_live] per spawn.
var _entries: Array[Array] = []
## species -> how many ids it has been given.
var _counts := {}

## The `[record, site]` entries still on offer to `director`.
func records(director: NpcDirector) -> Array:
	var out: Array = []
	var kept: Array[Array] = []
	for e in _entries:
		var record: NpcRecord = e[0]
		var site: NpcSite = e[1]
		if not site.alive():
			continue
		if director.live.has(record.id):
			e[2] = true
		elif e[2]:
			continue
		kept.append(e)
		out.append([record, site])
	_entries = kept
	return out

func add(record: NpcRecord, site: NpcSite) -> void:
	_entries.append([record, site, false])

## The next id of `species`: "dev:<species>:<n>", n from 1 for the session.
## Never the shape of a rock's ("<species>:<site>:<group>:<n>").
func next_id(species: StringName) -> StringName:
	var n: int = int(_counts.get(species, 0)) + 1
	_counts[species] = n
	return StringName("dev:%s:%d" % [species, n])
