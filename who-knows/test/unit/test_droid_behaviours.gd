extends GutTest

## The droid's behaviours (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §14.3), each from a made-up context.

func _ctx(time := 10.0) -> NpcContext:
	var c := NpcContext.new()
	c.memory = NpcMemory.new()
	c.time = time
	c.dt = 0.2
	c.needs = {&"duty": 0.0, &"charge": 0.0, &"curiosity": 0.0, &"fear": 0.0}
	c.record = NpcRecord.make(&"droid:t:0", &"maintenance_droid", &"ship:t", Vector3.ZERO, 7)
	return c

func _spot(key: StringName, at: Vector3, since: float) -> Dictionary:
	return {"key": key, "at": at, "since": since, "facing": Vector3i(0, 0, -1), "action": &"polish",
		"cell": Vector3i.ZERO}

func test_every_droid_behaviour_exists():
	var sp := NpcCatalog.load_from_dir("res://data/npcs").get_def(&"maintenance_droid")
	for id in sp.behaviours:
		assert_true(NpcBehaviours.exists(id), "%s" % id)
		assert_not_null(NpcBehaviours.make(id), "%s" % id)

func test_tend_scores_with_duty_and_not_with_fear():
	var tend := NpcBehaviours.make(&"tend")
	var c := _ctx()
	c.spots = [_spot(&"a", Vector3(2, 0, 0), 30.0)] as Array[Dictionary]
	assert_almost_eq(tend.score(c), 0.0, 0.001)
	c.needs[&"duty"] = 0.8
	assert_almost_eq(tend.score(c), 1.0, 0.001)
	c.needs[&"fear"] = 1.0
	assert_almost_eq(tend.score(c), 0.0, 0.001)
	c.needs[&"fear"] = 0.0
	c.spots = [] as Array[Dictionary]
	assert_almost_eq(tend.score(c), 0.0, 0.001, "nothing to tend")

func test_tend_picks_the_longest_left_but_never_the_one_by_you():
	var c := _ctx()
	c.spots = [_spot(&"fresh", Vector3(1, 0, 0), 5.0), _spot(&"old", Vector3(4, 0, 0), 200.0),
		_spot(&"older", Vector3(-4, 0, 0), 400.0)] as Array[Dictionary]
	var tend_script := load("res://src/npc/behaviours/tend.gd")
	assert_eq(tend_script.choose(c)["key"], &"older")
	c.player = Vector3(-4, 0, 0.5)
	assert_eq(tend_script.choose(c)["key"], &"old", "not the one beside you")

func test_tend_walks_there_works_and_says_so():
	var tend := NpcBehaviours.make(&"tend")
	var c := _ctx(0.0)
	c.needs[&"duty"] = 0.9
	c.spots = [_spot(&"a", Vector3(3, 0, 0), 100.0)] as Array[Dictionary]
	var told := []
	c.extra[&"tended"] = func(key: StringName, t: float) -> void: told.append([key, t])
	tend.start(c)
	var walking := tend.think(c)
	assert_eq(walking.move_to, Vector3(3, 0, 0))
	c.position = Vector3(3, 0, 0)
	var t := 0.0
	var working: Intent = null
	while not tend.done(c) and t < 20.0:
		t += 0.2
		c.time = t
		working = tend.think(c)
	assert_eq(working.action, &"polish")
	assert_eq(working.face, Vector3(3, 0, -1))
	assert_true(tend.done(c))
	assert_eq(told.size(), 1)
	assert_eq(told[0][0], &"a")
	assert_eq(c.voice, &"droid_chirp")
	assert_lt(c.need(&"duty"), 0.9)

func test_give_way_steps_away_from_you():
	var gw := NpcBehaviours.make(&"give_way")
	var c := _ctx()
	c.player = Vector3(0, 0, -2.5)
	assert_almost_eq(gw.score(c), 0.0, 0.001, "not yet closing")
	c.player = Vector3(0, 0, -2.0)
	assert_almost_eq(gw.score(c), 0.9, 0.001, "closing within 3 m")
	c.extra[&"nearby"] = [Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0), Vector3(0, 0, 0.6), Vector3(0, 0, -0.6)]
	gw.start(c)
	var i := gw.think(c)
	assert_eq(i.move_to, Vector3(0, 0, 0.6), "the spot farthest from you")
	assert_eq(i.face, Vector3(0, 0, -2.0), "facing you")

func test_notice_waits_for_you_to_stand_still():
	var n := NpcBehaviours.make(&"notice")
	var c := _ctx(0.0)
	c.needs[&"curiosity"] = 0.7
	c.player = Vector3(0, 0, -2)
	assert_almost_eq(n.score(c), 0.0, 0.001)
	c.time = 1.2
	assert_almost_eq(n.score(c), 1.0, 0.001, "still for a second")
	c.player_moving = true
	c.time = 1.4
	assert_almost_eq(n.score(c), 0.0, 0.001, "moving again")

func test_startle_fires_on_a_touch_and_frightens_it():
	var s := NpcBehaviours.make(&"startle")
	var c := _ctx()
	assert_false(s.score(c) >= s.threshold)
	c.memory.note(Stimulus.TOUCH, 5, Vector3(0, 0, -0.5), 0.7, c.time)
	assert_true(s.reflex)
	assert_true(s.score(c) >= s.threshold)
	c.extra[&"nearby"] = [Vector3(0, 0, -0.6), Vector3(0, 0, 0.6)]
	s.start(c)
	assert_almost_eq(c.need(&"fear"), 0.3, 0.001)
	assert_eq(c.voice, &"droid_beep")
	assert_eq(s.think(c).move_to, Vector3(0, 0, 0.6), "away from what touched it")

func test_a_quiet_sound_does_not_startle_it():
	var s := NpcBehaviours.make(&"startle")
	var c := _ctx()
	c.memory.note(Stimulus.SOUND, 5, Vector3(0, 0, -3), 0.3, c.time)
	assert_false(s.score(c) >= s.threshold)

func test_brace_fires_on_a_shake():
	var b := NpcBehaviours.make(&"brace")
	var c := _ctx()
	assert_false(b.score(c) >= b.threshold)
	c.memory.note(Stimulus.SHAKE, 0, Vector3.ZERO, 0.5, c.time)
	assert_true(b.score(c) >= b.threshold)
	assert_eq(b.think(c).action, &"brace")

func test_recharge_goes_home_and_charges():
	var r := NpcBehaviours.make(&"recharge")
	var c := _ctx()
	c.places[&"dock"] = Vector3(2, 0, 4)
	c.needs[&"charge"] = 1.0
	assert_almost_eq(r.score(c), 1.0, 0.001)
	assert_eq(r.think(c).move_to, Vector3(2, 0, 4))
	c.position = Vector3(2, 0, 4)
	assert_eq(r.think(c).action, &"dock")
	assert_lt(c.need(&"charge"), 1.0)

func test_keep_away_goes_to_a_room_you_are_not_in():
	var k := NpcBehaviours.make(&"keep_away")
	var c := _ctx()
	c.needs[&"fear"] = 0.9
	c.player = Vector3(0, 0, 0)
	c.extra[&"player_zone"] = &"galley"
	c.extra[&"rooms"] = [[Vector3(1, 0, 0), &"galley"], [Vector3(-4, 0, 2), &"bunk_room"], [Vector3(-1, 0, 0), &"bathroom"]]
	assert_almost_eq(k.score(c), 1.0, 0.001)
	k.start(c)
	assert_eq(k.think(c).move_to, Vector3(-4, 0, 2))
