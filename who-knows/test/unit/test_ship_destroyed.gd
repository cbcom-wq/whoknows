extends GutTest

## A ship destroyed (hostile ships spec §8.1, §8.2): at 0% HULL it says so
## once, everyone aboard dies, and it leaves the fleet a frame later; the
## starter, which the fleet never lets go, is held destroyed instead: asleep
## where it was, never woken, and saved that way.

const OFF := Vector3(300, 0, 0)
const PATH := "user://test_ship_destroyed/game.json"

var _root: Node
var _fleet: Fleet
var _starter: Ship

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_fleet = _root.fleet
	_starter = _root.get_node("Ship")

func after_each():
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

func _spawn(off := OFF) -> Ship:
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + off)
	return _fleet.spawn(_root._starter_grid(), place)

## Past every section's hp in one hit: spill-over takes HULL % to 0.
func _wreck(ship: Ship) -> void:
	var cell: Vector3i = ship.damage.sections_of.keys()[0]
	ship.take_damage_many({cell: 1e9})

func test_zero_hull_destroys_once():
	var ship := _spawn()
	watch_signals(ship)
	assert_false(ship.is_destroyed())
	_wreck(ship)
	assert_eq(ship.hull_whole(), 0.0)
	assert_true(ship.is_destroyed())
	assert_signal_emit_count(ship, "destroyed", 1)
	assert_eq(get_signal_parameters(ship, "destroyed"), [ship])
	var cell: Vector3i = ship.damage.sections_of.keys()[1]
	assert_eq(ship.take_damage_many({cell: 500.0}), [] as Array[Vector3i], "nothing more lands")
	assert_signal_emit_count(ship, "destroyed", 1, "said once")

func test_a_spawned_ship_is_removed():
	var ship := _spawn()
	var id := Weapons.ship_id(ship)
	var slot := ship.interior_slot
	var ship_name := ship.name
	_starter.fire_control.mark(id)
	watch_signals(_fleet)
	_wreck(ship)
	await wait_process_frames(2)
	assert_false(is_instance_valid(ship), "freed")
	assert_null(_fleet.named(ship_name), "gone from the fleet")
	assert_eq(_fleet.ships().size(), 1)
	assert_false(_fleet.slots.is_held(slot), "its slot free")
	assert_null(Weapons.find(get_tree(), id))
	assert_signal_emit_count(_fleet, "left", 1)
	assert_signal_emit_count(_fleet, "ship_destroyed", 1)
	await wait_seconds(WeaponValues.MISSING_GRACE + 0.2)
	assert_false(_starter.fire_control.list.has(id), "fire control lets it go")

func test_the_starter_is_held_destroyed():
	var other := _spawn()
	# Across to its helm, as F8 does: standing in the starter, you would go with it.
	_root.board_at_helm(other)
	watch_signals(_fleet)
	_wreck(_starter)
	await wait_process_frames(2)
	assert_true(_fleet.ships().has(_starter), "still in the fleet")
	assert_true(_fleet.is_destroyed(_starter))
	assert_true(_fleet.sleeping(_starter))
	assert_false(_starter.visible)
	assert_eq(_starter.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(_starter.exterior.is_in_group(Weapons.TARGETS))
	assert_false(_starter.exterior.is_in_group(Universe.EXTERIOR_SPACE))
	assert_signal_emit_count(_fleet, "left", 0, "the starter never leaves")
	assert_signal_emit_count(_fleet, "ship_destroyed", 1)
	_fleet.check_sleep()
	assert_true(_fleet.sleeping(_starter), "300 m off you, never woken")
	_fleet.wake(_starter)
	assert_true(_fleet.sleeping(_starter), "nor woken by hand")
	assert_false(_fleet.is_destroyed(other))
	assert_same(_fleet.nearest(other.exterior.global_position, other), null, "never the nearest ship")

func test_a_destroyed_starter_survives_a_save():
	_root.queue_free()
	await wait_process_frames(2)
	_root = load("res://scenes/flight_test.tscn").instantiate()
	_root.save_enabled = true
	_root.save_path = PATH
	add_child_autofree(_root)
	await wait_process_frames(2)
	_fleet = _root.fleet
	_starter = _root.get_node("Ship")
	var other := _spawn()
	# Across to its helm, as F8 does: standing in the starter, you would go with it.
	_root.board_at_helm(other)
	_wreck(_starter)
	await wait_process_frames(2)
	var part: Dictionary = _root._part_named(_root.capture(), Fleet.STARTER)
	assert_true(part.get("destroyed", false), "saved destroyed")
	assert_false(_root._part_named(_root.capture(), String(other.name)).has("destroyed"))
	assert_true(_root.save_now())
	var other_name := other.name
	_root.queue_free()
	await wait_process_frames(2)
	var again: Node = load("res://scenes/flight_test.tscn").instantiate()
	again.save_enabled = true
	again.save_path = PATH
	add_child_autofree(again)
	await wait_physics_frames(3)
	var fleet: Fleet = again.fleet
	var starter: Ship = again.get_node("Ship")
	assert_true(fleet.is_destroyed(starter), "held destroyed")
	assert_true(starter.is_destroyed())
	assert_true(fleet.sleeping(starter))
	assert_false(starter.visible)
	assert_eq(starter.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(starter.exterior.is_in_group(Weapons.TARGETS))
	assert_eq(String(again.aboard.name), String(other_name), "aboard the ship you saved in")
	assert_eq(fleet.ships().size(), 2)
	assert_eq(fleet.awake(), [again.aboard] as Array[Ship])
	fleet.check_sleep()
	assert_true(fleet.sleeping(starter), "never woken after a load")
	assert_true(again._part_named(again.capture(), Fleet.STARTER).get("destroyed", false), "and saved so again")

func test_the_crew_aboard_die():
	await wait_physics_frames(3)
	var crew: Array = _starter.npc_director.live_npcs()
	assert_false(crew.is_empty(), "the starter has its droid")
	var other := _spawn()
	# Across to its helm, as F8 does: standing in the starter, you would go with it.
	_root.board_at_helm(other)
	_wreck(_starter)
	await wait_process_frames(2)
	for npc: Npc in crew:
		assert_true(_root.npc_ledger.is_dead(npc.record.id), "%s died with the ship" % npc.record.id)
	for entry: Array in _starter.records(_starter.npc_director):
		assert_true(_root.npc_ledger.is_dead((entry[0] as NpcRecord).id))
