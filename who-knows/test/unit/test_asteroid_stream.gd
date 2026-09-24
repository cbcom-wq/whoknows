extends GutTest

## Streaming and pictures (docs/superpowers/specs/2026-09-24-asteroids-design.md
## §6), headless: a Universe, a focus, and the stream around it.

const T := AsteroidRecipe.Tier

var _world: Node3D
var _universe: Universe
var _focus: Node3D
var _stream: AsteroidStream
var _start: UniversePoint

func before_each():
	_world = Node3D.new()
	add_child_autofree(_world)
	_universe = Universe.new()
	_world.add_child(_universe)
	_focus = Node3D.new()
	_world.add_child(_focus)
	_focus.add_to_group(Universe.EXTERIOR_SPACE)
	_universe.set_focus(_focus)
	_stream = AsteroidStream.new()
	_world.add_child(_stream)
	_start = AsteroidRecipe.new(_stream.seed).find_start()
	_universe.origin = _start
	_stream.start(_universe, _start)

func _focus_cell(tier: int) -> Vector3i:
	return AsteroidRecipe.cell_of(tier, _universe.to_universe(_focus.global_position))

func _any_rock(tier: int) -> AsteroidRock:
	for x in range(-2, 3):
		for y in range(-2, 3):
			for z in range(-2, 3):
				var rocks := _stream.loaded_rocks(tier, _focus_cell(tier) + Vector3i(x, y, z))
				if not rocks.is_empty():
					return rocks[0]
	return null

func test_every_tier_loads_at_least_a_second_ahead_of_boost():
	for tier in AsteroidRecipe.TIERS:
		assert_gte(AsteroidStream.LOAD[tier] - AsteroidStream.FADE_END[tier], AsteroidStream.TOP_SPEED * 1.0)
		assert_gt(AsteroidStream.UNLOAD[tier], AsteroidStream.LOAD[tier])
		assert_gt(AsteroidStream.FADE_END[tier], AsteroidStream.FADE_START[tier])

func test_the_first_load_is_done_before_it_returns():
	for tier in AsteroidRecipe.TIERS:
		assert_true(_stream.is_loaded(tier, _focus_cell(tier)), "tier %d around you" % tier)
		assert_gt(_stream.loaded_count(tier), 0)
	assert_eq(_stream.late_cells, 0)

func test_a_picture_is_drawn_exactly_where_its_rock_is():
	var rock := _any_rock(T.RUBBLE)
	assert_not_null(rock)
	var want := Transform3D(rock.basis(), _stream.rock_pose(rock).origin)
	var got := _stream.picture_transform(rock)
	assert_almost_eq(got.origin, want.origin, Vector3.ONE * 0.001)
	assert_true(got.basis.is_equal_approx(want.basis))

func test_packing_follows_the_multimesh_layout():
	# MultiMesh.buffer, TRANSFORM_3D with colours: the transform's three rows
	# (basis columns' x, then y, then z, each followed by the origin's), then
	# the colour. The live check confirms it on a real renderer.
	var t := Transform3D(Basis.from_euler(Vector3(0.3, -1.2, 2.0)).scaled(Vector3(2, 3, 4)), Vector3(10, -20, 30))
	var buf := AsteroidStream.pack(PackedFloat32Array([1, 2]), t, SpacePalette.RUST)
	assert_eq(buf.size(), 18, "appends 16 floats")
	var row0 := PackedFloat32Array([t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x])
	assert_eq(buf.slice(2, 6), row0)
	assert_almost_eq(buf[2 + 12], SpacePalette.RUST.r, 1e-6)
	assert_true(AsteroidStream.unpack(buf.slice(2), 0).is_equal_approx(t))

func test_hiding_and_showing_a_rock():
	var rock := _any_rock(T.RUBBLE)
	_stream.hide_rock(rock)
	assert_true(_stream.is_hidden(rock))
	assert_eq(_stream.picture_transform(rock).basis, Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO))
	_stream.show_rock(rock)
	assert_false(_stream.is_hidden(rock))
	assert_almost_eq(_stream.picture_transform(rock).origin, _stream.rock_pose(rock).origin, Vector3.ONE * 0.001)

func test_cells_unload_past_unload_and_stay_between():
	var tier := T.RUBBLE
	var home := _focus_cell(tier)
	# Move so home (the 200 m cell whose corner is the start) is between LOAD
	# and UNLOAD away: it stays loaded.
	_focus.global_position += Vector3(AsteroidStream.LOAD[tier] + 300.0, 0, 0)
	_stream.update(0.0, true)
	assert_true(_stream.is_loaded(tier, home), "hysteresis: no flicker at the edge")
	_focus.global_position += Vector3(AsteroidStream.UNLOAD[tier] + 400.0, 0, 0)
	_stream.update(0.0, true)
	assert_false(_stream.is_loaded(tier, home))

func test_a_result_no_longer_wanted_is_dropped():
	var far := Vector3(0, 0, 50000)
	_focus.global_position = far
	_stream.update(0.0)
	_focus.global_position = Vector3.ZERO
	_stream.update(0.0, true)
	var cell := AsteroidRecipe.cell_of(T.RUBBLE, _universe.to_universe(far))
	assert_false(_stream.is_loaded(T.RUBBLE, cell), "out of date by the time it finished")

func test_everything_drawn_moves_with_the_origin():
	for block in _stream.find_children("Block_*", "Node3D", true, false):
		assert_true(block.is_in_group(Universe.EXTERIOR_SPACE))
	assert_false(_stream.is_in_group(Universe.EXTERIOR_SPACE), "the stream itself never moves")

func test_a_shift_keeps_pictures_on_their_rocks():
	var rock := _any_rock(T.MID)
	_focus.global_position = Vector3(2600, 0, 0)
	_universe.check()
	_stream.update(0.0, true)
	assert_almost_eq(_stream.picture_transform(rock).origin, _stream.rock_pose(rock).origin, Vector3.ONE * 0.002)

func test_pictures_fade_by_tier_and_only_giants_cast_shadows():
	var m := _stream.rock_material(T.MID, SpacePalette.UNTINTED)
	assert_eq(m.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER)
	assert_eq(m.distance_fade_min_distance, AsteroidStream.FADE_END[T.MID])
	assert_eq(m.distance_fade_max_distance, AsteroidStream.FADE_START[T.MID])
	for inst in _stream.find_children("*", "MultiMeshInstance3D", true, false):
		var giant := String(inst.get_parent().name).begins_with("Block_2_")
		assert_eq(inst.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, giant)
		assert_eq(inst.layers, 1)
