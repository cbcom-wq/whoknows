class_name ShipCrew
extends RefCounted

## Who lives aboard a ship (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §14.2): one maintenance droid per
## ship big enough to need one, docked in its closet, and the jobs it tends,
## all read from the ship's own layout so any blueprint gets them.
##
## Pure: reads the layout and its paths, touches no nodes.

const SPECIES := &"maintenance_droid"
## A ship smaller than this has no droid.
const MIN_CELLS := 12
const CLOSET := &"closet"
const NO_DOCK := Vector3i(-99999, -99999, -99999)

const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Where the droid lives: a cell of the closet if the ship has one it can
## reach, else the cell it can reach farthest from the helm. NO_DOCK if none.
static func dock(layout: InteriorLayout, paths: DeckPaths) -> Vector3i:
	for cell in paths.cells():
		if layout.zone_at(cell) == CLOSET:
			return cell
	var helm_side: Array[Vector3i] = []
	for f in layout.fixtures():
		if InteriorLayout.HELM_IDS.has(f["id"]):
			for n in _HORIZONTAL:
				if paths.has(f["coord"] + n):
					helm_side.append(f["coord"] + n)
	if helm_side.is_empty():
		var all := paths.cells()
		return all[all.size() - 1] if not all.is_empty() else NO_DOCK
	helm_side.sort()
	var steps := paths.distances(helm_side[0])
	var best := NO_DOCK
	var best_steps := -1
	for cell in paths.cells():
		var s: int = steps.get(cell, -1)
		if s > best_steps:
			best = cell
			best_steps = s
	return best

## The jobs it tends: {cell, facing, action, key}, sorted by key. A porthole
## is polished, a console or display scanned, lockers tidied, each from the
## floor in front of it; a fixture is scanned from beside it, never from its
## own cell.
static func work_spots(layout: InteriorLayout, paths: DeckPaths) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for face in layout.faces():
		if face["kind"] != InteriorLayout.Kind.WALL or not paths.has(face["coord"]):
			continue
		var action := &""
		if face.get("porthole", false):
			action = &"polish"
		else:
			match face.get("variant", InteriorLayout.WallVariant.NONE):
				InteriorLayout.WallVariant.CONSOLE, InteriorLayout.WallVariant.DISPLAY:
					action = &"scan"
				InteriorLayout.WallVariant.LOCKERS:
					action = &"tidy"
		if action == &"":
			continue
		out.append({"cell": face["coord"], "facing": face["normal"], "action": action,
			"key": StringName("wall:%s|%s" % [face["coord"], face["normal"]])})
	for f in layout.fixtures():
		var beside: Array[Vector3i] = []
		for n in _HORIZONTAL:
			if paths.has(f["coord"] + n):
				beside.append(f["coord"] + n)
		if beside.is_empty():
			continue
		beside.sort()
		out.append({"cell": beside[0], "facing": f["coord"] - beside[0], "action": &"scan",
			"key": StringName("fixture:%s" % f["coord"])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["key"]) < String(b["key"]))
	return out

## The jobs the droid can walk to from its dock. A job walled off by fixtures
## (the helm, the quantum core and machine) is left out rather than tried for
## ever.
static func reachable_spots(layout: InteriorLayout, paths: DeckPaths) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := dock(layout, paths)
	if at == NO_DOCK:
		return out
	var steps := paths.distances(at)
	for spot in work_spots(layout, paths):
		if steps.has(spot["cell"]):
			out.append(spot)
	return out

## The ship's crew as records: one droid, or none for a small ship.
static func records(layout: InteriorLayout, paths: DeckPaths, ship: StringName,
		world_seed: int) -> Array[NpcRecord]:
	var out: Array[NpcRecord] = []
	if layout.walkable_coords().size() < MIN_CELLS:
		return out
	var at := dock(layout, paths)
	if at == NO_DOCK:
		return out
	out.append(NpcRecord.make(StringName("droid:%s:0" % ship), SPECIES, StringName("ship:%s" % ship),
		DeckPaths.floor_point(at), AsteroidRecipe.mix(world_seed ^ stable_hash(String(ship)))))
	return out

## A hash of a string that never changes between engine versions.
static func stable_hash(s: String) -> int:
	var h := 0
	for b in s.to_utf8_buffer():
		h = AsteroidRecipe.mix(h ^ b)
	return h
