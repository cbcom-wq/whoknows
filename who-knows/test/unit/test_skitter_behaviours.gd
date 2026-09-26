extends GutTest

## The skitter's behaviours (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.2), each from a made-up context.

func _ctx(seed := 7, time := 10.0) -> NpcContext:
	var c := NpcContext.new()
	c.memory = NpcMemory.new()
	c.time = time
	c.dt = 0.2
	c.needs = {&"hunger": 0.0, &"company": 0.0, &"curiosity": 0.0, &"rest": 0.0, &"fear": 0.0}
	c.record = NpcRecord.make(&"skitter:t:0:0", &"skitter", &"rock:t", Vector3.ZERO, seed, 0)
	c.species = NpcCatalog.load_from_dir("res://data/npcs").get_def(&"skitter")
	c.up = Vector3.UP
	c.forward = Vector3.FORWARD
	return c

func test_every_skitter_behaviour_exists():
	var sp := NpcCatalog.load_from_dir("res://data/npcs").get_def(&"skitter")
	for id in sp.behaviours:
		assert_true(NpcBehaviours.exists(id), "%s" % id)
	for sp_id in [&"skitter", &"maintenance_droid"]:
		var species := NpcCatalog.load_from_dir("res://data/npcs").get_def(sp_id)
		for loco in species.locomotors:
			assert_not_null(Npc.make_locomotor(loco), "%s" % loco)
		var look := autofree(NpcLooks.build(species.look, 0.0, false)) as Node3D
		assert_null(look.get_node_or_null("Placeholder"), "%s has a look" % sp_id)

func test_freeze_fires_when_lit_and_not_otherwise():
	var f := NpcBehaviours.make(&"freeze")
	var c := _ctx()
	assert_true(f.reflex)
	assert_lt(f.score(c), f.threshold)
	c.lit = true
	assert_gt(f.score(c), f.threshold)
	assert_eq(f.think(c).action, &"freeze")

func test_freeze_fires_when_you_move_near():
	var f := NpcBehaviours.make(&"freeze")
	var c := _ctx()
	c.player = Vector3(0, 0, -8)
	assert_lt(f.score(c), f.threshold, "you are still")
	c.player_moving = true
	assert_gt(f.score(c), f.threshold, "you moved")

func test_scatter_fires_on_a_vibration_and_fans_the_herd_out():
	var dirs: Array[Vector3] = []
	for seed in [1, 500, 999]:
		var s := NpcBehaviours.make(&"scatter")
		var c := _ctx(seed)
		c.memory.note(Stimulus.VIBRATION, 0, Vector3(0, 0, 10), 0.8, c.time)
		assert_gt(s.score(c), s.threshold)
		s.start(c)
		var i := s.think(c)
		var to: Vector3 = i.move_to
		dirs.append(to.normalized())
		assert_lt(to.z, 0.0, "away from the jolt")
		assert_almost_eq(c.need(&"fear"), 0.4, 0.001)
	assert_gt(dirs[0].angle_to(dirs[2]), deg_to_rad(60.0), "the herd fans out")

func test_scatter_sometimes_leaps():
	var s := NpcBehaviours.make(&"scatter")
	var c := _ctx(3)
	c.memory.note(Stimulus.TOUCH, 0, Vector3(0, 0, 1), 0.8, c.time)
	s.start(c)
	var i := s.think(c)
	assert_eq(i.action, &"leap", "seed 3 leaps")
	assert_not_null(i.leap_to)
	assert_ne(s.think(c).action, &"leap", "once")

func test_a_mate_bolting_sets_it_off():
	var s := NpcBehaviours.make(&"scatter")
	var c := _ctx()
	c.memory.note(Perception.MATE_BOLTED, 9, Vector3(3, 0, 0), 0.8, c.time)
	assert_gt(s.score(c), s.threshold)

func test_graze_and_hide_and_rest_go_where_they_should():
	var g := NpcBehaviours.make(&"graze")
	var c := _ctx()
	c.needs[&"hunger"] = 0.8
	c.extra[&"graze"] = Vector3(20, 0, 0)
	assert_almost_eq(g.score(c), 1.0, 0.001)
	assert_lt((g.think(c).move_to as Vector3).distance_to(Vector3(20, 0, 0)), 1.6)
	var h := NpcBehaviours.make(&"hide")
	c.needs[&"fear"] = 0.9
	c.places[&"shelter"] = Vector3(-10, 0, 0)
	assert_almost_eq(h.score(c), 1.0, 0.001)
	assert_eq(h.think(c).move_to, Vector3(-10, 0, 0))
	c.position = Vector3(-10, 0, 0)
	assert_eq(h.think(c).action, &"freeze")

func test_investigate_stops_six_metres_off():
	var inv := NpcBehaviours.make(&"investigate")
	var c := _ctx()
	c.needs[&"curiosity"] = 1.0
	c.player = Vector3(0, 0, -20)
	assert_almost_eq(inv.score(c), 1.0, 0.001)
	var i := inv.think(c)
	assert_almost_eq((i.move_to as Vector3).distance_to(Vector3(0, 0, -20)), 6.0, 0.01)
	c.position = Vector3(0, 0, -15)
	assert_null(inv.think(c).move_to, "close enough: it stops and looks")

func test_drawn_to_a_still_flare_but_not_a_moving_one():
	var d := NpcBehaviours.make(&"drawn_to_flare")
	var c := _ctx()
	c.memory.note(Perception.FLARE, 3, Vector3(0, 0, -30), 1.0, c.time)
	assert_gt(d.score(c), 0.5)
	var i := d.think(c)
	assert_almost_eq((i.move_to as Vector3).distance_to(Vector3(0, 0, -30)), 6.0, 0.01, "to the light's edge")
	c.extra[&"flare_moving"] = true
	assert_almost_eq(d.score(c), 0.0, 0.001)
