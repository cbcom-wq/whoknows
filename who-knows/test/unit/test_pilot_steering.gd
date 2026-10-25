extends GutTest

## How a pilot flies a fight (hostile ships spec §5.2): which face to show so
## most turrets bear, the stick that turns it there, what rock to steer round,
## and which bolts are coming its way.

class FakeBolt extends RefCounted:
	var global_position := Vector3.ZERO
	var direction := Vector3.FORWARD
	var carrier := Vector3.ZERO
	var speed := 600.0
	var source: Node = null

var _world: Node3D

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)

## The starter's turrets' sky maps, ventral first, then dorsal.
func _starter_skies() -> Array:
	var grid := ShipLibrary.read("res://data/ships/starter.json")["grid"] as ShipGrid
	var by_y := {}
	for coord: Vector3i in grid.coords():
		var inst := grid.get_block(coord)
		if WeaponValues.is_turret(inst.block_id):
			by_y[coord.y] = SkyMap.build(grid, coord, SkyMap.normal_of(inst.orientation))
	assert_eq(by_y.size(), 2, "the starter carries a dorsal and a ventral turret")
	var ys := by_y.keys()
	ys.sort()
	return [by_y[ys[0]], by_y[ys[1]]]

## A dorsal turret down a walled pit: it bears only high overhead.
func _pit_sky() -> SkyMap:
	var g := ShipGrid.new()
	for x in range(-3, 4):
		for z in range(-3, 4):
			_put(g, Vector3i(x, 0, z))
			if absi(x) == 3 or absi(z) == 3:
				for y in range(1, 5):
					_put(g, Vector3i(x, y, z))
	return SkyMap.build(g, Vector3i.ZERO, Vector3i.UP)

func _put(g: ShipGrid, at: Vector3i) -> void:
	var inst := BlockInstance.new()
	inst.block_id = &"hull"
	g.set_block(at, inst)

func test_the_samples_are_a_cubes_faces_edges_and_corners():
	assert_eq(Broadside.SAMPLES.size(), 26)
	for s: Vector3 in Broadside.SAMPLES:
		assert_almost_eq(s.length(), 1.0, 0.0001)
	assert_true(Broadside.SAMPLES.has(Vector3.FORWARD))
	assert_true(Broadside.SAMPLES.has(Vector3.UP))

func test_best_face_on_a_starter_is_one_both_turrets_bear_on():
	# The starter's domes meet only at the horizon: both bear on the eight
	# level samples, and the tie goes to the nose.
	var skies := _starter_skies()
	var face := Broadside.best_face(skies, [true, true])
	assert_lt(absf(face.y), 0.5, "level, where both domes see")
	assert_true(skies[0].can_bear(face), "the ventral bears")
	assert_true(skies[1].can_bear(face), "the dorsal bears")
	assert_eq(face, Vector3.FORWARD, "ties go to the nose")

func test_no_turrets_shows_the_nose():
	assert_eq(Broadside.best_face([], []), Vector3.FORWARD)

func test_a_wrecked_turret_does_not_count():
	var ventral: SkyMap = _starter_skies()[0]
	var pit := _pit_sky()
	assert_true(pit.can_bear(Vector3.UP) and not pit.can_bear(Vector3.FORWARD), "the pit sees only up")
	var skies := [ventral, pit, pit]
	var live_face := Broadside.best_face(skies, [true, true, true])
	assert_true(pit.can_bear(live_face), "two live pit turrets outvote one ventral")
	var face := Broadside.best_face(skies, [true, false, false])
	assert_true(ventral.can_bear(face), "the ventral bears")
	assert_false(pit.can_bear(face), "a face only the ventral bears on")

func test_desired_basis_aims_the_face():
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 20:
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var current := Basis(axis, rng.randf_range(-PI, PI))
		var desired := Broadside.desired_basis(current, Vector3.UP, Vector3.RIGHT)
		assert_gt((desired * Vector3.UP).dot(Vector3.RIGHT), 0.999, "the face along the target")
		assert_almost_eq(desired.determinant(), 1.0, 0.0001, "still a rotation")

func test_desired_basis_turns_the_face_about_even_when_it_points_away():
	var desired := Broadside.desired_basis(Basis.IDENTITY, Vector3.UP, Vector3.DOWN)
	assert_gt((desired * Vector3.UP).dot(Vector3.DOWN), 0.999)

func test_rotate_input_turns_toward_and_settles():
	# A toy hull: the stick asks a rate, the hull reaches it with a 0.25 s lag.
	var desired := Basis.IDENTITY
	var current := Basis(Vector3.UP, deg_to_rad(120.0))
	var spin := Vector3.ZERO
	var dt := 1.0 / 120.0
	var worst_over := 0.0
	for i in int(10.0 / dt):
		var input := Broadside.rotate_input(current, desired, spin, 2.0)
		for k in 3:
			assert_between(input[k], -1.0, 1.0)
		spin += (input * FlightComputer.ASSIST_TURN_RATE - spin) * (dt / 0.25)
		if spin.length() > 1e-9:
			current = (current * Basis(spin.normalized(), spin.length() * dt)).orthonormalized()
		# Signed error about the turn's axis: below zero is past the target.
		var err := (current.inverse() * desired).get_rotation_quaternion()
		var signed := err.get_angle() * signf(err.get_axis().dot(Vector3.DOWN)) if err.get_angle() > 1e-6 else 0.0
		worst_over = maxf(worst_over, -rad_to_deg(signed))
	var left := rad_to_deg((current.inverse() * desired).get_rotation_quaternion().get_angle())
	assert_lt(left, 2.0, "settled within 2 degrees")
	assert_lt(worst_over, 10.0, "never more than 10 degrees past")

func _rock(at: Vector3, r := 50.0) -> StaticBody3D:
	var rock := StaticBody3D.new()
	rock.collision_layer = AsteroidBody.LAYER
	rock.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = r
	shape.shape = sphere
	rock.add_child(shape)
	_world.add_child(rock)
	rock.global_position = at
	return rock

func test_rock_avoid_steers_round_a_rock():
	_rock(Vector3(0, 0, -400))
	await wait_physics_frames(2)
	var v := Vector3(0, 0, -60)
	var space := _world.get_world_3d().direct_space_state
	var away := RockAvoid.steer(space, Vector3.ZERO, v, 10.0, [])
	assert_gt(away.length(), 0.0, "a rock dead ahead is steered round")
	assert_lt(absf(away.normalized().dot(v.normalized())), 0.3, "across the path, not just a brake")

func test_a_rock_past_clearance_is_left_alone():
	# Its nearest face is 40 m beyond the hull's radius plus CLEARANCE.
	_rock(Vector3(10.0 + RockAvoid.CLEARANCE + 50.0 + 40.0, 0, -400))
	await wait_physics_frames(2)
	var space := _world.get_world_3d().direct_space_state
	assert_eq(RockAvoid.steer(space, Vector3.ZERO, Vector3(0, 0, -60), 10.0, []), Vector3.ZERO)

func test_a_nearer_rock_steers_harder():
	var space := _world.get_world_3d().direct_space_state
	var rock := _rock(Vector3(30, 0, -400))
	await wait_physics_frames(2)
	var far := RockAvoid.steer(space, Vector3.ZERO, Vector3(0, 0, -60), 10.0, []).length()
	rock.global_position = Vector3(30, 0, -150)
	await wait_physics_frames(2)
	var near := RockAvoid.steer(space, Vector3.ZERO, Vector3(0, 0, -60), 10.0, []).length()
	assert_gt(far, 0.0)
	assert_gt(near, far)

func test_rock_avoid_ignores_what_it_excludes():
	var rock := _rock(Vector3(0, 0, -400))
	await wait_physics_frames(2)
	var space := _world.get_world_3d().direct_space_state
	var ex: Array[RID] = [rock.get_rid()]
	assert_eq(RockAvoid.steer(space, Vector3.ZERO, Vector3(0, 0, -60), 10.0, ex), Vector3.ZERO)

func test_inbound_counts_only_bolts_that_pass_close():
	var own := Node.new()
	add_child_autofree(own)
	var aimed := FakeBolt.new()
	aimed.global_position = Vector3(0, 0, -1000)
	aimed.direction = Vector3.BACK
	var wide := FakeBolt.new()
	wide.global_position = Vector3(200, 0, -1000)
	wide.direction = Vector3.BACK
	var ours := FakeBolt.new()
	ours.global_position = Vector3(0, 0, -1000)
	ours.direction = Vector3.BACK
	ours.source = own
	var late := FakeBolt.new()
	late.global_position = Vector3(0, 0, -3000)
	late.direction = Vector3.BACK
	var bolts := [aimed, wide, ours, late]
	assert_eq(Broadside.inbound(bolts, own, Vector3.ZERO, Vector3.ZERO, 25.0, 3.0), 1)

func test_inbound_is_relative_motion():
	# A bolt carried along with you, aimed level past you, never closes.
	var bolt := FakeBolt.new()
	bolt.global_position = Vector3(0, 0, -100)
	bolt.direction = Vector3.RIGHT
	bolt.speed = 0.0
	bolt.carrier = Vector3(0, 0, 50)
	assert_eq(Broadside.inbound([bolt], null, Vector3.ZERO, Vector3(0, 0, 50), 25.0, 3.0), 0, "it keeps its distance")
	assert_eq(Broadside.inbound([bolt], null, Vector3.ZERO, Vector3.ZERO, 25.0, 3.0), 1, "standing still, it reaches you")

func test_the_pool_lists_only_bolts_in_flight():
	var pool := BoltPool.new()
	_world.add_child(pool)
	var slab := StaticBody3D.new()
	slab.collision_layer = 1
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 1)
	var shape := CollisionShape3D.new()
	shape.shape = box
	slab.add_child(shape)
	_world.add_child(slab)
	slab.global_position = Vector3(0, 0, -20)
	await wait_physics_frames(2)
	var short := pool.fire(WeaponValues.LIGHT, Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, null, [])
	var long := pool.fire(WeaponValues.LIGHT, Vector3.ZERO, Vector3.BACK, Vector3.ZERO, null, [])
	assert_eq(pool.flying().size(), 2)
	await wait_physics_frames(4)
	assert_true(short.is_spent(), "landed on the slab")
	assert_eq(pool.flying(), [long] as Array[PhaserBolt], "a landed bolt fading is not in flight")
