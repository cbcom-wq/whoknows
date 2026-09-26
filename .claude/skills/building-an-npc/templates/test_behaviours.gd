extends GutTest

## TEMPLATE: copy to who-knows/test/unit/test_<species>_behaviours.gd. One test
## per behaviour at least: its score from made-up contexts, and what its
## think returns. No scene needed.

func _ctx(seed := 7, time := 10.0) -> NpcContext:
	var c := NpcContext.new()
	c.memory = NpcMemory.new()
	c.time = time
	c.dt = 0.2
	c.needs = {&"hunger": 0.0, &"fear": 0.0}   # CHANGE: the species' needs
	c.record = NpcRecord.make(&"CHANGE:t:0:0", &"CHANGE_species", &"CHANGE:t", Vector3.ZERO, seed, 0)
	c.species = NpcCatalog.load_from_dir("res://data/npcs").get_def(&"CHANGE_species")
	c.up = Vector3.UP
	c.forward = Vector3.FORWARD
	return c

func test_every_behaviour_exists():
	for id in NpcCatalog.load_from_dir("res://data/npcs").get_def(&"CHANGE_species").behaviours:
		assert_true(NpcBehaviours.exists(id), "%s" % id)

func test_CHANGE_scores_with_its_need():
	var b := NpcBehaviours.make(&"CHANGE_behaviour")
	var c := _ctx()
	assert_almost_eq(b.score(c), 0.0, 0.001)
	c.needs[&"hunger"] = 0.8
	assert_gt(b.score(c), 0.5)

func test_CHANGE_reflex_fires_on_a_percept():
	var b := NpcBehaviours.make(&"CHANGE_reflex")
	var c := _ctx()
	assert_lt(b.score(c), b.threshold)
	c.memory.note(Stimulus.TOUCH, 0, Vector3(0, 0, -1), 0.8, c.time)
	assert_true(b.reflex)
	assert_gt(b.score(c), b.threshold)

func test_CHANGE_goes_where_it_should():
	var b := NpcBehaviours.make(&"CHANGE_behaviour")
	var c := _ctx()
	c.places[&"shelter"] = Vector3(10, 0, 0)
	b.start(c)
	assert_eq(b.think(c).move_to, Vector3(10, 0, 0))
