extends GutTest

## The maintenance droid alive in the real starter (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §14): it tends jobs, goes home to
## charge, gives way, startles at a thrown mug, braces at a shake, and shows
## on the overlay.

var _root: Node
var _ship: Ship
var _droid: Npc
var _avatar: Avatar

func before_each():
	_root = load("res://scenes/flight_test.tscn").instantiate()
	add_child_autofree(_root)
	_ship = _root.get_node("Ship")
	_avatar = _root.get_node("Ship/Interior/Avatar")
	await wait_physics_frames(3)
	_droid = _ship.npc_director.live.values()[0]
	# Keep the avatar well away unless a test brings it close: at the back of
	# the bunk room, with nothing for the droid to tend.
	_stand_avatar(Vector3i(-1, 0, 1))

func _stand_avatar(cell: Vector3i) -> void:
	_avatar.place(_ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(cell) + Vector3(0, 0.05, 0)))

func _put_droid(cell: Vector3i) -> void:
	_droid.global_transform = _ship.interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(cell))
	_droid.velocity = Vector3.ZERO

func _behaviour() -> StringName:
	return _droid.brain.current.id if _droid.brain.current != null else &""

func test_it_tends_a_job():
	_droid.brain.needs[&"duty"] = 1.0
	_droid.brain.needs[&"charge"] = 0.0
	var tended := false
	for i in 60 * 15:
		await wait_physics_frames(1)
		if not _ship.crew_site.tended.is_empty():
			tended = true
			break
	assert_true(tended, "tended something within 15 s (doing %s)" % _behaviour())

func test_low_on_charge_it_goes_home():
	_put_droid(Vector3i(0, 0, -1))
	_droid.brain.needs[&"duty"] = 0.0
	_droid.brain.needs[&"charge"] = 1.0
	var home := DeckPaths.floor_point(_ship.crew_site.dock)
	var got_home := false
	for i in 60 * 14:
		await wait_physics_frames(1)
		if _droid.local_position().distance_to(home) < 0.3:
			got_home = true
			break
	assert_true(got_home, "home within 14 s (at %s, doing %s)" % [_droid.local_position(), _behaviour()])

func test_it_gives_way_when_you_come_at_it():
	_put_droid(Vector3i(0, 0, 0))
	_droid.brain.needs[&"duty"] = 0.0
	_droid.brain.needs[&"charge"] = 0.0
	# Walk the avatar at it down the corridor, wherever it goes, stopping short.
	var at := DeckPaths.floor_point(Vector3i(0, 0, -2))
	var gave_way := false
	var closest := INF
	for i in 60 * 4:
		var to := _droid.local_position() - at
		to.y = 0.0
		if to.length() > 1.2:
			at += to.normalized() * minf(1.5 / 60.0, to.length() - 1.2)
		_avatar.place(_ship.interior.global_transform * Transform3D(Basis.IDENTITY, at + Vector3(0, 0.05, 0)))
		await wait_physics_frames(1)
		closest = minf(closest, Behaviour.flat_distance(at, _droid.local_position()))
		if _behaviour() == &"give_way":
			gave_way = true
	assert_true(gave_way, "it chose to give way")
	assert_gt(closest, 0.6, "and never let you walk into it")

func test_a_thrown_mug_startles_it():
	_put_droid(Vector3i(0, 0, 0))
	await wait_physics_frames(2)
	var mug := Item.new()
	mug.setup(_ship.item_catalog.get_def(&"mug"), 0.3)
	_ship.items.add_child(mug)
	mug.set_loose()
	var at := _droid.global_position + Vector3(0, 0.3, -1.5)
	mug.global_position = at
	mug.linear_velocity = Vector3(0, 0, 6)
	var startled := false
	for i in 60:
		await wait_physics_frames(1)
		if _behaviour() == &"startle":
			startled = true
			break
	assert_true(startled, "startled (doing %s)" % _behaviour())
	assert_gt(float(_droid.brain.needs[&"fear"]), 0.25)

func test_a_shake_makes_it_brace():
	var coupling: MotionCoupling = _root.get_node("Ship/MotionCoupling")
	coupling.drive_felt_gravity(Vector3(0, 0, -8))
	var braced := false
	for i in 30:
		await wait_physics_frames(1)
		if _behaviour() == &"brace":
			braced = true
			break
	assert_true(braced, "braced (doing %s)" % _behaviour())

func test_the_overlay_shows_it():
	var overlay: NpcDebug = _root.npc_debug
	assert_false(overlay.shown)
	overlay.shown = true
	await wait_process_frames(5)
	var labels := overlay.find_children("*", "Label3D", true, false)
	assert_eq(labels.size(), 1)
	assert_string_contains((labels[0] as Label3D).text, "droid:Ship:0")
	overlay.shown = false
	await wait_process_frames(2)
	assert_eq(overlay.find_children("*", "Label3D", true, false).size(), 0)
