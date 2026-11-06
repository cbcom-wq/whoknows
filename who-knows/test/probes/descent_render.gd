extends "res://test/probes/landing_play.gd"

# The descent through a world's air (docs/superpowers/specs/
# 2026-11-03-desert-world-design.md §6.2, §10; phase 1's Task 3), rendered for
# descent.html's stages in the flight scene, by the system's largest planet
# with thick air and the sand palette (else the largest thick one, else the
# largest with air), on its day side with the sun 30 deg up, as the oasis will
# have it. Seated is at the starter's helm, looking out of its canopy.
#
#   stage 1  hovering at 1.2 x the air top, over the air: seated, toward the
#            sun (stage1_sun), and straight at the star, wide (stage1_star) and
#            at 15 deg (stage1_star_close), and that with the star's mesh hidden
#            (stage1_star_bare: its disc hides the sky's glow); today's sky
#            checked: unturned, the light in it, its own 1 deg sun glow on the
#            star, no StarHalo; then the glow round the world's edge (LimbGlow)
#            from 3 and 1.5 radii off its centre on the day side, seated and
#            from the chase camera (stage1_<k>_seated, _chase), 2 radii off on
#            the night side, backlit (stage1_night), and across the air top,
#            200 m over it and 200 m under it, at the limb (stage1_top_above,
#            stage1_top_below), which must not jump;
#   stage 2  hovering at 0.95, 0.6 and 0.3 x the air top: seated, to the
#            horizon (stage2_<k>_horizon) and pitched 30 deg down (_down);
#   stage 3  at 1000 m and 300 m: seated, toward the sun (stage3_<h>_sun) and
#            away from it (_away); the frame rate seated at 300 m;
#   stage 4  landed on the flattest ground near: seated (stage4_seated, and the
#            frame rate); standing in the cabin at a porthole (stage4_porthole);
#            in the airlock, the outer hatch open (stage4_hatch); on foot, eye
#            1.6 m over the ground, 6 m off: away from the sun (stage4_away),
#            toward it (stage4_sun) and straight at it (stage4_halo), 60 deg up
#            (stage4_up) and back at the ship (stage4_ship); the air on the
#            ground checked, and the frame rate standing there;
#   dive     seated, from the air top to 300 m at the speed limit, the sky
#            recoloured all the way: the frame rate over each 5 s of it, the
#            slowest checked; then the same dive squeezed into 5 s (about 8x
#            the limit), with the mood at work and held still, printed: what
#            streaming the ground that fast costs;
#   night    landed on the night side, on foot, to the horizon (night_ground);
#            seated 1000 m over the terminator, toward the sun (night_terminator);
#   thin     on the largest planet with thin air, if there is one: stage 3 at
#            300 m and stage 4 on foot, prefixed thin_.
#
# Every render prints the air there: altitude, air, sun_up, the dust's density,
# the fog's, and the sky's top and horizon colours. descent_sheet.png puts
# eight of them side by side. The renders on the sun's side also print where
# the sky's own sun glow would sit against the star, and where the StarHalo
# sits: the sky's glow sat 31 deg off the star once the sky turned (the engine
# leaves the light's way unturned), so in air the light is out of the sky and
# the StarHalo glows on the star instead; over the air the sky is today's,
# unturned, with its own glow. The controls card is hidden (H), as a
# player would. Run it WITHOUT --headless:
#
#   godot --path who-knows --resolution 1280x720 \
#     --script res://test/probes/descent_render.gd -- <abs out dir> [palette]
#
# A palette's name (SpacePalette.WORLDS: ochre, slate, rust, sage, ash,
# heather, sand, ice) after the directory draws both planets in it instead.

## The sun's height over the horizon by day, as the oasis will have it.
const SUN_DEG := 30.0
## Stage 1's height, a share of the air top: over the air, as on approach; and
## the close shot of the star's own sun glow there, its field of view in deg.
const STAGE1 := 1.2
const STAR_CLOSE_FOV := 15.0
## The glow round the edge: how far off the centre, in radii, the day side shots
## are taken; the night side's; and how far over and under the air top the
## crossing pair is, m.
const LIMB_RADII := ["3", "1.5"]
const LIMB_NIGHT_RADII := 2.0
const TOP_STEP := 200.0
## Stage 2's heights, each [its name, its share of the air top].
const STAGE2 := [["0.95", 0.95], ["0.6", 0.6], ["0.3", 0.3]]
const STAGE2_PITCH := 30.0
## Stage 3's heights over the ground, m.
const STAGE3: Array[float] = [1000.0, 300.0]
const LOW := 300.0
const TERMINATOR_HEIGHT := 1000.0
## On foot: how far up the shot toward the sun looks, so the sun and the
## horizon are both in it; how far up the look overhead goes; and at night.
const SUN_PITCH := 10.0
const UP_PITCH := 60.0
const NIGHT_PITCH := 5.0
## Standing at a porthole: your middle this far in from the wall.
const PORTHOLE_BACK := 0.5
const FPS_SECONDS := 5.0
const FPS_FLOOR := 120.0
const DIVE_SECONDS := 5.0
## The contact sheet: each render at this size, day over night.
const TILE := Vector2i(320, 180)
const SHEET := [
	["stage1_1.5_seated", "stage2_0.6_horizon", "stage3_1000_sun", "stage4_away", "stage4_up"],
	["stage1_night", "night_ground", "stage4_seated", "stage4_porthole", "thin_stage4_away"],
]

## The largest planet with thin air, for the second pass; null if none.
var _thin: SystemBody
## The renders the contact sheet takes, by name.
var _images := {}
## The way to the sun along the ground at `_spot`, and across it.
var _sun_flat := Vector3.FORWARD
var _across := Vector3.RIGHT
## The fog's density in stage 2 at 0.95 x the air top, and on foot.
var _top_fog := -1.0
var _ground_fog := -1.0
var _readings: Array[String] = []

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
		print("descent no planet to come down on")
		quit(1)
		return
	_starter.flight_computer.assist_enabled = true
	_day_side()
	await _sit(_starter)
	await _hide_the_card()
	await _stage1()
	await _stage2()
	await _stage3()
	await _stage4()
	await _dive()
	await _night()
	await _thin_air()
	_sheet()
	_let_go()
	print("        the frame rate, each over %.0f s:" % FPS_SECONDS)
	for line in _readings:
		print("        %s" % line)
	print("descent %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)

## The largest planet with thick air and the sand palette, else the largest
## thick one, else landing_play's choice (the largest with air, else the
## largest). The largest thin one is kept for the second pass.
func _pick_planet(system: SystemRecipe) -> SystemBody:
	var sand_at := _palette_index(&"sand")
	var sand: SystemBody = null
	var thick: SystemBody = null
	var thin: SystemBody = null
	for p in system.planets():
		var r := p.recipe
		print("        planet %s (%s): radius %.1f km, air %s, palette %s" % [p.name, p.id, p.radius / 1000.0,
			WorldRecipe.Atmosphere.keys()[r.atmosphere], SpacePalette.WORLDS[r.palette][&"name"]])
		if r.atmosphere == WorldRecipe.Atmosphere.THICK:
			if thick == null or p.radius > thick.radius:
				thick = p
			if r.palette == sand_at and (sand == null or p.radius > sand.radius):
				sand = p
		elif r.atmosphere == WorldRecipe.Atmosphere.THIN:
			if thin == null or p.radius > thin.radius:
				thin = p
	var chosen: SystemBody = sand if sand != null else thick if thick != null else super(system)
	_thin = thin if thin != chosen else null
	print("        chosen: %s (%s); the thin pass: %s" % [chosen.name,
		"thick, sand" if chosen == sand else "thick, not sand: no thick planet is sand" if chosen == thick
		else "no planet is thick", "%s (%s)" % [_thin.name, _thin.id] if _thin != null else "none"])
	# A palette to see in its place, by name, after the output directory: the
	# eight sky pairs are judged from renders (the brief's Checkpoint A).
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		var at := _palette_index(StringName(args[1]))
		if at < 0:
			print("        no palette called %s: %s's own" % [args[1], chosen.name])
		else:
			chosen.recipe.palette = at
			if _thin != null:
				_thin.recipe.palette = at
			print("        both planets drawn in the %s palette instead" % args[1])
	return chosen

static func _palette_index(palette_name: StringName) -> int:
	for i in SpacePalette.WORLDS.size():
		if SpacePalette.WORLDS[i][&"name"] == palette_name:
			return i
	return -1

## A spot on `_planet`'s day side with the sun SUN_DEG over the horizon, the
## flattest near it; the ways toward the sun and across it there.
func _day_side() -> void:
	var to_star := _to_star()
	var near := to_star.rotated(_tangents(to_star)[0], deg_to_rad(90.0 - SUN_DEG)).normalized()
	_spot = _flattest(near, FLAT_REACH)
	_sun_flat = (to_star - _spot * to_star.dot(_spot)).normalized()
	_across = _spot.cross(_sun_flat).normalized()
	_forward = _across
	print("        day spot on %s: the sun %.1f deg up there; within %.0f m the ground rises or falls %.2f m" % [
		_planet.name, 90.0 - rad_to_deg(_spot.angle_to(to_star)), FLAT_REACH, _spread(_spot, FLAT_REACH)])

## H, seated, as the player hides the controls card: it would cover a third of
## every render's sky.
func _hide_the_card() -> void:
	await _press(KEY_H)
	var how := "no card found"
	for n in _scene.find_children("*", "Control", true, false):
		if n is ControlsCard:
			var card := n as ControlsCard
			how = "by H" if not card.shown else "by hand, H not taken"
			card.shown = false
			card.visible = false
	print("        the controls card hidden (%s)" % how)

## From `_planet`'s centre toward the star.
func _to_star() -> Vector3:
	var star: SystemBody = (_scene.get("system") as SystemRecipe).star
	return star.point.minus(_planet.point).normalized()

# --- the stages ------------------------------------------------------------------

## Stage 1: the approach, over the air. Seated toward the sun's way, then
## straight at the star from there, wide and close: no air is today's sky,
## unturned, the light in it and its own sun glow round the star; checked.
func _stage1() -> void:
	var h := _planet.recipe.air_top() * STAGE1
	print("stage 1 the approach: %.0f m over the ground, %.1f x the air top" % [h, STAGE1])
	await _hold_at(_spot, h, _sun_flat)
	await _shot("stage1_sun")
	var cam := _starter.canopy_camera
	_halo_line("stage1_sun", cam)
	var star := _stars.proxy((_scene.get("system") as SystemRecipe).star.id)
	var at := cam.global_position
	var pose := Transform3D(Basis.looking_at(star.global_position - at, _spot), at)
	# From the helm's eye, with the outside alone in view: your own hull is
	# round that eye, and a window leaves it out.
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "ProbeCamera"
		_cam.far = BodyProxy.VIEW_FAR
		_scene.add_child(_cam)
		_cam.add_to_group(Universe.EXTERIOR_SPACE)
	_cam.cull_mask = 1
	await _camera_shot("stage1_star", pose)
	var fov := _cam.fov
	_cam.fov = STAR_CLOSE_FOV
	await _camera_shot("stage1_star_close", pose)
	# The star's own disc is far wider than the sky's glow, so the glow is
	# behind it: one shot with the star's mesh hidden shows where the sky draws
	# its sun.
	var disc := star.get_node("Far") as MeshInstance3D
	print("        the star's disc %.1f deg from its middle to its rim, the sky's sun glow %.1f" % [
		rad_to_deg(asin(minf(star.body.radius / star.distance, 1.0))), _sky().sun_angle_max])
	disc.visible = false
	await _camera_shot("stage1_star_bare", pose)
	disc.visible = true
	_cam.fov = fov
	_cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	var env := _env()
	var sun := _scene.get_node("DirectionalLight3D") as DirectionalLight3D
	var glow := Basis.from_euler(env.sky_rotation) * _sun_dir()
	var off := rad_to_deg(glow.angle_to(star.global_position - at))
	var turned := rad_to_deg(Basis.from_euler(env.sky_rotation).get_rotation_quaternion().get_angle())
	_check(not env.fog_enabled and env.sky_rotation.is_zero_approx() and turned < 0.01
		and sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY and off < 0.1
		and is_equal_approx(_sky().sun_angle_max, AirMood.SPACE_HALO_DEG) and not _stars.halo.is_visible_in_tree(),
		"stage1 over the air, today's sky: fog %s, the sky turned %.2f deg (0), the light %s, its own %.1f deg sun glow %.3f deg off the star (under 0.1), the StarHalo %s" % [
		"on" if env.fog_enabled else "off", turned,
		"in the sky" if sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY else "out of the sky",
		_sky().sun_angle_max, off, "showing" if _stars.halo.is_visible_in_tree() else "hidden"])
	await _limb()

## The glow round the world's edge from outside (spec §6.2 stage 1, §6.3): on
## the day side from LIMB_RADII radii off the centre, looking at the world,
## seated and from the chase camera; on the night side, backlit; and across the
## air top, TOP_STEP m either side, looking at the limb: the two must not jump.
func _limb() -> void:
	var r := _planet.radius
	var top := _planet.recipe.air_top()
	var down := Basis(_level(_spot, _sun_flat).x.normalized(), deg_to_rad(-90.0))
	print("stage 1 the limb glow: radius %.0f km, the air top %.0f km over it" % [r / 1000.0, top / 1000.0])
	for k in LIMB_RADII:
		await _hold_at(_spot, r * float(k) - r, _sun_flat, down)
		await _shot("stage1_%s_seated" % k)
		_limb_line("stage1_%s_seated" % k)
		await _outside_shot("stage1_%s_chase" % k, _starter, Vector3(0.0, 8.0, 30.0))
	var night := -_to_star()
	var night_forward := _tangents(night)[0]
	await _hold_at(night, r * LIMB_NIGHT_RADII - r, night_forward,
		Basis(_level(night, night_forward).x.normalized(), deg_to_rad(-90.0)))
	await _shot("stage1_night")
	_limb_line("stage1_night")
	var crossing: Array[float] = []
	for step in [TOP_STEP, -TOP_STEP]:
		# Pitched down by the limb's dip, the limb itself is at the middle.
		var dip := acos(r / (r + top + step))
		await _hold_at(_spot, top + step, _across, Basis(_level(_spot, _across).x.normalized(), -dip))
		var shot_name := "stage1_top_above" if step > 0.0 else "stage1_top_below"
		await _shot(shot_name)
		crossing.append(_limb_line(shot_name))
	# The limb itself moves as the eye does (0.5 deg over these 400 m), so what
	# must not jump is the band beyond it.
	var jump := rad_to_deg(absf(crossing[0] - crossing[1]))
	_check(jump < 0.05, "stage1 across the air top the glow's band beyond the limb differs by %.3f deg between %.0f m over and %.0f m under it (under 0.05)" % [
		jump, TOP_STEP, TOP_STEP])

## What the glow is doing now, printed; the width in rad of its band beyond the
## limb.
func _limb_line(shot_name: String) -> float:
	var proxy := _stars.proxy(_planet.id)
	var glow := proxy.get_node("LimbGlow") as LimbGlow
	var d := proxy.distance
	var a := LimbGlow.angles(_planet.radius, _planet.recipe.air_top(), d)
	print("limb    %s: %.2f radii off, %s, the ring %.2f to %.2f deg from the middle (the limb %.2f), strength %.2f, air %.3f" % [
		shot_name, d / _planet.radius, "showing" if glow.visible else "hidden", rad_to_deg(a.x), rad_to_deg(a.y),
		rad_to_deg(asin(minf(_planet.radius / d, 1.0))), LimbGlow.strength(_planet.radius, d, _stars.whereabouts.air()),
		_stars.whereabouts.air()])
	return a.y - asin(minf(_planet.radius / d, 1.0))

## Stage 2: into the air, at 0.95, 0.6 and 0.3 x the air top.
func _stage2() -> void:
	var top := _planet.recipe.air_top()
	print("stage 2 into the air: the air top %.0f m over the ground" % top)
	for s in STAGE2:
		var k: String = s[0]
		var h: float = top * float(s[1])
		await _hold_at(_spot, h, _across)
		await _shot("stage2_%s_horizon" % k)
		if k == "0.95":
			_top_fog = _env().fog_density
		var right := _level(_spot, _across).x.normalized()
		await _hold_at(_spot, h, _across, Basis(right, deg_to_rad(-STAGE2_PITCH)))
		await _shot("stage2_%s_down" % k)

## Stage 3: flying low, toward the sun and away; then hovering for real at
## LOW, the frame rate seated there.
func _stage3() -> void:
	print("stage 3 flying low")
	for h in STAGE3:
		await _hold_at(_spot, h, _sun_flat)
		await _shot("stage3_%d_sun" % roundi(h))
		_halo_line("stage3_%d_sun" % roundi(h), _starter.canopy_camera)
		await _hold_at(_spot, h, -_sun_flat)
		await _shot("stage3_%d_away" % roundi(h))
	_starter.exterior.freeze = false
	await _seconds(2.0)
	await _reading("seated at the starter's helm hovering %.0f m over the ground, away from the sun" % _alt(_starter))

## Stage 4: on the ground. Seated, at a porthole, in the open airlock, and on
## foot.
func _stage4() -> void:
	print("stage 4 on the ground")
	if not await _land(_spot, _across, "stage4"):
		return
	await _seconds(1.0)
	await _shot("stage4_seated")
	await _reading("seated at the starter's helm on the ground")
	_director.stand_now()
	await _frames(3)
	await _porthole("stage4_porthole")
	var lock: Airlock = _starter.airlocks.values()[0]
	if not await _out_through(lock, "stage4_hatch", "stage4"):
		return
	await _on_foot("stage4", true)
	var env := _env()
	var sky := _sky()
	_ground_fog = env.fog_density
	_check(is_zero_approx(_stars.dust.density) and env.fog_enabled
		and not sky.sky_top_color.is_equal_approx(SpacePalette.SPACE_SKY_TOP),
		"stage4 on foot on the ground: the dust's density %.3f (0), fog %s (on), the sky's top #%s (not space's #%s)" % [
		_stars.dust.density, "on" if env.fog_enabled else "off", sky.sky_top_color.to_html(false),
		SpacePalette.SPACE_SKY_TOP.to_html(false)])
	_check(_top_fog >= 0.0 and _top_fog < _ground_fog * 0.25,
		"stage2 at 0.95 x the air top the fog's density %s is under 25%% of the ground's %s (%.1f%%)" % [
		_sci(_top_fog), _sci(_ground_fog),
		_top_fog / maxf(_ground_fog, 1e-12) * 100.0])
	_face(_starter.exterior.global_position - _avatar.global_position)
	_avatar.set_head_pitch(0.0)
	await _seconds(0.5)
	await _reading("standing on foot %.1f m off the hatch, facing the ship" % _flat(_avatar.global_position - lock.beacon()).length())

## Seated, a dive from the air top to LOW over the ground as the flight
## computer lets you fly one, at the altitude's speed limit all the way, the
## air's mood left to its own loop: the frame rate over each FPS_SECONDS of it,
## the slowest checked. Under the floor, the dive again with the sky's
## reflections off (the brief's fallback). Then the same dive squeezed into
## DIVE_SECONDS, eight times the limit or so, with the mood at work and held
## still: what streaming the ground that fast costs, and that the sky is not it.
func _dive() -> void:
	await _aboard()
	var top := _planet.recipe.air_top()
	var worst := await _dive_at_limit(top, "")
	if worst < FPS_FLOOR:
		var env := _env()
		var was := env.reflected_light_source
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		await _dive_at_limit(top, ", the sky's reflections off")
		env.reflected_light_source = was
	_check(worst >= FPS_FLOOR, "dive fps %.0f at the slowest seated through a dive at the speed limit from the air top to %.0f m (at least %.0f)" % [
		worst, LOW, FPS_FLOOR])
	await _squeezed_dive(top, "")
	var mood := _scene.get("air_mood") as AirMood
	mood.set_physics_process(false)
	await _squeezed_dive(top, ", the mood held still (nothing recoloured)")
	mood.set_physics_process(true)

## The hull moved each physics tick by `step` (callable: the height now, m over
## the ground -> the height next), the mood's writes counted: [writes, the
## last mood seen, the height].
func _diving(from_h: float, step: Callable) -> Array:
	await _hold_at(_spot, from_h, _sun_flat)
	await _seconds(1.0)
	var mood := _scene.get("air_mood") as AirMood
	var seen := [0, mood.last_mood, from_h]
	var move := func() -> void:
		seen[2] = step.call(float(seen[2]))
		_set_hull(_starter, _spot, float(seen[2]), _sun_flat)
		if not is_same(mood.last_mood, seen[1]):
			seen[0] += 1
			seen[1] = mood.last_mood
	physics_frame.connect(move)
	seen.append(move)
	return seen

## Stops what `_diving` started. The mover holds `seen` and `seen` holds the
## mover: dropping it breaks the loop, which would otherwise leak at exit.
func _stop_diving(seen: Array) -> void:
	physics_frame.disconnect(seen[3])
	seen.resize(3)

## From `from_h` down to LOW at the speed limit for the altitude, the frame
## rate over each FPS_SECONDS; returns the slowest.
func _dive_at_limit(from_h: float, how: String) -> float:
	var fc := _starter.flight_computer
	var dt := 1.0 / Engine.physics_ticks_per_second
	var seen := await _diving(from_h, func(h: float) -> float: return maxf(h - fc.speed_limit_now() * dt, LOW))
	var worst := INF
	var t0 := Time.get_ticks_msec()
	var shifts := _universe.shifts
	var parts: Array[String] = []
	while float(seen[2]) > LOW + 0.5:
		var h0 := float(seen[2])
		var a0 := _stars.whereabouts.air()
		var w0 := int(seen[0])
		var fps := await _fps(FPS_SECONDS)
		worst = minf(worst, fps)
		parts.append("%.0f (%.0f-%.0f m, air %.3f-%.3f, %d writes)" % [fps, h0, float(seen[2]), a0,
			_stars.whereabouts.air(), int(seen[0]) - w0])
	_stop_diving(seen)
	var line := "fps     %.0f at the slowest seated through a dive%s at the speed limit from the air top (%.0f m) to %.0f m in %.0f s, the mood written %d times, the origin shifted %d times %s; each %.0f s: %s" % [
		worst, how, from_h, float(seen[2]), (Time.get_ticks_msec() - t0) / 1000.0, int(seen[0]),
		_universe.shifts - shifts, _ms(), FPS_SECONDS, ", ".join(parts)]
	print(line)
	_readings.append(line)
	return worst

## From `from_h` to LOW evenly in DIVE_SECONDS; returns the frame rate.
func _squeezed_dive(from_h: float, how: String) -> float:
	# When the first tick moved it.
	var t0 := [-1]
	var seen := await _diving(from_h, func(_h: float) -> float:
		if int(t0[0]) < 0:
			t0[0] = Time.get_ticks_usec()
		return lerpf(from_h, LOW, clampf((Time.get_ticks_usec() - int(t0[0])) / (DIVE_SECONDS * 1e6), 0.0, 1.0)))
	var air_from := _stars.whereabouts.air()
	var shifts := _universe.shifts
	var fps := await _fps(DIVE_SECONDS)
	_stop_diving(seen)
	var line := "fps     %.0f seated through the same dive squeezed into %.0f s%s (%.0f m/s): %.0f m to %.0f m, the air %.3f to %.3f, the mood written %d times, the origin shifted %d times %s" % [
		fps, DIVE_SECONDS, how, (from_h - LOW) / DIVE_SECONDS, from_h, float(seen[2]), air_from,
		_stars.whereabouts.air(), int(seen[0]), _universe.shifts - shifts, _ms()]
	print(line)
	_readings.append(line)
	return fps

## The night side: on foot by the landed starter, and seated over the
## terminator.
func _night() -> void:
	print("night")
	await _aboard()
	var to_star := _to_star()
	var night := -to_star
	if await _land(night, _tangents(night)[0], "night"):
		_director.stand_now()
		await _frames(3)
		var lock: Airlock = _starter.airlocks.values()[0]
		if await _out_through(lock, "", "night"):
			_avatar.set_head_pitch(deg_to_rad(NIGHT_PITCH))
			await _seconds(0.5)
			await _shot("night_ground")
	await _aboard()
	var axis := _tangents(to_star)[0]
	var terminator := to_star.rotated(axis, PI * 0.5).normalized()
	var sunward := (to_star - terminator * to_star.dot(terminator)).normalized()
	await _hold_at(terminator, TERMINATOR_HEIGHT, sunward)
	await _shot("night_terminator")

## Thin air: the largest planet with it, if any: stage 3 at LOW and stage 4
## on foot.
func _thin_air() -> void:
	if _thin == null:
		print("SKIPPED thin: no other planet in the system has thin air")
		return
	print("thin air")
	await _aboard()
	_starter.exterior.freeze = false
	if not await _hop_to(_thin):
		return
	_day_side()
	await _hold_at(_spot, LOW, _sun_flat)
	await _shot("thin_stage3_300_sun")
	_halo_line("thin_stage3_300_sun", _starter.canopy_camera)
	await _hold_at(_spot, LOW, -_sun_flat)
	await _shot("thin_stage3_300_away")
	if not await _land(_spot, _across, "thin"):
		return
	_director.stand_now()
	await _frames(3)
	var lock: Airlock = _starter.airlocks.values()[0]
	if await _out_through(lock, "", "thin"):
		await _on_foot("thin_stage4", false)

# --- the pieces ----------------------------------------------------------------

## The starter frozen `height` m over the ground at `dir`, nosed along
## `forward` and turned by `tilt`, at rest; its ground drawn.
func _hold_at(dir: Vector3, height: float, forward: Vector3, tilt := Basis.IDENTITY) -> void:
	await _unland()
	_place(_starter, dir, height, forward, tilt)
	_starter.exterior.freeze = true
	await _ground_built()

## Out of LANDED, as only the pilot's translation takes a ship out of it: up
## on the stick, seated, until the hull leaves it and thaws.
func _unland() -> void:
	if not _starter.landing.is_landed():
		return
	_stick_y(1.0)
	var left := await _until(func() -> bool: return not _starter.landing.is_landed(), 2.0)
	_stick_y(0.0)
	if not left:
		_check(false, "the landed starter leaves LANDED on the stick (seated %s)" % _director.is_seated)

## `ship`'s hull over `dir`, `height` m over the ground and level, and nothing
## else: the scene's own ticks place the worlds and shift the origin.
func _set_hull(ship: Ship, dir: Vector3, height: float, forward: Vector3) -> void:
	var up := dir.normalized()
	ship.exterior.global_transform = Transform3D(_level(up, forward),
		_centre() + up * (_ground_r(up) + ship.stance_depth() + height))

## The starter set down on the flattest ground near `near`, nosed along
## `forward`, as landing_play's night side does it. True once LANDED.
func _land(near: Vector3, forward: Vector3, step: String) -> bool:
	var at := _flattest(near, FLAT_REACH)
	await _unland()
	_starter.exterior.freeze = false
	_starter.flight_computer.assist_enabled = true
	_place(_starter, at, 3.0, forward)
	await _ground_built()
	var legs := _starter.exterior_builder.legs()
	await _until(func() -> bool: return legs.is_down(), 4.0)
	var end := Time.get_ticks_msec() + 15000
	while _starter.landing.state == LandingMonitor.State.FLYING and Time.get_ticks_msec() < end:
		_hold_sink(_starter, 1.0)
		await physics_frame
	_stick_y(0.0)
	var landed := await _until(func() -> bool: return _starter.landing.is_landed(), 10.0)
	_check(landed, "%s the starter landed on %s, the sun %.0f deg up, tilt %.1f deg; within %.0f m the ground rises or falls %.2f m" % [
		step, _planet.name, 90.0 - rad_to_deg(at.angle_to(_to_star())), rad_to_deg(_starter.landing.tilt()),
		FLAT_REACH, _spread(at, FLAT_REACH)])
	return landed

## Back aboard from outside, as a rescue brings you in, and to the helm.
func _aboard() -> void:
	if _avatar.is_outside():
		var deck: Transform3D = _scene.call("_deck_spot", _starter)
		_avatar.enter_plating(_starter.interior, _starter.interior.global_transform * deck, 0.0, Vector3.ZERO,
			Quaternion.IDENTITY)
		await _seconds(1.0)
	if not _director.is_seated:
		await _sit(_starter)

## The first porthole in the starter's cabin, as its interior layout has it:
## {coord, normal, ...}; empty if it has none.
static func _porthole_face(ship: Ship) -> Dictionary:
	for face in ship.interior_builder.layout().faces():
		if face["kind"] == InteriorLayout.Kind.WALL and face["porthole"] and face["owner"]:
			return face
	return {}

## Standing in the cabin at a porthole, PORTHOLE_BACK in from its wall, looking
## at it: the window must show the sky.
func _porthole(shot_name: String) -> void:
	var face := _porthole_face(_starter)
	if face.is_empty():
		_check(false, "%s the starter has a porthole" % shot_name)
		return
	var coord: Vector3i = face["coord"]
	var normal := Vector3(face["normal"] as Vector3i)
	var wall := DeckPaths.floor_point(coord) + normal * ShipGrid.CELL_SIZE * 0.5
	var stand := wall - normal * PORTHOLE_BACK
	_avatar.place(_starter.interior.global_transform * Transform3D(Basis.looking_at(normal, Vector3.UP), stand))
	var eye := _avatar.head.position.y
	_avatar.set_head_pitch(atan2(InteriorProps.PORTHOLE_HEIGHT - eye, PORTHOLE_BACK))
	await _seconds(0.5)
	var out := _starter.exterior.global_basis * normal
	print("        at the porthole of cell %s (zone %s), %.2f m in from its wall, eye %.2f m over the deck, pitched %.0f deg; it looks out %.0f deg from the sun's way" % [
		coord, face["zone"], PORTHOLE_BACK, eye, rad_to_deg(_avatar.head_pitch()),
		rad_to_deg(out.angle_to(_sun_way(_up(_starter.exterior.global_position))))])
	await _shot(shot_name)

## Into the airlock room, the outer hatch opened by its room panel (rendered
## from the room looking out, as `hatch_shot`, unless it is empty), its ramp
## down, and out down it on your feet to BESIDE m off the hatch. True once on
## foot outside.
func _out_through(lock: Airlock, hatch_shot: String, step: String) -> bool:
	await _into_the_room(_starter, lock)
	lock.room.room_panel.interact(_avatar)
	var opened := await _until(func() -> bool: return lock.cycle.outer_open >= 1.0, 12.0)
	var ramp := lock.alcove.ramp
	await _until(func() -> bool: return ramp == null or ramp.is_down(), 6.0)
	if hatch_shot != "":
		await _seconds(0.5)
		await _shot(hatch_shot)
	Input.action_press(&"move_forward")
	var out := await _until(func() -> bool: return _avatar.mode != Avatar.Mode.PLATING, 4.0)
	_check(opened and out and _avatar.mode == Avatar.Mode.FIELD,
		"%s the outer hatch opens and you walk out of the starter's airlock on foot (%s)" % [step,
		Avatar.Mode.keys()[_avatar.mode]])
	if _avatar.mode != Avatar.Mode.FIELD:
		Input.action_release(&"move_forward")
		return false
	await _walk_away(func() -> Vector3: return lock.beacon(), BESIDE, 6.0)
	return true

## On foot: away from the sun, toward it and straight at it, and with `full`
## 60 deg up and back at the ship. Your eye's height over the ground is said.
func _on_foot(prefix: String, full: bool) -> void:
	var sun_way := _flat(_sun_dir())
	var eye := _gravity.altitude_at(_avatar.camera.global_position)
	print("        on foot %.1f m from the hull's middle along the ground, eye %.2f m over the ground (%.2f over your feet)" % [
		_flat(_avatar.global_position - _starter.exterior.global_position).length(), eye,
		(_avatar.camera.global_position - _avatar.global_position).dot(_avatar.up)])
	_face(-sun_way)
	_avatar.set_head_pitch(0.0)
	await _seconds(0.5)
	await _shot(prefix + "_away")
	_face(sun_way)
	_avatar.set_head_pitch(deg_to_rad(SUN_PITCH))
	await _seconds(0.5)
	await _shot(prefix + "_sun")
	_halo_line(prefix + "_sun", _avatar.camera)
	var star := _stars.proxy((_scene.get("system") as SystemRecipe).star.id)
	var at := _avatar.camera.global_position
	await _camera_shot(prefix + "_halo", Transform3D(Basis.looking_at(star.global_position - at, _avatar.up), at))
	_halo_line(prefix + "_halo", _cam)
	var halo := _stars.halo
	var sun := _scene.get_node("DirectionalLight3D") as DirectionalLight3D
	var off := rad_to_deg((halo.global_position - at).angle_to(star.global_position - at))
	_check(sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY and halo.is_visible_in_tree() and off < 0.1,
		"%s the sun's glow is the StarHalo's, on the star: %.3f deg off it (under 0.1), strength %.2f; the light out of the sky %s" % [
		prefix, off, halo.strength(), sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY])
	if not full:
		return
	_face(-sun_way)
	_avatar.set_head_pitch(deg_to_rad(UP_PITCH))
	await _seconds(0.5)
	await _shot(prefix + "_up")
	var to_ship := _starter.exterior.global_position - _avatar.camera.global_position
	_face(to_ship)
	_avatar.set_head_pitch(atan2(to_ship.dot(_avatar.up), _flat(to_ship).length()))
	await _seconds(0.5)
	await _shot(prefix + "_ship")

## Toward the sun, as the scene's light comes from it.
func _sun_dir() -> Vector3:
	return (_scene.get_node("DirectionalLight3D") as DirectionalLight3D).global_basis.z.normalized()

## The way to the sun along the ground under `up`.
func _sun_way(up: Vector3) -> Vector3:
	var d := _sun_dir()
	return (d - up * d.dot(up)).normalized()

## The debug hop to `p`, as landing_play's first: its ground drawn.
func _hop_to(p: SystemBody) -> bool:
	var system: SystemRecipe = _scene.get("system")
	await _unland()
	await _until(func() -> bool:
		return _starter.airlocks.values().all(func(a: Airlock) -> bool: return a.busy() == ""), 15.0)
	_planet = p
	_scene.set("hop_index", system.bodies.find(p) - 1)
	var hopped: bool = _scene.call("hop", 1)
	await _frames(2)
	var proxy := _stars.proxy(p.id)
	_surface = proxy.surface() if proxy != null else null
	var r := p.recipe
	print("planet  %s (%s): radius %.1f km, air %s to %.1f km over the radius, palette %s" % [p.name, p.id,
		p.radius / 1000.0, WorldRecipe.Atmosphere.keys()[r.atmosphere], r.air_top() / 1000.0,
		SpacePalette.WORLDS[r.palette][&"name"]])
	_check(hopped and _surface != null, "thin the hop puts the starter 3 km off %s, its ground drawn" % p.name)
	return _surface != null

## Frames a second over FPS_SECONDS, `what` they are of, against the floor;
## under it, measured again with the sky's reflections off.
func _reading(what: String) -> float:
	var fps := await _fps(FPS_SECONDS)
	var line := "fps     %.0f %s %s" % [fps, what, _ms()]
	print(line)
	_readings.append(line)
	if fps < FPS_FLOOR:
		var env := _env()
		var was := env.reflected_light_source
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		var off := await _fps(FPS_SECONDS)
		env.reflected_light_source = was
		var again := "fps     %.0f %s, the sky's reflections off %s" % [off, what, _ms()]
		print(again)
		_readings.append(again)
	_check(fps >= FPS_FLOOR, "fps %.0f %s (at least %.0f)" % [fps, what, FPS_FLOOR])
	return fps

# --- the renders -----------------------------------------------------------------

## One render, once the air's mood has caught up by its own loop, and the air
## where the focus is.
func _shot(shot_name: String) -> void:
	await _seconds(0.3)
	await _frames(5)
	var image := root.get_viewport().get_texture().get_image()
	var file := "%s/descent_%s.png" % [_out, shot_name]
	image.save_png(file)
	print("render  %s" % file)
	for row: Array in SHEET:
		if row.has(shot_name):
			_images[shot_name] = image
	var w := _stars.whereabouts
	var env := _env()
	var sky := _sky()
	print("air     %s: altitude %.0f m, air %.4f, sun_up %.3f, dust %.3f, fog %s %s, sky top #%s horizon #%s, halo %.1f deg" % [
		shot_name, w.altitude(), w.air(), w.sun_up(), _stars.dust.density, "on" if env.fog_enabled else "off",
		_sci(env.fog_density), sky.sky_top_color.to_html(false),
		sky.sky_horizon_color.to_html(false), sky.sun_angle_max])

## Where the sky's own sun glow sits against the star, seen from `cam`: the
## light's way (which the sky shader is handed), that way turned by the sky's
## rotation and turned back, each in degrees off the star's proxy and where it
## falls on screen. If the engine leaves the light unturned while it turns the
## sky, the glow shows at the turned way, not on the star.
func _halo_line(shot_name: String, cam: Camera3D) -> void:
	var star := _stars.proxy((_scene.get("system") as SystemRecipe).star.id)
	var from := cam.global_position
	var to_star := (star.global_position - from).normalized()
	var light := _sun_dir()
	var r := Basis.from_euler(_env().sky_rotation)
	var ways := {"the light": light, "turned by the sky": (r * light).normalized(),
		"turned back": (r.inverse() * light).normalized()}
	var parts: Array[String] = ["the star %s" % _on_screen(cam, to_star)]
	for way: String in ways:
		var d: Vector3 = ways[way]
		parts.append("%s %.2f deg off it %s" % [way, rad_to_deg(d.angle_to(to_star)), _on_screen(cam, d)])
	var sun := _scene.get_node("DirectionalLight3D") as DirectionalLight3D
	var halo := _stars.halo
	var off := halo.global_position - from
	print("halo    %s: the sky turned %.1f deg; the light %s; %s; the StarHalo %.2f deg off the star, %.1f deg from its middle to its rim, strength %.2f%s" % [
		shot_name, rad_to_deg(r.get_rotation_quaternion().get_angle()),
		"in the sky too" if sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY else "out of the sky",
		"; ".join(parts), rad_to_deg(off.angle_to(to_star)),
		rad_to_deg(atan(halo.global_basis.x.length() / off.length())), halo.strength(),
		"" if halo.is_visible_in_tree() else " (hidden)"])

static func _on_screen(cam: Camera3D, d: Vector3) -> String:
	var p := cam.global_position + d * 1000.0
	if cam.is_position_behind(p):
		return "(behind)"
	var px := cam.unproject_position(p)
	return "(at %.0f, %.0f px)" % [px.x, px.y]

## descent_sheet.png: the SHEET renders at TILE size, day over night.
func _sheet() -> void:
	var sheet := Image.create_empty(TILE.x * (SHEET[0] as Array).size(), TILE.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for row in SHEET.size():
		for col in (SHEET[row] as Array).size():
			var shot_name: String = SHEET[row][col]
			if not _images.has(shot_name):
				print("        the sheet has no %s" % shot_name)
				continue
			var tile := (_images[shot_name] as Image).duplicate() as Image
			tile.convert(Image.FORMAT_RGBA8)
			tile.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, row * TILE.y))
	var file := "%s/descent_sheet.png" % _out
	sheet.save_png(file)
	print("render  %s" % file)

## `x` as 1.23e-5.
static func _sci(x: float) -> String:
	if x == 0.0:
		return "0"
	var e := floori(log(absf(x)) / log(10.0))
	return "%.2fe%d" % [x / pow(10.0, e), e]

func _env() -> Environment:
	return (_scene.get_node("WorldEnvironment") as WorldEnvironment).environment

func _sky() -> ProceduralSkyMaterial:
	return _env().sky.sky_material as ProceduralSkyMaterial
