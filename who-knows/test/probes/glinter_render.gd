extends SceneTree

# A Glinter nest on the start's big rock, as from a spacewalk, for the owner
# (docs/superpowers/specs/2026-10-10-rock-creatures-design.md §4, §12): would I
# notice it from afar, do the Glinters read as creatures up close, and do they
# flash on one beat beside the salvage's own blinks? Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/glinter_render.gd -- <abs out dir>
#
# The rock's own nest is used if it has one (the start rock does); otherwise a
# dev nest of four, as F10 makes one. Writes into the out dir:
#   glinter_<m>m.png, _up                  40 m and 100 m, standing at eye height
#                                           (1.6 m) and floating 12 m up, caught on the nest's
#                                           beat (all its glints lit); glinter_40m_dark.png is
#                                           the same view between flashes
#   glinter_close.png, glinter_close_beat.png   about 4 m: Glinters among the real salvage, by the
#                                           lamp (the nest is on the rock's night side); _sun: with the
#                                           sun brought round to it; glinter_one_shut.png one Glinter, 1.1 m
#   glinter_beat_<k>.png, glinter_beat_sheet.png   the frames, in order, in which what is lit
#                                           changes: the nest's Glinters together, the salvage
#                                           on its own
#   glinter_spring_pov_<k>.png               through the suit's eye as a Glinter springs and bites
#   glinter_spring_side_<k>.png              the same spring seen from beside its path
#   glinter_lit_*.png                         a dev nest of four Glinters and three real pieces of
#                                           salvage on the rock's sunlit side, in daylight, no lamp: _close (3 m),
#                                           _one (1 m, shut), _40m (from 40 m), _sprung_1..4 (a
#                                           spacewalker drifting over it, from 6 m to the side: spring,
#                                           bite, rebound, the start of its puff home)
# and prints, for the nest, how its Glinters and salvage lie on the ground.

const DISTANCES: Array[float] = [40.0, 100.0]
const EYE := 1.6
const FLOAT := 12.0

var _out := ""
var _cam: Camera3D
var _scene: Node
var _director: NpcDirector
var _site: RockSite
var _home := Vector3.ZERO
var _bed := Vector3.ZERO
var _n := Vector3.UP

class Lamp extends SpotLight3D:
	func light_reach() -> float:
		return spot_range
	func light_cone_deg() -> float:
		return spot_angle * 2.0
	func light_origin() -> Transform3D:
		return global_transform
	func light_kind() -> StringName:
		return &"lamp"

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
	var file := "%s/glinter_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

## The nest's Glinters, live.
func _glinters() -> Array[Npc]:
	var out: Array[Npc] = []
	for npc: Npc in _director.live.values():
		if npc.species.id == &"glinter" and npc.record.herd == _group:
			out.append(npc)
	return out

var _group := -1
var _lamp: SpotLight3D

## Every Glinter glint of the nest, and every glint of salvage near it.
func _glints() -> Array[ItemLooks.Glint]:
	var out: Array[ItemLooks.Glint] = []
	for npc in _glinters():
		var g := (npc.look as GlinterLook).glint if npc.look is GlinterLook else null
		if g != null:
			out.append(g)
	return out

func _salvage_glints() -> Array[ItemLooks.Glint]:
	var out: Array[ItemLooks.Glint] = []
	for item: Item in get_nodes_in_group(Item.GROUP):
		if item.global_position.distance_to(_bed) > 12.0:
			continue
		for c in item.find_children("*", "MeshInstance3D", true, false):
			if c is ItemLooks.Glint:
				out.append(c)
	return out

static func _lit(glints: Array[ItemLooks.Glint]) -> int:
	var n := 0
	for g in glints:
		if g.is_visible_in_tree():
			n += 1
	return n

## Waits until the nest is on its beat (every Glinter's glint lit), or `dark`
## until none is, then draws.
func _wait_beat(dark := false) -> void:
	var glints := _glints()
	for i in 600:
		await process_frame
		var lit := _lit(glints)
		if (not dark and lit == glints.size()) or (dark and lit == 0):
			break
	await process_frame

func _run() -> void:
	await _physics(5)
	var ship: Ship = _scene.get_node("Ship")
	# The crosshair would sit on the nest.
	for child in _scene.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var stream: AsteroidStream = _scene.get_node("AsteroidStream")
	_director = _scene.exterior_npcs
	var sun: DirectionalLight3D = _scene.get_node("DirectionalLight3D")
	var to_sun := sun.global_basis.z.normalized()
	var detail := stream.details.nearest(ship.exterior.global_position)
	var first := detail.global_position + (ship.exterior.global_position - detail.global_position).normalized() \
		* (detail.rock.radius + 60.0)
	ship.exterior.global_position = first
	ship.exterior.freeze = true
	await _physics(30)
	_site = _scene.rock_life.site_for(detail.rock)
	var own := false
	for g in _site.groups:
		if g["species"] == &"glinter" and int(g["index"]) < RockSite.DEV_FIRST:
			_home = g["home_dir"]
			_group = int(g["index"])
			own = true
			break
	if not own:
		var dev: DevCreatures = _scene.dev_creatures[_director]
		_home = _site.data.dir_of(_site.frame().affine_inverse() * first)
		var ids: Array[StringName] = []
		for i in 4:
			ids.append(_scene._new_dev_id(dev, &"glinter"))
		for record in _site.add_group(&"glinter", _home, 4, ids):
			dev.add(record, _site)
			_group = record.herd
	_bed = _site.frame() * _site.data.surface_point(_home)
	_n = (_site.frame().basis * RockHerds.surface_normal(_site.data, _home)).normalized()
	var side := _n.cross(Vector3.UP if absf(_n.y) < 0.9 else Vector3.RIGHT).normalized()
	print("%s nest at %s on %s, rock radius %.0f m" % ["the rock's own" if own else "a dev", _home, _site.id, detail.rock.radius])
	# The hull waits above the nest, within the Glinters' wake radius, out of shot.
	ship.exterior.global_position = _bed + _n * 60.0 + side * 40.0
	await _physics(150)
	print("the nest's up against the sun: %.2f (1 straight into it, below 0 night side)" % _n.dot(to_sun))
	print("glinters live %d; salvage items within 12 m: %d" % [_glinters().size(), _salvage_glints().size()])
	_ground_report()
	_cam = Camera3D.new()
	_cam.far = 30000.0
	_cam.near = 0.05
	_cam.fov = 70.0
	_scene.add_child(_cam)
	_cam.make_current()
	# The spacewalker's lamp, on the camera; off for the far shots.
	_lamp = SpotLight3D.new()
	_lamp.light_color = InteriorPalette.LIGHT_WARM
	_lamp.light_energy = 2.6
	_lamp.spot_range = 12.0
	_lamp.spot_angle = 35.0
	_lamp.visible = false
	_cam.add_child(_lamp)
	if OS.get_cmdline_user_args().has("--lit-only"):
		await _lit_set(ship, sun)
		quit()
		return
	# Far shots, as the rock is (its night side), then with the sun brought round
	# to the nest, which is where a day-side nest would be.
	await _far_shots("", to_sun)
	var real_sun := sun.global_basis
	# The star system re-aims the sun every physics tick: hold it.
	_scene.star_system.set_physics_process(false)
	sun.global_basis = Basis.looking_at(-(_n * 0.8 + side * 0.5).normalized(), Vector3.UP)
	await _physics(5)
	to_sun = sun.global_basis.z.normalized()
	print("sun moved onto the nest: its up against the sun %.2f" % _n.dot(to_sun))
	await _far_shots("_sun", to_sun)
	_lamp.visible = false
	# Close, by the lamp (the nest is on the rock's night side) and then by the sun.
	_cam.fov = 60.0
	for tag in ["_sun", ""]:
		if tag == "":
			sun.global_basis = real_sun
			_scene.star_system.set_physics_process(true)
			_lamp.visible = true
			await _physics(5)
			to_sun = sun.global_basis.z.normalized()
		_place(4.0, EYE, -1.0, to_sun)
		await _physics(2)
		await _wait_beat(true)
		_save("close%s" % tag)
		await _wait_beat()
		_save("close%s_beat" % tag)
	# The beat, across frames, from about 10 m, by the lamp.
	_cam.fov = 55.0
	_place(6.0, 2.5, -1.0, to_sun)
	await _physics(2)
	_lamp.spot_range = 20.0
	await _beat_sequence()
	_lamp.spot_range = 12.0
	# One Glinter, shut, from 1.1 m and half a metre up: does it read as a creature?
	var one := _glinters()[0]
	var one_up := one.global_basis.y.normalized()
	var one_side := one_up.cross(Vector3.RIGHT if absf(one_up.x) < 0.9 else Vector3.BACK).normalized()
	_cam.fov = 50.0
	_cam.global_position = one.global_position + one_side * 1.1 + one_up * 0.5
	_cam.look_at(one.global_position + one_up * 0.15, one_up)
	await _physics(2)
	await _wait_beat(true)
	_save("one_shut")
	_cam.fov = 70.0
	await _spring(ship, side, to_sun)
	await _lit_set(ship, sun)
	quit()

## The far shots, 40 m and 100 m, standing and floating, as the sun is.
func _far_shots(tag: String, to_sun: Vector3) -> void:
	for height in [EYE, FLOAT]:
		var bearing := -1.0
		for metres in DISTANCES:
			var placed := _place(metres, height, bearing, to_sun)
			bearing = placed[0]
			await _physics(2)
			var name := "%dm%s%s" % [int(metres), "" if height == EYE else "_up", tag]
			print("%s: %.0f m from the nest at %.1f m up, ground in the way: %s, nest %.0f px wide on a %d px screen" % [
				name, _cam.global_position.distance_to(_bed), height, "yes" if placed[1] else "no", _bed_pixels(),
				root.size.x])
			await _wait_beat()
			_save(name)
			if height == EYE and metres == 40.0:
				await _wait_beat(true)
				_save("40m%s_dark" % tag)

# --- the ground ---------------------------------------------------------------------

## How the nest's Glinters and salvage lie on the rock: the distance of each from
## the ground straight below it (along the nest's up).
func _ground_report() -> void:
	var space := root.get_world_3d().direct_space_state
	var gaps: Array[float] = []
	for npc in _glinters():
		gaps.append(_gap(space, npc.global_position))
	print("glinters stand %s m off the ground (feet)" % _fmt(gaps))
	gaps.clear()
	var count := 0
	for item: Item in get_nodes_in_group(Item.GROUP):
		if item.global_position.distance_to(_bed) > 12.0:
			continue
		count += 1
		var bottom := item.global_position
		var box := _lowest(item)
		gaps.append(_gap(space, box))
	print("%d salvage items: the lowest point of each is %s m off the ground" % [count, _fmt(gaps)])

static func _fmt(values: Array[float]) -> String:
	var parts: Array[String] = []
	for v in values:
		parts.append("%.2f" % v)
	return "[" + ", ".join(parts) + "]"

## The lowest point of an item's meshes, toward the rock (its up is the rock's).
func _lowest(item: Node3D) -> Vector3:
	var best := item.global_position
	var best_d := INF
	for c in item.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi is ItemLooks.Glint or mi.mesh == null:
			continue
		var box := mi.get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					var p := mi.global_transform * Vector3(x, y, z)
					var d := p.dot(_n)
					if d < best_d:
						best_d = d
						best = p
	return best

## How far above the rock `p` is, along the nest's up (negative: sunk in it).
func _gap(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + _n * 3.0, p - _n * 3.0, AsteroidBody.LAYER)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return INF
	return (p - (hit["position"] as Vector3)).dot(_n)

# --- placing the camera ---------------------------------------------------------------

## Puts the camera `metres` from the nest (over the surface), `height` over the
## ground, looking at it, on a bearing where nothing stands in the way and the
## nest is lit: `prefer` if it still serves. Returns [bearing, ground in the way].
func _place(metres: float, height: float, prefer: float, to_sun: Vector3) -> Array:
	var best := -1.0
	var best_score := -INF
	var tries: Array[float] = []
	if prefer >= 0.0:
		tries.append(prefer)
	for k in 12:
		tries.append(TAU * float(k) / 12.0)
	var space := _cam.get_world_3d().direct_space_state
	var target := _bed + _n * 0.15
	for bearing in tries:
		var pose := _site.frame() * _site.pose_at(_dir_at(metres, bearing))
		var eye := pose.origin + pose.basis.y.normalized() * height
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target, AsteroidBody.LAYER))
		if not (hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 1.0):
			continue
		var view := (target - eye).normalized()
		var score := _n.dot(to_sun) - maxf(view.dot(to_sun), 0.0) * 0.5 + (10.0 if bearing == prefer else 0.0)
		if score > best_score:
			best_score = score
			best = bearing
	var blocked := best < 0.0
	if blocked:
		best = maxf(prefer, 0.0)
	var pose := _site.frame() * _site.pose_at(_dir_at(metres, best))
	var up := pose.basis.y.normalized()
	_cam.global_position = pose.origin + up * height
	_cam.look_at(target, up)
	return [best, blocked]

## The direction `metres` of surface from the nest, toward `bearing`.
func _dir_at(metres: float, bearing: float) -> Vector3:
	var angle := metres / maxf(_site.data.surface_point(_home).length(), 1.0)
	var dir := RockHerds.tilted(_home, angle, bearing)
	for i in 3:
		var got := _site.data.surface_point(_home).distance_to(_site.data.surface_point(dir))
		angle *= metres / maxf(got, 0.001)
		dir = RockHerds.tilted(_home, angle, bearing)
	return dir

func _bed_pixels() -> float:
	var across := _n.cross(_cam.global_basis.z).normalized()
	return _cam.unproject_position(_bed - across * 2.5).distance_to(_cam.unproject_position(_bed + across * 2.5))

# --- the beat ----------------------------------------------------------------------------

## Draws frame after frame for a few seconds, keeping the ones in which what is
## lit changes to something new: prints each, saves them, and a sheet of them.
func _beat_sequence() -> void:
	var nest := _glints()
	var salvage := _salvage_glints()
	print("beat: %d Glinter glints, %d salvage glints" % [nest.size(), salvage.size()])
	var kept: Array[Image] = []
	var last := Vector2i(-1, -1)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4500 and kept.size() < 8:
		await process_frame
		var now := Vector2i(_lit(nest), _lit(salvage))
		if now == last:
			continue
		last = now
		if now == Vector2i.ZERO and not kept.is_empty():
			continue
		await RenderingServer.frame_post_draw
		kept.append(root.get_viewport().get_texture().get_image())
		print("beat frame %d at %.2f s: %d of %d Glinter glints lit, %d of %d salvage glints lit" % [
			kept.size(), float(Time.get_ticks_msec() - t0) / 1000.0, now.x, nest.size(), now.y, salvage.size()])
	for k in kept.size():
		kept[k].save_png("%s/glinter_beat_%d.png" % [_out, k + 1])
	if kept.is_empty():
		return
	var w := kept[0].get_width() / 2
	var h := kept[0].get_height() / 2
	var cols := 2
	var rows := ceili(float(kept.size()) / cols)
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for k in kept.size():
		var small := kept[k].duplicate() as Image
		small.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(small, Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
	sheet.save_png("%s/glinter_beat_sheet.png" % _out)
	print("render  %s/glinter_beat_sheet.png (%d frames)" % [_out, kept.size()])

# --- the spring --------------------------------------------------------------------------

## A spacewalker looking down drifts 4 m over the nest, lamp on, and a Glinter
## springs. Seen twice: through the suit's eye, and from beside its path.
func _spring(ship: Ship, side: Vector3, to_sun: Vector3) -> void:
	var avatar: Avatar = _scene.get_node("Ship/Interior/Avatar")
	var lamp := Lamp.new()
	lamp.spot_range = 10.0
	lamp.spot_angle = 30.0
	lamp.light_energy = 0.0
	lamp.add_to_group(StimulusBus.LIGHTS)
	var pose0 := Transform3D(Basis.IDENTITY, _bed + _n * 30.0)
	avatar.enter_suit(_scene.get_node("Outside"), pose0, Vector3.ZERO, ship.exterior)
	avatar.head.add_child(lamp)
	avatar.suit_cell.charge = 100.0
	avatar.suit_assist = false
	_cam.make_current()
	_lamp.visible = true
	_lamp.spot_range = 12.0
	for mode in ["pov", "side"]:
		var glinters := _glinters()
		var home: Array[Transform3D] = []
		for npc in glinters:
			home.append(npc.global_transform)
		# Calm and at home, the suit far off.
		avatar.global_position = _bed + _n * 40.0
		avatar.velocity = Vector3.ZERO
		for k in glinters.size():
			var npc := glinters[k]
			npc.switch_to(&"surface_crawler")
			npc.global_transform = home[k]
			npc.velocity = Vector3.ZERO
			npc.brain.needs[&"fear"] = 0.0
			npc.brain.current = null
			npc.intent = Intent.idle()
			npc.health.current = npc.health.max
			npc.look.call(&"act", &"shut")
		await _physics(150)
		# The Glinter nearest the middle of the nest is the one to watch.
		var star := glinters[0]
		for npc in glinters:
			if npc.global_position.distance_to(_bed) < star.global_position.distance_to(_bed):
				star = npc
		var up := star.global_basis.y.normalized()
		var across := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.BACK).normalized()
		avatar.health.current = avatar.health.max
		var start := star.global_position + up * 4.0 - across * 0.6
		avatar.global_transform = Transform3D(Basis.looking_at(-up, across), start)
		avatar.velocity = across * 0.5
		var mid := star.global_position + up * 1.6
		if mode == "side":
			var beside := across.cross(up).normalized()
			_cam.global_position = mid + beside * 2.8 + up * 0.3
			_cam.look_at(mid, up)
			_cam.fov = 45.0
		else:
			_cam.fov = 70.0
		var saved := 0
		var marks: Array[float] = [3.2, 2.2, 1.4, 0.7, 0.35]
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000 and saved < marks.size():
			await process_frame
			var eye := avatar.head.global_position
			var d := star.global_position.distance_to(avatar.global_position)
			var looking := star.look as GlinterLook
			var sprung := looking != null and (looking.action == &"leap" or looking.action == &"bite")
			if mode == "pov":
				_cam.global_position = eye
				_cam.look_at(star.global_position + up * 0.1, up)
			elif sprung:
				_cam.look_at(star.global_position + up * 0.1, up)
			if sprung and d <= marks[saved]:
				await RenderingServer.frame_post_draw
				saved += 1
				_save("spring_%s_%d" % [mode, saved])
				print("spring %s %d: Glinter %.2f m from the suit, action %s, eyes shown: %s" % [mode, saved, d, looking.action,
					looking.eyes.visible])
		print("spring %s: %d frames kept; suit health %.0f of %.0f" % [mode, saved, avatar.health.current, avatar.health.max])

# --- in daylight ------------------------------------------------------------------------

## A nest of the dev spawner's four Glinters and three real pieces of salvage on
## the sunlit side of the rock, shot with no lamp.
func _lit_set(ship: Ship, sun: DirectionalLight3D) -> void:
	_lamp.visible = false
	_cam.fov = 70.0
	var to_sun := sun.global_basis.z.normalized()
	# The ground that takes the sun at about 40 degrees up: lit, and shaped by it.
	var best := _home
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
	print("lit nest: ground facing the sun %.2f (1 straight at it)" % n.dot(to_sun))
	ship.exterior.global_position = spot + n * 60.0 + side * 40.0
	await _physics(180)
	var before := {}
	for npc in _all_glinters():
		before[npc] = true
	_cam.global_position = spot + n * 8.0 + side * 1.0
	_cam.look_at(spot, side)
	await _physics(3)
	print("spawn: %s" % _scene.spawn_creature(&"glinter"))
	await _physics(180)
	var fresh: Array[Npc] = []
	for npc in _all_glinters():
		if not before.has(npc):
			fresh.append(npc)
	if fresh.is_empty():
		print("lit nest: no Glinters came live")
		return
	_group = fresh[0].record.herd
	var centre := Vector3.ZERO
	for npc in fresh:
		centre += npc.global_position
	centre /= fresh.size()
	_home = _site.data.dir_of(_site.frame().affine_inverse() * centre)
	_bed = _site.frame() * _site.data.surface_point(_home)
	_n = (_site.frame().basis * RockHerds.surface_normal(_site.data, _home)).normalized()
	print("lit nest: %d Glinters live" % fresh.size())
	_place_salvage(fresh)
	await _physics(120)
	print("lit nest: %d salvage glints near" % _salvage_glints().size())
	_ground_report()
	# Close, about 3 m, with the sun behind the camera.
	_cam.fov = 55.0
	_place(2.8, EYE, -1.0, to_sun)
	await _physics(2)
	await _wait_beat(true)
	_save("lit_close")
	# One Glinter, shut, about 1 m, on the sun's side of it.
	var one := fresh[0]
	var one_up := one.global_basis.y.normalized()
	var toward := to_sun - one_up * to_sun.dot(one_up)
	toward = toward.normalized() if toward.length() > 0.2 else one_up.cross(Vector3.RIGHT).normalized()
	_cam.fov = 45.0
	_cam.global_position = one.global_position + toward * 1.0 + one_up * 0.45
	_cam.look_at(one.global_position + one_up * 0.12, one_up)
	await _physics(2)
	await _wait_beat(true)
	_save("lit_one")
	# From 40 m, as from a spacewalk: standing height (1.6 m) puts the nest past the
	# rock's horizon (about 30 m on a 284 m rock), so also from 6 m up.
	_cam.fov = 70.0
	_place(40.0, EYE, -1.0, to_sun)
	await _physics(2)
	await _wait_beat()
	_save("lit_40m_eye")
	_place(40.0, 6.0, -1.0, to_sun)
	await _physics(2)
	await _wait_beat()
	_save("lit_40m")
	_save_zoom("lit_40m_zoom", _cam.unproject_position(_bed))
	await _lit_sprung(fresh, to_sun)

## The picture round `centre` (pixels) blown up four times: what a small thing far off is.
func _save_zoom(name: String, centre: Vector2) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var w := 240
	var h := 135
	var x := clampi(int(centre.x) - w / 2, 0, image.get_width() - w)
	var y := clampi(int(centre.y) - h / 2, 0, image.get_height() - h)
	var crop := image.get_region(Rect2i(x, y, w, h))
	crop.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png("%s/glinter_%s.png" % [_out, name])
	print("render  %s/glinter_%s.png (nest at pixel %s)" % [_out, name, centre])

## Three real pieces of salvage on the nest's ground, as RockSite.place_nests
## builds entries: a ray down finds the rock, the piece lies at rest, its up the rock's.
func _place_salvage(glinters: Array[Npc]) -> void:
	var space := root.get_world_3d().direct_space_state
	var side := _n.cross(Vector3.UP if absf(_n.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := _n.cross(side).normalized()
	var taken: Array[Vector3] = []
	for npc in glinters:
		taken.append(npc.global_position)
	var entries: Array[Dictionary] = []
	for i in 3:
		var kind: StringName = SalvageField.MIX[i][0]
		var spot := _bed
		var spot_clear := -1.0
		for k in 24:
			var angle := TAU * float(k) / 24.0 + float(i) * 2.1
			var p := _bed + (side * cos(angle) + other * sin(angle)) * (1.5 + 0.25 * float(i))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + _n * 3.0, p - _n * 3.0, AsteroidBody.LAYER))
			if hit.is_empty():
				continue
			var at: Vector3 = hit["position"]
			var clear := INF
			for q in taken:
				clear = minf(clear, at.distance_to(q))
			if clear > spot_clear:
				spot_clear = clear
				spot = at
		taken.append(spot)
		var basis := Basis(Quaternion(Vector3.UP, _n)) * Basis(Vector3.UP, float(i) * 1.9)
		entries.append({"index": i, "kind": kind, "variety": 0.2 + 0.3 * float(i),
			"pose": Transform3D(basis, spot + _n * RockSite.LIFT - _bed)})
		print("salvage %d (%s) %.1f m from the nearest Glinter or piece" % [i, kind, spot_clear])
	_scene.salvage.add_placed_cloud(&"nest:dev:lit", _bed, entries)

func _all_glinters() -> Array[Npc]:
	var out: Array[Npc] = []
	for npc: Npc in _director.live.values():
		if npc.species.id == &"glinter":
			out.append(npc)
	return out

## A spacewalker drifts across the nest 4 m up, seen from the side about 6 m
## off, with the sun behind the camera: the spring, the bite, the rebound and the
## start of the puff home (rock creatures spec §4.3).
func _lit_sprung(glinters: Array[Npc], to_sun: Vector3) -> void:
	# (The earlier spring left the avatar on the outside: find it by its group.)
	var avatar := get_first_node_in_group(Avatar.GROUP) as Avatar
	if avatar.mode != Avatar.Mode.SUIT:
		avatar.enter_suit(_scene.get_node("Outside"), Transform3D(Basis.IDENTITY, _bed + _n * 40.0), Vector3.ZERO,
			(_scene.get_node("Ship") as Ship).exterior)
	_cam.make_current()
	avatar.suit_assist = false
	avatar.suit_cell.charge = 100.0
	var home: Array[Transform3D] = []
	for npc in glinters:
		home.append(npc.global_transform)
	avatar.global_position = _bed + _n * 40.0
	avatar.velocity = Vector3.ZERO
	for k in glinters.size():
		var npc := glinters[k]
		npc.switch_to(&"surface_crawler")
		npc.global_transform = home[k]
		npc.velocity = Vector3.ZERO
		npc.brain.needs[&"fear"] = 0.0
		npc.brain.current = null
		npc.intent = Intent.idle()
		npc.look.call(&"act", &"shut")
	await _physics(150)
	# The Glinter that will spring is the one nearest the nest's middle.
	var star := glinters[0]
	for npc in glinters:
		if npc.global_position.distance_to(_bed) < star.global_position.distance_to(_bed):
			star = npc
	var up := star.global_basis.y.normalized()
	var toward := to_sun - up * to_sun.dot(up)
	toward = toward.normalized() if toward.length() > 0.2 else up.cross(Vector3.RIGHT).normalized()
	var across := up.cross(toward).normalized()
	var ground := star.global_position
	_cam.fov = 38.0
	_cam.global_position = ground + up * 4.5 + toward * 4.0
	_cam.look_at(ground + up * 2.0, up)
	avatar.health.current = avatar.health.max
	avatar.global_transform = Transform3D(Basis.looking_at(-up, across), ground + up * 4.0 - across * 0.6)
	avatar.velocity = across * 0.5
	var looking := star.look as GlinterLook
	var kept := 0
	var t_bite := -1.0
	var t_puff := -1.0
	var t0 := Time.get_ticks_msec()
	var got := [false, false, false, false]
	while float(Time.get_ticks_msec() - t0) / 1000.0 < 8.0 and kept < 4:
		await process_frame
		var d := star.global_position.distance_to(avatar.global_position)
		var now := float(Time.get_ticks_msec() - t0) / 1000.0
		# The camera stays where it is and turns to keep the Glinter and the suit in view.
		_cam.look_at((star.global_position + avatar.global_position) * 0.5, up)
		var drift := star.active as ZeroGDrift
		if t_bite < 0.0 and avatar.health.current < avatar.health.max:
			t_bite = now
		if t_puff < 0.0 and t_bite >= 0.0 and looking.action == &"puff":
			t_puff = now
		var shoot := -1
		if not got[0] and (looking.action == &"leap" or looking.action == &"lunge") and d <= 3.0:
			shoot = 0
		elif not got[1] and t_bite >= 0.0 and now >= t_bite:
			shoot = 1
		elif not got[2] and t_bite >= 0.0 and now >= t_bite + 0.4:
			shoot = 2
		elif not got[3] and t_bite >= 0.0 and now >= t_bite + 1.6:
			shoot = 3
		if shoot >= 0:
			await RenderingServer.frame_post_draw
			got[shoot] = true
			kept += 1
			_save("lit_sprung_%d" % (shoot + 1))
			print("lit sprung %d at %.2f s: Glinter %.2f m from the suit, %s, action %s, %.1f m/s, still leaping %s" % [shoot + 1, now, d,
				star.active.id, looking.action, star.velocity.length(), "yes" if drift != null and drift.leaping() else "no"])
	print("lit sprung: %d of 4 frames kept; bite at %.2f s, first puff at %.2f s" % [kept, t_bite, t_puff])
