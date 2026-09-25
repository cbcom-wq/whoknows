extends GutTest

## The recipe (docs/superpowers/specs/2026-09-24-asteroids-design.md §5, as
## amended 2026-09-24 by §17): the same rocks every time, never overlapping,
## in groups -- a big rock with little ones round it -- a few kilometres apart.

const SEED := 1337
const T := AsteroidRecipe.Tier

var _recipe: AsteroidRecipe

func before_each():
	_recipe = AsteroidRecipe.new(SEED)

## A region that holds a big rock: [its giant cell, the rock].
func _group(from := 0) -> Array:
	for x in range(from, from + 400):
		var c := Vector3i(x, 3, -2)
		var rocks := _recipe.cell_rocks(T.GIANT, c)
		if not rocks.is_empty():
			return [c, rocks[0]]
	fail_test("no group found")
	return [Vector3i.ZERO, null]

## The big rock's centre, as a universe point.
func _centre(group: Array) -> UniversePoint:
	return AsteroidRecipe.cell_corner(T.GIANT, group[0]).plus(group[1].local)

## A cell of `tier` just off the big rock's surface, which holds rocks.
func _near(tier: int, group: Array) -> Vector3i:
	var big: AsteroidRock = group[1]
	var centre := _centre(group)
	for k in range(0, 40):
		var dir := Vector3(sin(k * 1.7), cos(k * 2.3), sin(k * 0.9)).normalized()
		var at := centre.plus(dir * (big.radius + AsteroidRecipe.CELL[tier] * 0.6))
		var cell := AsteroidRecipe.cell_of(tier, at)
		if not _recipe.cell_rocks(tier, cell).is_empty():
			return cell
	fail_test("no tier %d rocks round the group" % tier)
	return Vector3i.ZERO

func test_the_hash_is_splitmix64_and_pinned():
	assert_eq(AsteroidRecipe.mix(1), 6238072747940578789)
	assert_eq(AsteroidRecipe.mix(-5), 5185122842947594062)
	assert_eq(AsteroidRecipe.cell_seed(1337, 0, Vector3i.ZERO), 781683203928849809)
	assert_eq(AsteroidRecipe.cell_seed(1337, 2, Vector3i(-3, 7, 1)), -4929385403267878857)

func test_the_same_cell_gives_the_same_rocks():
	var c := _near(T.RUBBLE, _group())
	var a := AsteroidRecipe.new(SEED).cell_rocks(T.RUBBLE, c)
	var b := AsteroidRecipe.new(SEED).cell_rocks(T.RUBBLE, c)
	assert_gt(a.size(), 0)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].local, b[i].local)
		assert_eq(a[i].size, b[i].size)
		assert_eq(a[i].turn, b[i].turn)
		assert_eq(a[i].colour, b[i].colour)
		assert_eq(a[i].id(), b[i].id())

func test_another_seed_gives_other_rocks():
	var c := _near(T.RUBBLE, _group())
	var a := _recipe.cell_rocks(T.RUBBLE, c)
	var b := AsteroidRecipe.new(SEED + 1).cell_rocks(T.RUBBLE, c)
	assert_true(b.is_empty() or a.is_empty() or a[0].local != b[0].local)

func test_a_region_holds_at_most_one_big_rock_of_150_to_600_m():
	var groups := 0
	for x in 300:
		var rocks := _recipe.cell_rocks(T.GIANT, Vector3i(x, 0, 1))
		assert_lte(rocks.size(), 1)
		for rock in rocks:
			groups += 1
			var across := pow(rock.size.x * rock.size.y * rock.size.z, 1.0 / 3.0)
			assert_between(across, 150.0 * AsteroidRecipe.STRETCH_MIN, 600.0 * AsteroidRecipe.STRETCH_MAX)
	assert_between(groups, 60, 240, "some regions hold a group, some are empty")

func test_every_rock_stays_inside_its_cell():
	var group := _group()
	for tier in AsteroidRecipe.TIERS:
		var cell: Vector3i = group[0] if tier == T.GIANT else _near(tier, group)
		var size := float(AsteroidRecipe.CELL[tier])
		for rock in _recipe.cell_rocks(tier, cell):
			for axis in 3:
				assert_true(rock.local[axis] - rock.radius >= 0.0 and rock.local[axis] + rock.radius <= size,
					"tier %d rock %d pokes out of its cell" % [tier, rock.index])

func test_nothing_overlaps_in_a_group():
	# Every rubble cell of the mid cell the big rock sits in, against each
	# other within a cell, and against the mid and big rocks around them.
	var group := _group()
	var mid := AsteroidRecipe.cell_of(T.MID, _centre(group))
	var overlaps := 0
	var checked := 0
	var corner := AsteroidRecipe.cell_corner(T.MID, mid)
	var big := []
	for r in _recipe.cell_rocks(T.MID, mid):
		big.append([r.local, r.radius])
	var gc := AsteroidRecipe.cell_corner(T.GIANT, group[0]).minus(corner)
	for r in _recipe.cell_rocks(T.GIANT, group[0]):
		big.append([gc + r.local, r.radius])
	for i in big.size():
		for j in range(i + 1, big.size()):
			checked += 1
			if big[i][0].distance_to(big[j][0]) < big[i][1] + big[j][1]:
				overlaps += 1
	var rubble := 0
	for x in 5:
		for y in 5:
			for z in 5:
				var cell := mid * AsteroidRecipe.NEST + Vector3i(x, y, z)
				var off := AsteroidRecipe.cell_corner(T.RUBBLE, cell).minus(corner)
				var rocks := _recipe.cell_rocks(T.RUBBLE, cell)
				rubble += rocks.size()
				for i in rocks.size():
					for j in range(i + 1, rocks.size()):
						checked += 1
						if rocks[i].local.distance_to(rocks[j].local) < rocks[i].radius + rocks[j].radius:
							overlaps += 1
					for b in big:
						checked += 1
						if (off + rocks[i].local).distance_to(b[0]) < rocks[i].radius + b[1]:
							overlaps += 1
	assert_gt(rubble, 20, "a real swarm was checked")
	assert_eq(overlaps, 0)

func test_little_ones_crowd_round_big_ones_and_sprinkle_the_rest():
	var near := 0
	var far := 0
	var near_cells := 0
	var far_cells := 0
	for g in 6:
		var group := _group(g * 60)
		var big: AsteroidRock = group[1]
		var centre := _centre(group)
		for k in 30:
			var dir := Vector3(sin(k * 1.3 + g), cos(k * 0.7), sin(k * 2.1 - g)).normalized()
			near += _recipe.cell_rocks(T.RUBBLE, AsteroidRecipe.cell_of(T.RUBBLE, centre.plus(dir * (big.radius + 150.0)))).size()
			near_cells += 1
	# Open space: rubble cells in the middle of empty regions that no big
	# rock's halo reaches.
	for x in 400:
		var region := Vector3i(x, -7, 5)
		if not _recipe.cell_rocks(T.GIANT, region).is_empty():
			continue
		var base := AsteroidRecipe.cell_of(T.RUBBLE, AsteroidRecipe.cell_corner(T.GIANT, region).plus(Vector3(1500, 2500, 2500)))
		for i in 10:
			var cell := base + Vector3i(i, 0, 0)
			if not _recipe._big_rocks_near(T.RUBBLE, cell).is_empty():
				continue
			far += _recipe.cell_rocks(T.RUBBLE, cell).size()
			far_cells += 1
		if far_cells >= 1500:
			break
	var near_mean := float(near) / near_cells
	var far_mean := float(far) / maxi(far_cells, 1)
	gut.p("rubble per 200 m cell: %.2f beside a big rock, %.3f in open space (%d cells)" % [near_mean, far_mean, far_cells])
	assert_gt(far_cells, 100, "found open space")
	assert_gt(near_mean, far_mean * 20.0, "the little ones crowd round the big ones")
	assert_gt(far, 0, "a thin sprinkle in between")
	assert_lt(far_mean, 1.0, "only a thin one")

func test_groups_are_mostly_3_to_6_km_apart():
	var centres: Array[Vector3] = []
	var corner := AsteroidRecipe.cell_corner(T.GIANT, Vector3i.ZERO)
	for x in 12:
		for y in 12:
			for z in 12:
				var c := Vector3i(x, y, z)
				for rock in _recipe.cell_rocks(T.GIANT, c):
					centres.append(AsteroidRecipe.cell_corner(T.GIANT, c).minus(corner) + rock.local)
	var gaps: Array[float] = []
	for i in centres.size():
		var best := INF
		for j in centres.size():
			if i != j:
				best = minf(best, centres[i].distance_to(centres[j]))
		# Groups near the sample's edge may have their nearest outside it.
		var p := centres[i]
		if p.x > 5000.0 and p.y > 5000.0 and p.z > 5000.0 and p.x < 55000.0 and p.y < 55000.0 and p.z < 55000.0:
			gaps.append(best)
	gaps.sort()
	var median := gaps[gaps.size() / 2]
	gut.p("%d groups; nearest neighbour: median %.1f km, 10%% %.1f km, 90%% %.1f km" % [centres.size(), median / 1000.0,
		gaps[gaps.size() / 10] / 1000.0, gaps[gaps.size() * 9 / 10] / 1000.0])
	assert_between(median, 3000.0, 6000.0)

func test_the_start_faces_a_big_rock_and_is_clear():
	var start := _recipe.find_start()
	var r := AsteroidRecipe.new(SEED, start)
	var ahead := false
	for tier in AsteroidRecipe.TIERS:
		var home := AsteroidRecipe.cell_of(tier, start)
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var cell := home + Vector3i(x, y, z)
					var corner := AsteroidRecipe.cell_corner(tier, cell)
					for rock in r.cell_rocks(tier, cell):
						var to := corner.plus(rock.local).minus(start)
						assert_gt(to.length(), AsteroidRecipe.START_CLEAR + rock.radius - 0.001)
						if tier == T.GIANT and to.z < 0.0 and absf(to.x) < 1.0 and absf(to.y) < 1.0:
							ahead = true
							assert_almost_eq(-to.z - rock.radius, AsteroidRecipe.START_STANDOFF, 1.5)
	assert_true(ahead, "a big rock dead ahead, along -z")

func test_mass_follows_size():
	for rock in _recipe.cell_rocks(T.RUBBLE, _near(T.RUBBLE, _group())):
		assert_almost_eq(rock.mass, AsteroidRecipe.MASS_PER_M3 * rock.size.x * rock.size.y * rock.size.z, rock.mass * 1e-5)

func test_veined_rocks_are_never_rubble_and_carry_their_own_colour():
	var veined := 0
	for x in 400:
		for rock in _recipe.cell_rocks(T.GIANT, Vector3i(x, 1, 0)):
			if rock.shape == RockMesh.Shape.VEINED:
				veined += 1
				assert_eq(rock.colour, SpacePalette.UNTINTED)
	for rock in _recipe.cell_rocks(T.RUBBLE, _near(T.RUBBLE, _group())):
		assert_ne(rock.shape, RockMesh.Shape.VEINED)
	assert_gt(veined, 0, "some big rocks are veined")

func test_cells_nest_and_floor_toward_minus_infinity():
	assert_eq(AsteroidRecipe.floor_div(-1, 5), -1)
	assert_eq(AsteroidRecipe.floor_div(-5, 5), -1)
	assert_eq(AsteroidRecipe.floor_div(-6, 5), -2)
	assert_eq(AsteroidRecipe.parent_of(T.RUBBLE, Vector3i(-1, 24, 25), T.GIANT), Vector3i(-1, 0, 1))
	assert_eq(AsteroidRecipe.cell_of(T.MID, UniversePoint.at(-1, 999, 1000)), Vector3i(-1, 0, 1))
