extends GutTest

## Boarding another ship and flying it (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §4), in the real flight scene, with a
## second starter spawned 300 m off.

var _root: Node
var _starter: Ship
var _second: Ship
var _avatar: Avatar
var _director: CameraDirector
var _hud: HudRoot

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_starter = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	_director = _root.get_node("CameraDirector")
	_hud = _root.get_node("HudRoot")
	var place := Transform3D(_starter.exterior.global_basis, _starter.exterior.global_position + Vector3(300, 0, 0))
	_second = _root.fleet.spawn(_root._starter_grid(), place)
	await wait_process_frames(2)
	await wait_physics_frames(2)

func after_each():
	for action in [&"move_forward", &"move_back"]:
		Input.action_release(action)

## A ship you are not in still keeps its canopy camera on its hull, where its
## helm's eye would see from: the cockpit's markers project through it the
## moment you board, before its portal has synced to you, and the velocity
## marker aims at the hull's origin at rest.
func test_a_ship_you_are_not_in_keeps_its_canopy_camera_at_its_helm():
	await wait_process_frames(1)
	var eye: Node3D = _second.seat.get_node("Eye")
	var local := _second.interior.global_transform.affine_inverse() * eye.global_transform
	local.origin.y -= InteriorBuilder.storey_offset(InteriorBuilder.storey_at(local.origin.y))
	var expected := _second.exterior.global_transform * local
	assert_almost_eq(_second.canopy_camera.global_position, expected.origin, Vector3.ONE * 0.01)
	assert_gt(_second.canopy_camera.global_position.distance_to(_second.exterior.global_position), 1.0,
		"not at the hull's origin")

func test_you_start_aboard_the_starter():
	assert_same(_root.aboard, _starter)
	assert_true(_starter.own)
	assert_false(_second.own)

func test_f8_seats_you_at_the_other_ships_helm():
	assert_true(_root.board_nearest())
	assert_same(_root.aboard, _second)
	assert_true(_director.is_seated)
	assert_same(_director.seat_ship(), _second)
	assert_same(_avatar.get_parent(), _second.interior)
	assert_true(_second.pilot.seated)
	assert_false(_starter.pilot.seated)
	assert_same(_hud._source, _second.pilot, "the HUD reads the ship you fly")
	assert_same((_root.get_node("Universe") as Universe).focus, _second.exterior)
	assert_same(_root.warp_panel.drive, _second.warp)
	assert_same(_avatar.grasp.world_root, _second.items)
	assert_eq(_second.sensors.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(_starter.sensors.process_mode, Node.PROCESS_MODE_DISABLED, "the other's scans rest")

func test_the_ship_you_left_shows_through_your_windows():
	_root.board_nearest()
	assert_true(_second.own)
	assert_false(_starter.own)
	assert_false(_starter.interior.visible)
	assert_true(_second.interior.visible)
	for node in _starter.exterior.find_children("*", "GeometryInstance3D", true, false):
		assert_ne((node as GeometryInstance3D).layers, ExteriorBuilder.OWN_HULL_LAYER, "%s on the world's layer" % node.name)
	assert_ne(_second.canopy_camera.cull_mask & 1, 0, "the canopy shows layer 1")

func test_the_cockpit_markers_follow_you():
	_root.board_nearest()
	assert_true(_hud._registered.has(_second.canopy_overlay.get_node("CockpitMarker")))
	assert_false(_hud._registered.has(_starter.canopy_overlay.get_node("CockpitMarker")))
	for m: WorldMarker in _root.contact_markers:
		if String(m.name).ends_with("Cockpit"):
			assert_same(m.get_parent(), _second.canopy_overlay, "%s moved into its canopy" % m.name)
		assert_same((m as ContactMarker).sensors, _second.sensors)

func test_flying_it_moves_it_and_not_the_starter():
	_root.board_nearest()
	var starter_at := _starter.exterior.global_position
	Input.action_press(&"move_forward")
	await wait_physics_frames(60)
	Input.action_release(&"move_forward")
	var forward := -_second.exterior.global_basis.z
	assert_gt(_second.exterior.linear_velocity.dot(forward), 5.0, "it accelerates")
	assert_almost_eq(_starter.exterior.global_position, starter_at, Vector3.ONE * 0.5, "the starter stays")

func test_stand_up_and_walk_it():
	_root.board_nearest()
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)
	var from := _avatar.global_position
	Input.action_press(&"move_back")
	await wait_physics_frames(60)
	Input.action_release(&"move_back")
	assert_gt(from.distance_to(_avatar.global_position), 1.0, "walked off")
	assert_same(_avatar.get_parent(), _second.interior)

func test_f8_again_takes_you_back():
	_root.board_nearest()
	assert_true(_root.board_nearest())
	assert_same(_root.aboard, _starter)
	assert_same(_director.seat_ship(), _starter)
	assert_true(_starter.own)
	assert_false(_second.own)

func test_refused_on_a_spacewalk():
	var at := _starter.exterior.global_position + Vector3(0, 0, 20)
	_avatar.enter_suit(_root.get_node("Outside"), Transform3D(Basis.IDENTITY, at), Vector3.ZERO, _starter.exterior)
	assert_false(_root.board_nearest())
	assert_same(_root.aboard, _starter)

func test_refused_with_no_other_ship():
	assert_true(_root.fleet.remove(_second))
	assert_false(_root.board_nearest())

## Review focus: what you hold comes with you, and lands in the ship you are in.
func test_what_you_hold_comes_with_you():
	var mugs := _starter.items.get_children().filter(func(n): return n is Item and n.definition.id == &"mug")
	var mug: Item = mugs[0]
	assert_true(_avatar.grasp.take(mug))
	_root.board_nearest()
	assert_same(_avatar.grasp.item, mug, "still in your hand")
	_director.stand()
	await wait_for_signal(_director.transition_finished, 3)
	_avatar.grasp.drop()
	assert_same(mug.get_parent(), _second.items, "dropped, it lands in the ship you are in")
