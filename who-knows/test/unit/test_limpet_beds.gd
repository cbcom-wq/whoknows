extends GutTest

## Limpet beds on the big rocks (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §3.1, §6): the same beds every time, a
## few to a rock, on the vein of a veined rock and on crater rims elsewhere,
## clear of every other group, and numbered on after the skitters.

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
			if rock.shape == RockMesh.Shape.VEINED and _veined.size() < 5:
				_veined.append(rock)
				_veined_details.append(RockDetail.build(rock, SEED))
		if _rocks.size() < 6:
			var found := recipe.cell_rocks(T.GIANT, Vector3i(x, 3, -2))
			if not found.is_empty():
				_rocks.append(found[0])
				_details.append(RockDetail.build(found[0], SEED))
		if _rocks.size() >= 6 and _veined.size() >= 5:
			break

func _all_rocks() -> Array[AsteroidRock]:
	var out: Array[AsteroidRock] = []
	out.append_array(_rocks)
	out.append_array(_veined)
	return out

func _all_details() -> Array[RockDetail]:
	var out: Array[RockDetail] = []
	out.append_array(_details)
	out.append_array(_veined_details)
	return out

func _beds(i: int) -> Array[Dictionary]:
	return LimpetBeds.groups(_all_rocks()[i], _all_details()[i], SEED, [] as Array[Vector3], 0)

func test_we_found_rocks_to_try():
	assert_eq(_rocks.size(), 6)
	assert_gte(_veined.size(), 3, "some veined rocks")

func test_beds_are_few_and_full():
	var total := 0
	for i in _all_rocks().size():
		var beds := _beds(i)
		assert_between(beds.size(), 0, 2)
		for g in beds:
			total += 1
			assert_between(int(g["count"]), 8, 12)
			assert_eq(LimpetBeds.member_dirs(g, _all_details()[i]).size(), int(g["count"]))
			assert_eq(g["species"], &"limpet")
	assert_gt(total, 0, "some rock has a bed")

func test_the_same_rock_gives_the_same_beds():
	for i in _all_rocks().size():
		var a := _beds(i)
		var b := _beds(i)
		assert_eq(a.size(), b.size())
		for j in a.size():
			assert_eq(a[j]["home_dir"], b[j]["home_dir"])
			assert_eq(a[j]["seed"], b[j]["seed"])
			assert_eq(LimpetBeds.member_dirs(a[j], _all_details()[i]), LimpetBeds.member_dirs(b[j], _all_details()[i]))

func test_on_a_veined_rock_beds_sit_on_the_vein():
	var n := 0
	for i in _veined.size():
		for g in LimpetBeds.groups(_veined[i], _veined_details[i], SEED, [] as Array[Vector3], 0):
			assert_true(RockMesh.in_vein(g["home_dir"]), "a bed on veined rock %d is off the vein" % i)
			n += 1
	assert_gt(n, 0, "some veined rock has a bed")

func test_on_other_rocks_beds_sit_on_crater_rims():
	var n := 0
	for i in _rocks.size():
		for g in LimpetBeds.groups(_rocks[i], _details[i], SEED, [] as Array[Vector3], 0):
			if _rocks[i].shape == RockMesh.Shape.VEINED:
				continue
			var crater: Array = _details[i].craters[g["crater"]]
			assert_almost_eq((crater[0] as Vector3).angle_to(g["home_dir"]), float(crater[1]), 0.001)
			n += 1
	assert_gt(n, 0, "some rock has a bed on a rim")

func test_a_rock_with_no_craters_has_no_beds_unless_veined():
	var bare := RockDetail.build(_rocks[0], SEED)
	bare.craters.clear()
	if _rocks[0].shape != RockMesh.Shape.VEINED:
		assert_eq(LimpetBeds.groups(_rocks[0], bare, SEED, [] as Array[Vector3], 0).size(), 0)

func test_beds_keep_30_m_from_every_other_home():
	var checked := 0
	for i in _all_rocks().size():
		var data := _all_details()[i]
		var all := RockLife.groups(_all_rocks()[i], data, SEED)
		for a in all:
			if a["species"] != &"limpet":
				continue
			for b in all:
				if b == a:
					continue
				var apart := data.surface_point(a["home_dir"]).distance_to(data.surface_point(b["home_dir"]))
				assert_gte(apart, RockLife.SPACING, "a limpet bed %d m from a %s group" % [apart, b["species"]])
				checked += 1
	assert_gt(checked, 0, "some bed has a neighbour to keep clear of")

func test_a_bed_avoids_homes_it_is_told_are_taken():
	var tried := 0
	for i in _veined.size():
		var free := LimpetBeds.groups(_veined[i], _veined_details[i], SEED, [] as Array[Vector3], 0)
		if free.is_empty():
			continue
		var taken: Array[Vector3] = [free[0]["home_dir"]]
		for g in LimpetBeds.groups(_veined[i], _veined_details[i], SEED, taken, 0):
			assert_true(RockLife.clear_of(_veined_details[i], g["home_dir"], taken))
		tried += 1
	assert_gt(tried, 0, "some veined rock has a bed to move")

func test_adding_limpets_leaves_the_skitters_alone():
	for i in _all_rocks().size():
		var rock := _all_rocks()[i]
		var data := _all_details()[i]
		var mine := RockLife.records(rock, data, SEED).filter(
			func(r: NpcRecord) -> bool: return r.species == &"skitter")
		var theirs := RockHerds.records(rock, data, SEED)
		assert_eq(mine.size(), theirs.size())
		for j in mine.size():
			assert_eq(mine[j].id, theirs[j].id)
			assert_eq(mine[j].home, theirs[j].home)
			assert_eq(mine[j].seed, theirs[j].seed)
			assert_eq(mine[j].herd, theirs[j].herd)

## The records the rock life makes for a bed are ids with the group's number,
## `herd` that number, and homes at the surface point of each member direction;
## the beds' numbers carry on after the skitters'.
func test_limpet_records_are_named_numbered_and_homed():
	var checked := 0
	for i in _all_rocks().size():
		var rock := _all_rocks()[i]
		var data := _all_details()[i]
		var all := RockLife.groups(rock, data, SEED)
		var recs := RockLife.records(rock, data, SEED, all)
		var site := RockHerds.site_of(rock)
		var skitter_groups := 0
		for g in all:
			if g["species"] == &"skitter":
				skitter_groups += 1
		var at := 0
		for k in all.size():
			var g := all[k]
			var dirs := RockLife.member_dirs(g, data)
			if g["species"] == &"limpet":
				assert_eq(int(g["index"]), k, "numbers run on in order")
				assert_gte(int(g["index"]), skitter_groups, "after the skitters")
				for m in dirs.size():
					var r := recs[at + m]
					assert_eq(String(r.id), "limpet:%s:%d:%d" % [site, g["index"], m])
					assert_eq(r.species, &"limpet")
					assert_eq(r.site, site)
					assert_eq(r.herd, int(g["index"]))
					assert_true(r.home.is_equal_approx(data.surface_point(dirs[m])), "%s on the surface" % r.id)
					assert_lt(data.dir_of(r.home).distance_to(dirs[m]), 1e-3, "%s keeps its direction" % r.id)
					checked += 1
			at += dirs.size()
		assert_eq(at, recs.size())
	assert_gt(checked, 0)

func test_members_lie_close_round_their_bed():
	var n := 0
	for i in _all_rocks().size():
		for g in _beds(i):
			var home := _all_details()[i].surface_point(g["home_dir"])
			for d in LimpetBeds.member_dirs(g, _all_details()[i]):
				assert_lt(_all_details()[i].surface_point(d).distance_to(home), LimpetBeds.SPREAD * 1.6)
				n += 1
	assert_gt(n, 0)

## A drill (RockLifeSource.quiet) clears what is shy of it: a rock's skitters,
## not its limpets, which are drawn to it (§3.2, §6.3).
func test_a_drill_does_not_clear_limpets():
	var pick := -1
	for i in _all_rocks().size():
		var species := {}
		for g in RockLife.groups(_all_rocks()[i], _all_details()[i], SEED):
			species[g["species"]] = true
		if species.has(&"skitter") and species.has(&"limpet"):
			pick = i
			break
	assert_ne(pick, -1, "some rock has skitters and a limpet bed")
	var detail: AsteroidDetail = AsteroidDetail.new()
	detail.rock = _all_rocks()[pick]
	detail.data = _all_details()[pick]
	add_child_autofree(detail)
	var stream: AsteroidStream = autofree(AsteroidStream.new())
	stream.details = AsteroidDetails.new(stream, null)
	stream.details.live[detail.rock.id()] = detail
	var anchor := Node3D.new()
	anchor.add_to_group(AsteroidStream.SPACE_ANCHOR)
	add_child_autofree(anchor)
	var director := NpcDirector.new()
	add_child_autofree(director)
	var source := RockLifeSource.new(stream, NpcCatalog.load_from_dir("res://data/npcs"))
	var calm := _species_offered(source.records(director))
	assert_true(calm.has(&"skitter") and calm.has(&"limpet"), "with no drill, both are offered")
	var drilled := RockLifeSource.new(stream, NpcCatalog.load_from_dir("res://data/npcs"))
	var asked := [0]
	drilled.quiet = func(_site: StringName, _point: Vector3) -> bool:
		asked[0] += 1
		return true
	var offered := _species_offered(drilled.records(director))
	assert_true(offered.has(&"limpet"), "a drill does not clear the limpets")
	assert_false(offered.has(&"skitter"), "it clears the skitters")
	assert_eq(asked[0], RockLife.records(detail.rock, detail.data, SEED).filter(
		func(r: NpcRecord) -> bool: return r.species == &"skitter").size(), "and is asked only about them")

func _species_offered(pairs: Array) -> Dictionary:
	var out := {}
	for pair in pairs:
		out[(pair[0] as NpcRecord).species] = true
	return out
