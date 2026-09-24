extends GutTest

## The physics bubble (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §7), headless: rocks near an anchor's path become sleeping bodies and go
## back to being pictures when it has passed.

const T := AsteroidRecipe.Tier
const DT := 1.0 / 60.0

var _world: Node3D
var _universe: Universe
var _anchor: RigidBody3D
var _stream: AsteroidStream

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_universe = Universe.new()
	_world.add_child(_universe)
	_anchor = RigidBody3D.new()
	_anchor.gravity_scale = 0.0
	_anchor.collision_layer = 0
	_anchor.collision_mask = 0
	_world.add_child(_anchor)
	_anchor.add_to_group(Universe.EXTERIOR_SPACE)
	_anchor.set_meta(AsteroidStream.ANCHOR_RADIUS, 5.0)
	_universe.set_focus(_anchor)
	_stream = AsteroidStream.new()
	_world.add_child(_stream)
	var start := AsteroidRecipe.new(_stream.seed).find_start()
	_universe.origin = start
	_stream.start(_universe, start)

## A loaded rubble rock, and the anchor put `gap` metres from its surface.
func _beside_a_rock(gap: float) -> AsteroidRock:
	var fc := AsteroidRecipe.cell_of(T.RUBBLE, _universe.to_universe(Vector3.ZERO))
	for x in range(-3, 4):
		for z in range(-3, 4):
			var rocks := _stream.loaded_rocks(T.RUBBLE, fc + Vector3i(x, 0, z))
			if not rocks.is_empty():
				var rock := rocks[0]
				_anchor.global_position = _stream.rock_pose(rock).origin + Vector3(rock.radius + 5.0 + gap, 0, 0)
				_anchor.linear_velocity = Vector3.ZERO
				return rock
	fail_test("no rubble near the start")
	return null

func _arm() -> void:
	_anchor.add_to_group(AsteroidStream.SPACE_ANCHOR)

func test_a_rock_within_reach_becomes_a_sleeping_body_just_where_it_was():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	var body: AsteroidBody = _stream.bubble.live.get(rock.id())
	assert_not_null(body)
	assert_true(body.sleeping, "asleep until something touches it")
	assert_true(body.global_transform.is_equal_approx(_stream.rock_pose(rock)))
	assert_almost_eq(body.mass, minf(rock.mass, AsteroidBody.MASS_CAP), rock.mass * 1e-6)
	assert_eq(body.collision_layer, 64)
	assert_eq(body.collision_mask, 1 | 4 | 32 | 64)
	assert_true(body.is_in_group(Universe.EXTERIOR_SPACE))
	assert_true(_stream.is_hidden(rock), "its picture gives way")

func test_nothing_becomes_a_body_without_an_anchor():
	_beside_a_rock(10.0)
	_stream.bubble.step(DT)
	assert_eq(_stream.bubble.live.size(), 0)

func test_a_rock_out_of_reach_stays_a_picture():
	var rock := _beside_a_rock(AsteroidBubble.PAD + 20.0)
	_arm()
	_stream.bubble.step(DT)
	assert_false(_stream.bubble.live.has(rock.id()))

func test_the_reach_runs_ahead_along_your_velocity():
	var rock := _beside_a_rock(AsteroidBubble.PAD + 60.0)
	_arm()
	_anchor.linear_velocity = Vector3(-60, 0, 0)
	_stream.bubble.step(DT)
	assert_true(_stream.bubble.live.has(rock.id()), "1.5 s ahead at 60 m/s")

func test_an_untouched_body_goes_back_to_a_picture_after_you_pass():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	_anchor.global_position += Vector3(500, 0, 0)
	for i in 5:
		_stream.bubble.step(0.5)
	assert_false(_stream.bubble.live.has(rock.id()))
	assert_false(_stream.is_hidden(rock))
	assert_almost_eq(_stream.picture_transform(rock).origin, _stream.rock_pose(rock).origin, Vector3.ONE * 0.001)

func test_a_touched_rock_is_adrift_and_stays_while_in_sight():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	var body: AsteroidBody = _stream.bubble.live[rock.id()]
	body.global_position += Vector3(0, 0.02, 0)
	_stream.bubble.step(DT)
	assert_true(body.adrift)
	_anchor.global_position += Vector3(300, 0, 0)
	for i in 5:
		_stream.bubble.step(0.5)
	assert_true(_stream.bubble.live.has(rock.id()), "still within sight")
	assert_true(_stream.is_hidden(rock), "and its home stays empty")

func test_an_adrift_rock_is_dropped_out_of_sight_and_its_home_stays_empty():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	_stream.bubble.live[rock.id()].global_position += Vector3(0, 0.02, 0)
	_stream.bubble.step(DT)
	_anchor.global_position += Vector3(AsteroidStream.FADE_END[T.RUBBLE] + 100.0, 0, 0)
	_stream.bubble.step(DT)
	assert_false(_stream.bubble.live.has(rock.id()))
	assert_true(_stream.is_hidden(rock), "no second copy appears at home while its cell is loaded")

func test_the_home_is_forgotten_when_its_cell_unloads():
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	_stream.bubble.live[rock.id()].global_position += Vector3(0, 0.02, 0)
	_stream.bubble.step(DT)
	var home := _anchor.global_position
	_anchor.global_position += Vector3(5000, 0, 0)
	_stream.bubble.step(DT)
	_stream.update(0.0, true)
	_anchor.global_position = home
	_stream.update(0.0, true)
	assert_false(_stream.is_hidden(rock), "back in its seeded place")

func test_too_many_adrift_drops_the_farthest():
	_stream.bubble.max_adrift = 1
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	var near: AsteroidBody = _stream.bubble.live[rock.id()]
	var far := AsteroidBody.new()
	var other := AsteroidRock.new()
	other.cell = Vector3i(99, 99, 99)
	other.index = 1
	other.size = Vector3.ONE
	other.mass = 800.0
	far.setup(other, RockMesh.mesh(0, 0), _stream.rock_material(0, SpacePalette.ASH), RockMesh.hull_points(0, 0))
	_stream.get_node("Bodies").add_child(far)
	far.global_position = _anchor.global_position + Vector3(0, 0, 400)
	far.adrift = true
	_stream.bubble.live[other.id()] = far
	near.global_position += Vector3(0, 0.02, 0)
	_stream.bubble.step(DT)
	assert_true(_stream.bubble.live.has(rock.id()))
	assert_false(_stream.bubble.live.has(other.id()))
	assert_engine_error("adrift", "the cap says so")

func test_segment_distance():
	assert_almost_eq(AsteroidBubble.segment_distance(Vector3(5, 3, 0), Vector3.ZERO, Vector3(10, 0, 0)), 3.0, 0.0001)
	assert_almost_eq(AsteroidBubble.segment_distance(Vector3(-4, 3, 0), Vector3.ZERO, Vector3(10, 0, 0)), 5.0, 0.0001)
	assert_almost_eq(AsteroidBubble.segment_distance(Vector3(1, 1, 0), Vector3.ZERO, Vector3.ZERO), sqrt(2.0), 0.0001)

func test_a_new_body_is_where_its_rock_is_to_the_physics_server_at_once():
	# Placed after entering the tree, a body would sit at its holder's origin
	# -- usually right where you are -- until transforms next flush.
	var rock := _beside_a_rock(10.0)
	_arm()
	_stream.bubble.step(DT)
	var body: AsteroidBody = _stream.bubble.live[rock.id()]
	var server: Transform3D = PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	assert_almost_eq(server.origin, _stream.rock_pose(rock).origin, Vector3.ONE * 0.001)
	assert_true(PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING), "and asleep there")
