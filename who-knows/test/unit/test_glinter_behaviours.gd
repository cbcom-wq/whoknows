extends GutTest

## The Glinter's behaviours (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §4.3), each from a made-up context.

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

func test_ambush_springs_within_5_m_when_calm():
	var b := NpcBehaviours.make(&"ambush")
	assert_true(b.reflex, "a reflex: it pre-empts the quiet lure")
	assert_eq(b.threshold, 0.5)
	var c := _ctx()
	c.needs[&"fear"] = 0.1
	assert_eq(b.score(c), 0.0, "nobody in sight")
	c.player = Vector3(4.9, 0, 0)
	assert_gte(b.score(c), b.threshold, "4.9 m")
	c.player = Vector3(5.1, 0, 0)
	assert_eq(b.score(c), 0.0, "5.1 m")
	c.player = Vector3(4.9, 0, 0)
	c.needs[&"fear"] = 0.5
	assert_eq(b.score(c), 0.0, "afraid: it keeps still")
	c.needs[&"fear"] = 0.39
	assert_gte(b.score(c), b.threshold, "just under 0.4 is still calm")

func test_ambush_leaps_at_you_then_bites_once_and_is_afraid():
	var b := NpcBehaviours.make(&"ambush")
	var c := _ctx()
	c.needs[&"fear"] = 0.1
	c.player = Vector3(4.0, 0, 0)
	b.start(c)
	var i := b.think(c)
	assert_eq(i.action, &"leap")
	assert_eq(i.leap_to, Vector3(4.0, 0, 0), "at your suit")
	assert_false(b.done(c), "springing")
	c.time += 0.2
	c.player = Vector3(2.0, 0, 0)
	i = b.think(c)
	assert_eq(i.action, &"lunge", "not yet in reach: it keeps coming")
	assert_eq(i.move_to, Vector3(2.0, 0, 0))
	assert_false(b.done(c))
	c.time += 0.2
	c.player = Vector3(0.5, 0, 0)
	i = b.think(c)
	assert_eq(i.action, &"bite")
	assert_gte(float(c.needs[&"fear"]), 0.8, "afraid after")
	assert_true(b.done(c), "one bite, then it is done")
	assert_eq(b.score(c), 0.0, "and it does not spring again while afraid")

func test_ambush_bites_within_reach_plus_0_3():
	var b := NpcBehaviours.make(&"ambush")
	var c := _ctx()
	b.start(c)
	c.player = Vector3(3, 0, 0)
	b.think(c)
	c.player = Vector3(1.05, 0, 0)
	assert_eq(b.think(c).action, &"bite", "0.8 m reach + 0.3")
	b.start(c)
	b.think(c)
	c.player = Vector3(1.15, 0, 0)
	assert_eq(b.think(c).action, &"lunge")

func test_ambush_gives_up_after_4_s_and_springs_again_when_restarted():
	var b := NpcBehaviours.make(&"ambush")
	var c := _ctx()
	c.player = Vector3(3, 0, 0)
	b.start(c)
	b.think(c)
	c.time += 3.9
	assert_false(b.done(c))
	c.time += 0.2
	assert_true(b.done(c), "4 s and no bite")
	b.start(c)
	assert_false(b.done(c))
	assert_eq(b.think(c).action, &"leap", "a fresh start springs again")

func test_ambush_outranks_lure_and_hide_takes_over_after():
	var amb := NpcBehaviours.make(&"ambush")
	var lure := NpcBehaviours.make(&"lure")
	var hide := NpcBehaviours.make(&"hide")
	var c := _ctx()
	c.player = Vector3(3, 0, 0)
	assert_gt(amb.score(c), lure.score(c))
	c.places[&"shelter"] = Vector3(10, 0, 0)
	c.needs[&"fear"] = 0.9
	assert_eq(amb.score(c), 0.0)
	assert_gt(hide.score(c), lure.score(c), "afraid after the bite: it goes to the crater floor")

func test_a_bite_makes_it_exactly_as_afraid_as_the_spec_says():
	var b := NpcBehaviours.make(&"ambush")
	var c := _ctx()
	c.needs[&"fear"] = 0.1
	c.player = Vector3(4.0, 0, 0)
	b.start(c)
	b.think(c)
	c.player = Vector3(0.5, 0, 0)
	b.think(c)
	assert_almost_eq(float(c.needs[&"fear"]), 0.8, 0.0001, "0.1 is lifted to 0.8, not to 0.9")
	b = NpcBehaviours.make(&"ambush")
	c = _ctx()
	c.needs[&"fear"] = 0.35
	c.player = Vector3(4.0, 0, 0)
	b.start(c)
	b.think(c)
	c.player = Vector3(0.5, 0, 0)
	b.think(c)
	assert_almost_eq(float(c.needs[&"fear"]), 0.8, 0.0001, "and 0.35 likewise")
	b = NpcBehaviours.make(&"ambush")
	c = _ctx()
	c.needs[&"fear"] = 0.95
	b.start(c)
	c.player = Vector3(0.5, 0, 0)
	b.think(c)
	b.think(c)
	assert_almost_eq(float(c.needs[&"fear"]), 0.95, 0.0001, "never lowered")

func test_giving_up_without_a_bite_leaves_it_a_little_afraid_once():
	var b := NpcBehaviours.make(&"ambush")
	var c := _ctx()
	c.player = Vector3(3, 0, 0)
	b.start(c)
	b.think(c)
	assert_false(b.done(c))
	assert_eq(float(c.needs[&"fear"]), 0.0, "nothing yet")
	c.time += 4.1
	assert_true(b.done(c))
	assert_almost_eq(float(c.needs[&"fear"]), 0.3, 0.0001, "0.3 for a spring that found nobody")
	assert_true(b.done(c))
	assert_true(b.done(c))
	assert_almost_eq(float(c.needs[&"fear"]), 0.3, 0.0001, "asked again and again, it counts once")
	c.needs[&"fear"] = 0.3
	assert_gte(b.score(c), b.threshold, "0.3 is still calm: it springs once more")
	b.start(c)
	b.think(c)
	c.time += 4.1
	b.done(c)
	assert_almost_eq(float(c.needs[&"fear"]), 0.6, 0.0001, "the second miss gives 0.6")
	assert_eq(b.score(c), 0.0, "and then it keeps still instead of springing every 4 s")
