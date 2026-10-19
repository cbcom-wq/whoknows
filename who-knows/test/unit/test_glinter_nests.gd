extends GutTest

## Glinter nests on the big rocks (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §3.1, §4.1): about a third of rocks
## have one, on a crater floor, 3-5 Glinters among 2-4 real salvage items of
## the mix, 30 m clear of everything else and the same every time.

const T := AsteroidRecipe.Tier
const SEED := 1337
const ROCKS := 60

var _rocks: Array[AsteroidRock] = []
var _details: Array[RockDetail] = []

func before_all():
	RockMesh.warm()
	var recipe := AsteroidRecipe.new(SEED)
	var x := 0
	while _rocks.size() < ROCKS and x < 20000:
		var found := recipe.cell_rocks(T.GIANT, Vector3i(x, 3, -2))
		if not found.is_empty():
			_rocks.append(found[0])
			_details.append(RockDetail.build(found[0], SEED))
		x += 1

func _nests(i: int) -> Array[Dictionary]:
	return GlinterNests.groups(_rocks[i], _details[i], SEED, [] as Array[Vector3], 0)

func _all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in _rocks.size():
		for g in _nests(i):
			g["rock"] = i
			out.append(g)
	return out

func test_the_numbers_are_the_specs():
	assert_eq(GlinterNests.SPECIES, &"glinter")
	assert_eq(GlinterNests.SALT, 13)
	assert_almost_eq(GlinterNests.CHANCE, 1.0 / 3.0, 0.0001)
	assert_eq(GlinterNests.MEMBERS, Vector2i(3, 5))
	assert_eq(GlinterNests.SALVAGE, Vector2i(2, 4))
	assert_eq(GlinterNests.SPREAD, 3.0)
	assert_eq(GlinterNests.GAP, 1.0)

func test_we_found_cratered_rocks_to_try():
	assert_eq(_rocks.size(), ROCKS)
	for d in _details:
		assert_gt(d.craters.size(), 0, "a cratered rock")

func test_about_a_third_of_cratered_rocks_have_a_nest():
	var nests := _all()
	assert_between(nests.size(), 10, 30, "%d nests on %d rocks" % [nests.size(), _rocks.size()])
	for i in _rocks.size():
		assert_lte(_nests(i).size(), 1, "never more than one to a rock")

func test_a_nest_sits_on_a_crater_floor():
	for g in _all():
		var data := _details[g["rock"]]
		assert_eq(g["species"], &"glinter")
		var crater: int = g["crater"]
		assert_between(crater, 0, data.craters.size() - 1)
		assert_eq(g["home_dir"], data.craters[crater][0], "its home is the crater's centre")

func test_a_nest_holds_3_to_5_glinters_and_2_to_4_items_of_the_mix():
	var mix := []
	for m in SalvageField.MIX:
		mix.append(m[0])
	var kinds := {}
	for g in _all():
		var data := _details[g["rock"]]
		assert_between(int(g["count"]), 3, 5)
		assert_eq(GlinterNests.member_dirs(g, data).size(), int(g["count"]))
		var salvage: Array = g["salvage"]
		assert_between(salvage.size(), 2, 4)
		for k in salvage.size():
			var e: Dictionary = salvage[k]
			assert_eq(int(e["index"]), k, "indexed in order")
			assert_has(mix, e["kind"])
			kinds[e["kind"]] = true
			assert_between(float(e["variety"]), 0.0, 0.9999)
			assert_almost_eq((e["dir"] as Vector3).length(), 1.0, 0.001, "a direction")
	assert_gte(kinds.size(), 4, "the items are drawn from the whole mix")

func test_the_same_rock_gives_the_same_nest():
	for i in _rocks.size():
		var a := _nests(i)
		var b := _nests(i)
		assert_eq(a.size(), b.size())
		for j in a.size():
			assert_eq(a[j]["home_dir"], b[j]["home_dir"])
			assert_eq(a[j]["seed"], b[j]["seed"])
			assert_eq(a[j]["salvage"], b[j]["salvage"])
			assert_eq(GlinterNests.member_dirs(a[j], _details[i]), GlinterNests.member_dirs(b[j], _details[i]))

func test_numbering_carries_on_from_the_index_given():
	for g in _all():
		assert_eq(int(g["index"]), 0)
	for i in _rocks.size():
		for g in GlinterNests.groups(_rocks[i], _details[i], SEED, [] as Array[Vector3], 7):
			assert_eq(int(g["index"]), 7)

func test_nests_keep_30_m_from_skitter_herds():
	var nests := 0
	for i in _rocks.size():
		var all := RockLife.groups(_rocks[i], _details[i], SEED)
		var homes: Array[Vector3] = []
		for g in all:
			if g["species"] == &"skitter":
				homes.append(g["home_dir"])
		for g in all:
			if g["species"] != &"glinter":
				continue
			nests += 1
			for h in homes:
				assert_gte(_details[i].surface_point(g["home_dir"]).distance_to(_details[i].surface_point(h)), 30.0,
					"a nest on rock %d is within 30 m of a herd" % i)
	assert_gt(nests, 0, "some rock has a nest")

func test_a_nest_given_every_crater_taken_is_not_made():
	for i in _rocks.size():
		var taken: Array[Vector3] = []
		for c in _details[i].craters:
			taken.append(c[0])
		assert_eq(GlinterNests.groups(_rocks[i], _details[i], SEED, taken, 0).size(), 0,
			"no clear crater, no nest")

func test_glinters_and_items_keep_apart():
	for g in _all():
		var data := _details[g["rock"]]
		var points: Array[Vector3] = []
		for d in GlinterNests.member_dirs(g, data):
			points.append(data.surface_point(d))
		for e: Dictionary in g["salvage"]:
			points.append(data.surface_point(e["dir"]))
		var home := data.surface_point(g["home_dir"])
		for a in points.size():
			assert_lte(points[a].distance_to(home), GlinterNests.SPREAD + 0.01, "they lie about the nest")
			for b in range(a + 1, points.size()):
				assert_gte(points[a].distance_to(points[b]), GlinterNests.GAP - 0.001,
					"two things %.2f m apart in a nest" % points[a].distance_to(points[b]))

func test_every_member_gets_a_record_in_the_ecology():
	var n := 0
	for i in _rocks.size():
		var all := RockLife.groups(_rocks[i], _details[i], SEED)
		var records := RockLife.records(_rocks[i], _details[i], SEED, all)
		for g in all:
			if g["species"] != &"glinter":
				continue
			var mine := records.filter(func(r: NpcRecord) -> bool: return r.herd == g["index"])
			assert_eq(mine.size(), int(g["count"]))
			for r: NpcRecord in mine:
				assert_eq(r.species, &"glinter")
				assert_true(String(r.id).begins_with("glinter:"), "%s" % r.id)
				n += 1
	assert_gt(n, 0)
