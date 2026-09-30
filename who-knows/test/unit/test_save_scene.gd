extends GutTest

## The whole game through a save and a load, in the real flight scene
## (docs/superpowers/specs/2026-09-26-saving-design.md §6, §11.1): change
## something in every part, save, build a fresh scene from the file, and
## compare. Once walking, once seated and once on a spacewalk.

const SCENE := "res://scenes/flight_test.tscn"
const DIR := "user://test_save_scene"
const PATH := DIR + "/game.json"

var _real_save_time := 0

func before_all():
	_real_save_time = _modified(SaveGame.DEFAULT_PATH)

func after_all():
	assert_eq(_modified(SaveGame.DEFAULT_PATH), _real_save_time, "the owner's real save is untouched")

func before_each():
	_clear()

func after_each():
	_clear()

static func _modified(file_path: String) -> int:
	return FileAccess.get_modified_time(file_path) if FileAccess.file_exists(file_path) else 0

func _clear() -> void:
	for suffix in ["", ".bak", ".tmp", ".old"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)

## A flight scene with saving on, at the test's own path.
func _scene() -> Node:
	var root: Node = load(SCENE).instantiate()
	root.save_enabled = true
	root.save_path = PATH
	add_child(root)
	return root

func _drop(root: Node) -> void:
	remove_child(root)
	root.free()

static func _items(ship: Ship) -> Array:
	return ship.items.get_children().filter(func(n): return n is Item)

## Every item aboard as [kind, state], sorted: what is where, not which node.
static func _manifest(ship: Ship) -> Array:
	var out := []
	for item: Item in _items(ship):
		out.append("%s:%s" % [item.definition.id, Item.State.keys()[item.state]])
	out.sort()
	return out

static func _hull_at(root: Node) -> UniversePoint:
	return root.get_node("Universe").to_universe(root.get_node("Ship").exterior.global_position)

## Changes something in every part aboard: the hull flies somewhere, the
## store and the suit change, salvage is taken, the flight settings change,
## a pistol comes off the rack onto the floor and a mug goes into your hand.
func _live_a_little(root: Node) -> void:
	var ship: Ship = root.get_node("Ship")
	var avatar: Avatar = root.get_node("Ship/Interior/Avatar")
	ship.exterior.global_position += Vector3(120, -40, -900)
	ship.exterior.global_basis = Basis(Vector3.UP, 0.7)
	ship.exterior.linear_velocity = Vector3(3, 0, -25)
	ship.exterior.angular_velocity = Vector3(0, 0.05, 0)
	ship.quantum.store.from_dict({"amount": 321})
	avatar.suit_cell.from_dict({"charge": 64.0})
	root.salvage.ledger.take(SalvageField.NEAR, 4)
	ship.flight_computer.from_dict({"assist": true, "speed_locked": true, "locked_speed": 25.0})
	var pistol: Item = _items(ship).filter(func(i): return i.definition.id == &"plasma_pistol")[0]
	pistol.stow_point.release()
	pistol.global_position = ship.interior.global_transform * Vector3(0, -0.5, 2)
	var mug: Item = _items(ship).filter(func(i): return i.definition.id == &"mug")[0]
	assert_true(avatar.grasp.take(mug), "took the mug")

func test_a_new_game_starts_when_there_is_no_save():
	var root := _scene()
	assert_false(root.resumed)
	_drop(root)

func test_walking_round_trips():
	var a := _scene()
	_live_a_little(a)
	var avatar: Avatar = a.get_node("Ship/Interior/Avatar")
	var ship: Ship = a.get_node("Ship")
	var galley := ship.interior.global_transform * Vector3(0, InteriorBuilder.floor_y(Vector3i.ZERO) + 0.05, 2)
	avatar.place(Transform3D(Basis(Vector3.UP, 1.2), galley))
	avatar.set_head_pitch(-0.3)
	var hull := _hull_at(a)
	var manifest := _manifest(ship)
	var item_count := _items(ship).size()
	assert_true(a.save_now(), "saved")
	var was: Dictionary = a.capture()
	_drop(a)

	var b := _scene()
	assert_true(b.resumed)
	var ship_b: Ship = b.get_node("Ship")
	var avatar_b: Avatar = b.get_node("Ship/Interior/Avatar")
	assert_true(_hull_at(b).is_equal_approx(hull), "the hull is where it was")
	assert_almost_eq(ship_b.exterior.linear_velocity, Vector3(3, 0, -25), Vector3.ONE * 1e-4)
	assert_almost_eq(ship_b.exterior.angular_velocity, Vector3(0, 0.05, 0), Vector3.ONE * 1e-4)
	assert_true(ship_b.exterior.global_basis.is_equal_approx(Basis(Vector3.UP, 0.7)))
	assert_eq(ship_b.quantum.store.amount, 321)
	assert_eq(avatar_b.suit_cell.charge, 64.0)
	assert_true(b.salvage.ledger.is_taken(SalvageField.NEAR, 4))
	assert_true(ship_b.flight_computer.speed_locked)
	assert_eq(ship_b.flight_computer.locked_speed, 25.0)
	assert_eq(_items(ship_b).size(), item_count, "the shelves were not restocked on top")
	assert_eq(_manifest(ship_b), manifest)
	assert_eq(avatar_b.grasp.item.definition.id, &"mug", "the mug is still in your hand")
	assert_almost_eq(avatar_b.global_position, galley, Vector3.ONE * 1e-4)
	assert_almost_eq(avatar_b.head_pitch(), -0.3, 1e-5)
	assert_eq(avatar_b.mode, Avatar.Mode.PLATING)
	assert_eq(int(b.capture()["world"]["seed"]), int(was["world"]["seed"]))
	_drop(b)

func test_seated_round_trips():
	var a := _scene()
	var director: CameraDirector = a.get_node("Ship/CameraDirector")
	director.sit_now(a.get_node("Ship/Interior/PilotSeat"))
	assert_true(director.is_seated)
	assert_true(a.save_now())
	_drop(a)

	var b := _scene()
	var director_b: CameraDirector = b.get_node("Ship/CameraDirector")
	assert_true(director_b.is_seated, "back at the helm")
	assert_eq(director_b.view, CameraDirector.View.COCKPIT)
	assert_true(b.get_node("Ship/PilotControls").seated)
	assert_false(director_b.is_moving(), "no camera move on the way in")
	_drop(b)

func test_a_spacewalk_round_trips():
	var a := _scene()
	var ship: Ship = a.get_node("Ship")
	var avatar: Avatar = a.get_node("Ship/Interior/Avatar")
	var airlock: Airlock = ship.airlocks.values()[0]
	airlock.from_dict({"pressure": 0.0, "open": "outer"})
	var at := airlock.beacon() + ship.exterior.global_basis.z * 6.0
	avatar.enter_suit(a.get_node("Outside"), Transform3D(Basis(Vector3.RIGHT, 0.4), at), Vector3(0.5, 0, 0), ship.exterior)
	avatar.beacon_source = airlock.beacon
	avatar.home_source = airlock.home
	avatar.suit_cell.from_dict({"charge": 55.0})
	var you: UniversePoint = a.get_node("Universe").to_universe(avatar.global_position)
	var hull := _hull_at(a)
	assert_true(a.save_now())
	_drop(a)

	var b := _scene()
	var ship_b: Ship = b.get_node("Ship")
	var avatar_b: Avatar = b.get_node("Ship/Interior/Avatar") if b.has_node("Ship/Interior/Avatar") else null
	if avatar_b == null:
		avatar_b = b.get_node("Outside").find_child("Avatar", false, false)
	assert_not_null(avatar_b)
	var universe_b: Universe = b.get_node("Universe")
	assert_eq(avatar_b.mode, Avatar.Mode.SUIT)
	assert_eq(universe_b.focus, avatar_b, "the universe follows you outside")
	assert_true(universe_b.to_universe(avatar_b.global_position).is_equal_approx(you), "you are where you were")
	assert_true(_hull_at(b).is_equal_approx(hull))
	assert_true(avatar_b.global_basis.is_equal_approx(Basis(Vector3.RIGHT, 0.4)))
	assert_almost_eq(avatar_b.velocity, Vector3(0.5, 0, 0), Vector3.ONE * 1e-4)
	assert_eq(avatar_b.suit_cell.charge, 55.0)
	var airlock_b: Airlock = ship_b.airlocks.values()[0]
	assert_false(airlock_b.cycle.pressurized())
	assert_eq(airlock_b.cycle.open_side(), AirlockCycle.Door.OUTER, "the airlock stands open behind you")
	assert_true(avatar_b.beacon_source.is_valid(), "the way home is marked")
	_drop(b)

func test_a_far_stray_round_trips_and_a_near_one_comes_back_in_the_world():
	var a := _scene()
	var universe: Universe = a.get_node("Universe")
	var ship: Ship = a.get_node("Ship")
	var crate := Item.new()
	crate.setup(ship.item_catalog.get_def(&"crate"), 0.5)
	crate.set_space(true)
	a.get_node("Outside").add_child(crate)
	crate.global_position = ship.exterior.global_position + Vector3(0, 30, 0)
	a.strays.adopt(crate)
	assert_eq(a.strays.count(), 1)
	assert_true(crate.is_in_group(Universe.EXTERIOR_SPACE))
	var where := universe.to_universe(crate.global_position)
	assert_true(a.save_now())
	_drop(a)

	var b := _scene()
	assert_eq(b.strays.count(), 1)
	var live: Item = b.strays.live(b.strays.ledger.entries.keys()[0])
	assert_not_null(live, "a stray near you loads")
	assert_eq(live.definition.id, &"crate")
	assert_true(live.is_in_group(Universe.EXTERIOR_SPACE))
	assert_true(b.get_node("Universe").to_universe(live.global_position).is_equal_approx(where))
	_drop(b)

func test_a_stowed_item_whose_point_is_gone_loads_loose():
	var a := _scene()
	var ship: Ship = a.get_node("Ship")
	var d := {"kind": "mug", "variety": 0.2, "state": "stowed", "point": [99.0, 0.0, 99.0],
		"place": SaveCodec.transform(Transform3D(Basis.IDENTITY, Vector3(99, 0.2, 99)))}
	var item := ship.restore_item(d)
	assert_eq(item.state, Item.State.LOOSE)
	_drop(a)

func test_a_save_waits_while_the_ship_is_busy():
	var a := _scene()
	var ship: Ship = a.get_node("Ship")
	assert_eq(ship.busy(), "")
	ship.since_struck = 0.0
	assert_eq(ship.busy(), "hull struck")
	ship.since_struck = Ship.STRUCK_CALM
	var airlock: Airlock = ship.airlocks.values()[0]
	airlock.cycle.press(&"room")
	airlock.tick(0.1)
	assert_eq(ship.busy(), "airlock cycling")
	_drop(a)

func test_a_save_waits_while_you_are_busy():
	var a := _scene()
	var avatar: Avatar = a.get_node("Ship/Interior/Avatar")
	assert_eq(avatar.busy(), "")
	avatar.since_bumped = 0.0
	assert_eq(avatar.busy(), "bumped a rock")
	avatar.since_bumped = Avatar.BUMP_CALM
	avatar.grasp.charge = 0.2
	assert_eq(avatar.busy(), "throwing")
	_drop(a)

func test_a_newer_save_is_left_alone_and_the_game_starts_new():
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": SaveGame.FORMAT + 1}))
	f.close()
	var a := _scene()
	assert_false(a.resumed)
	assert_false(a.save_now())
	assert_eq(int(SaveGame._parse(PATH)["format"]), SaveGame.FORMAT + 1)
	assert_push_error("newer than this game")
	_drop(a)

## Health and damage spec §4.2, §8.2: damage and holes are kept, and so is the
## layout the ship launched with, which a rebuild puts back from.
func test_damage_and_the_launch_layout_round_trip():
	var a := _scene()
	var ship: Ship = a.get_node("Ship")
	var hurt := Vector3i.ZERO
	var gone := Vector3i.ZERO
	var found := 0
	for coord: Vector3i in ship.grid.coords():
		if ship.grid.get_block(coord).block_id == &"hull" and not ship.grid.has_block(coord + Vector3i(1, 0, 0)):
			if found == 0:
				hurt = coord
			else:
				gone = coord
			found += 1
			if found == 2:
				break
	assert_eq(found, 2)
	ship.take_damage(hurt, 90.0)
	ship.take_damage(gone, 10_000.0)
	assert_false(ship.grid.has_block(gone))
	ship.damage_log.since = DamageLog.CALM
	assert_true(a.save_now(), "saved")
	_drop(a)

	var b := _scene()
	assert_true(b.resumed)
	var ship_b: Ship = b.get_node("Ship")
	assert_eq(ship_b.grid.get_block(hurt).damage, 90.0, "the damage is kept")
	assert_false(ship_b.grid.has_block(gone), "and the hole")
	assert_eq(ship_b.launch_block(gone), [&"hull", 0], "the launch layout still has it")
	assert_eq(ship_b.launch_blueprint.damage_values.max(), 0.0, "nothing hurt in it")
	_drop(b)

func test_an_older_save_launches_from_its_own_layout():
	var d := {"layout": {"name": "Old", "format": 1, "cells": [[0, 0, 0, "core", 0, 0], [1, 0, 0, "hull", 4, 30]]}}
	var bp := Ship.launch_of(d)
	assert_eq(bp.coords, [Vector3i(0, 0, 0), Vector3i(1, 0, 0)] as Array[Vector3i])
	assert_eq(bp.damage_values.max(), 0.0)

## Health and damage spec §10: your health, the dead and the wounded are kept.
func test_health_and_the_ledger_round_trip():
	var a := _scene()
	var avatar: Avatar = a.get_node("Ship/Interior/Avatar")
	var ship: Ship = a.get_node("Ship")
	avatar.take_damage(35.0)
	ship.npc_director.review()
	var droid: Npc = ship.npc_director.live.values()[0]
	droid.take_damage(20.0)
	a.npc_ledger.mark_dead(&"skitter:somewhere:0:1")
	ship.damage_log.since = DamageLog.CALM
	avatar.health.since_hurt = 0.0
	assert_true(a.save_now(), "saved")
	var droid_id := droid.record.id
	_drop(a)

	var b := _scene()
	assert_true(b.resumed)
	var avatar_b: Avatar = b.get_node("Ship/Interior/Avatar")
	var ship_b: Ship = b.get_node("Ship")
	assert_almost_eq(avatar_b.health.current, 65.0, 0.01)
	assert_true(b.npc_ledger.is_dead(&"skitter:somewhere:0:1"))
	ship_b.npc_director.review()
	var droid_b: Npc = ship_b.npc_director.live.get(droid_id)
	assert_not_null(droid_b)
	assert_almost_eq(droid_b.health.current, droid_b.health.max - 20.0, 0.01)
	_drop(b)
