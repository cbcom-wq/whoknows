class_name PlanBounds
extends RefCounted

## Works out the plan's bounds (docs/superpowers/specs/2026-11-19-wadis-land-design.md
## §5.4 step 8, §8.3): the least and most height under each cell, which the
## streaming culls by (WorldPlan.bounds_of). Run once while the plan is built,
## last; the constants it uses are WorldPlan's, and WorldTerrain.bay_depth.

var plan: WorldPlan

func _init(p_plan: WorldPlan) -> void:
	plan = p_plan

## The map's base, shore, dunes, mountain and plateau fields by corner (by k),
## indexed by field; the others are empty.
static func corner_values(map: PlanMap) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	out.resize(WorldPlan.S_SIZE)
	for field in [WorldPlan.S_BASE, WorldPlan.S_SHORE, WorldPlan.S_DUNES, WorldPlan.S_MOUNTAIN, WorldPlan.S_PLATEAU]:
		out[field] = map.values_of(field)
	return out

## Sets the map's bounds (§5.4 step 8, §8.3): by cell, the base's corners' least
## less, and most plus, the most DETAIL_REACH of every land a corner's fields
## allow (a sea corner, or a mountain's, counts the open ground too); under it,
## the lowest floor of any canyon listed near the cell; up to a plateau's top
## and its DETAIL_REACH in every cell with plateau country; up to sea level in
## every cell with a corner under it (the water is drawn there), and down to it
## in every cell with a corner within WorldTerrain.bay_depth of the water (a sea
## cliff's bay and its beach); and over every cell within a kept disc's radius
## and blend, today's desert's range, KEPT_LOW to KEPT_HIGH.
## `cv` is corner_values'.
func set_bounds(recipe: WorldRecipe, dirs: PackedVector3Array, cv: Array[PackedFloat32Array]) -> void:
	var shore := cv[WorldPlan.S_SHORE]
	var dunes := cv[WorldPlan.S_DUNES]
	var mountain := cv[WorldPlan.S_MOUNTAIN]
	var plateau := cv[WorldPlan.S_PLATEAU]
	var sea_reach: float = WorldPlan.DETAIL_REACH[WorldPlan.Land.SEA]
	var dunes_reach: float = WorldPlan.DETAIL_REACH[WorldPlan.Land.DUNES]
	var plains_reach: float = WorldPlan.DETAIL_REACH[WorldPlan.Land.PLAINS]
	var plateau_reach: float = WorldPlan.DETAIL_REACH[WorldPlan.Land.PLATEAU]
	var mountain_reach: float = WorldPlan.DETAIL_REACH[WorldPlan.Land.MOUNTAINS]
	var reach := PackedFloat32Array()
	reach.resize(shore.size())
	for k in reach.size():
		var r := dunes_reach if dunes[k] >= WorldPlan.DUNES_FROM else plains_reach
		if shore[k] <= 0.0:
			r = maxf(r, sea_reach)
		if mountain[k] >= WorldPlan.MOUNTAINS_FROM:
			r = maxf(r, mountain_reach)
		if plateau[k] >= WorldPlan.PLATEAU_FROM:
			r = maxf(r, plateau_reach)
		reach[k] = r
	var low := PackedFloat32Array()
	var high := PackedFloat32Array()
	plan.map.cell_range(WorldPlan.S_BASE, low, high, reach)
	plan.shapes.lower_by_canyons(low)
	# A plateau stands at its top to the water's edge, whose corners stay at sea
	# level (the cliff's foot): up to the top in every cell with plateau country.
	var least := PackedFloat32Array()
	var tops := PackedFloat32Array()
	plan.map.cell_range(WorldPlan.S_PLATEAU_TOP, least, tops)
	var weights := PackedFloat32Array()
	plan.map.cell_range(WorldPlan.S_PLATEAU, least, weights)
	for c in high.size():
		if weights[c] >= WorldPlan.PLATEAU_FROM:
			high[c] = maxf(high[c], tops[c] + plateau_reach)
	if plan.sea_level > -INF:
		var wet := PackedFloat32Array()
		var spare := PackedFloat32Array()
		plan.map.cell_range(WorldPlan.S_SHORE, wet, spare)
		var bay := WorldTerrain.bay_depth(recipe.radius_m)
		for c in wet.size():
			if wet[c] < 0.0:
				high[c] = maxf(high[c], plan.sea_level)
			# A sea cliff's bay lays its beach a little over sea level up to
			# WorldTerrain.bay_depth inland of the water.
			if wet[c] < bay:
				low[c] = minf(low[c], plan.sea_level)
	for keep: Dictionary in recipe.keeps:
		_widen_to_kept(keep, dirs, low, high)
	plan.map.set_bounds(low, high)

## Widens the bounds of every cell within `keep`'s radius and blend (those
## _clear_of_keeps says are not clear), found by a flood from its place, to
## KEPT_LOW and KEPT_HIGH.
func _widen_to_kept(keep: Dictionary, dirs: PackedVector3Array, low: PackedFloat32Array,
		high: PackedFloat32Array) -> void:
	var radius := plan.shapes.radius_m
	var edge := CubeSphere.edge_m(radius, PlanMap.PLAN_DEPTH)
	var inside: float = keep.radius + keep.blend
	var dir: Vector3 = keep.dir
	var reach := inside + 2.0 * edge
	var seen := PackedByteArray()
	seen.resize(low.size())
	seen.fill(0)
	var start := plan.map.cell_number(dir)
	var todo := PackedInt32Array([start])
	seen[start] = 1
	var near := PackedInt32Array()
	near.resize(4)
	var at := 0
	while at < todo.size():
		var c := todo[at]
		at += 1
		var metres := WorldPlan._cell_centre(c, dirs).angle_to(dir) * radius
		if metres > reach:
			continue
		if metres - edge < inside:
			low[c] = minf(low[c], WorldPlan.KEPT_LOW)
			high[c] = maxf(high[c], WorldPlan.KEPT_HIGH)
		plan._cell_neighbours(c, near)
		for o in near:
			if seen[o] == 0:
				seen[o] = 1
				todo.append(o)
