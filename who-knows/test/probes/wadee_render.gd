extends "res://test/probes/oasis_render.gd"

## The five Wadees moving by the pool at WADIS's oasis. The models are
## assets/wadee/wadee_<a|b|c|m|n>.glb, made in Blender by tools/blender/wadee_base.py and
## given skeletons and motions by tools/blender/wadee_rig.py. Three walk a loop on the north
## bank while two stand talking inside it, then the three run a wider loop. A crowd of
## CROWD more joins for one frame-rate reading. The views are on foot with the eye 1.6 m
## over the ground, plus runs of frames (oasis_seq_<walk|run>_NN.png) that show the motion.
## A spike: there is no NPC brain or locomotor yet; this script steers the walkers round
## their circles and keeps their feet on the ground. Run WITHOUT --headless, from who-knows:
##
##   godot --path . --resolution 1280x720 --script res://test/probes/wadee_render.gd -- <abs out dir>

## The loops' middles, [east, north] m in the oasis's layout, and their radii, m.
const WALK_AT := [-8.6, 22.0]
const WALK_RADIUS := 5.5
const RUN_AT := [-8.6, 24.0]
const RUN_RADIUS := 8.0
## How fast the library's body moves over the ground in each clip, m/s, with its hips
## (Godot names a clip without the library's "_Loop" and loops it)
## LIB_HIPS m up (a planted foot's slide, measured by wadee_rig.py). A Wadee moves at that
## times its own hip height over LIB_HIPS, so its feet do not slide.
const PACE := {"Walk": 1.05, "Walk_Formal": 1.05, "Jog_Fwd": 5.9}
const LIB_HIPS := 0.917
## [model, clip, where on the loop it starts, deg].
const WALKERS := [["a", "Walk", 90.0], ["b", "Walk_Formal", 210.0], ["m", "Walk", 330.0]]
## [model, clip, where it stands, what it faces], [east, north] m.
const TALKERS := [["c", "Idle_Talking", [-9.4, 22.0], [-7.8, 22.0]],
	["n", "Idle", [-7.8, 22.0], [-9.4, 22.0]]]
## The crowd's loops: around this middle, at radii between these, all in view from
## RUN_VIEWS (the worst case for the frame rate: every one of them drawn and posed).
const CROWD := 20
const CROWD_AT := [-8.6, 24.0]
const CROWD_RADII := [3.0, 7.0]
## [name, where you stand, what you look at, head pitch deg], [east, north] m. The east bank
## is open; north of the loops (north 30 and on) stand the north court's houses.
const WALK_VIEWS := [
	["wadee_walk_bank", [-8.6, 33.0], [-8.6, 22.0], -6.0],
	["wadee_walk_side", [0.5, 25.0], [-8.6, 22.0], -4.0],
	["wadee_talkers", [-8.6, 18.6], [-8.6, 22.0], -2.0],
]
## Where the walk's run of frames is seen from: close, on the east bank.
const SEQ_WALK_VIEW := [[-1.0, 23.5], [-8.6, 22.0], -6.0]
const RUN_VIEWS := [
	["wadee_run_bank", [2.5, 25.5], [-8.6, 24.0], -5.0],
]
## Frames grabbed in a run, and the seconds between them.
const SEQ_FRAMES := 12
const SEQ_GAP := 0.1

## Steers one Wadee round a circle at its clip's pace, its feet on the ground.
class Walker extends Node:
	var model: Node3D
	var player: AnimationPlayer
	var ground: Callable
	var centre := Vector2.ZERO
	var radius := 5.0
	var angle := 0.0
	var speed := 0.0
	## Hip height over the library body's, from the skeleton's rest.
	var scale_to_lib := 1.0

	func play(clip: String, pace: float, at: Vector2, r: float) -> void:
		centre = at
		radius = r
		var anim := player.get_animation(clip)
		anim.loop_mode = Animation.LOOP_LINEAR
		player.play(clip, 0.3)
		speed = pace * scale_to_lib
		_place()

	func _process(delta: float) -> void:
		if speed > 0.0:
			angle += speed / radius * delta
			_place()

	func _place() -> void:
		var p := centre + Vector2(cos(angle), sin(angle)) * radius
		var q := centre + Vector2(cos(angle + 0.05), sin(angle + 0.05)) * radius
		var at: Vector3 = ground.call(p.x, p.y)
		var d: Vector3 = ground.call(q.x, q.y) - at
		model.transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), at)

var _walkers: Array[Walker] = []
## Every Wadee in the scene (walkers, talkers and the crowd), for the breakdown.
var _all: Array[Walker] = []

func _run() -> void:
	await _frames(3)
	_fleet = _scene.get("fleet")
	_starter = _scene.get_node("Ship")
	_director = _scene.get_node("CameraDirector")
	_avatar = get_first_node_in_group(Avatar.GROUP)
	_universe = _scene.get_node("Universe")
	_gravity = _scene.get("world_gravity")
	_stars = _scene.get("star_system")
	_scene.set("reload", func() -> void: pass)
	print("gpu     %s" % RenderingServer.get_video_adapter_name())
	var system: SystemRecipe = _scene.get("system")
	_planet = system.body(WORLD_ID)
	for place in system.places():
		if place.id == PLACE_ID:
			_oasis = place
	_starter.flight_computer.assist_enabled = true
	await _sit(_starter)
	await _hide_the_card()
	await _warp_in()
	if not await _to_the_planet():
		print("wadee   no world")
		quit(1)
		return
	_terrain = WorldTerrain.new(_planet.recipe)
	_starter.flight_computer.assist_enabled = true
	_find_the_oasis()
	await _aboard()
	await _starter_on_the_pad()
	_director.stand_now()
	await _frames(3)
	if not await _out_through(_starter.airlocks.values()[0], "", "foot"):
		quit(1)
		return
	var places: PlaceField = _scene.get("places")
	var node := places.loaded(PLACE_ID)
	var ground := PlaceField.ground_fn(_oasis, _terrain)
	for w: Array in WALKERS:
		var walker := _wadee(w[0], node, ground)
		walker.angle = deg_to_rad(float(w[2]))
		walker.play(w[1], PACE[w[1]], _v2(WALK_AT), WALK_RADIUS)
		_walkers.append(walker)
	for t: Array in TALKERS:
		var talker := _wadee(t[0], node, ground)
		var at: Vector3 = ground.call(float(t[2][0]), float(t[2][1]))
		var d: Vector3 = ground.call(float(t[3][0]), float(t[3][1])) - at
		talker.model.transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), at)
		talker.player.get_animation(t[1]).loop_mode = Animation.LOOP_LINEAR
		talker.player.play(t[1])
	print("wadee   %d walking a %.1f m loop, %d talking, in %s" % [WALKERS.size(), WALK_RADIUS, TALKERS.size(), node.name])
	for v: Array in WALK_VIEWS:
		await _foot_look(v[0], v[1], v[2], deg_to_rad(float(v[3])))
	await _foot_look("seq_walk_start", SEQ_WALK_VIEW[0], SEQ_WALK_VIEW[1], deg_to_rad(float(SEQ_WALK_VIEW[2])))
	await _sequence("seq_walk")
	await _reading_for("on foot by the pool with five Wadees moving", 5.0)
	for walker in _walkers:
		walker.play("Jog_Fwd", PACE["Jog_Fwd"], _v2(RUN_AT), RUN_RADIUS)
	for v: Array in RUN_VIEWS:
		await _foot_look(v[0], v[1], v[2], deg_to_rad(float(v[3])))
	await _sequence("seq_run")
	for walker in _walkers:
		walker.play("Walk", PACE["Walk"], _v2(WALK_AT), WALK_RADIUS)
	# a town's worth: CROWD more walking further out, for one reading (no floor: it is a measure)
	var models := ["a", "b", "c", "m", "n"]
	for i in CROWD:
		var walker := _wadee(models[i % models.size()], node, ground)
		walker.angle = TAU * i / CROWD
		var r := lerpf(float(CROWD_RADII[0]), float(CROWD_RADII[1]), float(i % 4) / 3.0)
		walker.play("Walk", PACE["Walk"], _v2(CROWD_AT), r)
	await _foot_look("wadee_crowd", RUN_VIEWS[0][1], RUN_VIEWS[0][2], deg_to_rad(float(RUN_VIEWS[0][3])))
	var fps := await _fps(5.0)
	var line := "fps     %.0f on foot by the pool with %d Wadees moving, over 5 s %s" % [fps, WALKERS.size() + TALKERS.size() + CROWD, _ms()]
	print(line)
	_readings.append(line)
	await _breakdown()
	_let_go()
	for l in _readings:
		print("        %s" % l)
	quit(0)

## One Wadee in the place's node, with its walker (which also holds its player).
func _wadee(tag: String, node: Node3D, ground: Callable) -> Walker:
	var model: Node3D = (load("res://assets/wadee/wadee_%s.glb" % tag) as PackedScene).instantiate()
	node.add_child(model)
	var walker := Walker.new()
	walker.model = model
	walker.ground = ground
	walker.player = model.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	walker.scale_to_lib = skeleton.get_bone_global_rest(skeleton.find_bone("Hips")).origin.y / LIB_HIPS
	node.add_child(walker)
	_all.append(walker)
	return walker

## Where the crowd's frame time goes, from the crowd view: the same view with one
## thing taken away at a time. Shadows and Godot's own lighter versions (LODs) are
## tried alone and put back; then the probe's steering, the motions and the Wadees
## themselves go one after another.
func _breakdown() -> void:
	await _part("all %d as they are" % _all.size())
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		_all[0].ground.call(-8.6 + i * 0.001, 24.0)
	var line := "cost    the ground under a point: %.1f us a call; the probe asks 2 a frame for each walker" % ((Time.get_ticks_usec() - t0) / 1000.0)
	print(line)
	_readings.append(line)
	var meshes: Array[MeshInstance3D] = []
	for w in _all:
		for m in w.model.find_children("*", "MeshInstance3D", true, false):
			meshes.append(m)
	line = "cost    %d mesh instances, %d surfaces in all" % [meshes.size(), meshes.reduce(func(n, m): return n + m.mesh.get_surface_count(), 0)]
	print(line)
	_readings.append(line)
	for m in meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _part("no shadows from the Wadees")
	for m in meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var vp := root.get_viewport()
	var lod := vp.mesh_lod_threshold
	vp.mesh_lod_threshold = 6.0
	await _part("LOD threshold 6 px (default %.0f)" % lod)
	vp.mesh_lod_threshold = lod
	for w in _all:
		w.speed = 0.0
	await _part("steering stopped, motions playing")
	for w in _all:
		w.player.pause()
	await _part("and the motions paused")
	for w in _all:
		w.model.visible = false
	await _part("and the Wadees hidden")

## One breakdown reading: frames a second, the renderer's times, the main
## thread's process time, and what was drawn (in view, and into shadows).
func _part(label: String) -> void:
	await _seconds(0.5)
	var fps := await _fps(4.0)
	var process := 0.0
	for k in 30:
		await process_frame
		process += Performance.get_monitor(Performance.TIME_PROCESS)
	var vp := root.get_viewport_rid()
	var info := func(type: int, what: int) -> int:
		return RenderingServer.viewport_get_render_info(vp, type, what)
	var line := "part    %.0f fps, %s %s, process %.1f ms; drawn %d calls %.2f M tris, shadows %d calls %.2f M tris" % [
		fps, label, _ms(), process / 30.0 * 1000.0,
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 1e6,
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		info.call(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 1e6]
	print(line)
	_readings.append(line)

## SEQ_FRAMES frames, SEQ_GAP s apart, from where you stand: oasis_<name>_NN.png.
func _sequence(seq_name: String) -> void:
	for k in SEQ_FRAMES:
		await _seconds(SEQ_GAP)
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s/oasis_%s_%02d.png" % [_out, seq_name, k])
	print("render  %s/oasis_%s_00..%02d.png" % [_out, seq_name, SEQ_FRAMES - 1])

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
