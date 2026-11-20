extends GutTest

## Their homes (docs/superpowers/specs/2026-11-16-wadoo-design.md §10, stage 5): the
## home in home_4 and the Glassworks in the workshop, built rooms (WadooRooms) with
## an open doorway and the spots the Wadees use inside; going home into a room, to
## sit at the table, talk with company, weave or tidy; water carried in to the jar;
## glass worked inside; and a frightened household huddled at the back of its room.

const POOL_RADIUS := 11.0
const DT := 0.2
const HOME := "home_4"
const GLASSWORKS := "workshop"
const WHO := &"wadee:wadoo:9"
const OTHER := &"wadee:wadoo:14"

var _layout: Dictionary
var _site: WadooSite
var _state: WadooState
var _at := Vector3.ZERO
var _fwd := Vector3.FORWARD
var _needs := {}
var _time := 0.0
var _person := {}

func before_all():
	_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))

func before_each():
	_site = _make_site()
	_state = WadooState.new()
	_site.state = _state
	_at = _site.ground(_site.paths.nearest_open(Vector2(14.0, 10.0)))
	_fwd = Vector3.FORWARD
	_needs = {&"work": 0.0, &"rest": 0.0, &"company": 0.0, &"thirst": 0.0, &"grief": 0.0, &"home": 0.0, &"fear": 0.0}
	_time = 100.0
	_person = WadooCast.person(9).duplicate()

## The shell `id` from the layout.
func _shell(id: String) -> Dictionary:
	for s: Dictionary in _layout["shells"]:
		if s["id"] == id:
			return s
	return {}

## A shell's frame on flat ground at height 0, as PlaceField sets it.
func _frame(id: String) -> Transform3D:
	var s := _shell(id)
	var at: Array = s["at"]
	return Transform3D(Basis(Vector3.UP, -deg_to_rad(float(s["yaw"]))),
		Vector3(float(at[0]), BrickShell.FOUNDATION, -float(at[1])))

## A site whose place node says where every open shell's room is, as PlaceField's would.
func _make_site() -> WadooSite:
	var node := Node3D.new()
	add_child_autofree(node)
	var rooms := {}
	for s: Dictionary in _layout["shells"]:
		if bool(s.get("open", false)) and s.has("room"):
			var sz: Array = s["size"]
			rooms[s["id"]] = {"room": StringName(s["room"]), "frame": _frame(s["id"]),
				"size": Vector3(float(sz[0]), float(sz[1]), float(sz[2]))}
	node.set_meta(&"rooms", rooms)
	return WadooSite.new(node, _layout, POOL_RADIUS, func(e: float, n: float) -> Vector3: return Vector3(e, 0.0, -n))

func _ctx(who := WHO) -> NpcContext:
	var c := NpcContext.new()
	c.record = NpcRecord.make(who, &"wadee_villager", &"wadoo", Vector3.ZERO, 1234)
	c.needs = _needs
	c.time = _time
	c.dt = DT
	c.position = _at
	c.forward = _fwd
	c.up = Vector3.UP
	c.extra[&"town"] = _site
	c.extra[&"person"] = _person
	c.extra[&"village"] = _state
	c.extra[&"pair"] = _site.pair_of(who)
	if _site.hidden(who):
		c.extra[&"indoors"] = true
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

static func _actions(intents: Array[Intent]) -> Array:
	var out := []
	for i in intents:
		if out.is_empty() or out[out.size() - 1] != i.action:
			out.append(i.action)
	return out

static func _count(list: Array, kind: StringName, action := &"") -> int:
	var n := 0
	for s: Dictionary in list:
		if s["kind"] == kind and (action == &"" or s["action"] == action):
			n += 1
	return n

## The point `at` of the shell `id`'s frame in the room, as site-local ground.
func _in_room(id: String, local: Vector3) -> Vector2:
	return WadooSite.flat(_frame(id) * local)

# --- the rooms ------------------------------------------------------------------

func test_both_shells_are_open_rooms() -> void:
	assert_eq(str(_shell(HOME).get("room", "")), "home")
	assert_eq(str(_shell(GLASSWORKS).get("room", "")), "glassworks")
	assert_true(bool(_shell(HOME).get("open", false)))
	assert_true(bool(_shell(GLASSWORKS).get("open", false)))
	assert_false(WadooRooms.DOORS.has(&"home"), "an open doorway, its curtain tied back")
	assert_false(WadooRooms.DOORS.has(&"glassworks"))
	assert_true(WadooRooms.DOORS.has(&"hall"), "the queen's hall keeps its door")

func test_the_rooms_have_their_spots() -> void:
	var home := WadooRooms.spots(&"home")
	assert_eq(_count(home, &"home", &"sit"), 2, "two stools, at the table's ends")
	assert_eq(_count(home, &"home", &"kneel"), 2, "the loom and a bedroll")
	assert_eq(_count(home, &"jar", &"interact"), 1, "the water jar")
	assert_eq(_count(home, &"hide", &"cower"), 3, "three corners to huddle in")
	var gw := WadooRooms.spots(&"glassworks")
	assert_eq(_count(gw, &"glass"), 3, "kiln, bench, sand")
	assert_eq(_count(gw, &"glass", &"interact"), 1)
	assert_eq(_count(gw, &"glass", &"kneel"), 1)
	assert_eq(_count(gw, &"glass", &"lift"), 1)
	var size: Array = _shell(HOME)["size"]
	for s: Dictionary in home + gw:
		var at: Vector3 = s["at"]
		assert_almost_eq(at.y, 0.0, 0.05, "%s %d on the floor" % [s["kind"], s["n"]])
		assert_gt(Vector2(at.x, at.z).distance_to(Vector2((s["look"] as Vector3).x, (s["look"] as Vector3).z)), 0.1,
			"%s %d looks somewhere" % [s["kind"], s["n"]])
	for s: Dictionary in home:
		var at: Vector3 = s["at"]
		assert_lt(absf(at.x), float(size[0]) * 0.5 - BrickShell.WALL, "%s %d inside the walls" % [s["kind"], s["n"]])
		assert_lt(absf(at.z), float(size[2]) * 0.5 - BrickShell.WALL, "%s %d inside the walls" % [s["kind"], s["n"]])

func test_the_rooms_build_lit_and_solid() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var home := WadooRooms.build(&"home", parent, _frame(HOME))
	assert_gte(home.find_children("*", "OmniLight3D", true, false).size(), 1, "a hanging lamp")
	assert_gt((home.get_node("Solid") as StaticBody3D).get_child_count(), 4, "table, stools, loom, jar, shelf")
	var stools := 0
	for sol: Array in WadooRooms.solids(&"home"):
		if (sol[1] as Vector2).is_equal_approx(Vector2(0.2, 0.2)):
			stools += 1
	assert_eq(stools, 2, "the stools are walked round")
	var gw := WadooRooms.build(&"glassworks", parent, _frame(GLASSWORKS))
	var lights := gw.find_children("*", "OmniLight3D", true, false)
	assert_gte(lights.size(), 3)
	var kiln := false
	for l: Node in lights:
		var o := l as OmniLight3D
		if o.light_color.is_equal_approx(WadeePalette.KILN):
			kiln = true
			assert_almost_eq(o.light_energy, WadooRooms.KILN_ENERGY, 0.001)
		assert_lte(o.light_energy, 1.5, "warm and dim")
	assert_true(kiln, "the kiln glows")
	assert_eq(gw.find_children("*", "WadooDoor", true, false).size(), 0)
	assert_eq(home.find_children("*", "WadooDoor", true, false).size(), 0)

func test_the_site_has_their_spots_inside() -> void:
	for n in 4:
		assert_false(_site.spot(&"home", "home:%s:%d" % [HOME, n]).is_empty(), "home %d" % n)
	assert_false(_site.spot_in(&"jar", HOME).is_empty())
	for n in 3:
		var h := _site.spot(&"hide", "hide:%s:%d" % [HOME, n])
		assert_false(h.is_empty(), "hide %d" % n)
		assert_eq(_site.room_at(WadooSite.flat(h["at"])), HOME, "hide %d in the room" % n)
		var g := _site.spot(&"glass", "glass:%s:%d" % [GLASSWORKS, n])
		assert_false(g.is_empty(), "glass %d inside" % n)
		assert_eq(_site.room_at(WadooSite.flat(g["at"])), GLASSWORKS, "glass %d in the Glassworks" % n)
	assert_false(_site.spot(&"glass", "glass:0").is_empty(), "and the three before its door still")
	assert_true(_site.spot_in(&"jar", "hut_b").is_empty(), "a home with no room has no jar")

func test_every_spot_inside_is_reached_from_the_street() -> void:
	var from := _site.paths.nearest_open(Vector2(14.0, 10.0))
	for kind: StringName in [&"home", &"jar", &"hide", &"glass"]:
		for s: Dictionary in _site.spots(kind):
			var key := String(s["key"])
			if not (key.begins_with("%s:%s:" % [kind, HOME]) or key.begins_with("%s:%s:" % [kind, GLASSWORKS])):
				continue
			var to := WadooSite.flat(s["at"])
			var r := _site.route(from, to)
			var end := r[r.size() - 1] if not r.is_empty() else from
			assert_lt(end.distance_to(to), WadooErrand.ARRIVED, "%s reached: the route ends %.2f m off (%d points; open there %s)" % [
				key, end.distance_to(to), r.size(), _site.open(to)])

# --- going home -----------------------------------------------------------------

func test_going_home_into_the_room_sits_in_sight_and_gets_up() -> void:
	_person["home"] = HOME
	_needs[&"home"] = 0.95
	var b := NpcBehaviours.make(&"go_home") as WadooErrand
	assert_gt(b.score(_ctx()), 0.9)
	# one sits at the table and the loom and bedroll are busy: theirs is the other stool
	_site.claim("home:%s:0" % HOME, &"x")
	_site.claim("home:%s:2" % HOME, &"z")
	_site.claim("home:%s:3" % HOME, &"w")
	b.start(_ctx())
	assert_eq(String(b.spot["key"]), "home:%s:1" % HOME, "a stool at the table")
	var intents: Array[Intent] = []
	var seated := false
	for k in int(200.0 / DT):
		var ctx := _ctx()
		if b.done(ctx):
			break
		intents.append(_think(b, ctx))
		assert_false(_site.hidden(WHO), "never out of sight")
		seated = seated or _site._state.get(WHO, &"") == &"seated"
	var acts := _actions(intents)
	assert_true(seated, "marked seated: %s" % [acts])
	assert_true(acts.has(&"sit"), "sits: %s" % [acts])
	assert_true(acts.has(&"sit_talk"), "talks with whoever else is at the table: %s" % [acts])
	assert_eq(acts[acts.size() - 1], &"rise", "and gets up before going: %s" % [acts])
	assert_eq(_site.room_at(WadooSite.flat(_at)), HOME, "in the room")
	assert_true(b.done(_ctx()))
	assert_null(_site.holder_of("home:%s:1" % HOME), "the stool let go")
	assert_eq(_site._state.get(WHO, &""), &"", "no longer seated")
	assert_lt(_needs[&"home"], 0.5, "home eased")

func test_at_home_in_the_room_they_stay_until_their_time_is_up() -> void:
	_person["home"] = HOME
	_needs[&"home"] = 0.95
	var b := NpcBehaviours.make(&"go_home") as WadooErrand
	b.start(_ctx())
	for k in int(60.0 / DT):
		_think(b, _ctx())
		if b.acting():
			break
	assert_true(b.acting(), "at their spot")
	_needs[&"home"] = 0.1
	assert_eq(b.score(_ctx()), 1.0, "home eased, they still stay: nothing else draws them out")
	while not b.done(_ctx()) and _time < 400.0:
		_think(b, _ctx())
	assert_true(b.done(_ctx()))
	assert_lt(b.score(_ctx()), 0.5, "then go about their day")

func test_alone_at_the_table_they_sit_quiet() -> void:
	_person["home"] = HOME
	var b := NpcBehaviours.make(&"go_home") as WadooErrand
	_site.claim("home:%s:2" % HOME, &"x")
	_site.claim("home:%s:3" % HOME, &"y")
	b.start(_ctx())
	assert_eq(b.spot["action"], &"sit")
	var intents: Array[Intent] = []
	for k in int(60.0 / DT):
		var ctx := _ctx()
		if b.done(ctx):
			break
		intents.append(_think(b, ctx))
	var acts := _actions(intents)
	assert_true(acts.has(&"sit"), "sits: %s" % [acts])
	assert_false(acts.has(&"sit_talk"), "no one to talk to: %s" % [acts])

func test_a_home_without_a_room_still_hides_them() -> void:
	_person["home"] = "hut_b"
	var b := NpcBehaviours.make(&"go_home")
	b.start(_ctx())
	var was_in := false
	for k in int(150.0 / DT):
		var ctx := _ctx()
		if b.done(ctx):
			break
		_think(b, ctx)
		was_in = was_in or _site.hidden(WHO)
	assert_true(was_in, "in through the door, out of sight")

# --- water and glass ------------------------------------------------------------

func test_water_from_the_pump_is_poured_into_the_jar() -> void:
	_person["home"] = HOME
	_person["jobs"] = ["pump"]
	_needs[&"work"] = 0.9
	var b := NpcBehaviours.make(&"work")
	b.start(_ctx())
	var jar := _site.spot_in(&"jar", HOME)
	var intents: Array[Intent] = []
	var poured_at_jar := false
	for k in int(240.0 / DT):
		var ctx := _ctx()
		if b.done(ctx):
			break
		var i := _think(b, ctx)
		intents.append(i)
		if i.action == &"interact" and Behaviour.flat_distance(_at, jar["at"]) < 0.5:
			poured_at_jar = true
	var acts := _actions(intents)
	assert_true(acts.has(&"carry"), "carries the water: %s" % [acts])
	assert_true(poured_at_jar, "pours it at the jar: %s" % [acts])
	assert_true(b.done(_ctx()))

func test_glass_is_worked_inside_when_the_door_is_busy() -> void:
	_person["jobs"] = ["glass"]
	_needs[&"work"] = 0.9
	for k in 3:
		_site.claim("glass:%d" % k, StringName("x%d" % k))
	var b := NpcBehaviours.make(&"work") as WadooErrand
	b.start(_ctx())
	assert_true(String(b.spot["key"]).begins_with("glass:%s:" % GLASSWORKS), "inside: %s" % b.spot["key"])
	var acts := []
	for k in int(120.0 / DT):
		var ctx := _ctx()
		if b.done(ctx):
			break
		var i := _think(b, ctx)
		if acts.is_empty() or acts[acts.size() - 1] != i.action:
			acts.append(i.action)
	assert_true(acts.has(b.spot["action"]) or b.done(_ctx()), "works there: %s" % [acts])
	assert_eq(_site.room_at(WadooSite.flat(_at)), GLASSWORKS)

# --- fear -----------------------------------------------------------------------

func test_frightened_they_huddle_at_the_back_of_their_room_in_sight() -> void:
	_person["home"] = HOME
	_state.turn_hostile()
	var you := {"at": _at + Vector3(3, 0, 0), "in_town": true}
	var b := NpcBehaviours.make(&"flee_home")
	var c := _ctx()
	c.extra[&"you"] = you
	assert_gte(b.score(c), b.threshold)
	b.start(c)
	var last: Intent = null
	for k in 400:
		c = _ctx()
		c.extra[&"you"] = you
		last = _think(b, c)
		if last.action == &"cower":
			break
	assert_eq(last.action, &"cower", "huddled")
	assert_false(_site.hidden(WHO), "seen, in the room")
	assert_eq(_site.room_at(WadooSite.flat(_at)), HOME)
	var key: Variant = null
	for n in 3:
		if _site.holder_of("hide:%s:%d" % [HOME, n]) == WHO:
			key = n
	assert_not_null(key, "holding a corner")
	var gone := {"at": Vector3(0, 0, -70), "in_town": false}
	for k in int((20.0 + 2.0) / DT):
		c = _ctx()
		c.extra[&"you"] = gone
		_think(b, c)
	assert_true(b.done(_ctx()), "out again once you have gone")
	for n in 3:
		assert_null(_site.holder_of("hide:%s:%d" % [HOME, n]), "the corner let go")
