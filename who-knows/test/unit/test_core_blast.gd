extends GutTest

## The core going up (hostile ships spec §8.2): a destroyed ship's blast hurts
## what is near it and not what is far, chains into a nearly dead neighbour
## that then goes up once of its own, and the ship breaks into chunks that
## drift off outside and are gone in a minute.

const AWAY := Vector3(600, 0, 0)

var _root: Node
var _fleet: Fleet
var _starter: Ship
var _outside: Node3D

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_fleet = _root.fleet
	_starter = _root.get_node("Ship")
	_outside = _root.get_node("Outside")

## A starter `off` from the flight scene's own, which stays well out of reach.
func _spawn(off: Vector3) -> Ship:
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + AWAY + off)
	return _fleet.spawn(_root._starter_grid(), place)

## A skitter adrift outside at `at`.
func _npc(at: Vector3) -> Npc:
	var sp := NpcSpecies.new()
	sp.id = &"skitter"
	sp.size = 0.85
	sp.height = 0.4
	sp.mass = 25.0
	var npc := Npc.new()
	_outside.add_child(npc)
	npc.setup(NpcRecord.make(&"s:blast", &"skitter", &"x", Vector3.ZERO, 1), sp, NpcSite.new(), false,
		Transform3D(Basis.IDENTITY, at))
	npc.global_position = at
	npc.set_physics_process(false)
	return npc

## A loose scrap plate adrift outside at `at`.
func _item(at: Vector3) -> Item:
	var item := Item.new()
	item.setup(_starter.item_catalog.get_def(Ship.SHED_ITEM), 0.5)
	_outside.add_child(item, true)
	item.global_position = at
	item.set_space(true)
	item.set_loose()
	return item

## Past every section's hp in one hit: spill-over takes HULL % to 0.
func _wreck(ship: Ship) -> void:
	var cell: Vector3i = ship.damage.sections_of.keys()[0]
	ship.take_damage_many({cell: 1e9})

## Leaves `hp` of hull, shared over the sections by their size.
func _leave(ship: Ship, hp: float) -> void:
	var total := 0.0
	for id in ShipDamage.SECTIONS:
		total += ship.damage.section_hp[id]
	for id in ShipDamage.SECTIONS:
		var size: float = ship.damage.section_hp[id]
		ship.damage.section_damage[id] = size - hp * size / total
	ship._apply_view()

func _chunks() -> Array:
	return get_tree().get_nodes_in_group(Universe.EXTERIOR_SPACE).filter(func(n: Node) -> bool:
		return n is RigidBody3D and n.is_in_group(ShipBreakup.CHUNKS))

func _breakups() -> Array:
	return _outside.get_children().filter(func(n: Node) -> bool: return n is ShipBreakup)

func test_blast_falls_off():
	assert_almost_eq(CoreBlast.damage_at(0.0, 1.0), 400.0, 0.001)
	assert_almost_eq(CoreBlast.damage_at(60.0, 1.0), 200.0, 0.001)
	assert_eq(CoreBlast.damage_at(130.0, 1.0), 0.0)
	assert_gt(CoreBlast.damage_at(200.0, 2.0), 0.0, "a ship twice as heavy reaches twice as far")
	assert_eq(CoreBlast.scale_for(105.0), 1.0)
	assert_eq(CoreBlast.scale_for(10.0), 0.5)
	assert_eq(CoreBlast.scale_for(1000.0), 2.0)

func test_blast_hurts_what_is_near_not_far():
	var source := _spawn(Vector3.ZERO)
	var near := _spawn(Vector3(0, 0, 50))
	var far := _spawn(Vector3(0, 0, 300))
	var at := source.exterior.global_position
	var npc := _npc(at + Vector3(0, 30, 0))
	var plate := _item(at + Vector3(0, -20, 0))
	var kept := _item(at + Vector3(0, -200, 0))
	await wait_physics_frames(3)
	CoreBlast.go(_outside, at, 1.0, source)
	assert_lt(near.hull_whole(), 1.0, "the near ship is hurt")
	assert_eq(far.hull_whole(), 1.0, "the far one untouched")
	assert_eq(source.hull_whole(), 1.0, "the blast is never its own ship's")
	assert_lt(npc.health.current, npc.health.max, "the NPC at 30 m is hurt")
	assert_false(plate.is_inside_tree(), "a loose plate at 20 m breaks")
	assert_true(kept.is_inside_tree(), "one at 200 m does not")

func test_blast_reaches_you_on_a_spacewalk():
	var avatar: Avatar = _root.get_node("Ship/Interior/Avatar")
	var at := _starter.exterior.global_position + Vector3(0, 0, 40)
	avatar.enter_suit(_outside, Transform3D(Basis.IDENTITY, at + Vector3(0, 40, 0)), Vector3.ZERO, _starter.exterior)
	var before := avatar.health.current
	CoreBlast.go(_outside, at, 1.0, null)
	assert_lt(avatar.health.current, before, "out in your suit, it reaches you")

func test_the_flash_is_outside_and_goes():
	CoreBlast.go(_outside, _starter.exterior.global_position + AWAY, 1.0, null)
	var blasts := _outside.get_children().filter(func(n: Node) -> bool: return n is CoreBlast)
	assert_eq(blasts.size(), 1)
	var blast: CoreBlast = blasts[0]
	assert_true(blast.is_in_group(Universe.EXTERIOR_SPACE))
	assert_almost_eq(blast.light.omni_range, 300.0, 0.001)
	blast.tick(CoreBlast.FLASH_LIFE * 0.2)
	assert_gt(blast.flash.scale.x, 1.0, "it grows")
	blast.tick(CoreBlast.LIFE)
	await wait_process_frames(2)
	assert_false(is_instance_valid(blast), "and is gone")

func test_a_chain_of_blasts_destroys_each_once():
	var first := _spawn(Vector3.ZERO)
	var second := _spawn(Vector3(0, 0, 40))
	await wait_physics_frames(3)
	_leave(second, 100.0)
	assert_false(second.is_destroyed())
	var said := [0, 0]
	first.destroyed.connect(func(_s: Ship) -> void: said[0] += 1)
	second.destroyed.connect(func(_s: Ship) -> void: said[1] += 1)
	var names := [String(first.name), String(second.name)]
	watch_signals(_fleet)
	_wreck(first)
	assert_true(second.is_destroyed(), "the first blast takes the second with it")
	assert_eq(said, [1, 1], "each says so once")
	await wait_process_frames(3)
	assert_eq(said, [1, 1], "and never again")
	assert_signal_emit_count(_fleet, "ship_destroyed", 2, "the fleet destroys each once")
	var gone := [String(get_signal_parameters(_fleet, "ship_destroyed", 0)[0]),
		String(get_signal_parameters(_fleet, "ship_destroyed", 1)[0])]
	gone.sort()
	names.sort()
	assert_eq(gone, names, "one each")
	assert_signal_emit_count(_fleet, "left", 2)
	assert_false(is_instance_valid(first))
	assert_false(is_instance_valid(second))
	assert_eq(_fleet.ships(), [_starter] as Array[Ship])

func test_chunks_are_outside_and_go():
	var ship := _spawn(Vector3.ZERO)
	await wait_physics_frames(3)
	var velocity := Vector3(3, 0, -4)
	ship.exterior.linear_velocity = velocity
	ShipBreakup.go(ship, _outside)
	var chunks := _chunks()
	assert_between(chunks.size(), 26, 40, "6-10 large chunks and 20-30 small")
	for c: RigidBody3D in chunks:
		assert_eq(c.collision_layer, 0, "nothing hits a chunk")
		assert_eq(c.collision_mask, AsteroidBody.LAYER, "and it touches only rocks")
		assert_between((c.linear_velocity - velocity).length(), 4.0, 30.0, "flung off the hull's own velocity")
		assert_ne(c.angular_velocity, Vector3.ZERO, "spinning")
	var cells := 0
	for c: RigidBody3D in chunks:
		cells += c.get_meta(&"cells") as int
	assert_eq(cells, ship.grid.coords().size(), "every block of the ship is in a chunk")
	assert_false(ship.exterior.visible, "the hull itself is gone from view")
	var breakups := _breakups()
	assert_eq(breakups.size(), 1)
	(breakups[0] as ShipBreakup).tick(19.0)
	assert_eq(_chunks().size(), chunks.size(), "none goes before 20 s")
	(breakups[0] as ShipBreakup).tick(42.0)
	await wait_process_frames(2)
	assert_eq(_chunks().size(), 0, "all gone by a minute")
	assert_eq(_breakups().size(), 0, "and the breakup with them")

func test_a_destroyed_ship_goes_up_and_breaks_apart():
	var ship := _spawn(Vector3.ZERO)
	var near := _spawn(Vector3(0, 0, 50))
	await wait_physics_frames(3)
	_wreck(ship)
	assert_eq(_outside.get_children().filter(func(n: Node) -> bool: return n is CoreBlast).size(), 1, "the core goes up")
	assert_gt(_chunks().size(), 0, "the ship breaks apart")
	assert_lt(near.hull_whole(), 1.0, "and its neighbour is hurt")
	await wait_process_frames(2)
	assert_false(is_instance_valid(ship), "then it is gone")
	assert_gt(_chunks().size(), 0, "its chunks drift on")
