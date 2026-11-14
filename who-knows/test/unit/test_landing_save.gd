extends GutTest

## A landed ship saves landed and loads frozen on the ground, awake or asleep
## (docs/superpowers/specs/2026-11-03-desert-world-design.md §5.3). Old saves
## without the key load flying.

const LevelGround := preload("res://test/unit/helpers/level_ground.gd")

var _root: Node
var _fleet: Fleet
var _starter: Ship
var _universe: Universe

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_fleet = _root.fleet
	_starter = _root.get_node("Ship")
	_universe = _root.get_node("Universe")

func _spawn(off: Vector3) -> Ship:
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + off)
	return _fleet.spawn(_root._starter_grid(), place)

## A ship landed on a hull tilted 10 degrees, `off` from the starter.
func _landed_ship(off: Vector3) -> Ship:
	var ship := _spawn(Vector3(300, 0, 0))
	ship.exterior.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)),
		_starter.exterior.global_position + off)
	ship.landing.restore_landed()
	return ship

func test_a_landed_hull_is_written_landed():
	var ship := _landed_ship(Vector3(0, 0, 200))
	assert_true(bool(ship.to_dict(_universe)["hull"]["landed"]))
	assert_false(bool(_starter.to_dict(_universe)["hull"]["landed"]), "a flying one is not")

func test_a_landed_ship_loads_landed_and_stays_put_with_no_ground():
	var ship := _landed_ship(Vector3(0, 0, 200))
	var saved := ship.to_dict(_universe)
	var was := ship.exterior.global_transform
	var other := _spawn(Vector3(-300, 0, 0))
	assert_false(other.landing.is_landed())
	_fleet.restore_hull(other, saved)
	await wait_physics_frames(120)
	assert_true(other.landing.is_landed(), "landed")
	assert_true(other.exterior.freeze, "frozen")
	assert_true(other.exterior.global_transform.is_equal_approx(was), "where and as it was")

func test_an_old_save_without_the_key_loads_flying():
	var saved := _starter.to_dict(_universe)
	(saved["hull"] as Dictionary).erase("landed")
	var other := _spawn(Vector3(-300, 0, 0))
	_fleet.restore_hull(other, saved)
	assert_false(other.landing.is_landed())
	assert_false(other.exterior.freeze)

## Ruling 9 (i): saved landed far off, it loads asleep, and wakes landed.
func test_a_landed_ship_loaded_far_off_wakes_landed():
	var ship := _landed_ship(Vector3(0, 0, 25000))
	var saved := ship.to_dict(_universe)
	var at := SaveCodec.to_upoint(saved["hull"]["at"])
	var turn := SaveCodec.to_basis(saved["hull"]["turn"])
	var other := _spawn(Vector3(-300, 0, 0))
	_fleet.restore_hull(other, saved)
	assert_true(_fleet.sleeping(other), "past SLEEP_AT: asleep")
	_fleet.wake(other)
	assert_false(_fleet.sleeping(other))
	assert_true(other.landing.is_landed(), "landed")
	assert_true(other.exterior.freeze, "frozen")
	assert_eq(other.exterior.linear_velocity, Vector3.ZERO)
	assert_eq(other.exterior.angular_velocity, Vector3.ZERO)
	assert_true(other.exterior.global_transform.is_equal_approx(
		Transform3D(turn, _universe.to_engine(at))), "unchanged transform")

## Ruling 9 (ii): put to sleep landed, a capture keeps it.
func test_a_landed_ship_put_to_sleep_is_captured_landed():
	var ship := _landed_ship(Vector3(0, 0, 200))
	_fleet.sleep(ship)
	assert_true(_fleet.sleeping(ship))
	var found := false
	for part: Dictionary in _fleet.capture(_universe):
		if part["name"] == String(ship.name):
			found = true
			assert_true(bool(part["hull"]["landed"]))
	assert_true(found)

func test_a_flying_ship_put_to_sleep_wakes_flying():
	var ship := _spawn(Vector3(0, 0, 200))
	_fleet.sleep(ship)
	_fleet.wake(ship)
	assert_false(ship.landing.is_landed())
	assert_false(ship.exterior.freeze)

# --- Review Focus 4: a save made before phase 2 on a world now a desert ---------

## The world the starter is put on, and its ground's up and height there. Its
## centre is worked out from its universe point at each use, never kept as an
## engine Vector3 (the floating origin, CLAUDE.md).
var _planet: SystemBody
var _up := Vector3.UP
var _ground := 0.0
var _basis := Basis.IDENTITY

## Hops to the system's largest desert (the largest planet if it has none) and
## finds flat ground near where the hop puts the starter (test_landing_legs'
## way to a world).
func _to_a_world() -> void:
	await wait_physics_frames(3)
	_root.reload = func() -> void: pass
	var system: SystemRecipe = _root.system
	var planet: SystemBody = null
	for p in system.planets():
		var better := planet == null or (p.recipe.is_desert() and not planet.recipe.is_desert()) \
			or (p.recipe.is_desert() == planet.recipe.is_desert() and p.radius > planet.radius)
		if better:
			planet = p
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface, "3 km off: its ground is drawn")
	_planet = planet
	var out := (_starter.exterior.global_position - _centre()).normalized()
	var best := out
	var flattest := INF
	for k in 13:
		var dir := out if k == 0 else (out + Vector3(cos(k * 0.52), 0.0, sin(k * 0.52)) * 0.02 * (1 + k % 3)).normalized()
		var spread := 0.0
		var h0: float = surface.terrain.height_at(dir)
		for j in 8:
			var o := Vector3(cos(j * 0.785), 0.0, sin(j * 0.785)) * (40.0 / planet.radius)
			spread = maxf(spread, absf(surface.terrain.height_at((dir + o).normalized()) - h0))
		if spread < flattest:
			flattest = spread
			best = dir
	_up = best
	_ground = planet.radius + surface.terrain.height_at(_up)
	var along := _up.cross(Vector3.UP).normalized()
	_basis = Basis(along, _up, along.cross(_up).normalized())
	gut.p("on %s (%s): spread %.2f m over 40 m" % [planet.id, "a desert" if planet.recipe.is_desert() else "not a desert",
		flattest])

func _centre() -> Vector3:
	return _universe.to_engine(_planet.point)

## The starter's save with its stance plane `height` m over the ground, landed:
## what a save made on the world's old ground reads like on its new one.
func _saved_landed_at(height: float) -> Dictionary:
	_starter.exterior.global_transform = Transform3D(_basis,
		_centre() + _up * (_ground + _starter.stance_depth() + height))
	_starter.exterior.linear_velocity = Vector3.ZERO
	_starter.exterior.angular_velocity = Vector3.ZERO
	var saved := _starter.to_dict(_universe)
	saved["hull"]["landed"] = true
	return saved

## Calls `each` every physics tick, first in the tick, until freed.
class Watcher extends Node:
	var each: Callable
	func _init(p_each: Callable) -> void:
		each = p_each
		process_physics_priority = -1000
	func _physics_process(_delta: float) -> void:
		each.call()

## A Watcher of `each`, in the tree; free it before the test ends.
func _watch(each: Callable) -> Watcher:
	var w := Watcher.new(each)
	add_child(w)
	return w

## Physics frames until `done` holds, up to `seconds`; true if it did.
func _within(seconds: float, done: Callable) -> bool:
	for k in roundi(seconds * 60.0):
		if done.call():
			return true
		await wait_physics_frames(1)
	return done.call()

func test_restored_landed_off_the_ground_falls_and_settles():
	await _to_a_world()
	var whole := _starter.damage.hull_whole()
	# Saved landed 3 m over the ground: it must not hang there frozen.
	_fleet.restore_hull(_starter, _saved_landed_at(3.0))
	assert_true(_starter.landing.is_landed(), "loads landed")
	var left := [false]
	var monitor := _starter.landing
	assert_true(await _within(10.0, func() -> bool:
		if not monitor.is_landed():
			left[0] = true
		return left[0] and monitor.is_landed()), "leaves LANDED and lands again within 10 s")
	assert_true(left[0], "it left LANDED")
	var keel := _starter.flight_computer.keel_altitude()
	gut.p("3 m up: landed again, its stance plane %.2f m over the ground" % keel)
	assert_lt(absf(keel), 0.5, "on the ground (%.2f m)" % keel)
	assert_true(_starter.exterior.freeze, "frozen on the ground")
	# Saved landed with its keel 1 m under the ground (its feet deeper still):
	# it ends above it.
	_fleet.restore_hull(_starter, _saved_landed_at(-1.0 - (_starter.stance_depth() - _starter.keel_depth())))
	await _within(10.0, func() -> bool: return monitor.is_landed() and _starter.flight_computer.keel_altitude() > -0.5)
	keel = _starter.flight_computer.keel_altitude()
	gut.p("keel 1 m under: its stance plane ends %.2f m over the ground" % keel)
	assert_gt(keel, -WorldSurface.FLOOR_SLACK, "above the ground, not buried in it")
	assert_lt(keel, 1.0, "and on it, not thrown off it")
	assert_true(monitor.is_landed(), "landed")
	assert_eq(_starter.damage.hull_whole(), whole, "not damaged")

## Between RESTORE_SLACK and RESTORE_FALL over what is under it, it falls from
## where it is: not moved first.
func test_restored_landed_a_metre_up_falls_from_where_it_is():
	await _to_a_world()
	_fleet.restore_hull(_starter, _saved_landed_at(1.2))
	var monitor := _starter.landing
	var at := _universe.to_universe(_starter.exterior.global_position)
	var first_drop := [INF]
	assert_true(await _within(10.0, func() -> bool:
		if not monitor.is_landed() and first_drop[0] == INF:
			first_drop[0] = at.minus(_universe.to_universe(_starter.exterior.global_position)).dot(_up)
		return first_drop[0] != INF and monitor.is_landed()), "leaves LANDED and lands again within 10 s")
	gut.p("1.2 m up: %.3f m lower on the tick it was let go" % first_drop[0])
	assert_lt(first_drop[0], 0.3, "let fall from where it was, not moved down first")
	var keel := _starter.flight_computer.keel_altitude()
	assert_lt(absf(keel), 0.5, "on the ground (%.2f m)" % keel)

## A ship landed where it stands -- on the ground, or with its feet on a tall
## boulder far over the analytic ground -- loads frozen where it was, restored,
## and is never moved or let go.
func test_restored_landed_where_it_stands_stays_put():
	await _to_a_world()
	var monitor := _starter.landing
	_fleet.restore_hull(_starter, _saved_landed_at(0.0))
	var at := _universe.to_universe(_starter.exterior.global_position)
	var stayed := [true]
	await _within(2.0, func() -> bool:
		stayed[0] = stayed[0] and monitor.is_landed()
		return false)
	assert_true(stayed[0], "on the ground: landed throughout")
	assert_true(monitor.restored, "restored: the ramp and legs never animate")
	assert_lt(at.minus(_universe.to_universe(_starter.exterior.global_position)).length(), 0.01, "not moved")
	# A boulder 4 m tall under its feet (a box on the terrain layer, its top
	# 2 cm under the stance plane): RESTORE_FALL and more over the ground.
	var rock := StaticBody3D.new()
	rock.collision_layer = BodyProxy.LAYER
	rock.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 3.96, 30.0)
	shape.shape = box
	rock.add_child(shape)
	rock.add_to_group(Universe.EXTERIOR_SPACE)
	add_child_autofree(rock)
	rock.global_transform = Transform3D(_basis, _centre() + _up * (_ground + 1.98))
	_fleet.restore_hull(_starter, _saved_landed_at(4.0))
	at = _universe.to_universe(_starter.exterior.global_position)
	stayed[0] = true
	await _within(2.0, func() -> bool:
		stayed[0] = stayed[0] and monitor.is_landed()
		return false)
	assert_true(stayed[0], "on a boulder: landed throughout")
	assert_true(_starter.exterior.freeze, "frozen")
	assert_true(monitor.restored, "restored")
	assert_lt(at.minus(_universe.to_universe(_starter.exterior.global_position)).length(), 0.01,
		"not moved into the boulder")

## Final review I5: a ship restored landed hovering a metre up -- over
## RESTORE_SLACK, under RESTORE_FALL -- has its ramp down at once, its tip
## just over the ground (a cast ignores what a shape starts inside, so a tip
## sunk in the ground was never the trouble). The check measures the hull's own colliders, never
## the ramp's: it is let fall from where it is and lands, not left frozen in
## the air on its ramp's tip.
func test_restored_landed_hovering_on_its_ramp_s_tip_is_set_down():
	await _to_a_world()
	var surface: WorldSurface = (_root.star_system.proxy(_planet.id) as BodyProxy).surface()
	_up = LevelGround.near(surface.terrain, _up)
	assert_lt(LevelGround.tilt(surface.terrain, _up), LevelGround.LEVEL, "level ground")
	_ground = _planet.radius + surface.terrain.height_at(_up)
	var along := _up.cross(Vector3.UP).normalized()
	_basis = Basis(along, _up, along.cross(_up).normalized())
	var monitor := _starter.landing
	var ramps: Array[LandingRamp] = []
	for lock: Airlock in _starter.airlocks.values():
		if is_instance_valid(lock.alcove) and lock.alcove.ramp != null:
			ramps.append(lock.alcove.ramp)
	assert_false(ramps.is_empty(), "the starter has a ramp")
	# Once there first, so the ground is solid when it loads, its ramps
	# stowed as a loaded hull's are built: they find the ground at once, as on
	# a save loaded where you are.
	_fleet.restore_hull(_starter, _saved_landed_at(0.0))
	await wait_physics_frames(30)
	for r in ramps:
		r.stow(true)
	# Watched every physics tick: the check comes a tick or two after the load.
	var ramp_down := [false]
	var watch := func() -> void:
		if monitor.is_landed() and ramps[0].is_down() and ramps[0].angle > LandingRamp.SLOPE:
			ramp_down[0] = true
	var watcher := _watch(watch)
	_fleet.restore_hull(_starter, _saved_landed_at(1.0))
	var left := [false]
	assert_true(await _within(10.0, func() -> bool:
		if not monitor.is_landed():
			left[0] = true
		return left[0] and monitor.is_landed()), "leaves LANDED and lands again within 10 s")
	watcher.free()
	assert_true(ramp_down[0], "its ramp was down while it waited, its tip on the ground")
	var keel := _starter.flight_computer.keel_altitude()
	gut.p("1 m up on its ramp: landed again, its stance plane %.2f m over the ground" % keel)
	assert_lt(absf(keel), 0.5, "on the ground (%.2f m)" % keel)

## Final review I3, on a world: a ship woken landed 1.5 km from you is checked
## once every chunk under its footprint is solid and not before, through the
## world's real surface (not after RESTORE_WAIT for want of it), and stays
## landed and unmoved on level ground.
func test_a_ship_woken_landed_off_is_checked_once_its_footprint_is_solid():
	await _to_a_world()
	var surface: WorldSurface = (_root.star_system.proxy(_planet.id) as BodyProxy).surface()
	var east := _up.cross(Vector3.UP).normalized()
	var there := LevelGround.near(surface.terrain, (_up + east * (1500.0 / _planet.radius)).normalized())
	assert_lt(LevelGround.tilt(surface.terrain, there), LevelGround.LEVEL, "level ground 1.5 km off")
	var along := there.cross(Vector3.UP).normalized()
	var ship := _spawn(Vector3(300, 0, 0))
	ship.exterior.global_transform = Transform3D(Basis(along, there, along.cross(there).normalized()),
		_centre() + there * (_planet.radius + surface.terrain.height_at(there) + ship.stance_depth()))
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.landing.restore_landed()
	_fleet.sleep(ship)
	_fleet.wake(ship)
	assert_true(ship.landing.is_landed(), "woken landed")
	var at := _universe.to_universe(ship.exterior.global_position)
	var radius := float(ship.exterior.get_meta(AsteroidStream.ANCHOR_RADIUS))
	# Watched every physics tick, before the tick's own work: [ticks, solid
	# at, checked at].
	var seen := [0, -1, -1]
	var watch := func() -> void:
		if seen[2] < 0 and not ship.landing._check_restore:
			seen[2] = seen[0]
		if seen[1] < 0 and surface.solid_round(_universe.to_universe(ship.exterior.global_position), radius):
			seen[1] = seen[0]
		seen[0] += 1
	var watcher := _watch(watch)
	await wait_physics_frames(LandingMonitor.RESTORE_WAIT)
	watcher.free()
	var solid_at: int = seen[1]
	var checked_at: int = seen[2]
	gut.p("woken 1.5 km off: footprint solid by tick %d, checked by tick %d" % [solid_at, checked_at])
	assert_gte(solid_at, 0, "its footprint was made solid")
	assert_gte(checked_at, 0, "and it was checked")
	assert_lt(checked_at, LandingMonitor.RESTORE_WAIT / 2, "well before the timeout")
	assert_lt(solid_at, checked_at, "after its footprint was solid, not before")
	assert_true(ship.landing.is_landed(), "landed")
	assert_lt(at.minus(_universe.to_universe(ship.exterior.global_position)).length(), 0.01, "not moved")
