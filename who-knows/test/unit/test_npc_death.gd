extends GutTest

## NPCs are hurt, die or are knocked out, and the ledger remembers
## (docs/superpowers/specs/2026-09-29-health-and-damage-design.md §6).

class FakeSite extends NpcSite:
	var wounds: Array = []
	func frame() -> Transform3D:
		return Transform3D.IDENTITY
	func alive() -> bool:
		return true
	func wounded(npc: Npc, hit: Hit, taken: float) -> void:
		wounds.append([npc, hit, taken])

## A look that moves as a person does (as WadeeLook): it is told of each hurt and
## of its death, and is never turned or squashed by the body.
class PersonLook extends Node3D:
	var hurts: Array = []
	var acts: Array = []
	func hurt(share: float) -> void:
		hurts.append(share)
	func act(action: StringName) -> void:
		acts.append(action)

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

func test_a_bite_hurts_and_shoves_you_when_you_are_close():
	var npc := _live(&"creature")
	var avatar: Avatar = load("res://scenes/avatar.tscn").instantiate()
	add_child_autofree(avatar)
	avatar.global_position = npc.global_position + Vector3(0.8, 0, 0)
	assert_true(npc.bite())
	assert_eq(avatar.health.current, Avatar.MAX_HEALTH - npc.species.bite_damage)
	assert_gt(avatar.velocity.x, 0.0, "shoved away")
	avatar.global_position = npc.global_position + Vector3(5, 0, 0)
	assert_false(npc.bite(), "out of reach")

func _person() -> Npc:
	var npc := _live(&"creature")
	if npc.look != null:
		npc.look.queue_free()
	var person := PersonLook.new()
	npc.add_child(person)
	npc.look = person
	return npc

## A person (Wadoo spec §9): a wound is told to their place; they stagger by
## their own motion, not squashed; dead, they fall by it too, upright to the body,
## no longer solid, and lie where they fell until their place sleeps.
func test_a_person_tells_their_place_staggers_and_lies_where_they_fell():
	var npc := _person()
	var look := npc.look as PersonLook
	npc.receive_hit(_hit(10.0))
	assert_eq(_site.wounds.size(), 1, "the wound is told to the place")
	assert_almost_eq(float(_site.wounds[0][2]), 10.0, 0.01)
	assert_eq(look.hurts.size(), 1)
	assert_almost_eq(float(look.hurts[0]), 0.25, 0.01, "a quarter of their health")
	var b := look.transform.basis
	assert_almost_eq(b.x.length(), b.y.length(), 0.001, "never squashed")
	npc.receive_hit(_hit(100.0))
	assert_true(npc.is_dead())
	assert_true(look.acts.has(&"dead"), "they fall by their own motion")
	assert_eq(look.hurts.size(), 1, "no stagger as they die")
	assert_true(look.transform.basis.y.normalized().is_equal_approx(Vector3.UP), "never flipped")
	assert_true(npc._shape.disabled, "you no longer walk into them")
	var id := npc.record.id
	npc._physics_process(Npc.CORPSE_FOR * 3.0)
	assert_true(_director.live.has(id), "they stay")
	_director.review()
	assert_true(_director.live.has(id), "through the director's reviews, while their place offers them")
	assert_eq(_site.wounds.size(), 2)
	_source.entries.clear()
	_director.review()
	assert_false(_director.live.has(id), "gone with their place")
	_source.entries.append([npc.record, _site])
	_director.review()
	assert_false(_director.live.has(id), "and never wake again")
