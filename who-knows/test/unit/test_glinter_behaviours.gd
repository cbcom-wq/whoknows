extends GutTest

## The Glinter's behaviours (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §4.3), each from a made-up context.
## (Its ambush is Task 10's.)

func _ctx(seed := 7, time := 10.0) -> NpcContext:
	var c := NpcContext.new()
	c.memory = NpcMemory.new()
	c.time = time
	c.dt = 0.2
	c.needs = {&"fear": 0.0}
	c.record = NpcRecord.make(&"glinter:t:0:0", &"glinter", &"rock:t", Vector3.ZERO, seed, 0)
	c.species = NpcCatalog.load_from_dir("res://data/npcs").get_def(&"glinter")
	c.up = Vector3.UP
	c.forward = Vector3.FORWARD
	return c

func test_every_behaviour_exists():
	var sp := NpcCatalog.load_from_dir("res://data/npcs").get_def(&"glinter")
	assert_gt(sp.behaviours.size(), 0)
	for id in sp.behaviours:
		assert_true(NpcBehaviours.exists(id), "%s" % id)
		assert_not_null(NpcBehaviours.make(id), "%s is a Behaviour" % id)

func test_lure_sits_shut():
	var b := NpcBehaviours.make(&"lure")
	var c := _ctx()
	assert_almost_eq(b.score(c), 0.2, 0.0001)
	assert_false(b.reflex)
	b.start(c)
	var i := b.think(c)
	assert_eq(i.action, &"shut")
	assert_null(i.move_to, "it stays where it is")
	assert_false(b.done(c), "it is never done")
	c.time += 1000.0
	assert_false(b.done(c), "however long")

func test_lure_eases_fear_by_0_05_a_second():
	var b := NpcBehaviours.make(&"lure")
	var c := _ctx()
	c.needs[&"fear"] = 0.5
	b.think(c)
	assert_almost_eq(float(c.needs[&"fear"]), 0.5 - 0.05 * 0.2, 0.0001)
	c.needs[&"fear"] = 0.0
	b.think(c)
	assert_eq(float(c.needs[&"fear"]), 0.0, "and no lower than none")

func test_hide_is_the_nests_after_a_fright():
	var b := NpcBehaviours.make(&"hide")
	var c := _ctx()
	assert_eq(b.score(c), 0.0, "not afraid: lure holds")
	c.places[&"shelter"] = Vector3(10, 0, 0)
	c.needs[&"fear"] = 0.8
	assert_gt(b.score(c), 0.2, "afraid: over lure's 0.2")
