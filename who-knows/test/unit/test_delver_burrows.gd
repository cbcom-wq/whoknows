extends GutTest

## Delver burrows on the veined rocks (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §3.1, §5): only a veined rock has one, a
## single Delver whose round is six to ten points on the crystal vein, fifteen
## metres apart; the site hands its mind the round.

const T := AsteroidRecipe.Tier
const SEED := 1337

var _rocks: Array[AsteroidRock] = []
var _details: Array[RockDetail] = []
var _veined: Array[AsteroidRock] = []
var _veined_details: Array[RockDetail] = []

func before_all():
	RockMesh.warm()
	var recipe := AsteroidRecipe.new(SEED)
	for x in 3000:
		for rock in recipe.cell_rocks(T.GIANT, Vector3i(x, 3, -2)):
			if rock.shape == RockMesh.Shape.VEINED:
				if _veined.size() < 5:
					_veined.append(rock)
					_veined_details.append(RockDetail.build(rock, SEED))
			elif _rocks.size() < 6:
				_rocks.append(rock)
				_details.append(RockDetail.build(rock, SEED))
		if _rocks.size() >= 6 and _veined.size() >= 5:
			break

func _none() -> Array[Vector3]:
	return [] as Array[Vector3]

func test_we_found_rocks_to_try():
	assert_eq(_rocks.size(), 6)
	assert_eq(_veined.size(), 5)

func test_only_veined_rocks_have_a_delver():
	for i in _rocks.size():
		assert_eq(DelverBurrows.groups(_rocks[i], _details[i], SEED, _none(), 0).size(), 0,
			"a %s rock has no Delver" % _rocks[i].shape)
	for i in _veined.size():
		var made := DelverBurrows.groups(_veined[i], _veined_details[i], SEED, _none(), 0)
		assert_eq(made.size(), 1, "a veined rock has one")
		assert_eq(made[0]["species"], DelverBurrows.SPECIES)
		assert_eq(int(made[0]["count"]), 1)
		assert_true(RockMesh.in_vein(made[0]["home_dir"]), "and it lives on the vein")
		assert_eq(DelverBurrows.member_dirs(made[0], _veined_details[i]), [made[0]["home_dir"]] as Array[Vector3],
			"one Delver, at its home")

func test_its_round_is_6_to_10_points_on_the_vein_15_m_apart():
	for i in _veined.size():
		var data := _veined_details[i]
		var g := DelverBurrows.groups(_veined[i], data, SEED, _none(), 0)[0]
		var round: Array = g["burrows"]
		assert_between(round.size(), DelverBurrows.POINTS.x, DelverBurrows.POINTS.y)
		assert_eq(round[0], g["home_dir"], "the round starts at its home")
		for a in round.size():
			assert_true(RockMesh.in_vein(round[a]), "point %d of rock %d is on the vein" % [a, i])
			for b in range(a + 1, round.size()):
				assert_gte(data.surface_point(round[a]).distance_to(data.surface_point(round[b])), 15.0 - 0.001,
					"points %d and %d are 15 m apart" % [a, b])

func test_the_same_rock_gives_the_same_burrows():
	for i in _veined.size():
		var a := DelverBurrows.groups(_veined[i], _veined_details[i], SEED, _none(), 4)
		var b := DelverBurrows.groups(_veined[i], _veined_details[i], SEED, _none(), 4)
		assert_eq(a[0]["home_dir"], b[0]["home_dir"])
		assert_eq(a[0]["seed"], b[0]["seed"])
		assert_eq(a[0]["burrows"], b[0]["burrows"])
		assert_eq(int(a[0]["index"]), 4, "numbered on from the index it is given")

func test_it_avoids_homes_it_is_told_are_taken():
	for i in _veined.size():
		var free := DelverBurrows.groups(_veined[i], _veined_details[i], SEED, _none(), 0)[0]
		var taken: Array[Vector3] = [free["home_dir"]]
		for g in DelverBurrows.groups(_veined[i], _veined_details[i], SEED, taken, 0):
			assert_true(RockLife.clear_of(_veined_details[i], g["home_dir"], taken))

func test_the_rock_life_lists_it_after_the_glinters_and_30_m_from_every_other_home():
	var checked := 0
	for i in _veined.size():
		var data := _veined_details[i]
		var all := RockLife.groups(_veined[i], data, SEED)
		var species: Array = all.map(func(g: Dictionary) -> StringName: return g["species"])
		assert_has(species, &"delver", "RockLife finds the recipe by name")
		for k in all.size():
			assert_eq(int(all[k]["index"]), k, "numbers run on")
			if all[k]["species"] != &"delver":
				continue
			for other in all:
				if other == all[k]:
					continue
				assert_gte(data.surface_point(all[k]["home_dir"]).distance_to(data.surface_point(other["home_dir"])),
					RockLife.SPACING, "a Delver 30 m from a %s group" % other["species"])
				checked += 1
	assert_gt(checked, 0)

func test_delver_records_are_named_numbered_and_homed():
	var data := _veined_details[0]
	var all := RockLife.groups(_veined[0], data, SEED)
	var recs := RockLife.records(_veined[0], data, SEED, all)
	var found := 0
	for r in recs:
		if r.species != &"delver":
			continue
		found += 1
		assert_true(String(r.id).begins_with("delver:%s:" % RockHerds.site_of(_veined[0])), String(r.id))
		assert_true(r.home.is_equal_approx(data.surface_point(RockLife.member_dirs(all[r.herd], data)[0])))
	assert_eq(found, 1)

func test_round_near_is_a_round_about_a_direction_on_any_rock():
	for i in _rocks.size():
		var data := _details[i]
		var dir := Vector3(0.3, 0.8, -0.5).normalized()
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var round := DelverBurrows.round_near(data, dir, rng)
		assert_between(round.size(), DelverBurrows.POINTS.x, DelverBurrows.POINTS.y)
		assert_eq(round[0], dir, "the first point is where it was put")
		for a in round.size():
			assert_lte(round[a].angle_to(dir), 0.5 + 0.001, "within 0.5 rad of it")
			for b in range(a + 1, round.size()):
				assert_gte(data.surface_point(round[a]).distance_to(data.surface_point(round[b])), 15.0 - 0.001)

# --- the site hands the mind its round ----------------------------------------------

func _site(i: int) -> RockSite:
	var detail := AsteroidDetail.new()
	detail.rock = _veined[i]
	detail.data = _veined_details[i]
	add_child_autofree(detail)
	return RockSite.new(detail, SEED)

func _delver(site: RockSite) -> NpcRecord:
	for r in site.records:
		if r.species == &"delver":
			return r
	return null

func _ctx(site: RockSite, record: NpcRecord, at: Vector3) -> NpcContext:
	var c := NpcContext.new()
	c.record = record
	c.position = at
	site._fill_delver(c, record)
	return c

func test_the_site_offers_the_round_the_crystal_and_the_next_burrow():
	var site := _site(0)
	var record := _delver(site)
	assert_not_null(record, "the rock has a Delver")
	var g := site.group_of(record)
	var points: Array[Vector3] = []
	for d: Vector3 in g["burrows"]:
		points.append(site.data.surface_point(d))
	var here := points[2] + Vector3(0.2, 0.0, 0.1)
	var c := _ctx(site, record, here)
	assert_eq(c.extra[&"burrows"], points, "the round, as site-local points")
	assert_eq(c.places[&"crystal"], points[2], "the crystal is the point it is nearest")
	assert_eq(c.places[&"burrow"], points[3], "and the burrow the next round")
	var last := _ctx(site, record, points[points.size() - 1])
	assert_eq(last.places[&"burrow"], points[0], "the round comes back to the start")

func test_the_cycle_is_3_to_6_minutes_and_its_own():
	var site := _site(0)
	var record := _delver(site)
	var c := _ctx(site, record, Vector3.ZERO)
	var cycle: float = c.extra[&"cycle"]
	assert_between(cycle, DelverBurrows.CYCLE.x, DelverBurrows.CYCLE.y)
	assert_eq(_ctx(site, record, Vector3.ZERO).extra[&"cycle"], cycle, "the same every think")
	var seen := {}
	for seed in 12:
		var other := NpcRecord.make(&"delver:x:%d" % seed, &"delver", site.id, Vector3.ZERO, seed * 7919, record.herd)
		seen[snappedf(_ctx(site, other, Vector3.ZERO).extra[&"cycle"], 0.001)] = true
	assert_gt(seen.size(), 6, "a seed picks its own")

func test_a_dev_delver_gets_a_round_wherever_it_is_put():
	var site := _site(0)
	var dir := Vector3(0.1, -0.9, 0.3).normalized()
	var ids: Array[StringName] = [&"dev:delver:1"]
	var made := site.add_group(&"delver", dir, 1, ids)
	assert_eq(made.size(), 1)
	var g := site.group_of(made[0])
	assert_true(g.has("burrows"), "a dev group has a round")
	assert_between((g["burrows"] as Array).size(), 6, 10)
	var c := _ctx(site, made[0], site.data.surface_point(dir))
	assert_true(c.places.has(&"crystal") and c.places.has(&"burrow"))
	var skitters: Array[StringName] = [&"dev:skitter:1"]
	site.add_group(&"skitter", dir, 1, skitters)
	assert_false(site.group_of(NpcRecord.make(&"dev:skitter:1", &"skitter", site.id, Vector3.ZERO, 1, RockSite.DEV_FIRST + 1)).has("burrows"),
		"only a Delver's group has one")

func test_a_group_with_no_round_offers_nothing():
	var site := _site(0)
	var record := NpcRecord.make(&"delver:stray", &"delver", site.id, Vector3.ZERO, 3, 9999)
	var c := _ctx(site, record, Vector3.ZERO)
	assert_false(c.places.has(&"crystal"))
	assert_false(c.places.has(&"burrow"))
	assert_false(c.extra.has(&"burrows"))
