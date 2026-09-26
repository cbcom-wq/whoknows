extends GutTest

## Herds on the big rocks (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §4.2, §4.4): the same herds every time,
## on the surface, on crater walls, walking their rounds.

const T := AsteroidRecipe.Tier

var _recipe: AsteroidRecipe
var _rocks: Array[AsteroidRock] = []
var _details: Array[RockDetail] = []

func before_all():
	RockMesh.warm()
	_recipe = AsteroidRecipe.new(1337)
	for x in 600:
		var found := _recipe.cell_rocks(T.GIANT, Vector3i(x, 3, -2))
		if not found.is_empty():
			_rocks.append(found[0])
			_details.append(RockDetail.build(found[0], 1337))
		if _rocks.size() >= 6:
			break

func test_the_same_rock_gives_the_same_skitters():
	var a := RockHerds.records(_rocks[0], _details[0], 1337)
	var b := RockHerds.records(_rocks[0], _details[0], 1337)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].id, b[i].id)
		assert_eq(a[i].home, b[i].home)
		assert_eq(a[i].seed, b[i].seed)

func test_ids_are_unique_and_name_their_rock():
	var seen := {}
	for i in _rocks.size():
		for r in RockHerds.records(_rocks[i], _details[i], 1337):
			assert_false(seen.has(r.id), "%s twice" % r.id)
			seen[r.id] = true
			assert_eq(r.site, RockHerds.site_of(_rocks[i]))
			assert_true(String(r.id).begins_with("skitter:" + String(r.site)))
	assert_gt(seen.size(), 0, "some rock has skitters")

func test_herds_are_few_and_small():
	for i in _rocks.size():
		var herds := RockHerds.herds(_rocks[i], _details[i], 1337)
		assert_between(herds.size(), 0, 3)
		for h in herds:
			assert_between(int(h["count"]), 3, 7)
			assert_between((h["round_dirs"] as Array).size(), 3, 5)
			assert_between(float(h["period"]), 1200.0, 2400.0)

func test_homes_lie_on_the_surface_near_their_herd():
	for i in _rocks.size():
		var herds := RockHerds.herds(_rocks[i], _details[i], 1337)
		var recs := RockHerds.records(_rocks[i], _details[i], 1337, herds)
		var n := 0
		for h in herds:
			var dirs := RockHerds.member_dirs(h, _details[i])
			for d in dirs:
				var r := recs[n]
				n += 1
				assert_true(_details[i].surface_point(d).is_equal_approx(r.home), "%s on the surface" % r.id)
				var home := _details[i].surface_point(h["home_dir"])
				assert_lt(home.distance_to(r.home), RockHerds.HUDDLE * 2.0, "%s strayed from its herd" % r.id)
		assert_eq(n, recs.size())

func test_herds_live_on_crater_walls():
	for i in _rocks.size():
		for h in RockHerds.herds(_rocks[i], _details[i], 1337):
			var crater: Array = _details[i].craters[h["crater"]]
			var angle := (crater[0] as Vector3).angle_to(h["home_dir"])
			assert_almost_eq(angle, float(crater[1]) * RockHerds.WALL, 0.001)

func test_a_rock_with_no_craters_has_no_herds():
	var bare := RockDetail.build(_rocks[0], 1337)
	bare.craters.clear()
	assert_eq(RockHerds.herds(_rocks[0], bare, 1337).size(), 0)

func test_a_round_starts_at_home_and_moves():
	var h := {}
	for i in _rocks.size():
		var herds := RockHerds.herds(_rocks[i], _details[i], 1337)
		if not herds.is_empty():
			h = herds[0]
			break
	assert_false(h.is_empty())
	assert_true(RockHerds.round_dir(h, 0.0).is_equal_approx(h["home_dir"]))
	assert_true(RockHerds.round_dir(h, 123.0).is_equal_approx(RockHerds.round_dir(h, 123.0)))
	assert_false(RockHerds.round_dir(h, float(h["period"]) * 0.3).is_equal_approx(h["home_dir"]))
	assert_true(RockHerds.round_dir(h, float(h["period"])).is_equal_approx(h["home_dir"]), "a round comes back")

func test_the_surface_normal_points_out():
	var d := Vector3(0.3, 0.8, -0.5).normalized()
	var n := RockHerds.surface_normal(_details[0], d)
	assert_almost_eq(n.length(), 1.0, 0.001)
	assert_gt(n.dot(d), 0.3)
