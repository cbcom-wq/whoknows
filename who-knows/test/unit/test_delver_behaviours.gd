extends GutTest

## The Delver's behaviours (docs/superpowers/specs/
## 2026-10-10-rock-creatures-design.md §5.3), each from a made-up context.

const CRYSTAL := Vector3(10, 0, 0)
const NEXT := Vector3(30, 0, 5)
const ROUND: Array[Vector3] = [Vector3(10, 0, 0), Vector3(30, 0, 5), Vector3(-20, 0, 2), Vector3(0, 0, 40)]

func _ctx(time := 100.0) -> NpcContext:
	var c := NpcContext.new()
	c.memory = NpcMemory.new()
	c.time = time
	c.dt = 0.2
	c.needs = {&"hunger": 0.0, &"fear": 0.0}
	c.record = NpcRecord.make(&"delver:t:0:0", &"delver", &"rock:t", Vector3.ZERO, 7, 0)
	c.species = NpcCatalog.load_from_dir("res://data/npcs").get_def(&"delver")
	c.up = Vector3.UP
	c.forward = Vector3.FORWARD
	c.position = CRYSTAL
	c.places = {&"crystal": CRYSTAL, &"burrow": NEXT}
	c.extra = {&"burrows": ROUND, &"cycle": 200.0, &"surfaced_ago": 0.0}
	return c

func test_every_behaviour_exists():
	var sp := NpcCatalog.load_from_dir("res://data/npcs").get_def(&"delver")
	assert_eq(sp.behaviours, [&"feed", &"delve", &"dive"] as Array[StringName])
	for id in sp.behaviours:
		assert_true(NpcBehaviours.exists(id), "%s" % id)
		assert_not_null(NpcBehaviours.make(id), "%s is a Behaviour" % id)

func test_feed_goes_to_the_crystal_when_hungry_and_eats_there():
	var b := NpcBehaviours.make(&"feed")
	assert_false(b.reflex)
	var c := _ctx()
	c.position = Vector3(40, 0, 0)
	c.needs[&"hunger"] = 0.3
	assert_eq(b.score(c), 0.0, "not hungry yet")
	c.needs[&"hunger"] = 0.55
	assert_almost_eq(b.score(c), Curves.ramp(0.55, 0.3, 0.8), 0.0001)
	assert_gt(b.score(c), 0.0)
	c.needs[&"hunger"] = 0.8
	assert_almost_eq(b.score(c), 1.0, 0.0001)
	b.start(c)
	var i := b.think(c)
	assert_eq(i.move_to, CRYSTAL, "to the crystal")
	assert_almost_eq(i.speed, 0.5, 0.0001, "at 0.5")
	assert_false(b.done(c), "it is hungry")
	c.position = CRYSTAL
	c.needs[&"hunger"] = 0.5
	var eating := b.think(c)
	assert_eq(eating.action, &"eat")
	assert_null(eating.move_to, "it stays and eats")
	assert_almost_eq(float(c.needs[&"hunger"]), 0.5 - 0.05 * 0.2, 0.0001, "hunger eases 0.05 a second")
	assert_false(b.done(c))
	c.needs[&"hunger"] = 0.0999
	assert_true(b.done(c), "done below 0.1")

func test_feed_scores_nothing_without_a_crystal():
	var b := NpcBehaviours.make(&"feed")
	var c := _ctx()
	c.needs[&"hunger"] = 0.9
	c.places.erase(&"crystal")
	assert_eq(b.score(c), 0.0)
	assert_null(b.think(c).move_to)

func test_delve_waits_out_its_cycle_then_burrows_to_the_next_point():
	var b := NpcBehaviours.make(&"delve")
	assert_false(b.reflex)
	var c := _ctx()
	c.extra[&"surfaced_ago"] = 199.0
	assert_eq(b.score(c), 0.0, "still digesting")
	c.extra[&"surfaced_ago"] = 200.0
	assert_almost_eq(b.score(c), 0.7, 0.0001, "the cycle is up")
	c.needs[&"hunger"] = 0.3
	assert_eq(b.score(c), 0.0, "but a hungry Delver feeds first")
	c.needs[&"hunger"] = 0.29
	assert_almost_eq(b.score(c), 0.7, 0.0001)
	b.start(c)
	var i := b.think(c)
	assert_eq(i.move_to, NEXT, "to the next point of its round")
	assert_almost_eq(i.speed, 1.0, 0.0001)
	assert_eq(i.action, &"burrow", "the body goes under")
	assert_false(b.done(c), "it has not come up")
	c.time += 12.0
	c.extra[&"surfaced_ago"] = 212.0
	assert_false(b.done(c), "12 s on, still the long wait since it last came up")
	c.extra[&"surfaced_ago"] = 0.5
	assert_true(b.done(c), "done once it has come up since it began")

func test_delve_scores_nothing_without_a_round():
	var b := NpcBehaviours.make(&"delve")
	var c := _ctx()
	c.extra[&"surfaced_ago"] = 1000.0
	c.places.erase(&"burrow")
	assert_eq(b.score(c), 0.0, "no next burrow")
	c.places[&"burrow"] = NEXT
	c.extra.erase(&"cycle")
	assert_eq(b.score(c), 0.0, "and no cycle")

func test_dive_sends_it_to_the_farthest_point_at_once():
	var b := NpcBehaviours.make(&"dive")
	assert_true(b.reflex, "it must interrupt")
	assert_almost_eq(b.threshold, 0.5, 0.0001)
	var c := _ctx()
	assert_eq(b.score(c), 0.0, "quiet")
	c.memory.note(Stimulus.VIBRATION, 1, Vector3(5, 0, 0), 0.8, c.time - 0.5)
	assert_almost_eq(b.score(c), 1.0, 0.0001, "a vibration just now")
	c.time += 1.0
	assert_eq(b.score(c), 0.0, "a second on it is forgotten")
	c.memory.note(Stimulus.TOUCH, 2, Vector3(1, 0, 0), 0.7, c.time - 0.2)
	assert_almost_eq(b.score(c), 1.0, 0.0001, "a touch")
	c.grounded = false
	assert_eq(b.score(c), 0.0, "off the ground it cannot dive")
	c.grounded = true
	b.start(c)
	var i := b.think(c)
	assert_eq(i.move_to, Behaviour.farthest_from(ROUND, CRYSTAL, CRYSTAL), "the farthest point")
	assert_eq(i.move_to, Vector3(0, 0, 40), "40 m off, not the next one")
	assert_almost_eq(i.speed, 1.0, 0.0001)
	assert_eq(i.action, &"burrow")
	assert_false(b.done(c))
	c.extra[&"surfaced_ago"] = 0.3
	c.time += 8.0
	assert_true(b.done(c), "done once it has come up")

func test_dive_ignores_the_hum_of_a_drill_and_goes_nowhere_without_a_round():
	var b := NpcBehaviours.make(&"dive")
	var c := _ctx()
	c.memory.note(Stimulus.VIBRATION, 1, Vector3(5, 0, 0), 0.1, c.time)
	assert_eq(b.score(c), 0.0, "a far, faint tremor is no reason to run")
	c.memory.note(Stimulus.VIBRATION, 2, Vector3(5, 0, 0), 0.9, c.time)
	c.extra.erase(&"burrows")
	assert_eq(b.score(c), 0.0, "and with nowhere to go it stays")

## The three together, in the brain, over 25 minutes of its rock's time: it eats
## when hungry, digests, and goes under once each cycle, never while hungry and
## never twice in a cycle; a bump sends it under at once, wherever it is in the cycle.
func test_the_mind_cycles_feed_digest_burrow():
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c := _ctx(0.0)
	var brain := Brain.new()
	brain.setup(c.species, rng)
	var burrows: Array[float] = []
	var hungry_burrows := 0
	var ate := 0.0
	var surfaced_ago := 0.0
	var time := 0.0
	# It is under for 10 s, the mind asking again every think meanwhile, then up.
	var comes_up := -1.0
	var goes_to := Vector3.ZERO
	for step in 7500:
		time += 0.2
		surfaced_ago += 0.2
		if comes_up >= 0.0 and time >= comes_up:
			comes_up = -1.0
			surfaced_ago = 0.0
			c.position = goes_to
			c.places[&"crystal"] = goes_to
		c.time = time
		c.extra[&"surfaced_ago"] = surfaced_ago
		var i := brain.think(c)
		if i.action == &"burrow" and comes_up < 0.0:
			burrows.append(time)
			if brain.needs[&"hunger"] >= 0.3:
				hungry_burrows += 1
			comes_up = time + 10.0
			goes_to = i.move_to
		elif i.action == &"eat":
			ate += 0.2
	assert_gte(burrows.size(), 5, "it went under every cycle (200 s here): %s" % [burrows])
	assert_eq(hungry_burrows, 0, "never while hungry")
	for k in range(1, burrows.size()):
		assert_gte(burrows[k] - burrows[k - 1], 200.0, "never twice in a cycle")
		assert_lte(burrows[k] - burrows[k - 1], 245.0, "and soon after the cycle is up")
	assert_gt(ate, 10.0, "it fed along the way")

func test_a_bump_sends_a_calm_delver_under_at_once():
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var c := _ctx(50.0)
	var brain := Brain.new()
	brain.setup(c.species, rng)
	brain.needs[&"hunger"] = 0.1
	c.extra[&"surfaced_ago"] = 40.0
	assert_ne(brain.think(c).action, &"burrow", "it sits quietly, 160 s from its cycle")
	c.time += 0.2
	c.memory.note(Stimulus.TOUCH, 7, Vector3(1, 0, 0), 0.7, c.time)
	var i := brain.think(c)
	assert_eq(i.action, &"burrow")
	assert_eq(i.move_to, Vector3(0, 0, 40), "to the farthest burrow point")
