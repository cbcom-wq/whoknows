extends GutTest

## The director (docs/superpowers/specs/2026-09-26-npc-foundation-design.md
## §4.3): records far, nodes near; by site inside and by distance outside;
## pooled; within budget; thinking spread over the ticks.

class FakeSite extends NpcSite:
	var at := Vector3.ZERO
	var dead := false
	func frame() -> Transform3D:
		return Transform3D(Basis.IDENTITY, at)
	func alive() -> bool:
		return not dead

class FakeSource:
	var entries: Array = []
	func records(_director) -> Array:
		return entries

class CountingNpc extends Npc:
	var thinks := 0
	func think(_time: float, _dt: float) -> void:
		thinks += 1

class CountingDirector extends NpcDirector:
	var amended := 0
	func amend(record: NpcRecord) -> NpcRecord:
		amended += 1
		return record
	func _make_npc() -> Npc:
		return CountingNpc.new()

var _director: CountingDirector
var _source: FakeSource
var _site: FakeSite
var _holder: Node3D

func _species(live_radius := 350.0, fade := Vector2(250, 300)) -> NpcSpecies:
	var s := NpcSpecies.new()
	s.id = &"thing"
	s.size = 0.8
	s.height = 0.4
	s.live_radius = live_radius
	s.fade = fade
	return s

func before_each():
	_holder = Node3D.new()
	add_child_autofree(_holder)
	_director = CountingDirector.new()
	_director.holder = _holder
	_director.catalog = NpcCatalog.new()
	_director.catalog.register(_species())
	_director.set_physics_process(false)
	_source = FakeSource.new()
	_director.sources = [_source]
	_site = FakeSite.new()
	_site.id = &"site"
	add_child_autofree(_director)

func _record(n: int, home := Vector3.ZERO) -> NpcRecord:
	return NpcRecord.make(StringName("thing:%d" % n), &"thing", &"site", home, n)

func _anchor(at := Vector3.ZERO) -> Node3D:
	var a := Node3D.new()
	a.add_to_group(AsteroidStream.SPACE_ANCHOR)
	add_child_autofree(a)
	a.global_position = at
	return a

func test_by_site_promotes_every_record_and_demotes_what_goes():
	_director.rule = NpcDirector.Rule.BY_SITE
	var a := _record(1)
	var b := _record(2)
	_source.entries = [[a, _site], [b, _site]]
	_director.review()
	assert_eq(_director.live.size(), 2)
	_source.entries = [[a, _site]]
	_director.review()
	assert_eq(_director.live.size(), 1)
	assert_true(_director.live.has(a.id))
	_site.dead = true
	_director.review()
	assert_eq(_director.live.size(), 0)

func test_demoted_bodies_are_reused():
	_director.rule = NpcDirector.Rule.BY_SITE
	_source.entries = [[_record(1), _site]]
	_director.review()
	var first: Npc = _director.live.values()[0]
	var id := first.get_instance_id()
	_source.entries = []
	_director.review()
	assert_null(first.get_parent())
	_source.entries = [[_record(2), _site]]
	_director.review()
	assert_eq(_director.live.values()[0].get_instance_id(), id)

func test_by_distance_promotes_within_the_live_radius_with_a_margin_to_demote():
	_anchor()
	var rec := _record(1, Vector3(300, 0, 0))
	_source.entries = [[rec, _site]]
	_director.review()
	assert_true(_director.live.has(rec.id), "300 m is within 350 m")
	var far := _record(2, Vector3(400, 0, 0))
	_source.entries = [[rec, _site], [far, _site]]
	_director.review()
	assert_false(_director.live.has(far.id), "400 m is not")
	var npc: Npc = _director.live[rec.id]
	npc.global_position = Vector3(420, 0, 0)
	_director.review()
	assert_true(_director.live.has(rec.id), "within the margin it stays")
	npc.global_position = Vector3(460, 0, 0)
	_director.review()
	assert_false(_director.live.has(rec.id), "past it, unseen, it goes")

func test_an_npc_a_camera_could_see_is_not_demoted():
	_anchor()
	var sp := _species(350.0, Vector2(0, 0))
	_director.catalog.register(sp)
	var rec := _record(1, Vector3(300, 0, 0))
	_source.entries = [[rec, _site]]
	_director.review()
	var npc: Npc = _director.live[rec.id]
	var cam := Camera3D.new()
	cam.far = 5000.0
	add_child_autofree(cam)
	cam.look_at_from_position(Vector3(0, 0, 0), Vector3(460, 0, 0))
	_director.cameras = [cam]
	npc.global_position = Vector3(460, 0, 0)
	_director.review()
	assert_true(_director.live.has(rec.id), "in view, it stays")
	cam.look_at_from_position(Vector3(0, 0, 0), Vector3(-460, 0, 0))
	_director.review()
	assert_false(_director.live.has(rec.id), "out of view, it goes")

func test_max_live_keeps_the_nearest_and_warns():
	_anchor()
	_director.max_live = 2
	_source.entries = [[_record(1, Vector3(100, 0, 0)), _site], [_record(2, Vector3(200, 0, 0)), _site],
		[_record(3, Vector3(300, 0, 0)), _site]]
	_director.review()
	assert_eq(_director.live.size(), 2)
	assert_false(_director.live.has(&"thing:3"))
	assert_eq(_director.over_budget, 1)
	assert_engine_error("over 2", "the budget says so")

func test_amend_sees_every_record():
	_director.rule = NpcDirector.Rule.BY_SITE
	_source.entries = [[_record(1), _site], [_record(2), _site]]
	_director.review()
	assert_eq(_director.amended, 2)

func test_outside_they_join_the_floating_origin_and_inside_they_do_not():
	_anchor()
	_source.entries = [[_record(1, Vector3(10, 0, 0)), _site]]
	_director.review()
	var outside: Npc = _director.live.values()[0]
	assert_true(outside.is_in_group(Universe.EXTERIOR_SPACE))
	_source.entries = []
	_director.review()
	_director.rule = NpcDirector.Rule.BY_SITE
	_source.entries = [[_record(2), _site]]
	_director.review()
	var inside: Npc = _director.live.values()[0]
	assert_eq(inside.get_instance_id(), outside.get_instance_id(), "the same pooled body")
	assert_false(inside.is_in_group(Universe.EXTERIOR_SPACE))
	assert_eq(inside.collision_mask, Npc.MASK_INSIDE)
	assert_eq(inside.collision_layer, Npc.LAYER)

func test_npcs_stand_where_their_site_puts_them():
	_director.rule = NpcDirector.Rule.BY_SITE
	_site.at = Vector3(5, 0, 0)
	_source.entries = [[_record(1, Vector3(0, 1, 0)), _site]]
	_director.review()
	var npc: Npc = _director.live.values()[0]
	assert_almost_eq(npc.global_position.distance_to(Vector3(5, 1, 0)), 0.0, 0.0001)
	assert_almost_eq(npc.local_position().distance_to(Vector3(0, 1, 0)), 0.0, 0.0001)

func test_each_npc_thinks_five_times_a_second():
	_director.rule = NpcDirector.Rule.BY_SITE
	_director.max_live = 64
	var entries: Array = []
	for n in 24:
		entries.append([_record(n), _site])
	_source.entries = entries
	_director.review()
	var every := NpcDirector.ticks_per_think()
	for i in every * 5:
		_director.think_step()
	for npc: CountingNpc in _director.live.values():
		assert_eq(npc.thinks, 5, "%s thought %d times" % [npc.record.id, npc.thinks])
