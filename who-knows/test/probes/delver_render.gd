extends SceneTree

# A Delver on the start's big rock, in daylight, as from a spacewalk, for the
# owner (docs/superpowers/specs/2026-10-10-rock-creatures-design.md §5, §12): is
# it a creature, would I notice it, how does it go under and come up, what does
# it leave behind. Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/delver_render.gd -- <abs out dir> [--no-snag | --far-only]
#
# A dev Delver (F10's path, so it has a round of burrow points about where it
# is put) on the ground that takes the sun at about 40 degrees, the camera on
# the sun's side. Writes into the out dir:
#   delver_close.png          about 5 m, the whole body
#   delver_sink_1..3.png      going under (the look sunk 0.12, 0.26, 0.38 m of 0.4)
#   delver_rise_1..3.png      coming up 16 m on: rising, just up with the ring of puffs, the puffs drifting
#   delver_heap.png           about 2 m from the grit it left
#   delver_40m.png, _100m.png  40 and 100 m from it, looking down 35 degrees (the usual view of a
#                             rock below a spacewalker); _low: 12 degrees, nearly along the ground
#   delver_40m_zoom.png       the 40 m picture round the Delver, blown up four times
# and prints how the 3 m body fares on the rock (spec §16: does it snag?): it is
# sent 25 m over three routes, one across a crater, and its progress and stalls
# are counted.

const EYE := 1.6
const FLOAT := 12.0

var _out := ""
var _scene: Node
var _cam: Camera3D
var _site: RockSite
var _director: NpcDirector
var _npc: Npc

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "."
	_scene = load("res://scenes/flight_test.tscn").instantiate()
	# Never the owner's saved game (saving spec §9): a windowed run would load and overwrite it.
	_scene.save_enabled = false
	root.add_child(_scene)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _physics(n: int) -> void:
	for i in n:
		await physics_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var file := "%s/delver_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _run() -> void:
	await _physics(5)
	var ship: Ship = _scene.get_node("Ship")
	for child in _scene.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var stream: AsteroidStream = _scene.get_node("AsteroidStream")
	_director = _scene.exterior_npcs
	var sun: DirectionalLight3D = _scene.get_node("DirectionalLight3D")
	var detail := stream.details.nearest(ship.exterior.global_position)
	var first := detail.global_position + (ship.exterior.global_position - detail.global_position).normalized() \
		* (detail.rock.radius + 60.0)
	ship.exterior.global_position = first
	ship.exterior.freeze = true
	await _physics(30)
	_site = _scene.rock_life.site_for(detail.rock)
	var to_sun := sun.global_basis.z.normalized()
	print("rock %s: %s, radius %.0f m, %d craters" % [_site.id, RockMesh.Shape.keys()[detail.rock.shape], detail.rock.radius,
		_site.data.craters.size()])
	_cam = Camera3D.new()
	_cam.far = 30000.0
	_cam.near = 0.05
	_cam.fov = 60.0
	_scene.add_child(_cam)
	_cam.make_current()
	# The ground that takes the sun at about 40 degrees up: lit, and shaped by it.
	var best := Vector3.UP
	var best_score := -INF
	var count := 600
	for k in count:
		var y := 1.0 - 2.0 * (float(k) + 0.5) / float(count)
		var r := sqrt(1.0 - y * y)
		var dir := Vector3(cos(float(k) * 2.399963) * r, y, sin(float(k) * 2.399963) * r)
		var up := (_site.frame().basis * RockHerds.surface_normal(_site.data, dir)).normalized()
		var score := -absf(up.dot(to_sun) - 0.75)
		if score > best_score:
			best_score = score
			best = dir
	var spot := _site.frame() * _site.data.surface_point(best)
	var n := (_site.frame().basis * RockHerds.surface_normal(_site.data, best)).normalized()
	var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	print("ground facing the sun %.2f (1 straight at it)" % n.dot(to_sun))
	ship.exterior.global_position = spot + n * 60.0 + side * 40.0
	await _physics(120)
	_cam.global_position = spot + n * 8.0 + side * 1.0
	_cam.look_at(spot, side)
	await _physics(3)
	print("spawn: %s" % _scene.spawn_creature(&"delver"))
	await _physics(150)
	for npc: Npc in _director.live.values():
		if npc.species.id == &"delver":
			_npc = npc
	if _npc == null:
		print("NO DELVER CAME LIVE")
		quit(1)
		return
	# The mind is off; the probe gives the orders.
	_npc.brain = null
	var round := _site.burrow_points(_site.group_of(_npc.record))
	print("delver %s: %d burrow points, %.0f triangles in its look, %s locomotor" % [_npc.record.id, round.size(),
		_triangles(_npc.look), _npc.active.id])
	var flags := OS.get_cmdline_user_args()
	await _close(to_sun)
	if flags.has("--far-only"):
		await _far(to_sun)
		quit()
		return
	await _sink_and_rise(to_sun, round)
	await _heap(to_sun)
	await _far(to_sun)
	if not flags.has("--no-snag"):
		await _snag()
	quit()

static func _triangles(root_node: Node) -> int:
	var total := 0
	for mi in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			for s in mesh.get_surface_count():
				total += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3
	return total

## The Delver's own up and forward (engine space) and the side of it that faces the sun.
func _frame_of(npc: Npc, to_sun: Vector3) -> Array:
	var up := npc.global_basis.y.normalized()
	var across := npc.global_basis.x.normalized()
	if across.dot(to_sun) < 0.0:
		across = -across
	return [up, across]

## The camera `metres` off the Delver's sun-facing flank, `height` over the ground, on `at`.
func _aim(at: Vector3, up: Vector3, across: Vector3, metres: float, height: float, fov := 60.0, look_up := 0.15) -> void:
	_cam.fov = fov
	_cam.global_position = at + across * metres + up * height
	_cam.look_at(at + up * look_up, up)

func _close(to_sun: Vector3) -> void:
	var f := _frame_of(_npc, to_sun)
	_aim(_npc.global_position, f[0], f[1], 5.0, EYE, 50.0, 0.2)
	await _physics(3)
	_report("close")
	await _save("close")
	# And nearer, to see the plates and the snout.
	_aim(_npc.global_position, f[0], f[1], 2.6, 0.9, 55.0, 0.2)
	await _physics(3)
	await _save("closer")

func _report(name: String) -> void:
	var p0 := _cam.unproject_position(_npc.global_position - _npc.global_basis.z * 1.5)
	var p1 := _cam.unproject_position(_npc.global_position + _npc.global_basis.z * 1.5)
	print("%s: %.1f m away; its 3 m is %.0f px on a %d px screen" % [name, _cam.global_position.distance_to(_npc.global_position),
		p0.distance_to(p1), root.size.x])

## Sinking where it stands, then 16 m under the rock and coming up, shot as it goes.
func _sink_and_rise(to_sun: Vector3, round: Array[Vector3]) -> void:
	var burrower := _npc.locomotors[&"burrower"] as Burrower
	# Where it comes up: 16 m along the surface from here.
	var here := _site.data.dir_of(_npc.local_position())
	var metres := _site.data.surface_point(here).length()
	var target_dir := RockHerds.tilted(here, 16.0 / metres, 2.2)
	var target := _site.data.surface_point(target_dir)
	var pose_there := _site.frame() * _site.pose_at(target_dir)
	var f := _frame_of(_npc, to_sun)
	_aim(_npc.global_position, f[0], f[1], 4.5, 1.3, 55.0, 0.1)
	await _physics(2)
	_npc.intent = Intent.go(target, 1.0, &"burrow")
	var marks: Array[float] = [0.12, 0.26, 0.38]
	var taken := 0
	var t0 := Time.get_ticks_msec()
	while taken < marks.size() and Time.get_ticks_msec() - t0 < 6000:
		await process_frame
		if _npc.look_drop >= marks[taken]:
			taken += 1
			print("sink %d: look sunk %.2f m, collider %s" % [taken, _npc.look_drop, "off" if _npc._shape.disabled else "on"])
			await _save("sink_%d" % taken)
	# Under: the camera goes to where it will come up, on its flank.
	var up_t := pose_there.basis.y.normalized()
	var across_t := pose_there.basis.x.normalized()
	if across_t.dot(to_sun) < 0.0:
		across_t = -across_t
	_aim(pose_there.origin, up_t, across_t, 6.5, 2.0, 55.0, 0.2)
	var taken_rise := 0
	var surfaced_at := _npc.surfaced_at
	var t_up := -1.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and taken_rise < 3:
		await process_frame
		if burrower.phase == Burrower.Phase.RISING and taken_rise == 0 and _npc.look_drop <= 0.3:
			taken_rise = 1
			print("rise 1: look sunk %.2f m, %.1f m from the exit" % [_npc.look_drop, _npc.global_position.distance_to(pose_there.origin)])
			await _save("rise_1")
		elif _npc.surfaced_at != surfaced_at and t_up < 0.0:
			t_up = float(Time.get_ticks_msec()) / 1000.0
			var puffs := _npc.look.find_children("Puff*", "MeshInstance3D", true, false).size()
			if taken_rise == 0:
				taken_rise = 1
			taken_rise = 2
			print("rise 2: up; %d puffs; grit near %d, shards near %d" % [puffs, _grit(_npc.global_position, 6.0), _shards(_npc.global_position, 6.0)])
			await _save("rise_2")
		elif t_up > 0.0 and float(Time.get_ticks_msec()) / 1000.0 - t_up >= 0.55 and taken_rise == 2:
			taken_rise = 3
			print("rise 3: %d puffs left" % _npc.look.find_children("Puff*", "MeshInstance3D", true, false).size())
			await _save("rise_3")
	print("up %.2f m from where it was asked to; took %.0f s" % [_npc.global_position.distance_to(pose_there.origin),
		float(Time.get_ticks_msec() - t0) / 1000.0])

func _items(kind: StringName, near: Vector3, within: float) -> Array[Item]:
	var out: Array[Item] = []
	for item: Item in get_nodes_in_group(Item.GROUP):
		if item.definition != null and item.definition.id == kind and item.global_position.distance_to(near) <= within:
			out.append(item)
	return out

func _grit(near: Vector3, within: float) -> int:
	return _items(&"crystal_grit", near, within).size()

func _shards(near: Vector3, within: float) -> int:
	return _items(&"quantum_shard", near, within).size()

## The grit it left, seen from 2 m after it has walked off.
func _heap(to_sun: Vector3) -> void:
	var left := _npc.global_position
	var grit := _items(&"crystal_grit", left, 6.0)
	print("grit where it came up: %d pieces (the cap is %d); shards %d" % [grit.size(), RockSite.GRIT_CAP, _shards(left, 6.0)])
	if grit.is_empty():
		return
	var centre := Vector3.ZERO
	for item in grit:
		centre += item.global_position
	centre /= grit.size()
	var up := _npc.global_basis.y.normalized()
	# It walks off, forward, so the heap is left on its own.
	var ahead := -_npc.global_basis.z.normalized()
	_npc.intent = Intent.go(_npc.local_position() + _site.frame().basis.inverse() * (ahead * 7.0), 0.6)
	await _physics(60 * 9)
	grit = _items(&"crystal_grit", left, 12.0)
	var moved := centre
	centre = Vector3.ZERO
	for item in grit:
		centre += item.global_position
	centre /= maxf(grit.size(), 1.0)
	print("the heap: %d pieces; the walk moved its middle %.2f m" % [grit.size(), moved.distance_to(centre)])
	var gone := _npc.global_position.distance_to(centre)
	print("it has walked %.1f m from the heap" % gone)
	var across := up.cross(ahead).normalized()
	if across.dot(to_sun) < 0.0:
		across = -across
	var lowest := INF
	var space := root.get_world_3d().direct_space_state
	for item in grit:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(item.global_position + up, item.global_position - up * 3.0, AsteroidBody.LAYER))
		if not hit.is_empty():
			lowest = minf(lowest, (item.global_position - (hit["position"] as Vector3)).dot(up))
	print("grit rests %.2f m or more off the ground (its box is %.2f m high)" % [lowest, grit[0].definition.size.y])
	_aim(centre, up, across, 2.0, 0.9, 55.0, 0.0)
	await _physics(3)
	await _save("heap")
	_aim(centre, up, across, 1.0, 0.5, 50.0, 0.0)
	await _physics(2)
	await _save("heap_close")

## 40 m and 100 m from it, by the sun, as a spacewalker sees it: looking down at it from 35
## degrees over the ground (the usual view of a rock below you), and from 12 degrees (nearly
## along the ground). Camera and Delver `metres` apart in a straight line.
func _far(to_sun: Vector3) -> void:
	_npc.intent = Intent.idle()
	await _physics(30)
	var at := _npc.global_position
	var up := _npc.global_basis.y.normalized()
	var space := root.get_world_3d().direct_space_state
	var tangent := to_sun - up * to_sun.dot(up)
	tangent = tangent.normalized() if tangent.length() > 0.2 else up.cross(Vector3.RIGHT).normalized()
	for metres: float in [40.0, 100.0]:
		for elevation: float in [35.0, 12.0]:
			var best := Vector3.ZERO
			var best_score := -INF
			var found := false
			for k in 16:
				var heading := tangent.rotated(up, TAU * float(k) / 16.0)
				var eye := at + (heading * cos(deg_to_rad(elevation)) + up * sin(deg_to_rad(elevation))) * metres
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at + up * 0.3, AsteroidBody.LAYER))
				if not hit.is_empty() and (hit["position"] as Vector3).distance_to(at + up * 0.3) > 1.0:
					continue
				found = true
				# Sun behind the camera.
				var score := -(at - eye).normalized().dot(to_sun)
				if score > best_score:
					best_score = score
					best = eye
			var tag := "%dm%s" % [int(metres), "" if elevation > 20.0 else "_low"]
			if not found:
				print("%s: the ground hides it from every bearing" % tag)
				continue
			_cam.fov = 70.0
			_cam.global_position = best
			_cam.look_at(at + up * 0.3, up)
			# Its flank to the camera: the way it happens to face is no part of the question.
			var to_cam := best - at
			to_cam -= up * to_cam.dot(up)
			var back := up.cross(to_cam.normalized()).normalized()
			_npc.global_basis = Basis(up.cross(back).normalized(), up, back)
			await _physics(2)
			var p0 := _cam.unproject_position(at - _npc.global_basis.z * 1.5)
			var p1 := _cam.unproject_position(at + _npc.global_basis.z * 1.5)
			print("%s: %.0f m away, %.0f m over the ground (%.0f degrees up); its 3 m is %.0f px on a %d px screen" % [tag,
				best.distance_to(at), (best - at).dot(up), elevation, p0.distance_to(p1), root.size.x])
			await _save(tag)
			if elevation > 20.0:
				_zoom("%dm_zoom" % int(metres), _cam.unproject_position(at))

func _zoom(name: String, centre: Vector2) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var w := 240
	var h := 135
	var x := clampi(int(centre.x) - w / 2, 0, image.get_width() - w)
	var y := clampi(int(centre.y) - h / 2, 0, image.get_height() - h)
	var crop := image.get_region(Rect2i(x, y, w, h))
	crop.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/delver_%s.png" % [_out, name])
	print("render  %s/delver_%s.png (Delver at pixel %s)" % [_out, name, centre])

## The direction `metres` of surface from `from` toward `heading`.
func _dir_from(from: Vector3, heading: Vector3, metres: float) -> Vector3:
	var start := _site.data.dir_of(_site.frame().affine_inverse() * from)
	var local_heading := _site.frame().basis.inverse() * heading
	var bearing_axis := start.cross(local_heading).normalized()
	var angle := metres / maxf(_site.data.surface_point(start).length(), 1.0)
	var dir := start
	for i in 3:
		dir = start.rotated(bearing_axis, angle).normalized()
		var got := _site.data.surface_point(start).distance_to(_site.data.surface_point(dir))
		angle *= metres / maxf(got, 0.001)
	return dir

## Does the 3 m body snag? Legs of 30 m at speed 1 (1.2 m/s: 25 s), each from a
## fresh start: down into the nearest crater, out of it again, and over open
## ground on three bearings. Prints, for each, when it arrived and its longest
## stall (a second or more under 0.3 m/s with ground still to cover), and a
## verdict. A leg that does not arrive in 60 s is stuck.
func _snag() -> void:
	print("--- does the 3 m body snag? ---")
	var here := _site.data.dir_of(_npc.local_position())
	var crater := Vector3.ZERO
	var best := INF
	for c in _site.data.craters:
		var d := (c[0] as Vector3).angle_to(here)
		if d < best:
			best = d
			crater = c[0]
	var legs: Array[Array] = [
		["into the crater", _along(crater, 1.0, 30.0), crater],
		["out of the crater", crater, _along(crater, 3.0, 30.0)],
		["open ground A", here, _along(here, 0.9, 30.0)],
		["open ground B", _along(here, 2.5, 40.0), _along(here, 4.1, 40.0)],
		["open ground C", _along(here, 5.2, 60.0), _along(here, 5.9, 80.0)],
	]
	var stuck := 0
	for leg in legs:
		var start: Vector3 = leg[1]
		var goal: Vector3 = leg[2]
		_npc.global_transform = _site.frame() * _site.pose_at(start)
		_npc.velocity = Vector3.ZERO
		await _physics(30)
		var target := _site.data.surface_point(goal)
		var asked := _npc.local_position().distance_to(target)
		_npc.intent = Intent.go(target, 1.0)
		var last := _npc.global_position
		var stall := 0.0
		var worst := 0.0
		var t := 0.0
		var arrived := -1.0
		var ups := 0.0
		while t < 60.0:
			await _physics(30)
			t += 0.5
			var moved := _npc.global_position.distance_to(last)
			last = _npc.global_position
			if moved / 0.5 < 0.3 and _npc.local_position().distance_to(target) > 1.7:
				stall += 0.5
				worst = maxf(worst, stall)
			else:
				stall = 0.0
			if _npc.local_position().distance_to(target) < 1.7:
				arrived = t
				break
		var snagged := arrived < 0.0 or worst >= 3.0
		stuck += 1 if snagged else 0
		print("%s: %.0f m asked, %s, longest stall %.1f s, now %.1f m from the goal, on %s  -> %s" % [leg[0], asked,
			("arrived in %.1f s (%.2f m/s)" % [arrived, asked / arrived]) if arrived >= 0.0 else "NOT ARRIVED in 60 s", worst,
			_npc.local_position().distance_to(target), _npc.active.id, "SNAGGED" if snagged else "free"])
	print("snagged on %d of %d legs" % [stuck, legs.size()])
	_npc.intent = Intent.idle()

## The direction `metres` of surface from `dir`, toward `bearing`.
func _along(dir: Vector3, bearing: float, metres: float) -> Vector3:
	var angle := metres / maxf(_site.data.surface_point(dir).length(), 1.0)
	var out := RockHerds.tilted(dir, angle, bearing)
	for i in 3:
		var got := _site.data.surface_point(dir).distance_to(_site.data.surface_point(out))
		angle *= metres / maxf(got, 0.001)
		out = RockHerds.tilted(dir, angle, bearing)
	return out
