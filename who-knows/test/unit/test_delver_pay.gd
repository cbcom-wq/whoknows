extends GutTest

## What a Delver pays (docs/superpowers/specs/2026-10-10-rock-creatures-design.md
## §5.4): 2-4 grit at each surfacing and about one time in twelve a shard, with
## a cap on both near the rock; a dead one leaves a shard and six grit, so
## following it beats shooting it. Run on a live Delver on a veined rock, with
## the flight scene's drop and count Callables stood in for by spies.

const T := AsteroidRecipe.Tier
const SEED := 1337

var _rock: AsteroidRock
var _data: RockDetail
var _site: RockSite
var _npc: Npc
## [kind, at, up, count], in the order they were asked for.
var _drops: Array = []
## What the stub says lies near the rock: kind -> how many.
var _near := {}
## [kind, at, radius] of each count asked for.
var _asked: Array = []

func before_all():
	RockMesh.warm()
	var recipe := AsteroidRecipe.new(SEED)
	for x in 3000:
		for rock in recipe.cell_rocks(T.GIANT, Vector3i(x, 3, -2)):
			if rock.shape == RockMesh.Shape.VEINED and _rock == null:
				_rock = rock
				_data = RockDetail.build(rock, SEED)
		if _rock != null:
			break

func before_each():
	_drops.clear()
	_asked.clear()
	_near = {}
	var detail := AsteroidDetail.new()
	detail.rock = _rock
	detail.data = _data
	add_child_autofree(detail)
	_site = RockSite.new(detail, SEED)
	_site.drop = func(kind: StringName, at: Vector3, up: Vector3, count: int) -> void:
		_drops.append([kind, at, up, count])
	_site.count_near = func(kind: StringName, at: Vector3, radius: float) -> int:
		_asked.append([kind, at, radius])
		return int(_near.get(kind, 0))
	var record: NpcRecord = null
	for r in _site.records:
		if r.species == &"delver":
			record = r
	assert_not_null(record, "the veined rock has a Delver")
	var catalog := NpcCatalog.load_from_dir("res://data/npcs")
	_npc = Npc.new()
	add_child_autofree(_npc)
	_npc.setup(record, catalog.get_def(&"delver"), _site, false, _site.start_pose(record, 0.0))

## Every drop of `kind` so far, as the counts.
func _counts(kind: StringName) -> Array[int]:
	var out: Array[int] = []
	for d in _drops:
		if d[0] == kind:
			out.append(d[3])
	return out

func _sum(counts: Array[int]) -> int:
	var n := 0
	for c in counts:
		n += c
	return n

func test_each_surfacing_leaves_2_to_4_grit():
	var seen := {}
	for i in 60:
		_drops.clear()
		_site.surfaced(_npc)
		var grit := _counts(&"crystal_grit")
		assert_eq(grit.size(), 1, "one drop of grit a surfacing")
		assert_between(grit[0], RockSite.GRIT.x, RockSite.GRIT.y)
		seen[grit[0]] = true
	assert_eq(seen.keys().size(), 3, "2, 3 and 4 all turn up")

func test_it_leaves_its_pay_just_behind_its_tail_up_its_up():
	_site.surfaced(_npc)
	var d: Array = _drops[0]
	var tail := _npc.global_position + _npc.global_basis.z * 1.5
	assert_almost_eq((d[1] as Vector3).distance_to(tail), RockSite.TAIL_CLEAR, 0.001, "half a metre past its tail, where its body is not")
	assert_gt(((d[1] as Vector3) - _npc.global_position).dot(_npc.global_basis.z), 1.5, "behind it, not beside it")
	assert_almost_eq((d[2] as Vector3).distance_to(_npc.global_basis.y), 0.0, 0.0001, "up its up")

func test_the_same_delver_rolls_the_same_every_time():
	var first: Array[int] = []
	for i in 30:
		_drops.clear()
		_site.surfaced(_npc)
		first.append(_sum(_counts(&"crystal_grit")) * 10 + _sum(_counts(&"quantum_shard")))
	var again := RockSite.new(_site.detail, SEED)
	again.drop = _site.drop
	var second: Array[int] = []
	for i in 30:
		_drops.clear()
		again.surfaced(_npc)
		second.append(_sum(_counts(&"crystal_grit")) * 10 + _sum(_counts(&"quantum_shard")))
	assert_eq(first, second, "a fresh site and the same record: the same luck")

func test_grit_stops_at_8_near_the_rock_and_one_shard_at_a_time():
	_near = {&"crystal_grit": 8, &"quantum_shard": 8}
	for i in 60:
		_site.surfaced(_npc)
	assert_eq(_drops.size(), 0, "8 grit lying near: it drops nothing")
	_near = {&"crystal_grit": 7}
	_site.surfaced(_npc)
	assert_eq(_counts(&"crystal_grit").size(), 1, "7 lying: one more lot")
	_drops.clear()
	# A shard already near: no second one, however often the dice come up.
	_near = {&"crystal_grit": 0, &"quantum_shard": 1}
	for i in 60:
		_site.surfaced(_npc)
	assert_eq(_counts(&"quantum_shard").size(), 0, "no second shard over 60 surfacings")
	assert_eq(_counts(&"crystal_grit").size(), 60, "though the grit goes on")

func test_the_cap_is_counted_about_the_rock_to_its_radius_and_50_m():
	_site.surfaced(_npc)
	var grit: Array = _asked.filter(func(a: Array) -> bool: return a[0] == &"crystal_grit")[0]
	assert_eq(grit[1], _site.frame().origin, "from the rock's centre")
	assert_almost_eq(float(grit[2]), _rock.radius + 50.0, 0.001, "its radius and 50 m")
	assert_almost_eq(_site.cap_radius(), _rock.radius + 50.0, 0.001)

func test_about_one_surfacing_in_12_leaves_a_shard():
	var shards := 0
	for i in 600:
		_site.surfaced(_npc)
	for d in _drops:
		if d[0] == &"quantum_shard":
			assert_eq(d[3], 1, "one at a time")
			shards += 1
	assert_between(shards, 30, 70, "600 surfacings (caps off): about 50 shards")

func test_a_surfacing_with_no_way_to_drop_does_nothing():
	_site.drop = Callable()
	_site.surfaced(_npc)
	assert_eq(_drops.size(), 0)

func test_a_dead_delver_leaves_a_shard_and_six_grit():
	_near = {&"crystal_grit": 8, &"quantum_shard": 8}
	_site.died(_npc)
	assert_eq(_counts(&"quantum_shard"), [1] as Array[int])
	assert_eq(_counts(&"crystal_grit"), [6] as Array[int])
	assert_almost_eq((_drops[0][1] as Vector3).distance_to(_site.behind(_npc)), 0.0, 0.0001, "behind it, as at a surfacing")

func test_a_limpet_still_leaves_its_husks_and_other_surfacings_leave_nothing():
	var limpet := NpcCatalog.load_from_dir("res://data/npcs").get_def(&"limpet")
	var crawler := Npc.new()
	add_child_autofree(crawler)
	crawler.setup(NpcRecord.make(&"limpet:t:0:0", &"limpet", _site.id, _site.data.surface_point(Vector3.UP), 5, 0),
		limpet, _site, false, Transform3D.IDENTITY)
	_site.surfaced(crawler)
	assert_eq(_drops.size(), 0, "only a Delver pays at a surfacing")
	_site.died(crawler)
	assert_eq(_counts(&"limpet_husk"), [1] as Array[int])

func test_drills_keep_delvers_away():
	var stream: AsteroidStream = autofree(AsteroidStream.new())
	stream.details = AsteroidDetails.new(stream, null)
	stream.details.live[_rock.id()] = _site.detail
	var anchor := Node3D.new()
	anchor.add_to_group(AsteroidStream.SPACE_ANCHOR)
	add_child_autofree(anchor)
	anchor.global_position = _site.detail.global_position
	var director := NpcDirector.new()
	add_child_autofree(director)
	var catalog := NpcCatalog.load_from_dir("res://data/npcs")
	var calm := RockLifeSource.new(stream, catalog)
	var offered := {}
	for pair in calm.records(director):
		offered[(pair[0] as NpcRecord).species] = true
	assert_true(offered.has(&"delver"), "with no drill, the Delver is offered")
	var drilled := RockLifeSource.new(stream, catalog)
	drilled.quiet = func(_site_id: StringName, _point: Vector3) -> bool:
		return true
	offered = {}
	for pair in drilled.records(director):
		offered[(pair[0] as NpcRecord).species] = true
	assert_false(offered.has(&"delver"), "with a drill working at its home its record is not offered")
	assert_true(catalog.get_def(&"delver").shy_of_drills)

# --- in the flight scene: the whole chain, mind to stray field -------------------------

## A dev Delver on the start rock, sent under by hand, comes up 20 m on and the
## grit it leaves is a real stray the stray field counts (the flight scene's
## drop and count_near Callables, which RockSite is given).
func test_a_real_delver_coming_up_leaves_grit_in_the_stray_field():
	var root: Node = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(root)
	var stream: AsteroidStream = root.get_node("AsteroidStream")
	var avatar: Avatar = root.get_node("Ship/Interior/Avatar")
	var ship: Ship = root.get_node("Ship")
	await wait_physics_frames(5)
	var detail := stream.details.nearest(ship.exterior.global_position)
	var scratch := RockSite.new(detail, stream.seed)
	var home := scratch.frame() * scratch.start_pose(scratch.records[0], 0.0).origin
	var up := (home - detail.global_position).normalized()
	ship.exterior.global_position = home + up * 120.0
	ship.exterior.linear_velocity = Vector3.ZERO
	avatar.enter_suit(root.get_node("Outside"), Transform3D(Basis.looking_at(-up, Vector3.UP), home + up * 40.0),
		Vector3.ZERO, ship.exterior)
	await wait_physics_frames(60)
	var site: RockSite = root.rock_life.site_for(detail.rock)
	assert_not_null(site, "the rock's creatures are on offer")
	if site == null:
		return
	assert_true(site.drop.is_valid() and site.count_near.is_valid(), "the flight scene wired the drop and the count")
	var dev: DevCreatures = root.dev_creatures[root.exterior_npcs]
	var ids: Array[StringName] = [dev.next_id(&"delver")]
	var dir := site.data.dir_of(site.frame().affine_inverse() * home)
	var made := site.add_group(&"delver", dir, 1, ids)
	dev.add(made[0], site)
	await wait_physics_frames(40)
	var npc: Npc = root.exterior_npcs.live.get(made[0].id)
	assert_not_null(npc, "the Delver is live")
	if npc == null:
		return
	npc.brain = null
	var strays: StrayField = root.strays
	var here := npc.global_position
	var before := strays.count_of(&"crystal_grit", here, 10000.0)
	var round := site.burrow_points(site.group_of(made[0]))
	assert_gte(round.size(), 6, "a dev Delver has a round")
	npc.intent = Intent.go(round[1], 1.0, &"burrow")
	for i in 60 * 30:
		if site._surfacings.has(made[0].id):
			break
		await wait_physics_frames(1)
	assert_true(site._surfacings.has(made[0].id), "it came up")
	await wait_physics_frames(5)
	var left := strays.count_of(&"crystal_grit", npc.global_position, 6.0)
	assert_between(left, 2, 4, "2 to 4 grit lie where it came up")
	assert_eq(strays.count_of(&"crystal_grit", here, 10000.0) - before, left, "and nowhere else")
	assert_lte(strays.count_of(&"quantum_shard", npc.global_position, 6.0), 1, "never more than a shard")
