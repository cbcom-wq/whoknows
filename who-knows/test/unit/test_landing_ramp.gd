extends GutTest

## The landing ramp (desert world phase 0, Task 14; the owner's decision,
## 2026-11-04): a chunky boarding ramp comes down under a high outer hatch
## when the ship lands on a world and folds away when it lifts off, so every
## ship can be walked back into (CLAUDE.md: every ship is usable).

const EPS := 0.0001
const STARTER_SILL := 2.05

# --- the geometry, pure --------------------------------------------------------

func test_a_2_05_m_sill_takes_a_4_1_m_ramp():
	assert_almost_eq(LandingRamp.length_for(STARTER_SILL), 4.1, 0.01)

func test_on_flat_ground_it_rests_at_30_degrees():
	var length := LandingRamp.length_for(STARTER_SILL)
	assert_almost_eq(LandingRamp.angle_for(STARTER_SILL, length, 0.0), deg_to_rad(30.0), EPS)

func test_ground_higher_at_the_tip_makes_it_shallower_down_to_15_degrees():
	var length := LandingRamp.length_for(STARTER_SILL)
	var a := LandingRamp.angle_for(STARTER_SILL, length, -0.5)
	assert_almost_eq(a, asin((STARTER_SILL - 0.5) / length), EPS, "the tip on ground 0.5 m higher")
	assert_lt(a, deg_to_rad(30.0))
	assert_gt(a, deg_to_rad(15.0))
	assert_almost_eq(LandingRamp.angle_for(STARTER_SILL, length, -1.8), deg_to_rad(15.0), EPS, "clamped at 15")
	assert_almost_eq(LandingRamp.angle_for(STARTER_SILL, length, -5.0), deg_to_rad(15.0), EPS,
		"ground over the sill: still 15")

func test_ground_lower_makes_it_steeper_up_to_38_degrees():
	var length := LandingRamp.length_for(STARTER_SILL)
	var a := LandingRamp.angle_for(STARTER_SILL, length, 0.3)
	assert_almost_eq(a, asin((STARTER_SILL + 0.3) / length), EPS, "the tip on ground 0.3 m lower")
	assert_gt(a, deg_to_rad(30.0))
	assert_lt(a, deg_to_rad(38.0))
	assert_almost_eq(LandingRamp.angle_for(STARTER_SILL, length, 1.0), deg_to_rad(38.0), EPS, "clamped at 38")
	assert_almost_eq(LandingRamp.angle_for(STARTER_SILL, length, 10.0), deg_to_rad(38.0), EPS,
		"ground far below: still 38")

func test_a_hatch_within_a_step_of_the_keel_gets_no_ramp():
	assert_eq(LandingRamp.need(Vector3(0, 0, 1), Airlock.HATCH_STEP), LandingRamp.STEP, "at the step")
	assert_eq(LandingRamp.need(Vector3(1, 0, 0), 0.05), LandingRamp.STEP, "a base's hatch, 5 cm up")
	assert_eq(LandingRamp.need(Vector3(-1, 0, 0), 0.3), LandingRamp.STEP)
	assert_eq(LandingRamp.need(Vector3(0, 0, -1), Airlock.HATCH_STEP + 0.01), LandingRamp.RAMP, "just over it")
	assert_eq(LandingRamp.need(Vector3(0, 0, 1), STARTER_SILL), LandingRamp.RAMP)

func test_a_hatch_facing_up_or_down_gets_no_ramp():
	assert_eq(LandingRamp.need(Vector3.UP, STARTER_SILL), LandingRamp.UP_OR_DOWN)
	assert_eq(LandingRamp.need(Vector3.DOWN, STARTER_SILL), LandingRamp.UP_OR_DOWN)

## Final review I4 (Ruling 15): the one home of the ramp condition. A step is a
## step; a ramp with nothing in its way is a ramp; a ramp through the hull, or
## a hatch in a floor or a ceiling, is no way up at all.
func _plan(need: StringName, through: Array[Vector3i] = []) -> Dictionary:
	return {"need": need, "sill": 4.05, "length": 0.0, "angle": LandingRamp.SLOPE, "through": through}

func test_the_way_up_to_a_hatch():
	assert_eq(AirlockAlcove.way_up_for(_plan(LandingRamp.STEP)), LandingRamp.STEP)
	assert_eq(AirlockAlcove.way_up_for(_plan(LandingRamp.RAMP)), LandingRamp.RAMP)
	var blocked: Array[Vector3i] = [Vector3i(-4, -1, 2)]
	assert_eq(AirlockAlcove.way_up_for(_plan(LandingRamp.RAMP, blocked)), AirlockAlcove.NONE, "through the hull")
	assert_eq(AirlockAlcove.way_up_for(_plan(LandingRamp.UP_OR_DOWN)), AirlockAlcove.NONE, "a hatch in a floor")

## Every library ship, built: the alcove keeps its plan and way up, and builds a
## ramp exactly for RAMP. The Warden's came down through its own hull until its
## forward retros moved (4f27cde): a ramp now, as every library ship has.
func test_every_library_ship_s_alcove_knows_its_way_up():
	var catalog := BlockCatalog.load_from_dir("res://data/blocks")
	var expected := {&"starter": LandingRamp.RAMP, &"lamplighter": LandingRamp.RAMP, &"warden": LandingRamp.RAMP}
	for id: StringName in expected:
		var grid: ShipGrid = ShipLibrary.read("res://data/ships/%s.json" % id)["grid"]
		for c: Vector3i in grid.coords():
			if grid.get_block(c).block_id != AirlockSite.AIRLOCK_ID:
				continue
			var parent := Node3D.new()
			var body := StaticBody3D.new()
			add_child_autofree(parent)
			add_child_autofree(body)
			var alcove := AirlockAlcove.build(parent, body, grid, catalog, c)
			assert_eq(alcove.way_up, expected[id], "%s's airlock %s" % [id, c])
			assert_eq(alcove.way_up, AirlockAlcove.way_up_for(AirlockAlcove.ramp_plan(grid, c)))
			assert_eq(alcove.ramp != null, alcove.way_up == LandingRamp.RAMP, "%s builds a ramp only for RAMP" % id)

func test_the_steepest_rest_stays_walkable_with_margin():
	var avatar: Avatar = load("res://scenes/avatar.tscn").instantiate()
	var floor_max := avatar.floor_max_angle
	avatar.free()
	assert_lt(LandingRamp.MOST, floor_max - deg_to_rad(5.0),
		"38 deg is at least 5 deg under the avatar's floor_max_angle (%.1f deg)" % rad_to_deg(floor_max))
	assert_lt(LandingRamp.SLOPE, LandingRamp.MOST)
	assert_gt(LandingRamp.SLOPE, LandingRamp.LEAST)

## Final review M4: after an instant deploy (a save loaded landed) it looks for
## the ground every physics tick for its first second, so ground whose
## collider comes a tick later settles it then -- not half a second on, when it
## could nudge you, saved standing on it.
func test_after_an_instant_deploy_it_finds_ground_that_comes_a_tick_later():
	var parent := Node3D.new()
	add_child_autofree(parent)
	var body := StaticBody3D.new()
	add_child_autofree(body)
	var ramp := LandingRamp.build(parent, body, Transform3D.IDENTITY, STARTER_SILL)
	ramp.set_down(true, true)
	assert_true(ramp.is_down(), "down at once")
	assert_almost_eq(ramp.angle, LandingRamp.SLOPE, EPS, "no ground yet: the design slope")
	var ground := StaticBody3D.new()
	ground.collision_layer = BodyProxy.LAYER
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	var shape := CollisionShape3D.new()
	shape.shape = box
	ground.add_child(shape)
	add_child_autofree(ground)
	ground.global_position = Vector3(0, -(STARTER_SILL + 0.3) - 0.5, 0)
	await wait_physics_frames(3)
	assert_almost_eq(ramp.angle, asin((STARTER_SILL + 0.3) / ramp.length), 0.01,
		"settled on ground 0.3 m under the keel's plane within 3 ticks")

func test_its_shape_is_the_brief_s():
	assert_almost_eq(LandingRamp.WIDTH, InteriorProps.DOOR_WIDTH + 0.3, EPS)
	assert_almost_eq(LandingRamp.THICKNESS, 0.18, EPS)
	assert_almost_eq(LandingRamp.RAIL_HEIGHT, 0.12, EPS)
	assert_almost_eq(LandingRamp.SLIDE_TIME + LandingRamp.SWING_TIME, 1.6, 0.05)

# --- which hatches, from a grid ---------------------------------------------------

func _block(grid: ShipGrid, at: Vector3i, id: StringName) -> void:
	var inst := BlockInstance.new()
	inst.block_id = id
	grid.set_block(at, inst)

## An airlock opening aft (+z) off a deck, walled either side, with a keel row
## of `keel` hull blocks under it.
func _lock_over_a_keel(keel: int) -> ShipGrid:
	var grid := ShipGrid.new()
	_block(grid, Vector3i(0, 0, 0), &"airlock")
	_block(grid, Vector3i(0, 0, -1), &"deck")
	_block(grid, Vector3i(1, 0, 0), &"hull")
	_block(grid, Vector3i(-1, 0, 0), &"hull")
	for k in keel:
		_block(grid, Vector3i(0, -1 - k, -1), &"hull")
	return grid

## Over its keel the starter's sill is 2.05 m up; its landing legs (Task 15)
## stand it higher, until its belly turret's dome clears the sand by 0.1 m
## (the owner, 2026-11-05), so its ramp is about 6 m long.
func test_the_starter_s_hatch_gets_a_ramp_about_6_m_long():
	var grid: ShipGrid = ShipLibrary.read("res://data/ships/starter.json")["grid"]
	var over_keel := AirlockAlcove.ramp_plan(grid, Vector3i(0, 0, 3), Ship.keel_depth_of(grid))
	assert_almost_eq(over_keel["sill"], STARTER_SILL, 0.001, "storey 0 over a keel row: 2.05 m")
	var plan := AirlockAlcove.ramp_plan(grid, Vector3i(0, 0, 3))
	assert_eq(plan["need"], LandingRamp.RAMP)
	var stood := Ship.stance_depth_of(grid) - Ship.keel_depth_of(grid)
	assert_gt(stood, LandingLegs.CLEARANCE + 0.5, "its belly turret stands it well over 0.4 m")
	assert_almost_eq(plan["sill"], STARTER_SILL + stood, 0.001, "over the legs' stance")
	assert_almost_eq(plan["length"], LandingRamp.length_for(STARTER_SILL + stood), 0.01)
	assert_between(float(plan["length"]), 5.8, 6.3, "about 6 m")
	assert_almost_eq(plan["angle"], deg_to_rad(30.0), EPS)
	assert_eq(plan["through"], [], "nothing in its way")

func test_a_hatch_level_with_the_keel_is_a_step():
	var plan := AirlockAlcove.ramp_plan(_lock_over_a_keel(0), Vector3i.ZERO)
	assert_eq(plan["need"], LandingRamp.STEP)
	assert_almost_eq(plan["sill"], 0.05, 0.001)

## Measured over the keel's plane, a keel row puts the hatch 2.05 m up; this
## little grid has room for landing legs on its storey-0 cells (Task 15), and on
## them it stands at least 0.4 m higher still.
func test_a_keel_row_under_the_ship_makes_the_hatch_need_one():
	var grid := _lock_over_a_keel(1)
	var plan := AirlockAlcove.ramp_plan(grid, Vector3i.ZERO, Ship.keel_depth_of(grid))
	assert_eq(plan["need"], LandingRamp.RAMP)
	assert_almost_eq(plan["sill"], 2.05, 0.001)
	assert_false(LandingLegs.plan(grid).is_empty())
	var stood := Ship.stance_depth_of(grid) - Ship.keel_depth_of(grid)
	assert_gte(stood, LandingLegs.CLEARANCE - 0.001)
	assert_almost_eq(AirlockAlcove.ramp_plan(grid, Vector3i.ZERO)["sill"], 2.05 + stood, 0.001)

func test_a_block_in_the_ramp_s_way_is_named():
	var grid := _lock_over_a_keel(1)
	_block(grid, Vector3i(0, -1, 1), &"hull")   # under the cell outside the hatch
	var plan := AirlockAlcove.ramp_plan(grid, Vector3i.ZERO)
	assert_eq(plan["need"], LandingRamp.RAMP)
	assert_eq(plan["through"], [Vector3i(0, -1, 1)])

func test_the_block_under_the_airlock_itself_is_not_in_the_way():
	var grid := _lock_over_a_keel(1)
	_block(grid, Vector3i(0, -1, 0), &"hull")
	assert_eq(AirlockAlcove.ramp_plan(grid, Vector3i.ZERO)["through"], [])

# --- in the flight scene, the starter on real ground ------------------------------

const LOCK := Vector3i(0, 0, 3)

var _root: Node
var _ship: Ship
var _universe: Universe
var _up := Vector3.UP

func _scene() -> void:
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	await wait_physics_frames(3)
	_root.reload = func() -> void: pass

func _lock() -> Airlock:
	return _ship.airlocks.get(LOCK)

func _ramp() -> LandingRamp:
	return _lock().alcove.ramp

## The starter upright `clearance` m over the flattest ground near where the
## hop puts it by the biggest planet, at rest, the assist on
## (test_system_scene's way to a world).
func _over_flat_ground(clearance: float) -> void:
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
	var centre := _universe.to_engine(planet.point)
	var out := (_ship.exterior.global_position - centre).normalized()
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
	var ground := planet.radius + surface.terrain.height_at(_up)
	var along := _up.cross(Vector3.UP).normalized()
	var basis := Basis(along, _up, along.cross(_up).normalized())
	_ship.exterior.global_transform = Transform3D(basis, centre + _up * (ground + _ship.stance_depth() + clearance))
	_ship.exterior.linear_velocity = Vector3.ZERO
	_ship.exterior.angular_velocity = Vector3.ZERO
	_ship.flight_computer.assist_enabled = true
	await wait_physics_frames(30)
	# Under 40 m its landing legs fold out (Task 15): it sets down on them.
	var legs := _ship.exterior_builder.legs()
	assert_true(await wait_until(func() -> bool: return legs.is_down(), 2.0), "its legs are down")

func _push(y: float) -> void:
	_ship.flight_computer.set_pilot_input(Vector3(0.0, y, 0.0), Vector3.ZERO, false)

## Set down gently from 3 m, as a pilot does: true once LANDED.
func _land() -> bool:
	await _over_flat_ground(3.0)
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

## The middle of the outer hatch's sill, in the world.
func _sill() -> Vector3:
	return _lock().alcove.outer_hatch.global_position

## The top of the ramp's collider at the hinge, in the world.
func _collider_top() -> Vector3:
	var ramp := _ramp()
	return _ship.exterior.global_transform * ramp.collider.transform \
		* Vector3(0.0, LandingRamp.THICKNESS * 0.5, -ramp.length * 0.5)

func test_landed_on_real_ground_the_ramp_comes_down():
	await _scene()
	var ramp := _ramp()
	assert_not_null(ramp, "the starter's hatch is 2.05 m up: it has a ramp")
	assert_true(ramp.is_stowed() and not ramp.visible and ramp.collider.disabled, "stowed and hidden while it flies")
	assert_true(await _land(), "landed")
	await wait_seconds(2.0)
	assert_true(ramp.is_down(), "down about 2 s after LANDED (state %d)" % ramp.state)
	assert_true(ramp.visible)
	assert_false(ramp.collider.disabled, "its collider is on")
	assert_eq(ramp.collider.get_parent(), _ship.exterior, "on the hull's own body")
	assert_lt(ramp.top_edge().distance_to(_sill()), 0.05, "its top edge at the sill")
	assert_lt(_collider_top().distance_to(_sill()), 0.05, "and its collider's")
	assert_between(ramp.angle, LandingRamp.LEAST, LandingRamp.MOST)
	var space := _ship.exterior.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ramp.tip() + _up * 1.0, ramp.tip() - _up * 1.0,
		BodyProxy.LAYER))
	assert_false(hit.is_empty(), "ground under the tip")
	if not hit.is_empty():
		assert_lt(absf((ramp.tip() - (hit["position"] as Vector3)).dot(_up)), 0.1,
			"the tip rests on the ground (at %.1f deg)" % rad_to_deg(ramp.angle))
	assert_false(_lock()._hatch_blocked(), "the ramp is the hull's: the hatch-clear cast leaves it out")

func test_lifting_off_stows_it_at_once_and_hides_it():
	await _scene()
	assert_true(await _land(), "landed")
	var ramp := _ramp()
	assert_true(await wait_until(func() -> bool: return ramp.is_down(), 3.0), "down")
	_push(1.0)
	var frames := 0
	while _ship.landing.is_landed() and frames < 120:
		await wait_physics_frames(1)
		frames += 1
	assert_false(_ship.landing.is_landed(), "lifted off")
	assert_true(ramp.collider.disabled, "its collider off the tick it lifts")
	assert_eq(ramp.state, LandingRamp.State.STOWING, "stowing at once")
	assert_true(await wait_until(func() -> bool: return not ramp.visible, 2.0), "hidden within 2 s")
	assert_true(ramp.is_stowed())
	_push(0.0)

func test_from_the_ramp_s_foot_you_walk_up_and_in():
	await _scene()
	assert_true(await _land(), "landed")
	var ramp := _ramp()
	assert_true(await wait_until(func() -> bool: return ramp.is_down(), 3.0), "down")
	var lock := _lock()
	var avatar: Avatar = get_tree().get_first_node_in_group(Avatar.GROUP)
	var out := (_ship.exterior.global_basis * Vector3(lock.alcove.hatch_normal)).normalized()
	var inward := (-out - _up * (-out).dot(_up)).normalized()
	var foot := ramp.tip() - inward * 0.5 + _up * 0.2
	avatar.enter_field(_ship.outside, Transform3D(Basis.looking_at(inward, _up), foot), Vector3.ZERO, _ship.exterior)
	assert_eq(avatar.mode, Avatar.Mode.FIELD)
	assert_true(await wait_until(func() -> bool: return avatar.is_on_floor(), 2.0), "standing at the ramp's foot")
	lock.alcove.hull_panel.interact(avatar)
	var start := avatar.global_position
	var climbed := [0.0]   # a lambda's captured local would not keep what it sets
	Input.action_press(&"move_forward")
	var aboard: bool = await wait_until(func() -> bool:
		if avatar.mode == Avatar.Mode.FIELD:
			climbed[0] = maxf(climbed[0], (avatar.global_position - start).dot(_up))
		return avatar.mode == Avatar.Mode.PLATING and avatar.get_parent() == _ship.interior, 12.0)
	Input.action_release(&"move_forward")
	assert_true(aboard, "up the ramp and in through the outer hatch within 12 s (mode %s, outer %.2f)" % [
		Avatar.Mode.keys()[avatar.mode], lock.cycle.outer_open])
	assert_almost_eq(ramp.length, LandingRamp.length_for(ramp.sill_height), 0.01, "the ramp over the legs")
	assert_between(ramp.length, 5.8, 6.3, "about 6 m")
	assert_gt(climbed[0], ramp.length * sin(LandingRamp.LEAST) + 0.5,
		"on your feet up the ramp: %.2f m up from its foot" % climbed[0])

## Out of the hatch with W held, you walk down the ramp on your feet -- not
## sail off the sill and land at its foot (found by landing_play: at 4 m/s
## under 5.3 m/s² the arc out of the doorway stays over a 30° ramp all the
## way down).
func test_out_of_the_hatch_you_walk_down_the_ramp_on_your_feet():
	await _scene()
	assert_true(await _land(), "landed")
	var ramp := _ramp()
	assert_true(await wait_until(func() -> bool: return ramp.is_down(), 3.0), "down")
	var lock := _lock()
	var avatar: Avatar = get_tree().get_first_node_in_group(Avatar.GROUP)
	avatar.place(_ship.interior.global_transform * Transform3D(lock.room.outer_frame.basis, lock.room.room_frame.origin))
	avatar.set_head_pitch(0.0)
	await wait_physics_frames(3)
	lock.room.room_panel.interact(avatar)
	assert_true(await wait_until(func() -> bool: return lock.cycle.outer_open >= 1.0, 15.0), "the outer hatch opens")
	# Ticks over the ramp, ticks of them off your feet, and the most your feet
	# were ever off its top.
	var on := [0, 0, 0.0]
	var watch := func() -> void:
		if avatar.mode != Avatar.Mode.FIELD:
			return
		var p := ramp.global_transform.affine_inverse() * avatar.global_position
		if p.z > 0.3 and p.z < ramp.length * cos(ramp.angle) - 0.3 and absf(p.x) < LandingRamp.WIDTH * 0.5:
			on[0] += 1
			if not avatar.is_on_floor():
				on[1] += 1
			on[2] = maxf(on[2], absf(p.y + p.z * tan(ramp.angle)))
	get_tree().physics_frame.connect(watch)
	Input.action_press(&"move_forward")
	await wait_until(func() -> bool: return avatar.mode == Avatar.Mode.FIELD \
		and (ramp.global_transform.affine_inverse() * avatar.global_position).z > ramp.length + 1.0, 8.0)
	Input.action_release(&"move_forward")
	get_tree().physics_frame.disconnect(watch)
	assert_eq(avatar.mode, Avatar.Mode.FIELD, "out on foot")
	assert_gt(on[0], 10, "over the ramp for %d ticks" % on[0])
	assert_lte(on[1], 3, "off your feet %d of them" % on[1])
	assert_lt(on[2], 0.25, "your feet at most %.2f m off its top" % on[2])

## A save of `_ship` landed where it stands now on the ground, and a second
## starter to load it into, 300 m up and flying.
func _saved_landed() -> Array:
	await _over_flat_ground(0.02)
	_ship.landing.restore_landed()
	var saved := _ship.to_dict(_universe)
	assert_true(bool(saved["hull"]["landed"]))
	var place := Transform3D(_ship.exterior.global_basis, _ship.exterior.global_position + _up * 300.0)
	var other: Ship = _root.fleet.spawn(_root._starter_grid(), place)
	return [saved, other]

func _ramp_of(ship: Ship) -> LandingRamp:
	return (ship.airlocks.get(LOCK) as Airlock).alcove.ramp

func test_a_save_loaded_landed_has_its_ramp_down_on_the_first_frame():
	await _scene()
	var made := await _saved_landed()
	var other: Ship = made[1]
	assert_true(_ramp_of(other).is_stowed(), "flying: stowed")
	_root.fleet.restore_hull(other, made[0])
	var ramp := _ramp_of(other)
	assert_true(other.landing.is_landed())
	assert_true(ramp.is_down(), "down with no frame run")
	assert_eq(ramp.progress(), 1.0, "no animation")
	assert_true(ramp.visible)
	assert_false(ramp.collider.disabled)

func test_loaded_before_its_gravity_the_ramp_is_down_the_first_tick_it_has_it():
	await _scene()
	var made := await _saved_landed()
	var other: Ship = made[1]
	# The flight scene restores the fleet before it wires each ship's gravity.
	other.flight_computer.gravity = null
	_root.fleet.restore_hull(other, made[0])
	var ramp := _ramp_of(other)
	assert_true(ramp.is_stowed(), "off a world, as far as it knows: stowed")
	other.flight_computer.gravity = _root.world_gravity
	await wait_physics_frames(1)
	assert_true(ramp.is_down(), "down")
	assert_eq(ramp.progress(), 1.0, "with no animation")

func test_a_rebuild_while_landed_keeps_the_ramp_down():
	await _scene()
	await _over_flat_ground(0.02)
	_ship.landing.restore_landed()
	# It may have set down by itself over the flat ground, its ramp still
	# swinging (WADIS's planned land): restored, it finishes on the next tick.
	await wait_physics_frames(1)
	var before := _ramp()
	assert_true(before.is_down())
	_ship._rebuild_everything()
	var after := _ramp()
	assert_ne(after, before, "a new alcove, a new ramp")
	assert_true(after.is_down(), "down at once")
	assert_false(after.collider.disabled)
	var ramp_shapes := _ship.exterior.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D and n.name.begins_with("LandingRamp"))
	assert_eq(ramp_shapes.size(), 1, "one ramp collider, the stale one freed")
