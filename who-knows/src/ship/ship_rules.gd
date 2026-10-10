class_name ShipRules
extends RefCounted

## The rules every ship in the game must pass (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §4): one checker for the catalog test,
## the ship probe and ship_check.gd, the designer's tool. A rule broken means
## the ship must not be given to the player; a note is worth knowing and never
## fails. Each finding is {code, text, cell}: cell is a Vector3i, or null when
## no one cell is to blame.
##
## Pure: it plans the interior, the hull, the droid's paths, the damage
## sections and the stats itself, from the grid, touching no nodes.

## The largest imbalance under a full burn, as a share of an axis's authority
## (the ship skill's step 6).
const IMBALANCE_MOST := 0.05
## Power made must beat power drawn by this much, so a ship we give the player
## never browns out at its first addition.
const POWER_HEADROOM := 1.1
## The most blocks a ship may have (ship designer spec §2.6, §9): the owner's
## first limit was 600, "and see how that goes"; at 600 the worst view fell to
## 116 fps, under the 120 floor, so the owner lowered it to 400 (2026-10-09).
const MOST_BLOCKS := 400
## The validator's issues that name a cell.
const _CELL_ISSUES: Array[StringName] = [&"ALL_CONNECTED", &"MOUNTS_REACHABLE", &"AIRLOCK_HATCH"]
const _AXES: Array[String] = ["pitch", "yaw", "roll"]
const _TURNS: Array[String] = ["pitches", "yaws", "rolls"]

static func check(grid: ShipGrid, catalog: BlockCatalog) -> Dictionary:
	var rules: Array = []
	var notes: Array = []
	var coords: Array = grid.coords()
	coords.sort()
	for coord: Vector3i in coords:
		var id := grid.get_block(coord).block_id
		if not catalog.has(id):
			rules.append(item(&"UNKNOWN_BLOCK", "no block called \"%s\" in data/blocks" % id, coord))
	if not rules.is_empty():
		return {"rules": rules, "notes": notes}
	if grid.size() > MOST_BLOCKS:
		rules.append(item(&"TOO_BIG", "%d blocks: a ship may have %d" % [grid.size(), MOST_BLOCKS]))
	for issue in ShipValidator.validate(grid, catalog):
		var cell: Variant = null
		if _CELL_ISSUES.has(issue.code):
			cell = issue.coord
		rules.append(item(&"VALIDATOR", "%s: %s" % [issue.code, issue.message], cell))
	var stats := ShipStats.compute(grid, catalog)
	_check_flight(stats, rules)
	var layout := InteriorLayout.plan(grid, catalog, DeckGraph.build(grid, catalog).walkable_coords())
	var paths := DeckPaths.build(layout)
	_check_cabin(layout, paths, rules)
	_check_seats(grid, layout, paths, rules)
	_check_droid(layout, paths, rules)
	for w in HullLayout.plan(grid, catalog, layout).unmatched:
		rules.append(item(&"WINDOW_UNMATCHED", "the window in %s's wall toward %s has no place outside"
			% [w["coord"], w["normal"]], w["coord"]))
	_check_pieces(grid, catalog, rules)
	_note(grid, catalog, stats, notes)
	return {"rules": rules, "notes": notes}

## One finding.
static func item(code: StringName, text: String, cell: Variant = null) -> Dictionary:
	return {"code": code, "text": text, "cell": cell}

## Where you stand up to from a helm at `helm` facing `facing`: the first of
## the cell behind it and the two beside it (where PilotSeat.STAND_SPOTS lie)
## that is open floor, or null. Stricter than the seat, which can also step
## past a quiet fixture.
static func stand_cell(helm: Vector3i, facing: Vector3i, paths: DeckPaths) -> Variant:
	var side := Vector3i(-facing.z, 0, facing.x)
	for c: Vector3i in [helm - facing, helm + side, helm - side]:
		if paths.has(c):
			return c
	return null

## Power, thrust both ways, turning on every axis, balance under a burn, and
## not crippled as built.
static func _check_flight(s: ShipStats, rules: Array) -> void:
	if s.power_gen <= s.power_draw * POWER_HEADROOM:
		rules.append(item(&"POWER_MARGIN", "%.1f MW made for %.1f MW drawn: it needs %.1f, 10%% to spare"
			% [s.power_gen, s.power_draw, s.power_draw * POWER_HEADROOM]))
	if s.thrust_budget[&"forward"] <= 0.0:
		rules.append(item(&"CANNOT_THRUST", "no forward thrust: no main thruster pushes it forward"))
	if s.thrust_budget[&"reverse"] <= 0.0:
		rules.append(item(&"CANNOT_BRAKE", "no reverse thrust: it can never slow down (give it a retro pair)"))
	for axis in 3:
		var authority: float = s.torque_budget[axis]
		if authority <= 0.0:
			rules.append(item(&"NO_AUTHORITY", "no %s authority: rcs in opposed pairs turn it both ways" % _AXES[axis]))
		elif absf(s.torque_imbalance[axis]) >= authority * IMBALANCE_MOST:
			rules.append(item(&"UNBALANCED", "a full burn %s it with %.1f%% of its %s authority: keep it under %d%%"
				% [_TURNS[axis], absf(s.torque_imbalance[axis]) / authority * 100.0, _AXES[axis],
				roundi(IMBALANCE_MOST * 100.0)]))
	if s.crippled:
		rules.append(item(&"CRIPPLED", "crippled as built: %s" % s.crippled_reason))

const _SIDES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

## The seats that do not fly (ship bridge spec §6.1): somewhere to stand up
## to, not facing a wall, a dais you can walk onto, and reachable on foot from
## an airlock.
static func _check_seats(grid: ShipGrid, layout: InteriorLayout, paths: DeckPaths, rules: Array) -> void:
	var reach := {}
	for lock in layout.airlocks():
		for n in _SIDES:
			var c: Vector3i = lock["coord"] + n
			if paths.has(c):
				reach = paths.distances(c)
				break
		if not reach.is_empty():
			break
	for f in layout.fixtures():
		if not InteriorLayout.SEAT_IDS.has(f["id"]):
			continue
		var at: Vector3i = f["coord"]
		var facing := InteriorLayout.facing(f["orientation"])
		if stand_cell(at, facing, paths) == null:
			rules.append(item(&"NO_STAND", "nowhere to stand up from the %s: behind it and beside it is no open floor" % f["id"], at))
		var ahead := at + facing
		var at_glass := grid.has_block(ahead) and grid.get_block(ahead).block_id == InteriorLayout.CANOPY_ID
		if not at_glass and not paths.has(ahead):
			rules.append(item(&"SEAT_FACES_WALL", "the %s looks straight into %s" % [f["id"], ahead], at))
		if f["id"] == &"captain_chair" and not paths.has(at - facing):
			rules.append(item(&"DAIS_BLOCKED", "the captain's dais has no open floor behind its ramp", at))
		var beside := false
		for n in _SIDES:
			if reach.has(at + n):
				beside = true
		if not reach.is_empty() and not beside:
			rules.append(item(&"UNREACHABLE", "the %s cannot be walked to from the airlock" % f["id"], at))

## One helm that sees out (a pod, or a bridge helm at its glass: ship bridge
## spec §6.1), standing up from it, an airlock that cycles, and every cell
## reachable on foot from the helm.
static func _check_cabin(layout: InteriorLayout, paths: DeckPaths, rules: Array) -> void:
	var helms := []
	for f in layout.fixtures():
		if InteriorLayout.HELM_IDS.has(f["id"]):
			helms.append(f)
	if helms.size() > 1:
		rules.append(item(&"TWO_HELMS", "%d seats fly this ship: a ship has one pilot seat or one helm" % helms.size(),
			helms[1]["coord"]))
	var sees := not layout.pods().is_empty()
	for f in helms:
		if f["id"] == InteriorLayout.BRIDGE_HELM:
			var facing := InteriorLayout.facing(f["orientation"])
			for face in layout.faces():
				if face["kind"] == InteriorLayout.Kind.CANOPY and face["coord"] == f["coord"] and face["normal"] == facing:
					sees = true
	if not sees:
		rules.append(item(&"NO_HELM", "no pilot seat looks straight at a canopy (a pod), and no helm has a canopy face straight ahead (a bridge)"))
	var helm: Variant = null
	var start: Variant = null
	for f in layout.fixtures():
		if InteriorLayout.HELM_IDS.has(f["id"]):
			helm = f["coord"]
			start = stand_cell(f["coord"], InteriorLayout.facing(f["orientation"]), paths)
			break
	if helm != null and start == null:
		rules.append(item(&"NO_STAND", "nowhere to stand up from the helm: behind it and beside it is no open floor", helm))
	var wanted := paths.cells()
	var cycles := false
	for lock in layout.airlocks():
		if lock["door_normal"] == Vector3i.ZERO:
			continue
		cycles = true
		var inside: Vector3i = lock["coord"] + lock["door_normal"]
		if not wanted.has(inside):
			wanted.append(inside)
	if not cycles:
		rules.append(item(&"NO_AIRLOCK", "no airlock that cycles with a way in through its inner hatch"))
	if start == null:
		return
	var reach := paths.distances(start)
	var missing := {}   # storey -> the cells on it out of reach
	for c in wanted:
		if not reach.has(c):
			missing.get_or_add(c.y, []).append(c)
	var storeys := missing.keys()
	storeys.sort()
	for y: int in storeys:
		var cells: Array = missing[y]
		cells.sort()
		if y == helm.y:
			rules.append(item(&"CUT_OFF", "%d cells can't be reached on foot from the helm, the first %s"
				% [cells.size(), cells[0]], cells[0]))
		else:
			rules.append(item(&"CUT_OFF", "cells on storey %d can't be reached from the helm: ladders don't climb yet"
				% y, cells[0]))

## The maintenance droid (NPC foundation spec §14): on a ship big enough to
## have one, a dock, and every job it tends reachable from there.
static func _check_droid(layout: InteriorLayout, paths: DeckPaths, rules: Array) -> void:
	if layout.walkable_coords().size() < ShipCrew.MIN_CELLS:
		return
	var dock := ShipCrew.dock(layout, paths)
	if dock == ShipCrew.NO_DOCK:
		rules.append(item(&"DROID", "the maintenance droid has nowhere to dock"))
		return
	var reachable := ShipCrew.reachable_spots(layout, paths)
	var lost: Array = []
	for spot in ShipCrew.work_spots(layout, paths):
		if not reachable.has(spot):
			lost.append(spot)
	if not lost.is_empty():
		rules.append(item(&"DROID", "the droid can't walk from its dock at %s to %d of its jobs, the first %s"
			% [dock, lost.size(), lost[0]["key"]], lost[0]["cell"]))

## Every hull section has pieces to lose (ship damage sections spec §4), or a
## hit there never shows a hole.
static func _check_pieces(grid: ShipGrid, catalog: BlockCatalog, rules: Array) -> void:
	var damage := ShipDamage.build(grid, catalog, Ship.inner_of(grid, catalog))
	for id: StringName in ShipDamage.SECTIONS:
		if (damage.pieces[id] as Array).is_empty():
			rules.append(item(&"NO_PIECES", "the %s has no plating or fairing outside the cabin to lose: it never shows a hole"
				% String(ShipDamage.SECTION_LABELS[id]).to_lower()))

## Worth knowing, never failing: rcs whose puffs are hidden, how it flies, and
## its size.
static func _note(grid: ShipGrid, catalog: BlockCatalog, s: ShipStats, notes: Array) -> void:
	for b in RcsShow.gather(grid, catalog, s.center_of_mass):
		var into: Vector3i = b["coord"] - Vector3i((b["force"] as Vector3).normalized().round())
		if grid.has_block(into):
			notes.append(item(&"RCS_BLOCKED", "the rcs at %s fires into the block at %s: its puffs never show"
				% [b["coord"], into], b["coord"]))
	var kg := maxf(s.total_mass_kg, 1.0)
	notes.append(item(&"FEEL", "turns %.2f / %.2f / %.2f rad/s2 (pitch / yaw / roll); side %.1f, vertical %.1f, brake %.1f, forward %.1f m/s2" % [
		s.torque_budget.x / maxf(s.inertia.x, 1.0), s.torque_budget.y / maxf(s.inertia.y, 1.0),
		s.torque_budget.z / maxf(s.inertia.z, 1.0), s.thrust_budget[&"lateral"] / kg,
		s.thrust_budget[&"vertical"] / kg, s.thrust_budget[&"reverse"] / kg, s.thrust_budget[&"forward"] / kg]))
	notes.append(item(&"SIZE", "%d blocks, %.1f t; %.1f MW made, %.1f drawn; %d QE, %.0f km of warp on a full store" % [
		grid.size(), s.total_mass_kg / 1000.0, s.power_gen, s.power_draw, s.quantum_capacity,
		maxf(s.quantum_capacity - WarpPlan.WARP_BASE, 0) * WarpPlan.WARP_M_PER_QE / 1000.0]))
