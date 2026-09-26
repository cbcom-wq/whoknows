extends GutTest

## How a crash feels (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §7.5, §7.6), in the real scene: capped aboard, with a jolt and a thump; two
## bodies in space on a spacewalk.

const DT := 1.0 / 60.0

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _mc: MotionCoupling

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_mc = _root.get_node("Ship/MotionCoupling")

func test_a_crash_shoves_you_no_harder_than_the_cap():
	_ship.exterior.linear_velocity = Vector3.ZERO
	_mc._physics_process(DT)
	_ship.exterior.linear_velocity = Vector3(0, 0, -20)
	_mc._physics_process(DT)
	assert_lte(_avatar.external_accel.length(), MotionCoupling.SHOVE_CAP + 0.001)
	assert_gt(_mc.jolt.length(), 0.0, "the rest is a jolt")

func test_ordinary_flying_is_not_capped():
	var shove := Vector3(0, 0, 5.7)
	assert_eq(MotionCoupling.felt(shove), shove)

func test_the_jolt_dies_away():
	_ship.exterior.linear_velocity = Vector3.ZERO
	_mc._physics_process(DT)
	_ship.exterior.linear_velocity = Vector3(0, 0, -20)
	_mc._physics_process(DT)
	for i in 60:
		_mc._physics_process(DT)
	assert_lt(_mc.jolt.length(), 0.001)

func test_a_harder_knock_thumps_louder():
	assert_lt(Ship.thump_db(0.5), Ship.thump_db(3.0))
	assert_lt(Ship.thump_db(3.0), Ship.thump_db(10.0))
	assert_eq(Ship.thump_db(100.0), Ship.thump_db(8.0), "capped")

func test_bumping_a_rock_on_a_spacewalk_shares_momentum():
	var outside: Node3D = _root.get_node("Outside")
	_ship.exterior.global_position = Vector3(0, 0, 500)
	# A charged suit coasts, assist off; a dry one's emergency cell would steer.
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	_avatar.enter_suit(outside, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), Vector3.ZERO, _ship.exterior)
	var rock := AsteroidRock.new()
	rock.cell = Vector3i(7, 7, 7)
	rock.size = Vector3.ONE * 1.2
	rock.mass = AsteroidRecipe.MASS_PER_M3 * 1.2 * 1.2 * 1.2
	var body := AsteroidBody.new()
	body.setup(rock, RockMesh.mesh(0, 0), StandardMaterial3D.new(), RockMesh.hull_points(0, 0))
	outside.add_child(body)
	body.global_position = Vector3(0, 0, -3)
	_avatar.suit_assist = false
	_avatar.velocity = Vector3(0, 0, -3)
	for i in 90:
		await wait_physics_frames(1)
	var p_avatar := Avatar.SUIT_MASS * _avatar.velocity.z
	var p_rock := body.mass * body.linear_velocity.z
	assert_lt(body.linear_velocity.z, -0.05, "the rock drifts away")
	assert_almost_eq(p_avatar + p_rock, Avatar.SUIT_MASS * -3.0, 40.0, "momentum is shared, not made")

func test_touching_a_rock_twice_in_one_step_is_one_bump():
	var outside: Node3D = _root.get_node("Outside")
	var rock := AsteroidRock.new()
	rock.cell = Vector3i(8, 8, 8)
	rock.size = Vector3.ONE * 3.0
	rock.mass = 21000.0
	var body := AsteroidBody.new()
	body.setup(rock, RockMesh.mesh(0, 0), StandardMaterial3D.new(), RockMesh.hull_points(0, 0))
	outside.add_child(body)
	body.global_position = Vector3(0, 0, -600)
	var n := Vector3(0, 0, 1)
	var at := body.global_position + Vector3(0, 0, 1.5)
	# Let the physics server take its mass before anything touches it.
	await wait_physics_frames(1)
	var v := _avatar.bump(Vector3(0, 0, -2), Vector3.ZERO, [[body, n, at], [body, n, at]])
	await wait_physics_frames(1)
	var m := Avatar.SUIT_MASS * rock.mass / (Avatar.SUIT_MASS + rock.mass)
	var j := (1.0 + Avatar.BUMP_BOUNCE) * m * 2.0
	assert_almost_eq(body.linear_velocity.z * rock.mass, -j, j * 0.02, "one impulse, not two")
	assert_almost_eq(v.z, -2.0 + j / Avatar.SUIT_MASS, 0.001, "you bounce off a little")
