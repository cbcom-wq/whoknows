extends GutTest

## The burrower (docs/superpowers/specs/2026-10-10-rock-creatures-design.md
## §5.2, §8.1): sinks, travels hidden under the rock and comes up elsewhere,
## off the fire-control targets while it is under. A test species stands in for
## the Delver; the scene tests run in the real flight scene on the start rock,
## with the creature made as F10 makes one (the dev spawner's path).

## A rock site that counts what the burrower asks of it.
class SpySite extends RockSite:
	var poses := 0
	var surfacings := 0
	func pose_at(dir: Vector3) -> Transform3D:
		poses += 1
		return super(dir)
	func surfaced(npc: Npc) -> void:
		surfacings += 1
		super(npc)

class FlatSite extends NpcSite:
	func frame() -> Transform3D:
		return Transform3D.IDENTITY

var _root: Node
var _stream: AsteroidStream
var _avatar: Avatar
var _ship: Ship
var _detail: AsteroidDetail
var _site: SpySite
var _npc: Npc
var _record: NpcRecord
var _species: NpcSpecies

func _digger() -> NpcSpecies:
	var s := NpcSpecies.new()
	s.id = &"digger"
	s.size = 3.0
	s.height = 1.5
	s.width = 1.5
	s.mass = 200.0
	s.top_speed = 0.5
	s.max_health = 60.0
	s.look = &"skitter"
	s.live_radius = 100.0
	s.fade = Vector2(70, 95)
	s.locomotors = [&"surface_crawler", &"burrower", &"zero_g_drift"] as Array[StringName]
	return s

# --- the registry and the hand-over, without a scene ----------------------------------

func test_the_registry_knows_the_burrower():
	var loco := Npc.make_locomotor(&"burrower")
	assert_true(loco is Burrower)
	assert_eq(loco.id, &"burrower")
	assert_true(loco.grounded())

func test_off_a_rock_it_hands_straight_back_and_the_crawler_never_sends_it():
	var root := Node3D.new()
	add_child_autofree(root)
	var npc := Npc.new()
	root.add_child(npc)
	var site := FlatSite.new()
	site.id = &"flat"
	npc.setup(NpcRecord.make(&"digger:0", &"digger", &"flat", Vector3.ZERO, 1), _digger(), site, false,
		Transform3D.IDENTITY)
	npc.intent = Intent.go(Vector3(5, 0, 0), 1.0, &"burrow")
	assert_eq(npc.active.handover(npc), &"", "the crawler keeps an ask it has no rock for")
	var burrower := npc.locomotors[&"burrower"] as Burrower
	npc.switch_to(&"burrower")
	assert_eq(burrower.handover(npc), &"surface_crawler", "and a burrower somehow active gives it back")

# --- in the flight scene ----------------------------------------------------------------

func _scene() -> void:
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_stream = _root.get_node("AsteroidStream")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_ship = _root.get_node("Ship")
	await wait_physics_frames(5)

## A digger live on the start rock, its mind off (the test gives the orders),
## the spacewalker 40 m over it.
func _digger_live() -> void:
	await _scene()
	_species = _digger()
	_root.exterior_npcs.catalog.register(_species)
	_detail = _stream.details.nearest(_ship.exterior.global_position)
	_site = SpySite.new(_detail, _stream.seed)
	var home := _site.frame() * _site.start_pose(_site.records[0], 0.0).origin
	var up := (home - _detail.global_position).normalized()
	_ship.exterior.global_position = home + up * 400.0
	_ship.exterior.linear_velocity = Vector3.ZERO
	var pose := Transform3D(Basis.looking_at(-up, Vector3.UP), home + up * 40.0)
	_avatar.enter_suit(_root.get_node("Outside"), pose, Vector3.ZERO, _ship.exterior)
	await wait_physics_frames(40)
	var dev: DevCreatures = _root.dev_creatures[_root.exterior_npcs]
	var ids: Array[StringName] = [dev.next_id(&"digger")]
	var dir := _site.data.dir_of(_site.frame().affine_inverse() * home)
	for record in _site.add_group(&"digger", dir, 1, ids):
		_record = record
		dev.add(record, _site)
	await wait_physics_frames(40)
	_npc = _root.exterior_npcs.live.get(_record.id)
	assert_not_null(_npc, "the digger is live")
	_npc.brain = null

## A point 20 m along the surface from the digger, site-local.
func _twenty_metres_on() -> Vector3:
	var here := _site.data.dir_of(_npc.local_position())
	var metres := _site.data.surface_point(here).length()
	return _site.data.surface_point(RockHerds.tilted(here, 20.0 / metres, 1.0))

func _is_target(npc: Npc) -> bool:
	return npc.is_in_group(Weapons.TARGETS)

func test_it_sinks_travels_hidden_and_comes_up_at_the_target():
	await _digger_live()
	assert_true(_is_target(_npc), "on the surface it is a target")
	assert_false(_npc._shape.disabled)
	var target := _twenty_metres_on()
	var poses := _site.poses
	_npc.intent = Intent.go(target, 1.0, &"burrow")
	await wait_physics_frames(98)
	assert_true(_npc.active is Burrower, "the crawler handed over")
	assert_true(_npc._shape.disabled, "no body under the rock")
	assert_true(_npc._skin_shape.disabled, "and no skin")
	assert_false(_is_target(_npc), "not a target")
	assert_false(_npc.look.visible, "and not seen")
	assert_eq(_site.poses, poses, "no ray yet: it has not come up")
	var a := _npc.global_position
	await wait_physics_frames(60)
	var pace := a.distance_to(_npc.global_position)
	assert_between(pace, 1.7, 2.3, "about 2 m/s under, not %.2f" % pace)
	for i in 60 * 14:
		if _npc.active is SurfaceCrawler:
			break
		await wait_physics_frames(1)
	assert_true(_npc.active is SurfaceCrawler, "back on the crawler")
	var up_at := _site.frame() * _site.pose_at(_site.data.dir_of(target)).origin
	assert_lt(_npc.global_position.distance_to(up_at), 1.0, "up within 1 m of the point")
	assert_eq(_site.poses, poses + 2, "one pose for the exit (and the one this test asked for)")
	assert_false(_npc._shape.disabled, "solid")
	assert_false(_npc._skin_shape.disabled)
	assert_true(_npc.look.visible)
	assert_true(_is_target(_npc), "a target again")
	assert_eq(Weapons.id_of(_npc), Weapons.npc_id(_record.id))
	assert_eq(_site.surfacings, 1, "surfaced() once")
	assert_eq(_npc.look_drop, 0.0, "the look stands")
	assert_lt(_root.exterior_npcs.time - _npc.surfaced_at, 3.0, "and it has just come up")
	assert_eq(_npc.intent.action, &"", "the spent ask is gone")
	await wait_physics_frames(120)
	assert_true(_npc.active is SurfaceCrawler, "and it does not dive again")
	assert_eq(_site.surfacings, 1)

func test_the_look_sinks_by_its_height_over_1_5_s():
	await _digger_live()
	_npc.intent = Intent.go(_twenty_metres_on(), 1.0, &"burrow")
	await wait_physics_frames(46)
	assert_almost_eq(_npc.look_drop, _species.height * 0.5, 0.15, "half down at half the time")
	assert_false(_npc._shape.disabled, "still solid while it sinks")
	assert_true(_is_target(_npc), "and still a target")

func test_a_pooled_delver_comes_back_solid_and_a_target():
	await _digger_live()
	_npc.intent = Intent.go(_twenty_metres_on(), 1.0, &"burrow")
	await wait_physics_frames(100)
	assert_true(_npc._shape.disabled, "under")
	var director: NpcDirector = _root.exterior_npcs
	director.demote(_npc)
	var back := director.promote(_record, _site)
	assert_same(back, _npc, "the pooled node is reused")
	assert_false(back._shape.disabled, "solid")
	assert_false(back._skin_shape.disabled)
	assert_true(back.look.visible, "drawn")
	assert_eq(back.look.position, Vector3.ZERO, "the look is not sunk")
	assert_eq(back.look_drop, 0.0)
	assert_true(_is_target(back), "and a target")
	assert_true(back.active is SurfaceCrawler, "on the crawler")

func test_resting_does_nothing():
	await _digger_live()
	_npc.switch_to(&"burrower")
	_npc.intent = Intent.idle()
	var burrower := _npc.active as Burrower
	assert_eq(burrower.phase, Burrower.Phase.DONE, "nothing to dig")
	var at := _npc.global_position
	var poses := _site.poses
	for i in 120:
		burrower.step(_npc, _npc.intent, 1.0 / 60.0)
	assert_eq(_npc.global_position, at, "it has not moved")
	assert_eq(_site.poses, poses, "and cast no ray")
	assert_false(_npc._shape.disabled)
	assert_true(_is_target(_npc))

func test_a_burrow_ask_is_not_swallowed_by_a_crawler_at_rest():
	await _digger_live()
	await wait_physics_frames(90)
	# An ask for the spot it stands on: the crawler has nowhere to walk, which
	# is when it rests.
	_npc.intent = Intent.go(_npc.local_position(), 1.0, &"burrow")
	await wait_physics_frames(3)
	assert_true(_npc.active is Burrower, "it went under")

func test_it_does_not_join_the_targets_when_its_director_has_none():
	await _digger_live()
	var director: NpcDirector = _root.exterior_npcs
	director.targets = false
	_npc.intent = Intent.go(_twenty_metres_on(), 1.0, &"burrow")
	for i in 60 * 14:
		if _npc.active is SurfaceCrawler and _site.surfacings > 0:
			break
		await wait_physics_frames(1)
	assert_eq(_site.surfacings, 1)
	assert_false(_is_target(_npc), "it joins only if its director has targets")
	director.targets = true
