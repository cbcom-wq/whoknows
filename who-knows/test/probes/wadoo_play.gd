extends "res://test/probes/oasis_render.gd"

## Wadoo lived in (docs/superpowers/specs/2026-11-16-wadoo-design.md §4, §5; stage 1
## plan, Task 9): the starter lands on the oasis's pad and you step out on foot; the
## town's twenty-five wake as you come near and go about their day. The probe lets
## them live a while, printing what each is doing, then looks at them from where you
## stand (the eye 1.6 m over the ground) at the queen's court, a garden, the benches,
## the memorial, the bank, the breach, the Glassworks and the gate; grabs a run of
## frames by the pool; reads the frame rate with the town in view (the floor is 80);
## and measures the gap between each Wadee's feet and the drawn ground. Run WITHOUT
## --headless, from who-knows:
##
##   godot --path . --resolution 1280x720 --script res://test/probes/wadoo_play.gd -- <abs out dir>

## How long to wait for the town to wake, and to let it live before looking, s.
const WAKE_WAIT := 60.0
const LIVE_FOR := 60.0
const CENSUS_EVERY := 20.0
## [name, spot kind, spot key, how far back you stand, pitch deg]: you stand that far
## from the spot, on the side it faces (so you see what they do), looking at it; a
## negative distance stands behind it (the Glassworks' spots face its door, and in
## front of them is indoors).
const SPOT_VIEWS := [
	["wadoo_court", &"court", "court:queen", 7.0, -2.0],
	["wadoo_glass", &"glass", "glass:2", -6.0, -4.0],
	["wadoo_garden", &"garden", "garden_1:0", 5.5, -6.0],
	["wadoo_breach", &"post", "post:breach_walk:0", 7.0, -3.0],
	["wadoo_gate", &"post", "post:gate", 6.0, -3.0],
]
## [name, where you stand, what you look at, pitch deg], [east, north] m.
const VIEWS := [
	["wadoo_memorial", [21.0, -10.5], [16.5, -16.5], -8.0],
	["wadoo_shade", [-28.0, 19.0], [-33.6, 23.5], -6.0],
	["wadoo_bank", [6.0, 17.5], [0.0, 9.0], -6.0],
	["wadoo_town", [14.0, 13.0], [-6.0, 0.0], -3.0],
]
## Where the run of frames is grabbed, and the town reading's view.
const SEQ_VIEW := [[8.0, 16.0], [0.0, 10.0], -5.0]
const SEQ_FRAMES := 24
const SEQ_GAP := 0.12
## People within this of what a view looks at are named under it.
const NAMED_WITHIN := 14.0

var _wadoo: WadooSource
var _npcs: NpcDirector

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
	print("gpu     %s" % RenderingServer.get_video_adapter_name())
	var system: SystemRecipe = _scene.get("system")
	_planet = system.body(WORLD_ID)
	for place in system.places():
		if place.id == PLACE_ID:
			_oasis = place
	_starter.flight_computer.assist_enabled = true
	await _sit(_starter)
	await _hide_the_card()
	await _warp_in()
	if not await _to_the_planet():
		print("wadoo   no world")
		quit(1)
		return
	_terrain = WorldTerrain.new(_planet.recipe)
	_starter.flight_computer.assist_enabled = true
	_find_the_oasis()
	await _aboard()
	await _starter_on_the_pad()
	_director.stand_now()
	await _frames(3)
	if not await _out_through(_starter.airlocks.values()[0], "", "foot"):
		quit(1)
		return
	_wadoo = _scene.get("wadoo")
	_npcs = _scene.get("exterior_npcs")
	var waited := 0.0
	while _live().size() < WadooCast.count() and waited < WAKE_WAIT:
		await _seconds(1.0)
		waited += 1.0
	print("wadoo   %d of %d awake after %.0f s on foot (max_live %d)" % [_live().size(), WadooCast.count(), waited, _npcs.max_live])
	_check(_live().size() == WadooCast.count(), "all %d Wadees awake" % WadooCast.count())
	if _live().is_empty():
		quit(1)
		return
	# Stand in the middle of town while it lives: they greet you and go about their day.
	await _foot_look("wadoo_waking", [14.0, 13.0], [-6.0, 0.0], deg_to_rad(-3.0))
	var lived := 0.0
	while lived < LIVE_FOR:
		await _seconds(CENSUS_EVERY)
		lived += CENSUS_EVERY
		_census("after %.0f s" % lived)
	for v: Array in SPOT_VIEWS:
		var spot := _wadoo.site.spot(v[1], v[2])
		if spot.is_empty():
			print("view    %s: no spot %s" % [v[0], v[2]])
			continue
		var at := WadooSite.flat(spot["at"])
		var ahead := (WadooSite.flat(spot["face"]) - at).normalized()
		var stand := at + ahead * float(v[3])
		await _foot_look(v[0], [stand.x, stand.y], [at.x, at.y], deg_to_rad(float(v[4])))
		_who_is_near(v[0], at)
	for v: Array in VIEWS:
		await _foot_look(v[0], v[1], v[2], deg_to_rad(float(v[3])))
		_who_is_near(v[0], _v2(v[2]))
	await _foot_look("wadoo_seq_start", SEQ_VIEW[0], SEQ_VIEW[1], deg_to_rad(float(SEQ_VIEW[2])))
	await _sequence("wadoo_seq")
	await _foot_look("wadoo_reading", [14.0, 13.0], [-6.0, 0.0], deg_to_rad(-3.0))
	_feet()
	await _reading_for("on foot in Wadoo, %d Wadees awake" % _live().size(), 5.0)
	await _npc_cost()
	_census("at the end")
	_let_go()
	for l in _readings:
		print("        %s" % l)
	print("wadoo   %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)

## Wadoo's live people.
func _live() -> Array[Npc]:
	var out: Array[Npc] = []
	if _npcs == null:
		return out
	for npc: Npc in _npcs.live_npcs():
		if is_instance_valid(npc) and npc.record != null and npc.record.site == WadooCast.SITE:
			out.append(npc)
	return out

## What everyone is doing, by behaviour: one line each, and a count.
func _census(when: String) -> void:
	var doing := {}
	for npc in _live():
		var b := npc.brain.current.id if npc.brain != null and npc.brain.current != null else &"-"
		doing[b] = int(doing.get(b, 0)) + 1
	print("census  %s: %s" % [when, doing])
	for npc in _live():
		var p := WadooCast.person(WadooCast.index_of(npc.record.id))
		var b := npc.brain.current.id if npc.brain.current != null else &"-"
		var at := WadooSite.flat(npc.local_position())
		print("          %-6s %-10s %-11s action %-9s at [%.1f, %.1f] %s%s" % [p["name"], p["role"], b,
			npc.intent.action, at.x, at.y, ("clip %s" % (npc.look as WadeeLook).clip) if npc.look is WadeeLook else "",
			" (indoors)" if _wadoo.site.hidden(npc.record.id) else ""])

## Who is near `at` ([east, north]) and what they do, under a view.
func _who_is_near(view: String, at: Vector2) -> void:
	var near := []
	for npc in _live():
		var here := WadooSite.flat(npc.local_position())
		if here.distance_to(at) < NAMED_WITHIN and not _wadoo.site.hidden(npc.record.id):
			var p := WadooCast.person(WadooCast.index_of(npc.record.id))
			near.append("%s (%s)" % [p["name"], (npc.look as WadeeLook).clip])
	print("near    %s: %s" % [view, ", ".join(near) if not near.is_empty() else "no one"])

## How far each Wadee's feet are from the drawn ground: a ray straight down.
func _feet() -> void:
	var space := root.get_world_3d().direct_space_state
	var worst := 0.0
	var total := 0.0
	var n := 0
	for npc in _live():
		if _wadoo.site.hidden(npc.record.id):
			continue
		var up := npc.global_basis.y.normalized()
		var q := PhysicsRayQueryParameters3D.create(npc.global_position + up * 1.0, npc.global_position - up * 1.5,
			0xFFFFFFFF & ~Npc.LAYER)
		q.exclude = [_avatar.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var gap := (npc.global_position - (hit["position"] as Vector3)).dot(up)
		worst = maxf(worst, absf(gap))
		total += absf(gap)
		n += 1
	var line := "feet    %d Wadees: the feet %.3f m from the ground on average, %.3f at worst" % [n, total / maxf(n, 1), worst]
	print(line)
	_readings.append(line)
	_check(worst < 0.1, "every Wadee's feet within 0.1 m of the ground (worst %.3f)" % worst)

## What the town costs: the frame rate with them, with their minds and bodies
## stopped, and with them hidden.
func _npc_cost() -> void:
	await _part_reading("the town living")
	_npcs.process_mode = Node.PROCESS_MODE_DISABLED
	for npc in _live():
		npc.process_mode = Node.PROCESS_MODE_DISABLED
	await _part_reading("minds, bodies and motions stopped")
	for npc in _live():
		npc.visible = false
	await _part_reading("and hidden")
	for npc in _live():
		npc.visible = true
		npc.process_mode = Node.PROCESS_MODE_INHERIT
	_npcs.process_mode = Node.PROCESS_MODE_INHERIT

func _part_reading(label: String) -> void:
	await _seconds(0.5)
	var fps := await _fps(4.0)
	var process := 0.0
	var physics := 0.0
	for k in 30:
		await process_frame
		process += Performance.get_monitor(Performance.TIME_PROCESS)
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var line := "part    %.0f fps, %s %s, process %.2f ms, physics %.2f ms" % [fps, label, _ms(),
		process / 30.0 * 1000.0, physics / 30.0 * 1000.0]
	print(line)
	_readings.append(line)

## SEQ_FRAMES frames, SEQ_GAP s apart, from where you stand: oasis_<name>_NN.png.
func _sequence(seq_name: String) -> void:
	for k in SEQ_FRAMES:
		await _seconds(SEQ_GAP)
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s/oasis_%s_%02d.png" % [_out, seq_name, k])
	print("render  %s/oasis_%s_00..%02d.png" % [_out, seq_name, SEQ_FRAMES - 1])

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
