extends "res://test/probes/desert_render.gd"

## The oasis on world p3 of system seed 1337, rendered in the flight scene
## (docs/superpowers/specs/2026-11-14-desert-world-p3-oasis; phase 3's Task 7,
## Checkpoint A). It rides on phase 2's harness (desert_render, descent_render
## and landing_play) and calls their helpers: placing a hull, the ground built
## round it, stepping out of the airlock, the frame rate, the camera shots. The
## desert's own search for a spot is not used: the oasis is placed by the
## design (PlaceDesign), and the world is always p3.
##
##   land     the warp from the entry to p3: its arrival rendered seated, with
##            the beacon's contact printed and then set as the course so its
##            marker is on the HUD (warp_arrival_seated outside the well; warp_inside_well);
##            hovering seated over the oasis at 2 km and 300 m, back from it
##            with the sun at the camera's back and across it (seated_<h>_lit,
##            seated_<h>_side); the starter brought down from LAND_FROM m onto
##            the pad, nosed at the pool (its tilt and damage printed), seen
##            from outside (starter_pad), seated (landed_seated) and its frame
##            rate over LANDED_SECONDS; on foot, eye 1.6 m over the ground, at
##            the pad's edge, then from the far side of the pool looking across
##            it to the pad (foot_pad_and_pool), at the
##            pool's edge looking over the water (foot_pool_edge) and back at
##            the pad (foot_pool_edge_back), the frame rate there, and in the
##            pool (foot_in_pool) with the wading speed against the dry speed;
##            a floating-origin shift forced while you stand in it (Review
##            Focus 3: the depth and the speed must hold); then the heaviest
##            library ship (the Warden) brought down on the pad the same way
##            (Review Focus 1: tilt under MAX_TILT_DEG, no damage).
##   village  Task 9's: the village outside (not built yet).
##   inside   Task 14's: inside a building (not built yet).
##   all      every set built so far.
##
## Every render is oasis_<name>.png in the output directory, its name and the
## eye's altitude over the ground printed with it, and oasis_sheet.png puts them
## side by side. Run it WITHOUT --headless, from who-knows:
##
##   godot --path . --resolution 1280x720 \
##     --script res://test/probes/oasis_render.gd -- <abs out dir> [land|village|inside|all]

## The world and the place the probe is about.
const WORLD_ID := &"p3"
const PLACE_ID := &"oasis"
## The sets that exist (a name asked for that is not here is refused).
const SETS := ["land", "village", "inside", "all"]
## Hovering over the oasis: these heights, m, and how far back from it the
## camera stands, as a multiple of its height, so the oasis is at the middle
## of the view (a 45 deg look down at 1x, 26 deg at 2x).
const HOVER_HEIGHTS: Array[float] = [2000.0, 300.0]
const HOVER_BACK: Array[float] = [1.0, 2.0]
## The range the sensors are asked for the beacon at, m: past the well (a
## beacon is listed by the well it lies in, whatever the range, but the list is
## cut to the range asked).
const BEACON_RANGE := 200000.0
## Inside the well, this share of its radius from the centre, for the beacon.
const WELL_DEPTH := 0.9
## The warp starts at least this far past the cluster's limit it began in, m.
const OUT_OF_THE_CLUSTER := 500.0
## Warp steps are taken at the physics rate.
const WARP_DT := 1.0 / 60.0
## A warp that has not dropped out after this many steps never will.
const WARP_STEPS_MAX := 200000
## The pad is landed on from this height (the plane the legs stand on, over
## the ground), at FAST_SINK m/s down to SLOW_FROM m (landing_play's), then at
## its SINK; the ground is built in full from GROUND_AT m down.
const LAND_FROM := 150.0
const FAST_SINK := 10.0
const GROUND_AT := 45.0
## What the brief asks of a landing on the pad, degrees.
const MAX_TILT_DEG := 2.0
## On the pad, on foot: this far in from its edge toward the pool, m.
const PAD_EDGE_IN := 2.0
## The view with the pad and the pool both in it is taken from this far (m) past
## the pool's middle, on the side away from the pad.
const BEHIND_POOL := 45.0
## On the pool's bank, this far from its middle, m (the basin's rim is 17 m, the
## water's edge a little in from it), and in the water this far from it.
const BANK_RADIUS := 16.0
const WADE_RADIUS := 5.0
## The wading speed is the mean flat speed over the last WALK_MEAN s of a walk
## of WALK_SECONDS.
const WALK_SECONDS := 1.2
const WALK_MEAN := 0.4
## The shift forced while you wade, m: one whole step.
const SHIFT_BY := Universe.STEP
## The wading speed against the depth's own share of the dry one, as a ratio.
const WADE_SPEED_TOLERANCE := 0.1
## The depth before and after the shift must agree within this, m.
const WADE_DEPTH_TOLERANCE := 0.01
## The seated frame rate on the pad, s.
const LANDED_SECONDS := 10.0
## While the Warden comes down, the starter hovers this far from the pad, m,
## this high (WATCH_HIGH is desert_render's).
const STARTER_ASIDE := 500.0
## The contact sheet: columns, and the renders it takes in order.
const OASIS_TILE := Vector2i(400, 225)
const OASIS_COLUMNS := 4
const OASIS_SHEET := [
	"warp_arrival_seated", "warp_inside_well", "seated_2000_lit", "seated_2000_side",
	"seated_300_lit", "seated_300_side", "starter_pad", "landed_seated",
	"foot_pad_and_pool", "foot_pool_edge", "foot_pool_edge_back", "foot_in_pool",
	"warden_pad",
]

## The oasis, and the pad's and the pool's directions on the world.
var _oasis: PlaceDesign
var _pad_dir := Vector3.UP
var _pool_dir := Vector3.UP
## The dry walking speed measured on the pad, m/s.
var _dry_speed := 0.0

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
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		_which = args[1]
	if not _which in SETS:
		print("oasis   no set called %s: %s" % [_which, ", ".join(SETS)])
		quit(1)
		return
	print("gpu     %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	var system: SystemRecipe = _scene.get("system")
	_planet = system.body(WORLD_ID)
	for place in system.places():
		if place.id == PLACE_ID:
			_oasis = place
	if _planet == null or _oasis == null:
		_check(false, "system %d has %s with a place called %s" % [system.seed, WORLD_ID, PLACE_ID])
		quit(1)
		return
	_starter.flight_computer.assist_enabled = true
	await _sit(_starter)
	await _hide_the_card()
	if _which in ["land", "all"]:
		await _land_set()
	if _which in ["village", "all"]:
		await _village_set()
	if _which in ["inside", "all"]:
		await _inside_set()
	_oasis_sheet()
	_let_go()
	print("        the frame rate:")
	for line in _readings:
		print("        %s" % line)
	print("oasis   %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)

## p3, whatever the system's other planets are.
func _pick_planet(system: SystemRecipe) -> SystemBody:
	return system.body(WORLD_ID)

## Later tasks put their views here.
func _village_set() -> void:
	print("village not built yet (Task 9)")

func _inside_set() -> void:
	print("inside  not built yet (Task 14)")

# --- the land set ----------------------------------------------------------------

func _land_set() -> void:
	await _warp_in()
	if not await _to_the_planet():
		print("oasis   no world to come down on")
		return
	_terrain = WorldTerrain.new(_planet.recipe)
	_starter.flight_computer.assist_enabled = true
	_find_the_oasis()
	await _hover_views()
	await _starter_on_the_pad()
	await _on_foot_at_the_oasis()
	await _warden_on_the_pad()

## The spot is the oasis; the pad's and the pool's directions from its layout.
func _find_the_oasis() -> void:
	var layout := _oasis.layout()
	var pad: Array = layout["pad"]["at"]
	var pool: Array = layout["pool"]["at"]
	_spot = _oasis.dir()
	_pad_dir = _oasis.local_dir(float(pad[0]), float(pad[1]), _planet.radius)
	_pool_dir = _oasis.local_dir(float(pool[0]), float(pool[1]), _planet.radius)
	var to_star := _to_star()
	_sun_flat = (to_star - _spot * to_star.dot(_spot)).normalized()
	_across = _spot.cross(_sun_flat).normalized()
	_forward = _across
	print("oasis   %s at lat %.2f lon %.2f: the sun %.1f deg up; the pad %.0f m and the pool %.0f m from it; the ground under the pool %.2f m, under the pad %.2f m, 200 m out %.2f m" % [
		_oasis.name, _oasis.lat, _oasis.lon, 90.0 - rad_to_deg(_spot.angle_to(to_star)),
		_spot.angle_to(_pad_dir) * _planet.radius, _spot.angle_to(_pool_dir) * _planet.radius,
		_surface.terrain.height_at(_pool_dir), _surface.terrain.height_at(_pad_dir),
		_surface.terrain.height_at(_off(_spot, _sun_flat, 200.0))])

# --- the warp --------------------------------------------------------------------

## The starter put at `from`, nosed at `look`, at rest and frozen, the world and
## the rocks ready, as test_warp_scene's _put does it.
func _put_at(from: UniversePoint, look: UniversePoint) -> void:
	var hull := _starter.exterior
	hull.freeze = true
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	var dir := look.minus(from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	hull.global_transform = Transform3D(Basis.looking_at(dir, up), _universe.to_engine(from))
	_universe.check()
	_stars.place_all()
	_stars.whereabouts.look()
	(_scene.get_node("AsteroidStream") as AsteroidStream).update(0.0, true)

## From the entry to p3 by the starter's own drive, stepped at the physics
## rate; its arrival rendered seated, with the beacon on the HUD.
func _warp_in() -> void:
	var system: SystemRecipe = _scene.get("system")
	var target := system.warp_target(WORLD_ID)
	var warp := _starter.warp
	warp.set_physics_process(false)
	_starter.quantum.store.amount = _starter.quantum.store.capacity
	var from := system.entry()
	warp.chart(WORLD_ID)
	_put_at(from, target.point)
	var plan := warp.check()
	print("warp    from the entry, %.0f km from %s's centre: %s" % [from.minus(target.point).length() / 1000.0,
		_planet.name, plan.text()])
	if plan.status == WarpPlan.Status.INSIDE:
		# The entry lies inside a cluster's limit: out of it, along the way.
		from = from.plus(plan.direction * (plan.clear_in + OUT_OF_THE_CLUSTER))
		_put_at(from, target.point)
		plan = warp.check()
		print("warp    %.0f m clear of the cluster: %s" % [plan.clear_in + OUT_OF_THE_CLUSTER, plan.text()])
	_put_at(from, plan.drop)
	plan = warp.check()
	_check(plan.status == WarpPlan.Status.READY, "warp the drive is ready (%s)" % plan.text())
	print("warp    to %s: %.0f km, %.0f qe, %.0f s of travel; it drops out %.1f km from the centre (the limit %.1f km), %.1f deg from the oasis seen from the centre" % [
		target.name, plan.distance / 1000.0, float(plan.cost), plan.duration, plan.drop.minus(target.point).length() / 1000.0,
		target.limit / 1000.0, rad_to_deg(plan.drop.minus(target.point).normalized().angle_to(_oasis.dir()))])
	warp.engage()
	var steps := 0
	while warp.is_spinning() and steps < WARP_STEPS_MAX:
		warp.step(WARP_DT)
		_stars.streak = warp.streak()
		_stars.place_all()
		steps += 1
	_stars.streak = Vector3.ZERO
	_check(not warp.is_spinning() and steps < WARP_STEPS_MAX, "warp dropped out after %.0f s" % (steps * WARP_DT))
	# Dropped out at the edge speed: held still for the render, the cruise lock
	# let go, as a pilot braking would.
	var hull := _starter.exterior
	hull.freeze = true
	hull.linear_velocity = Vector3.ZERO
	_starter.flight_computer.speed_locked = false
	warp.set_physics_process(true)
	_moved()
	await _frames(30)
	var focus := _universe.to_universe(hull.global_position)
	var inside := _planet.point.minus(focus).length() <= _planet.well_radius
	print("warp    arrived %.1f km from %s's centre, inside its well %s (%.1f km)" % [
		focus.minus(_planet.point).length() / 1000.0, _planet.name, inside, _planet.well_radius / 1000.0])
	# The drop is at the limit, a warp-clear margin outside the well, where the
	# beacon is not listed (spec 8.2): none now, and one once inside the well.
	_check(_beacon() == null, "warp the beacon is not listed at the drop-out, outside the well")
	await _shot("warp_arrival_seated")
	var oasis_at := _planet.point.plus(_oasis.dir() * _planet.radius)
	var inner := _planet.point.plus(_oasis.dir() * (_planet.well_radius * WELL_DEPTH))
	_put_at(inner, oasis_at)
	await _frames(30)
	var beacon := _beacon()
	_check(beacon != null, "warp the sensors list the beacon %.0f km from the centre, inside the well" % (_planet.well_radius * WELL_DEPTH / 1000.0))
	if beacon != null:
		print("        the beacon %s (%s), %.0f km off, listed inside the well" % [beacon.label, beacon.kind,
			beacon.point.minus(_universe.to_universe(hull.global_position)).length() / 1000.0])
		_starter.sensors.set_course(beacon.id)
		await _frames(10)
		await _shot("warp_inside_well")

## The beacon in the starter's sensor contacts, or null.
func _beacon() -> Contact:
	_starter.sensors.refresh(BEACON_RANGE)
	for c in _starter.sensors.contacts(BEACON_RANGE):
		if c.kind == PlaceContacts.KIND:
			return c
	return null

# --- hovering over the oasis -----------------------------------------------------

## Seated hovering at each of HOVER_HEIGHTS, back from the oasis with the sun at
## the camera's back and across, looking at it.
func _hover_views() -> void:
	for i in HOVER_HEIGHTS.size():
		var h := HOVER_HEIGHTS[i]
		var back := h * HOVER_BACK[i]
		print("hover   seated %.0f m over the ground, %.0f m back from the oasis" % [h, back])
		for way: Array in [["lit", _sun_flat], ["side", _across]]:
			var from := _off(_spot, way[1] as Vector3, back)
			var nose := _way_to(from, _spot)
			var pitch := Basis(_level(from, nose).x.normalized(), -atan2(h, back))
			await _hold_at(from, h, nose, pitch)
			await _shot("seated_%d_%s" % [roundi(h), way[0]])

# --- landing ---------------------------------------------------------------------

## `ship` from LAND_FROM m down onto where it is, FAST_SINK m/s to SLOW_FROM
## and then SINK, until the monitor says LANDED or not; `seated` by the stick,
## else by its flight computer's input. Prints and checks the touchdown (tilt
## under MAX_TILT_DEG, no hard landing, no damage). {landed, tilt (deg),
## damage (hp taken)}.
func _touch_down(ship: Ship, seated: bool, who: String) -> Dictionary:
	var landing := ship.landing
	var hard: Array[float] = []
	var on_hard := func(speed: float) -> void: hard.append(speed)
	landing.hard_landing.connect(on_hard)
	var damage := _block_damage(ship)
	var whole := ship.hull_whole()
	var legs := ship.exterior_builder.legs()
	var start := _alt(ship)
	var built := false
	var sinks: Array[float] = []
	var end := Time.get_ticks_msec() + 120000
	while landing.state == LandingMonitor.State.FLYING and Time.get_ticks_msec() < end:
		var alt := _alt(ship)
		if alt < GROUND_AT and not built:
			built = true
			await _ground_built()
		_sink_by(ship, seated, FAST_SINK if alt > SLOW_FROM else SINK)
		if alt < 3.0:
			sinks.append(_sink(ship))
		await physics_frame
	var touch: float = sinks.max() if not sinks.is_empty() else _sink(ship)
	_sink_by(ship, seated, NAN)
	var landed := await _until(func() -> bool: return landing.is_landed(), 10.0)
	await _seconds(0.5)
	await _frames(5)
	landing.hard_landing.disconnect(on_hard)
	var after := _block_damage(ship)
	var tilt := rad_to_deg(landing.tilt())
	var feet: Array[String] = []
	if legs != null:
		for foot in legs.feet():
			feet.append("%.2f" % _gravity.altitude_at(foot))
	print("landing %s: from %.0f m, legs %s, %s, down at most %.2f m/s over the last 3 m, tilt %.2f deg, damage %.1f hp before and %.1f after, HULL %.0f%%, feet %s m over the ground; the monitor %s" % [
		who, start, "down" if legs != null and legs.is_down() else "NOT down", "LANDED" if landed else "NOT landed (%s)" % LandingMonitor.State.keys()[landing.state],
		touch, tilt, damage, after, ship.hull_whole() * 100.0, ", ".join(feet),
		"says nothing" if landing.refusal() == "" else "refuses: '%s'" % landing.refusal()])
	_check(landed, "land %s landed on the pad" % who)
	_check(tilt < MAX_TILT_DEG, "land %s tilt %.2f deg (under %.0f)" % [who, tilt, MAX_TILT_DEG])
	_check(hard.is_empty(), "land %s no hard landing (%s)" % [who, "none said" if hard.is_empty() else "said at %s m/s" % str(hard)])
	_check(after == damage and ship.hull_whole() == whole, "land %s no damage (%.1f hp before, %.1f after; HULL %.0f%%, was %.0f%%)" % [
		who, damage, after, ship.hull_whole() * 100.0, whole * 100.0])
	if seated:
		_check_stick(ship, "land")
	return {"landed": landed, "tilt": tilt, "damage": after - damage}

## The starter over the pad's middle, nosed at the pool, brought down from
## LAND_FROM m: seen from outside, seated, and its frame rate.
func _starter_on_the_pad() -> void:
	print("pad     the starter onto the pad from %.0f m" % LAND_FROM)
	var nose := _way_to(_pad_dir, _pool_dir)
	await _unland()
	_starter.exterior.freeze = false
	_starter.flight_computer.assist_enabled = true
	_place(_starter, _pad_dir, LAND_FROM, nose)
	await _ground_built()
	var result := await _touch_down(_starter, true, "the starter")
	await _boulder_shot("starter_pad", _starter, -_sunward(_starter))
	if not bool(result["landed"]):
		return
	await _shot("landed_seated")
	await _reading_for("seated at the starter's helm landed on the pad, nosed at the pool", LANDED_SECONDS)

# --- on foot ---------------------------------------------------------------------

## Out of the starter's airlock onto the pad; then at the pad's edge, the pool's
## edge and in the pool, eye 1.6 m over the ground.
func _on_foot_at_the_oasis() -> void:
	if not _starter.landing.is_landed():
		print("        the starter did not land: no views on foot")
		return
	_director.stand_now()
	await _frames(3)
	var lock: Airlock = _starter.airlocks.values()[0]
	if not await _out_through(lock, "", "foot"):
		return
	# The pad's edge toward the pool, PAD_EDGE_IN m inside it.
	var pad_radius := float(_oasis.layout()["pad"]["radius"])
	var edge := _towards(_pad_dir, _pool_dir, pad_radius - PAD_EDGE_IN)
	await _stand_far(edge, _way_to(edge, _pool_dir))
	_avatar.set_head_pitch(0.0)
	print("        at the pad's edge %.0f m from the pool's middle, eye %.2f m over the ground, the ground there %s, %.2f m over the radius, the sun %.0f deg up" % [
		edge.angle_to(_pool_dir) * _planet.radius, _gravity.altitude_at(_avatar.camera.global_position),
		_surface.terrain.ground_at(edge, 0.0), _surface.terrain.height_at(edge), 90.0 - rad_to_deg(edge.angle_to(_to_star()))])
	await _seconds(0.5)
	_dry_speed = await _walk_speed("on the pad")
	# Then the view with both in it: on the far side of the pool, BEHIND_POOL m
	# from its middle, looking across the water to the pad and the ship on it.
	var behind := _off(_pool_dir, _way_to(_pool_dir, _pad_dir), -BEHIND_POOL)
	await _stand_far(behind, _way_to(behind, _pad_dir))
	_avatar.set_head_pitch(0.0)
	await _seconds(0.5)
	await _shot("foot_pad_and_pool")
	# The bank, toward the pad's side of the pool, then the water.
	var bank := _towards(_pool_dir, _pad_dir, BANK_RADIUS)
	await _stand_far(bank, _way_to(bank, _pool_dir))
	_avatar.set_head_pitch(0.0)
	await _seconds(0.5)
	await _shot("foot_pool_edge")
	await _reading("on foot at the pool's edge, %.0f m from its middle, looking over the water" % BANK_RADIUS)
	_face(_way_to(bank, _pad_dir))
	await _seconds(0.5)
	await _shot("foot_pool_edge_back")
	await _in_the_pool()

## The point `metres` from `from` along the ground toward `to`.
func _towards(from: Vector3, to: Vector3, metres: float) -> Vector3:
	return _off(from, _way_to(from, to), metres)

## Standing WADE_RADIUS m in from the pool's middle on the pad's side, looking
## across the water: the depth, the wading speed against the dry one, and a
## floating-origin shift forced while you stand there (Review Focus 3).
func _in_the_pool() -> void:
	var in_water := _towards(_pool_dir, _pad_dir, WADE_RADIUS)
	await _stand_far(in_water, _way_to(in_water, _pool_dir))
	_avatar.set_head_pitch(0.0)
	await _seconds(1.0)
	var depth := _avatar.wade_depth
	print("        in the pool %.1f m from its middle, eye %.2f m over the ground: wading %.2f m deep (the share left %.2f)" % [
		WADE_RADIUS, _gravity.altitude_at(_avatar.camera.global_position), depth, Avatar.wade_factor(depth)])
	_check(depth > 0.3, "pool standing %.1f m from the middle you are wading (%.2f m deep)" % [WADE_RADIUS, depth])
	await _shot("foot_in_pool")
	var wading := await _walk_speed("wading %.2f m deep" % depth)
	var want := _dry_speed * Avatar.wade_factor(_avatar.wade_depth)
	print("wading  %.2f m/s in %.2f m of water against %.2f m/s dry on the pad (%.0f%%; %.0f%% expected)" % [
		wading, depth, _dry_speed, wading / maxf(_dry_speed, 0.001) * 100.0, Avatar.wade_factor(depth) * 100.0])
	_check(absf(wading - want) <= WADE_SPEED_TOLERANCE * maxf(want, 0.001),
		"pool wading %.2f m/s against %.2f expected (dry %.2f x %.2f), within %.0f%%" % [
		wading, want, _dry_speed, Avatar.wade_factor(_avatar.wade_depth), WADE_SPEED_TOLERANCE * 100.0])
	# The shift, while you stand there.
	await _seconds(0.5)
	var before := _avatar.wade_depth
	var at := _avatar.global_position
	var shifts := _universe.shifts
	_universe.shift(Vector3(SHIFT_BY, 0.0, 0.0))
	await _seconds(1.0)
	var after := _avatar.wade_depth
	var moved := _avatar.global_position - at
	var after_speed := await _walk_speed("wading after the shift")
	print("shift   forced a floating-origin shift of %.0f m (%d shift) while wading: wade_depth %.3f m before and %.3f after (within %.2f), you moved %.0f m in the engine's frame, still %s; the wading speed after %.2f m/s (%.0f%% of dry)" % [
		SHIFT_BY, _universe.shifts - shifts, before, after, WADE_DEPTH_TOLERANCE, moved.length(),
		"on foot" if _avatar.mode == Avatar.Mode.FIELD else Avatar.Mode.keys()[_avatar.mode], after_speed,
		after_speed / maxf(_dry_speed, 0.001) * 100.0])
	_check(absf(after - before) <= WADE_DEPTH_TOLERANCE and after > 0.0,
		"shift wade_depth %.3f before, %.3f after a forced shift (within %.2f)" % [before, after, WADE_DEPTH_TOLERANCE])
	_check(absf(after_speed - want) <= WADE_SPEED_TOLERANCE * maxf(want, 0.001),
		"shift the wading speed after %.2f m/s against %.2f expected" % [after_speed, want])

## Walks you, W held and the way you face, for WALK_SECONDS; the mean flat speed
## over the last WALK_MEAN s, m/s. Printed with `what`.
func _walk_speed(what: String) -> float:
	await _until(func() -> bool: return _avatar.is_on_floor(), 2.0)
	var speeds: Array[float] = []
	var end := Time.get_ticks_msec() + int(WALK_SECONDS * 1000.0)
	var from := Time.get_ticks_msec()
	Input.action_press(&"move_forward")
	while Time.get_ticks_msec() < end:
		await physics_frame
		if Time.get_ticks_msec() - from >= int((WALK_SECONDS - WALK_MEAN) * 1000.0):
			speeds.append(_flat(_avatar.velocity).length())
	Input.action_release(&"move_forward")
	await _until(func() -> bool: return _flat(_avatar.velocity).length() < 0.05, 1.0)
	var mean := 0.0
	for s in speeds:
		mean += s / maxf(speeds.size(), 1.0)
	print("        walking %s: %.2f m/s over the last %.1f s of %.1f" % [what, mean, WALK_MEAN, WALK_SECONDS])
	return mean

# --- the Warden ------------------------------------------------------------------

## The heaviest library ship, spawned and brought down on the pad the same way
## (its own flight computer's input), the starter hovering off to one side.
func _warden_on_the_pad() -> void:
	await _aboard()
	var library: ShipLibrary = _scene.get("library")
	var heaviest := &""
	var mass := 0.0
	for id in library.ids():
		var m := ShipStats.compute(library.grid(id), _starter.catalog).total_mass_kg
		if m > mass:
			mass = m
			heaviest = id
	print("pad     %s (%s, %.0f t, the heaviest library ship) onto the pad from %.0f m" % [library.name_of(heaviest), heaviest,
		mass / 1000.0, LAND_FROM])
	var aside := _off(_pad_dir, _across, STARTER_ASIDE)
	await _hold_at(aside, WATCH_HIGH * 4.0, _way_to(aside, _pad_dir))
	var grid := library.grid(heaviest)
	var big := _fleet.spawn(grid, Transform3D(Basis.IDENTITY, _centre() + _pad_dir * (_ground_r(_pad_dir) + 600.0)),
		true, "", ShipBlueprint.from_grid(grid, library.name_of(heaviest)))
	if big == null:
		_check(false, "land the heaviest library ship (%s) spawns" % heaviest)
		return
	big.flight_computer.assist_enabled = true
	_place(big, _pad_dir, LAND_FROM, _way_to(_pad_dir, _pool_dir))
	await _ground_built()
	var result := await _touch_down(big, false, library.name_of(heaviest))
	if bool(result["landed"]):
		await _boulder_shot("warden_pad", big, -_sunward(big))
	_fleet.remove(big, true)
	await _frames(2)

# --- the renders -----------------------------------------------------------------

## One render, once the air's mood has caught up, as oasis_<name>.png; its name
## and the eye's altitude over the ground.
func _shot(shot_name: String) -> void:
	await _seconds(0.3)
	await _frames(5)
	var image := root.get_viewport().get_texture().get_image()
	var file := "%s/oasis_%s.png" % [_out, shot_name]
	image.save_png(file)
	print("render  %s" % file)
	_images[shot_name] = image
	print("view    %s: the eye %s" % [shot_name, _eye_height()])

## How high the eye that sees the outside is, as text: over the ground once the
## world's ground is drawn, else over the world's radius (the warp's arrival).
func _eye_height() -> String:
	var cam: Camera3D = _starter.canopy_camera
	if _cam != null and _cam.current:
		cam = _cam
	elif _avatar.mode == Avatar.Mode.FIELD:
		cam = _avatar.camera
	var p := cam.global_position
	if _surface == null:
		return "%.1f km over the world's radius" % (((p - _centre()).length() - _planet.radius) / 1000.0)
	return "%.1f m over the ground" % ((p - _centre()).length() - _ground_r(_up(p)))

## oasis_sheet.png: OASIS_SHEET's renders at OASIS_TILE size.
func _oasis_sheet() -> void:
	var names: Array = OASIS_SHEET.filter(func(n: String) -> bool: return _images.has(n))
	if names.is_empty():
		return
	var rows := ceili(float(names.size()) / OASIS_COLUMNS)
	var sheet := Image.create_empty(OASIS_TILE.x * OASIS_COLUMNS, OASIS_TILE.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in names.size():
		var tile := (_images[names[i]] as Image).duplicate() as Image
		tile.convert(Image.FORMAT_RGBA8)
		tile.resize(OASIS_TILE.x, OASIS_TILE.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, OASIS_TILE), Vector2i((i % OASIS_COLUMNS) * OASIS_TILE.x, (i / OASIS_COLUMNS) * OASIS_TILE.y))
	var file := "%s/oasis_sheet.png" % _out
	sheet.save_png(file)
	print("render  %s (in order: %s)" % [file, ", ".join(names)])
