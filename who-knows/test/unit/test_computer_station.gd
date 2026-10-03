extends GutTest

## The computer mode in the real flight scene (computer mode spec §3): F at
## the table glides you over the holo; F or Esc brings you back; nothing else
## takes your keys while you are there.

var _root: Node
var _ship: Ship
var _director: CameraDirector
var _avatar: Avatar

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_director = _root.get_node("CameraDirector")
	_avatar = _root.get_node("Ship/Interior/Avatar")

func _station() -> ComputerStation:
	return _ship.interior_builder.computers()[0].station

func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	_director._unhandled_input(ev)

func _enter() -> void:
	_station().interact(_avatar)
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)

func test_using_it_hands_the_view_to_the_station():
	watch_signals(_director)
	await _enter()
	assert_true(_director.is_at_station)
	assert_signal_emitted_with_parameters(_director, "station_changed", [_station()])
	assert_eq(_director.view, CameraDirector.View.STATION)
	assert_eq(_director.station(), _station())
	assert_almost_eq(_director.camera().global_position, _station().eye_transform().origin, Vector3.ONE * 0.01)
	assert_true(_avatar.at_station)
	assert_true(_avatar.interactor.suspended)
	assert_null(_avatar.interactor.current())

func test_f_leaves_and_nothing_else_takes_it():
	await _enter()
	_press(&"interact")
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	assert_false(_director.is_at_station)
	assert_eq(_director.view, CameraDirector.View.FOOT_FIRST)
	assert_eq(_director.camera().get_parent(), _avatar.head)
	assert_false(_avatar.at_station)
	assert_false(_avatar.interactor.suspended)
	assert_almost_eq(_station().computer.spin, 0.0, 0.0001, "the holo turned with the ship again")

func test_esc_leaves_too():
	await _enter()
	_press(&"ui_cancel")
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	assert_false(_director.is_at_station)

## Seated at once, with no camera move, so only being seated can refuse it.
## (Awaiting a whole sit here trips the cockpit velocity marker's
## unproject_position at a standstill, headless, which is not this test's.)
func test_not_while_seated():
	_director.sit_now(_ship.seat)
	assert_true(_director.is_seated)
	_station().interact(_avatar)
	assert_false(_director.is_at_station)

func test_the_camera_key_does_nothing_at_the_station():
	await _enter()
	_press(&"cycle_camera")
	assert_eq(_director.view, CameraDirector.View.STATION)
	await wait_process_frames(2)
	assert_almost_eq(_director.camera().global_position, _station().eye_transform().origin, Vector3.ONE * 0.01)

func test_the_eye_follows_the_orbit():
	await _enter()
	_station().orbit(30.0)
	await wait_process_frames(2)
	assert_almost_eq(_director.camera().global_position, _station().eye_transform().origin, Vector3.ONE * 0.01)

func test_a_rebuild_drops_you_out_with_your_controls_back():
	await _enter()
	_ship._rebuild_everything()
	await wait_process_frames(3)
	assert_false(_director.is_at_station)
	assert_eq(_director.camera().get_parent(), _avatar.head)
	assert_false(_avatar.at_station)
	assert_eq(_director.view, CameraDirector.View.FOOT_FIRST)
	assert_false(_avatar.interactor.suspended)
	assert_true(_avatar.grasp.enabled, "your controls are back")

## Spec §3.5: blacked out at the table, you drop out of it at once, and waking,
## not the station, gives your controls back.
func test_blacking_out_at_the_station_drops_you_out():
	await _enter()
	var hit := Hit.make(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, null)
	hit.damage = Avatar.MAX_HEALTH * 2.0
	_avatar.receive_hit(hit)
	assert_not_null(_avatar.downed, "blacked out")
	await wait_process_frames(2)
	assert_false(_director.is_at_station)
	assert_false(_avatar.at_station)
	assert_false(_avatar.interactor.suspended)
	assert_eq(_director.camera().get_parent(), _avatar.head)
	assert_eq(_director.view, CameraDirector.View.FOOT_FIRST)
	assert_not_null(_avatar.downed, "still out cold")
	assert_false(_avatar.grasp.enabled, "no controls until you wake")

## Spec §3.5: a hole where you stand puts you outside (flight_test's
## _on_blocks_lost), and out of the computer, with your suit yours to fly.
func test_blown_outside_at_the_station_drops_you_out():
	await _enter()
	var at := _ship.exterior.global_position + Vector3(0, 0, 20)
	_avatar.enter_suit(_ship.outside, Transform3D(Basis.IDENTITY, at), Vector3.ZERO, _ship.exterior)
	await wait_process_frames(2)
	assert_false(_director.is_at_station)
	assert_false(_avatar.at_station)
	assert_false(_avatar.interactor.suspended)
	assert_eq(_director.camera().get_parent(), _avatar.head)
	assert_eq(_director.view, CameraDirector.View.FOOT_FIRST)
	assert_true(_avatar.grasp.enabled, "your suit's controls are yours")

func test_saved_at_the_table_you_are_walking():
	await _enter()
	var you: Dictionary = _root.capture()["avatar"]
	assert_eq(you["mode"], "walking")

func test_the_avatar_ignores_esc_and_clicks_at_the_station():
	await _enter()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_avatar._unhandled_input(click)
	assert_true(_director.is_at_station, "the avatar's click-to-recapture stays out of it")

## The station's box covers the table top, so a mug set down there is inside
## it: the ray lands on the station first, and the station yields to the mug.
func test_a_mug_on_the_table_is_offered_before_the_computer():
	var station := _station()
	var mug := Item.new()
	mug.setup(_ship.item_catalog.get_def(&"mug"))
	_ship.items.add_child(mug)
	var half := mug.definition.size.y * 0.5
	mug.global_position = station.global_transform * Vector3(0, 0.95 + half + 0.005, 0)
	await wait_physics_frames(30)
	var on_table := station.global_transform.affine_inverse() * mug.global_position
	assert_almost_eq(on_table, Vector3(0, 0.95 + half, 0), Vector3.ONE * 0.03, "it settled on the table top")
	# Stand at the operator's spot, looking at the foot of the mug.
	var interior: Node3D = _ship.interior
	var spot := interior.global_transform * DeckPaths.floor_point(Vector3i(-1, 0, -2))
	var target := station.global_transform * (on_table - Vector3(0, half * 0.8, 0))
	var up := interior.global_basis.y
	var flat := target - up * (target - spot).dot(up)
	_avatar.place(Transform3D(interior.global_basis, spot).looking_at(flat, up))
	await wait_physics_frames(2)
	var eye := _avatar.interactor.global_position
	var to := target - eye
	_avatar.set_head_pitch(atan2(to.dot(up), (to - up * to.dot(up)).length()))
	await wait_physics_frames(3)
	assert_eq(_avatar.interactor.get_collider(), station, "the ray lands on the station's box first")
	assert_eq(_avatar.interactor.current(), mug, "the mug, not the computer")

func test_the_overlay_follows_the_station_and_the_prompt_clears():
	await _enter()
	assert_true(_root.computer_overlay.visible)
	assert_eq((_root.get_node("Prompt/Label") as Label).text, "")
	_press(&"interact")
	await wait_seconds(CameraDirector.SIT_DURATION + 0.2)
	assert_false(_root.computer_overlay.visible)
