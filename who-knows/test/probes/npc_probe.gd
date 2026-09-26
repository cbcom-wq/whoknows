extends SceneTree

# How much frame time the NPCs cost (docs/superpowers/specs/
# 2026-09-26-npc-foundation-design.md §16): wakes a herd on the start's big
# rock, fills the exterior up to its 32-NPC budget with copies of it, and times
# every NPC's work -- movement, gait, senses and thinking, both directors --
# over 600 physics frames, with the droid aboard as well. GUT never runs this
# (it is not under test/unit). Run headless: it measures the CPU, not the GPU.
#
#   godot --headless --path who-knows --script res://test/probes/npc_probe.gd

class Copies:
	var source
	var copies := 1
	func records(director) -> Array:
		var out: Array = []
		var base: Array = source.records(director)
		out.append_array(base)
		for k in copies:
			for e: Array in base:
				var r: NpcRecord = e[0]
				out.append([NpcRecord.make(StringName("%s:copy%d" % [r.id, k]), r.species, r.site, r.home,
					r.seed + 7919 * (k + 1), r.herd), e[1]])
		return out

func _initialize() -> void:
	var scene: Node = load("res://scenes/flight_test.tscn").instantiate()
	root.add_child(scene)
	_run.call_deferred(scene)

func _physics(n: int) -> void:
	for i in n:
		await physics_frame

func _run(scene: Node) -> void:
	await _physics(5)
	var ship: Ship = scene.get_node("Ship")
	var stream: AsteroidStream = scene.get_node("AsteroidStream")
	var outside: NpcDirector = scene.exterior_npcs
	var detail: AsteroidDetail = stream.details.live.values()[0]
	var site := RockSite.new(detail, stream.seed)
	var at := site.frame() * site.start_pose(site.records[0], 0.0).origin
	var out := (at - detail.global_position).normalized()
	ship.exterior.global_position = at + out * 60.0
	ship.exterior.freeze = true
	var copies := Copies.new()
	copies.source = outside.sources[0]
	copies.copies = 2
	outside.sources = [copies]
	await _physics(60)
	var npcs: Array = outside.live_npcs() + ship.npc_director.live_npcs()
	print("live   %d outside, %d inside" % [outside.live.size(), ship.npc_director.live.size()])
	# From here on the probe drives them, so it can time them.
	for d: NpcDirector in [outside, ship.npc_director]:
		d.set_physics_process(false)
	for npc: Npc in npcs:
		npc.set_physics_process(false)
		if npc.look != null:
			npc.look.set_process(false)
	var dt := 1.0 / Engine.physics_ticks_per_second
	var total := 0.0
	var worst := 0.0
	var parts := {"think": 0.0, "move": 0.0, "look": 0.0}
	for frame in 600:
		await physics_frame
		var t0 := Time.get_ticks_usec()
		for d: NpcDirector in [outside, ship.npc_director]:
			d.time += dt
			d.think_step()
		var t1 := Time.get_ticks_usec()
		for npc: Npc in npcs:
			npc._physics_process(dt)
		var t2 := Time.get_ticks_usec()
		for npc: Npc in npcs:
			if npc.look != null and npc.look.has_method(&"_process"):
				npc.look._process(dt)
		var t3 := Time.get_ticks_usec()
		parts["think"] += (t1 - t0) / 1000.0
		parts["move"] += (t2 - t1) / 1000.0
		parts["look"] += (t3 - t2) / 1000.0
		var used := (t3 - t0) / 1000.0
		total += used
		worst = maxf(worst, used)
	print("npc ms per frame: mean %.3f, worst %.3f (budget 1.0) over 600 frames" % [total / 600.0, worst])
	print("  of which: thinking %.3f, moving %.3f, looks %.3f" % [parts["think"] / 600.0, parts["move"] / 600.0,
		parts["look"] / 600.0])
	var gripping := 0
	for npc: Npc in outside.live_npcs():
		if npc.active is SurfaceCrawler and (npc.active as SurfaceCrawler).gripping:
			gripping += 1
	print("skitters gripping the rock: %d of %d" % [gripping, outside.live.size()])
	var doing := {}
	for npc: Npc in outside.live_npcs():
		var b: StringName = npc.brain.current.id if npc.brain.current != null else &"-"
		doing[b] = int(doing.get(b, 0)) + 1
	print("doing  %s" % doing)
	quit()
