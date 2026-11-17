extends GutTest

## Things lying outside, and taken stays taken (desert world phase 3, task 10):
## the oasis's crate and canister lie on its ground, frozen, children of the
## place; what the hands take is theirs and is never put back, through a
## reload of the place, a save, or being dropped outside (a stray).

const SCENE := "res://scenes/flight_test.tscn"

var _root: Node
var _ship: Ship
var _universe: Universe
var _avatar: Avatar
var _body: SystemBody
var _place: PlaceDesign
var _terrain: WorldTerrain

func before_each():
	_root = load(SCENE).instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_universe = _root.get_node("Universe")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	await wait_physics_frames(3)
	var system: SystemRecipe = _root.system
	_place = system.places()[0]
	_body = system.body(_place.body_id)
	_terrain = _root.star_system.whereabouts.terrain_of(_body)

func _hold_over(east: float, north: float, height: float) -> void:
	var d := _place.local_dir(east, north, _body.radius)
	var at := _body.point.plus(d * (_body.radius + _terrain.height_at(d) + height))
	_ship.exterior.freeze = true
	_ship.exterior.linear_velocity = Vector3.ZERO
	_ship.exterior.global_position = _universe.to_engine(at)
	await wait_physics_frames(3)

func _oasis() -> Node3D:
	return _root.places.loaded(&"oasis")

func _lying(kind: StringName) -> Item:
	if _oasis() == null:
		return null
	for c in _oasis().get_children():
		if c is Item and c.definition.id == kind:
			return c
	return null

## Where the layout lays item `id`, [east, north] m.
func _layout_at(id: String) -> Array:
	for it: Dictionary in _place.layout()["items"]:
		if it["id"] == id:
			return [float(it["at"][0]), float(it["at"][1])]
	return [NAN, NAN]

func test_items_lie_on_the_ground():
	await _hold_over(0, 0, 60.0)
	var items := {"crate": _layout_at("crate_hut"), "canister": _layout_at("canister_path")}
	for kind: String in items:
		var item := _lying(StringName(kind))
		assert_not_null(item, "%s lies in the place" % kind)
		if item == null:
			continue
		var ground := PlaceField.on_ground(_place, _terrain, items[kind][0], items[kind][1])
		var bottom := _oasis().to_local(item.global_position).y - item.definition.size.y * 0.5
		assert_almost_eq(bottom, ground.y, 0.05, "%s's bottom is on the ground" % kind)
		assert_true(item.freeze, "%s is frozen" % kind)
		assert_eq(item.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
		assert_true(item.in_space, "%s is outside" % kind)
		assert_false(item.is_in_group(Universe.EXTERIOR_SPACE), "never a member itself")
		assert_false(item.is_in_group(Universe.HOLDS_SHIFT))

func test_taking_one_marks_it():
	await _hold_over(0, 0, 60.0)
	var crate := _lying(&"crate")
	assert_false(_root.places.is_taken(&"oasis", "crate_hut"))
	assert_true(_avatar.grasp.take(crate), "the hands take it")
	assert_true(_root.places.is_taken(&"oasis", "crate_hut"))
	assert_false(_root.places.is_taken(&"oasis", "canister_path"))
	assert_ne(crate.get_parent(), _oasis(), "no longer a child of the place")

func test_take_on_something_else_does_nothing():
	await _hold_over(0, 0, 60.0)
	var other := Item.new()
	other.setup(_ship.item_catalog.get_def(&"mug"))
	add_child_autofree(other)
	_root.places.take(other)
	assert_eq(_root.places.to_dict(), {"taken": {}})

func test_taken_stays_taken_after_a_reload():
	await _hold_over(0, 0, 60.0)
	assert_true(_avatar.grasp.take(_lying(&"crate")))
	await _hold_over(11000, 0, 200.0)
	assert_null(_oasis(), "freed far off")
	await _hold_over(0, 0, 60.0)
	assert_not_null(_oasis())
	assert_null(_lying(&"crate"), "no crate again")
	assert_not_null(_lying(&"canister"), "the canister is back")

func test_what_was_not_taken_goes_with_the_place():
	await _hold_over(0, 0, 60.0)
	var canister := _lying(&"canister")
	await _hold_over(11000, 0, 200.0)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(canister), "freed with the place")

func test_taken_stays_taken_after_a_save():
	await _hold_over(0, 0, 60.0)
	assert_true(_avatar.grasp.take(_lying(&"crate")))
	var saved: Dictionary = _root.places.to_dict()
	assert_eq(saved, {"taken": {"oasis": ["crate_hut"]}})
	var fresh := PlaceField.new()
	fresh.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_true(fresh.is_taken(&"oasis", "crate_hut"))
	assert_false(fresh.is_taken(&"oasis", "canister_path"))
	fresh.free()
	_root.places.from_dict(saved)
	await _hold_over(0, 0, 60.0)
	await wait_physics_frames(2)
	assert_null(_lying(&"crate"), "no crate")
	assert_not_null(_lying(&"canister"), "the canister is still there")

func test_a_save_with_no_places_part_loads_with_nothing_taken():
	await _hold_over(0, 0, 60.0)
	_root.places.from_dict({})
	assert_eq(_root.places.to_dict(), {"taken": {}})
	await _hold_over(0, 0, 60.0)
	await wait_physics_frames(2)
	assert_not_null(_lying(&"crate"), "fresh")
	assert_not_null(_lying(&"canister"))

func test_the_flight_scene_saves_and_reads_the_part():
	await _hold_over(0, 0, 60.0)
	assert_true(_avatar.grasp.take(_lying(&"crate")))
	var captured: Dictionary = _root.capture()
	assert_eq(captured["places"], {"taken": {"oasis": ["crate_hut"]}})

func test_a_taken_item_dropped_outside_is_a_stray():
	await _hold_over(0, 0, 60.0)
	var crate := _lying(&"crate")
	assert_true(_avatar.grasp.take(crate))
	var before: int = _root.strays.count()
	_avatar.let_fall.emit(crate, true)
	assert_eq(_root.strays.count(), before + 1, "one more stray")
	assert_true(_root.places.is_taken(&"oasis", "crate_hut"), "and still taken")

func test_items_stay_on_the_ground_across_a_shift():
	await _hold_over(0, 0, 60.0)
	var crate := _lying(&"crate")
	var before := _universe.to_universe(crate.global_position)
	_universe.shift(Vector3(2000, 1000, -3000))
	await wait_physics_frames(2)
	assert_true(_universe.to_universe(crate.global_position).is_equal_approx(before), "the same point")
	assert_true(crate.freeze)
	var at := _layout_at("crate_hut")
	var ground := PlaceField.on_ground(_place, _terrain, at[0], at[1])
	assert_almost_eq(_oasis().to_local(crate.global_position).y - crate.definition.size.y * 0.5, ground.y, 0.05)

# --- what the Wadees make (Wadoo spec §7) ----------------------------------------

## A thing the Wadees make lies as the layout's items do (PlaceField.lay), counted
## while it lies (lying), taken once the hands take it.
func test_a_made_thing_lies_and_is_counted():
	await _hold_over(0, 0, 60.0)
	var before: int = _root.places.lying(&"oasis", &"sun_cell")
	var item: Item = _root.places.lay(&"oasis", "sun_cell_test", &"sun_cell", Vector2(-1.0, 27.7), 15.0)
	assert_not_null(item)
	assert_eq(item.get_parent(), _oasis(), "a child of the place")
	assert_true(item.freeze, "frozen")
	var foot := PlaceField.on_ground(_place, _terrain, -1.0, 27.7)
	assert_almost_eq(item.position.y - item.definition.size.y * 0.5, foot.y, 0.01, "on the ground")
	assert_eq(_root.places.lying(&"oasis", &"sun_cell"), before + 1)
	assert_true(_avatar.grasp.take(item))
	assert_eq(_root.places.lying(&"oasis", &"sun_cell"), before, "taken")
	assert_true(_root.places.is_taken(&"oasis", "sun_cell_test"))
	assert_null(_root.places.lay(&"nowhere", "x", &"sun_cell", Vector2.ZERO), "no such place")

## A sun-lily grows by garden_1 as the oasis is built, and again LILY_REGROW s
## after none is about; Daro's cell lies by the Glassworks once he has made one,
## one at a time, until the pump has it; nothing is made for a hostile town.
func test_the_wadees_make_their_things_again():
	await _hold_over(0, 0, 60.0)
	assert_eq(_root.places.lying(&"oasis", &"sun_lily"), 1, "a lily grows")
	assert_eq(_root.places.lying(&"oasis", &"sun_cell"), 0, "no cell until Daro makes one")
	_root.wadoo_state.make_cell()
	assert_eq(_root.places.lying(&"oasis", &"sun_cell"), 1, "Daro sets it out")
	_root._restock(_root.RESTOCK_EVERY)
	assert_eq(_root.places.lying(&"oasis", &"sun_cell"), 1, "only one at a time")
	var lily := _lying(&"sun_lily")
	assert_true(_avatar.grasp.take(lily))
	_root._restock(_root.LILY_REGROW)
	assert_eq(_root.places.lying(&"oasis", &"sun_lily"), 0, "none grows while you hold one")
	Item.consume(lily)
	_root._restock(_root.LILY_REGROW - 1.0)
	assert_eq(_root.places.lying(&"oasis", &"sun_lily"), 0, "not yet")
	_root._restock(1.0)
	assert_eq(_root.places.lying(&"oasis", &"sun_lily"), 1, "grown again")
	_root.wadoo_state.hostile = true
	Item.consume(_lying(&"sun_lily"))
	_root._restock(_root.LILY_REGROW * 2.0)
	assert_eq(_root.places.lying(&"oasis", &"sun_lily"), 0, "not for a hostile town")

## Fitting the cell and laying a lily, through the scene: each takes it from your
## hands and does its task; the pump works and the lily lies at the memorial, and
## so they are when the place is built again.
func test_fit_the_cell_and_lay_a_lily():
	await _hold_over(0, 0, 60.0)
	var pump := _oasis().get_node(SunPump.NAME) as SunPump
	var lilies := _oasis().get_node(MemorialLilies.NAME) as MemorialLilies
	_root.wadoo_state.make_cell()
	assert_true(_avatar.grasp.take(_lying(&"sun_cell")))
	assert_true(pump.can_interact(_avatar))
	pump.interact(_avatar)
	assert_null(_avatar.grasp.item, "fitted: out of your hands")
	assert_true(_root.wadoo_state.did(&"pump"))
	assert_true(pump.working, "it draws")
	assert_lt(pump.grown, 1.0, "the garden grows green over a minute")
	assert_true(_avatar.grasp.take(_lying(&"sun_lily")))
	lilies.interact(_avatar)
	assert_null(_avatar.grasp.item, "laid")
	assert_eq(int(_root.wadoo_state.tasks[&"lilies"]), 1)
	assert_eq(lilies.count, 1, "it lies before the first stone")
	assert_eq(_root.wadoo_state.regard, 2, "two tasks done")
	await _hold_over(11000, 0, 200.0)
	await _hold_over(0, 0, 60.0)
	pump = _oasis().get_node(SunPump.NAME) as SunPump
	assert_true(pump.working and pump.grown == 1.0, "built again: green at once")
	assert_eq((_oasis().get_node(MemorialLilies.NAME) as MemorialLilies).count, 1)
	assert_eq(_root.places.lying(&"oasis", &"sun_cell"), 0, "no cell once the pump has one")

## Wenna's healing and a gift, as the scene answers the town (WadooSite.you, on_give).
func test_the_town_sees_what_you_hold_and_your_wounds():
	await _hold_over(0, 0, 60.0)
	assert_eq(_root._you_to_wadoo()["holding"], "", "empty hands")
	assert_false(_root._you_to_wadoo()["hurt"])
	_avatar.health.current = _avatar.health.max - 30.0
	assert_true(_root._you_to_wadoo()["hurt"])
	_root._wadoo_effect("heal")
	assert_eq(_avatar.health.current, _avatar.health.max, "Wenna mends you")
	var armlet := _lying(&"armlet")
	assert_not_null(armlet, "Lio's armlet lies out past the breach")
	assert_true(_avatar.grasp.take(armlet))
	assert_eq(_root._you_to_wadoo()["holding"], "armlet")
	assert_false(_root._give_held(&"sun_cell"), "not what you hold")
	assert_true(_root._give_held(&"armlet"))
	assert_null(_avatar.grasp.item, "given")
	assert_true(_root.places.is_taken(&"oasis", "armlet_breach"), "and never back")
