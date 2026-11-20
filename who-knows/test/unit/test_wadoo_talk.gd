extends GutTest

## Talking with the Wadees (docs/superpowers/specs/2026-11-16-wadoo-design.md §6, §8):
## the talk seam on the body, the site choosing what is said, the panel showing it,
## converse turning them to you, and the Sunguard gathering at the breach once
## you take up the hunt.

const POOL_RADIUS := 11.0

var _layout: Dictionary
var _site: WadooSite
var _node: Node3D
var _state: WadooState
var _told: Array = []

func before_all():
	_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))

func before_each():
	_node = Node3D.new()
	add_child_autofree(_node)
	_site = WadooSite.new(_node, _layout, POOL_RADIUS, func(e: float, n: float) -> Vector3: return Vector3(e, 0.0, -n))
	_state = WadooState.new()
	_told = []
	_site.state = _state
	_site.on_talk = func(npc: Npc, person: Dictionary, said: Dictionary) -> void: _told.append([npc, person, said])

func _npc(n: int) -> Npc:
	var npc := Npc.new()
	autofree(npc)
	npc.record = WadooCast.record(n, _layout)
	npc.site = _site
	npc.species = load("res://data/npcs/%s.tres" % WadooCast.species_of(WadooCast.PEOPLE[n]["role"])) as NpcSpecies
	return npc

func _index(name: String) -> int:
	for n in WadooCast.count():
		if WadooCast.PEOPLE[n]["name"] == name:
			return n
	return -1

func _ctx(n: int) -> NpcContext:
	var c := NpcContext.new()
	c.record = WadooCast.record(n, _layout)
	c.position = Vector3(10.0, 0.0, -10.0)
	c.forward = Vector3.FORWARD
	c.player = Vector3(12.0, 0.0, -10.0)
	c.needs = {}
	c.extra[&"town"] = _site
	c.extra[&"person"] = WadooCast.person(n)
	c.extra[&"state"] = _site._state.get(c.record.id, &"")
	c.extra[&"talking"] = _site.talking == c.record.id
	c.extra[&"village"] = _state
	return c

func test_every_wadee_can_be_talked_to() -> void:
	for role in [&"villager", &"sunguard", &"queen"]:
		var species := load("res://data/npcs/%s.tres" % WadooCast.species_of(role)) as NpcSpecies
		assert_has(species.interactions, NpcTalk.ID, "%s talks" % role)
		assert_has(species.behaviours, &"converse", "%s turns to you" % role)

func test_the_body_offers_talk_through_its_site() -> void:
	var halla := _npc(_index("Halla"))
	assert_true(halla.can_interact(null))
	assert_eq(halla.prompt_text(), "Talk to Halla")
	assert_eq(_npc(0).prompt_text(), "Talk to Queen Imsa")
	halla.interact(null)
	assert_eq(_told.size(), 1)
	assert_string_contains(_told[0][2]["pages"][0], "pump")
	assert_eq(_site.talking, halla.record.id)
	var other := _npc(_index("Daro"))
	assert_false(other.can_interact(null), "one at a time")
	_site.end_talk()
	assert_true(other.can_interact(null))

func test_no_one_talks_indoors_or_unwired() -> void:
	var halla := _npc(_index("Halla"))
	_site._hidden[halla.record.id] = true
	assert_false(halla.can_interact(null), "indoors")
	_site._hidden.erase(halla.record.id)
	_site.on_talk = Callable()
	assert_false(halla.can_interact(null), "no panel to show it")

func test_converse_turns_to_you_and_talks() -> void:
	var b := NpcBehaviours.make(&"converse")
	var n := _index("Halla")
	assert_eq(b.score(_ctx(n)), 0.0)
	_site.talking = WadooCast.record(n, _layout).id
	var ctx := _ctx(n)
	assert_eq(b.score(ctx), 1.0)
	assert_true(b.reflex)
	var i := b.think(ctx)
	assert_eq(i.action, &"talk")
	assert_eq(i.face, ctx.player)
	_site.mark(ctx.record.id, &"seated")
	assert_eq(b.think(_ctx(n)).action, &"sit_talk", "seated, they talk where they sit")
	_site.end_talk()
	assert_true(b.done(_ctx(n)))

func test_gather_slots_kesh_first_and_oru_stays() -> void:
	assert_eq(WadooCast.gather_slot(WadooCast.person(_index("Kesh"))), 0)
	assert_eq(WadooCast.gather_slot(WadooCast.person(_index("Oru"))), -1)
	assert_eq(WadooCast.gather_slot(WadooCast.person(_index("Halla"))), -1)
	var slots := {}
	for name in ["Kesh", "Tarro", "Seli", "Nadi"]:
		slots[WadooCast.gather_slot(WadooCast.person(_index(name)))] = name
	assert_eq(slots.size(), 4)
	assert_eq(_site.spots(&"gather").size(), WadooSite.GATHER.size())
	for s: Dictionary in _site.spots(&"gather"):
		assert_true(_site.open(WadooSite.flat(s["at"])), "%s on open ground" % s["key"])

func test_gather_once_the_hunt_is_taken_up() -> void:
	var b := NpcBehaviours.make(&"gather")
	var kesh := _index("Kesh")
	assert_eq(b.score(_ctx(kesh)), 0.0)
	_state.answer_hunt(WadooState.HUNT_ACCEPTED)
	assert_eq(b.score(_ctx(kesh)), 0.9)
	assert_eq(b.score(_ctx(_index("Oru"))), 0.0, "Oru keeps his door")
	var i := b.think(_ctx(kesh))
	assert_not_null(i.move_to)
	assert_lt(WadooSite.flat(i.move_to).distance_to(WadooSite.flat(_site.spot(&"gather", "gather:0")["at"])), 0.01)
	var pose := _site.start_pose(WadooCast.record(kesh, _layout), 100.0)
	assert_lt(WadooSite.flat(pose.origin).distance_to(WadooSite.flat(_site.spot(&"gather", "gather:0")["at"])), 0.01,
		"she wakes at the breach")
	_state.turn_hostile()
	assert_eq(b.score(_ctx(kesh)), 0.0)

func test_the_panel_turns_pages_asks_and_replies() -> void:
	var panel := DialogPanel.new()
	add_child_autofree(panel)
	watch_signals(panel)
	panel.open("Queen Imsa", ["One.", "Two."], {"ask": "Will you?", "answers": [
		{"say": "Yes", "reply": ["Good."]}, {"say": "No"}]})
	assert_true(panel.is_open())
	assert_eq(panel.text_label.text, "One.")
	assert_eq(panel.name_label.text, "QUEEN IMSA")
	panel.pick(0)
	assert_eq(panel.text_label.text, "One.", "no answer before the question")
	panel.next()
	assert_eq(panel.text_label.text, "Two.")
	panel.next()
	assert_eq(panel.stage, &"choice")
	assert_eq(panel.text_label.text, "Will you?")
	assert_true(panel.answer_labels[0].visible)
	assert_eq(panel.answer_labels[1].text, "2   No")
	panel.next()
	assert_eq(panel.stage, &"choice", "F does not skip the question")
	panel.pick(0)
	assert_eq(panel.text_label.text, "Good.")
	panel.next()
	assert_false(panel.is_open())
	assert_signal_emitted_with_parameters(panel, "finished", [0])

func test_the_panel_shut_early_answers_nothing() -> void:
	var panel := DialogPanel.new()
	add_child_autofree(panel)
	watch_signals(panel)
	panel.open("Halla", ["One.", "Two."])
	panel.close()
	assert_signal_emitted_with_parameters(panel, "finished", [-1])
	panel.open("Halla", ["Only."])
	assert_eq(panel.hint_label.text, DialogPanel.LAST_HINT)
	panel.pick(1)
	panel.next()
	assert_false(panel.is_open())

func test_the_state_does_the_lines_then() -> void:
	assert_true(_state.apply("meet_queen"))
	assert_true(_state.met_queen)
	assert_true(_state.apply("hunt_later"))
	assert_eq(_state.hunt, WadooState.HUNT_LATER)
	assert_true(_state.apply("hunt_accepted"))
	_state.apply("hunt_later")
	assert_eq(_state.hunt, WadooState.HUNT_ACCEPTED, "taken up is taken up")
	assert_false(_state.apply("give_sun_cell"), "not the village's to do")

## Stage 3 (§7): holding what someone wants, [F] gives it; Wenna sees to you
## when you are hurt; Daro sets out a sun cell until the pump is mended.
func test_lio_takes_her_armlet_from_your_hands() -> void:
	var lio := _npc(_index("Lio"))
	var held := {"holding": "", "hurt": false}
	var given := []
	_site.you = func() -> Dictionary: return held
	_site.on_give = func(kind: StringName) -> bool:
		given.append(kind)
		held["holding"] = ""
		return true
	assert_eq(lio.prompt_text(), "Talk to Lio")
	held["holding"] = "sun_cell"
	assert_eq(lio.prompt_text(), "Talk to Lio", "not what she wants")
	held["holding"] = "armlet"
	assert_eq(lio.prompt_text(), "Give the armlet to Lio")
	lio.interact(null)
	assert_eq(given, [&"armlet"], "taken from your hands")
	assert_true(_state.did(&"armlet"))
	assert_eq(_state.regard, 1, "the town thinks better of you")
	assert_string_contains(_told[-1][2]["pages"][0], "armlet", "she thanks you")
	_site.end_talk()
	held["holding"] = "armlet"
	assert_eq(lio.prompt_text(), "Talk to Lio", "done: she takes no more")

func test_wenna_heals_you_when_you_are_hurt() -> void:
	var wenna := _npc(_index("Wenna"))
	var me := {"hurt": false}
	_site.you = func() -> Dictionary: return me
	assert_eq(wenna.prompt_text(), "Talk to Wenna")
	wenna.interact(null)
	assert_eq(_told[-1][2]["then"], "", "nothing to mend")
	_site.end_talk()
	me["hurt"] = true
	assert_eq(wenna.prompt_text(), "Ask Wenna to heal you")
	wenna.interact(null)
	assert_eq(_told[-1][2]["then"], "heal")
	assert_eq(_npc(_index("Halla")).prompt_text(), "Talk to Halla", "only Wenna heals")

func test_daro_sets_out_a_cell_until_the_pump_is_mended() -> void:
	var daro := _npc(_index("Daro"))
	daro.interact(null)
	assert_eq(_told[-1][2]["then"], "make_cell")
	_site.end_talk()
	_state.make_cell()
	daro.interact(null)
	assert_eq(_told[-1][2]["then"], "make_cell", "again, in case it was lost")
	_site.end_talk()
	_site.you = func() -> Dictionary: return {"holding": "sun_cell"}
	daro.interact(null)
	assert_eq(_told[-1][2]["then"], "", "you are carrying it")
	_site.end_talk()
	var halla := _npc(_index("Halla"))
	halla.interact(null)
	assert_string_contains(_told[-1][2]["pages"][0], "cell", "Halla sees it in your hands")
	_site.end_talk()
	_state.do_task(&"pump")
	daro.interact(null)
	assert_eq(_told[-1][2]["then"], "")
	var back := WadooState.from_dict(_state.to_dict())
	assert_true(back.cell_made, "saved")
