class_name NpcSite
extends RefCounted

## What a place tells its NPCs (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4): its frame, its gravity, whether it
## still exists, where a record wakes, and the helpers its behaviours ask for.
## The only thing that knows the place: the brain and the locomotors ask the
## site.

var id: StringName

## Site-local to engine space.
func frame() -> Transform3D:
	return Transform3D.IDENTITY

## Engine-space gravity at a site-local point, m/s^2.
func gravity(_local: Vector3) -> Vector3:
	return Vector3.ZERO

## False once the place is gone (a rock out of detail, a ship torn down).
func alive() -> bool:
	return true

## Where `record` wakes at `time`, site-local, feet on the ground and up the
## way it stands.
func start_pose(record: NpcRecord, _time: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, record.home)

## The colour its NPCs take from it, if any: a skitter wears its rock's.
func tint() -> Color:
	return SpacePalette.UNTINTED

## Fills in what behaviours may ask of this place: mates, shelter, spots...
func fill(_ctx: NpcContext, _npc: Npc) -> void:
	pass

## Called by the body when `npc` dies for good (not when it is only knocked
## out), after the ledger is marked. A site with something to do on a death
## (a drop, a count) overrides it.
func died(_npc: Npc) -> void:
	pass

## Called by the body when `npc` comes up out of the ground.
func surfaced(_npc: Npc) -> void:
	pass

## QE/s the body may drain from this site's own store for `npc`, over `dt`
## seconds; 0 when the place has none.
func sip_source(_npc: Npc, _dt: float) -> float:
	return 0.0

## The seed of the group `record` belongs to; a site with no groups gives the
## record's own.
func group_seed(record: NpcRecord) -> int:
	return record.seed
