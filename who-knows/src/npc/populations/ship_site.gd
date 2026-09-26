class_name ShipSite
extends NpcSite

## A ship's interior as a place NPCs live (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §5.5, §14.2): its frame is the
## interior's, which never moves; its gravity is the interior's felt gravity,
## the same number every loose item gets; and it keeps the droid's map, its
## dock and its jobs, rebuilt with the ship.

var ship: Ship
var paths: DeckPaths
var dock := ShipCrew.NO_DOCK
var spots: Array[Dictionary] = []
## Work spot key -> director time it was last tended.
var tended := {}
## Bumped by every rebind, so a walker knows its path may be stale.
var version := 0

func _init(p_ship: Ship) -> void:
	ship = p_ship
	id = StringName("ship:%s" % p_ship.name)

## Re-reads the ship after a rebuild: its map, its dock, its jobs. Cells with
## no plating are left off the map (spec §5.5).
func rebind(layout: InteriorLayout) -> void:
	var avoid: Array[Vector3i] = []
	for cell in layout.walkable_coords():
		if ship.interior_builder.gravity_at(cell) <= 0.0:
			avoid.append(cell)
	paths = DeckPaths.build(layout, avoid)
	dock = ShipCrew.dock(layout, paths)
	spots = ShipCrew.work_spots(layout, paths)
	version += 1

func frame() -> Transform3D:
	return ship.interior.global_transform

## Plating plus the hull's shove, as MotionCoupling sets it each tick.
func gravity(_local: Vector3) -> Vector3:
	var felt := ship.interior_builder.felt_gravity
	return felt.felt if felt != null else Vector3.DOWN * InteriorBuilder.DEFAULT_GRAVITY

func alive() -> bool:
	return is_instance_valid(ship) and ship.interior_builder.layout() != null and paths != null

## A job finished at `time`.
func tend(key: StringName, time: float) -> void:
	tended[key] = time
