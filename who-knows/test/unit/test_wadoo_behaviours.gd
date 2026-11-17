extends GutTest

## Wadoo's behaviours (docs/superpowers/specs/2026-11-16-wadoo-design.md §5), each from
## a made-up context on the real town (a flat ground): they score from their needs,
## walk to a spot they hold, turn to it, do its action for their time, ease their
## need and let the spot go.

const POOL_RADIUS := 11.0
const DT := 0.2
const WHO := &"wadee:wadoo:7"

var _layout: Dictionary
var _site: WadooSite
var _node: Node3D
## The simulated body: where it is and which way it faces, moved by its intents.
var _at := Vector3.ZERO
var _fwd := Vector3.FORWARD
var _needs := {}
var _time := 0.0
var _person := {}

func before_all():
	_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))

func before_each():
	_node = Node3D.new()
	add_child_autofree(_node)
	_site = WadooSite.new(_node, _layout, POOL_RADIUS, func(e: float, n: float) -> Vector3: return Vector3(e, 0.0, -n))
	_at = _site.ground(_site.paths.nearest_open(Vector2(14.0, 10.0)))
	_fwd = Vector3.FORWARD
	_needs = {&"work": 0.9, &"rest": 0.0, &"company": 0.0, &"thirst": 0.0, &"grief": 0.0, &"home": 0.0, &"fear": 0.0}
	_time = 100.0
	_person = WadooCast.person(7)

func _ctx(who := WHO) -> NpcContext:
	var c := NpcContext.new()
	c.record = NpcRecord.make(who, &"wadee_villager", &"wadoo", Vector3.ZERO, 1234)
	c.needs = _needs
	c.time = _time
	c.dt = DT
	c.position = _at
	c.forward = _fwd
	c.extra[&"town"] = _site
	c.extra[&"person"] = _person
	c.extra[&"pair"] = _site.pair_of(who)
	c.extra[&"state"] = _site._state.get(who, &"")
	if _site.hidden(who):
		c.extra[&"indoors"] = true
	c.extra[&"nearby"] = [_at + Vector3(2, 0, 0), _at + Vector3(-2, 0, 0), _at + Vector3(0, 0, 2)]
	return c

## One think: the body goes where it is sent and turns where it is told.
func _think(b: Behaviour, ctx: NpcContext) -> Intent:
	var i := b.think(ctx)
	if i.move_to != null:
		var to: Vector3 = i.move_to
		if Behaviour.flat_distance(to, _at) > 0.01:
			_fwd = Vector3(to.x - _at.x, 0.0, to.z - _at.z).normalized()
		_at = to
	elif i.face != null:
		var f: Vector3 = i.face
		if Behaviour.flat_distance(f, _at) > 0.05:
			_fwd = Vector3(f.x - _at.x, 0.0, f.z - _at.z).normalized()
	_time += DT
	return i

## Runs `b` from its start for up to `seconds`; the intents, in order.
func _run(b: Behaviour, seconds: float, who := WHO) -> Array[Intent]:
	b.start(_ctx(who))
	var out: Array[Intent] = []
	for k in int(seconds / DT):
		var ctx := _ctx(who)
		if b.done(ctx):
			break
		out.append(_think(b, ctx))
	return out

static func _actions(intents: Array[Intent]) -> Array:
	var out := []
	for i in intents:
		if out.is_empty() or out[out.size() - 1] != i.action:
			out.append(i.action)
	return out

func test_work_goes_to_a_job_and_does_it():
	var b := NpcBehaviours.make(&"work")
	assert_gt(b.score(_ctx()), 0.9, "much work to do")
	_needs[&"work"] = 0.1
	assert_eq(b.score(_ctx()), 0.0)
	_needs[&"work"] = 0.9
	_person = WadooCast.person(7).duplicate()
	_person["jobs"] = ["glass"]
	var intents := _run(b, 120.0)
	assert_not_null(intents[0].move_to, "it walks there first")
	assert_eq(intents[0].speed, WadooErrand.WALK)
	var acts := _actions(intents)
	assert_true(acts.has(&"kneel") or acts.has(&"interact"), "and works glass: %s" % [acts])
	assert_true(b.done(_ctx()), "for a while, then it is done")
	assert_lt(_needs[&"work"], 0.5, "it eased its work")
	for s: Dictionary in _site.spots(&"glass"):
		assert_null(_site.holder_of(s["key"]), "and let the spot go")

func test_work_holds_its_spot_while_there():
	var b := NpcBehaviours.make(&"work")
	_person = WadooCast.person(7).duplicate()
	_person["jobs"] = ["garden"]
	b.start(_ctx())
	var key: String = (b as WadooErrand).spot["key"]
	assert_eq(_site.holder_of(key), WHO)
	var other := NpcBehaviours.make(&"work")
	other.start(_ctx(&"wadee:wadoo:8"))
	assert_ne((other as WadooErrand).spot["key"], key, "another takes another spot")

func test_a_pump_job_carries_water_home():
	var b := NpcBehaviours.make(&"work")
	_person = WadooCast.person(7).duplicate()
	_person["jobs"] = ["pump"]
	var intents := _run(b, 120.0)
	var acts := _actions(intents)
	assert_true(acts.has(&"interact"), "works the pump: %s" % [acts])
	assert_gt(acts.find(&"carry"), acts.find(&"interact"), "then carries the water: %s" % [acts])
	var door := _site.door_of(_person["home"])
	assert_lt(Behaviour.flat_distance(_at, door["at"]), 0.4, "home")

func test_rest_sits_and_rises():
	_needs[&"rest"] = 0.9
	var b := NpcBehaviours.make(&"rest_shade")
	assert_gt(b.score(_ctx()), 0.9)
	var seated := [false]
	b.start(_ctx())
	var intents: Array[Intent] = []
	for k in int(120.0 / DT):
		var ctx := _ctx()
		if b.done(ctx):
			break
		intents.append(_think(b, ctx))
		if _site._state.get(WHO, &"") == &"seated":
			seated[0] = true
	var acts := _actions(intents)
	assert_true(acts.has(&"sit"), "sits: %s" % [acts])
	assert_eq(acts[acts.size() - 1], &"rise", "gets up last: %s" % [acts])
	assert_true(seated[0], "the town knows they sat")
	assert_eq(_site._state.get(WHO, &""), &"", "and that they got up")
	assert_lt(_needs[&"rest"], 0.5)

func test_rest_talks_with_company():
	_needs[&"rest"] = 0.9
	var b := NpcBehaviours.make(&"rest_shade")
	b.start(_ctx())
	var key: String = (b as WadooErrand).spot["key"]
	var parts := key.split(":")
	var across := "shade:%d:%s" % [int(parts[1]) ^ 1, parts[2]]
	_site._claims[across] = &"someone"
	var acts := []
	for k in int(60.0 / DT):
		acts.append(_think(b, _ctx()).action)
	assert_true(acts.has(&"sit_talk"), "talks with whoever sits across")

func test_talk_pair_meets_and_talks_by_turns():
	_site._pairs[WHO] = {"partner": &"wadee:wadoo:9", "at": _at + Vector3(3, 0, 0), "face": _at + Vector3(4.1, 0, 0)}
	_site._pairs[&"wadee:wadoo:9"] = {"partner": WHO, "at": _at + Vector3(4.1, 0, 0), "face": _at + Vector3(3, 0, 0)}
	var b := NpcBehaviours.make(&"talk_pair")
	assert_eq(b.score(_ctx()), 0.95, "answers a partner at once")
	_needs[&"company"] = 0.9
	var acts := _actions(_run(b, 60.0))
	assert_true(acts.has(&"talk"), "talks: %s" % [acts])
	assert_true(acts.has(&""), "and listens: %s" % [acts])
	assert_true(_site.pair_of(&"wadee:wadoo:9").is_empty(), "the talk ends for both")
	assert_lt(_needs[&"company"], 0.6)

func test_talk_pair_alone_waits_before_asking_again():
	_needs[&"company"] = 0.9
	var b := NpcBehaviours.make(&"talk_pair")
	assert_gt(b.score(_ctx()), 0.7)
	b.start(_ctx())
	assert_true(b.done(_ctx()), "no one to talk with")
	assert_eq(b.score(_ctx()), 0.0, "so it does not ask at once again")

func test_drink_at_the_bank():
	_needs[&"thirst"] = 0.9
	var b := NpcBehaviours.make(&"drink")
	assert_gt(b.score(_ctx()), 0.9)
	var acts := _actions(_run(b, 40.0))
	assert_true(acts.has(&"drink"), "%s" % [acts])
	assert_lt(_needs[&"thirst"], 0.1)

func test_mourn_only_who_grieves():
	_needs[&"grief"] = 0.9
	var b := NpcBehaviours.make(&"mourn")
	_person = WadooCast.person(7)
	assert_false(_person["grief"], "Daro lost no one")
	assert_eq(b.score(_ctx()), 0.0)
	_person = WadooCast.person(6)
	assert_true(_person["grief"], "Halla did")
	assert_gt(b.score(_ctx()), 0.9)
	var acts := _actions(_run(b, 90.0))
	assert_true(acts.has(&"kneel"), "kneels at the memorial: %s" % [acts])
	var m: Array = _layout["memorial"]["at"]
	assert_lt(Behaviour.flat_distance(_at, Vector3(m[0], 0, -m[1])), 4.0)

func test_go_home_hides_then_comes_out():
	_needs[&"home"] = 0.95
	var b := NpcBehaviours.make(&"go_home")
	assert_gt(b.score(_ctx()), 0.9)
	b.start(_ctx())
	var was_in := [false]
	for k in int(150.0 / DT):
		var ctx := _ctx()
		if b.done(ctx):
			break
		_think(b, ctx)
		if _site.hidden(WHO):
			was_in[0] = true
			assert_eq(b.score(_ctx()), 1.0, "indoors it stays in")
	assert_true(was_in[0], "went in")
	assert_false(_site.hidden(WHO), "and came out")
	var door := _site.door_of(_person["home"])
	assert_lt(Behaviour.flat_distance(_at, door["door"]), 0.5)

func test_keep_post_and_the_breach_walk():
	_person = WadooCast.person(2)
	var b := NpcBehaviours.make(&"keep_post")
	assert_eq(b.score(_ctx()), 0.5)
	var acts := _actions(_run(b, 10.0))
	assert_true(acts.has(&"watch"), "Oru keeps the queen's door: %s" % [acts])
	assert_lt(Behaviour.flat_distance(_at, _site.spot(&"post", "post:queen_door")["at"]), 0.35)
	_person = WadooCast.person(1)
	var ends := {}
	b.start(_ctx())
	for k in int(130.0 / DT):
		_think(b, _ctx())
		for e in 2:
			if Behaviour.flat_distance(_at, _site.spot(&"post", "post:breach_walk:%d" % e)["at"]) < 0.35:
				ends[e] = true
	assert_eq(ends.size(), 2, "Kesh walks the breach end to end")

func test_greet_once_and_nod():
	var b := NpcBehaviours.make(&"greet")
	assert_true(b.reflex)
	var c := _ctx()
	assert_eq(b.score(c), 0.0, "no one there")
	c.player = _at + Vector3(5, 0, 0)
	assert_eq(b.score(c), 0.8)
	b.start(c)
	var acts := []
	for k in int(3.0 / DT):
		var ctx := _ctx()
		ctx.player = _at + Vector3(5, 0, 0)
		if b.done(ctx):
			break
		var i := _think(b, ctx)
		acts.append(i.action)
		assert_not_null(i.face, "looks at you")
	assert_true(acts.has(&"nod"))
	c = _ctx()
	c.player = _at + Vector3(5, 0, 0)
	assert_eq(b.score(c), 0.0, "not again so soon")
	_time += 61.0
	c = _ctx()
	c.player = _at + Vector3(5, 0, 0)
	assert_eq(b.score(c), 0.8, "but after a while")
	_site.mark(WHO, &"seated")
	c = _ctx()
	c.player = _at + Vector3(5, 0, 0)
	assert_eq(b.score(c), 0.0, "seated, they let you be")

func test_the_shy_step_back():
	_person = WadooCast.person(17)
	assert_true(_person["shy"], "Nesh is shy")
	var b := NpcBehaviours.make(&"greet")
	var c := _ctx()
	c.player = _at + Vector3(1.5, 0, 0)
	b.start(c)
	c = _ctx()
	c.player = _at + Vector3(1.5, 0, 0)
	var i := b.think(c)
	assert_not_null(i.move_to, "steps away")
	assert_gt(Behaviour.flat_distance(i.move_to, c.player), 1.5)

func test_the_queen_holds_court():
	_person = WadooCast.person(0)
	var b := NpcBehaviours.make(&"hold_court")
	assert_eq(b.score(_ctx()), 0.5)
	_run(b, 60.0)
	assert_lt(Behaviour.flat_distance(_at, _site.spot(&"court", "court:queen")["at"]), 0.35)

func test_species_read_back():
	for id in [&"wadee_villager", &"wadee_sunguard", &"wadee_queen"]:
		var s: NpcSpecies = load("res://data/npcs/%s.tres" % id)
		assert_eq(s.id, id)
		assert_eq(s.look, &"wadee")
		assert_eq(s.locomotors, [&"ground_walker"] as Array[StringName])
		assert_eq(s.population, &"wadoo")
		assert_eq(s.live_radius, 400.0)
		assert_eq(s.fade, Vector2(330, 380))
		assert_eq(s.height, 1.75)
		assert_eq(s.knocked_out_for, 0.0)
		assert_eq(s.needs.size(), 7)
		for b: StringName in s.behaviours:
			assert_true(NpcBehaviours.exists(b), "%s: %s" % [id, b])
	assert_eq((load("res://data/npcs/wadee_sunguard.tres") as NpcSpecies).max_health, 90.0)
	assert_eq((load("res://data/npcs/wadee_villager.tres") as NpcSpecies).behaviours.size(), 9, "eight of their day, and converse")
