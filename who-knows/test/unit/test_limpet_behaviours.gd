extends GutTest

## The limpet's behaviours (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §6.2), each from a made-up context.

func _ctx(seed := 7, time := 10.0) -> NpcContext:
	var c := NpcContext.new()
	c.memory = NpcMemory.new()
	c.time = time
	c.dt = 0.2
	c.needs = {&"appetite": 0.0, &"fear": 0.0}
	c.record = NpcRecord.make(&"limpet:t:0:0", &"limpet", &"rock:t", Vector3.ZERO, seed, 0)
	c.species = NpcCatalog.load_from_dir("res://data/npcs").get_def(&"limpet")
	c.up = Vector3.UP
	c.forward = Vector3.FORWARD
	return c

func test_every_behaviour_exists():
	var sp := NpcCatalog.load_from_dir("res://data/npcs").get_def(&"limpet")
	assert_gt(sp.behaviours.size(), 0)
	for id in sp.behaviours:
		assert_true(NpcBehaviours.exists(id), "%s" % id)
		assert_not_null(NpcBehaviours.make(id), "%s is a Behaviour" % id)

func test_cling_is_the_quiet_default():
	var b := NpcBehaviours.make(&"cling")
	var c := _ctx()
	assert_almost_eq(b.score(c), 0.2, 0.0001)
	assert_false(b.reflex)
	b.start(c)
	var i := b.think(c)
	assert_eq(i.action, &"cling")
	assert_null(i.move_to, "it stays where it is")
	assert_false(b.done(c), "it is never done")
	c.time += 1000.0
	c.needs[&"appetite"] = 1.0
	assert_false(b.done(c), "however long, however hungry")
