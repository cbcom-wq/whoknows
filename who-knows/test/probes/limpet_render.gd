extends SceneTree

# A bed of limpets on the start's big rock, as from a spacewalk, for the owner
# (docs/superpowers/specs/2026-10-10-rock-creatures-design.md §11, §12): the
# bed seen from 4 m (to see the look itself), 40 m, 70 m and 100 m away, once standing at eye height (1.6 m)
# and once floating 12 m up, as a spacewalker drifts, asking "would I notice
# it?". The rock's own bed if it has one; otherwise a dev bed of eight (what
# F10 makes, with a few more). Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/limpet_render.gd -- <abs out dir>
#
# Writes limpet_<m>m.png (standing) and limpet_<m>m_up.png (floating), and
# prints, for each, how many limpets are in frame, whether the ground hides the
# bed, and how wide the bed's 5 m spread is on the screen.

const DISTANCES: Array[float] = [4.0, 40.0, 70.0, 100.0]
const EYE := 1.6
const FLOAT := 12.0

var _out := ""
var _cam: Camera3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "."
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	# Never the owner's saved game (saving spec §9): a windowed run would load and overwrite it.
	scene.save_enabled = false
	root.add_child(scene)
	_run.call_deferred(scene)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _physics(n: int) -> void:
	for i in n:
		await physics_frame

func _shot(name: String) -> void:
	await _frames(8)
	var file := "%s/limpet_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _run(scene: Node) -> void:
	await _physics(5)
	var ship: Ship = scene.get_node("Ship")
	# The crosshair would sit on the bed.
	for child in scene.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var stream: AsteroidStream = scene.get_node("AsteroidStream")
	var director: NpcDirector = scene.exterior_npcs
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var to_sun := sun.global_basis.z.normalized()
	var detail := stream.details.nearest(ship.exterior.global_position)
	# Bring the hull near, out of shot, so the rock's creatures are on offer.
	var first := detail.global_position + (ship.exterior.global_position - detail.global_position).normalized() \
		* (detail.rock.radius + 60.0)
	ship.exterior.global_position = first
	ship.exterior.freeze = true
	await _physics(30)
	var site: RockSite = scene.rock_life.site_for(detail.rock)
	var home := Vector3.ZERO
	var own := false
	for g in site.groups:
		if g["species"] == &"limpet":
			home = g["home_dir"]
			own = true
			break
	if not own:
		# No bed on this rock: make one where the hull is, as F10 does.
		var dev: DevCreatures = scene.dev_creatures[director]
		home = site.data.dir_of(site.frame().affine_inverse() * first)
		var ids: Array[StringName] = []
		for i in 8:
			ids.append(dev.next_id(&"limpet"))
		for record in site.add_group(&"limpet", home, 8, ids):
			dev.add(record, site)
	print("%s bed at %s on %s, rock radius %.0f m" % ["the rock's own" if own else "a dev", home, site.id,
		detail.rock.radius])
	var bed := site.frame() * site.data.surface_point(home)
	var n := (site.frame().basis * RockHerds.surface_normal(site.data, home)).normalized()
	var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	# The hull waits above the bed, within the limpets' wake radius, out of shot.
	ship.exterior.global_position = bed + n * 60.0 + side * 40.0
	await _physics(150)
	var live := 0
	for npc: Npc in director.live.values():
		if npc.species.id == &"limpet":
			live += 1
	print("limpets live %d" % live)
	_cam = Camera3D.new()
	_cam.far = 30000.0
	_cam.near = 0.05
	_cam.fov = 70.0
	scene.add_child(_cam)
	_cam.make_current()
	for height in [EYE, FLOAT]:
		var bearing := -1.0
		for metres in DISTANCES:
			var placed := _place(site, home, bed, n, to_sun, metres, height, bearing)
			bearing = placed[0]
			await _physics(2)
			var name := "%dm%s" % [int(metres), "" if height == EYE else "_up"]
			var seen := 0
			for npc: Npc in director.live.values():
				if npc.species.id == &"limpet" and not _cam.is_position_behind(npc.global_position):
					if Rect2(Vector2.ZERO, Vector2(root.size)).has_point(_cam.unproject_position(npc.global_position)):
						seen += 1
			print("%s: %.0f m from the bed at %.1f m up, ground in the way: %s, %d limpets in frame, bed %.0f px wide on a %d px screen" % [
				name, _cam.global_position.distance_to(bed), height, "yes" if placed[1] else "no", seen,
				_bed_pixels(bed, n), root.size.x])
			await _shot(name)
	quit()

# Puts the camera `metres` away from the bed (over the surface, so a bit less
# in a straight line), `height` over the ground, looking at it, on a bearing
# where nothing stands in the way and the bed is lit: the last shot's bearing if
# it still serves. Returns [bearing used, whether the ground is in the way].
func _place(site: RockSite, home: Vector3, bed: Vector3, n: Vector3, to_sun: Vector3, metres: float,
		height: float, prefer: float) -> Array:
	var best := -1.0
	var best_score := -INF
	var tries: Array[float] = []
	if prefer >= 0.0:
		tries.append(prefer)
	for k in 12:
		tries.append(TAU * float(k) / 12.0)
	var space := _cam.get_world_3d().direct_space_state
	var target := bed + n * 0.1
	for bearing in tries:
		var pose := site.frame() * site.pose_at(_dir_at(site, home, metres, bearing))
		var eye := pose.origin + pose.basis.y.normalized() * height
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target, AsteroidBody.LAYER))
		if not (hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 1.0):
			continue
		# Lit bed, sun behind or beside the viewer, never in the lens.
		var view := (target - eye).normalized()
		var score := n.dot(to_sun) - maxf(view.dot(to_sun), 0.0) * 0.5 + (10.0 if bearing == prefer else 0.0)
		if score > best_score:
			best_score = score
			best = bearing
	var blocked := best < 0.0
	if blocked:
		best = maxf(prefer, 0.0)
	var pose := site.frame() * site.pose_at(_dir_at(site, home, metres, best))
	var up := pose.basis.y.normalized()
	_cam.global_position = pose.origin + up * height
	_cam.look_at(target, up)
	return [best, blocked]

# The direction `metres` of surface from `home`, toward `bearing`.
func _dir_at(site: RockSite, home: Vector3, metres: float, bearing: float) -> Vector3:
	var angle := metres / maxf(site.data.surface_point(home).length(), 1.0)
	var dir := RockHerds.tilted(home, angle, bearing)
	for i in 3:
		var got := site.data.surface_point(home).distance_to(site.data.surface_point(dir))
		angle *= metres / maxf(got, 0.001)
		dir = RockHerds.tilted(home, angle, bearing)
	return dir

# How wide the bed's 5 m spread is on the screen, pixels.
func _bed_pixels(bed: Vector3, n: Vector3) -> float:
	var across := n.cross(_cam.global_basis.z).normalized()
	return _cam.unproject_position(bed - across * 2.5).distance_to(_cam.unproject_position(bed + across * 2.5))
