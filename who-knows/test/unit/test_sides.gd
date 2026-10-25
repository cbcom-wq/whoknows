extends GutTest

## Sides (hostile ships spec §4): a ship is crew or hostile, saved with it;
## crew and hostile are hostile to each other, a side never to itself. Your
## turrets engage a hostile unmarked, and on a spacewalk you are a target to
## hostiles only. In the real flight scene, with a second starter spawned.

var _root: Node
var _starter: Ship
var _other: Ship
var _avatar: Avatar

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_starter = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + Vector3(300, 0, 0))
	_other = _root.fleet.spawn(_root._starter_grid(), place)
	await wait_process_frames(2)
	await wait_physics_frames(2)

func after_each():
	if is_instance_valid(_avatar):
		_avatar.mode = Avatar.Mode.PLATING

func test_crew_and_hostile_are_hostile_to_each_other():
	assert_true(Sides.hostile_to(Sides.CREW, Sides.HOSTILE))
	assert_true(Sides.hostile_to(Sides.HOSTILE, Sides.CREW))
	assert_false(Sides.hostile_to(Sides.CREW, Sides.CREW), "a side is never hostile to itself")
	assert_false(Sides.hostile_to(Sides.HOSTILE, Sides.HOSTILE))
	assert_false(Sides.hostile_to(&"", Sides.HOSTILE), "no side, no enemy")

func test_a_ship_is_crew_until_made_hostile():
	assert_eq(_other.side, Sides.CREW, "every ship spawned as now is crew")
	assert_false(Weapons.is_hostile(_starter, _other.exterior))
	_other.side = Sides.HOSTILE
	assert_true(Weapons.is_hostile(_starter, _other.exterior))
	assert_true(Weapons.is_hostile(_other, _starter.exterior), "both ways")
	assert_false(Weapons.is_hostile(_starter, _starter.exterior))

func test_fire_control_engages_a_hostile_unmarked():
	var dorsal: Turret = _starter.turrets[0]
	for t in _starter.turrets:
		if t.coord.y > dorsal.coord.y:
			dorsal = t
	var up := _starter.exterior.global_basis.y
	_other.exterior.global_position = dorsal.muzzle() + up * 400.0
	await wait_physics_frames(2)
	var fc := _starter.fire_control
	fc.set_orders(FireControl.Orders.ENGAGE)
	assert_true(fc.list.is_empty(), "nothing listed")
	_other.side = Sides.HOSTILE
	fc.assign(0.2)
	var aimed := false
	for t in _starter.turrets:
		aimed = aimed or t.target == _other.exterior
	assert_true(aimed, "some turret takes the hostile's hull unmarked")
	_other.side = Sides.CREW
	fc.assign(0.2)
	for t in _starter.turrets:
		assert_null(t.target, "a crew ship is never engaged unmarked")

func test_you_are_a_target_only_to_hostiles_on_a_spacewalk():
	assert_true(_avatar.is_in_group(Weapons.TARGETS))
	assert_eq(Weapons.id_of(_avatar), Weapons.YOU)
	assert_eq(_avatar.mode, Avatar.Mode.PLATING)
	assert_false(Weapons.usable(_avatar), "aboard, you are not a target")
	_avatar.mode = Avatar.Mode.SUIT
	assert_true(Weapons.usable(_avatar), "in the suit, you are")
	_other.side = Sides.HOSTILE
	assert_true(Weapons.is_hostile(_other, _avatar))
	assert_false(Weapons.is_hostile(_starter, _avatar), "your own turrets never see you")

func test_side_survives_a_save():
	var universe: Universe = _root.get_node("Universe")
	_other.side = Sides.HOSTILE
	var d := _other.to_dict(universe)
	assert_eq(d["side"], "hostile")
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + Vector3(-300, 0, 0))
	var fresh: Ship = _root.fleet.spawn(_root._starter_grid(), place)
	await wait_process_frames(2)
	fresh.restore_aboard(d)
	assert_eq(fresh.side, Sides.HOSTILE)
	d.erase("side")
	fresh.restore_aboard(d)
	assert_eq(fresh.side, Sides.CREW, "a save from before sides is crew")
