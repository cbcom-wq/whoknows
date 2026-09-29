extends GutTest

## NPCs are hurt, die or are knocked out, and the ledger remembers
## (docs/superpowers/specs/2026-09-29-health-and-damage-design.md §6).

class FakeSite extends NpcSite:
	func frame() -> Transform3D:
		return Transform3D.IDENTITY
	func alive() -> bool:
		return true

class FakeSource:
	var entries: Array = []
	func records(_director) -> Array:
		return entries

var _director: NpcDirector
var _source: FakeSource
var _site: FakeSite
var _ledger: NpcLedger

func _species(id: StringName, knocked_out_for := 0.0) -> NpcSpecies:
	var s := NpcSpecies.new()
	s.id = id
	s.size = 0.8
	s.height = 0.4
	s.max_health = 40.0
	s.knocked_out_for = knocked_out_for
	s.needs = {&"fear": 0.0}
	return s

func before_each():
	var holder := Node3D.new()
	add_child_autofree(holder)
	_director = NpcDirector.new()
	_director.rule = NpcDirector.Rule.BY_SITE
	_director.holder = holder
	_director.catalog = NpcCatalog.new()
	_director.catalog.register(_species(&"creature"))
	_director.catalog.register(_species(&"droid", 60.0))
	_director.set_physics_process(false)
	_ledger = NpcLedger.new()
	_director.ledger = _ledger
	_source = FakeSource.new()
	_director.sources = [_source]
	_site = FakeSite.new()
	_site.id = &"site"
	add_child_autofree(_director)

func _live(species: StringName, n := 1) -> Npc:
	var r := NpcRecord.make(StringName("%s:%d" % [species, n]), species, &"site", Vector3.ZERO, n)
	_source.entries.append([r, _site])
	_director.review()
	return _director.live.get(r.id)

func _hit(damage: float) -> Hit:
	var hit := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, null)
	hit.damage = damage
	return hit

func test_a_hit_hurts_and_frightens():
	var npc := _live(&"creature")
	npc.receive_hit(_hit(10.0))
	assert_eq(npc.health.current, 30.0)
	assert_almost_eq(float(npc.brain.needs[&"fear"]), 0.25, 0.01, "a quarter of its health")
	assert_false(npc.down)

func test_a_creature_dies_lies_still_goes_and_never_wakes_again():
	var npc := _live(&"creature")
	npc.receive_hit(_hit(100.0))
	assert_true(npc.down)
	assert_true(npc.is_dead())
	assert_true(_ledger.is_dead(npc.record.id))
	var id := npc.record.id
	npc._physics_process(Npc.CORPSE_FOR - 1.0)
	assert_true(_director.live.has(id), "it lies there a while")
	npc._physics_process(1.5)
	assert_false(_director.live.has(id), "then it goes")
	_director.review()
	assert_false(_director.live.has(id), "and never wakes again")

func test_the_droid_is_knocked_out_and_gets_up():
	var npc := _live(&"droid")
	npc.receive_hit(_hit(100.0))
	assert_true(npc.down)
	assert_false(npc.is_dead())
	assert_false(_ledger.is_dead(npc.record.id))
	npc._physics_process(59.0)
	assert_true(npc.down)
	npc._physics_process(1.5)
	assert_false(npc.down)
	assert_almost_eq(npc.health.current, 40.0 * 0.25, 0.01)

func test_revive_gets_a_knocked_out_droid_up_at_once_but_not_the_dead():
	var droid := _live(&"droid")
	droid.receive_hit(_hit(100.0))
	droid.revive()
	assert_false(droid.down)
	var creature := _live(&"creature", 2)
	creature.receive_hit(_hit(100.0))
	creature.revive()
	assert_true(creature.down, "the dead stay dead")

func test_wounds_are_kept_while_it_sleeps():
	var npc := _live(&"creature")
	var id := npc.record.id
	npc.receive_hit(_hit(15.0))
	_source.entries.clear()
	_director.review()
	assert_false(_director.live.has(id))
	assert_eq(_ledger.health_of(id, 40.0), 25.0)
	var again := _live(&"creature")
	assert_eq(again.health.current, 25.0)

func test_the_ledger_round_trips():
	_ledger.mark_dead(&"a")
	_ledger.set_health(&"b", 12.0, 40.0)
	_ledger.set_health(&"c", 40.0, 40.0)
	var back := NpcLedger.new()
	back.from_dict(JSON.parse_string(JSON.stringify(_ledger.to_dict())))
	assert_true(back.is_dead(&"a"))
	assert_eq(back.health_of(&"b", 40.0), 12.0)
	assert_eq(back.health_of(&"c", 40.0), 40.0, "full is not remembered")
	assert_eq(back.dead_count(), 1)
