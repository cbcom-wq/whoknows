extends SceneTree

# Does a Glinter's leap work against a drifting spacewalker? (rock creatures spec
# §4.3, §16: "ZeroGDrift was built to land on rock, not a moving suit"; the plan's
# Task 10, Step 4.) Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/glinter_leap.gd [-- --trace] [-- --only-a]
#
# On the start rock a dev Glinter (F10's path) lies shut; a spacewalker drifts at
# DRIFT m/s, HEIGHT m over it, lamp on (a lit suit is seen at the species'
# whole sight, 6 m; an unlit one at half: part D). For each try it prints whether
# the Glinter sprang, how near its middle came to the suit (Npc.bite measures
# from its middle to the avatar's origin, at the feet), and whether a bite
# landed (Avatar.hurt). Parts:
#   A  TRIES single Glinters, the suit looking down at the nest (the way you
#      approach it to gather its salvage);
#   B  TRIES more, the suit at a random attitude (a tumbling spacewalker);
#   C  a group of four, GROUP_TRIES tries: how many of the leaps bite;
#   H  TRIES single Glinters, the suit holding station (assist on: it brakes to rest);
#   D  an unlit suit drifting toward a Glinter from 8 m: how near when it springs.
# The verdict line is the plan's: at least PASS of TRIES leaps end within bite
# reach and bite.

const TRIES := 20
const GROUP_TRIES := 10
const PASS := 15
const DRIFT := 0.5
const HEIGHT := 4.0
## A try's length once the suit is placed, seconds, and the calm between tries.
const TRY_FOR := 3.0
const SETTLE := 2.0

class Lamp extends SpotLight3D:
	var on := true
	func light_reach() -> float:
		return spot_range if on else 0.0
	func light_cone_deg() -> float:
		return spot_angle * 2.0
	func light_origin() -> Transform3D:
		return global_transform
	func light_kind() -> StringName:
		return &"lamp"

var _scene: Node
var _avatar: Avatar
var _director: NpcDirector
var _site: RockSite
var _lamp: Lamp
var _rng := RandomNumberGenerator.new()
var _bites := 0
var _trace := false

func _initialize() -> void:
	_scene = load("res://scenes/flight_test.tscn").instantiate()
	# Never the owner's saved game (saving spec §9): a windowed run would load and overwrite it.
	_scene.save_enabled = false
	root.add_child(_scene)
	_run.call_deferred()

func _physics(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	_rng.seed = 20261019
	_trace = OS.get_cmdline_user_args().has("--trace")
	await _physics(5)
	var ship: Ship = _scene.get_node("Ship")
	var stream: AsteroidStream = _scene.get_node("AsteroidStream")
	_director = _scene.exterior_npcs
	_avatar = _scene.get_node("Ship/Interior/Avatar")
	var detail := stream.details.nearest(ship.exterior.global_position)
	var first := detail.global_position + (ship.exterior.global_position - detail.global_position).normalized() \
		* (detail.rock.radius + 60.0)
	ship.exterior.global_position = first
	ship.exterior.freeze = true
	await _physics(30)
	_site = _scene.rock_life.site_for(detail.rock)
	var home := _site.data.dir_of(_site.frame().affine_inverse() * first)
	var spot := _site.frame() * _site.data.surface_point(home)
	var n := (_site.frame().basis * RockHerds.surface_normal(_site.data, home)).normalized()
	var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	# The hull waits well off, out of the way but near enough for the Glinters to wake.
	ship.exterior.global_position = spot + n * 60.0 + side * 40.0
	_avatar.enter_suit(_scene.get_node("Outside"), Transform3D(Basis.IDENTITY, spot + n * 30.0), Vector3.ZERO, ship.exterior)
	_avatar.hurt.connect(func(_amount: float, _from: Vector3) -> void: _bites += 1)
	_lamp = Lamp.new()
	_lamp.light_color = InteriorPalette.LIGHT_WARM
	_lamp.spot_range = 10.0
	_lamp.spot_angle = 30.0
	_lamp.visible = false
	_avatar.head.add_child(_lamp)
	_lamp.add_to_group(StimulusBus.LIGHTS)
	print("rock radius %.0f m; glinter bite reach %.2f m" % [detail.rock.radius, _director.catalog.get_def(&"glinter").bite_reach])

	var a := await _part("A single Glinter, drifting suit looking down", _apart(home, 0), 1, TRIES, false, true)
	if OS.get_cmdline_user_args().has("--only-a"):
		print("A: %d of %d tries sprang, %d ended within reach, %d bit" % [a[0], TRIES, a[1], a[2]])
		quit()
		return
	var b := await _part("B single Glinter, drifting suit at a random attitude", _apart(home, 1), 1, TRIES, true, true)
	var c := await _part("C group of four, drifting suit looking down", _apart(home, 2), 4, GROUP_TRIES, false, true)
	var h := await _part("H single Glinter, suit holding station (assist on) looking down", _apart(home, 3), 1, TRIES, false, false)
	await _unlit(_apart(home, 4))
	print("")
	print("A: %d of %d tries sprang, %d ended within reach, %d bit" % [a[0], TRIES, a[1], a[2]])
	print("B: %d of %d tries sprang, %d ended within reach, %d bit" % [b[0], TRIES, b[1], b[2]])
	print("C: %d leaps in %d tries, %d ended within reach, %d bit" % [c[0], GROUP_TRIES, c[1], c[2]])
	print("H: %d of %d tries sprang, %d ended within reach, %d bit" % [h[0], TRIES, h[1], h[2]])
	var verdict := "PASS" if a[2] >= PASS else "FAIL (fall back: lunge along the surface, ambush 3 m)"
	print("VERDICT (part A, at least %d of %d leap and bite): %s" % [PASS, TRIES, verdict])
	quit()

## Spawns `count` Glinters where the hull was, and runs `tries` tries with them.
## Returns [leaps, within reach, bites].
func _part(label: String, dir: Vector3, count: int, tries: int, tumble: bool, drift: bool) -> Array:
	print("")
	print("--- %s ---" % label)
	var dev: DevCreatures = _scene.dev_creatures[_director]
	var ids: Array[StringName] = []
	for i in count:
		ids.append(_scene._new_dev_id(dev, &"glinter"))
	for record in _site.add_group(&"glinter", dir, count, ids):
		dev.add(record, _site)
	await _physics(120)
	var homes := {}
	for id in ids:
		var npc: Npc = _director.live.get(id)
		if npc == null:
			print("a Glinter is not live: %s" % id)
			return [0, 0, 0]
		homes[id] = npc.global_transform
	var leaps := 0
	var reached := 0
	var bit := 0
	for t in tries:
		var r := await _try(ids, homes, tumble, drift, t)
		leaps += r[0]
		reached += r[1]
		bit += r[2]
	# Out of the way: they are gone from the live set when the part ends.
	for id in ids:
		var npc: Npc = _director.live.get(id)
		if npc != null:
			npc.take_damage(1000.0)
	await _physics(30)
	return [leaps, reached, bit]

## Part `k`'s ground: 12 m round the rock from the last, so none lies near another.
func _apart(home: Vector3, k: int) -> Vector3:
	return RockHerds.tilted(home, 12.0 * float(k) / maxf(_site.data.surface_point(home).length(), 1.0), 0.7)

## One try. Returns [leaps, leaps ending within bite reach, bites landed].
func _try(ids: Array[StringName], homes: Dictionary, tumble: bool, drift: bool, t: int) -> Array:
	# Calm and home, the suit far off.
	_avatar.global_position = (homes[ids[0]] as Transform3D).origin + (homes[ids[0]] as Transform3D).basis.y * 40.0
	_avatar.velocity = Vector3.ZERO
	_avatar.health.current = _avatar.health.max
	for id in ids:
		var npc: Npc = _director.live.get(id)
		if npc == null:
			continue
		npc.switch_to(&"surface_crawler")
		npc.global_transform = homes[id]
		npc.velocity = Vector3.ZERO
		npc.brain.needs[&"fear"] = 0.0
		npc.brain.current = null
		npc.intent = Intent.idle()
		npc.health.current = npc.health.max
		if npc.look != null:
			npc.look.call(&"act", &"shut")
	await _physics(int(SETTLE * 60.0))
	# The suit HEIGHT over the first Glinter, a little off to one side, drifting across.
	var base: Transform3D = homes[ids[0]]
	var up := base.basis.y.normalized()
	var across := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.BACK).normalized().rotated(up, _rng.randf() * TAU)
	var at := base.origin + up * HEIGHT + across * _rng.randf_range(-0.6, 0.6)
	var pose: Basis
	if tumble:
		pose = Basis(Quaternion(Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(),
			_rng.randf() * TAU))
	else:
		pose = Basis.looking_at(-up, across)
	_avatar.global_transform = Transform3D(pose, at)
	_avatar.velocity = across * DRIFT if drift else Vector3.ZERO
	_lamp.on = true
	_lamp.visible = true
	_avatar.suit_assist = not drift
	_avatar.suit_cell.charge = 100.0
	_bites = 0
	var sprang := {}
	var nearest := {}
	for f in int(TRY_FOR * 60.0):
		await physics_frame
		if _trace and t == 0 and f % 6 == 0 and f < 120:
			var g: Npc = _director.live.get(ids[0])
			print("  f%3d suit %s glinter %s (%.2f m) %s %s slides %d v %.1f layer %d mask %d" % [f, _avatar.global_position,
				g.global_position, g.global_position.distance_to(_avatar.global_position),
				g.brain.current.id if g.brain.current != null else "-", g.active.id, g.get_slide_collision_count(),
				g.velocity.length(), _avatar.collision_layer, g.collision_mask])
		for id in ids:
			var npc: Npc = _director.live.get(id)
			if npc == null or npc.look == null:
				continue
			var looking := npc.look as GlinterLook
			if looking != null and (looking.action == &"leap" or looking.action == &"bite") and not sprang.has(id):
				sprang[id] = f
			if sprang.has(id):
				var middle := npc.global_position + npc.global_basis.y * npc.species.height * 0.5
				nearest[id] = minf(float(nearest.get(id, INF)), middle.distance_to(_avatar.global_position))
	var reached := 0
	for id in sprang:
		if float(nearest[id]) <= (_director.catalog.get_def(&"glinter") as NpcSpecies).bite_reach:
			reached += 1
	var line := "try %2d: %d sprang" % [t + 1, sprang.size()]
	for id in sprang:
		line += ", glinter %s at %.2f s came within %.2f m" % [String(id).get_slice(":", 2), float(sprang[id]) / 60.0, float(nearest[id])]
	line += "; bites landed %d; suit drifted %.2f m/s" % [_bites, _avatar.velocity.length()]
	print(line)
	return [sprang.size(), reached, _bites]

## An unlit suit, upright, drifting toward a Glinter at 0.5 m/s from 8 m along
## the ground, its feet UNLIT_UP m up: how near when it springs (it sees the
## suit's head, and in the dark only at half its range).
const UNLIT_UP := 1.0

func _unlit(home: Vector3) -> void:
	print("")
	print("--- D unlit suit, upright, drifting toward one Glinter from 8 m, feet %.1f m up ---" % UNLIT_UP)
	var dev: DevCreatures = _scene.dev_creatures[_director]
	var id: StringName = _scene._new_dev_id(dev, &"glinter")
	var ids: Array[StringName] = [id]
	for record in _site.add_group(&"glinter", home, 1, ids):
		dev.add(record, _site)
	await _physics(120)
	var npc: Npc = _director.live.get(id)
	if npc == null:
		print("not live")
		return
	var base := npc.global_transform
	for k in 3:
		npc.switch_to(&"surface_crawler")
		npc.global_transform = base
		npc.velocity = Vector3.ZERO
		npc.brain.needs[&"fear"] = 0.0
		npc.brain.current = null
		npc.look.call(&"act", &"shut")
		_lamp.on = false
		_lamp.visible = false
		_avatar.suit_assist = false
		_avatar.suit_cell.charge = 100.0
		var up := base.basis.y.normalized()
		var across := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.BACK).normalized().rotated(up, k * 2.0)
		_avatar.global_position = base.origin + up * 40.0
		await _physics(120)
		_avatar.global_transform = Transform3D(Basis.looking_at(-across, up), base.origin + across * 8.0 + up * UNLIT_UP)
		_avatar.velocity = -across * DRIFT
		var feet := INF
		var head := INF
		for f in 60 * 20:
			await physics_frame
			var looking := npc.look as GlinterLook
			if looking != null and (looking.action == &"leap" or looking.action == &"bite"):
				feet = npc.global_position.distance_to(_avatar.global_position)
				head = npc.global_position.distance_to(_avatar.head.global_position)
				break
		print("unlit drift %d: sprang with the suit's feet %.2f m and its head %.2f m off the Glinter" % [k + 1, feet, head])
		_avatar.velocity = Vector3.ZERO
		_avatar.global_position = base.origin + up * 40.0
		await _physics(60)
