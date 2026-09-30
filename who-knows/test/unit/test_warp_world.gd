extends GutTest

## The world while a warp carries you (the warp spec §5.2): the rocks stop
## streaming and hide, and come back whole at once; belts show every slab; the
## dust stretches into streaks along the velocity and shrinks back after.

func test_a_suspended_stream_hides_its_rocks_loads_nothing_and_resumes_whole():
	var universe := Universe.new()
	add_child_autofree(universe)
	var focus := Node3D.new()
	add_child_autofree(focus)
	universe.set_focus(focus)
	var stream := AsteroidStream.new()
	stream.seed = 1337
	add_child_autofree(stream)
	stream.start(universe)
	assert_gt(stream.loaded_count(0), 0)
	stream.suspended = true
	assert_false((stream.get_node("Pictures") as Node3D).visible)
	assert_false((stream.get_node("Details") as Node3D).visible)
	universe.origin = universe.origin.plus(Vector3(0, 0, -40000))
	await wait_frames(5)
	var here := AsteroidRecipe.cell_of(0, universe.to_universe(focus.global_position))
	assert_false(stream.is_loaded(0, here), "nothing loads while suspended")
	stream.resume()
	assert_false(stream.suspended)
	assert_true((stream.get_node("Pictures") as Node3D).visible)
	assert_true(stream.is_loaded(0, here), "everything near is loaded at once")

func test_at_warp_a_belt_shows_every_slab():
	var s := SystemRecipe.from_seed(1337)
	var look := BeltLook.new()
	look.setup(s.belts[0], 7)
	add_child_autofree(look)
	assert_eq(look.material_override, BeltLook.material())
	look.set_whole(true)
	assert_eq(look.material_override, BeltLook.whole_material())
	assert_lt(BeltLook.whole_material().distance_fade_max_distance, 1000.0, "only the canopy's closest slab dithers")
	look.set_whole(false)
	assert_eq(look.material_override, BeltLook.material())

func test_dust_streaks_along_the_warp_and_comes_back():
	var universe := Universe.new()
	add_child_autofree(universe)
	var dust := SpaceDust.new()
	add_child_autofree(dust)
	var focus := UniversePoint.at(1000, 2000, 3000)
	dust.place(universe, focus)
	# A fleck well inside the box: one at its edge is shrunk to nothing.
	var i := 0
	while absf(dust.fleck_basis(i).determinant()) < 1e-4:
		i += 1
	var calm := absf(dust.fleck_basis(i).determinant())
	dust.streak = Vector3(0, 0, -30)
	dust.place(universe, focus)
	var stretched := absf(dust.fleck_basis(i).determinant())
	assert_almost_eq(stretched / calm, 1.0 + 30.0 / SpaceDust.STREAK_BASE, 0.01, "stretched along the streak")
	dust.streak = Vector3(0, 0, -1000)
	dust.place(universe, focus)
	assert_almost_eq(absf(dust.fleck_basis(i).determinant()) / calm, 1.0 + SpaceDust.STREAK_MAX / SpaceDust.STREAK_BASE,
		0.01, "capped at STREAK_MAX")
	dust.streak = Vector3.ZERO
	dust.place(universe, focus)
	assert_almost_eq(absf(dust.fleck_basis(i).determinant()), calm, calm * 1e-4, "back to flecks")

func test_stretch_stretches_only_along_its_direction():
	var m := SpaceDust.stretch(Vector3(0, 0, 1), 5.0)
	assert_true((m * Vector3(0, 0, 1)).is_equal_approx(Vector3(0, 0, 5)))
	assert_true((m * Vector3(1, 0, 0)).is_equal_approx(Vector3(1, 0, 0)))
