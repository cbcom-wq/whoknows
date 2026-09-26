class_name NpcRecord
extends RefCounted

## One NPC as data (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §4.1): who it is, what it is, and where it lives in its site's own frame. No
## node: population recipes make these on any thread, and the same place always
## makes the same ones.

var id: StringName
var species: StringName
## The place it belongs to: a big rock, a ship.
var site: StringName
## Where it lives, in its site's frame: a rock's local coordinates, a ship's
## interior. Never an engine position: those move with the floating origin.
var home := Vector3.ZERO
## Its own randomness: size, colour, temperament.
var seed := 0
## Which group it belongs to at its site, or -1.
var herd := -1

static func make(p_id: StringName, p_species: StringName, p_site: StringName, p_home: Vector3,
		p_seed: int, p_herd := -1) -> NpcRecord:
	var r := NpcRecord.new()
	r.id = p_id
	r.species = p_species
	r.site = p_site
	r.home = p_home
	r.seed = p_seed
	r.herd = p_herd
	return r
