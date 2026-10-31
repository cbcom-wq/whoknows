extends SceneTree

# The duel probe (hostile ships spec §11, §12.2): two ships, each with a pilot,
# fight in real time in a patch of space clear of big rocks, until one is
# destroyed or CAP. Windowed, so it renders and measures the frame rate:
#
#   godot --path who-knows --resolution 1280x720 --script res://test/probes/duel_probe.gd -- <abs out dir> [only=<groups>] [count=<n>] [rep=<k>] [fast]
#
# Groups, in the order they run: renders, even (starter v starter at 0.5/0.5,
# x5, the first seated for the fps), skill (0.8 v 0.2, x5, the 0.8 on either
# ship by turns), style (BRAWLER v STAND-OFF and the reverse, x3 each), warden
# (the Warden v a starter, x2, seated), yours (your ship on its own pilot,
# seated), lost (seated aboard the ship that loses, to LostScreen.finished).
# `count` caps the repeats of each group (of each way round, for style), `rep`
# runs only that repeat; `fast` is for tuning: run it as
# `--headless --fixed-fps 60` and the same fights run as fast as the CPU goes,
# with no fps and no renders. Time in a fight is game time, physics ticks.
#
# You are always aboard ship A, the starter (/Ship): it is your ship, CREW; B
# is spawned HOSTILE. The patch is found off the belt: no big rock (nor its
# swarm) within CLEAR of the fight's middle. The thin sprinkle of small rocks
# lies everywhere in the field (AsteroidRecipe.SPRINKLE: rubble every ~270 m,
# a mid-size rock every ~1.5 km), so there is no patch with no rock at all
# within 5 km; dodging those is the pilot's job, and rock_contacts counts it.
# A ship whose cockpit is wrecked has no assist (Ship: assist_allowed), so its
# pilot cannot steer at all: its contacts are counted apart, as adrift.
#
# One line per fight:
#   duel <a> <skill> <style> vs <b> <skill> <style> · <s> · winner <x> · hits a <band>:<rate> ... b ... · qe <a>/<b> · switches <n> · rock_contacts <n> (<n> adrift)
# then `fps`, `lost ok`, `render` lines, and the pass table (spec §12.2).

const GAP := 3000.0
## The longest fight, s.
const CAP := 720.0
## No big rock, nor its swarm, within this of the fight's middle, m.
const CLEAR := 5000.0
## Held still this long after the ships are placed, s: the rocks load.
const SETTLE := 2.0
## A progress line this often in a fight, s.
const REPORT_EVERY := 60.0
## Hit rates are counted in bands BAND m wide, named by their middle; the
## range is the one when the bolt left.
const BAND := 200
const AXES: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0.7, 0.2, 0.7),
	Vector3(-0.6, 0.3, 0.75), Vector3(0.8, -0.3, -0.5)]
const GROUPS := ["renders", "even", "skill", "style", "warden", "yours", "lost"]
const STARTER := &"starter"
const WARDEN := &"warden"
const AUTO := ShipPilot.Style.AUTO
const STAND_OFF := ShipPilot.Style.STAND_OFF
const BRAWLER := ShipPilot.Style.BRAWLER
## The lost fight: your hull starts worn to this, so it is short and you lose.
const LOST_WORN := 0.8
## The render targets, m off your helm.
const NEAR := 400.0
const FAR := 1000.0
const VENTING := 300.0
const CHASE := 80.0

## One ship of a fight, as counted.
class Fighter:
	var ship: Ship
	var label := ""
	## kind -> band -> count
	var shots := {}
	var hits := {}
	var qe := 0
	var switches := 0
	var last_style := -1
	var styles: Array[String] = []
	var rocks := 0
	## Rock contacts with its assist off: nobody flying it.
	var adrift := 0
	var touches := 0
	## turret part -> s into the fight it was wrecked
	var lost := {}

	func losses() -> String:
		var times: Array = lost.values()
		times.sort()
		return "/".join(times.map(func(t: float) -> String: return "%.0f" % t)) if not times.is_empty() else "none"

	func count(table: Dictionary, kind: StringName, band: int) -> void:
		if not table.has(kind):
			table[kind] = {}
		table[kind][band] = int(table[kind].get(band, 0)) + 1

var _out := ""
var _fast := false
var _only: Array = []
var _count := 99
var _rep := -1
var _scene: Node
var _results: Array = []
var _fps_lines := {}
var _lost_line := ""
var _lost_at := -1.0
var _finished := false
var _reloaded := false
## Every light bolt of every fight, band -> [shots, hits].
var _light := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "user://duel_probe"
	for arg: String in args.slice(1):
		if arg == "fast":
			_fast = true
		elif arg.begins_with("only="):
			_only = Array(arg.substr(5).split(","))
		elif arg.begins_with("count="):
			_count = int(arg.substr(6))
		elif arg.begins_with("rep="):
			_rep = int(arg.substr(4))
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()

func _wants(group: String) -> bool:
	if _fast and group == "renders":
		return false
	return _only.is_empty() or _only.has(group)

func _run() -> void:
	print("probe   %s, %s" % ["fast (no fps, no renders)" if _fast else "real time", "groups %s" % (
		", ".join(_only) if not _only.is_empty() else "all")])
	if _wants("renders"):
		await _renders()
	for f: Dictionary in _fights():
		var rep := int(f.get("rep", f["k"]))
		if _wants(f["group"]) and rep < _count and (_rep < 0 or rep == _rep):
			await _duel(f)
	_table()
	quit(0)

## Every fight the pass marks need, in order.
func _fights() -> Array:
	var out := []
	for k in 5:
		out.append({"group": "even", "k": k, "b": STARTER, "skill": [0.5, 0.5], "style": [AUTO, AUTO],
			"seated": k == 0})
	for k in 5:
		out.append({"group": "skill", "k": k, "b": STARTER, "skill": [0.8, 0.2] if k % 2 == 0 else [0.2, 0.8],
			"style": [AUTO, AUTO]})
	for k in 3:
		out.append({"group": "style", "k": k, "b": STARTER, "skill": [0.5, 0.5], "style": [BRAWLER, STAND_OFF]})
	for k in 3:
		out.append({"group": "style", "k": k + 3, "rep": k, "b": STARTER, "skill": [0.5, 0.5],
			"style": [STAND_OFF, BRAWLER]})
	for k in 2:
		out.append({"group": "warden", "k": k, "b": WARDEN, "skill": [0.5, 0.5], "style": [AUTO, AUTO],
			"seated": true})
	out.append({"group": "yours", "k": 0, "b": STARTER, "skill": [PilotValues.YOUR_SKILL, 0.5],
		"style": [AUTO, AUTO], "seated": true, "yours": true})
	out.append({"group": "lost", "k": 0, "b": STARTER, "skill": [0.2, 0.8], "style": [AUTO, AUTO],
		"seated": true, "worn": LOST_WORN})
	return out

# --- the scene --------------------------------------------------------------------

func _make() -> Node:
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	scene.save_enabled = false
	scene.reload = func() -> void: _reloaded = true
	root.add_child(scene)
	_scene = scene
	return scene

func _drop() -> void:
	if _scene != null:
		_scene.queue_free()
		_scene = null
	await _frames(5)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## Game time, s: physics ticks, the same in real time and in `fast`.
static func _now() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)

func _wait(seconds: float) -> void:
	var end := _now() + seconds
	while _now() < end:
		await process_frame

## The middle of a fight: off the belt (or the open field) from the start, the
## first place with no big rock or its swarm within CLEAR. Null if none.
func _patch(scene: Node) -> UniversePoint:
	var recipe: AsteroidRecipe = scene._stream.recipe
	var here: UniversePoint = scene._universe.to_universe(scene._starter.exterior.global_position)
	var dirs: Array[Vector3] = []
	if recipe.shapes != null and not recipe.shapes.belts.is_empty():
		var n: Vector3 = recipe.shapes.belts[0].normal
		dirs.append_array([n, -n])
	dirs.append_array([Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK])
	for d: float in [8000.0, 12000.0, 16000.0, 24000.0, 32000.0, 48000.0]:
		for dir in dirs:
			var p := here.plus(dir.normalized() * d)
			if _clear_of_big(recipe, p):
				return p
	return null

static func _clear_of_big(recipe: AsteroidRecipe, p: UniversePoint) -> bool:
	var tier := AsteroidRecipe.Tier.GIANT
	var most := AsteroidRecipe.BOUND * AsteroidRecipe.D_MAX[tier] * AsteroidRecipe.STRETCH_MAX
	var reach := CLEAR + most * (1.0 + AsteroidRecipe.HALO_REACH * AsteroidRecipe.HALO_SCALE)
	var lo := AsteroidRecipe.cell_of(tier, p.plus(-Vector3.ONE * reach))
	var hi := AsteroidRecipe.cell_of(tier, p.plus(Vector3.ONE * reach))
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var cell := Vector3i(x, y, z)
				var corner := AsteroidRecipe.cell_corner(tier, cell)
				for rock in recipe.cell_rocks(tier, cell):
					var swarm := rock.radius * (1.0 + AsteroidRecipe.HALO_REACH * AsteroidRecipe.HALO_SCALE)
					if corner.plus(rock.local).minus(p).length() - swarm < CLEAR:
						return false
	return true

## The mid-size rocks within CLEAR of `p`: how many, and the nearest, m.
static func _mid_rocks(recipe: AsteroidRecipe, p: UniversePoint) -> Vector2:
	var tier := AsteroidRecipe.Tier.MID
	var lo := AsteroidRecipe.cell_of(tier, p.plus(-Vector3.ONE * CLEAR))
	var hi := AsteroidRecipe.cell_of(tier, p.plus(Vector3.ONE * CLEAR))
	var n := 0
	var nearest := INF
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var cell := Vector3i(x, y, z)
				var corner := AsteroidRecipe.cell_corner(tier, cell)
				for rock in recipe.cell_rocks(tier, cell):
					var d := corner.plus(rock.local).minus(p).length()
					if d < CLEAR:
						n += 1
						nearest = minf(nearest, d)
	return Vector2(n, nearest)

## Puts your ship, at rest, half the gap back from `middle` along `axis`,
## facing along it, as the debug hop does; returns where B goes, facing back.
func _place(scene: Node, a: Ship, middle: UniversePoint, axis: Vector3) -> Transform3D:
	var hull := a.exterior
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	var up := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	hull.global_transform = Transform3D(Basis.looking_at(axis, up),
		scene._universe.to_engine(middle.plus(-axis * GAP * 0.5)))
	scene._universe.check()
	scene.star_system.place_all()
	scene.star_system.whereabouts.look()
	scene._stream.update(0.0, true)
	return Transform3D(Basis.looking_at(-axis, up), scene._universe.to_engine(middle.plus(axis * GAP * 0.5)))

func _spawn(scene: Node, id: StringName, place: Transform3D, ship_name: String) -> Ship:
	var grid: ShipGrid = scene.library.grid(id)
	return scene.fleet.spawn(grid, place, true, ship_name, ShipBlueprint.from_grid(grid, scene.library.name_of(id)))

## Holds a ship where it is: no physics, no flying.
static func _hold(ship: Ship) -> void:
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.exterior.freeze = true
	ship.flight_computer.set_physics_process(false)

static func _wear(ship: Ship, share: float) -> void:
	for id in ShipDamage.SECTIONS:
		ship.damage.section_damage[id] = ship.damage.section_hp[id] * share
	ship._apply_view()

## No stick, keys or mouse of the window's take a seated ship back from its
## pilot while the probe runs (T15's takeback): its PilotControls stop.
static func _quiet_controls(ship: Ship) -> void:
	for n in ship.find_children("*", "", true, false):
		if n is PilotControls:
			n.set_process(false)
			n.set_process_input(false)
			n.set_process_unhandled_input(false)
			n.set_process_unhandled_key_input(false)

static func _lateral(ship: Ship) -> float:
	return float(ship.stats.thrust_budget[&"lateral"]) / maxf(ship.stats.total_mass_kg, 1.0)

static func _band(d: float) -> int:
	return maxi(BAND, roundi(d / BAND) * BAND)

## Untyped: a destroyed ship is freed, and a freed object passed to a typed
## parameter aborts the call.
static func _alive(ship) -> bool:
	return is_instance_valid(ship) and not ship.is_destroyed()

static func _dist(a, b) -> float:
	if not is_instance_valid(a) or not is_instance_valid(b) or a.exterior == null or b.exterior == null:
		return INF
	return a.exterior.global_position.distance_to(b.exterior.global_position)

## Each turret of `side` wrecked, the first time it is: when, s into the fight.
static func _turret_losses(side: Fighter, t: float) -> void:
	if not is_instance_valid(side.ship) or side.ship.damage == null:
		return
	for turret in side.ship.turrets:
		var part := ShipDamage.turret_part(turret.coord)
		if not side.lost.has(part) and side.ship.damage.component_stage(part) >= BlockDamage.Stage.WRECKED:
			side.lost[part] = t

# --- counting -----------------------------------------------------------------------

func _watch(side: Fighter, foe_of: Callable) -> void:
	var pool: BoltPool = _scene.bolt_pool
	for t in side.ship.turrets:
		t.fired.connect(func(kind: StringName) -> void:
			var band := _band(_dist(side.ship, foe_of.call()))
			side.count(side.shots, kind, band)
			side.qe += int(WeaponValues.spec(kind)["qe"])
			_tag(pool, side, kind, band, foe_of))
	side.ship.exterior.body_entered.connect(func(body: Node) -> void:
		if _is_rock(body):
			var flown := side.ship.flight_computer.assist_enabled
			if flown:
				side.rocks += 1
			else:
				side.adrift += 1
			print("  ROCK  %s hit %s (%s) at %.0f m/s, hull %.0f %%%s" % [side.label, body.name, body.get_class(),
				side.ship.exterior.linear_velocity.length(), side.ship.hull_whole() * 100.0,
				"" if flown else ", adrift (assist off)"])
		elif body is RigidBody3D and body.has_meta(&"ship"):
			side.touches += 1)

static func _is_rock(body: Node) -> bool:
	if body is AsteroidBody or body is AsteroidDetail:
		return true
	var c := body as CollisionObject3D
	return c != null and (c.collision_layer & (1 << 6)) != 0

## The bolt the turret just armed: told its band, and heard where it lands.
func _tag(pool: BoltPool, side: Fighter, kind: StringName, band: int, foe_of: Callable) -> void:
	var frame := Engine.get_physics_frames()
	for bolt in pool.flying():
		if bolt.source != side.ship or bolt.age > 0.03:
			continue
		if int(bolt.get_meta(&"duel_frame", -100)) >= frame - 5:
			continue
		bolt.set_meta(&"duel_frame", frame)
		bolt.set_meta(&"duel_band", band)
		bolt.set_meta(&"duel_kind", kind)
		bolt.set_meta(&"duel_side", side)
		bolt.set_meta(&"duel_foe", foe_of)
		if not bolt.has_meta(&"duel_heard"):
			bolt.set_meta(&"duel_heard", true)
			bolt.struck.connect(_on_struck.bind(bolt))
		return

func _on_struck(_point: Vector3, collider: Object, bolt: PhaserBolt) -> void:
	var side: Fighter = bolt.get_meta(&"duel_side", null)
	var foe_of: Callable = bolt.get_meta(&"duel_foe", Callable())
	if side == null or not foe_of.is_valid():
		return
	var foe = foe_of.call()
	if not is_instance_valid(foe) or not collider is Node:
		return
	var node := collider as Node
	if node == foe.exterior or foe.exterior.is_ancestor_of(node):
		side.count(side.hits, bolt.get_meta(&"duel_kind"), int(bolt.get_meta(&"duel_band")))

func _rates(side: Fighter, kind: StringName) -> String:
	var shots: Dictionary = side.shots.get(kind, {})
	var hits: Dictionary = side.hits.get(kind, {})
	var bands := shots.keys()
	bands.sort()
	var parts: Array[String] = []
	for band: int in bands:
		var s := int(shots[band])
		var h := int(hits.get(band, 0))
		parts.append("%d:%.0f%%(%d/%d)" % [band, 100.0 * h / maxf(s, 1.0), h, s])
	return " ".join(parts) if not parts.is_empty() else "-"

func _style_of(side: Fighter) -> void:
	var p := side.ship.ship_pilot
	if p.last_reading.is_empty():
		return
	if side.last_style >= 0 and p.style != side.last_style:
		side.switches += 1
	if p.style != side.last_style:
		side.styles.append(ShipPilot.style_name(p.style))
	side.last_style = p.style

# --- a fight --------------------------------------------------------------------------

func _duel(f: Dictionary) -> void:
	var scene := _make()
	await _frames(30)
	var group: String = f["group"]
	var k: int = f["k"]
	var a: Ship = scene.get_node("Ship")
	var seated: bool = f.get("seated", false) and not _fast
	if f.get("seated", false):
		scene.board_at_helm(a)
		_quiet_controls(a)
		await _frames(10)
	var middle := _patch(scene)
	if middle == null:
		print("duel    %s %d: NO CLEAR PATCH" % [group, k])
		await _drop()
		return
	var axis: Vector3 = AXES[k % AXES.size()].normalized()
	var b_place := _place(scene, a, middle, axis)
	var mids := _mid_rocks(scene._stream.recipe, middle)
	var b := _spawn(scene, f["b"], b_place, "Duel%s%d" % [group.capitalize(), k])
	if b == null:
		print("duel    %s %d: NO SHIP SPAWNED" % [group, k])
		await _drop()
		return
	b.side = Sides.HOSTILE
	if f.has("worn"):
		_wear(a, f["worn"])
	# Held still while the rocks there load.
	var end := _now() + SETTLE
	while _now() < end:
		for s in [a, b]:
			s.exterior.linear_velocity = Vector3.ZERO
			s.exterior.angular_velocity = Vector3.ZERO
		await process_frame
	var sa := Fighter.new()
	sa.ship = a
	sa.label = "a"
	var sb := Fighter.new()
	sb.ship = b
	sb.label = "b"
	_watch(sa, func() -> Ship: return b)
	_watch(sb, func() -> Ship: return a)
	var pa := a.ship_pilot
	var pb := b.ship_pilot
	pa.skill = f["skill"][0]
	pa.style_choice = f["style"][0]
	if f.get("yours", false):
		pa.fight_for_you()
	else:
		pa.engage(Weapons.ship_id(b))
	pb.skill = f["skill"][1]
	pb.style_choice = f["style"][1]
	pb.engage(Weapons.ship_id(a))
	# Each repeat flies its own jinks.
	pa._rng.seed = hash("%s%d a" % [group, k])
	pb._rng.seed = hash("%s%d b" % [group, k])
	var head := "duel %s %.1f %s vs %s %.1f %s" % [STARTER, pa.skill, ShipPilot.style_name(f["style"][0]),
		f["b"], pb.skill, ShipPilot.style_name(f["style"][1])]
	print("start   %s%s · %s %d · %d mid-size rocks within %.0f m, the nearest %.0f m · lateral %.1f/%.1f m/s²" % [head,
		" (yours)" if f.get("yours", false) else "", group, k, mids.x, CLEAR, mids.y, _lateral(a), _lateral(b)])
	_lost_at = -1.0
	_finished = false
	_reloaded = false
	if group == "lost":
		scene.lost.connect(func(_text: String) -> void: _lost_at = Time.get_ticks_msec() / 1000.0)
		scene.lost_screen.finished.connect(func() -> void: _finished = true)
	var t0 := _now()
	var real0 := Time.get_ticks_msec()
	var next_report := REPORT_EVERY
	var range_sum := 0.0
	var range_min := INF
	var samples := 0
	var frames := []
	var last_us := Time.get_ticks_usec()
	var shot_taken := false
	while true:
		await process_frame
		var t := _now() - t0
		if seated:
			var now_us := Time.get_ticks_usec()
			frames.append(now_us - last_us)
			last_us = now_us
		if not _alive(a) or not _alive(b) or t >= CAP:
			break
		var d := _dist(a, b)
		range_sum += d
		samples += 1
		range_min = minf(range_min, d)
		_style_of(sa)
		_style_of(sb)
		_turret_losses(sa, t)
		_turret_losses(sb, t)
		if seated and not shot_taken and t >= 60.0:
			shot_taken = true
			await _shot("duel_%s%d_helm_60s" % [group, k])
		if t >= next_report:
			next_report += REPORT_EVERY
			var rel := b.exterior.linear_velocity - a.exterior.linear_velocity
			var closing := -rel.dot((b.exterior.global_position - a.exterior.global_position) / maxf(d, 0.001))
			print("  %3.0f s  range %4.0f (closing %+4.0f m/s)  speed %3.0f/%3.0f  hull %3.0f/%3.0f %%  qe %4d/%4d  assist %s/%s  %s %s %.0f / %s %s %.0f" % [
				t, d, closing, a.exterior.linear_velocity.length(), b.exterior.linear_velocity.length(),
				a.hull_whole() * 100.0, b.hull_whole() * 100.0, a.quantum.store.amount, b.quantum.store.amount,
				"on" if a.flight_computer.assist_enabled else "OFF", "on" if b.flight_computer.assist_enabled else "OFF",
				ShipPilot.style_name(pa.style), pa.intent, float(pa.last_reading.get("preferred", 0.0)),
				ShipPilot.style_name(pb.style), pb.intent, float(pb.last_reading.get("preferred", 0.0))])
	var seconds := _now() - t0
	var winner := "none"
	if not _alive(a) and _alive(b):
		winner = "b"
	elif not _alive(b) and _alive(a):
		winner = "a"
	elif not _alive(a) and not _alive(b):
		winner = "both lost"
	var line := "%s · %.0f s · winner %s · hits a %s b %s · qe %d/%d · switches %d · rock_contacts %d (%d adrift)" % [head,
		seconds, winner, _rates(sa, WeaponValues.LIGHT), _rates(sb, WeaponValues.LIGHT), sa.qe, sb.qe,
		sa.switches + sb.switches, sa.rocks + sb.rocks, sa.adrift + sb.adrift]
	print(line)
	var heavy := _rates(sb, WeaponValues.HEAVY)
	print("  detail  %s %d · range mean %.0f, closest %.0f · hull a %.0f %% b %.0f %% · styles a %s, b %s · ship touches %d · turrets lost at a %s b %s · real %.0f s%s" % [
		group, k, range_sum / maxf(samples, 1.0),
		range_min, a.hull_whole() * 100.0 if is_instance_valid(a) else 0.0,
		b.hull_whole() * 100.0 if _alive(b) else 0.0, "→".join(sa.styles), "→".join(sb.styles),
		sa.touches + sb.touches, sa.losses(), sb.losses(), (Time.get_ticks_msec() - real0) / 1000.0, " · heavy b %s" % heavy if heavy != "-" else ""])
	for side in [sa, sb]:
		var shots: Dictionary = side.shots.get(WeaponValues.LIGHT, {})
		var hits: Dictionary = side.hits.get(WeaponValues.LIGHT, {})
		for band: int in shots:
			if not _light.has(band):
				_light[band] = [0, 0]
			_light[band][0] += int(shots[band])
			_light[band][1] += int(hits.get(band, 0))
	_results.append({"group": group, "k": k, "seconds": seconds, "winner": winner,
		"skill": f["skill"], "style": f["style"], "b": f["b"], "rocks": sa.rocks + sb.rocks, "adrift": sa.adrift + sb.adrift,
		"yours": f.get("yours", false)})
	if seated and not frames.is_empty():
		var fps := _fps_of(frames)
		_fps_lines["%s %d" % [group, k]] = fps
		print("fps     %s %d seated at the helm: %s" % [group, k, fps["text"]])
	if group == "lost":
		await _lost(a, winner)
	await _drop()

## {min, mean, text} from frame times, µs: min is the slowest whole second.
static func _fps_of(frames: Array) -> Dictionary:
	var total := 0
	var slow := 0
	var worst := 0
	var second := 0
	var in_second := 0
	var slowest_second := INF
	for us: int in frames:
		total += us
		worst = maxi(worst, us)
		if us > 1e6 / 120.0:
			slow += 1
		second += us
		in_second += 1
		if second >= 1000000:
			slowest_second = minf(slowest_second, in_second * 1e6 / second)
			second = 0
			in_second = 0
	var mean := frames.size() * 1e6 / maxf(total, 1.0)
	if slowest_second == INF:
		slowest_second = mean
	return {"min": slowest_second, "mean": mean, "text": "fps %.0f %.0f (min of each second, mean; worst frame %.0f; %.0f%% of %d frames under 120)" % [
		slowest_second, mean, 1e6 / maxf(worst, 1.0), 100.0 * slow / maxf(frames.size(), 1.0), frames.size()]}

## After the lost fight: frames of the screen, and its end.
func _lost(a: Ship, winner: String) -> void:
	if winner != "b" or _lost_at < 0.0:
		_lost_line = "lost MISSED: winner %s, SHIP LOST %s" % [winner, "shown" if _lost_at >= 0.0 else "never shown"]
		print(_lost_line)
		return
	if not _fast:
		for shot: Array in [[0.08, "lost_0.1s_white"], [0.8, "lost_0.8s_grey"], [1.4, "lost_1.4s_dark"],
				[2.4, "lost_2.4s_text"]]:
			while Time.get_ticks_msec() / 1000.0 - _lost_at < float(shot[0]):
				await process_frame
			await _shot(shot[1])
	var end := Time.get_ticks_msec() + 8000
	while not _finished and Time.get_ticks_msec() < end:
		await process_frame
	var took := Time.get_ticks_msec() / 1000.0 - _lost_at
	_lost_line = "lost ok · SHIP LOST, finished %.2f s after, the stubbed reload %s" % [took,
		"called" if _reloaded else "NOT CALLED"] if _finished else "lost MISSED: LostScreen never finished"
	print(_lost_line)

# --- renders ------------------------------------------------------------------------

func _shot(shot_name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var file := "%s/%s.png" % [_out, shot_name]
	image.save_png(file)
	print("render  %s" % file)
	return image

## A 4x blow-up of `image` round `at` (screen px), nearest-neighbour.
func _zoom(image: Image, at: Vector2, shot_name: String) -> void:
	var w := 200
	var h := 112
	var x := clampi(int(at.x) - w / 2, 0, image.get_width() - w)
	var y := clampi(int(at.y) - h / 2, 0, image.get_height() - h)
	var crop := image.get_region(Rect2i(x, y, w, h))
	crop.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
	var file := "%s/%s.png" % [_out, shot_name]
	crop.save_png(file)
	print("render  %s" % file)

## Where `of` shows on screen from your seat. The eye is in the interior,
## which never moves; the outside is drawn through the canopy, by a camera that
## holds the eye's pose out in the world. So: into that camera's frame, then
## out of the eye's.
func _screen(of: Ship) -> Vector2:
	var eye := root.get_viewport().get_camera_3d()
	var outside: Camera3D = _scene.aboard.canopy_camera if _scene.aboard != null else null
	if eye == null or outside == null:
		return Vector2(640, 360)
	var seen := eye.global_transform * (outside.global_transform.affine_inverse() * Weapons.point_of(of.exterior))
	var at := eye.unproject_position(seen)
	print("render  %s on screen at (%.0f, %.0f)" % [of.name, at.x, at.y])
	return at

## The same frame again with the HUD hidden: at range the contact marker sits
## right over the ship, and over any burst on it.
func _hud_off_shot(shot_name: String) -> Image:
	var layers: Array[CanvasLayer] = []
	for layer: CanvasLayer in _scene.find_children("*", "CanvasLayer", true, false):
		if layer.visible:
			layers.append(layer)
			layer.visible = false
	# The cockpit's own markers are drawn on the canopy, in the ship's SubViewport.
	var overlay: CanvasItem = _scene.aboard.canopy_overlay if _scene.aboard != null else null
	var shown := overlay != null and overlay.visible
	if shown:
		overlay.visible = false
	var image := await _shot(shot_name + "_nohud")
	for layer in layers:
		layer.visible = true
	if shown:
		overlay.visible = true
	return image

## A hull-local direction near the nose, in the helm's view, on which one of
## `ship`'s light turrets bears surely.
static func _in_view_and_bearing(ship: Ship) -> Vector3:
	var best := Vector3.FORWARD
	var best_angle := INF
	for pitch in range(-30, 21, 5):
		for yaw in range(-30, 31, 5):
			var dir := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)) * Vector3.FORWARD
			for t in ship.turrets:
				if t.kind == WeaponValues.LIGHT and ShipPilot._bears_round(t.sky, dir):
					var angle := dir.angle_to(Vector3.FORWARD)
					if angle < best_angle:
						best = dir
						best_angle = angle
	return best

## Waits until one of your bolts lands on `target`, then `frames` frames; false
## if none did in `limit` s.
func _until_hit(a: Ship, target: Ship, limit: float, frames: int) -> bool:
	var landed := [false]
	var pool: BoltPool = _scene.bolt_pool
	var hook := func(_p: Vector3, collider: Object) -> void:
		if collider == target.exterior:
			landed[0] = true
	var hooked: Array = []
	var end := _now() + limit
	while not landed[0] and _now() < end:
		for bolt in pool.flying():
			if bolt.source == a and not hooked.has(bolt):
				hooked.append(bolt)
				bolt.struck.connect(hook)
		await process_frame
	for bolt in hooked:
		if is_instance_valid(bolt) and bolt.struck.is_connected(hook):
			bolt.struck.disconnect(hook)
	if landed[0]:
		await _frames(frames)
	return landed[0]

func _renders() -> void:
	var scene := _make()
	await _frames(30)
	var a: Ship = scene.get_node("Ship")
	var middle := _patch(scene)
	if middle == null:
		print("render  NO CLEAR PATCH")
		await _drop()
		return
	var to_sun := Vector3.BACK
	for light: DirectionalLight3D in scene.find_children("*", "DirectionalLight3D", true, false):
		to_sun = light.global_basis.z
		break
	# You look away from the sun, at the target's lit side.
	var axis := -to_sun.normalized()
	_place(scene, a, middle, axis)
	scene.board_at_helm(a)
	_quiet_controls(a)
	await _frames(30)
	_hold(a)
	a.quantum.store.amount = a.quantum.store.capacity
	var dir_local := _in_view_and_bearing(a)
	var dir := a.exterior.global_basis * dir_local
	print("render  target %.0f° off the nose (pitch %.0f°, yaw %.0f°)" % [rad_to_deg(dir_local.angle_to(Vector3.FORWARD)),
		rad_to_deg(asin(dir_local.y)), rad_to_deg(atan2(-dir_local.x, -dir_local.z))])
	var me := a.exterior.global_position
	var b := _spawn(scene, STARTER, Transform3D(Basis.looking_at(-dir, Vector3.UP), me + dir * NEAR), "RenderFoe")
	b.side = Sides.HOSTILE
	await _frames(20)
	_hold(b)
	b.fire_control.set_orders(FireControl.Orders.HOLD)
	await _wait(SETTLE)
	a.fire_control.mark(Weapons.ship_id(b))
	a.fire_control.set_orders(FireControl.Orders.ENGAGE)
	# A burst on the foe's hull from your helm, at 400 m and at 1 km.
	for at: Array in [[NEAR, "hit_from_helm_400"], [FAR, "hit_from_helm_1000"]]:
		b.exterior.global_position = me + dir * float(at[0])
		await _frames(5)
		if await _until_hit(a, b, 20.0, 2):
			await _shot(at[1])
			_zoom(await _hud_off_shot(at[1]), _screen(b), at[1] + "_zoom4x")
		else:
			print("render  %s: NO HIT in 20 s" % at[1])
	a.fire_control.set_orders(FireControl.Orders.HOLD)
	await _wait(3.0)
	# The cabin during a heavy hit: a heavy bolt from the foe, and the frame
	# where the ceiling lights are lowest.
	await _shot("cabin_before_hit")
	await _heavy_hit(a, b, "cabin_heavy_hit")
	scene._director.stand_now()
	await _frames(20)
	var avatar: Avatar = scene._avatar
	avatar.rotate_y(PI)
	await _frames(20)
	await _shot("cabin_standing_before_hit")
	await _heavy_hit(a, b, "cabin_standing_heavy_hit")
	scene._director.sit_now(a.seat)
	await _frames(30)
	# The foe at 30 % HULL, venting and sparking, at 300 m.
	b.exterior.global_position = me + dir * VENTING
	_wear(b, 0.7)
	await _wait(2.5)
	await _shot("enemy_30pct")
	_zoom(await _hud_off_shot("enemy_30pct"), _screen(b), "enemy_30pct_zoom4x")
	for i in 2:
		await _wait(0.1)
		await _shot("enemy_30pct_%s" % ["b", "c"][i])
	# The core going up at 1 km, from your helm.
	b.exterior.global_position = me + dir * FAR
	_wear(b, 0.97)
	await _wait(1.0)
	await _blow(b, "")
	await _wait(3.0)
	# And from a chase view 80 m off, the sun behind it.
	var c := _spawn(scene, STARTER, Transform3D(Basis.looking_at(-dir, Vector3.UP), me + dir * FAR), "RenderFoe2")
	c.side = Sides.HOSTILE
	await _frames(20)
	_hold(c)
	_wear(c, 0.97)
	var cam := Camera3D.new()
	cam.far = 20000.0
	scene.fleet.outside.add_child(cam)
	cam.add_to_group(Universe.EXTERIOR_SPACE)
	var at_c := c.exterior.global_position
	var off := (to_sun.normalized() + Vector3(0, 0.35, 0) + to_sun.cross(Vector3.UP).normalized() * 0.5).normalized() * CHASE
	cam.global_transform = Transform3D(Basis.looking_at(-off, Vector3.UP), at_c + off)
	cam.current = true
	await _wait(1.0)
	await _shot("enemy_chase80_worn")
	await _blow(c, "_chase80")
	await _wait(2.0)
	print("render  done")
	await _drop()

## A heavy bolt at your hull from the foe's side; the frame where the cabin
## lights dip lowest is kept as `shot_name`.
func _heavy_hit(a: Ship, foe: Ship, shot_name: String) -> void:
	var pool: BoltPool = _scene.bolt_pool
	var at := a.exterior.global_position
	var from := foe.exterior.global_position + (at - foe.exterior.global_position).normalized() * 30.0
	var ex: Array[RID] = [foe.exterior.get_rid()]
	pool.fire(WeaponValues.HEAVY, from, (at - from).normalized(), Vector3.ZERO, foe, ex)
	var lowest := 1.0
	var best: Image = null
	var end := _now() + 5.0
	while _now() < end:
		await RenderingServer.frame_post_draw
		var factor := a.cabin_dip.factor()
		if factor < lowest - 0.001:
			lowest = factor
			best = root.get_viewport().get_texture().get_image()
	if best == null:
		print("render  %s: NO DIP" % shot_name)
		return
	var file := "%s/%s.png" % [_out, shot_name]
	best.save_png(file)
	print("render  %s  (the dip at %.2f of the lights)" % [file, lowest])

## The last hit on a worn `ship`; frames at 0.1 s, 0.4 s and 2 s after.
func _blow(ship: Ship, suffix: String) -> void:
	var t0 := Time.get_ticks_usec()
	for cell: Vector3i in ship.damage.sections_of:
		if ship.grid.has_block(cell):
			ship.take_damage_many({cell: 1e9})
			break
	print("render  destroyed %s, the blast frame's work %.1f ms" % [ship.is_destroyed(), (Time.get_ticks_usec() - t0) / 1000.0])
	for shot: Array in [[0.1, "core_0.1s"], [0.4, "core_0.4s"], [2.0, "breakup_2s"]]:
		while (Time.get_ticks_usec() - t0) / 1e6 < float(shot[0]):
			await process_frame
		await _shot(shot[1] + suffix)

# --- the pass table -------------------------------------------------------------------

func _table() -> void:
	print("")
	print("pass table (spec §12.2)")
	var even := _results.filter(func(r: Dictionary) -> bool: return r["group"] == "even")
	if not even.is_empty():
		var sum := 0.0
		var decided := 0
		for r in even:
			sum += float(r["seconds"])
			if r["winner"] != "none":
				decided += 1
		var mean := sum / even.size()
		print("  even 0.5/0.5 mean %.0f s (%.1f min) over %d, %d decided: %s (4-6 min)" % [mean, mean / 60.0,
			even.size(), decided, "PASS" if mean >= 240.0 and mean <= 360.0 else "MISS"])
		print("    each: %s" % ", ".join(even.map(func(r: Dictionary) -> String: return "%.0f s %s" % [r["seconds"], r["winner"]])))
	var skill := _results.filter(func(r: Dictionary) -> bool: return r["group"] == "skill")
	if not skill.is_empty():
		var wins := 0
		for r in skill:
			var ace := "a" if float(r["skill"][0]) > float(r["skill"][1]) else "b"
			if r["winner"] == ace:
				wins += 1
		print("  0.8 v 0.2: the 0.8 won %d of %d: %s (at least 4 of 5)" % [wins, skill.size(),
			"PASS" if wins >= 4 else "MISS"])
	var style := _results.filter(func(r: Dictionary) -> bool: return r["group"] == "style")
	if not style.is_empty():
		var brawls := 0
		var stands := 0
		for r in style:
			if r["winner"] == "a" or r["winner"] == "b":
				var won: int = r["style"][0] if r["winner"] == "a" else r["style"][1]
				if won == BRAWLER:
					brawls += 1
				else:
					stands += 1
		print("  styles: BRAWLER won %d, STAND-OFF won %d of %d: %s (neither wins every one of its six)" % [brawls,
			stands, style.size(), "PASS" if brawls < style.size() and stands < style.size() else "MISS"])
	var rocks := 0
	var adrift := 0
	for r in _results:
		rocks += int(r["rocks"])
		adrift += int(r["adrift"])
	print("  rock_contacts %d over %d fights: %s (and %d adrift, cockpit wrecked, nobody flying)" % [rocks,
		_results.size(), "PASS" if rocks == 0 else "MISS", adrift])
	for key: String in _fps_lines:
		var fps: Dictionary = _fps_lines[key]
		var floor_fps := 109.0 if key.begins_with("warden") else 120.0
		print("  seated fps %s: min %.0f mean %.0f: %s (mean at least %.0f)" % [key, fps["min"], fps["mean"],
			"PASS" if fps["mean"] >= floor_fps else "MISS", floor_fps])
	for band: int in [400, 1000]:
		if _light.has(band):
			var rate: float = 100.0 * _light[band][1] / maxf(_light[band][0], 1.0)
			var ok: bool = rate >= 70.0 if band == 400 else rate <= 40.0
			print("  light hit rate %d m band: %.0f %% (%d/%d): %s (%s)" % [band, rate, _light[band][1], _light[band][0],
				"PASS" if ok else "MISS", "at least 70 %" if band == 400 else "at most 40 %"])
	var bands := _light.keys()
	bands.sort()
	print("  light hit rate by band: %s" % " ".join(bands.map(func(band: int) -> String:
		return "%d:%.0f%%(%d/%d)" % [band, 100.0 * _light[band][1] / maxf(_light[band][0], 1.0), _light[band][1], _light[band][0]])))
	var yours := _results.filter(func(r: Dictionary) -> bool: return r["yours"])
	for r in yours:
		print("  your pilot: %.0f s, winner %s" % [r["seconds"], r["winner"]])
	if _lost_line != "":
		print("  %s" % _lost_line)
