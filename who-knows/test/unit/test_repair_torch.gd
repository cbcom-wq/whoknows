extends GutTest

## The repair torch in the real ship (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §8): it mends, rebuilds and brings
## the droid round, using nothing up (owner, 2026-10-03).

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
		if t.get("kind") == &"part" and t["cell"] == coord + normal:
			return [aim, coord + normal]
	return []

## An aim from outside the hull at an outer hull block off the centre line:
## [aim, the block's cell].
func _outside() -> Array:
	for coord: Vector3i in _ship.damage.sections_of:
		if coord.x == 0 or _ship.grid.get_block(coord).block_id != &"hull":
			continue
		var out := Vector3i(signi(coord.x), 0, 0)
		if _ship.grid.has_block(coord + out):
			continue
		var from := _ship.exterior.to_global(ShipGrid.cell_center(coord) + Vector3(out) * 2.0 + Vector3(0, 0.1, 0.1))
		var to := _ship.exterior.to_global(ShipGrid.cell_center(coord))
		return [Transform3D(Basis.looking_at(to - from, Vector3.UP), from), coord]
	return []

func _section(cell: Vector3i) -> StringName:
	return _ship.damage.sections_of[cell][0]

## An aim from the walkable cell beside the quantum core at its column.
func _at_core() -> Array:
	for coord: Vector3i in _ship.damage.component_of:
		if _ship.damage.component_of[coord] != &"quantum_core":
			continue
		for n: Vector3i in ShipGrid.FACE_OFFSETS:
			if n.y != 0 or not _ship.interior_builder.walkable_coords().has(coord + n):
				continue
			var eye := DeckPaths.floor_point(coord + n) + Vector3(0, 1.2, 0)
			var aim := _aim_inside(eye, DeckPaths.floor_point(coord) + Vector3(0, 1.2, 0))
			if _torch.target(_item, aim, _avatar).get("part") == &"quantum_core":
				return [aim, coord]
	return []

func _hold(aim: Transform3D, seconds: float, step := 0.1) -> void:
	for i in roundi(seconds / step):
		_torch.hold(_item, aim, _ship.items, _avatar, step)

func test_the_ship_starts_with_a_torch():
	assert_not_null(_item, "stocked in the weapon room's ammo crate")

## Three plates of salvage, in a pile on the closet's bottom shelf where a crate
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

## A section from outside (ship damage sections spec §6): SECTION_RATE of it
## a second.
func test_a_section_is_mended_from_outside_at_its_rate():
	var out := _outside()
	assert_false(out.is_empty(), "an outer hull block to aim at")
	var section := _section(out[1])
	_ship.damage.section_damage[section] = _ship.damage.section_hp[section] * 0.5
	_ship._apply_view()
	_hold(out[0], 2.0)
	assert_almost_eq(_ship.damage.health(section), 0.5 + RepairTorch.SECTION_RATE * 2.0, 0.005)
	assert_eq(_torch.busy(), "welding")

## Health as a share with H (owner, 2026-10-02), and no scrap to show.
func test_the_aim_line_outside_names_the_section():
	var out := _outside()
	var section := _section(out[1])
	var label: String = ShipDamage.SECTION_LABELS[section]
	assert_eq(_torch.aim_text(_item, out[0], _avatar), "%s HULL · 100%% H" % label)
	_ship.damage.section_damage[section] = _ship.damage.section_hp[section] * 0.55
	_ship._apply_view()
	assert_eq(_torch.aim_text(_item, out[0], _avatar), "%s HULL · 45%% H" % label)
	assert_eq(_torch.status(), "")

## To fix the hull you go outside (the owner, 2026-10-03).
func test_from_inside_the_hull_refuses():
	var wall := _wall()
	assert_false(wall.is_empty(), "a hull wall the torch can see")
	var section := _ship.damage.part_of(wall[1])
	_ship.damage.section_damage[section] = _ship.damage.section_hp[section] * 0.5
	_ship._apply_view()
	assert_string_starts_with(_torch.aim_text(_item, wall[0], _avatar), "HULL ")
	assert_string_ends_with(_torch.aim_text(_item, wall[0], _avatar), "· WELD FROM OUTSIDE")
	_hold(wall[0], 1.0)
	assert_almost_eq(_ship.damage.health(section), 0.5, 0.0001, "nothing mended")
	assert_eq(_torch.busy(), "")

func test_a_component_inside_is_mended_where_it_is():
	var core := _at_core()
	assert_false(core.is_empty(), "the quantum core to aim at")
	_ship.take_damage(core[1], 150.0)
	assert_eq(_torch.aim_text(_item, core[0], _avatar), "QUANTUM CORE · 40% H · DAMAGED")
	_hold(core[0], 2.0)
	assert_almost_eq(_ship.damage.component_damage[&"quantum_core"], 100.0, 0.5)

## Long welding never runs dry: the core and a wrecked section mended whole,
## one after another.
func test_it_never_runs_out():
	var core := _at_core()
	_ship.take_damage(core[1], 240.0)
	_hold(core[0], 12.0)
	assert_almost_eq(_ship.damage.component_damage[&"quantum_core"], 0.0, 0.001)
	var out := _outside()
	var section := _section(out[1])
	_ship.damage.section_damage[section] = _ship.damage.section_hp[section]
	_ship._apply_view()
	_hold(out[0], 1.0 / RepairTorch.SECTION_RATE + 0.5)
	assert_almost_eq(_ship.damage.health(section), 1.0, 0.001)

func test_out_of_reach_it_sees_nothing():
	var wall := _wall()
	var aim: Transform3D = wall[0]
	aim.origin -= -aim.basis.z * 3.0
	assert_ne(_torch.target(_item, aim, _avatar).get("cell", ShipCells.NONE), wall[1])

## A plate is salvage, not feed: aimed at, it is nothing to the torch.
func test_a_plate_is_left_alone():
	var plate := _plate(DeckPaths.floor_point(Vector3i(0, 0, 1)) + Vector3.UP * 0.05)
	plate.freeze = true
	await wait_physics_frames(2)
	var above := plate.global_position + Vector3.UP * 0.4
	var aim := Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), above)
	assert_eq(_torch.target(_item, aim, _avatar).get("kind", &""), &"")
	assert_eq(_torch.aim_text(_item, aim, _avatar), "")
	_hold(aim, 2.0)
	assert_true(is_instance_valid(plate), "not eaten")
	assert_eq(_torch.busy(), "")

## A piece knocked off is welded back as its section rises: aimed at the hole,
## the torch mends the section (spec §6).
func test_a_hole_is_its_section_and_its_piece_comes_back():
	var section := &"port_mid"
	_ship.damage.section_damage[section] = _ship.damage.section_hp[section]
	_ship._apply_view()
	var gone: Vector3i = _ship.damage.pieces[section][0]
	assert_false(_ship.grid.has_block(gone))
	var out := Vector3i.ZERO
	for n: Vector3i in ShipGrid.FACE_OFFSETS:
		if not _ship.grid.has_block(gone + n) and _ship.damage.launch.has(gone - n):
			out = n
			break
	var from := _ship.exterior.to_global(ShipGrid.cell_center(gone) + Vector3(out) * 2.0 + Vector3(0.1, 0.1, 0.1))
	var to := _ship.exterior.to_global(ShipGrid.cell_center(gone))
	var aim := Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	var t := _torch.target(_item, aim, _avatar)
	assert_eq(t.get("kind"), &"part")
	assert_eq(t.get("part"), section)
	assert_true(t.get("outside"))
	var held := 0.0
	while _ship.damage.health(section) < 1.0 and held < 30.0:
		_torch.hold(_item, aim, _ship.items, _avatar, 0.1)
		held += 0.1
	assert_true(_ship.grid.has_block(gone), "put back")
	assert_almost_eq(held, 1.0 / RepairTorch.SECTION_RATE, 0.2, "25 s from nothing to whole")

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

## Nothing to save; an old save's feed is ignored.
func test_it_saves_nothing():
	assert_eq(_torch.save(), {})
	_torch.restore({"feed": 123.0})
