extends SceneTree

# Many ships, played through in real time (docs/superpowers/specs/
# 2026-10-02-many-ships-design.md §4): a second starter parked stern to stern
# with the first; F8 to its helm; up and out of its airlock in a full cycle;
# across the gap, the suit switching ships on the way; in through the
# starter's airlock in a full cycle; and back to the starter's helm to fly.
# Every step prints what it found, and the key moments are rendered. Run it
# WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 \
#     --script <abs path>/test/probes/fleet_play.gd -- <abs out dir>
#
# Saving is turned off before the scene enters the tree, so the owner's game
# is never touched.

var _out := ""
var _fails := 0

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	root.add_child(scene)
	# A script error mid-run stops _run without quitting: never hang.
	create_timer(150.0).timeout.connect(func() -> void:
		print("play    TIMED OUT")
		quit(1))
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await physics_frame

## Waits until `done` is true, at most `limit` seconds. True if it came true.
func _until(done: Callable, limit: float) -> bool:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		if done.call():
			return true
		await physics_frame
	return done.call()

func _shot(shot_name: String) -> void:
	await _frames(5)
	var file := "%s/play_%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok     " if ok else "FAILED ", what])
	if not ok:
		_fails += 1

func _run(scene: Node) -> void:
	await _frames(3)
	var fleet: Fleet = scene.get("fleet")
	var starter: Ship = scene.get_node("Ship")
	var director: CameraDirector = scene.get_node("CameraDirector")
	var avatar: Avatar = get_first_node_in_group(Avatar.GROUP)
	avatar.suit_cell.from_dict({"charge": 100.0})
	var hull := starter.exterior.global_transform
	var stern_to_stern := Transform3D(Basis(hull.basis.y, PI) * hull.basis, hull * Vector3(0, 0, 45))
	var second := fleet.spawn(scene.call("_starter_grid"), stern_to_stern)
	await _frames(5)
	var lock_out: Airlock = second.airlocks.values()[0]
	var lock_in: Airlock = starter.airlocks.values()[0]

	# F8 to the second ship's helm, then up.
	_check(scene.call("board_nearest"), "F8 seats you at %s's helm" % second.name)
	_check(scene.get("aboard") == second and director.seat_ship() == second, "aboard %s, in its seat" % second.name)
	await _seconds(0.5)
	director.stand_now()
	await _frames(3)

	# Out of its airlock: open the inner hatch, step in, cycle, step out.
	lock_out.room.corridor_panel.interact(avatar)
	await _until(func() -> bool: return lock_out.cycle.inner_open >= 1.0, 5.0)
	# Standing in the room, facing the outer hatch (a frame's -z looks out).
	var facing_out := Transform3D(lock_out.room.outer_frame.basis, lock_out.room.room_frame.origin)
	avatar.place(second.interior.global_transform * facing_out)
	avatar.set_head_pitch(0.0)
	await _frames(3)
	lock_out.room.room_panel.interact(avatar)
	var opened := await _until(func() -> bool: return lock_out.cycle.outer_open >= 1.0, 12.0)
	_check(opened, "%s's outer hatch opens onto vacuum" % second.name)
	await _shot("cycled_out")
	avatar.position = lock_out.room.outer_frame * Vector3(0, 0.05, -0.4)
	var out := await _until(func() -> bool: return avatar.mode == Avatar.Mode.SUIT, 3.0)
	_check(out, "out onto a spacewalk")
	_check(avatar.hull == second.exterior, "the suit is %s's" % second.name)

	# Across the gap: 8 m off the starter's outer hatch, the suit is the
	# starter's, and home is its airlock.
	avatar.suit_assist = false
	var in_hull := starter.exterior.global_transform
	var outside_hatch := in_hull * (lock_in.alcove.outer_frame * Vector3(0, 0.3, -8.0))
	avatar.global_position = outside_hatch
	avatar.velocity = Vector3.ZERO
	var tied := await _until(func() -> bool: return avatar.hull == starter.exterior, 2.0)
	_check(tied, "near the starter, the suit is the starter's")
	_check(scene.get("aboard") == starter, "and aboard is the starter")
	_check(avatar.beacon_source.get_object() == lock_in, "home is the starter's airlock")
	await _shot("suit_tied_to_starter")

	# In through the starter's airlock: the hull panel, a cycle, glide in.
	lock_in.alcove.hull_panel.interact(avatar)
	opened = await _until(func() -> bool: return lock_in.cycle.outer_open >= 1.0, 12.0)
	_check(opened, "the starter's outer hatch opens")
	var inward := (in_hull.basis * lock_in.alcove.outer_frame.basis * Vector3(0, 0, 1)).normalized()
	avatar.global_position = in_hull * (lock_in.alcove.outer_frame * Vector3(0, 0.3, -1.5))
	avatar.velocity = inward * 1.2
	var inside := await _until(func() -> bool: return avatar.mode == Avatar.Mode.PLATING, 6.0)
	_check(inside, "in through the starter's outer hatch")
	_check(avatar.get_parent() == starter.interior, "standing in the starter's airlock")
	_check(scene.get("aboard") == starter and starter.own and not second.own, "aboard the starter; its hull is yours")
	# The view eases in from where your eye was outside; wait it out.
	await _seconds(1.5)
	await _shot("in_the_starters_airlock")

	# Cycle in, then the helm, and fly.
	await _frames(10)
	lock_in.room.room_panel.interact(avatar)
	var cycled_in := await _until(func() -> bool: return lock_in.cycle.inner_open >= 1.0, 12.0)
	_check(cycled_in, "the starter's inner hatch opens on air")
	avatar.position = scene.call("_deck_spot", starter).origin
	await _frames(3)
	starter.seat.interact(avatar)
	await director.transition_finished
	_check(director.seat_ship() == starter and starter.pilot.seated and not second.pilot.seated,
		"at the starter's helm; only its controls are yours")
	await _shot("back_at_the_starters_helm")
	var second_at := second.exterior.global_position
	Input.action_press("move_forward")
	await _seconds(1.0)
	Input.action_release("move_forward")
	var speed := starter.exterior.linear_velocity.dot(-starter.exterior.global_basis.z)
	_check(speed > 5.0, "the starter flies: %.1f m/s forward after 1 s" % speed)
	_check(second.exterior.global_position.distance_to(second_at) < 0.5, "and the second ship stays where it was")
	print("play    %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit()
