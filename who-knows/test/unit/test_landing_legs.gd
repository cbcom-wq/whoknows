extends GutTest

## Landing legs (desert world phase 0, Task 15; the owner's decision,
## 2026-11-04): four chunky legs, worked out from each ship's own shape, fold
## out about 40 m over a world's ground and tuck back up past 60 m, so a landed
## ship stands on its feet with its keel strip and belly turret clear of the
## sand, instead of resting on its keel and reading as hovering.

const EPS := 0.001
const SHIPS: Array[StringName] = [&"starter", &"lamplighter", &"warden"]

var _blocks: BlockCatalog

func _grid(id: StringName) -> ShipGrid:
	return ShipLibrary.read("res://data/ships/%s.json" % id)["grid"]

## The blocks, loaded once for the pure tests (the plan reads the looks).
func _catalog() -> BlockCatalog:
	if _blocks == null:
		_blocks = BlockCatalog.load_from_dir()
	return _blocks

## The middle of a grid's footprint, x and z, in metres.
static func _middle(grid: ShipGrid) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector3i in grid.coords():
		var p := ShipGrid.cell_center(c)
		lo = Vector2(minf(lo.x, p.x - 1.0), minf(lo.y, p.z - 1.0))
		hi = Vector2(maxf(hi.x, p.x + 1.0), maxf(hi.y, p.z + 1.0))
	return (lo + hi) * 0.5

## The cells a leg hangs through: its mount, down to the cell its foot is in.
static func _column(leg: Dictionary) -> Array[Vector3i]:
	var cell: Vector3i = leg["cell"]
	var foot: Vector3 = leg["foot"]
	var out: Array[Vector3i] = []
	for y in range(cell.y, roundi(foot.y / ShipGrid.CELL_SIZE) - 1, -1):
		out.append(Vector3i(cell.x, y, cell.z))
	return out

## Every cell a landing ramp's sample points fall in, worked out here from the
## ramp's own pure pieces (not from LandingLegs).
static func _ramp_cells(grid: ShipGrid) -> Dictionary:
	var out := {}
	for c: Vector3i in grid.coords():
		if grid.get_block(c).block_id != AirlockSite.AIRLOCK_ID:
			continue
		var normal := AirlockSite.hatch_normal(grid, c)
		if normal == Vector3i.ZERO:
			continue
		var plan := AirlockAlcove.ramp_plan(grid, c)
		if plan["need"] != LandingRamp.RAMP:
			continue
		var hinge := AirlockAlcove.hinge_frame(c, normal)
		for p in LandingRamp.sample_points(plan["length"], LandingRamp.SLOPE):
			out[Vector3i(((hinge * p) / ShipGrid.CELL_SIZE).round())] = true
	return out

## Engines, and RCS blocks whose exhaust faces down.
static func _keep_clear(grid: ShipGrid) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c: Vector3i in grid.coords():
		var inst := grid.get_block(c)
		if inst.block_id == &"thruster":
			out.append(c)
		elif inst.block_id == &"rcs" and (BlockOrientation.basis_for(inst.orientation) * Vector3.FORWARD).y > 0.5:
			out.append(c)
	return out

# --- where, pure ----------------------------------------------------------------

func test_every_library_ship_plans_four_legs_one_per_quadrant():
	for id in SHIPS:
		var grid := _grid(id)
		var legs := LandingLegs.plan(grid)
		assert_eq(legs.size(), 4, "%s plans four legs" % id)
		var mid := _middle(grid)
		var seen := {}
		for leg in legs:
			var at := ShipGrid.cell_center(leg["cell"])
			var foot: Vector3 = leg["foot"]
			var q := Vector2i(signi(roundi((at.x - mid.x) * 100.0)), signi(roundi((at.z - mid.y) * 100.0)))
			assert_ne(q.x, 0, "%s: %s is port or starboard" % [id, leg["cell"]])
			assert_ne(q.y, 0, "%s: %s is fore or aft" % [id, leg["cell"]])
			assert_eq(Vector2i(signi(roundi((foot.x - mid.x) * 100.0)), signi(roundi((foot.z - mid.y) * 100.0))), q,
				"%s: the foot is in its mount's quadrant" % id)
			seen[q] = true
		assert_eq(seen.size(), 4, "%s: one in each quadrant (%s)" % [id, seen.keys()])

func test_every_foot_is_on_the_stance_plane_under_its_mount():
	for id in SHIPS:
		var grid := _grid(id)
		var stance := Ship.stance_depth_of(grid, _catalog())
		for leg in LandingLegs.plan(grid, NAN, _catalog()):
			var cell: Vector3i = leg["cell"]
			var foot: Vector3 = leg["foot"]
			var bottom := ShipGrid.cell_center(cell).y - ShipGrid.CELL_SIZE * 0.5
			assert_almost_eq(foot.y, -stance, EPS, "%s %s: the foot on the stance plane" % [id, cell])
			assert_almost_eq(float(leg["length"]), bottom - foot.y, EPS, "%s %s: mount to stance plane" % [id, cell])
			assert_lte(float(leg["length"]), LandingLegs.MOST_LENGTH, "%s %s: no longer than 4 m" % [id, cell])
			assert_false(grid.has_block(cell + Vector3i.DOWN), "%s %s: its bottom face is open" % [id, cell])
			var flat := Vector2(foot.x, foot.z) - Vector2(ShipGrid.cell_center(cell).x, ShipGrid.cell_center(cell).z)
			assert_lt(flat.length(), ShipGrid.CELL_SIZE * 0.5, "%s %s: the foot is under its mount" % [id, cell])

func test_no_leg_stands_in_or_beside_a_ramp_s_path():
	for id in SHIPS:
		var grid := _grid(id)
		var path := _ramp_cells(grid)
		assert_false(path.is_empty(), "%s has a ramp" % id)
		for leg in LandingLegs.plan(grid):
			for k in _column(leg):
				assert_false(path.has(k), "%s: leg %s hangs through the ramp's path at %s" % [id, leg["cell"], k])
				for n: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					assert_false(path.has(k + n), "%s: leg %s hangs beside the ramp's path at %s" % [id, leg["cell"], k + n])

func test_no_leg_is_under_or_beside_a_downward_thruster_or_an_engine():
	for id in SHIPS:
		var grid := _grid(id)
		var clear := _keep_clear(grid)
		assert_false(clear.is_empty(), "%s has engines" % id)
		for leg in LandingLegs.plan(grid):
			for k in _column(leg):
				for t in clear:
					var d := t - k
					assert_ne(absi(d.x) + absi(d.y) + absi(d.z), 0, "%s: leg %s at %s" % [id, leg["cell"], t])
					assert_ne(absi(d.x) + absi(d.y) + absi(d.z), 1, "%s: leg %s beside %s" % [id, leg["cell"], t])
					assert_false(d.x == 0 and d.z == 0 and d.y > 0, "%s: leg %s under %s" % [id, leg["cell"], t])

func test_the_starter_s_legs_are_mirrored_port_and_starboard():
	var legs := LandingLegs.plan(_grid(&"starter"))
	for leg in legs:
		var foot: Vector3 = leg["foot"]
		var twin := legs.filter(func(l: Dictionary) -> bool: return (l["foot"] as Vector3).distance_to(Vector3(-foot.x, foot.y, foot.z)) < EPS)
		assert_eq(twin.size(), 1, "the starter's leg at %s has a twin across the keel" % foot)

func test_a_one_cell_grid_plans_fewer_than_four_legs():
	var grid := ShipGrid.new()
	var inst := BlockInstance.new()
	inst.block_id = &"hull"
	grid.set_block(Vector3i.ZERO, inst)
	assert_lt(LandingLegs.plan(grid).size(), 4, "one cell")
	assert_eq(LandingLegs.plan(ShipGrid.new()).size(), 0, "no cells")
	assert_almost_eq(Ship.stance_depth_of(grid), Ship.keel_depth_of(grid), EPS, "no legs: it stands on its keel")

# --- the stance, pure: the lowest hanging look clears the sand by 0.1 m ------------
# (the owner, 2026-11-05: legs lengthen, so a hanging part costs ramp length)

func test_the_stance_clears_the_lowest_look_by_0_1_m_and_the_keel_by_0_4_m_at_least():
	assert_almost_eq(LandingLegs.HANG_CLEAR, 0.1, EPS)
	assert_almost_eq(LandingLegs.CLEARANCE, 0.4, EPS)
	assert_almost_eq(LandingLegs.stance_for(3.0, -3.883), 3.983, EPS, "a dome 0.883 m under a 3 m keel")
	assert_almost_eq(LandingLegs.stance_for(3.0, -3.2), 3.4, EPS, "a look 0.2 m under the keel: 0.4 still")
	assert_almost_eq(LandingLegs.stance_for(3.0, -2.4), 3.4, EPS, "nothing under the keel")
	assert_almost_eq(LandingLegs.stance_for(3.0, INF), 3.4, EPS, "no look at all")

func test_every_ship_stands_its_lowest_hanging_look_0_1_m_over_the_ground():
	for id in SHIPS:
		var grid := _grid(id)
		var keel := Ship.keel_depth_of(grid)
		var lowest := ExteriorBuilder.lowest_look(grid, _catalog())
		var stance := Ship.stance_depth_of(grid, _catalog())
		assert_almost_eq(stance, maxf(keel + LandingLegs.CLEARANCE, -lowest + LandingLegs.HANG_CLEAR), EPS, String(id))
		gut.p("%s: lowest look %.3f m under its keel's plane, stance %.3f m under it" % [id, -lowest - keel,
			stance - keel])
	# The starter's and the Warden's belly turrets hang lowest, parked; the
	# Lamplighter has nothing under its keel's plane.
	for id: StringName in [&"starter", &"warden"]:
		var grid := _grid(id)
		assert_gt(Ship.stance_depth_of(grid, _catalog()) - Ship.keel_depth_of(grid), 0.9, "%s: its belly turret" % id)
	var lamp := _grid(&"lamplighter")
	assert_almost_eq(Ship.stance_depth_of(lamp, _catalog()) - Ship.keel_depth_of(lamp), LandingLegs.CLEARANCE, EPS,
		"the Lamplighter: 0.4 m")

func test_the_starter_s_ramp_grows_to_about_6_m():
	var grid := _grid(&"starter")
	var plan := AirlockAlcove.ramp_plan(grid, Vector3i(0, 0, 3))
	var sill := 2.05 + Ship.stance_depth_of(grid, _catalog()) - Ship.keel_depth_of(grid)
	assert_almost_eq(float(plan["sill"]), sill, 0.001, "the sill over the stance plane")
	assert_almost_eq(float(plan["length"]), LandingRamp.length_for(sill), 0.01)
	assert_between(float(plan["length"]), 5.8, 6.3, "about 6 m")
	assert_eq(plan["through"], [], "nothing in its way")
	gut.p("the starter's ramp: %s" % AirlockAlcove.ramp_words(plan))

func test_the_warden_s_ramp_grows_to_about_10_m():
	var grid := _grid(&"warden")
	for c: Vector3i in grid.coords():
		if grid.get_block(c).block_id == AirlockSite.AIRLOCK_ID:
			var plan := AirlockAlcove.ramp_plan(grid, c)
			var sill := 4.05 + Ship.stance_depth_of(grid, _catalog()) - Ship.keel_depth_of(grid)
			assert_almost_eq(float(plan["sill"]), sill, 0.001)
			assert_between(float(plan["length"]), 9.6, 10.4, "about 10 m")
			assert_eq(AirlockAlcove.way_up_for(plan), LandingRamp.RAMP, "boardable: %s" % AirlockAlcove.ramp_words(plan))
			gut.p("the Warden's ramp: %s" % AirlockAlcove.ramp_words(plan))

## Review I1: a grid lying wholly above y = 0 has its keel's plane over the
## origin, so its stance is negative; "not given" was a negative stance, and
## the plan and the ramp asked each other for one for ever.
func test_a_grid_wholly_above_y_0_with_an_airlock_plans_legs_and_a_ramp_without_recursion():
	var grid := _grid(&"starter")
	var high := ShipGrid.new()
	for c: Vector3i in grid.coords():
		high.set_block(c + Vector3i(0, 3, 0), grid.get_block(c))
	assert_almost_eq(Ship.keel_depth_of(high), -3.0, EPS, "its keel's plane 3 m over the origin")
	var low_legs := LandingLegs.plan(grid, NAN, _catalog())
	var legs := LandingLegs.plan(high, NAN, _catalog())
	assert_eq(legs.size(), 4, "four legs")
	for i in mini(legs.size(), low_legs.size()):
		assert_almost_eq(legs[i]["foot"] as Vector3, (low_legs[i]["foot"] as Vector3) + Vector3(0.0, 6.0, 0.0),
			Vector3.ONE * EPS, "leg %d: where the starter's is, 6 m up" % i)
	var plan := AirlockAlcove.ramp_plan(high, Vector3i(0, 3, 3))
	assert_eq(plan["need"], LandingRamp.RAMP)
	assert_almost_eq(float(plan["sill"]), float(AirlockAlcove.ramp_plan(grid, Vector3i(0, 0, 3))["sill"]), 0.001,
		"the starter's sill")

# --- when, pure ---------------------------------------------------------------------

func test_they_come_down_under_40_m_and_go_up_over_60_m():
	assert_true(LandingLegs.wanted(false, true, false, 39.0), "under 40: down")
	assert_false(LandingLegs.wanted(false, true, false, 41.0), "up, between: stay up")
	assert_true(LandingLegs.wanted(true, true, false, 59.0), "down, between: stay down")
	assert_false(LandingLegs.wanted(true, true, false, 61.0), "over 60: up")
	assert_almost_eq(LandingLegs.DOWN_BELOW, 40.0, EPS)
	assert_almost_eq(LandingLegs.UP_ABOVE, 60.0, EPS)

func test_landed_they_stay_down_and_off_a_world_they_are_up():
	assert_true(LandingLegs.wanted(false, true, true, 500.0), "landed: down, whatever the altitude reads")
	assert_true(LandingLegs.wanted(false, false, true, INF), "landed before its gravity is wired: down")
	assert_false(LandingLegs.wanted(true, false, false, 5.0), "out of a well: up")
	assert_false(LandingLegs.wanted(true, false, false, INF))

# --- the shape, pure ------------------------------------------------------------------

## Chunky gear (the owner, 2026-11-05: 0.38 m struts, a 0.8 m foot) folds a
## little deeper than the brief's 0.35 m.
func test_stowed_a_leg_folds_flat_within_0_5_m_of_its_cell():
	for length: float in [2.4, 3.0, LandingLegs.MOST_LENGTH]:
		var stowed := LandingLegs.pose(length, 0.0)
		assert_gte(float(stowed["lowest"]), -0.5, "a %.1f m leg stowed reaches %.3f m under its cell" % [length, stowed["lowest"]])

func test_the_gear_is_chunky():
	assert_gte(LandingLegs.STRUT, 0.35, "struts about 0.4 m")
	assert_gte(LandingLegs.ARM_HEIGHT, 0.35)
	assert_gte(LandingLegs.PAD.x, 0.75, "a foot about 0.8 m")
	assert_gte(LandingLegs.PAD.z, 0.75)
	assert_gt(LandingLegs.KNEE_RADIUS, LandingLegs.ARM_HEIGHT * 0.5, "the knuckle stands proud of the arms")

func test_down_its_foot_is_on_the_stance_plane_where_the_plan_says():
	for length: float in [2.4, 3.0, LandingLegs.MOST_LENGTH]:
		var down := LandingLegs.pose(length, LandingLegs.TRAVEL)
		assert_almost_eq(float(down["lowest"]), -length, EPS, "a %.1f m leg's foot" % length)
		assert_almost_eq((down["foot"] as Vector3).y, -length, EPS)
		assert_almost_eq(down["foot"], LandingLegs.foot_local(length), Vector3.ONE * EPS)
	for leg in LandingLegs.plan(_grid(&"starter"), NAN, _catalog()):
		var frame := LandingLegs.frame(leg["cell"], leg["end"])
		assert_almost_eq(frame * LandingLegs.foot_local(leg["length"]), leg["foot"] as Vector3, Vector3.ONE * EPS)

func test_it_takes_a_second_and_a_half_folding_out_then_straightening():
	assert_almost_eq(LandingLegs.TRAVEL, 1.5, EPS)
	var mid := LandingLegs.pose(2.4, LandingLegs.FOLD_TIME)
	assert_almost_eq(float(mid["upper"]), LandingLegs.SPLAY, EPS, "folded out about the hinge")
	assert_almost_eq(float(mid["lower"]), LandingLegs.SPLAY + PI, EPS, "the knee still bent")
	var down := LandingLegs.pose(2.4, LandingLegs.TRAVEL)
	assert_almost_eq(float(down["lower"]), PI * 0.5, EPS, "then straight down at the knee")

# --- in the flight scene, the starter on real ground ------------------------------

var _root: Node
var _ship: Ship
var _universe: Universe
var _up := Vector3.UP
var _centre := Vector3.ZERO
var _ground := 0.0
var _basis := Basis.IDENTITY

func _scene() -> void:
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	await wait_physics_frames(3)
	_root.reload = func() -> void: pass

func _legs() -> LandingLegs:
	return _ship.exterior_builder.legs()

## Hops to the biggest planet and finds the flattest ground near where it puts
## the starter (test_landing_ramp's way to a world).
func _find_flat() -> void:
	var system: SystemRecipe = _root.system
	var planet: SystemBody = system.planets()[0]
	for p in system.planets():
		if p.radius > planet.radius:
			planet = p
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface, "3 km off: its ground is drawn")
	_centre = _universe.to_engine(planet.point)
	var out := (_ship.exterior.global_position - _centre).normalized()
	var best := out
	var flattest := INF
	var tries: Array[Vector3] = [out]
	for k in 12:
		tries.append((out + Vector3(cos(k * 0.52), 0.0, sin(k * 0.52)) * 0.02 * (1 + k % 3)).normalized())
	for dir in tries:
		var spread := 0.0
		var h0: float = surface.terrain.height_at(dir)
		for k in 8:
			var o := Vector3(cos(k * 0.785), 0.0, sin(k * 0.785)) * (40.0 / planet.radius)
			spread = maxf(spread, absf(surface.terrain.height_at((dir + o).normalized()) - h0))
		if spread < flattest:
			flattest = spread
			best = dir
	_up = best
	_ground = planet.radius + surface.terrain.height_at(_up)
	var along := _up.cross(Vector3.UP).normalized()
	_basis = Basis(along, _up, along.cross(_up).normalized())

## The starter upright, still, its stance plane `height` m over the flat ground,
## the assist on.
func _place(height: float) -> void:
	_ship.exterior.global_transform = Transform3D(_basis, _centre + _up * (_ground + _ship.stance_depth() + height))
	_ship.exterior.linear_velocity = Vector3.ZERO
	_ship.exterior.angular_velocity = Vector3.ZERO
	_ship.flight_computer.assist_enabled = true

func _push(y: float) -> void:
	_ship.flight_computer.set_pilot_input(Vector3(0.0, y, 0.0), Vector3.ZERO, false)

## Set down gently from 3 m on its legs, as a pilot does: true once LANDED.
func _land() -> bool:
	await _find_flat()
	_place(3.0)
	await wait_physics_frames(30)
	assert_true(await wait_until(func() -> bool: return _legs().is_down(), 2.0), "legs down before touchdown")
	_push(-0.1)
	var frames := 0
	while _ship.landing.state == LandingMonitor.State.FLYING and frames < 600:
		await wait_physics_frames(1)
		frames += 1
	_push(0.0)
	frames = 0
	while not _ship.landing.is_landed() and frames < 60 * 4:
		await wait_physics_frames(1)
		frames += 1
	return _ship.landing.is_landed()

## How far `p` is over the ground straight under it, or INF with none found.
func _over_ground(p: Vector3) -> float:
	var space := _ship.exterior.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + _up * 2.0, p - _up * 4.0, BodyProxy.LAYER))
	return INF if hit.is_empty() else (p - (hit["position"] as Vector3)).dot(_up)

func _all_off() -> bool:
	return _legs().colliders.all(func(c: CollisionShape3D) -> bool: return c.disabled)

func _all_on() -> bool:
	return _legs().colliders.all(func(c: CollisionShape3D) -> bool: return not c.disabled)

## The corners of a box or the points of a convex shape, in its own frame.
static func _points(shape: Shape3D) -> PackedVector3Array:
	if shape is ConvexPolygonShape3D:
		return (shape as ConvexPolygonShape3D).points
	var out := PackedVector3Array()
	if shape is BoxShape3D:
		var h := (shape as BoxShape3D).size * 0.5
		for i in 8:
			out.append(Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	return out

func test_built_with_four_stowed_legs_their_colliders_off():
	await _scene()
	var legs := _legs()
	assert_not_null(legs, "the starter has legs")
	assert_eq(legs.legs.size(), 4)
	assert_eq(legs.colliders.size(), 12, "three boxes a leg")
	assert_true(legs.is_stowed())
	assert_true(_all_off(), "off while stowed")
	for c in legs.colliders:
		assert_eq(c.get_parent(), _ship.exterior, "on the hull's own body")
		assert_true(c.has_meta(&"cell"), "a hit on a leg lands on its mount")
	assert_true(legs.is_in_group(Universe.EXTERIOR_SPACE) or _ship.exterior.is_ancestor_of(legs),
		"under the hull body, which the floating origin moves")

func test_descending_under_40_m_they_come_down_with_their_colliders_on():
	await _scene()
	await _find_flat()
	_place(50.0)
	await wait_physics_frames(20)
	assert_between(_ship.flight_computer.keel_altitude(), 40.0, 60.0, "between the two heights")
	assert_true(_legs().is_stowed(), "at 50 m, coming down from above: still up")
	_place(35.0)
	await wait_physics_frames(2)
	assert_eq(_legs().state, LandingLegs.State.DEPLOYING, "under 40 m: folding out")
	assert_true(_all_off(), "no collider until they are fully down")
	assert_true(await wait_until(func() -> bool: return _legs().is_down(), 2.0), "down within 2 s")
	assert_true(_all_on(), "colliders on once down")

## Every look of the starter's outside you can see but its legs, its ramps
## (which rest on the ground) and its lights' rig (a lamp's bounds are its
## reach, a beam is light): its skin, its turrets, its alcoves.
func _looks() -> Array[GeometryInstance3D]:
	var skip: Array[Node] = [_legs()]
	for airlock: Airlock in _ship.airlocks.values():
		if airlock.alcove != null and airlock.alcove.ramp != null:
			skip.append(airlock.alcove.ramp)
	var rig := _ship.exterior.get_node_or_null("Lights")
	if rig != null:
		skip.append(rig)
	var out: Array[GeometryInstance3D] = []
	for node in _ship.exterior.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi is GPUParticles3D or gi is CPUParticles3D:
			continue
		if skip.any(func(s: Node) -> bool: return s == gi or s.is_ancestor_of(gi)):
			continue
		out.append(gi)
	return out

## The corners of `gi`'s bounds, in the world.
static func _corners(gi: GeometryInstance3D) -> Array[Vector3]:
	var box := gi.get_aabb()
	var out: Array[Vector3] = []
	for i in 8:
		out.append(gi.global_transform * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)))
	return out

## The owner's rule (2026-11-05), and review M1: what the eye sees, not the
## colliders -- the lowest point of every look but the legs and the ramp is at
## least 0.05 m over the ground (the stance gives it 0.1).
func test_landed_every_look_but_its_legs_and_ramp_stands_clear_of_the_ground():
	await _scene()
	assert_true(await _land(), "landed")
	var lowest := INF
	var what := ""
	for gi in _looks():
		for p in _corners(gi):
			var gap := _over_ground(p)
			if gap < lowest:
				lowest = gap
				what = str(_ship.exterior.get_path_to(gi))
	assert_gte(lowest, 0.05, "the lowest look, %s, is %.3f m over the ground" % [what, lowest])
	gut.p("landed: the lowest look, %s, %.3f m over the ground" % [what, lowest])

## The stance is worked out from a look drawn off the tree
## (ExteriorBuilder.lowest_look); the ship's own rebuild measures what it drew.
## Both are what the built starter shows.
func test_the_lowest_look_worked_out_is_the_one_the_built_starter_shows():
	await _scene()
	var hull := _ship.exterior.global_transform.affine_inverse()
	var built := INF
	for gi in _looks():
		for p in _corners(gi):
			built = minf(built, (hull * p).y)
	assert_almost_eq(ExteriorBuilder.lowest_look(_ship.grid, _ship.catalog), built, 0.005, "worked out")
	assert_almost_eq(_ship.stance_depth(), LandingLegs.stance_for(_ship.keel_depth(), built), 0.005, "stood on")

func test_landed_on_its_legs_its_colliders_stand_clear_and_it_is_level():
	await _scene()
	assert_true(await _land(), "landed")
	var legs := _legs()
	assert_true(legs.is_down())
	for foot in legs.feet():
		assert_lt(absf(_over_ground(foot)), 0.06, "a foot on the ground (%.3f m)" % _over_ground(foot))
	var skip: Array = legs.colliders.duplicate()
	for airlock: Airlock in _ship.airlocks.values():
		if airlock.alcove != null and airlock.alcove.ramp != null:
			skip.append(airlock.alcove.ramp.collider)
	var lowest := INF
	var cell := Vector3i.ZERO
	for node in _ship.exterior.get_children():
		var c := node as CollisionShape3D
		if c == null or c.disabled or skip.has(c):
			continue
		for p in _points(c.shape):
			var gap := _over_ground(_ship.exterior.global_transform * c.transform * p)
			if gap < lowest:
				lowest = gap
				cell = c.get_meta(&"cell", Vector3i(99, 99, 99))
	assert_gte(lowest, 0.3, "the hull's lowest collider point, in %s, is %.2f m over the ground" % [cell, lowest])
	assert_eq(cell.y, -1, "and it is on the keel strip (the belly turret's row)")
	assert_lt(_ship.landing.tilt(), deg_to_rad(1.0), "level on flat ground: %.2f deg" % rad_to_deg(_ship.landing.tilt()))
	gut.p("landed: lowest collider %.3f m over the ground in %s; tilt %.2f deg" % [lowest, cell,
		rad_to_deg(_ship.landing.tilt())])

func test_climbing_over_60_m_folds_them_up_and_their_colliders_off():
	await _scene()
	await _find_flat()
	_place(30.0)
	assert_true(await wait_until(func() -> bool: return _legs().is_down(), 2.5), "down at 30 m")
	_place(55.0)
	await wait_physics_frames(10)
	assert_true(_legs().is_down(), "between the two heights: still down")
	_place(65.0)
	await wait_physics_frames(2)
	assert_eq(_legs().state, LandingLegs.State.STOWING, "over 60 m: folding up")
	assert_true(_all_off(), "colliders off the moment they start up")
	assert_true(await wait_until(func() -> bool: return _legs().is_stowed(), 2.0), "up within 2 s")

## A hostile flown by its pilot never puts them down (it stays 2000 m up
## anyway)...
func test_a_hostile_its_pilot_flies_never_puts_them_down():
	await _scene()
	await _find_flat()
	_ship.side = Sides.HOSTILE
	_ship.ship_pilot.set_physics_process(false)
	_ship.ship_pilot.on = true
	_place(10.0)
	await wait_physics_frames(100)
	assert_true(_legs().is_stowed(), "a hostile's pilot flies low with its legs up")
	_ship.ship_pilot.on = false
	_ship.side = Sides.CREW

## ...but review M4: a hostile hull with nobody hostile at its stick -- boarded
## and flown to a world by you (every ship is usable) -- stands on them.
func test_a_hostile_hull_its_pilot_does_not_fly_puts_them_down():
	await _scene()
	await _find_flat()
	_ship.side = Sides.HOSTILE
	assert_false(_ship.ship_pilot.on)
	_place(10.0)
	assert_true(await wait_until(func() -> bool: return _legs().is_down(), 3.0), "down near the ground")
	_ship.side = Sides.CREW

## Review M3: a save puts the hull back after set_grid builds it, and the scene
## wires its gravity after that, so the legs cannot know where they are when
## they are built. A ship loaded hovering 20 m up has them down on its first
## frame, at once: never folding out in front of you.
func test_a_ship_loaded_hovering_under_40_m_has_its_legs_down_on_the_first_frame():
	await _scene()
	await _find_flat()
	var place := Transform3D(_basis, _centre + _up * (_ground + _ship.stance_depth() + 20.0))
	var other: Ship = _root.fleet.spawn(_root._starter_grid(), place)
	var legs := other.exterior_builder.legs()
	assert_true(legs.is_stowed(), "built stowed")
	var states: Array = []
	for i in 4:
		await wait_physics_frames(1)
		states.append(LandingLegs.State.keys()[legs.state])
	# The first tick it runs -- the wait may hand back before or after it.
	assert_eq(states[1], "DOWN", "down on its first frame: %s" % [states])
	assert_false(states.has("DEPLOYING"), "never folding out: %s" % [states])
	assert_almost_eq(legs.progress(), 1.0, EPS)
	assert_true(legs.colliders.all(func(c: CollisionShape3D) -> bool: return not c.disabled), "colliders on")

## Untested before: a ship asleep on the ground (a save loads one built with
## its legs stowed) wakes standing on them, colliders on, never folding out.
func test_a_ship_woken_landed_has_its_legs_down_with_their_colliders_on():
	await _scene()
	assert_true(await _land(), "landed")
	_root.fleet.sleep(_ship)
	_legs().set_down(false, true)
	assert_true(_legs().is_stowed(), "stowed while asleep, as a loaded one is built")
	_root.fleet.wake(_ship)
	await wait_physics_frames(1)
	assert_true(_legs().is_down(), "down on waking")
	assert_almost_eq(_legs().progress(), 1.0, EPS, "at once")
	assert_true(_all_on(), "colliders on")

## Review M5: a mount lost to damage takes its leg on the rebuild; the other
## three stand, the ship stands as tall, and nothing of the lost leg is left.
func test_a_lost_mount_takes_its_leg_and_the_other_three_stand():
	await _scene()
	var before := _legs()
	var lost: Vector3i = before.legs[0]["cell"]
	var stance := _ship.stance_depth()
	var shapes := _ship.exterior.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D)
	var its_own := shapes.filter(func(n: Node) -> bool:
		return n.get_meta(&"cell", Vector3i(99, 99, 99)) == lost and not before.colliders.has(n))
	_ship.grid.clear_block(lost)
	await wait_physics_frames(1)
	var legs := _legs()
	assert_eq(legs.legs.size(), 3, "three legs")
	assert_false(legs.legs.any(func(l: Dictionary) -> bool: return l["cell"] == lost), "none on the lost cell")
	assert_eq(legs.colliders.size(), 9, "three boxes each")
	assert_false(is_instance_valid(before), "the old legs are freed")
	var after := _ship.exterior.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D)
	assert_eq(after.size(), shapes.size() - its_own.size() - 3, "the lost cell's and its leg's colliders gone, no other")
	assert_eq(_ship.exterior_builder.get_children().filter(func(n: Node) -> bool: return n is LandingLegs).size(), 1,
		"one LandingLegs")
	assert_almost_eq(_ship.stance_depth(), stance, EPS, "it stands as tall")

func test_a_save_loaded_landed_has_its_legs_down_on_the_first_frame():
	await _scene()
	assert_true(await _land(), "landed")
	var saved := _ship.to_dict(_universe)
	assert_true(bool(saved["hull"]["landed"]))
	var place := Transform3D(_ship.exterior.global_basis, _ship.exterior.global_position + _up * 300.0)
	var other: Ship = _root.fleet.spawn(_root._starter_grid(), place)
	var legs := other.exterior_builder.legs()
	assert_true(legs.is_stowed(), "flying 300 m up: up")
	_root.fleet.restore_hull(other, saved)
	assert_true(other.landing.is_landed())
	assert_true(legs.is_down(), "down with no frame run")
	assert_eq(legs.progress(), 1.0, "no animation")
	assert_true(legs.colliders.all(func(c: CollisionShape3D) -> bool: return not c.disabled), "colliders on")

## The floating origin (CLAUDE.md): a shift while landed moves the legs with the
## hull and the ground with the world, so every foot stays on the ground.
func test_a_shift_while_landed_keeps_every_foot_on_the_ground():
	await _scene()
	assert_true(await _land(), "landed")
	var before: Array[float] = []
	for foot in _legs().feet():
		before.append(_over_ground(foot))
	_universe.shift(Vector3(2000.0, 0.0, 0.0))
	await wait_physics_frames(3)
	var feet := _legs().feet()
	gut.p("feet over the ground before the shift: %s" % [before])
	for i in feet.size():
		var after := _over_ground(feet[i])
		assert_lt(absf(after), 0.05, "foot %d on the ground after the shift (%.3f m; %.3f before)" % [i, after, before[i]])
		assert_lt(absf(after - before[i]), 0.05, "foot %d where it was" % i)
