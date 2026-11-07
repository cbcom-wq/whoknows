extends SceneTree

# A world played through in real time (docs/superpowers/specs/
# 2026-11-03-desert-world-design.md §5, §10; the phase 0 plan's Task 13), in
# the flight scene by the system's largest planet with air (the largest planet
# if none has any):
#
#   1. the starter 300 m over flat ground, assist on, hovers, in air with
#      fog on; seen from outside, its RCS does not puff the steady hold;
#   4. its airlock will not let you out while it flies: NOT LANDED;
#   2. tilted 15 deg at 130 m with the stick centred, it levels; and so does
#      the heaviest library ship, without overshooting;
#   3. it comes down at 2 m/s and lands, with no hard landing and no damage;
#      its landing legs (Task 15) stay up at 100 m (rendered from the chase
#      view), fold out under 40 m (rendered halfway) and are down before
#      touchdown, so it lands on its feet with its keel clear of the ground
#      (rendered from 25 m at eye height, and low under the belly); its
#      landing ramp comes down under the outer hatch (Task 14), rendered
#      halfway and down; the frame rate seated at its helm on the ground;
#   5. out of its airlock on foot (the hatch clear of the real ground) and
#      down the ramp on your feet, the frame rate standing beside it, 20 m
#      off, and a jump;
#   6. what you carried out, dropped, falls and rests;
#   7. a second starter, landed 30 m off: from its ramp's foot (the frame
#      rate there, the view up it), up the ramp on your feet, its hull panel
#      within reach, and in through its outer hatch -- never put there by hand;
#   8. from its helm, up off the ground to a hover at 300 m, the ramp
#      stowing at once and the legs folding up past 60 m;
#   9. the first starter on low power: F8 to its helm, and up again;
#  10. the planet's ring: with `ring` after the directory, a seed whose ringed
#      planet's ring begins inside its well is played on (step 0 and this step
#      only): the starter put by hand mid-annulus, a spacewalk there does not
#      fall and what you let go of does not drift; without it, above the air
#      top a spacewalk does not fall; and the head lamp at night, at eye
#      height.
#
# Every step prints what it measured and the key moments are rendered. Run it
# WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 \
#     --script res://test/probes/landing_play.gd -- <abs out dir> [ring]
#
# Saving is turned off before the scene enters the tree, so the owner's game
# is never touched. The pilot's stick and your feet go through the input
# actions, as fleet_play's do; ships are put in place by hand only to set a
# step up, never past the thing it tests.

const TIME_LIMIT := 600.0
const HOVER := 300.0
const LEVEL_AT := 130.0
const TILT := 15.0
## The descent runs at 10 m/s down to here (feet over the ground), then at SINK.
const SLOW_FROM := 30.0
const SINK := 2.0
const BESIDE := 6.0
const WALK_OUT := 20.0
const SIDE := 30.0
## The flat-ground search: the ground within this many metres of a spot.
const FLAT_REACH := 50.0
## Eye height over the ground for the renders on foot, m.
const EYE := 1.6
## The ring run's seeds, and how far past the air top it settles if the middle
## of the ring would be over the world, m.
const RING_SEEDS := 2000
const RING_CLEAR := 100.0

var _out := ""
var _fails := 0
var _scene: Node
var _fleet: Fleet
var _starter: Ship
var _director: CameraDirector
var _avatar: Avatar
var _universe: Universe
var _gravity: WorldGravity
var _stars: StarSystem
var _planet: SystemBody
var _surface: WorldSurface
## Where the play happens, a unit direction from the planet's centre (the
## floating origin never turns, so it outlives every shift), and the way the
## ships' noses point there.
var _spot := Vector3.UP
var _forward := Vector3.FORWARD
var _cam: Camera3D
var _gpu_ms := 0.0
var _cpu_ms := 0.0
## `ring` on the command line: the ring run, and the seed it plays on.
var _ring_run := false
var _ring_seed := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else "user://landing_play"
	DirAccess.make_dir_recursive_absolute(_out)
	_ring_run = args.size() > 1 and args[1] == "ring"
	if _ring_run:
		_ring_seed = _find_ring_seed()
		if _ring_seed == 0:
			print("FAILED 10 no ringed planet in seeds 1-%d" % RING_SEEDS)
			quit(1)
			return
	# The frame rate is measured as combat_probe does: uncapped.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_scene = load("res://scenes/flight_test.tscn").instantiate()
	_scene.save_enabled = false
	if _ring_run:
		# The scene reads a seed only from a save: set it before it is ready.
		(_scene.get_node("AsteroidStream") as AsteroidStream).seed = _ring_seed
	root.add_child(_scene)
	# A script error mid-run stops _run without quitting: never hang.
	create_timer(TIME_LIMIT).timeout.connect(func() -> void:
		_let_go()
		print("play    TIMED OUT")
		quit(1))
	_run.call_deferred()

# --- the run -----------------------------------------------------------------

func _run() -> void:
	await _frames(3)
	_fleet = _scene.get("fleet")
	_starter = _scene.get_node("Ship")
	_director = _scene.get_node("CameraDirector")
	_avatar = get_first_node_in_group(Avatar.GROUP)
	_universe = _scene.get_node("Universe")
	_gravity = _scene.get("world_gravity")
	_stars = _scene.get("star_system")
	# A lost ship goes back to the last save by reloading the current scene,
	# which is this probe's.
	_scene.set("reload", func() -> void: pass)
	print("gpu     %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	if not await _to_the_planet():
		print("play    no planet to play on")
		quit(1)
		return
	if _ring_run:
		await _ring()
		_let_go()
		print("play    %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
		quit(0 if _fails == 0 else 1)
		return
	await _hovers()
	await _refuses_while_flying()
	await _sit(_starter)
	await _levels()
	await _big_ship_levels()
	await _lands()
	await _out_on_foot()
	await _drops()
	var second := await _second_ship()
	if second != null:
		await _lifts_off(second)
	await _low_power_lift_off()
	await _ring()
	await _above_the_air()
	await _night_lamp()
	_let_go()
	print("play    %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)

## The planet `_pick_planet` chooses, 3 km off it by the debug hop, its ground
## drawn.
func _to_the_planet() -> bool:
	var system: SystemRecipe = _scene.get("system")
	_planet = _pick_planet(system)
	var r := _planet.recipe
	print("planet  %s (%s): radius %.1f km, %.2f m/s2, air %s to %.1f km over the radius, ring %s" % [_planet.name,
		_planet.id, _planet.radius / 1000.0, r.surface_gravity, WorldRecipe.Atmosphere.keys()[r.atmosphere],
		r.air_top() / 1000.0, "none" if _planet.ring == null else "%.0f-%.0f km" % [_planet.ring.inner / 1000.0, _planet.ring.outer / 1000.0]])
	if r.atmosphere == WorldRecipe.Atmosphere.NONE:
		print("        no planet in the system has air: the largest instead")
	_scene.set("hop_index", system.bodies.find(_planet) - 1)
	var hopped: bool = _scene.call("hop", 1)
	await _frames(2)
	var proxy := _stars.proxy(_planet.id)
	_surface = proxy.surface() if proxy != null else null
	_check(hopped and _surface != null, "0 the hop puts the starter 3 km off %s, its ground drawn" % _planet.name)
	return _surface != null

## The first seed in 1..RING_SEEDS with a ringed planet whose ring begins
## inside its well; 0 if none.
func _find_ring_seed() -> int:
	for s in range(1, RING_SEEDS + 1):
		if _ringed(SystemRecipe.from_seed(s)) != null:
			return s
	return 0

## The first planet whose ring begins inside its gravity well, or null.
static func _ringed(system: SystemRecipe) -> SystemBody:
	for p in system.planets():
		if p.ring != null and p.ring.inner < p.recipe.well_radius():
			return p
	return null

## The system's largest planet with air, or its largest if none has any (the
## ring run's: the ringed one).
func _pick_planet(system: SystemRecipe) -> SystemBody:
	if _ring_run:
		return _ringed(system)
	var largest: SystemBody = null
	var with_air: SystemBody = null
	for p in system.planets():
		if largest == null or p.radius > largest.radius:
			largest = p
		if p.recipe.atmosphere != WorldRecipe.Atmosphere.NONE and (with_air == null or p.radius > with_air.radius):
			with_air = p
	return with_air if with_air != null else largest

## Step 1, and the controller's check 1: a hover, and how it looks.
func _hovers() -> void:
	var under := _up(_starter.exterior.global_position)
	_spot = _flattest(under, FLAT_REACH)
	_forward = _tangents(_spot)[0]
	print("        flat ground %.0f m from under the hop: within %.0f m it rises or falls %.2f m" % [
		under.angle_to(_spot) * _planet.radius, FLAT_REACH, _spread(_spot, FLAT_REACH)])
	_place(_starter, _spot, HOVER, _forward)
	_starter.flight_computer.assist_enabled = true
	await _ground_built()
	await _seconds(3.0)
	var first := _alt(_starter)
	var lowest := first
	var highest := first
	for i in 50:
		await _seconds(0.1)
		lowest = minf(lowest, _alt(_starter))
		highest = maxf(highest, _alt(_starter))
	var drift := _alt(_starter) - first
	_check(absf(drift) < 2.0 and highest - lowest < 2.0,
		"1 assist on, stick centred, %.1f m over the ground: drift %.2f m in 5 s, range %.2f m (under 2)" % [
		first, drift, highest - lowest])
	var rcs := _starter.rcs_show
	var on := 0
	var most := 0.0
	for i in rcs.emitters.size():
		if rcs.emitters[i].emitting:
			on += 1
		most = maxf(most, rcs.firing[i])
	var fc := _starter.flight_computer
	var cores := _starter.quantum.cores
	var core := "no core" if cores.is_empty() else "the core's rings turn at %.2f rev/s (%s)" % [
		cores[0].ring_rate(), cores[0].state]
	# In a well the steady hold is not puffed (RcsShow.HOLD_SHOW, 0740abd); the
	# pilot's and the assist's changes are. Hands off the stick, only the hold
	# is commanded, so nothing puffs.
	_check(on == 0 and fc.commanded_force_local.y > 0.0, "1 hovering hands off, only the assist's steady hold commanded: it is not puffed, %d of %d RCS emitters puffing (most %.2f), commanded %.0f of %.0f kN up; %s" % [
		on, rcs.emitters.size(), most, fc.commanded_force_local.y / 1000.0, fc.thrust_budget[&"vertical"] / 1000.0, core])
	var air := _stars.whereabouts.air()
	if _planet.recipe.atmosphere != WorldRecipe.Atmosphere.NONE:
		_check(air > 0.0 and _env().fog_enabled,
			"1 at %.0f m on a world with air: air() %.3f (over 0), fog %s (on), density %s" % [
			_alt(_starter), air, "on" if _env().fog_enabled else "off", _env().fog_density])
	else:
		print("        at %.0f m: air() %.3f; %s has none, so no fog is asked of it" % [_alt(_starter), air, _planet.name])
	await _outside_shot("hover", _starter, Vector3(20.0, 2.0, -6.0))
	var legs := _starter.exterior_builder.legs()
	_check(legs != null and legs.legs.size() == 4 and legs.is_stowed() and _legs_off(legs),
		"1 at %.0f m its four landing legs are folded up, their colliders off" % _alt(_starter))

## Step 4, run from step 1's hover: the room panel refuses.
func _refuses_while_flying() -> void:
	var lock: Airlock = _starter.airlocks.values()[0]
	await _into_the_room(_starter, lock)
	var readout := lock.room.room_panel.readout_text().replace("\n", " / ")
	var prompt := lock.prompt(&"room")
	lock.room.room_panel.interact(_avatar)
	await _seconds(2.0)
	var held := lock.cycle.stage == AirlockCycle.Stage.IDLE and lock.cycle.outer_open == 0.0 and lock.cycle.pressurized()
	_check(readout.contains("NOT LANDED") and prompt == "Not landed" and held,
		"4 flying at %.0f m, in the airlock: the room panel reads '%s', prompts '%s'; pressed, it stays idle and shut" % [
		_alt(_starter), readout, prompt])
	await _shot("not_landed")

## Step 2: the levelling, on the starter.
func _levels() -> void:
	var axis := _tilt_axis(_spot)
	_place(_starter, _spot, LEVEL_AT, _forward, Basis(axis, deg_to_rad(TILT)))
	var series := PackedFloat32Array()
	var level_at := -1.0
	var lowest := INF
	for i in 51:
		var t := _signed_tilt(_starter, axis)
		lowest = minf(lowest, t)
		if i % 5 == 0:
			series.append(t)
		if level_at < 0.0 and absf(t) < 2.0:
			level_at = i * 0.1
		if i < 50:
			await _seconds(0.1)
	_check(level_at >= 0.0 and level_at <= 5.0 and absf(series[series.size() - 1]) < 2.0,
		"2 tilted %.0f deg at %.0f m, stick centred: under 2 deg after %.1f s (within 5); every 0.5 s %s; lowest %.2f deg" % [
		TILT, LEVEL_AT, level_at, _degrees(series), lowest])

## The controller's check 2: levelling settles on the heaviest library ship.
func _big_ship_levels() -> void:
	var library: ShipLibrary = _scene.get("library")
	var heaviest := &""
	var mass := 0.0
	var masses: Array[String] = []
	for id in library.ids():
		var m := ShipStats.compute(library.grid(id), _starter.catalog).total_mass_kg
		masses.append("%s %.0f t" % [id, m / 1000.0])
		if m > mass:
			mass = m
			heaviest = id
	var tangents := _tangents(_spot)
	var dir := (_spot + tangents[1] * (400.0 / _planet.radius)).normalized()
	var grid := library.grid(heaviest)
	var big := _fleet.spawn(grid, Transform3D(Basis.IDENTITY, _centre() + dir * (_ground_r(dir) + 600.0)),
		true, "", ShipBlueprint.from_grid(grid, library.name_of(heaviest)))
	if big == null:
		_check(false, "2b the heaviest library ship (%s) spawns" % heaviest)
		return
	big.flight_computer.assist_enabled = true
	var axis := _tilt_axis(dir)
	_place(big, dir, LEVEL_AT, _forward, Basis(axis, deg_to_rad(TILT)))
	var series := PackedFloat32Array([_signed_tilt(big, axis)])
	var lowest := INF
	for s in 8:
		for i in 10:
			await _seconds(0.1)
			lowest = minf(lowest, _signed_tilt(big, axis))
		series.append(_signed_tilt(big, axis))
	var last := series[series.size() - 1]
	_check(absf(last) < 2.0 and lowest > -3.0,
		"2b %s, the heaviest (%s), tilted %.0f deg at %.0f m, stick centred: each second %s; ends %.2f deg (under 2), lowest %.2f deg (not past -3)" % [
		library.name_of(heaviest), ", ".join(masses), TILT, LEVEL_AT, _degrees(series), last, lowest])
	_fleet.remove(big)
	await _frames(2)

## Step 3, and the controller's check 5: down at 2 m/s, landed, unhurt; then
## the frame rate seated on the ground.
func _lands() -> void:
	var landing := _starter.landing
	var hard: Array[float] = []
	landing.hard_landing.connect(func(speed: float) -> void: hard.append(speed))
	var damage := _block_damage(_starter)
	var hull := _starter.hull_whole()
	# The landing legs on the way down (Task 15): {up_at_100, began, down, halfway}.
	var legs := _starter.exterior_builder.legs()
	var seen := {"up_at_100": false, "shot_100": false, "began": -1.0, "down": -1.0, "halfway": false}
	var end := Time.get_ticks_msec() + 30000
	while _alt(_starter) > SLOW_FROM and Time.get_ticks_msec() < end:
		_hold_sink(_starter, 10.0)
		await physics_frame
		await _watch_legs(legs, seen)
	var sinks: Array[float] = []
	var touch := 0.0
	end = Time.get_ticks_msec() + 40000
	while landing.state == LandingMonitor.State.FLYING and Time.get_ticks_msec() < end:
		_hold_sink(_starter, SINK)
		touch = _sink(_starter)
		if _alt(_starter) < 10.0:
			sinks.append(touch)
		await physics_frame
		await _watch_legs(legs, seen)
	_stick_y(0.0)
	var touched := Time.get_ticks_msec()
	_check(bool(seen["up_at_100"]), "3 at 100 m on the way down its legs are still folded up (rendered from the chase view)")
	_check(float(seen["began"]) > 36.0 and float(seen["began"]) <= LandingLegs.DOWN_BELOW and float(seen["down"]) > 0.0,
		"3 its legs began to fold out at %.1f m (under %.0f) and were down, colliders on, at %.1f m: before touchdown" % [
		float(seen["began"]), LandingLegs.DOWN_BELOW, float(seen["down"])])
	var landed := await _until(func() -> bool: return landing.is_landed(), 10.0)
	var landed_at := Time.get_ticks_msec()
	var took := (landed_at - touched) / 1000.0
	var mean := 0.0
	for s in sinks:
		mean += s / maxf(sinks.size(), 1.0)
	_check(landed and absf(mean - SINK) < 0.3,
		"3 down at %.2f m/s over the last 10 m (%.2f at touchdown): LANDED %.1f s after touchdown (within 10), tilt %.1f deg, frozen %s" % [
		mean, touch, took, rad_to_deg(landing.tilt()), _starter.exterior.freeze])
	_check(hard.is_empty(), "3 no hard landing (%s)" % ("none said" if hard.is_empty() else "said at %s m/s" % str(hard)))
	var lock: Airlock = _starter.airlocks.values()[0]
	await _ramp_comes_down(lock, landed_at)
	await _frames(5)
	var damage_after := _block_damage(_starter)
	_check(damage_after == damage, "3 the blocks' damage %.1f hp before touchdown and %.1f after; HULL %.0f%% and %.0f%%" % [
		damage, damage_after, hull * 100.0, _starter.hull_whole() * 100.0])
	print("        its feet %.2f m over the ground; the outer hatch floor %.2f m over the ground under it" % [
		_alt(_starter), _hatch_floor_height(lock)])
	await _stands_on_its_legs(_starter)
	await _outside_shot("landed", _starter, Vector3(16.0, 3.0, 18.0))
	await _seconds(1.0)
	await _shot("seated_on_the_ground")
	await _seconds(1.0)
	print("fps     %.0f seated at the starter's helm, landed %s" % [await _fps(3.0), _ms()])

## Step 3 (Task 14): the landing ramp under `lock`'s outer hatch comes down
## once the hull is LANDED (`landed_at`, ms): rendered halfway down its swing,
## held there for the render; then down, its top edge at the sill, its tip on
## the real ground, its collider on; rendered from 25 m at eye height.
func _ramp_comes_down(lock: Airlock, landed_at: int) -> void:
	var ramp := lock.alcove.ramp
	if ramp == null:
		_check(false, "3 the starter's outer hatch has no landing ramp")
		return
	# Halfway down its swing, out of its slot: the middle of the swing.
	var middle := (LandingRamp.SLIDE_TIME + LandingRamp.SWING_TIME * 0.5) / LandingRamp.TRAVEL
	var halfway := await _until(func() -> bool: return ramp.progress() >= middle, 3.0)
	var held := Time.get_ticks_msec()
	ramp.set_process(false)
	var at := ramp.progress()
	await _ramp_shot("ramp_halfway", ramp, Vector3(7.5, 0.0, 6.5), Vector3(0.0, -ramp.sill_height * 0.45, 1.4))
	ramp.set_process(true)
	var frozen := Time.get_ticks_msec() - held
	_check(halfway and ramp.visible and ramp.collider.disabled,
		"3 its landing ramp on its way down, rendered %.0f%% of the way: seen, its collider off until it is down" % [at * 100.0])
	var down := await _until(func() -> bool: return ramp.is_down(), 3.0)
	var took := (Time.get_ticks_msec() - landed_at - frozen) / 1000.0
	var sill := lock.alcove.outer_hatch.global_position
	var gap := ramp.top_edge().distance_to(sill)
	var tip := _gravity.altitude_at(ramp.tip())
	var angle := rad_to_deg(ramp.angle)
	_check(down and ramp.visible and not ramp.collider.disabled and gap < 0.05 and absf(tip) < 0.15
		and angle >= 15.0 - 0.01 and angle <= 38.0 + 0.01,
		"3 its landing ramp is down %.2f s after LANDED (the travel is %.1f s; held %.2f s for the render): sill %.2f m over its feet, %.2f m long at %.1f deg (15..38), its top edge %.3f m from the sill (under 0.05), its tip %.2f m over the ground (within 0.15), collider on" % [
		took, LandingRamp.TRAVEL, frozen / 1000.0, ramp.sill_height, ramp.length, angle, gap, tip])
	await _ramp_shot("ramp_down", ramp, Vector3(-12.0, 0.0, 22.0), Vector3(0.0, -0.6, 0.5))
	print("        the landed starter and its ramp from %.0f m at eye height" % (
		_flat(_cam.global_position - ramp.global_position).length()))

## Every leg collider off.
static func _legs_off(legs: LandingLegs) -> bool:
	return legs.colliders.all(func(c: CollisionShape3D) -> bool: return c.disabled)

static func _legs_on(legs: LandingLegs) -> bool:
	return legs.colliders.all(func(c: CollisionShape3D) -> bool: return not c.disabled)

## Step 3 (Task 15), one tick of the descent: up at 100 m (rendered from the
## chase view), the altitude they began to fold out at and were down at, and
## halfway out (rendered, the legs held there for it).
func _watch_legs(legs: LandingLegs, seen: Dictionary) -> void:
	var alt := _alt(_starter)
	if not bool(seen["shot_100"]) and alt < 100.0:
		seen["shot_100"] = true
		seen["up_at_100"] = legs.is_stowed() and _legs_off(legs)
		_director.cycle_view()
		await _shot("legs_up_in_flight")
		print("        ★ the starter at %.0f m from the chase view, its legs folded up" % alt)
		_director.cycle_view()
	if float(seen["began"]) < 0.0 and not legs.is_stowed():
		seen["began"] = alt
	if not bool(seen["halfway"]) and legs.progress() >= 0.5:
		seen["halfway"] = true
		legs.set_process(false)
		# From the sun's side, 35 deg round from it, level with the hull's
		# middle and looking down past the belly, so the legs stand against
		# the sand, not the sky.
		var sunward := _sunward(_starter).rotated(Vector3.UP, deg_to_rad(35.0))
		await _hull_shot("legs_halfway", _starter, sunward * 15.0,
			Vector3(0.0, -_starter.stance_depth(), 0.0))
		print("        ★ its legs %.0f%% of the way out at %.0f m, folding out about the hinge, then the knee" % [
			legs.progress() * 100.0, alt])
		legs.set_process(true)
	if float(seen["down"]) < 0.0 and legs.is_down() and _legs_on(legs):
		seen["down"] = alt

## Step 3 (Task 15), landed: on its four feet, every foot on the ground, its
## keel strip clear of it, level; rendered from 25 m at eye height and low
## under the belly beside a foot.
func _stands_on_its_legs(ship: Ship) -> void:
	var legs := ship.exterior_builder.legs()
	var feet: Array[String] = []
	var on := true
	for foot in legs.feet():
		var h := _gravity.altitude_at(foot)
		feet.append("%.3f" % h)
		on = on and absf(h) < 0.1
	var hull := ship.exterior.global_transform
	var keel := INF
	for c: Vector3i in ship.grid.coords():
		if c.y == -1:
			for x: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					keel = minf(keel, _gravity.altitude_at(hull * (ShipGrid.cell_center(c) + Vector3(x, -1.0, z))))
	var dome := INF
	for t in ship.turrets:
		for mi: MeshInstance3D in t.find_children("*", "MeshInstance3D", true, false):
			var box := mi.get_aabb()
			for i in 8:
				dome = minf(dome, _gravity.altitude_at(mi.global_transform * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))))
	_check(legs.is_down() and _legs_on(legs) and on and keel >= 0.3,
		"3 it stands on its four legs: feet %s m over the ground (each within 0.1), its keel strip's lowest corner %.2f m over it (at least 0.3), tilt %.2f deg" % [
		", ".join(feet), keel, rad_to_deg(ship.landing.tilt())])
	print("        the belly turret's look reaches %.2f m over the ground (negative: into it)" % dome)
	await _ground_shot("legs_landed", ship, Vector3(17.0, 0.0, 18.0), EYE, Vector3(0.0, -1.5, 0.0))
	var up := _up(hull.origin)
	var off := _cam.global_position - hull.origin
	print("        ★ the landed starter on its legs from %.0f m at eye height" % (off - up * off.dot(up)).length())
	var plan_legs := legs.legs
	var fore_starboard: Dictionary = plan_legs[0]
	for leg in plan_legs:
		if int(leg["side"]) > 0 and int(leg["end"]) < 0:
			fore_starboard = leg
	# Inboard of the forward starboard foot and ahead of it, 0.55 m up,
	# looking aft under the starboard half of the belly: the near foot left
	# of the middle (starboard is on the left looking aft), the aft one beyond
	# it, the keel strip 0.4 m off the sand on the right, and the light past
	# the stern. The aim is a little outboard, so the key card does not
	# cover the near foot.
	var f: Vector3 = fore_starboard["foot"]
	await _ground_shot("legs_under_the_belly", ship, f + Vector3(-1.5, 0.0, -2.7), 0.55,
		Vector3(f.x + 1.5, -ship.stance_depth() + 1.4, f.z + 10.0))
	print("        ★ low under the belly, from beside the forward starboard foot, looking aft")

## The way to the sun, level, in `ship`'s hull axes (a unit vector, y 0).
func _sunward(ship: Ship) -> Vector3:
	var sun := _scene.get_node("DirectionalLight3D") as DirectionalLight3D
	var d := ship.exterior.global_basis.inverse() * sun.global_basis.z
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.RIGHT

## A camera outside at `offset` in `ship`'s hull axes from its hull, looking at
## `target` in them, for one render.
func _hull_shot(shot_name: String, ship: Ship, offset: Vector3, target: Vector3) -> void:
	var hull := ship.exterior.global_transform
	var at := hull * offset
	await _camera_shot(shot_name, Transform3D(Basis.looking_at(hull * target - at, _up(at)), at))

## A camera `height` m over the real ground at `flat` in `ship`'s hull axes
## (its y ignored), looking at `target` in them, for one render.
func _ground_shot(shot_name: String, ship: Ship, flat: Vector3, height: float, target: Vector3) -> void:
	var hull := ship.exterior.global_transform
	var at := hull * Vector3(flat.x, -ship.stance_depth(), flat.z)
	var up := _up(at)
	at += up * (height - _gravity.altitude_at(at))
	await _camera_shot(shot_name, Transform3D(Basis.looking_at(hull * target - at, up), at))

## Step 5, and the controller's check 4: out on foot with something in hand,
## the frame rate beside the ship, 20 m off, and a jump.
func _out_on_foot() -> void:
	_director.stand_now()
	await _frames(3)
	var crate := Item.new()
	crate.setup(_starter.item_catalog.get_def(&"crate"))
	_starter.items.add_child(crate)
	crate.global_position = _avatar.global_position + _avatar.global_basis * Vector3(0.0, 1.0, -0.6)
	crate.set_loose()
	var carrying := _avatar.grasp.take(crate)
	var lock: Airlock = _starter.airlocks.values()[0]
	await _into_the_room(_starter, lock)
	var why := lock.world_refusal()
	_check(why == "", "5 landed on the real ground, in the airlock: world_refusal() is '%s' (empty: the raised capsule clears the terrain), the panel reads '%s'" % [
		why, lock.room.room_panel.readout_text().replace("\n", " / ")])
	if not await _cycle_out("5", _starter, lock, Avatar.Mode.FIELD):
		return
	_check(carrying and _avatar.grasp.item == crate and crate.in_space, "5 the crate in hand came out with you")
	var hatch := func() -> Vector3: return lock.beacon()
	# Down the ramp on your feet: how long you were over it, how long off your
	# feet while there, and how far your feet ever were off its top.
	var ramp := lock.alcove.ramp
	var on := [0, 0, 0.0]
	var watch := func() -> void:
		if ramp == null:
			return
		var p := ramp.global_transform.affine_inverse() * _avatar.global_position
		if p.z > 0.3 and p.z < ramp.length * cos(ramp.angle) - 0.3 and absf(p.x) < LandingRamp.WIDTH * 0.5:
			on[0] += 1
			if not _avatar.is_on_floor():
				on[1] += 1
			on[2] = maxf(on[2], absf(p.y + p.z * tan(ramp.angle)))
	physics_frame.connect(watch)
	await _walk_away(hatch, BESIDE, 5.0)
	physics_frame.disconnect(watch)
	_check(ramp != null and on[0] > 10 and on[1] <= 3 and on[2] < 0.25,
		"5 walked down the landing ramp on your feet: %d ticks over it, %d of them off your feet (at most 3), your feet at most %.2f m off its top (under 0.25)" % [
		on[0], on[1], on[2]])
	_face(lock.beacon() - _avatar.global_position)
	await _seconds(1.0)
	var eye := (_avatar.camera.global_position - _avatar.global_position).dot(_avatar.up)
	if _planet.recipe.atmosphere != WorldRecipe.Atmosphere.NONE:
		var sky_top := _sky().sky_top_color
		_check(is_zero_approx(_stars.dust.density) and not sky_top.is_equal_approx(SpacePalette.SPACE_SKY_TOP),
			"5 on foot on the ground: air() %.3f, the dust's density %.3f (0), fog %s, the sky's top #%s (not space's #%s)" % [
			_stars.whereabouts.air(), _stars.dust.density, "on" if _env().fog_enabled else "off",
			sky_top.to_html(false), SpacePalette.SPACE_SKY_TOP.to_html(false)])
	await _shot("standing_beside")
	print("fps     %.0f standing beside the landed starter, %.0f m off its hatch, facing it, eye %.2f m %s" % [
		await _fps(3.0), _flat(_avatar.global_position - lock.beacon()).length(), eye, _ms()])
	_face(_avatar.global_position - lock.beacon())
	var t0 := Time.get_ticks_msec()
	var walked := await _walk_away(hatch, WALK_OUT, 10.0)
	var away := _flat(_avatar.global_position - lock.beacon()).length()
	_check(walked and _avatar.mode == Avatar.Mode.FIELD and _avatar.is_on_floor(),
		"5 walked %.1f m from the hatch on foot in %.1f s, standing" % [away, (Time.get_ticks_msec() - t0) / 1000.0])
	_face(lock.beacon() - _avatar.global_position)
	await _jump()

## Step 6: drop what you carried out.
func _drops() -> void:
	var crate := _avatar.grasp.item
	if crate == null:
		_check(false, "6 nothing in hand to drop")
		return
	var strays: StrayField = _scene.get("strays")
	var lock: Airlock = _starter.airlocks.values()[0]
	# Facing away from the ships, so it lies off the way to the next one.
	_face(_avatar.global_position - lock.beacon())
	await _frames(3)
	var before := strays.count()
	var high := _gravity.altitude_at(crate.global_position)
	await _press(KEY_G)
	var by_key := _avatar.grasp.item == null
	if not by_key:
		_avatar.grasp.drop()
	var t0 := Time.get_ticks_msec()
	var rested := await _until(func() -> bool: return crate.freeze, 3.0)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	var low := _gravity.altitude_at(crate.global_position)
	_check(rested and strays.count() == before + 1 and crate.get_parent() == strays,
		"6 dropped (%s): a stray, it fell %.2f m and rests frozen after %.1f s (within 3), its middle %.2f m over the ground" % [
		"G" if by_key else "G not taken, grasp.drop()", high - low, took, low])

## Step 7: a second starter landed 30 m off, and in through its airlock.
## Returns it, or null.
func _second_ship() -> Ship:
	var library: ShipLibrary = _scene.get("library")
	var grid := library.grid(ShipLibrary.STARTER)
	var second: Ship = null
	for side: float in [1.0, -1.0]:
		var hull := _starter.exterior.global_transform
		var dir := _up(hull.origin + hull.basis.x.normalized() * SIDE * side)
		var ship := _fleet.spawn(grid, Transform3D(Basis.IDENTITY, _centre() + dir * (_ground_r(dir) + 600.0)),
			true, "", ShipBlueprint.from_grid(grid, library.name_of(ShipLibrary.STARTER)))
		ship.flight_computer.assist_enabled = true
		_place(ship, dir, 2.0, -hull.basis.z)
		await _seconds(0.5)
		# Under 40 m its legs fold out: it sets down on them.
		await _until(func() -> bool: return ship.exterior_builder.legs().is_down(), 2.5)
		ship.flight_computer.set_pilot_input(Vector3(0.0, -0.15, 0.0), Vector3.ZERO, false)
		await _until(func() -> bool: return ship.landing.state != LandingMonitor.State.FLYING, 6.0)
		ship.flight_computer.set_pilot_input(Vector3.ZERO, Vector3.ZERO, false)
		if await _until(func() -> bool: return ship.landing.is_landed(), 8.0):
			second = ship
			break
		print("        the spot %s of the starter would not take a landing (tilt %.1f deg); the other side" % [
			"starboard" if side > 0.0 else "port", rad_to_deg(ship.landing.tilt())])
		_fleet.remove(ship)
		await _frames(2)
	if second == null:
		_check(false, "7 a second starter lands 30 m off")
		return null
	var apart := second.exterior.global_position.distance_to(_starter.exterior.global_position)
	var lock: Airlock = second.airlocks.values()[0]
	print("        %s landed %.1f m from the starter, tilt %.1f deg; its hatch floor %.2f m over the ground under it" % [
		second.name, apart, rad_to_deg(second.landing.tilt()), _hatch_floor_height(lock)])
	# Its outer hatch is 2.45 m over the ground on its legs, over twice a jump:
	# the landing ramp (Task 14) is the only way up, walked on your feet.
	var ramp := lock.alcove.ramp
	if ramp == null:
		_check(false, "7 %s's outer hatch has no landing ramp: there is no way up to it" % second.name)
		return null
	var down := await _until(func() -> bool: return ramp.is_down(), 4.0)
	_check(down and ramp.visible and not ramp.collider.disabled,
		"7 its landing ramp is down: %.2f m long at %.1f deg, collider on" % [ramp.length, rad_to_deg(ramp.angle)])
	# Out from the hatch along the ground.
	var out := func() -> Vector3: return _flat(ramp.global_basis.z).normalized()
	var foot := func() -> Vector3: return ramp.tip() + (out.call() as Vector3) * 1.0
	var t0 := Time.get_ticks_msec()
	# Round onto its centre line well out, then in to 1 m past its foot.
	var lined_up := await _walk_to(func() -> Vector3: return ramp.tip() + (out.call() as Vector3) * 6.0, 0.4, 30.0)
	var there := false
	if lined_up:
		there = await _walk_to(foot, 0.25, 10.0)
	var off_line: float = (ramp.global_transform.affine_inverse() * _avatar.global_position).x
	_check(there, "7 walked to 1 m past the foot of %s's ramp in %.1f s, %.2f m off its centre line" % [
		second.name, (Time.get_ticks_msec() - t0) / 1000.0, off_line])
	_face(-(out.call() as Vector3))
	_avatar.set_head_pitch(0.0)
	await _seconds(1.0)
	await _shot("up_the_ramp")
	var fps := await _fps(3.0)
	var eye := (_avatar.camera.global_position - _avatar.global_position).dot(_avatar.up)
	_check(fps >= 120.0, "7 fps %.0f at the foot of the ramp looking up it, eye %.2f m (at least 120) %s" % [fps, eye, _ms()])
	# Up the ramp on your feet to the shut hatch.
	var front := func() -> Vector3: return lock.alcove.outer_hatch.global_position + (out.call() as Vector3) * 0.45
	t0 = Time.get_ticks_msec()
	var up_it := await _walk_to(front, 0.2, 10.0)
	var under := _below_hatch_floor(lock)
	_check(up_it and _avatar.mode == Avatar.Mode.FIELD and _avatar.is_on_floor() and absf(under) < 0.5,
		"7 walked up the ramp on your feet in %.1f s to its shut outer hatch: feet %.2f m under the sill (within 0.5), standing %s" % [
		(Time.get_ticks_msec() - t0) / 1000.0, under, _avatar.is_on_floor()])
	# Its hull panel, as you would: look at it and press F.
	var panel := lock.alcove.hull_panel
	var to_panel := panel.global_position - _avatar.camera.global_position
	_face(to_panel)
	_avatar.set_head_pitch(atan2(to_panel.dot(_avatar.up), _flat(to_panel).length()))
	var seen := await _until(func() -> bool: return _avatar.interactor.current() == panel, 1.0)
	var reach := _avatar.camera.global_position.distance_to(panel.global_position)
	_check(seen and reach <= 2.5, "7 its hull panel %.2f m from your eye (the reach is 2.5), in your sights: '%s'" % [
		reach, panel.prompt_text() if seen else "not seen"])
	if seen:
		await _press(KEY_F)
	else:
		panel.interact(_avatar)
	var opened := await _until(func() -> bool: return lock.cycle.outer_open >= 1.0, 12.0)
	_check(opened, "7 %s: the room empties and the outer hatch opens" % ("F on its hull panel" if seen else "its hull panel (F not taken)"))
	# In on your feet, W held: no jump, never put in the doorway by hand.
	_face(-(out.call() as Vector3))
	_avatar.set_head_pitch(0.0)
	Input.action_press(&"move_forward")
	# Your feet under its floor on your last tick outside, and whether you stood.
	var last := [0.0, false]
	var inside := await _until(func() -> bool:
		if _avatar.mode == Avatar.Mode.FIELD:
			last[0] = _below_hatch_floor(lock)
			last[1] = _avatar.is_on_floor()
		return _avatar.mode == Avatar.Mode.PLATING, 4.0)
	Input.action_release(&"move_forward")
	_check(inside and bool(last[1]),
		"7 walked in off the ramp through its outer hatch on your feet (on your last tick outside: feet %.2f m under its floor, standing %s)" % [
		float(last[0]), last[1]])
	if not inside:
		return null
	# Off the sill and into the room on your feet: the hatch shuts on no one.
	var depth := func() -> float:
		return (lock.room.outer_frame.affine_inverse() * _avatar.position).z
	var room_depth: float = (lock.room.outer_frame.affine_inverse() * lock.room.room_frame.origin).z
	await _frames(2)
	# Aboard, "in" is the interior's: the room's outer frame looks out along -z.
	_face(second.interior.global_basis * (lock.room.outer_frame.basis * Vector3(0.0, 0.0, 1.0)))
	_avatar.set_head_pitch(0.0)
	Input.action_press(&"move_forward")
	var in_room := await _until(func() -> bool: return float(depth.call()) >= room_depth, 3.0)
	Input.action_release(&"move_forward")
	_check(in_room, "7 walked off the sill into its airlock room (%.2f m in, the room's middle %.2f m)" % [
		float(depth.call()), room_depth])
	await _seconds(1.5)
	await _shot("in_the_second_airlock")
	var aboard: Ship = _scene.get("aboard")
	_check(aboard == second and second.own and not _starter.own and _avatar.get_parent() == second.interior,
		"7 in its airlock: aboard %s (%s), its hull your own %s, the starter's %s, standing in %s" % [
		second.name, aboard.name if aboard != null else "none", second.own, _starter.own,
		_avatar.get_parent().get_parent().name if _avatar.get_parent() != null else "nothing"])
	lock.room.room_panel.interact(_avatar)
	var cycled := await _until(func() -> bool: return lock.cycle.inner_open >= 1.0, 12.0)
	_check(cycled, "7 its room panel cycles it in: the inner hatch opens on air (inner %.2f, outer %.2f, panel '%s')" % [
		lock.cycle.inner_open, lock.cycle.outer_open, lock.room.room_panel.readout_text().replace("\n", " / ")])
	return second

## Step 8: from its helm, translate up off the ground to a 300 m hover; its
## landing ramp stows at once, its collider off the tick it leaves LANDED.
func _lifts_off(ship: Ship) -> void:
	await _sit(ship)
	_check(_director.seat_ship() == ship, "8 at %s's helm" % ship.name)
	var ramp := (ship.airlocks.values()[0] as Airlock).alcove.ramp
	var legs := ship.exterior_builder.legs()
	# ms it left LANDED, ms it was hidden, its collider off the tick after; the
	# altitude its legs began to fold up at, and their colliders off then.
	var seen := [-1, -1, false, -1.0, false]
	var watch := func() -> void:
		if float(seen[3]) < 0.0 and legs != null and not legs.is_down():
			seen[3] = _alt(ship)
			seen[4] = _legs_off(legs)
		if ramp == null:
			return
		if int(seen[0]) < 0 and not ship.landing.is_landed():
			seen[0] = Time.get_ticks_msec()
			seen[2] = ramp.collider.disabled
		if int(seen[0]) >= 0 and int(seen[1]) < 0 and not ramp.visible:
			seen[1] = Time.get_ticks_msec()
	physics_frame.connect(watch)
	var r := await _climb(ship, func() -> float: return _alt(ship), HOVER, 45.0)
	physics_frame.disconnect(watch)
	_say_climb("8", ship, r)
	_check(float(seen[3]) >= LandingLegs.UP_ABOVE and float(seen[3]) < LandingLegs.UP_ABOVE + 8.0 and bool(seen[4])
		and legs.is_stowed(),
		"8 its legs began to fold up at %.1f m (past %.0f), their colliders off then; folded up at the hover" % [
		float(seen[3]), LandingLegs.UP_ABOVE])
	var hid := (int(seen[1]) - int(seen[0])) / 1000.0
	_check(ramp != null and bool(seen[2]) and int(seen[1]) >= 0 and hid <= 2.0 and ramp.is_stowed()
		and ramp.collider.disabled,
		"8 its landing ramp stows as it lifts off: the collider off the tick it left LANDED (%s), hidden %.2f s later (within 2), stowed %s" % [
		seen[2], hid, ramp != null and ramp.is_stowed()])

## Step 9: the first starter on low power, F8 to its helm, and up again.
func _low_power_lift_off() -> void:
	var store := _starter.quantum.store
	store.drain(store.amount - int(store.capacity * 0.05), &"probe")
	_check(store.is_low_power(), "9 the starter's store at %d of %d QE: low power (under %d%%)" % [
		store.amount, store.capacity, roundi(QuantumStore.LOW_POWER_FRACTION * 100.0)])
	await _press(KEY_F8)
	var by_key := await _until(func() -> bool: return _director.is_seated and _director.seat_ship() == _starter, 2.0)
	if not by_key:
		_scene.call("board_nearest")
		await _frames(3)
	_check(_director.seat_ship() == _starter and _scene.get("aboard") == _starter and _starter.landing.is_landed(),
		"9 F8%s: at the landed starter's helm" % ("" if by_key else " (key not taken; board_nearest())"))
	var low := [true]
	var r := await _climb(_starter, func() -> float:
		low[0] = low[0] and store.is_low_power()
		return _alt(_starter), HOVER, 60.0)
	_say_climb("9", _starter, r)
	_check(low[0], "9 low power the whole climb (store %d QE)" % store.amount)
	store.credit(store.capacity, &"probe")

## Step 10: the planet's ring. Without `ring` there is none to go to (the
## default seed has no ringed planet whose ring is in its well); with it, the
## starter is put mid-annulus and you walk out into the ring.
func _ring() -> void:
	if not _ring_run:
		print("SKIPPED 10 %s has no ring in its well on this seed: run with `ring` after the directory for the spacewalk in one" % _planet.name)
		return
	var ring := _planet.ring
	var well := _planet.recipe.well_radius()
	var air_top := _planet.recipe.air_top()
	var normal := ring.normal
	var dir := normal.cross(Vector3.RIGHT)
	if dir.length() < 0.01:
		dir = normal.cross(Vector3.UP)
	dir = dir.normalized()
	var mid := (ring.inner + minf(ring.outer, well)) * 0.5
	var floor_r := _planet.radius + air_top + RING_CLEAR
	var moved := ""
	if mid < floor_r:
		moved = "; the middle is inside the air top + %.0f m, so moved out to %.0f m from the centre" % [RING_CLEAR, floor_r]
		mid = floor_r
	print("ring    seed %d, %s (%s): ring %.0f-%.0f km from its centre, well %.0f km, radius %.1f km, air top %.1f km; the starter %.0f km out in the ring's plane%s" % [
		_ring_seed, _planet.name, _planet.id, ring.inner / 1000.0, ring.outer / 1000.0, well / 1000.0, _planet.radius / 1000.0,
		air_top / 1000.0, mid / 1000.0, moved])
	_spot = dir
	_forward = _tangents(dir)[0]
	_starter.exterior.global_transform = Transform3D(_level(dir, _forward), _centre() + dir * mid)
	_starter.exterior.linear_velocity = Vector3.ZERO
	_starter.exterior.angular_velocity = Vector3.ZERO
	_moved()
	_starter.flight_computer.assist_enabled = true
	await _seconds(3.0)
	var w := _stars.whereabouts
	var env := _env()
	_check(not _starter.on_world() and is_zero_approx(w.air()) and not env.fog_enabled and _stars.dust.density > 0.0,
		"10 hovering in the ring, assist on: on a world %s (no), air() %.3f (0), fog %s (off), the dust's density %.3f (over 0)" % [
		_starter.on_world(), w.air(), "on" if env.fog_enabled else "off", _stars.dust.density])
	# Out of the seat as the game does it, then through the real airlock.
	if _director.is_seated:
		_director.stand_now()
		await _frames(3)
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	var crate := Item.new()
	crate.setup(_starter.item_catalog.get_def(&"crate"))
	_starter.items.add_child(crate)
	crate.global_position = _avatar.global_position + _avatar.global_basis * Vector3(0.0, 1.0, -0.6)
	crate.set_loose()
	var carrying := _avatar.grasp.take(crate)
	var lock: Airlock = _starter.airlocks.values()[0]
	await _into_the_room(_starter, lock)
	if not await _cycle_out("10", _starter, lock, Avatar.Mode.SUIT):
		return
	_check(carrying and _avatar.grasp.item == crate and crate.in_space, "10 the crate in hand came out with you")
	# The suit's assist stops you against the hull, then lets go.
	await _seconds(2.0)
	_avatar.suit_assist = false
	var from_centre := (_avatar.global_position - _centre()).length()
	var hull_from := (_starter.exterior.global_position - _centre()).length()
	await _seconds(10.0)
	var fell := from_centre - (_avatar.global_position - _centre()).length()
	var hull_fell := hull_from - (_starter.exterior.global_position - _centre()).length()
	_check(_avatar.mode == Avatar.Mode.SUIT and absf(fell) < 0.5,
		"10 on a spacewalk in the ring, assist off: in 10 s you fell %.2f m, the hull %.2f m (under 0.5); air() %.3f, fog %s, dust %.3f" % [
		fell, hull_fell, w.air(), "on" if env.fog_enabled else "off", _stars.dust.density])
	# Let go of the crate: it stays where it is.
	_avatar.grasp.drop()
	await _frames(2)
	var item_from := (crate.global_position - _centre()).length()
	await _seconds(5.0)
	var drift := (crate.global_position - _centre()).length() - item_from
	_check(_avatar.grasp.item == null, "10 the crate let go: nothing in hand")
	_check(absf(drift) < 0.5, "10 the crate let go in the ring: its distance from the planet's centre changed %.2f m in 5 s (under 0.5)" % drift)
	# From outside, 25 m out from the hull and 4 m off the ring's plane, looking
	# along the ring with the sun behind or beside, and a little toward the
	# planet so its limb is in frame: the lit rocks of the ring are in view.
	var hull := _starter.exterior.global_transform
	var to_sun := (_scene.get_node("DirectionalLight3D") as DirectionalLight3D).global_basis.z.normalized()
	var along := normal.cross(dir).normalized()
	if along.dot(to_sun) > 0.0:
		along = -along
	var eye := hull.origin + dir * 25.0 + normal * 4.0
	var gaze := (along - dir * 0.35).normalized()
	print("        ring shot: looking along the ring, %.0f deg from the sun's way (over 90 is sun behind or beside)" % rad_to_deg(gaze.angle_to(to_sun)))
	await _camera_shot("ring_spacewalk", Transform3D(Basis.looking_at(gaze, normal), eye))
	# Back in, as fleet_play glides in, and to the helm.
	lock.alcove.hull_panel.interact(_avatar)
	await _until(func() -> bool: return lock.cycle.outer_open >= 1.0, 12.0)
	hull = _starter.exterior.global_transform
	var inward := (hull.basis * lock.alcove.outer_frame.basis * Vector3(0, 0, 1)).normalized()
	_avatar.global_position = hull * (lock.alcove.outer_frame * Vector3(0, 0.3, -1.5))
	_avatar.velocity = inward * 1.2 + _starter.exterior.linear_velocity
	var inside := await _until(func() -> bool: return _avatar.mode == Avatar.Mode.PLATING, 6.0)
	lock.room.room_panel.interact(_avatar)
	var cycled := await _until(func() -> bool: return lock.cycle.inner_open >= 1.0, 12.0)
	_check(inside and cycled, "10 back in through the starter's airlock")
	await _sit(_starter)

## Review Focus 1 without a ring: up through the air top, out of the airlock
## onto a spacewalk, and no fall.
func _above_the_air() -> void:
	var air := _planet.recipe.air_top()
	var over := func() -> float: return (_starter.exterior.global_position - _centre()).length() - _planet.radius
	var dir := _up(_starter.exterior.global_position)
	_starter.exterior.global_transform = Transform3D(_level(dir, _forward), _centre() + dir * (_planet.radius + air - 150.0))
	_starter.exterior.linear_velocity = Vector3.ZERO
	_starter.exterior.angular_velocity = Vector3.ZERO
	_moved()
	await _seconds(1.0)
	var under := _starter.on_world()
	var r := await _climb(_starter, over, air + 300.0, 60.0)
	_check(under and not _starter.on_world() and float(r["height"]) > air,
		"10b from %.0f m under the air top (on the world: %s) up through it, hovering %.0f m over it (on the world: %s)" % [
		150.0, under, float(r["height"]) - air, _starter.on_world()])
	_director.stand_now()
	await _frames(3)
	_avatar.suit_cell.charge = SuitCell.CAPACITY
	var lock: Airlock = _starter.airlocks.values()[0]
	await _into_the_room(_starter, lock)
	if not await _cycle_out("10b", _starter, lock, Avatar.Mode.SUIT):
		return
	# The suit's assist stops you against the hull, then lets go.
	await _seconds(2.0)
	_avatar.suit_assist = false
	var from_centre := (_avatar.global_position - _centre()).length()
	var hull_from := (_starter.exterior.global_position - _centre()).length()
	await _seconds(10.0)
	var fell := from_centre - (_avatar.global_position - _centre()).length()
	var hull_fell := hull_from - (_starter.exterior.global_position - _centre()).length()
	_check(_avatar.mode == Avatar.Mode.SUIT and absf(fell) < 0.5,
		"10b on a spacewalk %.0f m over the air top, assist off: in 10 s you fell %.2f m, the hull %.2f m (no fall: under 0.5)" % [
		from_centre - _planet.radius - air, fell, hull_fell])
	_avatar.set_head_pitch(deg_to_rad(-35.0))
	await _shot("spacewalk_over_the_air")
	# Back in, as fleet_play glides in, and to the helm.
	lock.alcove.hull_panel.interact(_avatar)
	await _until(func() -> bool: return lock.cycle.outer_open >= 1.0, 12.0)
	var hull := _starter.exterior.global_transform
	var inward := (hull.basis * lock.alcove.outer_frame.basis * Vector3(0, 0, 1)).normalized()
	_avatar.global_position = hull * (lock.alcove.outer_frame * Vector3(0, 0.3, -1.5))
	_avatar.velocity = inward * 1.2 + _starter.exterior.linear_velocity
	var inside := await _until(func() -> bool: return _avatar.mode == Avatar.Mode.PLATING, 6.0)
	lock.room.room_panel.interact(_avatar)
	var cycled := await _until(func() -> bool: return lock.cycle.inner_open >= 1.0, 12.0)
	_check(inside and cycled, "10b back in through the starter's airlock")
	await _sit(_starter)

## The controller's check 3: the head lamp at night, at eye height. The
## starter is set down on the night side and you step out to look.
func _night_lamp() -> void:
	var star: SystemBody = (_scene.get("system") as SystemRecipe).star
	var to_star := star.point.minus(_planet.point).normalized()
	var night := _flattest(-to_star, FLAT_REACH)
	_place(_starter, night, 3.0, _tangents(night)[0])
	await _ground_built()
	await _seconds(0.5)
	var end := Time.get_ticks_msec() + 15000
	while _starter.landing.state == LandingMonitor.State.FLYING and Time.get_ticks_msec() < end:
		_hold_sink(_starter, 1.0)
		await physics_frame
	_stick_y(0.0)
	var landed := await _until(func() -> bool: return _starter.landing.is_landed(), 10.0)
	var sun := 90.0 - rad_to_deg(night.angle_to(to_star))
	_check(landed and sun < -10.0, "lamp the starter landed on %s's night side, the sun %.0f deg below the horizon; floods %s" % [
		_planet.name, -sun, "on" if _starter.lights.floods else "off"])
	_director.stand_now()
	await _frames(3)
	var lock: Airlock = _starter.airlocks.values()[0]
	await _into_the_room(_starter, lock)
	print("        world_refusal() here: '%s'" % lock.world_refusal())
	if not await _cycle_out("lamp", _starter, lock, Avatar.Mode.FIELD):
		return
	await _walk_away(func() -> Vector3: return lock.beacon(), BESIDE, 5.0)
	_avatar.set_head_pitch(deg_to_rad(-12.0))
	await _seconds(1.0)
	var eye := (_avatar.camera.global_position - _avatar.global_position).dot(_avatar.up)
	await _shot("lamp_off")
	await _press(KEY_L)
	var lamp := _avatar.lamp
	_check(lamp.visible, "lamp L switches the head lamp on: energy %.1f, range %.0f m, %.0f deg, eye %.2f m over your feet" % [
		lamp.light_energy, lamp.spot_range, lamp.spot_angle, eye])
	await _seconds(0.5)
	await _shot("lamp_on")
	_face(lock.beacon() - _avatar.global_position)
	await _seconds(0.5)
	await _shot("lamp_on_the_hull")

# --- the pieces ----------------------------------------------------------------

## Into `ship`'s airlock room from aboard, the inner hatch opened by its
## corridor panel, standing facing the outer hatch.
func _into_the_room(ship: Ship, lock: Airlock) -> void:
	if lock.cycle.inner_open < 1.0:
		await _until(func() -> bool: return lock.cycle.stage == AirlockCycle.Stage.IDLE, 6.0)
		lock.room.corridor_panel.interact(_avatar)
		await _until(func() -> bool: return lock.cycle.inner_open >= 1.0, 6.0)
	# A frame's -z looks out.
	_avatar.place(ship.interior.global_transform * Transform3D(lock.room.outer_frame.basis, lock.room.room_frame.origin))
	_avatar.set_head_pitch(0.0)
	await _frames(3)

## The room panel, the outer hatch, and out on your feet: true once you are
## out in `mode`.
func _cycle_out(step: String, ship: Ship, lock: Airlock, mode: Avatar.Mode) -> bool:
	lock.room.room_panel.interact(_avatar)
	var opened := await _until(func() -> bool: return lock.cycle.outer_open >= 1.0, 12.0)
	Input.action_press(&"move_forward")
	var out := await _until(func() -> bool: return _avatar.mode != Avatar.Mode.PLATING, 4.0)
	if mode == Avatar.Mode.SUIT:
		Input.action_release(&"move_forward")
	var what := "on foot" if mode == Avatar.Mode.FIELD else "on a spacewalk"
	_check(opened and out and _avatar.mode == mode and _avatar.get_parent() == ship.outside,
		"%s the outer hatch opens and you walk out of %s's airlock %s (%s)" % [step, ship.name, what,
		Avatar.Mode.keys()[_avatar.mode]])
	return _avatar.mode == mode

## Walks you, W held and the way you face, until `from` is `dist` metres
## behind you along the ground.
func _walk_away(from: Callable, dist: float, limit: float) -> bool:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	Input.action_press(&"move_forward")
	var ok := false
	while Time.get_ticks_msec() < end:
		if _flat(_avatar.global_position - (from.call() as Vector3)).length() >= dist:
			ok = true
			break
		await physics_frame
	Input.action_release(&"move_forward")
	await _until(func() -> bool: return _flat(_avatar.velocity).length() < 0.05, 1.0)
	return ok

## Walks you, W held, turning toward `target` (a world point, asked each
## tick) until it is within `within` metres along the ground.
func _walk_to(target: Callable, within: float, limit: float) -> bool:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	Input.action_press(&"move_forward")
	var ok := false
	while Time.get_ticks_msec() < end:
		var d := _flat((target.call() as Vector3) - _avatar.global_position)
		if d.length() <= within:
			ok = true
			break
		_face(d)
		await physics_frame
	Input.action_release(&"move_forward")
	await _until(func() -> bool: return _flat(_avatar.velocity).length() < 0.05, 1.0)
	return ok

## Space, standing still: how high you go against 3.1^2 / (2g), rendered at
## the top.
func _jump() -> void:
	await _until(func() -> bool: return _avatar.is_on_floor(), 2.0)
	await _seconds(0.5)
	var p0 := _avatar.global_position
	var up := _avatar.up
	var g := _gravity.at(p0).length()
	var top := 0.0
	var left := false
	var peak: Image = null
	await _press(KEY_SPACE)
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		await physics_frame
		top = maxf(top, (_avatar.global_position - p0).dot(up))
		if not _avatar.is_on_floor():
			left = true
		if left and peak == null and _avatar.velocity.dot(up) <= 0.0:
			peak = root.get_viewport().get_texture().get_image()
		if left and _avatar.is_on_floor():
			break
	var expected := Avatar.JUMP_SPEED * Avatar.JUMP_SPEED / (2.0 * g)
	_check(left and absf(top - expected) <= expected * 0.1,
		"5 jump: peak %.3f m, against %.1f^2 / (2 x %.2f) = %.3f m (within 10%%: %.1f%%), and back down" % [
		top, Avatar.JUMP_SPEED, g, expected, absf(top - expected) / expected * 100.0])
	if peak != null:
		var file := "%s/landing_jump_peak.png" % _out
		peak.save_png(file)
		print("render  %s" % file)

## Full stick up until, braking as the assist does, `ship` would stop with
## `height_of` at `height`; hands off, and the hover. {left: seconds to leave
## LANDED (-1 if it never was), stick: seconds on the stick, height: where it
## settled, drift: over 3 s of hover, reached}.
func _climb(ship: Ship, height_of: Callable, height: float, limit: float) -> Dictionary:
	var fc := ship.flight_computer
	var was_landed := ship.landing.is_landed()
	var t0 := Time.get_ticks_msec()
	var left := -1.0
	var reached := false
	var release := {}
	_stick_y(1.0)
	while Time.get_ticks_msec() - t0 < limit * 1000.0:
		await physics_frame
		if was_landed and left < 0.0 and not ship.landing.is_landed() and not ship.exterior.freeze:
			left = (Time.get_ticks_msec() - t0) / 1000.0
		var v := ship.exterior.linear_velocity.dot(_up(ship.exterior.global_position))
		var low := ship.quantum.store != null and ship.quantum.store.is_low_power()
		var brake: float = fc.thrust_budget[&"vertical"] * (QuantumValues.LOW_POWER_AUTHORITY if low else 1.0) / ship.exterior.mass
		var k := WorldGravity.DRAG_K * _gravity.air_at(ship.exterior.global_position)
		if float(height_of.call()) + _stop_distance(v, brake * 0.95, k) >= height:
			reached = true
			var at := float(height_of.call())
			release = {"v": v, "brake": brake, "k": k, "drag": k * v * v, "at": at,
				"plain": at + _stop_distance(v, brake * 0.95, 0.0), "predicted": at + _stop_distance(v, brake * 0.95, k)}
			break
	var stick := (Time.get_ticks_msec() - t0) / 1000.0
	_stick_y(0.0)
	# Hands off, the assist brakes at its budget and then eases the last metres
	# out (its drift correction is proportional): wait for it to stop.
	var t1 := Time.get_ticks_msec()
	await _until(func() -> bool:
		return absf(ship.exterior.linear_velocity.dot(_up(ship.exterior.global_position))) < 0.1, 20.0)
	var braking := (Time.get_ticks_msec() - t1) / 1000.0
	var settled := float(height_of.call())
	await _seconds(3.0)
	return {"was_landed": was_landed, "left": left, "stick": stick, "braking": braking,
		"height": settled, "drift": float(height_of.call()) - settled, "reached": reached, "release": release}

## How far a climb at `v` up goes before it stops under a constant brake `b`
## and the air's drag `k v^2`: ln(1 + k v^2 / b) / (2 k). The plain v^2 / (2 b)
## where there is no air (k about 0) or you are not climbing.
static func _stop_distance(v: float, b: float, k: float) -> float:
	if v <= 0.0:
		return 0.0
	if k < 1e-9:
		return v * v / (2.0 * b)
	return log(1.0 + k * v * v / b) / (2.0 * k)

func _say_climb(step: String, ship: Ship, r: Dictionary) -> void:
	var low := " on low power" if ship.quantum.store.is_low_power() else ""
	var rel: Dictionary = r["release"]
	if not rel.is_empty():
		print("        %s stick released at %.1f m climbing %.1f m/s: brake %.2f m/s2, drag %.2f m/s2 (k %.5f); stops at %.1f m by v2/2b alone, %.1f m with the drag; settled %.1f m" % [
			step, float(rel["at"]), float(rel["v"]), float(rel["brake"]), float(rel["drag"]), float(rel["k"]),
			float(rel["plain"]), float(rel["predicted"]), float(r["height"])])
	_check(bool(r["was_landed"]) and float(r["left"]) >= 0.0 and float(r["left"]) < 1.0,
		"%s translate up%s: %s leaves LANDED after %.2f s, thawed" % [step, low, ship.name, float(r["left"])])
	_check(bool(r["reached"]) and absf(float(r["height"]) - HOVER) < 15.0 and absf(float(r["drift"])) < 2.0,
		"%s climbs%s: %.1f s on the stick, %.1f s braking hands off, settles %.1f m over the ground (300 within 15), drift %.2f m in 3 s (under 2)" % [
		step, low, float(r["stick"]), float(r["braking"]), float(r["height"]), float(r["drift"])])

## Holds the vertical stick, through the input, so `ship` sinks at `rate` m/s:
## proportional to the error, never quite centred (a centred axis brakes).
func _hold_sink(ship: Ship, rate: float) -> void:
	var s := clampf((_sink(ship) - rate) * 0.5, -1.0, 1.0)
	if absf(s) < 0.02:
		s = 0.02 if _sink(ship) > rate else -0.02
	_stick_y(s)

func _sink(ship: Ship) -> float:
	return -ship.exterior.linear_velocity.dot(_up(ship.exterior.global_position))

## The pilot's up/down translation, -1..1: Shift up, Ctrl down.
func _stick_y(s: float) -> void:
	Input.action_release(&"sprint")
	Input.action_release(&"crouch")
	if s > 0.0:
		Input.action_press(&"sprint", minf(s, 1.0))
	elif s < 0.0:
		Input.action_press(&"crouch", minf(-s, 1.0))

func _let_go() -> void:
	for action: StringName in [&"move_forward", &"sprint", &"crouch"]:
		Input.action_release(action)

## You to `ship`'s helm: stood on its deck by the helm, then into the seat.
func _sit(ship: Ship) -> void:
	_avatar.position = (_scene.call("_deck_spot", ship) as Transform3D).origin
	await _frames(3)
	ship.seat.interact(_avatar)
	await _until(func() -> bool: return _director.is_seated and not _director.is_moving(), 3.0)
	await _frames(3)

## A camera outside, `offset` in `ship`'s hull axes from its hull, looking at
## the middle of the hull, for one render.
func _outside_shot(shot_name: String, ship: Ship, offset: Vector3) -> void:
	var hull := ship.exterior.global_transform
	var at := hull * offset
	var middle := hull * Vector3(0.0, 1.0, -1.0)
	await _camera_shot(shot_name, Transform3D(Basis.looking_at(middle - at, _up(at)), at))

## A camera at eye height (EYE m over the real ground) at `flat` in `ramp`'s
## hinge frame (x along the hull, z out of the hatch; its y is ignored),
## looking at `target` in that frame, for one render.
func _ramp_shot(shot_name: String, ramp: LandingRamp, flat: Vector3, target: Vector3) -> void:
	var frame := ramp.global_transform
	var at := frame * Vector3(flat.x, -ramp.sill_height, flat.z)
	var up := _up(at)
	at += up * (EYE - _gravity.altitude_at(at))
	await _camera_shot(shot_name, Transform3D(Basis.looking_at(frame * target - at, up), at))

## The probe's own camera, outside, at `pose`, for one render.
func _camera_shot(shot_name: String, pose: Transform3D) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "ProbeCamera"
		_cam.far = BodyProxy.VIEW_FAR
		_cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
		_scene.add_child(_cam)
		_cam.add_to_group(Universe.EXTERIOR_SPACE)
	var was := root.get_viewport().get_camera_3d()
	_cam.global_transform = pose
	_cam.current = true
	await _shot(shot_name)
	_cam.current = false
	if was != null:
		was.current = true

func _shot(shot_name: String) -> void:
	await _frames(5)
	var file := "%s/landing_%s.png" % [_out, shot_name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

## Frames a second over `seconds`, as combat_probe measures them; `_gpu_ms`
## and `_cpu_ms` take the renderer's mean times.
func _fps(seconds: float) -> float:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var frames := 0
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(seconds * 1e6):
		await process_frame
		frames += 1
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	RenderingServer.viewport_set_measure_render_time(vp, false)
	_gpu_ms = gpu / maxf(frames, 1.0)
	_cpu_ms = cpu / maxf(frames, 1.0)
	return frames / seconds

func _env() -> Environment:
	return (_scene.get_node("WorldEnvironment") as WorldEnvironment).environment

func _sky() -> ProceduralSkyMaterial:
	return _env().sky.sky_material as ProceduralSkyMaterial

func _ms() -> String:
	return "(render gpu %.1f ms, cpu %.1f ms)" % [_gpu_ms, _cpu_ms]

# --- the world -----------------------------------------------------------------

func _centre() -> Vector3:
	return _universe.to_engine(_planet.point)

## Away from the planet's centre at engine point `p`.
func _up(p: Vector3) -> Vector3:
	return (p - _centre()).normalized()

## Metres from the centre to the ground along `dir`.
func _ground_r(dir: Vector3) -> float:
	return _planet.radius + _surface.terrain.height_at(dir.normalized())

func _alt(ship: Ship) -> float:
	return ship.flight_computer.keel_altitude()

static func _tangents(dir: Vector3) -> Array[Vector3]:
	var a := dir.cross(Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	return [a, dir.cross(a).normalized()]

## A level axis between pitch and roll for a ship nosed along `_forward`.
func _tilt_axis(dir: Vector3) -> Vector3:
	var f := (_forward - dir * _forward.dot(dir)).normalized()
	return (f + f.cross(dir)).normalized()

## How far the ground rises or falls within `reach` metres of `dir`.
func _spread(dir: Vector3, reach: float) -> float:
	var t := _surface.terrain
	var ab := _tangents(dir)
	var h0 := t.height_at(dir)
	var most := 0.0
	for r: float in [reach / 3.0, reach * 2.0 / 3.0, reach]:
		for k in 8:
			var o := (ab[0] * cos(k * TAU / 8.0) + ab[1] * sin(k * TAU / 8.0)) * (r / _planet.radius)
			most = maxf(most, absf(t.height_at((dir + o).normalized()) - h0))
	return most

## The flattest of spots on rings 250 m apart round `near`, out to 1 km.
func _flattest(near: Vector3, reach: float) -> Vector3:
	var ab := _tangents(near)
	var best := near
	var least := _spread(near, reach)
	for ring in range(1, 5):
		for k in 12:
			var o := (ab[0] * cos(k * TAU / 12.0) + ab[1] * sin(k * TAU / 12.0)) * (ring * 250.0 / _planet.radius)
			var d := (near + o).normalized()
			var s := _spread(d, reach)
			if s < least:
				least = s
				best = d
	return best

## Upright on `up`, the nose along `forward` laid on the ground.
static func _level(up: Vector3, forward: Vector3) -> Basis:
	var y := up.normalized()
	var f := (forward - y * forward.dot(y)).normalized()
	return Basis(y.cross(-f).normalized(), y, -f)

## `ship`'s hull over `dir`, the plane its legs stand on `height` m over the
## ground, turned by `tilt` from level, at rest; the origin, the worlds and the
## sun follow.
func _place(ship: Ship, dir: Vector3, height: float, forward: Vector3, tilt := Basis.IDENTITY) -> void:
	var up := dir.normalized()
	ship.exterior.global_transform = Transform3D(tilt * _level(up, forward),
		_centre() + up * (_ground_r(up) + ship.stance_depth() + height))
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	_moved()

func _moved() -> void:
	_universe.check()
	_stars.place_all()
	_stars.whereabouts.look()

## The ground round the focus streamed in full: the renders see it whole.
func _ground_built() -> void:
	await _frames(3)
	_surface.finish()
	await _frames(2)

## Degrees between `ship`'s up and the local up, signed about `axis`: positive
## the way it was tilted, negative past level.
func _signed_tilt(ship: Ship, axis: Vector3) -> float:
	var up := _up(ship.exterior.global_position)
	var y := ship.exterior.global_basis.y.normalized()
	return rad_to_deg(atan2(up.cross(y).dot(axis), up.dot(y)))

static func _degrees(series: PackedFloat32Array) -> String:
	var parts: Array[String] = []
	for v in series:
		parts.append("%.1f" % v)
	return "[%s]" % ", ".join(parts)

func _block_damage(ship: Ship) -> float:
	var total := 0.0
	for c in ship.grid.coords():
		total += ship.grid.get_block(c).damage
	return total

## The outer hatch floor's height over the ground under it.
func _hatch_floor_height(lock: Airlock) -> float:
	return _gravity.altitude_at(lock.alcove.outer_hatch.global_position)

## How far your feet are under `lock`'s outer hatch floor, along your up.
func _below_hatch_floor(lock: Airlock) -> float:
	return (lock.alcove.outer_hatch.global_position - _avatar.global_position).dot(_avatar.up)

# --- you -----------------------------------------------------------------------

## The part of `v` along the ground where you stand.
func _flat(v: Vector3) -> Vector3:
	var up := _avatar.up
	return v - up * v.dot(up)

## Turns you about up to face `d`, as the mouse would.
func _face(d: Vector3) -> void:
	var f := _flat(-_avatar.global_basis.z)
	var t := _flat(d)
	if f.length() < 1e-4 or t.length() < 1e-4:
		return
	var angle := f.normalized().signed_angle_to(t.normalized(), _avatar.up)
	_avatar.look(Vector2(-angle / Avatar.MOUSE_SENSITIVITY, 0.0))

# --- as fleet_play ---------------------------------------------------------------

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

func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok     " if ok else "FAILED ", what])
	if not ok:
		_fails += 1

## A key as the player presses it: down and up, through the engine's input.
func _press(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
	await _frames(2)
