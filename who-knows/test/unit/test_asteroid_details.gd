extends GutTest

## Big rocks up close (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §18): within NEAR of the hull or a spacewalker a big rock is drawn in detail
## and solid exactly as drawn, fixed where it is; past FAR it is a picture
## again. Headless, with bare nodes, starting 700 m off a big rock.

const T := AsteroidRecipe.Tier

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
	_anchor.add_to_group(AsteroidStream.SPACE_ANCHOR)
	_anchor.set_meta(AsteroidStream.ANCHOR_RADIUS, 10.0)
	_universe.set_focus(_anchor)
	_stream = AsteroidStream.new()
	_world.add_child(_stream)
	var start := AsteroidRecipe.new(_stream.seed).find_start()
	_universe.origin = start
	_stream.start(_universe, start)

## The big rock you start beside.
func _ahead() -> AsteroidRock:
	var best: AsteroidRock = null
	var best_d := INF
	var fc := AsteroidRecipe.cell_of(T.GIANT, _universe.to_universe(_anchor.global_position))
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				for rock in _stream.loaded_rocks(T.GIANT, fc + Vector3i(x, y, z)):
					var d := _stream.rock_pose(rock).origin.distance_to(_anchor.global_position)
					if d < best_d:
						best = rock
						best_d = d
	return best

## Puts the anchor `gap` metres outside the big rock's bounds, and steps.
func _stand_off(rock: AsteroidRock, gap: float) -> void:
	var centre := _stream.rock_pose(rock).origin
	_anchor.global_position = centre + Vector3(0, 0, rock.radius + gap)
	_stream.update(0.0, true)
	_stream.details.step()
	_stream.details.finish()
	_stream.details.step()

func test_the_big_rock_you_start_by_is_in_detail_at_once():
	var rock := _ahead()
	var detail: AsteroidDetail = _stream.details.live.get(rock.id())
	assert_not_null(detail, "detailed before the first frame")
	assert_true(detail is StaticBody3D, "fixed where it is")
	assert_true(detail.global_transform.is_equal_approx(_stream.rock_pose(rock)))
	assert_eq(detail.collision_layer, AsteroidBody.LAYER)
	assert_true(detail.is_in_group(Universe.EXTERIOR_SPACE))
	assert_true(_stream.is_hidden(rock), "its picture gives way")

func test_it_is_solid_exactly_as_drawn_even_in_a_crater():
	var detail: AsteroidDetail = _stream.details.live.get(_ahead().id())
	var data := detail.data
	# A crater with no boulder in it.
	var crater: Array = []
	for c in data.craters:
		var clear := true
		for b in data.boulders:
			if (b[4] as Vector3).angle_to(c[0]) < float(c[1]) * 1.2:
				clear = false
		if clear:
			crater = c
			break
	if crater.is_empty():
		pending("every crater holds a boulder")
		return
	await wait_physics_frames(2)
	var floor_local := data.surface_point(crater[0])
	var floor := detail.global_transform * floor_local
	var out := (detail.global_basis * floor_local).normalized()
	var query := PhysicsRayQueryParameters3D.create(floor + out * 150.0, floor - out * 5.0, AsteroidBody.LAYER)
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "the ray meets the rock")
	if not hit.is_empty():
		assert_eq(hit.collider, detail)
		assert_lt((hit.position as Vector3).distance_to(floor), 2.0, "at the crater's floor, not a shell over it")

func test_between_near_and_far_it_stays_in_detail():
	var rock := _ahead()
	_stand_off(rock, (AsteroidDetails.NEAR + AsteroidDetails.FAR) * 0.5)
	assert_true(_stream.details.live.has(rock.id()), "no flicker at the edge")

func test_past_far_it_is_a_picture_again():
	var rock := _ahead()
	_stand_off(rock, AsteroidDetails.FAR + 300.0)
	assert_false(_stream.details.live.has(rock.id()))
	assert_false(_stream.is_hidden(rock))

func test_coming_near_it_is_built_off_the_main_thread():
	var rock := _ahead()
	_stand_off(rock, AsteroidDetails.FAR + 300.0)
	var centre := _stream.rock_pose(rock).origin
	_anchor.global_position = centre + Vector3(0, 0, rock.radius + 1000.0)
	_stream.details.step()
	assert_false(_stream.details.live.has(rock.id()), "not built on this frame")
	_stream.details.finish()
	_stream.details.step()
	assert_true(_stream.details.live.has(rock.id()), "and in once it is")

func test_big_rocks_never_become_pushable_bodies():
	var rock := _ahead()
	_anchor.global_position = _stream.rock_pose(rock).origin + Vector3(0, 0, rock.radius + 5.0)
	_anchor.linear_velocity = Vector3(0, 0, -60)
	_stream.bubble.step(1.0 / 60.0)
	var giants := 0
	for body: AsteroidBody in _stream.bubble.live.values():
		if body.rock.tier == T.GIANT:
			giants += 1
	assert_eq(giants, 0, "headed straight at it, it stays fixed")
	assert_false(_stream.bubble.live.has(rock.id()))
