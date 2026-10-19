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

func test_creep_goes_for_the_quantum_when_hungry():
	var b := NpcBehaviours.make(&"creep")
	var c := _ctx()
	assert_eq(b.score(c), 0.0, "no source known: nothing to creep to")
	c.places[&"quantum"] = Vector3(12, 0, 0)
	assert_eq(b.score(c), 0.0, "not hungry")
	c.needs[&"appetite"] = 0.55
	assert_almost_eq(b.score(c), Curves.ramp(0.55, 0.3, 0.8), 0.0001)
	assert_gt(b.score(c), 0.2, "over cling's 0.2 once hungry enough")
	c.needs[&"appetite"] = 0.9
	assert_almost_eq(b.score(c), 1.0, 0.0001)
	b.start(c)
	var i := b.think(c)
	assert_eq(i.move_to, Vector3(12, 0, 0))
	assert_almost_eq(i.speed * c.species.top_speed, 0.2, 0.0001, "0.2 m/s")
	assert_false(b.done(c), "12 m off")
	c.position = Vector3(8, 0, 0)
	assert_true(b.done(c), "4 m off is within its 5 m reach")
	c.places.erase(&"quantum")
	assert_true(b.done(c), "the source is gone")

func test_sip_holds_while_in_reach():
	var b := NpcBehaviours.make(&"sip")
	var c := _ctx()
	assert_eq(b.score(c), 0.0, "no source known")
	c.places[&"quantum"] = Vector3(4.9, 0, 0)
	assert_almost_eq(b.score(c), 0.9, 0.0001, "in reach: over everything but a reflex")
	c.needs[&"appetite"] = 0.5
	b.start(c)
	var i := b.think(c)
	assert_eq(i.action, &"sip")
	assert_null(i.move_to, "it stays")
	assert_almost_eq(c.need(&"appetite"), 0.5 - 0.02 * c.dt, 0.0001, "eases appetite 0.02 a second")
	assert_false(b.done(c))
	c.places[&"quantum"] = Vector3(5.1, 0, 0)
	assert_eq(b.score(c), 0.0, "out of reach")
	assert_true(b.done(c), "done once out of reach")

func test_a_base_is_sipped_from_nearer_than_a_suit():
	# The site tells how near a base must be sipped from (RockSite.BASE_REACH): a
	# little inside what Bases.sip allows.
	var c := _ctx()
	c.places[&"quantum"] = Vector3(4.2, 0, 0)
	c.extra[&"quantum_reach"] = Bases.SIP_REACH
	assert_eq(NpcBehaviours.make(&"sip").score(c), 0.0, "4.2 m is too far from a module")
	assert_false(NpcBehaviours.make(&"creep").done(c), "so it creeps on")
	c.position = Vector3(0.5, 0, 0)
	assert_almost_eq(NpcBehaviours.make(&"sip").score(c), 0.9, 0.0001)
