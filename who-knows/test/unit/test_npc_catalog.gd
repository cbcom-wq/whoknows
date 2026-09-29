extends GutTest

## Every species in data/npcs is wired up (.claude/skills/building-an-npc):
## its behaviours, locomotors, look and sound exist; its needs start where they
## rise; its fade makes sense. A new species is checked here without anyone
## writing a test for it.

var _catalog: NpcCatalog

func before_all():
	_catalog = NpcCatalog.load_from_dir("res://data/npcs")

func test_there_are_species():
	assert_gt(_catalog.ids().size(), 0)

func test_each_file_is_named_for_its_species():
	for file in DirAccess.get_files_at("res://data/npcs"):
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var def := ResourceLoader.load("res://data/npcs/" + name) as NpcSpecies
		assert_not_null(def, "%s is an NpcSpecies" % name)
		if def != null:
			assert_eq(String(def.id) + ".tres", name, "a species' file is its id")

func test_every_behaviour_exists_and_every_weight_names_one():
	for id in _catalog.ids():
		var sp := _catalog.get_def(id)
		assert_gt(sp.behaviours.size(), 0, "%s does something" % id)
		for b in sp.behaviours:
			assert_true(NpcBehaviours.exists(b), "%s: no behaviour file src/npc/behaviours/%s.gd" % [id, b])
			var made := NpcBehaviours.make(b)
			assert_not_null(made, "%s: %s does not extend Behaviour" % [id, b])
		for w in sp.behaviour_weights:
			assert_true(sp.behaviours.has(w), "%s weights %s, which it does not have" % [id, w])

func test_every_locomotor_exists():
	for id in _catalog.ids():
		var sp := _catalog.get_def(id)
		assert_gt(sp.locomotors.size(), 0, "%s moves" % id)
		for l in sp.locomotors:
			assert_not_null(Npc.make_locomotor(l), "%s: add %s to Npc.make_locomotor" % [id, l])

func test_every_look_is_built_not_a_placeholder():
	for id in _catalog.ids():
		var sp := _catalog.get_def(id)
		var look := autofree(NpcLooks.build(sp.look, 0.5, sp.live_radius <= 0.0, SpacePalette.UNTINTED, sp.fade)) as Node3D
		assert_null(look.get_node_or_null("Placeholder"), "%s: add %s to NpcLooks.build" % [id, sp.look])

func test_a_move_sound_is_a_looping_synth_sound():
	for id in _catalog.ids():
		var sp := _catalog.get_def(id)
		if sp.move_sound != &"":
			assert_true(Synth.NAMES.has(sp.move_sound), "%s: no Synth sound %s" % [id, sp.move_sound])
			assert_true(Synth.LOOPED.has(sp.move_sound), "%s: %s must loop" % [id, sp.move_sound])

func test_needs_have_starting_ranges():
	for id in _catalog.ids():
		var sp := _catalog.get_def(id)
		for n in sp.needs:
			assert_true(sp.need_start.has(n), "%s: %s has no need_start" % [id, n])
			var r: Vector2 = sp.need_start.get(n, Vector2.ZERO)
			assert_true(r.x >= 0.0 and r.y <= 1.0 and r.x <= r.y, "%s: %s starts in [0, 1]" % [id, n])
		for n in sp.need_start:
			assert_true(sp.needs.has(n), "%s: %s starts but never rises" % [id, n])

func test_bodies_and_senses_are_sane():
	for id in _catalog.ids():
		var sp := _catalog.get_def(id)
		assert_true(sp.size > 0.0 and sp.height > 0.0 and sp.width > 0.0 and sp.mass > 0.0, "%s has a body" % id)
		assert_gt(sp.top_speed, 0.0, "%s can move" % id)
		assert_true(sp.sight_cone_deg > 0.0 and sp.sight_cone_deg <= 360.0, "%s's cone is its whole width" % id)
		assert_between(sp.light_response, -1.0, 1.0, "%s's light response" % id)
		if sp.live_radius > 0.0:
			assert_true(sp.fade.x > 0.0 and sp.fade.x < sp.fade.y, "%s fades in: whole within x, gone past y" % id)
			assert_lt(sp.fade.y, sp.live_radius, "%s wakes beyond where it can be seen" % id)

## Health and damage spec §6: every species can be hurt, and says whether it
## dies or is knocked out.
func test_every_species_has_health():
	for id in _catalog.ids():
		var sp := _catalog.get_def(id)
		assert_gt(sp.max_health, 0.0, "%s can be hurt" % id)
		assert_between(sp.wake_health, 0.0, 1.0, "%s gets up with a share of its health" % id)

func test_the_two_species_read_back():
	assert_eq(_catalog.get_def(&"skitter").max_health, 40.0)
	assert_eq(_catalog.get_def(&"skitter").knocked_out_for, 0.0, "a skitter dies")
	assert_eq(_catalog.get_def(&"maintenance_droid").max_health, 60.0)
	assert_eq(_catalog.get_def(&"maintenance_droid").knocked_out_for, 60.0, "the droid is knocked out")
	assert_eq(_catalog.get_def(&"maintenance_droid").wake_health, 0.25)
