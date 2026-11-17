extends "res://test/probes/oasis_render.gd"

## Wadoo lived in (docs/superpowers/specs/2026-11-16-wadoo-design.md §4, §5; stage 1
## plan, Task 9): the starter lands on the oasis's pad and you step out on foot; the
## town's twenty-five wake as you come near and go about their day. The probe lets
## them live a while, printing what each is doing, then looks at them from where you
## stand (the eye 1.6 m over the ground) at the queen's court, a garden, the benches,
## the memorial, the bank, the breach, the Glassworks and the gate; grabs a run of
## frames by the pool; reads the frame rate with the town in view (the floor is 80);
## and measures the gap between each Wadee's feet and the drawn ground.
##
## Stage 2 (§6, §8), at the end, or alone with "hall" after the out dir: Oru before
## the queen's shut door, talked to through the Interactor; the village comes to
## think well of you (one task, set here) and the door swings open as Oru steps
## aside; the queen on her throne seen from the door, rising to receive you inside;
## her audience page by page, the hunt taken up with the 1 key; and the Sunguard
## gathered at the breach.
##
## Stage 3 (§7), alone with "things" after the out dir: Halla's pump stands broken;
## you talk to Daro and he sets a sun cell out by the Glassworks; you take it and
## fit it, and the dry garden grows green; you find Lio's armlet past the breach
## and give it to her, and she wears it; you pick a sun-lily by garden_1 and lay
## it at the memorial; hurt, you ask Wenna to heal you. Each through the
## Interactor, as a player would. Run WITHOUT --headless, from who-knows:
##
##   godot --path . --resolution 1280x720 --script res://test/probes/wadoo_play.gd -- <abs out dir> [hall|things]

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
## The hall's views, in its frame (x across, z from the door toward the throne):
## [name, where you stand, what you look at (its height over the floor)].
const HALL_INSIDE := ["wadoo_hall_inside", Vector3(1.2, 0.0, -1.9), Vector3(0.0, 1.3, 1.6)]
const HALL_BACK := ["wadoo_hall_back", Vector3(-1.3, 0.0, 0.6), Vector3(0.6, 1.2, -2.8)]
## Where you stand to speak with the queen, in the hall's frame.
const AUDIENCE_AT := Vector3(0.0, 0.0, 0.45)
## How long the Sunguard are given to reach the breach once the hunt is taken up, s.
const GATHER_WAIT := 90.0

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
	if "things" in OS.get_cmdline_user_args():
		await _things()
		_feet()
		_census("at the end")
		_let_go()
		print("wadoo   %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
		quit(0 if _fails == 0 else 1)
		return
	if "hall" in OS.get_cmdline_user_args():
		await _hall()
		_feet()
		_census("at the end")
		_let_go()
		print("wadoo   %s" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
		quit(0 if _fails == 0 else 1)
		return
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
	await _hall()
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

# --- stage 2: the queen's hall ------------------------------------------------

func _hall() -> void:
	var site := _wadoo.site
	var state: WadooState = _scene.get("wadoo_state")
	var room := site.room_of("house_b")
	_check(not room.is_empty(), "the hall is a room in house_b")
	var oru := _person("Oru")
	var queen := _person("Imsa")
	_check(oru != null and queen != null, "Oru and the queen are awake")
	if room.is_empty() or oru == null or queen == null:
		return
	var f: Transform3D = room["frame"]
	var door: Dictionary = site.door_of("house_b")
	var hall_door := site.node.find_child(WadooDoor.NAME, false, false) as WadooDoor
	_check(hall_door != null and not hall_door.is_open, "the hall's door is there and shut (regard %d)" % state.regard)
	# Oru before the shut door.
	var shut_at := WadooSite.flat(site.post_of("queen_door")["at"])
	await _until(func() -> bool: return WadooSite.flat(oru.local_position()).distance_to(shut_at) < 0.4, 30.0)
	print("hall    Oru %.2f m from his place before the shut door" % WadooSite.flat(oru.local_position()).distance_to(shut_at))
	_check(WadooSite.flat(oru.local_position()).distance_to(shut_at) < 0.4, "Oru stands before the shut door")
	var out: Vector2 = door["out"]
	var door_at := WadooSite.flat(door["at"])
	await _site_look("wadoo_hall_shut", door_at + out * 5.0, door["door"] + Vector3(0.0, 1.2, 0.0))
	var side := Vector2(out.y, -out.x)
	await _site_look("wadoo_hall_shut_side", door_at + out * 0.5 + side * 4.0, oru.local_position() + Vector3(0.0, 1.0, 0.0))
	# Talk to him through the Interactor: face him from 1.8 m, press F.
	await _site_look("", door_at + out * 1.8, oru.local_position() + Vector3(0.0, 1.2, 0.0))
	await _frames(4)
	_ray_report("facing Oru", oru)
	_check(WadooSite.flat(oru.local_position()).distance_to(shut_at) < 0.4, "you walk up: Oru holds his post")
	var aimed: Node = _avatar.interactor.current()
	print("hall    the Interactor finds %s: '%s'" % [aimed.name if aimed != null else "nothing", oru.prompt_text()])
	_check(aimed == oru, "facing Oru, F talks to him")
	await _press_action(&"interact")
	await _frames(3)
	var dialog: DialogPanel = _scene.get("dialog")
	_check(dialog.is_open(), "the panel opens")
	print("hall    Oru: %s" % dialog.text_label.text)
	await _shot("wadoo_talk_oru")
	await _press_action(&"ui_cancel")
	await _frames(3)
	_check(not dialog.is_open(), "Esc shuts it")
	# They come to think well of you: the door swings open, Oru steps aside.
	state.do_task(&"pump")
	await _seconds(WadooDoor.SWING_TIME + 0.5)
	_check(hall_door.is_open and absf(hall_door.leaf.rotation.y + WadooDoor.SWING) < 0.01,
		"the door swung open (%.0f deg)" % rad_to_deg(hall_door.leaf.rotation.y))
	var aside := WadooSite.flat(site.post_of("queen_door")["at"])
	await _until(func() -> bool: return WadooSite.flat(oru.local_position()).distance_to(aside) < 0.4, 20.0)
	_check(WadooSite.flat(oru.local_position()).distance_to(aside) < 0.4, "Oru steps aside")
	await _site_look("wadoo_hall_open", door_at + out * 5.0, door["door"] + Vector3(0.0, 1.2, 0.0))
	# From the doorway: the queen on her throne.
	await _site_look("", door_at + out * 0.2, f * Vector3(0.0, 1.0, 1.9))
	await _until(func() -> bool: return site._state.get(queen.record.id, &"") == &"seated", 20.0)
	await _seconds(1.5)
	print("hall    the queen: %s, clip %s" % [site._state.get(queen.record.id, &"standing"), (queen.look as WadeeLook).clip])
	_check(site._state.get(queen.record.id, &"") == &"seated", "the queen sits on her throne")
	await _shot("wadoo_hall_throne")
	# Inside: she rises to receive you.
	await _site_look("", WadooSite.flat(f * (HALL_INSIDE[1] as Vector3)), f * (HALL_INSIDE[2] as Vector3))
	await _until(func() -> bool: return site._state.get(queen.record.id, &"") == &"" and queen.intent.action == &"", 10.0)
	await _seconds(1.0)
	_check(site._state.get(queen.record.id, &"") == &"", "she rises as you come in")
	await _shot(HALL_INSIDE[0])
	await _site_look(HALL_BACK[0], WadooSite.flat(f * (HALL_BACK[1] as Vector3)), f * (HALL_BACK[2] as Vector3))
	# Her audience.
	await _site_look("", WadooSite.flat(f * AUDIENCE_AT), queen.local_position() + Vector3(0.0, 1.45, 0.0))
	await _frames(4)
	var aimed_q: Node = _avatar.interactor.current()
	print("hall    the Interactor finds %s: '%s'" % [aimed_q.name if aimed_q != null else "nothing", queen.prompt_text()])
	_check(aimed_q == queen, "facing the queen, F speaks to her")
	await _press_action(&"interact")
	await _frames(3)
	_check(dialog.is_open(), "her audience opens")
	var page := 1
	while dialog.is_open() and dialog.stage == &"pages" and page < 10:
		print("hall    Imsa %d: %s" % [page, dialog.text_label.text])
		await _shot("wadoo_audience_%d" % page)
		dialog.next()
		page += 1
	_check(dialog.stage == &"choice", "she asks")
	print("hall    Imsa asks: %s / %s / %s" % [dialog.text_label.text, dialog.answer_labels[0].text, dialog.answer_labels[1].text])
	await _shot("wadoo_audience_ask")
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	print("hall    Imsa answers: %s" % dialog.text_label.text)
	await _shot("wadoo_audience_reply")
	dialog.next()
	await _frames(3)
	_check(not dialog.is_open() and state.met_queen and state.hunt == WadooState.HUNT_ACCEPTED,
		"the hunt is taken up (met %s, hunt %s)" % [state.met_queen, state.hunt])
	_check(not _avatar.interactor.suspended, "you can move again")
	# The Sunguard gather at the breach.
	var g0 := site.spot(&"gather", "gather:0")
	var at0 := WadooSite.flat(g0["at"])
	var waited := 0.0
	while waited < GATHER_WAIT and _gathered(site) < 4:
		await _seconds(1.0)
		waited += 1.0
	print("hall    %d of 4 Sunguard at the breach after %.0f s" % [_gathered(site), waited])
	_check(_gathered(site) >= 4, "Kesh, Tarro, Seli and Nadi gather at the breach")
	var stand := at0 + (WadooSite.flat(g0["face"]) - at0).normalized() * 7.0
	await _site_look("wadoo_gather", stand, g0["at"] + Vector3(0.0, 1.0, 0.0))
	_who_is_near("wadoo_gather", at0)

## Stage 3 (§7): the things to do, played through.
func _things() -> void:
	var site := _wadoo.site
	var state: WadooState = _scene.get("wadoo_state")
	var node := site.node
	var pump := node.find_child(SunPump.NAME, false, false) as SunPump
	var lilies := node.find_child(MemorialLilies.NAME, false, false) as MemorialLilies
	_check(pump != null and not pump.working, "Halla's pump stands broken by the dry garden")
	_check(lilies != null and lilies.count == 0, "the memorial has no flowers")
	if pump == null or lilies == null:
		return
	var pump_at := WadooSite.flat(pump.position)
	var bed := pump_at + Vector2(1.9, -3.0)
	await _site_look("wadoo_pump_broken", pump_at + Vector2(-2.6, 1.6), pump.position + Vector3(0.9, 0.6, 1.4))
	# Daro sets a sun cell out by the Glassworks.
	await _talk_to("Daro", "wadoo_talk_daro")
	_check(state.cell_made, "Daro makes a sun cell")
	var cell := _lying_item(node, &"sun_cell")
	_check(cell != null, "it lies by the Glassworks")
	if cell == null:
		return
	await _take(cell, "wadoo_cell_lying")
	# Fit it to Halla's pump.
	await _site_look("", pump_at + Vector2(-1.3, 0.9), pump.position + Vector3(0.0, OasisLooks.SUN_CAGE, 0.0))
	await _frames(4)
	var aimed: Node = _avatar.interactor.current()
	print("things  at the pump the Interactor finds %s: '%s'" % [aimed.name if aimed != null else "nothing", pump.prompt_text()])
	_check(aimed == pump, "facing the pump, F fits the cell")
	await _press_action(&"interact")
	await _frames(3)
	_check(pump.working and state.did(&"pump") and Grasp.kind_in(_avatar) == &"", "fitted: the pump draws")
	var fitted_at := Time.get_ticks_msec()
	await _seconds(1.0)
	await _site_look("wadoo_pump_working", pump_at + Vector2(-2.6, 1.6), pump.position + Vector3(0.9, 0.6, 1.4))
	# Lio's armlet, past the breach, among the rubble.
	var armlet := _lying_item(node, &"armlet")
	_check(armlet != null, "Lio's armlet lies past the breach")
	if armlet != null:
		var at := WadooSite.flat(armlet.position)
		# found by its glint: shot as it flashes, from 6 m and then from 2 m, the
		# eye on the sand a little past it so the crosshair does not hide it
		var back := (_v2([46.43, -11.15]) - at).normalized()
		var past := armlet.position + Vector3(-back.x, 0.0, back.y)
		var glints := armlet.find_children("Glint", "", true, false)
		_check(not glints.is_empty(), "the armlet glints")
		for shot: Array in [["wadoo_armlet", 6.0, 1.0], ["wadoo_armlet_close", 2.0, 0.5]]:
			await _site_look("", at + back * float(shot[1]), armlet.position.lerp(past, float(shot[2])))
			if not glints.is_empty():
				await _until(func() -> bool: return (glints[0] as Node3D).visible, 5.0)
			await _shot(shot[0])
		await _take(armlet, "")
		await _talk_to("Lio", "wadoo_give_armlet")
		var lio := _person("Lio")
		_check(state.did(&"armlet") and Grasp.kind_in(_avatar) == &"", "Lio takes her armlet")
		_check(lio != null and (lio.look as WadeeLook).worn.has(&"armlet"), "and wears it")
		if lio != null:
			# from her left, where she wears it
			var frame := site.frame()
			var ahead := frame.basis.inverse() * -lio.global_basis.z
			var left := Vector3.UP.cross(Vector3(ahead.x, 0.0, ahead.z).normalized())
			await _site_look("wadoo_lio_armlet", WadooSite.flat(lio.local_position() + left * 1.4 + Vector3(ahead.x, 0.0, ahead.z).normalized() * 0.6),
				lio.local_position() + Vector3(0.0, 1.0, 0.0))
	# A sun-lily from the edge of garden_1, laid at the memorial.
	var lily := _lying_item(node, &"sun_lily")
	_check(lily != null, "a sun-lily grows by garden_1")
	if lily != null:
		await _take(lily, "wadoo_lily_growing")
		var middle := WadooSite.flat(lilies.position)
		var d := OasisLooks.memorial_dir(0, lilies.stones)
		var stone := middle + Vector2(d.x, -d.z) * 2.4
		await _site_look("", middle + Vector2(d.x, -d.z) * 4.2, site.ground(stone) + Vector3(0.0, 0.6, 0.0))
		await _frames(4)
		var at_m: Node = _avatar.interactor.current()
		print("things  at the memorial the Interactor finds %s: '%s'" % [at_m.name if at_m != null else "nothing", lilies.prompt_text()])
		_check(at_m == lilies, "facing a stone, F lays the lily")
		await _press_action(&"interact")
		await _frames(3)
		_check(lilies.count == 1 and int(state.tasks[&"lilies"]) == 1, "the lily lies before the stone")
		await _site_look("wadoo_lily_laid", middle + Vector2(d.x, -d.z) * 4.6 + Vector2(-d.z, -d.x) * 1.2,
			site.ground(stone) + Vector3(0.0, 0.2, 0.0))
	# Hurt, Wenna heals you.
	_avatar.health.take(_avatar.health.max * 0.5)
	await _talk_to("Wenna", "wadoo_wenna_heals")
	print("things  health %.0f of %.0f after Wenna" % [_avatar.health.current, _avatar.health.max])
	_check(_avatar.health.current == _avatar.health.max, "Wenna mends you")
	# The garden, green.
	var left := SunPump.GROW_TIME + 2.0 - (Time.get_ticks_msec() - fitted_at) / 1000.0
	if left > 0.0:
		await _seconds(left)
	print("things  the garden %.0f%% grown; regard %d, the door %s" % [pump.grown * 100.0, state.regard,
		"open" if state.door_open() else "shut"])
	_check(pump.grown >= 1.0, "the dry garden is green")
	_check(state.regard == 3 and state.door_open(), "all three done: the town thinks well of you")
	await _site_look("wadoo_garden_green", bed + Vector2(-3.2, 3.6), site.ground(bed) + Vector3(0.0, 0.3, 0.0))
	_who_is_near("wadoo_garden_green", bed)

## The item of `kind` lying in the town (a child of its node), or null.
func _lying_item(node: Node3D, kind: StringName) -> Item:
	for c in node.get_children():
		if c is Item and (c as Item).definition.id == kind:
			return c
	return null

## The way from `npc` toward the pool, on the ground.
func _toward_pool(npc: Npc) -> Vector2:
	var at := WadooSite.flat(npc.local_position())
	return (-at).normalized() if at.length() > 0.1 else Vector2.RIGHT

## You stand 1.2 m from `item` and look at it; F takes it.
func _take(item: Item, shot_name: String) -> void:
	var at := WadooSite.flat(item.position)
	var from := at + (-at).normalized() * 1.2
	await _site_look(shot_name, from, item.position)
	await _frames(4)
	var aimed: Node = _avatar.interactor.current()
	print("things  the Interactor finds %s: '%s'" % [aimed.name if aimed != null else "nothing", item.prompt_text()])
	_check(aimed == item, "facing the %s, F takes it" % item.definition.display_name)
	await _press_action(&"interact")
	await _frames(3)
	_check(_avatar.grasp.item == item, "you hold the %s" % item.definition.display_name)

## You walk up to `who` as a player does, face them and press F; the panel's
## pages are read and turned to the end.
func _talk_to(who: String, shot_name: String) -> void:
	var npc := _person(who)
	_check(npc != null, "%s is awake" % who)
	if npc == null:
		return
	var aimed: Node = null
	for attempt in 3:
		await _walk_up(npc)
		await _frames(4)
		aimed = _avatar.interactor.current()
		if aimed == npc:
			break
		_ray_report("facing %s, try %d" % [who, attempt + 1], npc)
	print("things  the Interactor finds %s: '%s'" % [aimed.name if aimed != null else "nothing", npc.prompt_text()])
	_check(aimed == npc, "facing %s, F speaks to them" % who)
	await _press_action(&"interact")
	await _frames(3)
	var dialog: DialogPanel = _scene.get("dialog")
	_check(dialog.is_open(), "%s's panel opens" % who)
	var page := 1
	while dialog.is_open() and page < 10:
		print("things  %s %d: %s" % [who, page, dialog.text_label.text])
		if page == 1 and shot_name != "":
			# they turn to you first (converse)
			await _seconds(1.2)
			await _shot(shot_name)
		dialog.next()
		await _frames(2)
		page += 1
	_check(not dialog.is_open(), "the panel shuts")
	await _frames(3)

## How far off you start walking up to someone, how near you stop, and your
## pace: a step of WALK_STEP m every WALK_EVERY s (1.7 m/s).
const WALK_FROM := 5.0
const WALK_TO := 1.9
const WALK_STEP := 0.25
const WALK_EVERY := 0.15

## You walk up to `npc` as a player would: from WALK_FROM m off, on open ground in
## a clear line to them, step by step toward wherever they are now, looking at
## them, until WALK_TO m off. A Wadee walking somewhere gives way and turns to you
## as you come (give_way); one you have not met lately stops to greet you.
func _walk_up(npc: Npc) -> void:
	var site := _wadoo.site
	var at := WadooSite.flat(npc.local_position())
	var me := at + _toward_pool(npc) * WALK_FROM
	for k in 16:
		var from := at + _toward_pool(npc).rotated(TAU * k / 16.0) * WALK_FROM
		if site.open(from) and site.paths.clear_line(from, at):
			me = from
			break
	for step in 60:
		var them := WadooSite.flat(npc.local_position())
		var gap := me.distance_to(them)
		if gap <= WALK_TO + 0.01:
			break
		me = me.move_toward(them, minf(WALK_STEP, gap - WALK_TO))
		await _stand(me, npc.local_position() + Vector3(0.0, 1.2, 0.0))
		await _seconds(WALK_EVERY)
	print("things  walked up to %s: %.2f m off" % [WadooCast.person(WadooCast.index_of(npc.record.id))["name"],
		me.distance_to(WadooSite.flat(npc.local_position()))])

## You stand at [east, north] `stand` on the town's ground looking at the site-local
## point `look`, at once (a step of a walk; _site_look settles and shoots).
func _stand(stand: Vector2, look: Vector3) -> void:
	var site := _wadoo.site
	var frame := site.frame()
	var pos := frame * (site.ground(stand) + Vector3(0.0, 0.05, 0.0))
	var up := _up(pos)
	var way := frame * look - pos
	_avatar.place(Transform3D(_level(up, way), pos))
	_moved()
	await _frames(1)
	_face(way)
	var to := frame * look - (pos + up * 1.6)
	_avatar.set_head_pitch(atan2(to.dot(up), (to - up * to.dot(up)).length()))

## Where the eye is and what the Interactor's ray meets first, beside `npc`.
func _ray_report(what: String, npc: Npc) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var inverse := _wadoo.site.frame().affine_inverse()
	var eye := inverse * cam.global_position
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 3.0,
		Interactor.SUIT_MASK)
	q.exclude = [_avatar.get_rid()]
	var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
	var met := "nothing"
	if not hit.is_empty():
		met = "%s (%s) %.2f m off" % [(hit["collider"] as Node).get_path(), (hit["collider"] as CollisionObject3D).collision_layer,
			cam.global_position.distance_to(hit["position"])]
	print("ray     %s: the eye at [%.2f, %.2f] %.2f m up, %s at [%.2f, %.2f] %.2f m off; the ray meets %s" % [what, eye.x, -eye.z,
		eye.y, npc.name, WadooSite.flat(npc.local_position()).x, WadooSite.flat(npc.local_position()).y,
		cam.global_position.distance_to(npc.global_position), met])

## How many Sunguard stand within 0.6 m of their gather spot.
func _gathered(site: WadooSite) -> int:
	var n := 0
	for npc in _live():
		var slot := WadooCast.gather_slot(WadooCast.person(WadooCast.index_of(npc.record.id)))
		if slot < 0:
			continue
		var s := site.spot(&"gather", "gather:%d" % slot)
		if not s.is_empty() and WadooSite.flat(npc.local_position()).distance_to(WadooSite.flat(s["at"])) < 0.6:
			n += 1
	return n

## The live Wadee called `who`, or null.
func _person(who: String) -> Npc:
	for npc in _live():
		if WadooCast.person(WadooCast.index_of(npc.record.id))["name"] == who:
			return npc
	return null

## You stood at [east, north] `stand` on the town's ground (a room's floor inside
## a shell), looking at the site-local point `look`; a shot called `shot_name`
## unless it is empty.
func _site_look(shot_name: String, stand: Vector2, look: Vector3) -> void:
	var site := _wadoo.site
	var frame := site.frame()
	var pos := frame * (site.ground(stand) + Vector3(0.0, 0.05, 0.0))
	var up := _up(pos)
	var target := frame * look
	var way := target - pos
	_avatar.place(Transform3D(_level(up, way), pos))
	_moved()
	await _seconds(0.6)
	_face(way)
	var eye := pos + up * 1.6
	var to := target - eye
	_avatar.set_head_pitch(atan2(to.dot(up), (to - up * to.dot(up)).length()))
	await _seconds(0.4)
	if shot_name != "":
		await _shot(shot_name)

## A key bound to `action` pressed and let go, through the input as a player's.
func _press_action(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up_ev := InputEventAction.new()
	up_ev.action = action
	up_ev.pressed = false
	Input.parse_input_event(up_ev)
