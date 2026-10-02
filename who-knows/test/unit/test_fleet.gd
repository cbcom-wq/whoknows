extends GutTest

## The fleet (docs/superpowers/specs/2026-10-02-many-ships-design.md §5):
## every ship in the world, in the real flight scene, with a second starter
## spawned beside the first.

const OFF := Vector3(300, 0, 0)

var _root: Node
var _fleet: Fleet
var _starter: Ship
var _director: CameraDirector

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_fleet = _root.fleet
	_starter = _root.get_node("Ship")
	_director = _root.get_node("CameraDirector")

func _spawn(off := OFF) -> Ship:
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + off)
	return _fleet.spawn(_root._starter_grid(), place)

func test_the_starter_is_the_first_ship():
	assert_eq(_fleet.ships().size(), 1)
	assert_same(_fleet.ships()[0], _starter)
	assert_eq(_starter.interior_slot, 0)
	assert_same(_root.aboard, _starter)

func test_a_spawned_ship_is_whole_and_where_it_was_put():
	var ship := _spawn()
	assert_not_null(ship)
	assert_eq(String(ship.name), "Ship2")
	assert_eq(ship.interior_slot, 1)
	assert_eq(ship.grid.coords().size(), _starter.grid.coords().size(), "built from the grid")
	assert_almost_eq(ship.exterior.global_position, _starter.exterior.global_position + OFF, Vector3.ONE * 0.01)
	assert_eq(ship.exterior.linear_velocity, Vector3.ZERO, "at rest")
	assert_ne(ship.interior.global_position, _starter.interior.global_position, "an interior of its own")
	assert_eq(ship.outside, _root.get_node("Outside"))
	assert_false(ship.own, "not yours until you board it")
	assert_true(ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))

func test_a_spawned_ship_is_wired_like_the_starter():
	var ship := _spawn()
	assert_same(ship.seat.director, _director)
	assert_same(ship.pilot.director, _director)
	assert_same(ship.pilot.lights, ship.lights)
	assert_not_null(ship.flight_computer.whereabouts, "its speed limit knows where it is")
	assert_not_null(ship.warp.system, "its warp is bound")
	assert_eq(ship.chase_camera.far, BodyProxy.VIEW_FAR)
	assert_true(_root.npc_debug.directors.has(ship.npc_director), "its crew shows on F4")
	assert_same(ship.npc_director.ledger, _root.npc_ledger)

func test_its_seat_is_where_its_chair_is():
	var ship := _spawn()
	assert_eq(ship.seat.transform, InteriorDressing.fixture_frame(ship.interior_builder.layout(), ship.helm_cell()))

func test_names_never_repeat_and_slots_are_reused():
	var a := _spawn()
	var b := _spawn(Vector3(-300, 0, 0))
	assert_eq([String(a.name), String(b.name)], ["Ship2", "Ship3"])
	assert_eq([a.interior_slot, b.interior_slot], [1, 2])
	assert_true(_fleet.remove(a))
	await wait_process_frames(1)
	var c := _spawn(Vector3(0, 300, 0))
	assert_eq(String(c.name), "Ship4", "a name is never used twice")
	assert_eq(c.interior_slot, 1, "a slot is")

func test_the_starter_and_the_ship_aboard_stay():
	assert_false(_fleet.remove(_starter), "the starter stays")
	var ship := _spawn()
	_root.aboard = ship
	assert_false(_fleet.remove(ship), "the ship you are aboard stays")
	_root.aboard = _starter

func test_no_more_than_the_cap():
	_fleet.max_ships = 2
	assert_not_null(_spawn())
	assert_null(_spawn(Vector3(-300, 0, 0)), "past the cap, none")
	assert_engine_error("the most there can be", "and it says why")
	assert_eq(Fleet.MAX_SHIPS, 16)

func test_nearest():
	var a := _spawn()
	var b := _spawn(Vector3(0, 0, 900))
	assert_same(_fleet.nearest(_starter.exterior.global_position, _starter), a)
	assert_same(_fleet.nearest(b.exterior.global_position, b), _starter)

## Review focus: a shift moves every hull, and no interior.
func test_a_shift_moves_both_hulls_and_neither_interior():
	var ship := _spawn()
	var gap := ship.exterior.global_position - _starter.exterior.global_position
	var interiors := [_starter.interior.global_position, ship.interior.global_position]
	_starter.exterior.global_position += Vector3(2500, 0, 0)
	ship.exterior.global_position += Vector3(2500, 0, 0)
	assert_true((_root.get_node("Universe") as Universe).check())
	assert_almost_eq(ship.exterior.global_position - _starter.exterior.global_position, gap, Vector3.ONE * 0.001)
	assert_eq([_starter.interior.global_position, ship.interior.global_position], interiors)

## Only the ship whose seat you take answers the stick (§3.2).
func test_sitting_in_the_starter_seats_only_its_controls():
	var ship := _spawn()
	_director.sit(_starter.seat)
	assert_true(_starter.pilot.seated)
	assert_false(ship.pilot.seated, "the other ship's controls ignore you")

## You are shoved only by the ship you stand in.
func test_another_ships_burn_never_shoves_you():
	var ship := _spawn()
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	_starter.motion.set_physics_process(false)
	avatar.external_accel = Vector3.ZERO
	ship.exterior.linear_velocity = Vector3(0, 0, -50)
	await wait_physics_frames(3)
	assert_eq(avatar.external_accel, Vector3.ZERO)

## Review focus: a block lost on another ship leaves you where you are.
func test_a_block_lost_on_another_ship_leaves_you_aboard():
	var ship := _spawn()
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	ship.blocks_lost.emit([Vector3i(0, 0, 0)] as Array[Vector3i])
	assert_eq(avatar.mode, Avatar.Mode.PLATING)
	assert_same(avatar.get_parent(), _starter.interior)

## Moves the starter `by` and lets the origin and the fleet catch up.
func _fly_starter(by: Vector3) -> void:
	_starter.exterior.global_position += by
	(_root.get_node("Universe") as Universe).check()
	_fleet.check_sleep()

func test_a_ship_left_far_behind_sleeps_and_wakes_when_you_come_back():
	var ship := _spawn()
	var universe: Universe = _root.get_node("Universe")
	var was := universe.to_universe(ship.exterior.global_position)
	_fly_starter(Vector3(21000, 0, 0))
	assert_true(_fleet.sleeping(ship), "20.7 km off: asleep")
	assert_true(ship.is_in_group(Fleet.ASLEEP))
	assert_false(ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))
	assert_false(ship.exterior.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_eq(ship.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(ship.visible)
	assert_false(_fleet.awake().has(ship))
	_fly_starter(Vector3(-2000, 0, 0))
	assert_true(_fleet.sleeping(ship), "18.7 km: between the two, it sleeps on")
	_fly_starter(Vector3(-2000, 0, 0))
	assert_false(_fleet.sleeping(ship), "16.7 km: awake")
	assert_true(ship.visible)
	assert_true(ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))
	assert_lt(universe.to_universe(ship.exterior.global_position).minus(was).length(), 0.01, "where it was")

func test_a_sleeping_ship_keeps_its_place_across_shifts():
	var ship := _spawn()
	var universe: Universe = _root.get_node("Universe")
	var was := universe.to_universe(ship.exterior.global_position)
	_fly_starter(Vector3(25000, 0, 0))
	for i in 3:
		_starter.exterior.global_position += Vector3(0, 0, 3000)
		assert_true(universe.check())
	assert_lt(_fleet.place_of(ship).minus(was).length(), 0.001)
	_starter.exterior.global_position = universe.to_engine(was) + Vector3(100, 0, 0)
	_fleet.check_sleep()
	assert_false(_fleet.sleeping(ship))
	assert_lt(universe.to_universe(ship.exterior.global_position).minus(was).length(), 0.01)

func test_the_ship_aboard_never_sleeps():
	var ship := _spawn()
	assert_true(_root.board_nearest())
	ship.exterior.global_position += Vector3(30000, 0, 0)
	(_root.get_node("Universe") as Universe).check()
	_fleet.check_sleep()
	assert_false(_fleet.sleeping(ship), "you are aboard it")
	assert_true(_fleet.sleeping(_starter), "the one you left behind sleeps")

## Review focus: asleep, a ship holds neither the origin's shift nor the save.
func test_a_ship_falling_asleep_stops_its_puffs_and_never_holds_the_save():
	var ship := _spawn()
	var puffs := ship.find_children("*", "GPUParticles3D", true, false)
	assert_gt(puffs.size(), 0, "it has emitters")
	for p in puffs:
		(p as GPUParticles3D).emitting = true
	ship.since_struck = 0.0
	assert_eq(_root._fleet_busy(), "hull struck")
	_fly_starter(Vector3(25000, 0, 0))
	for p in puffs:
		assert_false((p as GPUParticles3D).emitting, "%s stopped" % p.name)
	assert_eq(_root._fleet_busy(), "", "asleep, it never holds the save")

## The stripe is painted from ship-local height through `hull_inverse`: each
## ship's livery must carry its own hull's, or one ship's stripe is measured in
## the other's frame (the final review, I1).
func test_each_ship_paints_its_stripe_from_its_own_hull():
	var ship := _spawn(Vector3(300, 40, 0))
	ship.exterior.global_basis = Basis(Vector3.RIGHT, 0.3)
	await wait_process_frames(2)
	for s: Ship in [_starter, ship]:
		var found := 0
		for node in s.exterior.find_children("*", "GeometryInstance3D", true, false):
			var mat := (node as GeometryInstance3D).material_override as ShaderMaterial
			if mat == null or mat.shader != Ship.HULL_LIVERY_MATERIAL.shader:
				continue
			found += 1
			var inv: Variant = mat.get_shader_parameter(&"hull_inverse")
			var t: Transform3D = Transform3D(inv) if inv is Projection else inv
			assert_true(t.is_equal_approx(s.exterior.global_transform.affine_inverse()),
				"%s's %s carries its own hull" % [s.name, node.name])
		assert_gt(found, 0, "%s has livery pieces" % s.name)

## A ship nobody is in draws no canopy view: one asleep from the start never
## had its portal run to turn it off (the final review, I2).
func test_a_ship_nobody_looks_into_draws_no_canopy_view():
	var far := _spawn(Vector3(0, 0, 25000))
	_fleet.check_sleep()
	assert_true(_fleet.sleeping(far))
	assert_eq((far.get_node("Canopy") as SubViewport).render_target_update_mode, SubViewport.UPDATE_DISABLED)

## Only the ship you are aboard scans (§5.2), a ship spawned after you boarded
## included (the final review, M2).
func test_a_ship_spawned_beside_you_scans_nothing():
	var ship := _spawn()
	assert_eq(ship.sensors.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(_starter.sensors.process_mode, Node.PROCESS_MODE_INHERIT)

## Saving waits on any ship (§6.4).
func test_the_save_waits_on_every_ship():
	var ship := _spawn()
	assert_eq(_root._fleet_busy(), "")
	ship.since_struck = 0.0
	assert_eq(_root._fleet_busy(), "hull struck")
