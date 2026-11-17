extends GutTest

## Harm and defence in Wadoo (docs/superpowers/specs/2026-11-16-wadoo-design.md §8,
## §9), as pieces on the real town (a flat ground): a wound you deal turns the
## town for good; villagers run home or cower; the Sunguard keep their distance,
## move between places with a line to you, throw bolts of sun in their own
## rhythm and roll aside when aimed at; the queen's sun-rod and its charm.

const POOL_RADIUS := 11.0
const DT := 0.2
const VILLAGER := 7
const KESH := 1

class Avatarish extends Node3D:
	pass

var _layout: Dictionary
var _node: Node3D
var _site: WadooSite
var _state: WadooState
var _at := Vector3.ZERO
var _time := 100.0

func before_all():
	_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/places/oasis.json"))

func before_each():
	_node = Node3D.new()
	add_child_autofree(_node)
	_site = WadooSite.new(_node, _layout, POOL_RADIUS, func(e: float, n: float) -> Vector3: return Vector3(e, 0.0, -n))
	_state = WadooState.new()
	_site.state = _state
	_time = 100.0

## You, as the town knows you, standing at site-local `at`.
func _you(at: Vector3, more := {}) -> Dictionary:
	var d := {"at": at, "chest": at + Vector3(0, 1.2, 0), "vel": Vector3.ZERO, "on_foot": true, "down": false,
		"armed": false, "in_town": _site.inside_walls(WadooSite.flat(at)), "up_for": 100.0,
		"eye": at + Vector3(0, 1.65, 0), "look": Vector3.FORWARD}
	d.merge(more, true)
	return d

func _ctx(n: int, you: Dictionary, more := {}) -> NpcContext:
	var p := WadooCast.person(n)
	var c := NpcContext.new()
	c.record = WadooCast.record(n, _layout)
	c.needs = {&"work": 0.5, &"rest": 0.0, &"company": 0.0, &"thirst": 0.0, &"grief": 0.0, &"home": 0.0, &"fear": 0.0}
	c.time = _time
	c.dt = DT
	c.position = _at
	c.forward = Vector3.FORWARD
	c.up = Vector3.UP
	c.extra[&"town"] = _site
	c.extra[&"person"] = p
	c.extra[&"village"] = _state
	c.extra[&"you"] = you
	c.extra[&"aimed_at"] = false
	if _site.hidden(c.record.id):
		c.extra[&"indoors"] = true
	c.extra.merge(more, true)
	return c

func _open(e: float, n: float) -> Vector3:
	return _site.ground(_site.paths.nearest_open(Vector2(e, n)))

func _behaviour(id: StringName) -> Behaviour:
	var b := NpcBehaviours.make(id)
	assert_not_null(b, "a behaviour called %s" % id)
	return b

# --- the village remembers ------------------------------------------------------

func test_a_wound_you_deal_turns_the_town_for_good():
	var you := Avatarish.new()
	autofree(you)
	var hit := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, you)
	hit.damage = 10.0
	var guard := Npc.new()
	autofree(guard)
	var stray := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, guard)
	_site.wounded(null, stray, 5.0)
	assert_false(_state.hostile, "a Wadee's own stray does not count")
	_site.wounded(null, hit, 10.0)
	assert_true(_state.hostile, "yours does")
	assert_true(WadooState.from_dict(_state.to_dict()).hostile, "and it is saved")
	assert_false(_state.door_open(), "the hall's door shuts")

func test_the_sunguard_do_not_talk_once_turned():
	_site.on_talk = func(_n: Npc, _p: Dictionary, _s: Dictionary) -> void: pass
	var kesh := Npc.new()
	autofree(kesh)
	kesh.record = WadooCast.record(KESH, _layout)
	var lio := Npc.new()
	autofree(lio)
	lio.record = WadooCast.record(VILLAGER, _layout)
	assert_true(_site.can_talk(kesh))
	_state.turn_hostile()
	assert_false(_site.can_talk(kesh), "Kesh fights you instead")
	assert_true(_site.can_talk(lio), "a villager you catch only turns away")

func test_inside_the_walls():
	assert_true(_site.inside_walls(Vector2.ZERO), "the pool")
	assert_true(_site.inside_walls(Vector2(30.0, 20.0)))
	assert_false(_site.inside_walls(Vector2(0.0, 60.0)), "north of the wall")
	assert_false(_site.inside_walls(Vector2(56.5, -8.0)), "past the breach, where the armlet lay")

func test_the_town_knows_where_you_are_and_what_you_hold():
	var you := Avatarish.new()
	add_child_autofree(you)
	_node.global_transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(300.0, 5.0, -40.0))
	var local := _open(14.0, 10.0)
	you.global_position = _node.global_transform * local
	var eye := Transform3D(Basis.looking_at(_node.global_transform.basis * Vector3(1, 0, 0)), you.global_position + Vector3(0, 1.65, 0))
	_site.avatar = you
	_site.you = func() -> Dictionary:
		return {"on_foot": true, "down": false, "armed": true, "eye": eye,
			"velocity": _node.global_transform.basis * Vector3(2.0, 0.0, 0.0)}
	_site._you_frame = -1
	var seen := _site.you_here(_time)
	assert_true((seen["at"] as Vector3).is_equal_approx(local), "in the town's own frame")
	assert_true(seen["in_town"])
	assert_true(seen["on_foot"] and seen["armed"])
	assert_true((seen["vel"] as Vector3).is_equal_approx(Vector3(2.0, 0.0, 0.0)))
	assert_almost_eq((seen["look"] as Vector3).dot(Vector3(1, 0, 0)), 1.0, 0.001, "looking east")
	var ahead: Vector3 = seen["eye"] + Vector3(10.0, -0.45, 0.0)
	assert_true(_site._aimed_at(seen, ahead), "a Wadee 10 m east is aimed at")
	assert_false(_site._aimed_at(seen, seen["eye"] + Vector3(0.0, 0.0, 10.0)), "one to the south is not")
	seen["armed"] = false
	assert_false(_site._aimed_at(seen, ahead), "empty hands aim at no one")

func test_a_place_to_fight_from():
	var you := _you(_open(14.0, 10.0))
	for salt in [1, 2, 3]:
		var spot: Variant = _site.fire_spot(_open(-10.0, -20.0), you, salt)
		assert_not_null(spot, "somewhere with a line to you")
		if spot == null:
			continue
		var d := Behaviour.flat_distance(spot, you["at"])
		assert_between(d, WadooSite.FIGHT_NEAR, WadooSite.FIGHT_FAR, "at range")
		assert_true(_site.inside_walls(WadooSite.flat(spot)) and _site.open(WadooSite.flat(spot)), "open ground within the walls")
		assert_eq(_site.room_at(WadooSite.flat(spot)), "", "out of doors")
	assert_null(_site.fire_spot(Vector3.ZERO, {}, 1), "no you, no place")

# --- the villagers --------------------------------------------------------------

func test_villagers_run_home_while_you_are_in_town_and_come_out_after():
	var b := _behaviour(&"flee_home")
	_at = _open(-5.0, 18.0)
	var you := _you(_open(14.0, 10.0))
	assert_eq(b.score(_ctx(VILLAGER, you)), 0.0, "not while they think well of you")
	_state.turn_hostile()
	assert_gte(b.score(_ctx(VILLAGER, you)), b.threshold, "turned, they run")
	assert_eq(b.score(_ctx(VILLAGER, _you(Vector3(0, 0, -70)))), 0.0, "not while you are outside the walls")
	var who := WadooCast.record(VILLAGER, _layout).id
	var door := _site.door_of(str(WadooCast.person(VILLAGER)["home"]))
	b.start(_ctx(VILLAGER, you))
	var ran := false
	for i in 200:
		var i_ := b.think(_ctx(VILLAGER, you))
		if i_.move_to != null:
			ran = ran or i_.speed > 2.0
			_at = i_.move_to
		_time += DT
		if _site.hidden(who):
			break
	assert_true(ran, "they run")
	assert_true(_site.hidden(who), "and go in")
	assert_lt(Behaviour.flat_distance(_at, door["door"]), 0.5, "through their own door")
	assert_gte(b.score(_ctx(VILLAGER, _you(Vector3(0, 0, -70)))), b.threshold, "in, they stay in")
	var away := _you(Vector3(0, 0, -70))
	var stay: float = (b.get_script() as Script).get_script_constant_map()["STAY"]
	for i in int(stay / 4.0):
		b.think(_ctx(VILLAGER, away))
		_time += 4.0
	assert_true(_site.hidden(who), "a while after you go")
	for i in 2:
		b.think(_ctx(VILLAGER, away))
		_time += 4.0
	assert_false(_site.hidden(who), "then out again")
	assert_true(b.done(_ctx(VILLAGER, away)))

func test_one_with_you_across_their_way_home_cowers():
	var b := _behaviour(&"cower")
	_state.turn_hostile()
	var door: Dictionary = _site.door_of(str(WadooCast.person(VILLAGER)["home"]))
	var d: Vector3 = door["door"]
	var out := Vector3(door["out"].x, 0.0, -door["out"].y) if door["out"] is Vector2 else Vector3.ZERO
	_at = _site.ground(_site.paths.nearest_open(WadooSite.flat(d) + WadooSite.flat(d).normalized() * -8.0))
	var between := _at.lerp(d, 0.5)
	assert_eq(b.score(_ctx(VILLAGER, _you(between))), 1.0, "you stand between them and their door")
	var behind := _at + (_at - d).normalized() * 4.0
	assert_eq(b.score(_ctx(VILLAGER, _you(behind))), 0.0, "you behind them: they run for it")
	b.start(_ctx(VILLAGER, _you(between)))
	var i := b.think(_ctx(VILLAGER, _you(between)))
	assert_eq(i.action, &"cower")
	assert_null(i.move_to, "where they are")
	assert_eq(b.score(_ctx(VILLAGER, _you(behind))), 1.0, "once down they stay down while you are near")
	assert_false(b.done(_ctx(VILLAGER, _you(behind))))
	var far: Vector3 = _at + (_at - d).normalized() * (float((b.get_script() as Script).get_script_constant_map()["CLEAR"]) + 1.0)
	assert_true(b.done(_ctx(VILLAGER, _you(far))), "until you are off")

# --- the Sunguard ---------------------------------------------------------------

func test_the_sunguard_fight_only_you_on_your_feet_within_the_walls():
	var b := _behaviour(&"fight_ranged")
	_at = _open(-10.0, -20.0)
	var you := _you(_open(14.0, 10.0))
	assert_eq(b.score(_ctx(KESH, you)), 0.0, "not while they think well of you")
	_state.turn_hostile()
	assert_gte(b.score(_ctx(KESH, you)), b.threshold)
	assert_eq(b.score(_ctx(KESH, _you(you["at"], {"down": true}))), 0.0, "not while you are down")
	assert_eq(b.score(_ctx(KESH, _you(you["at"], {"up_for": 3.0}))), 0.0, "nor just up again")
	assert_eq(b.score(_ctx(KESH, _you(you["at"], {"on_foot": false}))), 0.0, "nor in your ship")
	assert_eq(b.score(_ctx(KESH, _you(Vector3(0, 0, -70)))), 0.0, "nor once you leave the walls")

func test_they_take_a_place_at_range_and_shoot_in_their_own_rhythm():
	var b := _behaviour(&"fight_ranged")
	_state.turn_hostile()
	_at = _open(-10.0, -20.0)
	var you := _you(_open(14.0, 10.0))
	b.start(_ctx(KESH, you))
	var shots: Array[float] = []
	var ran := false
	for k in int(30.0 / DT):
		var i := b.think(_ctx(KESH, you))
		if i.move_to != null:
			ran = ran or i.speed > 2.0
			assert_eq(i.action, &"armed", "the staff in hand as they run")
			_at = i.move_to
		elif i.action == &"shoot":
			shots.append(_time)
			assert_between(Behaviour.flat_distance(_at, you["at"]), WadooSite.FIGHT_NEAR - 0.5, WadooSite.FIGHT_FAR + 3.5,
				"from range")
		else:
			assert_eq(i.action, &"aim")
		_time += DT
	assert_true(ran, "they run to their place")
	assert_gt(shots.size(), 8, "and shoot, again and again")
	for k in range(1, shots.size()):
		assert_between(shots[k] - shots[k - 1], 1.5 - 0.01, 2.5 + DT + 0.01, "every 1.5 to 2.5 s")

func test_two_of_them_keep_different_rhythms():
	var a: Variant = load("res://src/npc/behaviours/fight_ranged.gd")
	var rhythms := {}
	for n in [1, 2, 3, 4, 5]:
		var ctx := _ctx(n, _you(Vector3.ZERO))
		rhythms[snappedf(lerpf(1.5, 2.5, a.nature(ctx, 3)), 0.01)] = true
	assert_gt(rhythms.size(), 3, "each their own")

func test_aimed_at_they_roll_aside_now_and_then():
	var b := _behaviour(&"fight_ranged")
	_state.turn_hostile()
	var you := _you(_open(14.0, 10.0))
	_at = _site.fire_spot(_open(-10.0, -20.0), you, 1)
	b.start(_ctx(KESH, you))
	var rolls: Array[float] = []
	var was := &""
	for k in int(40.0 / DT):
		var i := b.think(_ctx(KESH, you, {&"aimed_at": true}))
		if i.action == &"roll" and was != &"roll":
			rolls.append(_time)
			assert_not_null(i.move_to)
			assert_between(Behaviour.flat_distance(i.move_to, _at), 2.0, 3.0, "a roll aside")
		if i.move_to != null:
			_at = i.move_to
		was = i.action
		_time += DT
	assert_gt(rolls.size(), 1, "now and then")
	for k in range(1, rolls.size()):
		assert_gte(rolls[k] - rolls[k - 1], 4.0 - 0.01, "never more than once in 4 s")

# --- the sun bolt and the sun-rod ----------------------------------------------

func test_a_sun_bolt():
	var bolt := SunBolt.new()
	autofree(bolt)
	assert_eq(bolt.speed, 30.0)
	assert_eq(bolt.damage, 12.0, "a Sunguard's bolt (spec §9)")
	assert_eq(bolt.kind, &"sun")
	assert_true(SunBolt.AT_YOU_MASK & 4 != 0, "it meets you")
	assert_true(SunBolt.AT_YOU_MASK & BodyProxy.LAYER != 0, "and the walls and the ground")
	assert_eq(SunBolt.AT_YOU_MASK & Npc.LAYER, 0, "not the Wadees")

## A bolt that hits you hurts you, and bursts small: at your chest, a full burst
## hides a sixth of the view.
func test_a_sun_bolt_on_you_hurts_and_bursts_small():
	var world := Node3D.new()
	add_child_autofree(world)
	var avatar: Avatar = load("res://scenes/avatar.tscn").instantiate()
	world.add_child(avatar)
	var bolt := SunBolt.new()
	world.add_child(bolt)
	bolt.launch(Vector3(0, 1.2, -5), Vector3.BACK)
	var before := avatar.health.current
	bolt.impact({"position": Vector3(0, 1.2, -0.3), "normal": Vector3.FORWARD, "collider": avatar})
	assert_eq(avatar.health.current, before - SunBolt.DAMAGE, "12 hp")
	var flashes := world.find_children("*", "ImpactFlash", false, false)
	assert_eq(flashes.size(), 1)
	if not flashes.is_empty():
		assert_almost_eq((flashes[0] as ImpactFlash).grow, SunBolt.ON_YOU_FLASH, 0.01, "a small burst")

func _rod(kind: StringName) -> Item:
	var cat := ItemCatalog.load_from_dir()
	var item := Item.new()
	item.setup(cat.get_def(kind))
	add_child_autofree(item)
	return item

func test_the_sun_rod_is_slow_strong_and_fills_in_daylight():
	var item := _rod(&"sun_rod")
	var rod := item.use_node as SunRod
	assert_not_null(rod)
	assert_gt(rod.recoil(), 0.0, "a gun: the town sees you armed")
	var world := Node3D.new()
	add_child_autofree(world)
	var aim := Transform3D(Basis.IDENTITY, Vector3(0, 50, 0))
	assert_true(rod.use(item, aim, world, null))
	assert_eq(rod.charges, SunRod.CHARGES - 1)
	assert_false(rod.use(item, aim, world, null), "slower than the pistol: not again at once")
	var bolt := world.find_children("*", "SunBolt", false, false)
	assert_eq(bolt.size(), 1)
	assert_eq((bolt[0] as SunBolt).damage, SunRod.DAMAGE, "stronger than the pistol's 10")
	assert_eq((bolt[0] as SunBolt).bright, 1.0)
	for k in SunRod.CHARGES - 1:
		rod.tick(SunRod.COOLDOWN, false)
		assert_true(rod.use(item, aim, world, null))
	assert_eq(rod.charges, 0)
	rod.tick(SunRod.COOLDOWN, false)
	assert_false(rod.use(item, aim, world, null), "spent")
	assert_eq(rod.status(), "0 of 6")
	rod.tick(SunRod.RECHARGE * 3.0, false)
	assert_eq(rod.charges, 0, "not in the dark")
	rod.tick(SunRod.RECHARGE * 2.0 + 0.1, true)
	assert_eq(rod.charges, 2, "in daylight, one each RECHARGE")
	var again := SunRod.new()
	autofree(again)
	again.restore(rod.save())
	assert_eq(again.charges, 2, "saved")

func test_the_charmed_rod_burns_brighter():
	var item := _rod(&"sun_rod_charmed")
	var rod := item.use_node as SunRod
	var world := Node3D.new()
	add_child_autofree(world)
	assert_true(rod.use(item, Transform3D(Basis.IDENTITY, Vector3(0, 50, 0)), world, null))
	var bolt := world.find_children("*", "SunBolt", false, false)[0] as SunBolt
	assert_eq(bolt.bright, SunBolt.CHARMED)
	assert_true(item.definition.never_made and _rod(&"sun_rod").definition.never_made, "only the queen gives one")

# --- the gift -------------------------------------------------------------------

func test_the_queen_gives_her_rod_once():
	assert_true(_state.give_rod())
	assert_false(_state.give_rod(), "once")
	assert_true(WadooState.from_dict(_state.to_dict()).rod_given, "saved")

func test_she_names_the_charm_only_for_all_three():
	var f := _state.facts()
	assert_eq(WadooLines.fill("A rod.{charm}", {}, f), "A rod.")
	for t in WadooState.TASKS:
		_state.do_task(t)
	assert_string_contains(WadooLines.fill("A rod.{charm}", {}, _state.facts()), "water stone")
