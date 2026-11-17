extends SceneTree

## A Sunguard's fighting poses up close (Wadoo spec §9, §11), in a plain lit
## room of sand: the staff across the back, then in the right hand aiming,
## shooting, rolling aside, staggering (a small wound and a big one: both
## Hit_Chest) and falling dead, and a villager
## cowering. A small ball marks staff_head(), where a bolt leaves, which should
## sit in the staff's glowing head. Run WITHOUT --headless, from who-knows:
##
##   godot --path . --resolution 1280x720 --script res://test/probes/wadee_poses.gd -- <abs out dir>

var _out := ""
var _world: Node3D
var _cam: Camera3D
var _body: CharacterBody3D
var _look: WadeeLook
var _ball: MeshInstance3D
## The staff in the hand stands this way in the look's frame (it faces -z, +x is
## its right): leaning out to the right and forward, the head beside the
## shoulder where one she aims at sees it, its butt in and back behind the skirt.
const WANT_UP := Vector3(0.3, 1.0, -0.45)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else OS.get_user_data_dir()
	_run.call_deferred()

func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.68, 0.58)
	env.environment.ambient_light_energy = 0.6
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	_world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.78, 0.66, 0.48)
	ground.material_override = sand
	_world.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_world.add_child(_cam)
	_cam.current = true
	_ball = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.025
	s.height = 0.05
	_ball.mesh = s
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0, 0)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.no_depth_test = true
	_ball.material_override = red
	_world.add_child(_ball)
	_make({"model": "s", "seed": 5, "role": &"sunguard", "staff": true})
	await _frames(10)
	_look.act(&"idle")
	await _seconds(0.5)
	await _shot("idle_back", Vector3(1.2, 1.6, 2.4), 1.2)
	_look.act(&"aim")
	await _seconds(0.8)
	_report("aim")
	await _shot("aim_front", Vector3(-1.2, 1.6, -2.6), 1.2)
	await _shot("aim_side", Vector3(2.8, 1.5, -0.3), 1.2)
	await _shot("aim_hand", Vector3(0.9, 1.5, -1.1), 1.2, 0.8)
	_look.act(&"shoot")
	await _seconds(0.25)
	_report("shoot 0.25 s")
	await _shot("shoot", Vector3(-1.2, 1.6, -2.6), 1.2, 0.0, 0.0)
	_look.act(&"aim")
	await _seconds(1.0)
	_look.act(&"roll")
	await _seconds(0.5)
	await _shot("roll", Vector3(2.8, 1.4, -0.3), 0.7, 0.0, 0.0)
	_look.act(&"aim")
	await _seconds(1.5)
	_look.hurt(0.1)
	await _seconds(0.15)
	await _shot("hit_chest", Vector3(-1.2, 1.6, -2.6), 1.1, 0.0, 0.0)
	await _seconds(0.8)
	_look.hurt(0.4)
	await _seconds(0.3)
	await _shot("hit_big", Vector3(2.8, 1.5, -0.3), 1.0, 0.0, 0.0)
	await _seconds(1.0)
	_look.act(&"dead")
	await _seconds(0.7)
	await _shot("dying", Vector3(2.8, 1.5, -0.3), 0.8, 0.0, 0.0)
	await _seconds(2.0)
	await _shot("dead", Vector3(2.4, 1.6, 1.6), 0.2)
	_make({"model": "a", "seed": 9, "role": &"villager"})
	await _frames(5)
	_look.act(&"cower")
	await _seconds(1.5)
	await _shot("cower", Vector3(-1.2, 1.6, -2.6), 0.6)
	quit(0)

func _make(person: Dictionary) -> void:
	if _body != null:
		_body.queue_free()
	_body = CharacterBody3D.new()
	_world.add_child(_body)
	_look = WadeeLook.new()
	_look.build(0.1, Vector2(330, 380))
	_body.add_child(_look)
	_look.set_person(person)

## The camera at `eye`, looking at the Wadee `at_height` m up; a shot after
## `settle` s (0 for at once), saved as wadee_<name>.png.
func _shot(shot_name: String, eye: Vector3, at_height: float, side := 0.0, settle := 0.2) -> void:
	_cam.global_position = eye
	_cam.look_at(Vector3(side * 0.0, at_height, 0.0), Vector3.UP)
	_mark()
	if settle > 0.0:
		await _seconds(settle)
	await _frames(2)
	_mark()
	await _frames(1)
	var file := "%s/wadee_%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s (clip %s)" % [file, _look.clip])

func _mark() -> void:
	var head: Variant = _look.staff_head()
	_ball.visible = head != null
	if head != null:
		_ball.global_position = head

## Where the staff's head and the hand are, for `what`.
func _report(what: String) -> void:
	var head: Variant = _look.staff_head()
	var skel := _look.skeleton()
	var hand := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("RightHand")).origin
	print("pose    %s: clip %s, armed %s, staff head %s, right hand %s" % [what, _look.clip, _look.armed,
		"none" if head == null else "(%.2f, %.2f, %.2f)" % [head.x, head.y, head.z], "(%.2f, %.2f, %.2f)" % [hand.x, hand.y, hand.z]])
	# The turn that stands the staff as WANT_UP in the look's frame, from the
	# hand's turn now: for WadeeLook.HAND_TURN.
	var hand_b := (_look.global_basis.inverse() * skel.global_basis * skel.get_bone_global_pose(skel.find_bone("RightHand")).basis).orthonormalized()
	var up_h := (hand_b.inverse() * WANT_UP.normalized()).normalized()
	var x_h := (Vector3.RIGHT - up_h * up_h.dot(Vector3.RIGHT)).normalized()
	var turn := Basis(x_h, up_h, x_h.cross(up_h)).orthonormalized()
	var e := turn.get_euler()
	print("pose    %s: the hand's x %s y %s z %s; HAND_TURN for up %s: Vector3(%.4f, %.4f, %.4f)" % [what, hand_b.x, hand_b.y, hand_b.z,
		WANT_UP, e.x, e.y, e.z])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
