extends GutTest

## Wadoo's cast, site and source (docs/superpowers/specs/2026-11-16-wadoo-design.md §4,
## §5, §12) on the real oasis layout: twenty-five people with stable ids, homes they
## can reach, a spot for every job on open ground, spots one person holds at a time,
## and each wakes standing on the ground where their day has them.

const POOL_RADIUS := 11.0
const SLOPE := 0.02
const NOT_HOMES := ["home_5", "hut_8", "hut_9", "workshop", "comms", "store"]

class FakePlaces extends PlaceField:
	var node: Node3D

	func loaded(_id: StringName) -> Node3D:
		return node

var _layout: Dictionary
var _node: Node3D
var _site: WadooSite

func before_all():
	_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))

func before_each():
	_node = Node3D.new()
	add_child_autofree(_node)
	_node.global_transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(500.0, 20.0, -100.0))
	_site = WadooSite.new(_node, _layout, POOL_RADIUS,
		func(e: float, n: float) -> Vector3: return Vector3(e, SLOPE * e, -n))

func _hub() -> Vector2:
	return _site.paths.nearest_open(Vector2(14.0, 10.0))

func _reaches(to: Vector3) -> bool:
	var r := _site.route(_hub(), WadooSite.flat(to))
	return not r.is_empty() and r[r.size() - 1].distance_to(WadooSite.flat(to)) < 0.3

func test_twenty_five_with_stable_ids():
	var a := WadooCast.records(_layout)
	var b := WadooCast.records(_layout)
	assert_eq(a.size(), 25)
	var seen := {}
	for n in a.size():
		assert_eq(a[n].id, StringName("wadee:wadoo:%d" % n))
		assert_eq(a[n].seed, b[n].seed, "the same seed every time")
		assert_eq(a[n].site, &"wadoo")
		assert_eq(WadooCast.index_of(a[n].id), n)
		seen[a[n].id] = true
	assert_eq(seen.size(), 25)
	assert_eq(WadooCast.index_of(&"skitter:rock:1:2"), -1)

func test_roles_and_species():
	var count := {}
	var women := 0
	var men := 0
	for n in WadooCast.count():
		var p := WadooCast.person(n)
		count[p["role"]] = count.get(p["role"], 0) + 1
		assert_eq(WadooCast.record(n, _layout).species, WadooCast.species_of(p["role"]))
		assert_eq(p["staff"], p["role"] == &"sunguard", "only the Sunguard carry staffs")
		if p["role"] == &"villager":
			if p["model"] in ["a", "b", "c"]:
				women += 1
			elif p["model"] in ["m", "n"]:
				men += 1
	assert_eq(count, {&"queen": 1, &"sunguard": 5, &"villager": 19})
	assert_eq(women, 15)
	assert_eq(men, 4)
	assert_eq(WadooCast.person(0)["title"], "Queen Imsa")

func test_homes_are_houses():
	for n in WadooCast.count():
		var p := WadooCast.person(n)
		assert_false(p["home"] in NOT_HOMES, "%s lives in a house, not %s" % [p["name"], p["home"]])
		var door := _site.door_of(p["home"])
		assert_false(door.is_empty(), "%s's home has a door" % p["name"])
		assert_true(_reaches(door["at"]), "%s can walk home" % p["name"])
		assert_ne(WadooCast.record(n, _layout).home, Vector3.ZERO)

func test_spots_open():
	for kind: StringName in WadooSite.SPOT_KINDS:
		assert_gt(_site.spots(kind).size(), 0, "there is somewhere to %s" % kind)
		for s: Dictionary in _site.spots(kind):
			var at: Vector3 = s["at"]
			if kind != &"shade":
				assert_true(_site.open(WadooSite.flat(at)), "%s stands on open ground" % s["key"])
			assert_true(_reaches(at), "%s can be walked to" % s["key"])
			assert_almost_eq(at.y, SLOPE * at.x, 0.001, "%s is on the ground" % s["key"])
	assert_eq(_site.spots(&"memorial").size(), 6)
	assert_eq(_site.spots(&"shade").size(), 12, "two seats on each of six benches")
	for key in ["post:gate", "post:breach", "post:pool", "post:queen_door", "post:breach_walk:0",
			"post:breach_walk:1"]:
		assert_false(_site.spot(&"post", key).is_empty(), key)

func test_every_job_has_spots():
	for n in WadooCast.count():
		for job: String in WadooCast.person(n)["jobs"]:
			assert_gt(_site.spots(StringName(job)).size(), 0, job)

func test_claims_are_exclusive():
	assert_true(_site.claim("pump:0", &"a"))
	assert_false(_site.claim("pump:0", &"b"), "held by another")
	assert_true(_site.claim("pump:1", &"a"), "one at a time: a lets go of pump:0")
	assert_true(_site.claim("pump:0", &"b"))
	for i in 3:
		var s := _site.take_spot(&"pump", StringName("p%d" % i), Vector3.ZERO, i)
		if not s.is_empty():
			assert_eq(_site.holder_of(s["key"]), StringName("p%d" % i))
	assert_true(_site.take_spot(&"pump", &"late", Vector3.ZERO, 0).is_empty(), "every pump spot is held")
	_site.release(&"a")
	assert_false(_site.take_spot(&"pump", &"late", Vector3.ZERO, 0).is_empty())

func test_pairs_end_for_both():
	_site._pairs[&"x"] = {"partner": &"y", "at": Vector3.ZERO, "face": Vector3.ONE}
	_site._pairs[&"y"] = {"partner": &"x", "at": Vector3.ONE, "face": Vector3.ZERO}
	assert_eq(_site.pair_of(&"x")["partner"], &"y")
	_site.end_pair(&"y")
	assert_true(_site.pair_of(&"x").is_empty())

func test_records_only_while_loaded():
	var places := FakePlaces.new()
	add_child_autofree(places)
	var source := WadooSource.new(places)
	var director := NpcDirector.new()
	autofree(director)
	assert_eq(source.records(director).size(), 0, "nothing while the oasis is not loaded")
	places.node = _node
	source.site = _site
	var out := source.records(director)
	assert_eq(out.size(), 25)
	assert_eq(out[0][1], _site)
	assert_eq(_site.director, director)
	places.node = null
	assert_eq(source.records(director).size(), 0)
	assert_null(source.site, "the site goes with the place")

func test_start_pose_on_a_spot():
	for n in WadooCast.count():
		var r := WadooCast.record(n, _layout)
		var p := WadooCast.person(n)
		for time in [0.0, 600.0, 3000.0]:
			var pose := _site.start_pose(r, time)
			var at := WadooSite.flat(pose.origin)
			assert_true(_site.open(at), "%s wakes on open ground" % p["name"])
			assert_almost_eq(pose.origin.y, SLOPE * pose.origin.x, 0.001, "%s wakes on the ground" % p["name"])
			assert_almost_eq(pose.basis.y.dot(Vector3.UP), 1.0, 0.001, "and upright")
		if p["role"] == &"sunguard":
			var key := "post:%s" % p["post"]
			var post := _site.spot(&"post", key)
			if post.is_empty():
				post = _site.spot(&"post", key + ":0")
			assert_lt(WadooSite.flat(_site.start_pose(r, 0.0).origin).distance_to(WadooSite.flat(post["at"])), 0.01,
				"%s wakes at the post" % p["name"])

func test_ground_bilinear():
	var at := _site.ground(Vector2(3.3, -2.7))
	assert_almost_eq(at.y, SLOPE * 3.3, 0.0001)
	assert_almost_eq(at.x, 3.3, 0.0001)
	assert_almost_eq(at.z, 2.7, 0.0001)

func test_up_is_away_from_the_middle():
	var curved := WadooSite.new(_node, _layout, POOL_RADIUS,
		func(e: float, n: float) -> Vector3: return Vector3(e, 0.0, -n), Vector3(0.0, -1000.0, 0.0))
	assert_almost_eq(curved.up_at(Vector3(0, 0, 0)).dot(Vector3.UP), 1.0, 0.0001)
	assert_gt(curved.up_at(Vector3(100, 0, 0)).x, 0.09, "tilted away 100 m east")

## Wadoo spec §7: once the sun pump is fitted Halla's dry garden is a garden again
## (its spots are garden spots, worked as the others are).
func test_the_dry_garden_is_a_garden_once_the_pump_works():
	var state := WadooState.new()
	_site.state = state
	assert_eq(_site.spots(&"dry").size(), 4, "Halla grieves at the dead garden")
	var gardens := _site.spots(&"garden").size()
	state.do_task(&"armlet")
	assert_eq(_site.spots(&"dry").size(), 4, "only the pump greens it")
	state.do_task(&"pump")
	assert_eq(_site.spots(&"dry").size(), 0)
	assert_eq(_site.spots(&"garden").size(), gardens + 4, "she tends it")
	assert_false(_site.spot(&"garden", "garden_dry:0").is_empty())
	_site.state = WadooState.from_dict(state.to_dict())
	assert_eq(_site.spots(&"dry").size(), 0, "a loaded state too")

## Wadoo spec §7: a gift given is worn (Lio's armlet), and she wakes wearing it.
func test_lio_wears_her_armlet_once_given():
	var state := WadooState.new()
	_site.state = state
	var n := -1
	for i in WadooCast.count():
		if WadooCast.PEOPLE[i]["name"] == "Lio":
			n = i
	var record := WadooCast.record(n, _layout)
	assert_false(_site.person(record).has("wears"))
	state.do_task(&"armlet")
	assert_eq(_site.person(record)["wears"], [&"armlet"])
	assert_false(WadooCast.person(n).has("wears"), "the cast itself is untouched")
