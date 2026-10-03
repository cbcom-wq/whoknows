extends SceneTree

# Real-scene check of a ship: what the grid validates and flies like, what the
# interior made of it, whether you can sit, stand up and walk away, and what
# it looks like at eye height -- with the frame rate. Run it WITHOUT
# --headless so it renders (and shaders compile):
#
#   godot --path who-knows --resolution 1280x720 \
#     --script <abs path>/ship_probe.gd -- <abs out dir> [scene path]
#
# The scene defaults to res://scenes/flight_test.tscn. It must hold a Ship at
# Ship, with Interior/Avatar and Interior/PilotSeat, and a CameraDirector at
# its root, as that scene does. Writes <out>/probe_spawn.png, probe_seated.png and
# probe_stood.png; on a ship with a lights panel, probe_panel_off.png,
# probe_panel_on.png and probe_panel_close.png too; with a bathroom,
# probe_toilet_shut.png and (a dev build) probe_toilet_open.png and the
# toilet line. On a ship with lights it
# also writes probe_lit_{floods,forward,both}_* (the hull against the dark),
# probe_star_bloom_{off,on}, probe_seated_lit, and, parked beside a rock's
# night side, probe_seated_rock_{dark,lit} and probe_rock_*. Every ship gets
# probe_hull_* (the skin, fill-lit) and prints skin, windows, lights and tint lines.
# Then a two-ship pass (docs/superpowers/specs/2026-10-02-many-ships-design.md
# §8.2): fps in the worst view with a second ship 300 m off,
# probe_fleet_from_starter{,_dark}.png, F8 to its helm, probe_fleet_from_second
# .png, a burn, standing and walking, probe_fleet_spacewalk.png, and the fleet
# line.
#
# A windowed run would save and load the owner's real game
# (docs/superpowers/specs/2026-09-26-saving-design.md §9), so the probe turns
# saving off before the scene enters the tree.

var _out := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	# Vsync would cap the frame rate at the monitor's; measure the real one.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var path := args[1] if args.size() > 1 else "res://scenes/flight_test.tscn"
	var scene: Node = load(path).instantiate()
	if &"save_enabled" in scene:
		scene.save_enabled = false
	root.add_child(scene)
	_run.call_deferred(scene)

func _process_frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _process_frames(5)
	var file := "%s/probe_%s.png" % [_out, name]
	root.get_viewport().get_texture().get_image().save_png(file)
	print("render  %s" % file)

func _fps(seconds: float) -> float:
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < seconds * 1e6:
		await process_frame
		frames += 1
	return frames / ((Time.get_ticks_usec() - start) / 1e6)

## The hull from outside (ship exterior spec §10): two quarters, the profile,
## above and below, from a camera riding on the hull. While `fill` is true a
## soft directional light rides with the camera, a little off its axis so faces
## read as different tones: an unlit hull renders near-black and says nothing
## about shape. Pass false to judge the ship's own lights against the dark.
func _hull_shots(ship: Ship, tag: String, fill := true) -> void:
	var cam := Camera3D.new()
	cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	cam.far = 5000.0
	ship.exterior.add_child(cam)
	var light: DirectionalLight3D = null
	if fill:
		light = DirectionalLight3D.new()
		light.light_cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
		light.light_energy = 1.4
		light.shadow_enabled = false
		light.rotation_degrees = Vector3(-22, 28, 0)
		cam.add_child(light)
	var views := {
		"bow_port": Vector3(-14, 6, -18), "stern_starboard": Vector3(14, 6, 18),
		"profile": Vector3(-26, 1, 0), "above": Vector3(0, 28, 4), "below": Vector3(4, -22, 0),
	}
	for view: String in views:
		var at: Vector3 = views[view]
		var up := Vector3.UP if absf(at.normalized().y) < 0.9 else Vector3.FORWARD
		cam.transform = Transform3D(Basis.looking_at(-at, up), at)
		cam.current = true
		await _shot("%s_%s" % [tag, view])
	cam.current = false
	if light != null:
		light.queue_free()
	cam.queue_free()

## The star as the flight scene draws it, straight ahead of a camera riding on
## the hull, with the world environment's bloom off and then on (ship exterior
## spec 6.3: the star's glow was approved before the bloom existed).
func _star_shots(scene: Node, ship: Ship) -> void:
	var star_system: StarSystem = scene.get("star_system")
	var env_node: WorldEnvironment = scene.get_node_or_null("WorldEnvironment")
	if star_system == null or env_node == null:
		return
	var universe: Universe = scene.get_node("Universe")
	var focus := universe.to_universe(universe.focus.global_position)
	var toward := star_system.recipe.star.point.minus(focus).normalized()
	var cam := Camera3D.new()
	cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	cam.far = BodyProxy.VIEW_FAR
	ship.exterior.add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at(toward, Vector3.UP if absf(toward.y) < 0.9 else Vector3.RIGHT),
		ship.exterior.global_position + toward * 12.0)
	cam.current = true
	var env: Environment = env_node.environment
	var was := env.glow_enabled
	for on in [false, true]:
		env.glow_enabled = on
		await _shot("star_bloom_%s" % ("on" if on else "off"))
	env.glow_enabled = was
	cam.current = false
	cam.queue_free()

## Parks the hull `gap` m off the nearest big rock's night side, still. With
## `belly_down` it hangs belly to the rock (for the floods); otherwise nose on
## to it (for the forward lights). The surface is found by a ray, not the
## rock's bounding radius, which is looser than the mesh. Returns false when no
## big rock is in sensor range (ship exterior spec 10).
func _park_by_a_rock(scene: Node, ship: Ship, gap: float, belly_down := false) -> bool:
	var universe: Universe = scene.get_node("Universe")
	var best: Contact = null
	for c in ship.sensors.contacts(RockContacts.RANGE):
		if c.kind == RockContacts.KIND:
			best = c
			break
	if best == null:
		return false
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var light_goes := -sun.global_basis.z
	var rock := universe.to_engine(best.point)
	var at := rock + light_goes * (best.radius + gap)
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.exterior.global_transform = Transform3D(Basis.looking_at(rock - at, Vector3.UP), at)
	# Let the stream build the rock's body there, then find its real surface.
	await _process_frames(90)
	await physics_frame
	var space := ship.exterior.get_world_3d().direct_space_state
	var from := rock + light_goes * (best.radius * 1.5 + 200.0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, rock, AsteroidBody.LAYER))
	var surface := best.radius
	if hit.is_empty():
		print("rock    no surface hit; using the bounding radius %.0f m" % best.radius)
	else:
		surface = (hit["position"] as Vector3).distance_to(rock)
		print("rock    radius %.0f m, surface found %.0f m out on the night side" % [best.radius, surface])
	at = rock + light_goes * (surface + gap)
	var dir := (rock - at).normalized()
	var look := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
	var basis := look if not belly_down else Basis(look.x, look.z, -look.y)
	ship.exterior.global_transform = Transform3D(basis, at)
	await _process_frames(30)
	return true

## The hull against a rock, from a camera riding on it. `views` maps a name to
## [where the camera is, what it looks at], in hull space.
## With `fps_label`, the frame rate from the last view is printed under it.
func _rock_shots(ship: Ship, tag: String, views: Dictionary, fps_label := "") -> void:
	var cam := Camera3D.new()
	cam.cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	cam.far = 5000.0
	ship.exterior.add_child(cam)
	for view: String in views:
		var v: Array = views[view]
		var at: Vector3 = v[0]
		var target: Vector3 = v[1]
		cam.transform = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)
		cam.current = true
		await _shot("%s_%s" % [tag, view])
	if fps_label != "":
		print("fps     %.0f %s" % [await _fps(2.0), fps_label])
	cam.current = false
	cam.queue_free()

func _lights(ship: Ship, floods: bool, forward: bool) -> void:
	ship.lights.set_group(ShipLights.FLOOD, floods)
	ship.lights.set_group(ShipLights.FORWARD, forward)

## The bridge's lights panel (ship exterior spec 7.3) at eye height: stood in
## the cell behind the starboard shoulder, facing forward, with the floods and
## forward lights off, then on. Skipped on a ship with no panel.
func _panel_shots(ship: Ship, avatar: Avatar) -> void:
	var panels := ship.interior_builder.lights_panels()
	print("panel   %d lights panels%s" % [panels.size(), "" if panels.size() == 1 else "  <-- EXPECTED ONE"])
	if panels.is_empty():
		return
	var cell := Vector3i(1, 0, -2)
	var interior: Node3D = ship.get_node("Interior")
	var feet := interior.global_transform * Vector3(ShipGrid.cell_center(cell).x, InteriorBuilder.floor_y(cell),
		ShipGrid.cell_center(cell).z)
	avatar.place(Transform3D(interior.global_transform.basis, feet))
	avatar.set_head_pitch(0.0)
	await _shot("panel_off")
	ship.lights.toggle(ShipLights.FLOOD)
	ship.lights.toggle(ShipLights.FORWARD)
	await _shot("panel_on")
	# Close up, a step to the panel's side of the shoulder cell, to read the labels.
	var near := interior.global_transform * Vector3(ShipGrid.cell_center(cell).x - 0.5, InteriorBuilder.floor_y(cell),
		ShipGrid.cell_center(cell).z - 2.3)
	avatar.place(Transform3D(interior.global_transform.basis, near))
	await _shot("panel_close")
	ship.lights.toggle(ShipLights.FLOOD)
	ship.lights.toggle(ShipLights.FORWARD)

## The bathroom's toilet at eye height (ToiletLid): stood in front of it,
## aimed at the shut lid, then -- on a dev build -- at the QE refill button
## with the lid lifted, which is pressed to fill the store and the store put
## back. Prints what the Interactor finds each time. Skipped with no bathroom.
func _toilet_shots(ship: Ship, avatar: Avatar) -> void:
	var lids := ship.interior_builder.toilet_lids()
	if lids.is_empty():
		print("toilet  none")
		return
	var lid := lids[0]
	var interactor: Interactor = avatar.get_node("Head/Interactor")
	var feet := lid.global_transform * Vector3(-0.3, 0, 1.25)
	var toward := lid.global_transform * Vector3(-0.5, 0, 0.4) - feet
	toward.y = 0.0
	avatar.place(Transform3D(Basis.looking_at(toward.normalized(), Vector3.UP), feet))
	var aim := func(at: Vector3) -> void:
		var eye: Vector3 = avatar.head.global_position
		var flat := Vector2(at.x - eye.x, at.z - eye.z).length()
		avatar.set_head_pitch(atan2(at.y - eye.y, flat))
	aim.call(lid.global_transform * (InteriorProps.toilet_hinge().origin + Vector3(0, 0, 0.25)))
	await _shot("toilet_shut")
	var found_lid := interactor.current() == lid
	if not lid.dev:
		print("toilet  %d lids; no dev button (a release build)" % lids.size())
		return
	var store := ship.quantum.store
	var before := store.amount
	lid.set_open(true, false)
	aim.call(lid.global_transform * InteriorProps.toilet_button().origin)
	await _shot("toilet_open")
	var found_button := interactor.current() == lid.button
	lid.button.interact(avatar)
	var filled := store.amount
	store.drain(filled - before, &"probe")
	lid.set_open(false, false)
	print("toilet  %d lids; the shut lid %s, the button under it %s; refill %d -> %d of %d%s" % [lids.size(),
		"found" if found_lid else "NOT FOUND", "found" if found_button else "NOT FOUND", before, filled,
		store.capacity, "" if filled == store.capacity else "  <-- NOT FULL"])

## Many ships (docs/superpowers/specs/2026-10-02-many-ships-design.md §8.2):
## the worst view's frame rate with a second ship 300 m off; the second ship
## from the starter's seat, sunlit and then dark with its floods on; F8 to its
## helm and the starter from there; a 1.5 s burn, short of the starter; standing
## and walking; a spacewalk between the two. Prints the fleet line.
func _fleet_pass(scene: Node) -> void:
	var fleet: Fleet = scene.get("fleet")
	if fleet == null:
		print("fleet   no Fleet in this scene")
		return
	var first: Ship = scene.get("aboard")
	var director: CameraDirector = scene.get_node("CameraDirector")
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	var avatar: Avatar = scene.get_tree().get_first_node_in_group(Avatar.GROUP)
	director.sit_now(first.seat)
	var behind := first.exterior.global_transform * Vector3(0, 0, 300)
	var second := fleet.spawn(scene.call("_starter_grid"), Transform3D(first.exterior.global_basis, behind))
	if await _park_by_a_rock(scene, first, 60.0):
		second.exterior.global_position = first.exterior.global_transform * Vector3(0, 0, 300)
		_lights(first, true, true)
		print("fps     %.0f seated by a rock, both groups on, a second ship 300 m off" % await _fps(2.0))
		_lights(first, false, false)
	# Out in the open, the second ship 60 m ahead and a little to port, nose to
	# the starter. Parked by the rock the starter looks toward the sun, so the
	# other ship's near side is unlit: a fill light riding with the viewer shows
	# its shape, as _hull_shots' does.
	first.exterior.global_position += first.exterior.global_basis.z * 2000.0
	await _process_frames(60)
	var hull := first.exterior.global_transform
	# Rolled 15°: each hull's stripe must stay on its own hull, painted in its
	# own frame, not the other ship's.
	var turned := Basis(hull.basis.y, PI) * hull.basis * Basis(Vector3.FORWARD, deg_to_rad(15))
	second.exterior.global_transform = Transform3D(turned, hull * Vector3(-5, 1, -60))
	second.exterior.linear_velocity = Vector3.ZERO
	second.exterior.angular_velocity = Vector3.ZERO
	var fill := DirectionalLight3D.new()
	fill.light_cull_mask = 1 | ExteriorBuilder.OWN_HULL_LAYER
	fill.light_energy = 1.4
	fill.shadow_enabled = false
	scene.add_child(fill)
	fill.global_basis = hull.basis * Basis.from_euler(Vector3(deg_to_rad(-22), deg_to_rad(28), 0))
	await _shot("fleet_from_starter")
	fill.visible = false
	sun.visible = false
	_lights(second, true, true)
	await _shot("fleet_from_starter_dark")
	_lights(second, false, false)
	sun.visible = true
	print("board   F8 %s" % ("ok" if scene.call("board_nearest") else "REFUSED"))
	await _process_frames(10)
	fill.global_basis = second.exterior.global_basis * Basis.from_euler(Vector3(deg_to_rad(-22), deg_to_rad(28), 0))
	fill.visible = true
	await _shot("fleet_from_second")
	fill.visible = false
	# Backing away, so it never reaches the starter 60 m ahead.
	var first_at := first.exterior.global_position
	Input.action_press("move_back")
	for i in 90:
		await physics_frame
	Input.action_release("move_back")
	print("fly     second ship %.1f m/s after 1.5 s in reverse; the starter moved %.2f m" % [
		second.exterior.linear_velocity.length(), first.exterior.global_position.distance_to(first_at)])
	# Let the controls see the key go before standing: a burn held as you
	# stand latches on (FlightComputer.clear_pilot_input), by design.
	await _process_frames(2)
	director.stand()
	await director.transition_finished
	var from := avatar.global_position
	Input.action_press("move_back")
	for i in 60:
		await physics_frame
	Input.action_release("move_back")
	var walked := from.distance_to(avatar.global_position)
	print("walked  %.2f m aboard %s%s" % [walked, second.name, "" if walked > 1.0 else "  <-- STUCK"])
	print("motion  second ship %.1f m/s, turning %.2f rad/s" % [second.exterior.linear_velocity.length(),
		second.exterior.angular_velocity.length()])
	# Off to the side of the line between them, so both ships are in view.
	var mid := (first.exterior.global_position + second.exterior.global_position) * 0.5
	var at := mid + first.exterior.global_basis.x * 45.0 + first.exterior.global_basis.y * 8.0
	var look := Basis.looking_at(mid - at, first.exterior.global_basis.y)
	avatar.enter_suit(scene.get_node("Outside"), Transform3D(look, at), second.exterior.linear_velocity, second.exterior)
	fill.global_basis = look * Basis.from_euler(Vector3(deg_to_rad(-22), deg_to_rad(28), 0))
	fill.visible = true
	await _process_frames(10)
	await _shot("fleet_spacewalk")
	fill.queue_free()
	var aboard: Ship = scene.get("aboard")
	var own_ok := true
	for s in fleet.ships():
		var own_pieces := 0
		for g in s.exterior.find_children("*", "GeometryInstance3D", true, false):
			if (g as GeometryInstance3D).layers == ExteriorBuilder.OWN_HULL_LAYER:
				own_pieces += 1
		own_ok = own_ok and ((own_pieces > 0) == (s == aboard))
	var asleep := fleet.ships().filter(func(s: Ship) -> bool: return fleet.sleeping(s)).size()
	print("fleet   %d ships, aboard %s, own layer %s, asleep %d" % [fleet.ships().size(), aboard.name,
		"ok" if own_ok else "WRONG", asleep])

func _run(scene: Node) -> void:
	# A process frame or two first: the canopy camera is placed on the first.
	await _process_frames(3)
	var ship: Ship = scene.get_node("Ship")
	var avatar: Avatar = ship.get_node("Interior/Avatar")
	var seat: PilotSeat = ship.get_node("Interior/PilotSeat")
	var director: CameraDirector = scene.get_node("CameraDirector")

	var issues := ShipValidator.validate(ship.grid, ship.catalog)
	for issue in issues:
		print("ISSUE   %s %s" % [issue.code, issue.message])
	print("grid    %d blocks, %d issues, can launch %s" % [ship.grid.coords().size(), issues.size(),
		ShipValidator.can_launch(issues)])
	var s := ShipStats.compute(ship.grid, ship.catalog)
	print("mass    %.1f t, centre of mass %s" % [s.total_mass_kg / 1000.0, s.center_of_mass])
	print("power   %.1f MW made, %.1f MW drawn" % [s.power_gen, s.power_draw])
	# Damage (health and damage spec §4): what it can take, whether it is
	# crippled before anything hits it, and the most one block's loss cuts off.
	var total_hp := 0
	var worst_cut := 0
	var buffer := 0
	for coord: Vector3i in ship.grid.coords():
		var def := ship.catalog.get_def(ship.grid.get_block(coord).block_id)
		if def == null:
			continue
		total_hp += def.hp
		if not ship.inner_cells.has(coord) and not BlockDamage.KEEP.has(def.id):
			buffer += 1
		if not BlockDamage.KEEP.has(def.id):
			var cut := BlockDamage.cut_off(ship.grid, [coord] as Array[Vector3i]).size()
			worst_cut = maxi(worst_cut, cut)
	print("damage  intact hp %d, crippled as built %s, buffer %d of %d can break away, one loss cuts off at most %d%s" % [
		total_hp, "no" if not s.crippled else "YES: " + s.crippled_reason, buffer, ship.grid.size(), worst_cut,
		"" if worst_cut <= 2 else "  <-- FRAGILE"])
	var reach_km := (s.quantum_capacity - WarpPlan.WARP_BASE) * WarpPlan.WARP_M_PER_QE / 1000.0
	print("warp    reach %.0f km on a full store (%d QE); drive %s" % [reach_km, s.quantum_capacity,
		"yes" if ship.warp != null else "MISSING"])
	var mask := ship.exterior.collision_mask
	var wants := 1 | BodyProxy.LAYER | AsteroidBody.LAYER | Npc.LAYER
	print("bumps   hull mask %d: hulls, worlds, rocks, NPCs %s" % [mask, "yes" if (mask & wants) == wants else "MISSING"])
	var anchored := ship.exterior.is_in_group(AsteroidStream.SPACE_ANCHOR)
	var placed := ship.flight_computer != null and ship.flight_computer.whereabouts != null
	print("worlds  hull is a space anchor %s; speed limit knows where it is %s" % [
		"yes" if anchored else "MISSING (no solid ground under it)",
		"yes" if placed else "MISSING (held to 120 m/s everywhere)"])
	print("thrust  kN fwd %.0f rev %.0f lat %.0f vert %.0f" % [s.thrust_budget[&"forward"] / 1000.0,
		s.thrust_budget[&"reverse"] / 1000.0, s.thrust_budget[&"lateral"] / 1000.0,
		s.thrust_budget[&"vertical"] / 1000.0])
	print("torque  authority %s, imbalance under burn %s" % [s.torque_budget, s.torque_imbalance])
	# The 5% rule (SKILL.md step 5): the reshaped starter's pitch sits at 4.91%,
	# so a little more mass above the thrust line breaks it.
	var share := Vector3(absf(s.torque_imbalance.x) / maxf(s.torque_budget.x, 1.0),
		absf(s.torque_imbalance.y) / maxf(s.torque_budget.y, 1.0),
		absf(s.torque_imbalance.z) / maxf(s.torque_budget.z, 1.0)) * 100.0
	print("balance imbalance %% of authority pitch %.2f yaw %.2f roll %.2f%s" % [share.x, share.y, share.z,
		"" if maxf(share.x, maxf(share.y, share.z)) <= 5.0 else "  <-- OVER 5%"])
	# The feel: assist is the same for every ship, so these decide how it flies.
	var kg := maxf(s.total_mass_kg, 1.0)
	var side: float = s.thrust_budget[&"lateral"] / kg
	print("feel    turn accel rad/s2 pitch %.2f yaw %.2f roll %.2f" % [
		s.torque_budget.x / maxf(s.inertia.x, 1.0), s.torque_budget.y / maxf(s.inertia.y, 1.0),
		s.torque_budget.z / maxf(s.inertia.z, 1.0)])
	print("feel    m/s2 side %.1f vert %.1f brake %.1f fwd %.1f; 100 m/s sideways gone in %.0f s" % [
		side, s.thrust_budget[&"vertical"] / kg, s.thrust_budget[&"reverse"] / kg,
		s.thrust_budget[&"forward"] / kg, 100.0 / maxf(side, 0.001)])
	# An rcs block whose exhaust face touches another block puffs inside it.
	var blocked := []
	var rcs := RcsShow.gather(ship.grid, ship.catalog, s.center_of_mass)
	for b in rcs:
		var push: Vector3 = (b["force"] as Vector3).normalized().round()
		if ship.grid.has_block(b["coord"] - Vector3i(push)):
			blocked.append(b["coord"])
	print("rcs     %d blocks%s" % [rcs.size(),
		"" if blocked.is_empty() else ", exhaust BLOCKED at %s" % [blocked]])

	# The ship's part of a save must bring back the same grid and store.
	var universe: Universe = scene.get_node_or_null("Universe")
	if universe != null:
		var part := JSON.parse_string(JSON.stringify(ship.to_dict(universe), "", false, true)) as Dictionary
		var again := Ship.layout_of(part)
		var same := again.coords().size() == ship.grid.coords().size()
		for c in ship.grid.coords():
			same = same and again.has_block(c) and again.get_block(c).block_id == ship.grid.get_block(c).block_id \
				and again.get_block(c).orientation == ship.grid.get_block(c).orientation
		var store := QuantumStore.new(ship.quantum.store.capacity, 0)
		store.from_dict(part.get("store", {}))
		print("save    layout %s, store %s, %d items aboard" % ["round-trips" if same else "MISMATCH",
			"round-trips" if store.amount == ship.quantum.store.amount else "MISMATCH", part["items"].size()])

	var layout := ship.interior_builder.layout()
	for room in layout.rooms():
		print("room    %s %s doorway %s" % [room["zone"], room["coords"], room["doorway"]])
	print("pods    %s" % [layout.pods()])
	print("locks   %s" % [layout.airlocks()])
	# The skin (ship exterior spec §3): every interior window must have one outside
	# and none may be UNMATCHED; the lights are the generator's, 5 floods and 2
	# forward on the starter.
	var hull := ship.exterior_builder.layout()
	print("skin    %d plates, %d chamfers, %d corners, %d facets, %d nozzles" % [hull.plates.size(),
		hull.edges.size(), hull.corners.size(), hull.facets.size(), hull.nozzles.size()])
	print("windows %d outside for %d inside%s" % [hull.windows.size(), hull.wanted,
		"" if hull.unmatched.is_empty() else "  <-- UNMATCHED %s" % [hull.unmatched]])
	print("lights  %d floods, %d forward" % [ship.lights.spots(&"flood").size(), ship.lights.spots(&"forward").size()])
	# The damage tint (health and damage spec §9): every tinted skin vertex is
	# one cell's, so a hurt block never leaves a piece of itself clean.
	var owned := {}   # ArrayMesh -> vertices claimed
	var cells := 0
	for coord: Vector3i in ship.grid.coords():
		var spans := ship.exterior_builder.skin_spans(coord)
		cells += int(not spans.is_empty())
		for span: Array in spans:
			owned[span[0]] = owned.get(span[0], 0) + span[2] - span[1]
	var unowned := 0
	for mesh: ArrayMesh in owned:
		unowned += mesh.surface_get_array_len(0) - owned[mesh]
	print("tint    %d cells in %d meshes%s" % [cells, owned.size(),
		"" if unowned == 0 else "  <-- %d VERTICES WITHOUT A CELL" % unowned])
	await _hull_shots(ship, "hull")
	var has_lights := ship.lights != null and not ship.lights.spots(ShipLights.FLOOD).is_empty()
	if has_lights:
		# No fill light: it would falsify the dark the lamps are judged against.
		for lit in [["floods", true, false], ["forward", false, true], ["both", true, true]]:
			_lights(ship, lit[1], lit[2])
			await _hull_shots(ship, "lit_%s" % lit[0], false)
		_lights(ship, false, false)
		await _star_shots(scene, ship)
	# The maintenance droid (NPC foundation spec §14): its dock, and every job it
	# must be able to reach on foot from there.
	var crew := ship.crew_site
	if crew != null and crew.dock != ShipCrew.NO_DOCK:
		print("droid   dock %s, %d jobs it can reach%s" % [crew.dock, crew.spots.size(),
			"" if crew.unreachable.is_empty() else ", UNREACHABLE %s" % [crew.unreachable.map(func(s): return s["key"])]])
	else:
		print("droid   none (under %d walkable cells, or no dock)" % ShipCrew.MIN_CELLS)
	# The bridge computer's tables (bridge computer spec §3): each needs its
	# operator's spot on walkable deck, and every reference bound.
	for computer in ship.interior_builder.computers():
		var spot := computer.cell + InteriorLayout.facing(ship.grid.get_block(computer.cell).orientation)
		var inst := ship.grid.get_block(spot)
		var def := ship.catalog.get_def(inst.block_id) if inst != null else null
		var standable := def != null and def.is_walkable() and def.occupancy != BlockDefinition.Occupancy.MOUNT
		var bound := computer.ctx.sensors != null and computer.ctx.store != null and computer.ctx.stats != null
		print("table   %s, used from %s%s%s" % [computer.cell, spot, "" if standable else "  <-- NOWHERE TO STAND",
			"" if bound else "  <-- UNBOUND"])
		# The computer mode's eye (computer mode spec §3.2, §4.4): it orbits the
		# holo up to ELEVATION_MAX, and must stay under the ceiling's lights.
		var eye := computer.station.eye_transform().origin
		var floor_y := computer.station.global_position.y
		var high := (computer.station.global_transform * InteriorProps.holo_station_eye(ComputerStation.ELEVATION_MAX)).origin.y
		print("        eye %.2f m up, orbiting to %.2f m%s" % [eye.y - floor_y, high - floor_y,
			"" if high - floor_y < InteriorProps.HEADROOM - 0.1 else "  <-- EYE IN THE CEILING"])

	await _shot("spawn")
	print("fps     %.0f standing at spawn" % await _fps(2.0))

	seat.interact(avatar)
	await director.transition_finished
	await _shot("seated")
	print("fps     %.0f seated" % await _fps(2.0))
	if has_lights:
		_lights(ship, true, true)
		await _shot("seated_lit")
		print("fps     %.0f seated, both light groups on" % await _fps(2.0))
		_lights(ship, false, false)
		# The worst view: seated, both groups on, nose to a big rock's night side.
		if await _park_by_a_rock(scene, ship, 60.0):
			await _shot("seated_rock_dark")
			_lights(ship, true, true)
			await _shot("seated_rock_lit")
			print("fps     %.0f seated by a rock, both groups on" % await _fps(2.0))
			_lights(ship, false, false)
			var rock_views := {
				"chase": [Vector3(3, 4, 16), Vector3(0, 0, -40)],
				"side": [Vector3(-22, 2, 4), Vector3(0, -1, -30)],
			}
			for lit in [["dark", false, false], ["forward", false, true], ["both", true, true]]:
				_lights(ship, lit[1], lit[2])
				await _rock_shots(ship, "rock_nose_%s" % lit[0], rock_views,
					"chase view 60 m off a rock, both groups on" if lit[0] == "both" else "")
			# Belly to the ground, 20 m off it: what the floods are for.
			_lights(ship, false, false)
			if await _park_by_a_rock(scene, ship, 20.0, true):
				var belly_views := {
					"side": [Vector3(-16, 2, 10), Vector3(0, -12, -2)],
					"low": [Vector3(0, -8, 14), Vector3(0, -14, -10)],
				}
				for lit in [["dark", false, false], ["floods", true, false], ["both", true, true]]:
					_lights(ship, lit[1], lit[2])
					await _rock_shots(ship, "rock_belly_%s" % lit[0], belly_views,
						"chase view 20 m over a rock, both groups on" if lit[0] == "both" else "")
			_lights(ship, false, false)

	director.stand()
	await director.transition_finished
	var at := seat.global_transform.affine_inverse() * avatar.global_position
	print("stood   seat-local %s (stand spots %s)" % [at, PilotSeat.STAND_SPOTS])
	await _shot("stood")
	var from := avatar.global_position
	Input.action_press("move_back")
	for i in 60:
		await physics_frame
	Input.action_release("move_back")
	var walked := from.distance_to(avatar.global_position)
	print("walked  %.2f m in 1 s after standing%s" % [walked, "" if walked > 1.0 else "  <-- STUCK"])
	await _panel_shots(ship, avatar)
	await _toilet_shots(ship, avatar)
	await _fleet_pass(scene)
	quit()
