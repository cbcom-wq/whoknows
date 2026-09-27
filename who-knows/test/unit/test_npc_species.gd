extends GutTest

## The two species as authored (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §8, §13.1, §14.1), read back at runtime:
## a .tres can drop a property silently (CLAUDE.md), so every value is checked.

var _catalog: NpcCatalog

func before_each():
	_catalog = NpcCatalog.load_from_dir("res://data/npcs")

func test_the_catalogue_finds_both_species():
	assert_true(_catalog.has(&"maintenance_droid"))
	assert_true(_catalog.has(&"skitter"))

func test_the_droid_reads_back_as_authored():
	var d := _catalog.get_def(&"maintenance_droid")
	assert_eq(d.display_name, "Maintenance droid")
	assert_almost_eq(d.size, 0.55, 0.0001)
	assert_almost_eq(d.height, 0.55, 0.0001)
	assert_almost_eq(d.width, 0.5, 0.0001)
	assert_almost_eq(d.mass, 40.0, 0.0001)
	assert_almost_eq(d.top_speed, 1.8, 0.0001)
	assert_eq(d.locomotors, [&"deck_walker"] as Array[StringName])
	assert_eq(d.look, &"droid")
	assert_eq(d.move_sound, &"droid_whir")
	assert_almost_eq(d.sight_range, 8.0, 0.0001)
	assert_almost_eq(d.sight_cone_deg, 140.0, 0.0001)
	assert_almost_eq(d.dark_sight, 1.0, 0.0001)
	assert_almost_eq(d.near_sense, 3.0, 0.0001)
	assert_almost_eq(d.feels_vibration, 0.0, 0.0001)
	assert_almost_eq(d.hears, 1.0, 0.0001)
	assert_almost_eq(d.feels_shake, 1.0, 0.0001)
	assert_almost_eq(d.light_response, 0.0, 0.0001)
	assert_almost_eq(float(d.needs[&"duty"]), 0.02, 0.0001)
	assert_almost_eq(float(d.needs[&"charge"]), 0.004, 0.0001)
	assert_almost_eq(float(d.needs[&"curiosity"]), 0.01, 0.0001)
	assert_almost_eq(float(d.needs[&"fear"]), 0.0, 0.0001)
	assert_eq(d.need_start[&"duty"], Vector2(0.3, 0.7))
	assert_eq(d.need_start[&"charge"], Vector2(0, 0.3))
	assert_eq(d.behaviours, [&"tend", &"roam", &"recharge", &"give_way", &"notice", &"startle",
		&"brace", &"keep_away"] as Array[StringName])
	assert_almost_eq(d.fear_of_player, 0.1, 0.0001)
	assert_almost_eq(d.curiosity_about_player, 0.6, 0.0001)
	assert_eq(d.population, &"ship_crew")
	assert_almost_eq(d.live_radius, 0.0, 0.0001)
	assert_eq(d.fade, Vector2.ZERO)
	assert_eq(d.interactions.size(), 0)

func test_the_skitter_reads_back_as_authored():
	var s := _catalog.get_def(&"skitter")
	assert_eq(s.display_name, "Skitter")
	assert_almost_eq(s.size, 1.3, 0.0001)
	assert_almost_eq(s.height, 0.6, 0.0001)
	assert_almost_eq(s.width, 0.75, 0.0001)
	assert_almost_eq(s.mass, 90.0, 0.0001)
	assert_almost_eq(s.top_speed, 4.0, 0.0001)
	assert_eq(s.locomotors, [&"surface_crawler", &"zero_g_drift"] as Array[StringName])
	assert_eq(s.look, &"skitter")
	assert_eq(s.move_sound, &"")
	assert_almost_eq(s.sight_range, 40.0, 0.0001)
	assert_almost_eq(s.sight_cone_deg, 220.0, 0.0001)
	assert_almost_eq(s.dark_sight, 0.33, 0.0001)
	assert_almost_eq(s.near_sense, 2.0, 0.0001)
	assert_almost_eq(s.feels_vibration, 1.0, 0.0001)
	assert_almost_eq(s.hears, 0.0, 0.0001)
	assert_almost_eq(s.feels_shake, 0.0, 0.0001)
	assert_almost_eq(s.light_response, -1.0, 0.0001)
	assert_almost_eq(float(s.needs[&"hunger"]), 0.006, 0.0001)
	assert_almost_eq(float(s.needs[&"company"]), 0.01, 0.0001)
	assert_almost_eq(float(s.needs[&"curiosity"]), 0.008, 0.0001)
	assert_almost_eq(float(s.needs[&"rest"]), 0.003, 0.0001)
	assert_almost_eq(float(s.needs[&"fear"]), 0.0, 0.0001)
	assert_eq(s.need_start[&"hunger"], Vector2(0.2, 0.6))
	assert_eq(s.need_start[&"rest"], Vector2(0, 0.4))
	assert_eq(s.behaviours, [&"graze", &"wander", &"stay_with_herd", &"freeze", &"scatter", &"hide",
		&"investigate", &"rest", &"drawn_to_flare"] as Array[StringName])
	assert_almost_eq(s.fear_of_player, 0.5, 0.0001)
	assert_almost_eq(s.curiosity_about_player, 0.4, 0.0001)
	assert_eq(s.population, &"rock_herds")
	assert_almost_eq(s.live_radius, 350.0, 0.0001)
	assert_eq(s.fade, Vector2(250, 300))
	assert_eq(s.interactions.size(), 0)

func test_layer_eight_is_named_npcs():
	assert_eq(ProjectSettings.get_setting("layer_names/3d_physics/layer_8"), "npcs")

func test_records_and_stimuli_are_plain_data():
	var r := NpcRecord.make(&"skitter:x:0:1", &"skitter", &"rock:x", Vector3(1, 2, 3), 42, 0)
	assert_eq(r.id, &"skitter:x:0:1")
	assert_eq(r.home, Vector3(1, 2, 3))
	assert_eq(r.herd, 0)
	var s := Stimulus.make(Stimulus.SOUND, Vector3.ZERO, 1.0, 10.0)
	assert_almost_eq(s.felt_at(Vector3(5, 0, 0)), 0.5, 0.0001)
	assert_almost_eq(s.felt_at(Vector3(20, 0, 0)), 0.0, 0.0001)
	var shake := Stimulus.make(Stimulus.SHAKE, Vector3.ZERO, 0.7, 0.0)
	assert_almost_eq(shake.felt_at(Vector3(500, 0, 0)), 0.7, 0.0001)
	var i := Intent.go(Vector3(1, 0, 0), 0.5, &"graze").facing(Vector3(2, 0, 0))
	assert_eq(i.move_to, Vector3(1, 0, 0))
	assert_eq(i.face, Vector3(2, 0, 0))
	assert_eq(i.action, &"graze")
