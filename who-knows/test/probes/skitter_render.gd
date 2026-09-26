extends SceneTree

# A herd of skitters on the start's big rock, as from a spacewalk, for the
# owner (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §17.2):
# grazing, frozen in a lamp, scattering at a jolt. Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/skitter_render.gd -- <abs out dir>
#
# Writes skitter_grazing, skitter_lit and skitter_scatter.png, and prints how
# many froze and scattered.

class Lamp extends SpotLight3D:
	var on := false
	func light_reach() -> float:
		return spot_range if on else 0.0
	func light_cone_deg() -> float:
		return spot_angle * 2.0
	func light_origin() -> Transform3D:
		return global_transform
	func light_kind() -> StringName:
		return &"lamp"

var _out := ""
var _cam: Camera3D
var _lamp: Lamp

func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.add_child(scene)
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _physics(n: int) -> void:
	for i in n:
		await physics_frame

func _shot(name: String) -> void:
	await _frames(6)
	var file := "%s/skitter_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _run(scene: Node) -> void:
	await _physics(5)
	var ship: Ship = scene.get_node("Ship")
	var stream: AsteroidStream = scene.get_node("AsteroidStream")
	var director: NpcDirector = scene.exterior_npcs
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var to_sun := sun.global_basis.z.normalized()
	var detail: AsteroidDetail = stream.details.live.values()[0]
	var site := RockSite.new(detail, stream.seed)
	var best: NpcRecord = null
	var best_lit := -2.0
	for r in site.records:
		var pose := site.frame() * site.start_pose(r, director.time)
		var lit := pose.basis.y.dot(to_sun)
		if lit > best_lit:
			best_lit = lit
			best = r
	print("sunniest herd member %s, lit %.2f" % [best.id, best_lit])
	var pose := site.frame() * site.start_pose(best, director.time)
	var n := pose.basis.y.normalized()
	# Bring the hull near (out of shot), so the herd wakes.
	ship.exterior.global_position = pose.origin + n * 250.0
	ship.exterior.freeze = true
	await _physics(90)
	print("live %d" % director.live.size())
	var herd: Array[Npc] = []
	for npc: Npc in director.live.values():
		if npc.record.herd == best.herd:
			herd.append(npc)
	# Let them settle, and keep them calm.
	await _physics(120)
	var centre := Vector3.ZERO
	for npc in herd:
		centre += npc.global_position
	centre /= maxf(herd.size(), 1)
	var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	_cam = Camera3D.new()
	_cam.far = 30000.0
	_cam.near = 0.05
	_cam.fov = 70.0
	scene.add_child(_cam)
	_cam.global_position = centre + n * 1.2 + side * 3.2
	_cam.look_at(centre + n * 0.2, n)
	_cam.make_current()
	_lamp = Lamp.new()
	_lamp.light_color = InteriorPalette.LIGHT_WARM
	_lamp.light_energy = 2.6
	_lamp.spot_range = 10.0
	_lamp.spot_angle = 22.0
	_lamp.visible = false
	_cam.add_child(_lamp)
	_lamp.add_to_group(StimulusBus.LIGHTS)
	await _shot("grazing")
	# The lamp on: they freeze.
	_lamp.on = true
	_lamp.visible = true
	await _physics(40)
	var frozen := 0
	for npc in herd:
		if npc.brain.current != null and npc.brain.current.id == &"freeze":
			frozen += 1
	print("frozen %d of %d" % [frozen, herd.size()])
	await _shot("lit")
	# Lamp off, and a jolt through the rock: they scatter.
	_lamp.on = false
	_lamp.visible = false
	await _physics(150)
	director.bus.emit(Stimulus.make(Stimulus.VIBRATION, centre + side * 3.0, 1.0, 40.0, null, site.id), 1.0)
	await _physics(30)
	var bolting := 0
	for npc in herd:
		if npc.brain.current != null and npc.brain.current.id == &"scatter":
			bolting += 1
	print("scattering %d of %d" % [bolting, herd.size()])
	_cam.global_position = centre + n * 4.0 + side * 7.0
	_cam.look_at(centre, n)
	await _shot("scatter")
	quit()
