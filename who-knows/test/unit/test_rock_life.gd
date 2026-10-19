extends GutTest

## One rock, one ecology (rock creatures spec §3.1): every group of every
## species from one recipe, the skitters exactly as before.

const T := AsteroidRecipe.Tier
const GOLDEN := "res://test/unit/golden/rock_life_skitters.json"

var _rocks: Array[AsteroidRock] = []
var _details: Array[RockDetail] = []

func before_all():
	RockMesh.warm()
	var recipe := AsteroidRecipe.new(1337)
	for x in 600:
		var found := recipe.cell_rocks(T.GIANT, Vector3i(x, 3, -2))
		if not found.is_empty():
			_rocks.append(found[0])
			_details.append(RockDetail.build(found[0], 1337))
		if _rocks.size() >= 6:
			break

func _rock(world_seed: int, at: Array) -> AsteroidRock:
	return AsteroidRecipe.new(world_seed).cell_rocks(T.GIANT, Vector3i(int(at[0]), int(at[1]), int(at[2])))[int(at[3])]

func test_skitter_records_match_the_golden_file():
	var golden: Array = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	assert_gte(golden.size(), 10, "the golden file covers many rocks")
	for entry: Dictionary in golden:
		var rock := _rock(int(entry["seed"]), entry["rock"])
		var data := RockDetail.build(rock, int(entry["seed"]))
		var skitters := RockLife.records(rock, data, int(entry["seed"])).filter(
			func(r: NpcRecord) -> bool: return r.species == &"skitter")
		assert_eq(skitters.size(), (entry["records"] as Array).size())
		for i in skitters.size():
			var want: Dictionary = entry["records"][i]
			assert_eq(String(skitters[i].id), want["id"])
			assert_almost_eq(skitters[i].home, Vector3(want["home"][0], want["home"][1], want["home"][2]), Vector3.ONE * 0.0001)
			assert_eq(skitters[i].seed, int(want["seed"]))
			assert_eq(skitters[i].herd, int(want["herd"]))

func test_the_same_rock_gives_the_same_life():
	for i in _rocks.size():
		var a := RockLife.records(_rocks[i], _details[i], 1337)
		var b := RockLife.records(_rocks[i], _details[i], 1337)
		assert_eq(a.size(), b.size())
		for j in a.size():
			assert_eq(a[j].id, b[j].id)
			assert_eq(a[j].home, b[j].home)
			assert_eq(a[j].seed, b[j].seed)

func test_ids_are_unique_and_groups_number_on_across_species():
	var seen := {}
	for i in _rocks.size():
		var all := RockLife.groups(_rocks[i], _details[i], 1337)
		var skitters := 0
		for g in all:
			if g["species"] == &"skitter":
				assert_eq(int(g["index"]), skitters, "skitter groups number from 0")
				skitters += 1
		var indices := {}
		for g in all:
			assert_false(indices.has(g["index"]), "group %d twice" % g["index"])
			indices[g["index"]] = true
			if g["species"] != &"skitter":
				assert_gte(int(g["index"]), skitters, "later species continue the numbering")
		for r in RockLife.records(_rocks[i], _details[i], 1337):
			assert_false(seen.has(r.id), "%s twice" % r.id)
			seen[r.id] = true
	assert_gt(seen.size(), 0, "some rock has creatures")

## A record's home is the surface point of its member direction. (Not of its own
## direction from the centre: the rock is stretched, so the two differ.)
func test_every_home_lies_on_the_surface():
	var n := 0
	for i in _rocks.size():
		var all := RockLife.groups(_rocks[i], _details[i], 1337)
		var recs := RockLife.records(_rocks[i], _details[i], 1337, all)
		var at := 0
		for g in all:
			for d in RockLife.member_dirs(g, _details[i]):
				assert_true(_details[i].surface_point(d).is_equal_approx(recs[at].home), "%s on the surface" % recs[at].id)
				at += 1
				n += 1
		assert_eq(at, recs.size())
	assert_gt(n, 0)
func test_clear_of_measures_surface_metres():
	var d := _details[0]
	var here := Vector3.UP
	assert_true(RockLife.clear_of(d, here, [] as Array[Vector3]), "nothing taken is always clear")
	assert_false(RockLife.clear_of(d, here, [here] as Array[Vector3]), "a taken home is not clear of itself")
	var far := d.surface_point(here).distance_to(d.surface_point(-here))
	assert_true(RockLife.clear_of(d, here, [-here] as Array[Vector3], far - 1.0))
	assert_false(RockLife.clear_of(d, here, [-here] as Array[Vector3], far + 1.0))

func test_a_site_keeps_every_group_and_each_records_direction():
	for i in _rocks.size():
		var site := RockSite.new(_details_as_detail(i), 1337)
		var all := RockLife.groups(_rocks[i], _details[i], 1337)
		assert_eq(site.groups.size(), all.size())
		for j in all.size():
			assert_eq(int(site.groups[j]["index"]), int(all[j]["index"]))
			assert_eq(site.groups[j]["species"], all[j]["species"])
		for r in site.records:
			assert_true(site.dirs.has(r.id), "%s has a direction" % r.id)
			assert_true(site.data.surface_point(site.dirs[r.id]).is_equal_approx(r.home), "%s's direction gives its home" % r.id)

## RockDetail.dir_of undoes surface_point: the rock is stretched, so
## `p.normalized()` would be wrong by tens of metres.
func test_dir_of_is_the_inverse_of_surface_point():
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for data in _details:
		for k in 60:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			assert_lt(data.dir_of(data.surface_point(d)).distance_to(d), 1e-4)

func _details_as_detail(i: int) -> AsteroidDetail:
	var detail: AsteroidDetail = autofree(AsteroidDetail.new())
	detail.rock = _rocks[i]
	detail.data = _details[i]
	return detail
