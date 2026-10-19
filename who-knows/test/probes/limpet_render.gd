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
#
# Then three closer looks (the owner's render of a finished Limpet), each on
# a fresh dev group made with the scene's spawn_creature, F10's path:
#   limpet_sip.png    a spacewalker 2-3 m off a group that is sipping his suit
#                     (underside facets at the brightest shade); prints the
#                     suit cell's charge before and after 5 s.
#   limpet_base.png   a hub planted on the rock the way test_limpet_sip plants
#                     one, a group left to creep to it, shot from about 8 m.
#   limpet_husks.png  a Limpet that sipped 120 QE, killed, and its husks at 1.5 m.

const DISTANCES: Array[float] = [4.0, 40.0, 70.0, 100.0]
const EYE := 1.6
const FLOAT := 12.0

var _out := ""
var _cam: Camera3D

## The ground a base stands on, as far as Bases.plant asks (see test_limpet_sip).
class Ground extends PlantSurface:
	var id: StringName = &""
	func fixed() -> bool:
		return true
	func site_id() -> StringName:
		return id
	func rock() -> Vector4i:
		return Vector4i(1, 2, 3, 4)

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
	await _extras(scene, ship, site, detail, director, to_sun)
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

# --- the closer looks -------------------------------------------------------------

func _aim(from: Vector3, at: Vector3, up: Vector3) -> void:
	_cam.global_position = from
	_cam.look_at(at, up)

## The surface direction, 60 m or so from `home`, whose ground faces the sun most.
func _sunny_dir(site: RockSite, home: Vector3, sun: Vector3, metres: float) -> Vector3:
	var best := home
	var best_lit := -2.0
	for k in 12:
		var dir := _dir_at(site, home, metres, TAU * float(k) / 12.0)
		var up := (site.frame().basis * RockHerds.surface_normal(site.data, dir)).normalized()
		if up.dot(sun) > best_lit:
			best_lit = up.dot(sun)
			best = dir
	return best

## Makes a group of limpets on the ground under `dir`, by the scene's own F10 path
## (the crosshair on the rock), and returns the new live ones once they have settled.
func _spawn_group(scene: Node, site: RockSite, director: NpcDirector, ship: Ship, dir: Vector3, sun: Vector3) -> Array[Npc]:
	var spot := site.frame() * site.data.surface_point(dir)
	var n := (site.frame().basis * RockHerds.surface_normal(site.data, dir)).normalized()
	var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	# The hull waits above, in the limpets' wake radius, out of shot.
	ship.exterior.global_position = spot + n * 60.0 + side * 40.0
	await _physics(90)
	var before := {}
	for npc: Npc in director.live.values():
		before[npc] = true
	_aim(spot + n * 8.0 + side * 1.0, spot, side)
	await _physics(3)
	print("spawn: %s" % scene.spawn_creature(&"limpet"))
	await _physics(150)
	var fresh: Array[Npc] = []
	for npc: Npc in director.live.values():
		if npc.species.id == &"limpet" and not before.has(npc):
			fresh.append(npc)
	print("a fresh group of %d limpets" % fresh.size())
	return fresh

static func _centre(group: Array[Npc]) -> Vector3:
	var c := Vector3.ZERO
	for npc in group:
		c += npc.global_position
	return c / maxf(group.size(), 1)

func _extras(scene: Node, ship: Ship, site: RockSite, detail: AsteroidDetail, director: NpcDirector, sun: Vector3) -> void:
	var avatar: Avatar = scene.get_node("Ship/Interior/Avatar")
	var home := site.data.dir_of(site.frame().affine_inverse() * (ship.exterior.global_position))
	var rock_c := detail.global_position
	# --- 1. the sip -----------------------------------------------------------------
	var dir := _sunny_dir(site, home, sun, 60.0)
	var group := await _spawn_group(scene, site, director, ship, dir, sun)
	var c := _centre(group)
	var up := (c - rock_c).normalized()
	var toward := (sun - up * sun.dot(up)).normalized()
	if toward.length() < 0.5:
		toward = up.cross(Vector3.RIGHT).normalized()
	# The limpet nearest the middle is the one to stand by.
	var star: Npc = group[0]
	for npc in group:
		if npc.global_position.distance_to(c) < star.global_position.distance_to(c):
			star = npc
	var ground := star.global_position - up * 0.075
	var stand := ground + toward * 2.5
	var pose := Transform3D(Basis.looking_at(-up, Vector3.UP), stand + up * 1.0)
	avatar.enter_suit(scene.get_node("Outside"), pose, Vector3.ZERO, ship.exterior)
	avatar.suit_cell.charge = 100.0
	await _physics(3)
	avatar.global_position += (ground + toward * 2.5 + up * EYE) - avatar.camera.global_position
	avatar.velocity = Vector3.ZERO
	await _physics(240)
	var sipping := 0
	for npc in group:
		if npc.brain.current != null and npc.brain.current.id == &"sip":
			sipping += 1
	var eye := avatar.camera.global_position
	print("sip: avatar eye %.2f m up and %.2f m from the middle limpet; %d of %d sipping" % [
		(eye - ground).dot(up), eye.distance_to(star.global_position), sipping, group.size()])
	var charge_before := avatar.suit_cell.charge
	await _physics(300)
	print("sip: suit cell %.2f -> %.2f QE in 5 s (%.2f QE/s)" % [charge_before, avatar.suit_cell.charge,
		(charge_before - avatar.suit_cell.charge) / 5.0])
	eye = avatar.camera.global_position
	_aim(eye, star.global_position, up)
	print("sip: the middle limpet is %.0f px wide" % (_cam.unproject_position(star.global_position + _cam.global_basis.x * 0.15).distance_to(
		_cam.unproject_position(star.global_position - _cam.global_basis.x * 0.15))))
	await _shot("sip")
	# The same eye through a long lens on the nearest sipping limpet, and then
	# (not a spacewalker's view) a camera by the ground, to show the facets.
	var nearest: Npc = star
	for npc in group:
		if npc.brain.current != null and npc.brain.current.id == &"sip" and \
				npc.global_position.distance_to(eye) < nearest.global_position.distance_to(eye):
			nearest = npc
	var lit_facets := nearest.brain.current != null and nearest.brain.current.id == &"sip"
	print("sip: nearest limpet %.2f m off, sipping: %s" % [nearest.global_position.distance_to(eye), lit_facets])
	var looks := nearest.find_children("*", "LimpetLook", true, false)
	print("sip: look action %s (%d looks)" % [(looks[0] as LimpetLook).action if not looks.is_empty() else "none", looks.size()])
	_cam.fov = 22.0
	_aim(eye, nearest.global_position, up)
	await _shot("sip_close")
	_cam.fov = 50.0
	var low := nearest.global_position + toward * 0.8 + up * 0.04
	_aim(low, nearest.global_position + up * 0.03, up)
	await _shot("sip_low")
	_cam.fov = 70.0
	# --- 2. the base ----------------------------------------------------------------
	var bdir := _sunny_dir(site, dir, sun, 60.0)
	var spot := site.frame() * site.data.surface_point(bdir)
	var n := (site.frame().basis * RockHerds.surface_normal(site.data, bdir)).normalized()
	var x := n.cross(Vector3.RIGHT if absf(n.x) < 0.9 else Vector3.BACK).normalized()
	var basis := Basis(x, n, x.cross(n)).orthonormalized()
	var r := Planting.Result.new()
	r.fit = Planting.Fit.OK
	r.frame = Transform3D(basis, spot + n * 0.5 - basis * Vector3(2, 0, 1))
	r.legs = PackedFloat32Array([0.5, 0.5, 0.5, 0.5])
	var floor_ := Ground.new()
	floor_.id = site.id
	# A group a few metres from the hub's middle, along its long side.
	var base_dir := _dir_at(site, bdir, 6.0, 0.5)
	var bgroup := await _spawn_group(scene, site, director, ship, base_dir, sun)
	# The suit is far and the base awake: an anchor near keeps the rock live.
	avatar.global_position = spot + n * 25.0
	var base: Base = scene.bases.plant(ModuleCatalog.HUB, r, floor_)
	if base == null:
		print("base: could not plant")
	else:
		base.tick_unfold(HabitatValues.UNFOLD + 0.1)
		base.quantum.store.credit(150, &"probe")
		var mid := spot + n * 1.0
		await _physics(60 * 25)
		var near := 0
		var farthest := 0.0
		for npc in bgroup:
			var place: Variant = scene.bases.place_of(site.id, npc.global_position)
			if place != null:
				var d := (place as Vector3).distance_to(npc.global_position)
				farthest = maxf(farthest, d)
				if d < Bases.SIP_REACH:
					near += 1
		print("base: %d of %d limpets within %.0f m of a module after 25 s (farthest %.1f m); store %d" % [
			near, bgroup.size(), Bases.SIP_REACH, farthest, base.quantum.store.amount])
		var shot_c := (mid + _centre(bgroup)) * 0.5
		var look_side := (sun - n * sun.dot(n)).normalized()
		if look_side.length() < 0.5:
			look_side = x
		_cam.fov = 55.0
		_aim(shot_c + look_side * 7.0 + n * 3.5, shot_c, n)
		await _shot("base")
		_cam.fov = 70.0
	# --- 3. the husks ---------------------------------------------------------------
	var hdir := _sunny_dir(site, bdir, sun, 60.0)
	var hgroup := await _spawn_group(scene, site, director, ship, hdir, sun)
	var victim: Npc = hgroup[0]
	var hp := victim.global_position
	var hup := (hp - rock_c).normalized()
	victim.sipped = 120.0
	victim.take_damage(100.0)
	await _physics(30)
	var husks: Array[Item] = []
	for item: Item in get_nodes_in_group(Item.GROUP):
		if item.definition.id == &"limpet_husk" and item.global_position.distance_to(hp) < 2.0:
			husks.append(item)
	var hc := hp
	if not husks.is_empty():
		hc = Vector3.ZERO
		for item in husks:
			hc += item.global_position
		hc /= husks.size()
	print("husks: %d dropped, centred %.2f m from where it died" % [husks.size(), hc.distance_to(hp)])
	var hside := (sun - hup * sun.dot(hup))
	hside = hside.normalized() if hside.length() > 0.2 else hup.cross(Vector3.RIGHT).normalized()
	_aim(hc + hside * 1.2 + hup * 0.9, hc, hup)
	await _shot("husks")