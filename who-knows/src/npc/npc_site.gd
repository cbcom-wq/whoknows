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

## Fills in what behaviours may ask of this place: mates, shelter, spots...
func fill(_ctx: NpcContext, _npc: Npc) -> void:
	pass
