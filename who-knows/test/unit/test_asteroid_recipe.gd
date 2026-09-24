extends GutTest

## The recipe (docs/superpowers/specs/2026-09-24-asteroids-design.md §5): the
## same rocks every time, never overlapping, in fields with gaps.

const SEED := 1337
const T := AsteroidRecipe.Tier

var _recipe: AsteroidRecipe

func before_each():
	_recipe = AsteroidRecipe.new(SEED)

## A cell in a field's core, so there are rocks to test.
func _dense(tier: int) -> Vector3i:
	for x in 2000:
		var c := Vector3i(x, 3, -2)
		if _recipe.cell_density(tier, c) > 0.9:
			return c
	fail_test("no dense cell found")
	return Vector3i.ZERO

func test_the_hash_is_splitmix64_and_pinned():
	assert_eq(AsteroidRecipe.mix(1), 6238072747940578789)
	assert_eq(AsteroidRecipe.mix(-5), 5185122842947594062)
	assert_eq(AsteroidRecipe.cell_seed(1337, 0, Vector3i.ZERO), 781683203928849809)
	assert_eq(AsteroidRecipe.cell_seed(1337, 2, Vector3i(-3, 7, 1)), -4929385403267878857)

func test_the_same_cell_gives_the_same_rocks():
	var c := _dense(T.MID)
	var a := AsteroidRecipe.new(SEED).cell_rocks(T.MID, c)
	var b := AsteroidRecipe.new(SEED).cell_rocks(T.MID, c)
	assert_gt(a.size(), 0)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].local, b[i].local)
		assert_eq(a[i].size, b[i].size)
		assert_eq(a[i].turn, b[i].turn)
		assert_eq(a[i].colour, b[i].colour)
		assert_eq(a[i].id(), b[i].id())

func test_another_seed_gives_other_rocks():
	var c := _dense(T.MID)
	var a := _recipe.cell_rocks(T.MID, c)
	var b := AsteroidRecipe.new(SEED + 1).cell_rocks(T.MID, c)
	assert_true(b.is_empty() or a.is_empty() or a[0].local != b[0].local)

func test_every_rock_stays_inside_its_cell():
	for tier in AsteroidRecipe.TIERS:
		var size := float(AsteroidRecipe.CELL[tier])
		for rock in _recipe.cell_rocks(tier, _dense(tier)):
			for axis in 3:
				assert_true(rock.local[axis] - rock.radius >= 0.0 and rock.local[axis] + rock.radius <= size,
					"tier %d rock %d pokes out of its cell" % [tier, rock.index])

func test_no_rocks_overlap_in_a_field_core():
	# Every rubble cell of one dense mid cell, against each other within a
	# cell, and against the mid and giant rocks around them.
	var giant := _dense(T.GIANT)
	var mid := giant * AsteroidRecipe.NEST + Vector3i(2, 2, 2)
	var overlaps := 0
	var checked := 0
	var corner := AsteroidRecipe.cell_corner(T.MID, mid)
	var big := []
	for r in _recipe.cell_rocks(T.MID, mid):
		big.append([r.local, r.radius])
	var gc := AsteroidRecipe.cell_corner(T.GIANT, giant).minus(corner)
	for r in _recipe.cell_rocks(T.GIANT, giant):
		big.append([gc + r.local, r.radius])
	for i in big.size():
		for j in range(i + 1, big.size()):
			checked += 1
			if big[i][0].distance_to(big[j][0]) < big[i][1] + big[j][1]:
				overlaps += 1
	for x in 5:
		for y in 5:
			for z in 5:
				var cell := mid * AsteroidRecipe.NEST + Vector3i(x, y, z)
				var off := AsteroidRecipe.cell_corner(T.RUBBLE, cell).minus(corner)
				var rocks := _recipe.cell_rocks(T.RUBBLE, cell)
				for i in rocks.size():
					for j in range(i + 1, rocks.size()):
						checked += 1
						if rocks[i].local.distance_to(rocks[j].local) < rocks[i].radius + rocks[j].radius:
							overlaps += 1
					for b in big:
						checked += 1
						if (off + rocks[i].local).distance_to(b[0]) < rocks[i].radius + b[1]:
							overlaps += 1
	assert_gt(checked, 1000, "a real field was checked")
	assert_eq(overlaps, 0)

func test_fields_have_gaps_and_cores():
	var empty := 0
	var full := 0
	var n := 0
	for x in 60:
		for z in 60:
			var d := _recipe.cell_density(T.MID, Vector3i(x * 3, 0, z * 3))
			n += 1
			if d <= 0.0:
				empty += 1
			elif d >= 0.99:
				full += 1
	gut.p("density over %d mid cells: %.0f%% empty, %.0f%% core" % [n, 100.0 * empty / n, 100.0 * full / n])
	assert_gt(empty, n / 10, "gaps")
	assert_gt(full, n / 50, "cores")

func test_giants_live_only_in_cores():
	for x in 200:
		var c := Vector3i(x, 0, 0)
		if not _recipe.cell_rocks(T.GIANT, c).is_empty():
			assert_gt(_recipe.cell_density(T.GIANT, c), AsteroidRecipe.GIANT_DENSITY)

func test_the_start_is_at_a_fields_edge_and_clear():
	var start := _recipe.find_start()
	var d := _recipe.density_at(start)
	assert_between(d, 0.3, 0.6)
	var r := AsteroidRecipe.new(SEED, start)
	for tier in AsteroidRecipe.TIERS:
		var home := AsteroidRecipe.cell_of(tier, start)
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var cell := home + Vector3i(x, y, z)
					var corner := AsteroidRecipe.cell_corner(tier, cell)
					for rock in r.cell_rocks(tier, cell):
						var at := corner.plus(rock.local)
						assert_gt(at.minus(start).length(), AsteroidRecipe.START_CLEAR + rock.radius - 0.001)

func test_mass_follows_size():
	for rock in _recipe.cell_rocks(T.MID, _dense(T.MID)):
		assert_almost_eq(rock.mass, AsteroidRecipe.MASS_PER_M3 * rock.size.x * rock.size.y * rock.size.z, rock.mass * 1e-5)

func test_veined_rocks_are_never_rubble_and_carry_their_own_colour():
	var veined := 0
	for x in 40:
		for rock in _recipe.cell_rocks(T.MID, _dense(T.MID) + Vector3i(0, x, 0)):
			if rock.shape == RockMesh.Shape.VEINED:
				veined += 1
				assert_eq(rock.colour, SpacePalette.UNTINTED)
	for rock in _recipe.cell_rocks(T.RUBBLE, _dense(T.RUBBLE)):
		assert_ne(rock.shape, RockMesh.Shape.VEINED)
	assert_gt(veined, 0, "some mid-size rocks are veined")

func test_cells_nest_and_floor_toward_minus_infinity():
	assert_eq(AsteroidRecipe.floor_div(-1, 5), -1)
	assert_eq(AsteroidRecipe.floor_div(-5, 5), -1)
	assert_eq(AsteroidRecipe.floor_div(-6, 5), -2)
	assert_eq(AsteroidRecipe.parent_of(T.RUBBLE, Vector3i(-1, 24, 25), T.GIANT), Vector3i(-1, 0, 1))
	assert_eq(AsteroidRecipe.cell_of(T.MID, UniversePoint.at(-1, 999, 1000)), Vector3i(-1, 0, 1))
