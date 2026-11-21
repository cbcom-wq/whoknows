class_name PlanSites
extends RefCounted

## Finds a world plan's sites (docs/superpowers/specs/2026-11-19-wadis-land-design.md
## §5.4 step 7, §5.5): its oases, its shore ledges and a kept site for each kept
## disc. Run once while the plan is built (WorldPlan.build), after its canyons,
## buttes and kept discs are in; the constants it uses are WorldPlan's.

var plan: WorldPlan

func _init(p_plan: WorldPlan) -> void:
	plan = p_plan

## Lists the plan's sites (§5.4 step 7). `cv` is the map's base, shore, dunes,
## mountain and plateau fields by corner (corner_values). Candidates are cells,
## weighed from their corners alone: oases among every SITE_STRIDEth cell each
## way (sites lie thousands of metres apart), shore sites among the land cells
## beside a sea's. A candidate is ranked (see OASIS_FAVOUR and the constants
## round it), then the best first are looked at closely (_site_at) one at a
## time and kept if they pass and keep their distance from those kept: the
## cells' worth is weighed once, the exact work done for a few. Each kind is
## listed best first by its rank, its exact level in it. A KEPT site is added for
## each kept disc, and each oasis is given a seeded heading.
func list(recipe: WorldRecipe, dirs: PackedVector3Array, cv: Array[PackedFloat32Array]) -> Array[PlanSite]:
	var sites: Array[PlanSite] = []
	var radius := recipe.radius_m
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	var base := cv[WorldPlan.S_BASE]
	var shore := cv[WorldPlan.S_SHORE]
	var dunes := cv[WorldPlan.S_DUNES]
	var mountain := cv[WorldPlan.S_MOUNTAIN]
	var up := PlanMap.SIDE
	var cells := CubeSphere.FACES * PlanMap.CELLS * PlanMap.CELLS
	assert(cells <= 32768, "_sort_key holds a cell number in 15 bits")
	# By cell, what ranking the candidates found: its rank and its cell-wide level.
	var rank := PackedFloat32Array()
	rank.resize(cells)
	var wide := PackedFloat32Array()
	wide.resize(cells)
	var oases := PackedFloat64Array()
	var shores := PackedFloat64Array()
	# The rise across a cell that is a level of 1.
	var steep := WorldPlan.SITE_ROUGH_SLOPE * edge
	var c := -1
	for face in CubeSphere.FACES:
		for j in PlanMap.CELLS:
			var row := (face * up + j) * up
			for i in PlanMap.CELLS:
				c += 1
				if j % WorldPlan.SITE_STRIDE != 0 or i % WorldPlan.SITE_STRIDE != 0:
					continue
				var k := row + i
				var s := 0.25 * (shore[k] + shore[k + 1] + shore[k + up] + shore[k + up + 1])
				if s < WorldPlan.OASIS_SHORE_MIN:
					continue
				var a := base[k]
				var b := base[k + 1]
				var d := base[k + up]
				var e := base[k + up + 1]
				var spread := maxf(maxf(a, b), maxf(d, e)) - minf(minf(a, b), minf(d, e))
				if spread > steep * WorldPlan.OASIS_LEVEL_MAX:
					continue
				var m := maxf(maxf(mountain[k], mountain[k + 1]), maxf(mountain[k + up], mountain[k + up + 1]))
				var favours := int(m > 0.0) + int(s <= WorldPlan.OASIS_COAST) + int(plan.shapes.canyon_floor_low(c) < INF)
				var mean := 0.25 * (a + b + d + e)
				var dune := 0.25 * (dunes[k] + dunes[k + 1] + dunes[k + up] + dunes[k + up + 1])
				if dune >= WorldPlan.DUNES_FROM and i >= 3 and j >= 3 and i < PlanMap.CELLS - 3 and j < PlanMap.CELLS - 3:
					var around := 0.25 * (base[k - 3] + base[k + 3] + base[k - 3 * up] + base[k + 3 * up])
					favours += int(mean <= around - WorldPlan.OASIS_HOLLOW)
				wide[c] = spread / steep
				rank[c] = wide[c] + WorldPlan.OASIS_LOW_RANK * clampf((mean + WorldPlan.BASE_ROLL) / (2.0 * WorldPlan.BASE_ROLL), 0.0, 1.0) \
					- WorldPlan.OASIS_FAVOUR * favours
				oases.append(_sort_key(rank[c], c))
	if plan.sea_level > -INF:
		var near := PackedInt32Array()
		near.resize(4)
		# 2 for a sea's cells, 1 for any other looked at.
		var listed := PackedByteArray()
		listed.resize(cells)
		listed.fill(0)
		for sea: Dictionary in plan.shapes.seas:
			for w: int in sea.cells:
				listed[w] = 2
		for sea: Dictionary in plan.shapes.seas:
			for w: int in sea.cells:
				plan._cell_neighbours(w, near)
				for o in near:
					if listed[o] != 0:
						continue
					listed[o] = 1
					var k := WorldPlan._first_corner(o)
					var s := 0.25 * (shore[k] + shore[k + 1] + shore[k + up] + shore[k + up + 1])
					if s <= 0.0 or s > WorldPlan.SHORE_SITE_REACH * 1.5:
						continue
					var spread := maxf(maxf(base[k], base[k + 1]), maxf(base[k + up], base[k + up + 1])) \
						- minf(minf(base[k], base[k + 1]), minf(base[k + up], base[k + up + 1]))
					if spread > steep * WorldPlan.SHORE_LEVEL_MAX:
						continue
					wide[o] = spread / steep
					rank[o] = wide[o]
					shores.append(_sort_key(rank[o], o))
	var rng := WorldSeed.rng(recipe.seed, &"plan_sites")
	for site: PlanSite in _pick(oases, rank, wide, dirs, PlanSite.Kind.OASIS, WorldPlan.OASIS_SPACING, plan.dials.oases + WorldPlan.OASIS_EXTRA, radius):
		site.heading = rng.randf_range(0.0, 360.0)
		sites.append(site)
	for site: PlanSite in _pick(shores, rank, wide, dirs, PlanSite.Kind.SHORE, WorldPlan.SHORE_SPACING, WorldPlan.SHORE_MAX, radius):
		site.heading = _facing_sea(site.dir, radius)
		sites.append(site)
	for keep: Dictionary in recipe.keeps:
		var site := PlanSite.new()
		site.kind = PlanSite.Kind.KEPT
		site.dir = keep.dir
		site.radius = keep.radius
		site.heading = float(keep.get("heading", 0.0))
		sites.append(site)
	return sites

## A sort key for candidate cell `c` of rank `rank`: ascending is rank order,
## ties by cell (_cell_of_key undoes it). Exact in a double.
static func _sort_key(rank: float, c: int) -> float:
	return floorf((rank + 4.0) * 10000.0) * 32768.0 + c

static func _cell_of_key(key: float) -> int:
	return int(key) % 32768

## The sites of `kind` among the candidates `keys` (_sort_key), at most `cap`,
## at least `spacing` metres apart: the best candidate that passes a close look
## (_site_at), then the best that does and is clear of it, and so on. Listed
## best first by rank, with the exact level in place of the cell-wide `wide`.
func _pick(keys: PackedFloat64Array, rank: PackedFloat32Array, wide: PackedFloat32Array, dirs: PackedVector3Array,
		kind: PlanSite.Kind, spacing: float, cap: int, radius: float) -> Array[PlanSite]:
	keys.sort()
	# Past this cosine two directions are nearer than `spacing` (a hair more).
	var near := cos(minf(spacing * 1.001 / radius, PI))
	var out: Array[PlanSite] = []
	var fields := PackedFloat64Array()
	fields.resize(WorldPlan.LAND_FIELDS)
	for key in keys:
		if out.size() >= cap:
			break
		var c := _cell_of_key(key)
		var mid := WorldPlan._cell_centre(c, dirs)
		var clear := true
		for other in out:
			if mid.dot(other.dir) > near:
				clear = false
				break
		if not clear:
			continue
		var level := _site_at(mid, c, kind, radius, fields)
		if level < 0.0:
			continue
		var site := PlanSite.new()
		site.kind = kind
		site.dir = mid
		site.radius = WorldPlan.SITE_RADIUS
		site.level = level
		site.rank = rank[c] - wide[c] + level
		out.append(site)
	out.sort_custom(func(a: PlanSite, b: PlanSite) -> bool: return a.rank < b.rank)
	return out

## The level of a site of `kind` at `mid`, the middle of cell number `c`, or -1
## if there can be none there: the ground is not what that kind needs (OASIS:
## dune or gravel ground OASIS_SHORE_MIN or more from the water; SHORE: land 0
## to SHORE_SITE_REACH from it), a kept disc is within SITE_RADIUS, a butte's
## reach within SITE_RADIUS and BUTTE_SITE_CLEAR, a canyon's walls reach it or the
## ring of points SITE_RADIUS round it, or its level is over the kind's most.
## `fields` is scratch, LAND_FIELDS long.
func _site_at(mid: Vector3, c: int, kind: PlanSite.Kind, radius: float, fields: PackedFloat64Array) -> float:
	plan.map.sample(mid, fields, WorldPlan.LAND_FIELDS)
	var metres := fields[WorldPlan.S_SHORE]
	var land := WorldPlan.land_in(fields)
	var most: float
	if kind == PlanSite.Kind.OASIS:
		if (land != WorldPlan.Land.DUNES and land != WorldPlan.Land.PLAINS) or metres < WorldPlan.OASIS_SHORE_MIN:
			return -1.0
		most = WorldPlan.OASIS_LEVEL_MAX
	else:
		if metres <= 0.0 or metres > WorldPlan.SHORE_SITE_REACH:
			return -1.0
		most = WorldPlan.SHORE_LEVEL_MAX
	if not _clear_of_sites(mid, WorldPlan.SITE_RADIUS, radius) or plan.shapes.canyon_at(mid, c).x < INF \
			or not plan.shapes.clear_of_buttes(mid, WorldPlan.SITE_RADIUS + WorldPlan.BUTTE_SITE_CLEAR):
		return -1.0
	var angle := WorldPlan.SITE_RADIUS / radius
	var near_canyon := plan.shapes.canyon_floor_low(c) < INF
	var base := fields[WorldPlan.S_BASE]
	var worst := 0.0
	for n in 8:
		var d := WorldPlan._toward(mid, angle, n * TAU / 8.0)
		if near_canyon and plan.shapes.canyon_at(d, plan.map.cell_number(d)).x < INF:
			return -1.0
		worst = maxf(worst, absf(plan.map.at(WorldPlan.S_BASE, d) - base))
	var level := minf(worst / WorldPlan.SITE_RADIUS / WorldPlan.SITE_ROUGH_SLOPE, 1.0)
	return level if level <= most else -1.0

## True if `d`, and a disc of `margin` metres round it, is clear of every kept
## disc's radius and blend.
func _clear_of_sites(d: Vector3, margin: float, radius: float) -> bool:
	for n in plan._keep_dirs.size():
		if d.angle_to(plan._keep_dirs[n]) * radius - margin < plan._keep_radius[n] + plan._keep_blend[n]:
			return false
	return true

## The heading, degrees clockwise from north (as PlaceDesign.heading), toward the
## sea from `at`: the way the shore's metres fall off most steeply over 300 m
## either way.
func _facing_sea(at: Vector3, radius: float) -> float:
	var frame := SystemDesign.frame_at(at, 0.0)
	var east := frame.x
	var north := -frame.z
	var angle := 300.0 / radius
	var e := plan.nearest_shore_m((at * cos(angle) - east * sin(angle)).normalized()) \
		- plan.nearest_shore_m((at * cos(angle) + east * sin(angle)).normalized())
	var n := plan.nearest_shore_m((at * cos(angle) - north * sin(angle)).normalized()) \
		- plan.nearest_shore_m((at * cos(angle) + north * sin(angle)).normalized())
	return fposmod(rad_to_deg(atan2(e, n)), 360.0)
