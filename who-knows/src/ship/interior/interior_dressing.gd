class_name InteriorDressing
extends RefCounted

## Turns an InteriorLayout into props (docs/superpowers/specs/
## 2026-09-23-ship-interior-redesign-design.md §4): works out each face's
## frame and asks InteriorProps for the piece its record names. The only
## place that decides which prop goes where -- the props themselves never see
## a grid, which is what lets other generators reuse them.

## Builds everything under one `Dressing` node inside `body`, so the builder's
## single remove_child() + free() clears it with the rest of the interior.
static func build(layout: InteriorLayout, body: StaticBody3D, canopy_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	body.add_child(root)
	var kit := InteriorKit.new(root, body, portal_material(canopy_material))
	for face in layout.faces():
		_dress(kit, face)
	for group in layout.canopy_groups():
		var pods: Array = group["pods"]
		if pods.is_empty():
			_nose(kit, group, canopy_material)
		else:
			_cockpit(kit, group)
	for fixture in layout.fixtures():
		_fixture(kit, layout, fixture)
	for site in layout.airlocks():
		_airlock_room(kit, layout, site)
	kit.commit()
	return root

## Whether the dressing draws this MOUNT block itself, as a prop. The builder
## draws a block's own mesh only for the fixtures this leaves out.
static func draws_fixture(id: StringName) -> bool:
	return id == InteriorLayout.HELM_ID

## A fixture's frame (cockpit pod spec §5): origin on the floor under it, -z
## the way it faces, +y up. A helm with a pod ahead stands POD_SEAT_DEPTH
## beyond the canopy plane, out in the pod; any other fixture at its cell's
## floor centre.
static func fixture_frame(layout: InteriorLayout, coord: Vector3i) -> Transform3D:
	var facing := Vector3i(0, 0, -1)
	for fixture in layout.fixtures():
		if fixture["coord"] == coord:
			facing = InteriorLayout.facing(fixture["orientation"])
	if facing.y != 0:
		facing = Vector3i(0, 0, -1)   # a fixture stands upright, whichever way its block points
	for pod in layout.pods():
		if pod["coord"] == coord:
			return pod_frame(coord, pod["normal"]) * InteriorKit.at(Vector3(0, 0, -InteriorProps.POD_SEAT_DEPTH))
	var origin := ShipGrid.cell_center(coord)
	origin.y = floor_y(coord)
	return Transform3D(Basis.looking_at(Vector3(facing), Vector3.UP), origin)

## A pod's frame, as InteriorProps.cockpit_pod expects it: origin at the floor
## centre of the canopy face it juts out through, on the canopy plane; -z out
## into the pod, +x across, +y up.
static func pod_frame(coord: Vector3i, normal: Vector3i) -> Transform3D:
	var n := Vector3(normal)
	var origin := ShipGrid.cell_center(coord) + n * ShipGrid.CELL_SIZE * 0.5
	origin.y = floor_y(coord)
	return Transform3D(Basis(Vector3.UP.cross(-n), Vector3.UP, -n), origin)

## The PORTAL batch's material: the scene's canopy material -- the window
## shader fed by the canopy view -- made all window. Without one wired, black
## glass.
static func portal_material(canopy_material: Material) -> Material:
	if canopy_material is ShaderMaterial:
		var m: ShaderMaterial = canopy_material.duplicate()
		m.set_shader_parameter(&"all_glass", true)
		return m
	return InteriorMaterials.portal_fallback()

## A wall's frame, as InteriorProps expects it: origin on the wall's inner
## surface at floor level, centred along the wall; +x along the wall, +y up,
## +z into the room.
static func wall_frame(coord: Vector3i, normal: Vector3i) -> Transform3D:
	var n := Vector3(normal)
	var inward := -n
	var along := Vector3.UP.cross(inward)
	var origin := ShipGrid.cell_center(coord) + n * (ShipGrid.CELL_SIZE - InteriorBuilder.FLOOR_THICKNESS) * 0.5
	origin.y = floor_y(coord)
	return Transform3D(Basis(along, Vector3.UP, inward), origin)

## The top of a walkable cell's deck slab.
static func floor_y(coord: Vector3i) -> float:
	return InteriorBuilder.floor_y(coord)

## A face's stable 0..1 variety, for what its props show.
static func face_variety(face: Dictionary) -> float:
	return float(InteriorLayout.face_hash(face["coord"], face["normal"]) % 1000) / 1000.0

## One rounded nose over a windshield group, in a frame on the canopy plane at
## floor level: +x across the group, +y up, +z back into the room.
static func _nose(kit: InteriorKit, group: Dictionary, material: Material) -> void:
	var normal: Vector3i = group["normal"]
	var n := Vector3(normal)
	var across := Vector3.UP.cross(-n)
	var coords: Array = group["coords"]
	var lo := INF
	var hi := -INF
	for coord: Vector3i in coords:
		var c := ShipGrid.cell_center(coord).dot(across)
		lo = minf(lo, c - ShipGrid.CELL_SIZE * 0.5)
		hi = maxf(hi, c + ShipGrid.CELL_SIZE * 0.5)
	var first: Vector3i = coords[0]
	var plane := (ShipGrid.cell_center(first) + n * ShipGrid.CELL_SIZE * 0.5).dot(n)
	var origin := across * ((lo + hi) * 0.5) + n * plane + Vector3.UP * floor_y(first)
	InteriorProps.nose(kit, Transform3D(Basis(across, Vector3.UP, -n), origin), hi - lo, material)

## A windshield with a helm behind it: the pod out through the helm's face,
## with a CockpitPod marker at its frame, and a shoulder on every other face.
static func _cockpit(kit: InteriorKit, group: Dictionary) -> void:
	var normal: Vector3i = group["normal"]
	var pods: Array = group["pods"]
	for coord: Vector3i in group["coords"]:
		if pods.has(coord):
			var f := pod_frame(coord, normal)
			InteriorProps.cockpit_pod(kit, f)
			var marker := Node3D.new()
			marker.name = "CockpitPod"
			marker.transform = f
			kit.root.add_child(marker)
		else:
			InteriorProps.shoulder(kit, wall_frame(coord, normal),
				face_variety({"coord": coord, "normal": normal}))

## The fixtures the dressing draws itself (draws_fixture), at their frames.
static func _fixture(kit: InteriorKit, layout: InteriorLayout, fixture: Dictionary) -> void:
	var coord: Vector3i = fixture["coord"]
	if fixture["id"] == InteriorLayout.HELM_ID:
		InteriorProps.pilot_station(kit, fixture_frame(layout, coord),
			face_variety({"coord": coord, "normal": Vector3i.ZERO}))

static func _dress(kit: InteriorKit, face: Dictionary) -> void:
	var coord: Vector3i = face["coord"]
	if face["zone"] == InteriorLayout.AIRLOCK_ZONE and face["kind"] != InteriorLayout.Kind.DOORWAY:
		return   # _airlock_room dresses the airlock's walls and ceiling
	match face["kind"]:
		InteriorLayout.Kind.CEILING:
			var centre := ShipGrid.cell_center(coord)
			centre.y = floor_y(coord) + InteriorProps.HEADROOM
			InteriorProps.ceiling_light(kit, centre)
		InteriorLayout.Kind.WALL:
			var f := wall_frame(coord, face["normal"])
			InteriorProps.wall_trim(kit, f)
			_wall_piece(kit, f, face)
		InteriorLayout.Kind.DOORWAY:
			if face["owner"] and not face["hatch"]:
				_doorway(kit, wall_frame(coord, face["normal"]))

static func _wall_piece(kit: InteriorKit, f: Transform3D, face: Dictionary) -> void:
	var variety := face_variety(face)
	match face["variant"]:
		InteriorLayout.WallVariant.CONSOLE:
			InteriorProps.console(kit, f, variety)
		InteriorLayout.WallVariant.PORTHOLE:
			InteriorProps.porthole(kit, f)
		InteriorLayout.WallVariant.LOCKERS:
			InteriorProps.lockers(kit, f, variety)
		InteriorLayout.WallVariant.DISPLAY:
			InteriorProps.display(kit, f, variety)
		InteriorLayout.WallVariant.FEATURE, InteriorLayout.WallVariant.SECONDARY:
			_room_piece(kit, f, face, variety)
		# PANEL: the trim is the whole wall.

## A room wall's furniture, by room: the feature wall gets the room's main
## piece, the secondary wall a smaller one (spec §7.4). Secondary pieces are
## under a metre wide and pushed to the end of their wall away from the
## feature wall, so the two never meet in the corner.
static func _room_piece(kit: InteriorKit, f: Transform3D, face: Dictionary, variety: float) -> void:
	var feature: bool = face["variant"] == InteriorLayout.WallVariant.FEATURE
	var porthole: bool = face["porthole"]
	if not feature:
		var away := signf(f.basis.x.dot(-Vector3(face["feature_normal"])))
		f = f * InteriorKit.at(Vector3(away * InteriorProps.BAY * 0.25, 0, 0))
	match face["zone"]:
		&"bunk_room":
			if feature:
				InteriorProps.bunks(kit, f, variety, porthole)
			else:
				InteriorProps.tall_lockers(kit, f, variety)
		&"galley":
			if feature:
				InteriorProps.galley_counter(kit, f, variety, porthole)
				_stow(kit, f, InteriorProps.galley_counter_spots(), {&"small": &"mug"})
			else:
				InteriorProps.fridge(kit, f, variety)
		&"bathroom":
			if feature:
				InteriorProps.washstand(kit, f, variety)
			else:
				InteriorProps.towel_rail(kit, f, variety)
		&"closet":
			var width := 1.7 if feature else 0.85
			InteriorProps.shelves(kit, f, variety, width)
			_stow(kit, f, InteriorProps.shelves_spots(width), {&"small": &"canister", &"crate": &"crate"})
		&"weapon_room":
			if feature:
				InteriorProps.weapon_rack(kit, f, variety)
				_stow(kit, f, InteriorProps.weapon_rack_spots(), {&"sidearm": &"plasma_pistol"})
			else:
				InteriorProps.ammo_crates(kit, f, variety)
	if porthole:
		InteriorProps.porthole(kit, f)

## A StowPoint at every spot a prop publishes, stocked by stow class
## (hands-and-items spec §5.2). The prop decides where things can sit; this
## decides what a ship starts with there.
static func _stow(kit: InteriorKit, f: Transform3D, spots: Array, stock: Dictionary) -> void:
	for spot in spots:
		var point := StowPoint.new()
		point.name = "StowPoint"
		point.transform = f * (spot[0] as Transform3D)
		point.accepts = spot[1]
		point.stock = stock.get(spot[1], &"")
		kit.root.add_child(point, true)

## One airlock's room (airlock spec §3): its walls and ceiling, a hatch frame
## and an AirlockHatch at each end, the room panel on a side wall, the corridor
## panel beside the inner hatch, and a portal pane just outside the outer
## hatch's leaves. Everything the Airlock node drives is gathered on an
## AirlockRoom.
static func _airlock_room(kit: InteriorKit, layout: InteriorLayout, site: Dictionary) -> AirlockRoom:
	var coord: Vector3i = site["coord"]
	var hatch_n: Vector3i = site["hatch_normal"]
	var door_n: Vector3i = site["door_normal"]
	var room := AirlockRoom.new()
	room.name = "Airlock_%d_%d_%d" % [coord.x, coord.y, coord.z]
	room.coord = coord
	room.hatch_normal = hatch_n
	room.door_normal = door_n
	kit.root.add_child(room)

	var n := Vector3(hatch_n)
	var origin := ShipGrid.cell_center(coord)
	origin.y = floor_y(coord)
	room.room_frame = Transform3D(Basis(Vector3.UP.cross(-n), Vector3.UP, -n), origin)
	var mid := InteriorKit.at(Vector3(0, 0, -InteriorProps.WALL_THICKNESS * 0.5))
	room.outer_frame = wall_frame(coord, hatch_n) * mid

	var right := Vector3i(room.room_frame.basis.x.round())
	var panel_wall := Vector3i.ZERO
	for face in layout.faces():
		if face["coord"] != coord or face["kind"] != InteriorLayout.Kind.WALL \
				or face["variant"] != InteriorLayout.WallVariant.AIRLOCK:
			continue
		var normal: Vector3i = face["normal"]
		var side := normal.x * hatch_n.x + normal.z * hatch_n.z == 0
		InteriorProps.airlock_wall(kit, wall_frame(coord, normal), face_variety(face), side)
		if side:
			room.nozzles.append_array(InteriorProps.nozzle_frames(wall_frame(coord, normal)))
		if panel_wall == Vector3i.ZERO or normal == right:
			panel_wall = normal

	InteriorProps.hatch_frame(kit, room.outer_frame)
	room.outer_hatch = _hatch(kit, room.outer_frame, "Outer", true)
	var w := InteriorProps.DOOR_WIDTH * 0.5
	var pane := room.outer_frame
	var pane_n := (pane.basis * Vector3.BACK).normalized()
	kit.quad(InteriorKit.Batch.PORTAL, pane * Vector3(-w, 0, -0.08), pane * Vector3(w, 0, -0.08),
		pane * Vector3(w, InteriorProps.HATCH_HEIGHT, -0.08), pane * Vector3(-w, InteriorProps.HATCH_HEIGHT, -0.08),
		pane_n, InteriorKit.solid(InteriorPalette.GLASS))

	if door_n != Vector3i.ZERO:
		room.inner_frame = wall_frame(coord, door_n) * mid
		InteriorProps.hatch_frame(kit, room.inner_frame)
		room.inner_hatch = _hatch(kit, room.inner_frame, "Inner", false)
		room.corridor_panel = _panel(kit, &"inner",
			wall_frame(coord + door_n, -door_n) * InteriorKit.at(Vector3(0.8, 1.25, 0)))
	if panel_wall != Vector3i.ZERO:
		room.room_panel = _panel(kit, &"room", wall_frame(coord, panel_wall) * InteriorKit.at(Vector3(0, 1.25, 0)))

	var ceiling := room.room_frame * InteriorKit.at(Vector3(0, InteriorProps.AIRLOCK_CLEAR, 0))
	room.ceiling_light = InteriorProps.airlock_ceiling(kit, ceiling)
	return room

static func _hatch(kit: InteriorKit, f: Transform3D, hatch_name: String, portal: bool) -> AirlockHatch:
	var hatch := AirlockHatch.new()
	hatch.name = hatch_name + "Hatch"
	hatch.setup(InteriorProps.DOOR_WIDTH, InteriorProps.HATCH_HEIGHT, kit.body, f, portal, kit.portal_material)
	kit.root.add_child(hatch)
	return hatch

static func _panel(kit: InteriorKit, role: StringName, f: Transform3D) -> AirlockPanel:
	var panel := AirlockPanel.new()
	panel.setup(role, InteriorKit.LAYER)
	panel.transform = f
	kit.root.add_child(panel)
	return panel

## A doorway's frame and its sliding door, on the wall's mid-plane.
static func _doorway(kit: InteriorKit, f: Transform3D) -> void:
	InteriorProps.door_frame(kit, f)
	var door := SlidingDoor.new()
	door.name = "SlidingDoor"
	door.setup(InteriorProps.DOOR_WIDTH, InteriorProps.DOOR_HEIGHT)
	door.transform = f * InteriorKit.at(Vector3(0, 0, -InteriorProps.WALL_THICKNESS * 0.5))
	kit.root.add_child(door)
