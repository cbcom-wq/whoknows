extends GutTest

## Flat ground at height `y`, for planting a hub in the open.
class Ground extends PlantSurface:
	var y := 0.0
	func _init(p_y: float) -> void:
		y = p_y
	func cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
		var to := from + dir * reach
		if from.y >= y and to.y <= y:
			return {"position": from.lerp(to, (from.y - y) / (from.y - to.y)), "normal": Vector3.UP}
		return {}
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return &"rock:origin"

## The floating origin in the real flight scene (docs/superpowers/specs/
## 2026-09-24-asteroids-design.md §4): who it follows, what it moves, and the
## rule that everything outside is covered.

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _universe: Universe
var _outside: Node3D

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_universe = _root.get_node_or_null("Universe") as Universe
	_outside = _root.get_node("Outside")

func _out(at: Vector3) -> void:
	_avatar.enter_suit(_outside, Transform3D(Basis.IDENTITY, at), Vector3.ZERO, _ship.exterior)

func _back_in() -> void:
	_avatar.enter_plating(_ship.interior, Transform3D(Basis.IDENTITY, _ship.interior.to_global(Vector3(0, -0.95, 6))),
		0.0, Vector3.ZERO, Quaternion.IDENTITY)

## A node is covered if it, or something above it, is shifted, or is a ship
## asleep, held as a UniversePoint (many ships spec §5.1).
func _covered(node: Node) -> bool:
	while node != null:
		if node.is_in_group(Universe.EXTERIOR_SPACE) or node.is_in_group(Fleet.ASLEEP):
			return true
		node = node.get_parent()
	return false

func _uncovered() -> Array:
	var out := []
	for n in _root.find_children("*", "Node3D", true, false):
		if not (n is PhysicsBody3D or n is GeometryInstance3D):
			continue
		if _in_an_interior(n):
			continue
		if not _covered(n):
			out.append(str(_root.get_path_to(n)))
	return out

## Inside any ship or base: interiors never move (many ships spec §5.1;
## habitat modules spec §9.3).
func _in_an_interior(n: Node) -> bool:
	var homes: Array[GridHome] = []
	for ship: Ship in _root.fleet.ships():
		homes.append(ship)
	for base: Base in _root.bases.awake():
		homes.append(base)
	for home in homes:
		if home.interior.is_ancestor_of(n):
			return true
	return false

func test_the_universe_survived_the_parse():
	assert_true(_universe is Universe, "FlightTest/Universe is a Universe")

func test_aboard_the_focus_is_the_hull():
	assert_eq(_universe.focus, _ship.exterior)
	assert_true(_ship.exterior.is_in_group(Universe.EXTERIOR_SPACE))

func test_on_a_spacewalk_the_focus_is_you_and_back_aboard_the_hull():
	_out(Vector3(0, 0, 12))
	assert_eq(_universe.focus, _avatar)
	assert_true(_avatar.is_in_group(Universe.EXTERIOR_SPACE))
	_back_in()
	assert_eq(_universe.focus, _ship.exterior)
	assert_false(_avatar.is_in_group(Universe.EXTERIOR_SPACE), "aboard, you never move")

func test_a_shift_moves_the_hull_and_leaves_the_interior():
	var interior_at := _ship.interior.global_position
	var avatar_at := _avatar.global_position
	_ship.exterior.global_position = Vector3(2500, 0, -40)
	assert_true(_universe.check())
	assert_eq(_ship.exterior.global_position, Vector3(-500, 0, -40))
	assert_eq(_ship.interior.global_position, interior_at)
	assert_eq(_avatar.global_position, avatar_at)

func test_a_spacewalk_across_a_shift_keeps_you_beside_your_ship():
	_ship.exterior.global_position = Vector3(0, 0, -2490)
	_out(Vector3(3, 1, -2478))
	var offset := _avatar.global_position - _ship.exterior.global_position
	_avatar.global_position += Vector3(0, 0, -20)
	offset += Vector3(0, 0, -20)
	assert_true(_universe.check())
	assert_almost_eq(_avatar.global_position - _ship.exterior.global_position, offset, Vector3.ONE * 0.0001)

func test_everything_outside_is_covered():
	assert_eq(_uncovered(), [], "every body and mesh outside the interior shifts")

func test_with_a_second_ship_everything_outside_is_covered():
	var place := Transform3D(Basis.IDENTITY, _ship.exterior.global_position + Vector3(300, 0, 0))
	_root.fleet.spawn(_root._starter_grid(), place)
	assert_eq(_uncovered(), [])

func test_with_a_ship_asleep_everything_outside_is_covered():
	var place := Transform3D(Basis.IDENTITY, _ship.exterior.global_position + Vector3(0, 0, 25000))
	var far: Ship = _root.fleet.spawn(_root._starter_grid(), place)
	_root.fleet.check_sleep()
	assert_true(_root.fleet.sleeping(far))
	assert_eq(_uncovered(), [])

func test_everything_outside_is_covered_on_a_spacewalk():
	_out(Vector3(0, 0, 12))
	assert_eq(_uncovered(), [])

func _salvage() -> SalvageField:
	return _outside.get_node_or_null("SalvageField") as SalvageField

## Quantum energy spec §10.1, §10.2: the near cloud is out behind the stern
## from the first frame, each item a member of its own under a field that is
## never moved and never a member, so the walk below covers them.
func test_the_near_cloud_is_loaded_behind_the_stern_from_the_start():
	var field := _salvage()
	assert_not_null(field, "Outside/SalvageField")
	if field == null:
		return
	assert_false(field.is_in_group(Universe.EXTERIOR_SPACE))
	assert_eq(field.global_transform, Transform3D.IDENTITY)
	var items := field.loaded_items(SalvageField.NEAR)
	assert_eq(items.size(), 12)
	var hatch: Transform3D = (_ship.airlocks.values()[0] as Airlock).alcove.outer_hatch.global_transform
	for item in items:
		assert_true(item.is_in_group(Universe.EXTERIOR_SPACE))
		var aft := _ship.exterior.global_transform.affine_inverse() * item.global_position \
			- _ship.exterior.global_transform.affine_inverse() * hatch.origin
		assert_between(aft.z, 12.0, 40.0, "%s is aft of the stern" % item.name)
	assert_eq(_uncovered(), [], "and every one of them is covered")

func test_a_shift_moves_the_salvage_with_the_hull():
	var items := _salvage().loaded_items(SalvageField.NEAR)
	assert_eq(items.size(), 12)
	_ship.exterior.global_position = Vector3(2500, 0, -40)
	var offsets := items.map(func(i: Item) -> Vector3: return i.global_position - _ship.exterior.global_position)
	assert_true(_universe.check())
	for k in items.size():
		assert_almost_eq(items[k].global_position - _ship.exterior.global_position, offsets[k], Vector3.ONE * 0.001)
	assert_eq(_salvage().global_transform, Transform3D.IDENTITY)

func test_everything_outside_is_covered_with_a_herd_awake():
	var stream: AsteroidStream = _root.get_node("AsteroidStream")
	await wait_physics_frames(5)
	var detail: AsteroidDetail = stream.details.nearest((_root.get_node("Ship") as Ship).exterior.global_position)
	var site := RockSite.new(detail, stream.seed)
	var at := site.frame() * site.start_pose(site.records[0], 0.0).origin
	var out := (at - detail.global_position).normalized()
	for i in 20:
		_ship.exterior.global_position = at + out * lerpf(400.0, 60.0, i / 19.0)
		_ship.exterior.linear_velocity = Vector3.ZERO
		await wait_physics_frames(3)
	assert_gt((_root.exterior_npcs as NpcDirector).live.size(), 0, "a herd is awake")
	assert_eq(_uncovered(), [], "skitters and their looks shift too")

func test_the_readout_starts_hidden():
	var label := _root.get_node_or_null("Prompt/UniverseReadout") as Label
	assert_not_null(label)
	if label != null:
		assert_false(label.visible)

func test_the_hull_and_a_spacewalker_touch_rocks():
	assert_true(_ship.exterior.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_eq(_ship.exterior.collision_mask, 1 | BodyProxy.LAYER | 64 | Npc.LAYER)
	assert_true(_ship.exterior.continuous_cd)
	assert_gt(float(_ship.exterior.get_meta(AsteroidStream.ANCHOR_RADIUS)), 7.0)
	_out(Vector3(0, 0, 12))
	assert_true(_avatar.is_in_group(AsteroidStream.SPACE_ANCHOR))
	assert_eq(_avatar.collision_mask, 1 | BodyProxy.LAYER | 32 | 64 | Npc.LAYER)
	_back_in()
	assert_false(_avatar.is_in_group(AsteroidStream.SPACE_ANCHOR))

func test_the_cameras_outside_see_as_far_as_rocks_are_drawn():
	# Godot's default is 4 km: past that, no big rock was ever drawn.
	var far := AsteroidStream.FADE_END[AsteroidRecipe.Tier.GIANT]
	for path in ["Ship/Exterior/ChaseCamera", "Ship/Canopy/CanopyCam"]:
		assert_gte((_root.get_node(path) as Camera3D).far, far, path)
	assert_gte(_avatar.camera.far, far, "on a spacewalk")
	# The world scale spec §5.2: far enough for the horizon of the world
	# you are over, and past every proxy.
	assert_gt(BodyProxy.VIEW_FAR, BodyProxy.PROXY_AT)
	assert_gte(BodyProxy.VIEW_FAR, BodyProxy.PROXY_AT + SystemRecipe.STAR_RADIUS.y, "every proxy is drawn whole, the star's too")
	for path in ["Ship/Exterior/ChaseCamera", "Ship/Canopy/CanopyCam"]:
		assert_eq((_root.get_node(path) as Camera3D).far, BodyProxy.VIEW_FAR, path)
	assert_eq(_avatar.camera.far, BodyProxy.VIEW_FAR, "on a spacewalk")

func test_the_sun_throws_shadows_far_enough_to_shape_a_big_rock():
	var sun: DirectionalLight3D = _root.get_node("DirectionalLight3D")
	assert_gte(sun.directional_shadow_max_distance, AsteroidStream.SHADOW_REACH)

func test_everything_outside_is_covered_beside_a_world():
	var system: SystemRecipe = _root.system
	var planet := system.planets()[0]
	_root.hop_index = system.bodies.find(planet) - 1
	assert_true(_root.hop(1))
	await wait_physics_frames(2)
	var surface: WorldSurface = (_root.star_system.proxy(planet.id) as BodyProxy).surface()
	assert_not_null(surface)
	surface.finish()
	assert_eq(_uncovered(), [], "every chunk of ground shifts too")

## The pistol on a spacewalk: the bolt and its flashes are outside, so they
## are covered too.
func test_a_shot_on_a_spacewalk_is_covered():
	var pistol: Item = null
	for node in get_tree().get_nodes_in_group(Item.GROUP):
		if _root.is_ancestor_of(node) and (node as Item).definition.id == &"plasma_pistol":
			pistol = node
	assert_not_null(pistol, "the pistol is aboard")
	if pistol == null:
		return
	assert_true(_avatar.grasp.take(pistol))
	_out(Vector3(0, 0, 12))
	await wait_physics_frames(2)
	assert_true(_avatar.grasp.use(), "it fires outside")
	var shots := _root.find_children("*", "Node3D", true, false).filter(func(n): return n is PlasmaBolt)
	assert_eq(shots.size(), 1)
	assert_false(_in_an_interior(shots[0]), "the bolt is outside")
	assert_eq(_uncovered(), [], "and covered")

## Ship library spec §6.2: a ship arriving out of warp, its wake and its flash,
## is covered.
func test_a_ship_arriving_is_covered():
	var place := Transform3D(Basis.IDENTITY, _ship.exterior.global_position + Vector3(300, 0, 0))
	var ship: Ship = _root.fleet.spawn(_root._starter_grid(), place)
	var a := WarpArrival.play(ship.exterior, place)
	a.set_physics_process(false)
	a._physics_process(0.3)
	assert_eq(_uncovered(), [], "flying in, its wake behind it")
	a._physics_process(WarpArrival.DURATION)
	assert_eq(_uncovered(), [], "and its flash")

## Habitat modules spec §9.3: a base outside, settled, with a hub package
## adrift beside it as a stray, is covered; its interior never moves. Far
## off, it sleeps, and a sleeping base has no nodes at all.
func test_with_a_base_and_a_package_adrift_everything_outside_is_covered():
	var at := _ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	var base: Base = _root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	assert_not_null(base)
	if base == null:
		return
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	var item := Item.new()
	item.setup(_ship.item_catalog.get_def(&"hub_package"), 0.5)
	_outside.add_child(item, true)
	item.global_position = at + Vector3(6, 4, 0)
	item.set_space(true)
	item.set_loose()
	_root.strays.adopt(item)
	assert_eq(_uncovered(), [], "the base, its legs and the package all shift")
	_universe.origin = _universe.origin.plus(Vector3(25000, 0, 0))
	_root.bases.check_sleep()
	assert_null(_root.find_child("Base1", true, false), "asleep, no node of it is left")

## The hose out on a spacewalk (quantum energy spec §11.3, §14.2): the nozzle
## is never a member, the line is, and a shift keeps both where they were
## relative to you.
func test_everything_outside_is_covered_with_the_hose_out():
	var airlock: Airlock = _ship.airlocks.values()[0]
	var reel: HoseReel = airlock.alcove.reel
	# Held out of the reel, `reel.item` is null: keep the nozzle itself.
	var nozzle := reel.item
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	# A hatch frame's +z points INTO its room: 3 m outside is -3 on z.
	_out(airlock.alcove.outer_hatch.global_transform * Vector3(0, 1.0, -3.0))
	await wait_physics_frames(2)
	assert_true(_avatar.grasp.take(nozzle))
	# Hands' grab swipe takes 0.3 s and moves the nozzle: wait it out.
	await wait_physics_frames(30)
	assert_eq(_avatar.grasp.item, nozzle, "still in your hand")
	assert_eq(_uncovered(), [])
	assert_not_null(reel.line)
	assert_true(reel.line.is_in_group(Universe.EXTERIOR_SPACE))
	assert_false(nozzle.is_in_group(Universe.EXTERIOR_SPACE), "the nozzle is never a member")

func test_a_shift_with_the_hose_out_keeps_it_where_it_was_relative_to_you():
	var airlock: Airlock = _ship.airlocks.values()[0]
	var reel: HoseReel = airlock.alcove.reel
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	# A hatch frame's +z points INTO its room: 3 m outside is -3 on z.
	_out(airlock.alcove.outer_hatch.global_transform * Vector3(0, 1.0, -3.0))
	await wait_physics_frames(2)
	_avatar.grasp.take(reel.item)
	# Hands' grab swipe takes 0.3 s and moves the nozzle: wait it out.
	await wait_physics_frames(30)
	var to_reel := reel.anchor() - _avatar.global_position
	var to_tail := reel.line.tail() - _avatar.global_position
	assert_lte(_line_reach(reel), HoseRope.LENGTH + 1.0, "the line lies along its own reel")
	_universe.shift(Vector3(2000, 0, 4000))
	# At once, before the next tick pins its ends again (which would hide a
	# line left behind): the line's own points went with the hull.
	assert_lte(_line_reach(reel), HoseRope.LENGTH + 1.0, "the line moved with the hull")
	await wait_physics_frames(2)
	assert_almost_eq(reel.anchor() - _avatar.global_position, to_reel, Vector3.ONE * 0.05)
	assert_almost_eq(reel.line.tail() - _avatar.global_position, to_tail, Vector3.ONE * 0.05)
	assert_lte(_line_reach(reel), HoseRope.LENGTH + 1.0, "and it stays there")
	assert_eq(_uncovered(), [])

## How far the farthest point of the hose's line lies from its reel, in the
## world: a line left behind by a shift has its middle kilometres away while
## both its ends are pinned to the hull and the nozzle.
func _line_reach(reel: HoseReel) -> float:
	var far := 0.0
	for p in reel.line.rope.points:
		far = maxf(far, reel.line.to_global(p).distance_to(reel.anchor()))
	return far

## Habitat modules spec §9.1, quantum energy spec §11.1: a base's hub has an
## airlock, so a reel and a nozzle too; it draws into the base's own store, and
## its line lives in the base's outside, covered like the ship's.
func test_a_bases_reel_has_a_nozzle_and_credits_the_bases_own_store():
	var at := _ship.exterior.global_position + Vector3(0, -40, 60)
	var r := Planting.fit(Ground.new(at.y), ModuleCatalog.get_def(ModuleCatalog.HUB), at, Vector3.FORWARD, 0)
	var base: Base = _root.bases.plant(ModuleCatalog.HUB, r, Ground.new(at.y))
	assert_not_null(base)
	if base == null:
		return
	base.tick_unfold(HabitatValues.UNFOLD + 0.1)
	assert_eq(base.airlocks.size(), 1, "the hub's airlock")
	var airlock: Airlock = base.airlocks.values()[0]
	assert_not_null(airlock.alcove, "its alcove on the base's hull")
	var reel: HoseReel = airlock.alcove.reel
	assert_not_null(reel, "a reel on it")
	if reel == null:
		return
	assert_not_null(reel.item, "a nozzle stocked")
	assert_eq(reel.item.definition.id, &"hose_nozzle")
	assert_eq(reel.item.state, Item.State.STOWED)
	assert_false(reel.item.is_in_group(Universe.EXTERIOR_SPACE), "the nozzle is never a member")
	assert_not_null(base.outside)
	assert_eq(reel.line_parent, base.outside, "the line lives in the base's outside")
	assert_true(reel.sink.is_valid())
	assert_true(reel.room.is_valid())
	assert_ne(reel, (_ship.airlocks.values()[0] as Airlock).alcove.reel, "not the ship's reel")
	assert_eq(_uncovered(), [], "the base's reel and nozzle are covered, on its hull")
	var ship_store := _ship.quantum.store.amount
	var base_store := base.quantum.store.amount
	var chunk := Item.new()
	chunk.setup(_ship.item_catalog.get_def(&"rock_chunk"))
	var worth := chunk.definition.quantum_value
	assert_gt(worth, 0, "salvage is worth something")
	assert_gt(base.quantum.store.room(), worth - 1, "the base's store has room for it")
	assert_true(reel.sink.call(chunk))
	assert_eq(base.quantum.store.amount, base_store + worth, "the base's store")
	assert_eq(_ship.quantum.store.amount, ship_store, "not the ship's")
	chunk.free()
