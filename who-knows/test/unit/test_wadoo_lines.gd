extends GutTest

## The village's state and what the Wadees say from it (Wadoo spec §6-§8).

func _person(name: String) -> Dictionary:
	return WadooCast.person(WadooCast.index_of(WadooCast.ID % _index(name)))

func _index(name: String) -> int:
	for n in WadooCast.count():
		if WadooCast.PEOPLE[n]["name"] == name:
			return n
	return -1

func _say(name: String, state: WadooState) -> Dictionary:
	return WadooLines.shared().pick(_person(name), state, StringName(name))

func test_state_round_trips() -> void:
	var s := WadooState.new()
	s.do_task(&"pump")
	s.do_task(&"lilies")
	s.do_task(&"lilies")
	s.meet_queen()
	s.answer_hunt(WadooState.HUNT_LATER)
	s.heard_from(&"wadee:wadoo:1")
	var back := WadooState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.regard, 2)
	assert_true(back.did(&"pump"))
	assert_false(back.did(&"armlet"))
	assert_eq(int(back.tasks[&"lilies"]), 2)
	assert_true(back.met_queen)
	assert_eq(back.hunt, WadooState.HUNT_LATER)
	assert_false(back.hostile)
	assert_eq(int(back.heard[&"wadee:wadoo:1"]), 1)

func test_an_empty_save_is_a_stranger() -> void:
	var s := WadooState.from_dict({})
	assert_eq(s.regard, 0)
	assert_false(s.door_open())
	assert_eq(s.hunt, WadooState.HUNT_NONE)

func test_each_task_raises_regard_once() -> void:
	var s := WadooState.new()
	assert_true(s.do_task(&"pump"))
	assert_false(s.do_task(&"pump"), "the pump is woken once")
	for k in 6:
		assert_true(s.do_task(&"lilies"))
	assert_false(s.do_task(&"lilies"), "six lilies at most")
	assert_eq(s.regard, 2)
	s.do_task(&"armlet")
	assert_eq(s.regard, WadooState.REGARD_MAX)
	assert_eq(s.tasks_done(), 3)

func test_the_door_opens_at_regard_one_and_shuts_for_good_on_harm() -> void:
	var s := WadooState.new()
	assert_false(s.door_open())
	s.do_task(&"armlet")
	assert_true(s.door_open())
	s.turn_hostile()
	assert_false(s.door_open())

func test_every_line_parses_and_names_a_real_speaker() -> void:
	var lines := WadooLines.shared().lines
	assert_gt(lines.size(), 40)
	var names := []
	for p: Dictionary in WadooCast.PEOPLE:
		names.append(p["name"])
	for line: Dictionary in lines:
		var who := str(line["who"])
		if who == "*" or who.begins_with("#"):
			continue
		if who.begins_with("@"):
			assert_has(["@villager", "@sunguard"], who)
		else:
			assert_has(names, who, "%s is in the cast" % who)
		assert_false((line.get("pages", []) as Array).is_empty(), "%s says something" % who)

func test_everyone_has_something_to_say_as_a_stranger_and_as_a_friend() -> void:
	for regard in [0, 1, 3]:
		var s := WadooState.new()
		s.regard = regard
		for p: Dictionary in WadooCast.PEOPLE:
			var said := WadooLines.shared().pick(_person(p["name"]), s, StringName(p["name"]))
			assert_false(said.is_empty(), "%s at regard %d" % [p["name"], regard])

func test_oru_keeps_the_door_until_regard_one() -> void:
	var s := WadooState.new()
	assert_string_contains(_say("Oru", s)["pages"][0], "does not receive strangers")
	s.do_task(&"pump")
	assert_string_contains(_say("Oru", s)["pages"][0], "Go in")

func test_a_name_beats_a_trait_beats_a_role() -> void:
	var s := WadooState.new()
	# Halla grieves, but her own line is about her garden
	assert_string_contains(_say("Halla", s)["pages"][0], "pump")
	# Lio's own line: her mother's armlet; once found, her thanks
	assert_string_contains(_say("Lio", s)["pages"][0], "armlet")
	s.do_task(&"armlet")
	assert_string_contains(" ".join(_say("Lio", s)["pages"]), "wear it")

func test_a_speaker_goes_through_equal_lines_in_turn() -> void:
	var s := WadooState.new()
	var first: String = _say("Asha", s)["pages"][0]
	# Asha has one line of her own: always that
	assert_eq(_say("Asha", s)["pages"][0], first)
	# a stranger's lines for a plain villager (Sabi has her own; use the role)
	var villager := {"name": "Nobody", "role": &"villager"}
	var seen := {}
	for k in 5:
		seen[WadooLines.shared().pick(villager, s, &"nobody")["pages"][0]] = true
	assert_eq(seen.size(), 5, "five stranger lines, each in turn")

func test_the_queen_receives_you_names_your_deeds_and_asks() -> void:
	var s := WadooState.new()
	s.do_task(&"pump")
	s.do_task(&"lilies")
	var said := _say("Imsa", s)
	assert_eq(said["then"], "meet_queen")
	assert_string_contains(said["pages"][0], "You woke Halla's pump and you laid a lily for our dead")
	assert_eq((said["choice"]["answers"] as Array).size(), 2)
	assert_eq(said["choice"]["answers"][0]["then"], "hunt_accepted")
	s.meet_queen()
	s.answer_hunt(WadooState.HUNT_LATER)
	said = _say("Imsa", s)
	assert_eq(said["pages"], ["You have come back."])
	assert_false((said["choice"] as Dictionary).is_empty(), "asks again")
	s.answer_hunt(WadooState.HUNT_ACCEPTED)
	assert_string_contains(_say("Imsa", s)["pages"][0], "breach")
	assert_string_contains(_say("Kesh", s)["pages"][0], "When you are ready")

func test_hostile_they_say_nothing_kind() -> void:
	var s := WadooState.new()
	s.do_task(&"pump")
	s.turn_hostile()
	assert_eq(_say("Halla", s)["pages"][0], "They will not look at you.")
	assert_eq(_say("Imsa", s)["pages"][0], "Leave my hall.")

func test_deeds_read_as_a_sentence() -> void:
	assert_eq(WadooLines.deeds({}), "You came to us")
	assert_eq(WadooLines.deeds({"task:armlet": true}), "You found Lio's armlet")
	assert_eq(WadooLines.deeds({"task:pump": true, "task:armlet": true, "task:lilies": true}),
		"You woke Halla's pump, you found Lio's armlet and you laid a lily for our dead")
