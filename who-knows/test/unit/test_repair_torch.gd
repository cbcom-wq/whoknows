extends GutTest

## The repair torch in the real ship (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §8): it mends, eats plates,
## rebuilds, and brings the droid round.

var _root: Node
var _ship: Ship
var _avatar: Avatar
var _item: Item
var _torch: RepairTorch

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _ship.get_node("Interior/Avatar")
	_item = null
	for node in _ship.items.get_children():
		if node is Item and node.definition.id == &"repair_torch":
			_item = node
	_torch = _item.use_node as RepairTorch
	# New bodies join the physics space on the next physics frame.
	await wait_physics_frames(2)

## An aim from `from` toward `to`, both interior-local.
func _aim_inside(from: Vector3, to: Vector3) -> Transform3D:
	var f := _ship.interior.global_transform * from
	var t := _ship.interior.global_transform * to
	return Transform3D(Basis.looking_at(t - f, Vector3.UP), f)

## An interior wall with a hull block behind it that the torch sees as that
## block: [aim, the block's cell].
func _wall() -> Array:
	for face in _ship.interior_builder.layout().faces():
		if face["kind"] != InteriorLayout.Kind.WALL or not face["owner"]:
			continue
		var coord: Vector3i = face["coord"]
		var normal: Vector3i = face["normal"]
		if normal.y != 0 or not _ship.grid.has_block(coord + normal) \
				or _ship.grid.get_block(coord + normal).block_id != &"hull":
			continue
		var eye := InteriorBuilder.interior_center(coord) - Vector3(normal) * 0.3
		var aim := _aim_inside(eye, eye + Vector3(normal))
		var t := _torch.target(_item, aim, _avatar)
		if t.get("kind") == &"block" and t["cell"] == coord + normal:
			return [aim, coord + normal]
	return []

func _hold(aim: Transform3D, seconds: float, step := 0.1) -> void:
	for i in roundi(seconds / step):
		_torch.hold(_item, aim, _ship.items, _avatar, step)

func test_the_ship_starts_with_a_full_torch():
	assert_not_null(_item, "stocked in the weapon room's ammo crate")
	assert_eq(_torch.feed, RepairTorch.HOPPER, "three plates' worth")

## Three plates to load, in a pile on the closet's bottom shelf where a crate
## stood (spec §8.1; the owner chose the crate's place, 2026-10-02).
func test_the_ship_starts_with_three_plates_stowed_in_a_pile():
	var piled: Array[Item] = []
	for node in _ship.items.get_children():
		if node is Item and node.definition.id == &"scrap_plate":
			assert_eq(node.state, Item.State.STOWED, "on the shelf, not loose")
			piled.append(node)
	assert_eq(piled.size(), InteriorProps.PLATE_STACK)
	for item in _ship.items.get_children():
		assert_ne((item as Item).definition.id, &"crate", "the plates took the crate's place")
	piled.sort_custom(func(a: Item, b: Item) -> bool: return a.global_position.y < b.global_position.y)
	for i in range(1, piled.size()):
		var below := _ship.interior.to_local(piled[i - 1].global_position)
		var above := _ship.interior.to_local(piled[i].global_position)
		assert_almost_eq(Vector2(above.x, above.z), Vector2(below.x, below.z), Vector2.ONE * 0.001, "one on another")
		assert_almost_eq(above.y - below.y, InteriorProps.PLATE_LIFT, 0.001)

## A scrap plate lying loose on the deck at `at` (interior-local).
func _plate(at: Vector3) -> Item:
	var plate := Item.new()
	plate.setup(ItemCatalog.load_from_dir().get_def(&"scrap_plate"))
	_ship.items.add_child(plate)
	plate.global_position = _ship.interior.global_transform * at
	plate.set_loose()
	return plate

func test_holding_mends_at_its_rate_for_one_feed_an_hp():
	var wall := _wall()
	assert_false(wall.is_empty(), "a hull wall the torch can see")
	var cell: Vector3i = wall[1]
	_ship.take_damage(cell, 100.0)
	_hold(wall[0], 2.0)
	assert_almost_eq(_ship.damage_at(cell), 50.0, 0.5)
	assert_almost_eq(_torch.feed, RepairTorch.HOPPER - 50.0, 0.5)
	assert_eq(_torch.busy(), "welding")

## Health as a share with H and the stage beside it, and the hopper as SCRAP
## (owner, 2026-10-02: "WRECKED 0%" read either way, and "FEED" said nothing).
func test_the_aim_line_names_health_and_scrap():
	var wall := _wall()
	var cell: Vector3i = wall[1]
	var name := _ship.catalog.get_def(_ship.grid.get_block(cell).block_id).display_name.to_upper()
	var hp := float(_ship.catalog.get_def(_ship.grid.get_block(cell).block_id).hp)
	assert_eq(_torch.aim_text(_item, wall[0], _avatar), "%s · 100%% H · INTACT · SCRAP 300/300" % name)
	_ship.take_damage(cell, hp * 0.6)
	assert_eq(_torch.aim_text(_item, wall[0], _avatar), "%s · 40%% H · DAMAGED · SCRAP 300/300" % name)
	_ship.take_damage(cell, hp * 0.5)
	assert_eq(_torch.aim_text(_item, wall[0], _avatar), "%s · 0%% H · WRECKED · SCRAP 300/300" % name)
	assert_eq(_torch.status(), "scrap 300/300")

func test_an_empty_hopper_does_nothing():
	var wall := _wall()
	var cell: Vector3i = wall[1]
	_ship.take_damage(cell, 100.0)
	_torch.feed = 0.0
	_hold(wall[0], 1.0)
	assert_eq(_ship.damage_at(cell), 100.0)
	assert_eq(_torch.busy(), "")

func test_out_of_reach_it_sees_nothing():
	var wall := _wall()
	var aim: Transform3D = wall[0]
	aim.origin -= -aim.basis.z * 3.0
	assert_ne(_torch.target(_item, aim, _avatar).get("cell", ShipCells.NONE), wall[1])

func test_it_eats_a_plate_and_refuses_one_when_full():
	var plate := _plate(DeckPaths.floor_point(Vector3i(0, 0, 1)) + Vector3.UP * 0.05)
	plate.freeze = true
	await wait_physics_frames(2)
	var above := plate.global_position + Vector3.UP * 0.4
	var aim := Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), above)
	assert_eq(_torch.target(_item, aim, _avatar).get("kind"), &"plate")
	assert_eq(_torch.aim_text(_item, aim, _avatar), "TORCH FULL · SCRAP 300/300")
	_hold(aim, 1.0)
	assert_true(is_instance_valid(plate), "full: refused")
	_torch.feed = 150.0
	assert_eq(_torch.aim_text(_item, aim, _avatar), "LOAD PLATE +100 · SCRAP 150/300")
	_hold(aim, RepairTorch.PLATE_TIME + 0.2)
	assert_false(is_instance_valid(plate), "eaten")
	assert_almost_eq(_torch.feed, 250.0, 0.001)

func test_it_rebuilds_a_hole_from_outside_wrecked_for_its_cost():
	var gone := Vector3i.ZERO
	for coord: Vector3i in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"hull" and not _ship.grid.has_block(coord + Vector3i(1, 0, 0)) \
				and not _ship.inner_cells.has(coord):
			gone = coord
			break
	_ship.take_damage(gone, 100_000.0)
	assert_false(_ship.grid.has_block(gone))
	var from := _ship.exterior.to_global(ShipGrid.cell_center(gone) + Vector3(2.0, 0.1, 0.1))
	var to := _ship.exterior.to_global(ShipGrid.cell_center(gone))
	var aim := Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	var t := _torch.target(_item, aim, _avatar)
	assert_eq(t.get("kind"), &"hole")
	assert_eq(t.get("cell"), gone)
	assert_eq(_torch.aim_text(_item, aim, _avatar), "REBUILD HULL PLATE · COSTS 100 · SCRAP 300/300")
	var held := 0.0
	while not _ship.grid.has_block(gone) and held < RepairTorch.REBUILD_TIME + 1.0:
		_torch.hold(_item, aim, _ship.items, _avatar, 0.1)
		held += 0.1
	assert_true(_ship.grid.has_block(gone), "put back")
	assert_almost_eq(held, RepairTorch.REBUILD_TIME, 0.15)
	var hp := float(_ship.catalog.get_def(&"hull").hp)
	assert_eq(_ship.damage_at(gone), hp * BlockDamage.WRECKED_AT, "wrecked")
	assert_almost_eq(_torch.feed, RepairTorch.HOPPER - RepairTorch.REBUILD_COST, 0.001)

func test_it_brings_the_droid_round():
	var droid: Npc = _ship.npc_director.live.values()[0]
	droid.take_damage(1000.0)
	assert_true(droid.down)
	var from := droid.global_position + Vector3(1.0, droid.species.height * 0.5, 0)
	var at := droid.global_position + Vector3(0, droid.species.height * 0.5, 0)
	var aim := Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	assert_eq(_torch.target(_item, aim, _avatar).get("kind"), &"npc")
	_hold(aim, 0.1)
	assert_false(droid.down)
	assert_almost_eq(_torch.feed, RepairTorch.HOPPER - droid.species.max_health * droid.species.wake_health, 0.001)

func test_the_feed_is_saved_with_the_torch():
	_torch.feed = 123.0
	var back := RepairTorch.new()
	back.restore(_torch.save())
	assert_eq(back.feed, 123.0)
	back.free()
