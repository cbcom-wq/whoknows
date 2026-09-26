extends GutTest

## The brain (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §7):
## needs rise; the best behaviour runs; the current one keeps a near tie; a
## held behaviour is kept for its minimum time unless a reflex fires.

class Fixed extends Behaviour:
	var value := 0.0
	var finished := false
	func score(_ctx: NpcContext) -> float:
		return value
	func done(_ctx: NpcContext) -> bool:
		return finished
	func think(_ctx: NpcContext) -> Intent:
		return Intent.idle(id)

func _b(id: StringName, value: float, min_time := 0.0, reflex := false) -> Fixed:
	var b := Fixed.new()
	b.id = id
	b.value = value
	b.min_time = min_time
	b.reflex = reflex
	return b

func _ctx(time: float) -> NpcContext:
	var c := NpcContext.new()
	c.time = time
	c.dt = 0.2
	return c

func test_needs_rise_at_their_rates_and_stop_at_one():
	var sp := NpcSpecies.new()
	sp.needs = {&"hunger": 0.5}
	sp.need_start = {&"hunger": Vector2(0.2, 0.2)}
	var brain := Brain.new()
	brain.setup(sp, RandomNumberGenerator.new())
	assert_almost_eq(float(brain.needs[&"hunger"]), 0.2, 0.0001)
	brain.think(_ctx(0.0))
	assert_almost_eq(float(brain.needs[&"hunger"]), 0.3, 0.0001)
	for i in 20:
		brain.think(_ctx(i * 0.2))
	assert_almost_eq(float(brain.needs[&"hunger"]), 1.0, 0.0001)

func test_the_best_runs_and_a_near_tie_does_not_flip_it():
	var brain := Brain.new()
	var a := _b(&"a", 0.5)
	var b := _b(&"b", 0.4)
	brain.behaviours = [a, b]
	assert_eq(brain.think(_ctx(0.0)).action, &"a")
	b.value = 0.6
	assert_eq(brain.think(_ctx(0.2)).action, &"a", "1.2x is not enough")
	b.value = 0.65
	assert_eq(brain.think(_ctx(0.4)).action, &"b", "1.3x is")

func test_a_held_behaviour_waits_for_its_minimum_time_unless_done():
	var brain := Brain.new()
	var a := _b(&"a", 0.5, 2.0)
	var b := _b(&"b", 0.1)
	brain.behaviours = [a, b]
	brain.think(_ctx(0.0))
	b.value = 5.0
	assert_eq(brain.think(_ctx(1.0)).action, &"a", "held")
	a.finished = true
	assert_eq(brain.think(_ctx(1.2)).action, &"b", "done releases it")

func test_a_reflex_preempts_and_is_not_preempted_while_held():
	var brain := Brain.new()
	var a := _b(&"a", 0.5, 5.0)
	var r := _b(&"r", 0.0, 1.0, true)
	r.threshold = 0.5
	var c := _b(&"c", 0.1)
	brain.behaviours = [a, r, c]
	brain.think(_ctx(0.0))
	r.value = 0.4
	assert_eq(brain.think(_ctx(0.2)).action, &"a", "under its threshold")
	r.value = 0.6
	assert_eq(brain.think(_ctx(0.4)).action, &"r", "over it, at once")
	c.value = 9.0
	assert_eq(brain.think(_ctx(0.6)).action, &"r", "held against a bigger ordinary score")
	r.value = 0.0
	assert_eq(brain.think(_ctx(1.6)).action, &"c", "and let go after")

func test_a_finished_behaviour_that_still_wins_starts_again():
	var brain := Brain.new()
	var a := _b(&"a", 0.5)
	brain.behaviours = [a]
	brain.think(_ctx(0.0))
	a.finished = true
	brain.think(_ctx(3.0))
	assert_almost_eq(a.started, 3.0, 0.0001)

func test_an_unknown_behaviour_is_skipped_with_an_error():
	var sp := NpcSpecies.new()
	sp.id = &"odd"
	sp.behaviours = [&"no_such_behaviour"] as Array[StringName]
	var brain := Brain.new()
	brain.setup(sp, RandomNumberGenerator.new())
	assert_eq(brain.behaviours.size(), 0)
	assert_push_error("no behaviour called no_such_behaviour")

func test_scores_are_kept_for_the_overlay():
	var brain := Brain.new()
	brain.behaviours = [_b(&"a", 0.5), _b(&"b", 0.2)]
	brain.think(_ctx(0.0))
	assert_almost_eq(float(brain.scores[&"a"]), 0.5, 0.0001)
	assert_almost_eq(float(brain.scores[&"b"]), 0.2, 0.0001)

func test_the_overlay_describes_a_brain():
	assert_eq(NpcDebug.bar(0.0), "▯▯▯▯▯")
	assert_eq(NpcDebug.bar(0.6), "▮▮▮▯▯")
	assert_eq(NpcDebug.bar(1.0), "▮▮▮▮▮")
