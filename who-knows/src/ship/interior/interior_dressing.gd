class_name InteriorDressing
extends RefCounted

## Turns an InteriorLayout into props (docs/superpowers/specs/
## 2026-09-23-ship-interior-redesign-design.md §4): works out each face's
## frame and asks InteriorProps for the piece its record names. The only
## place that decides which prop goes where -- the props themselves never see
## a grid, which is what lets other generators reuse them.

## The quantum fixtures (quantum energy spec §6): the core at the bridge's
## centre and the machine against a wall.
const QUANTUM_CORE_ID := &"quantum_core"
const QUANTUM_MACHINE_ID := &"quantum_machine"

## The air the machine's conduit keeps between itself and a ceiling light's
## rim as it runs past.
const CONDUIT_LAMP_GAP := 0.19
## The least a conduit run along the ceiling stands off the centre lines of
## the cells it crosses (quantum energy spec §6.3). Every walkable cell's
## ceiling light hangs on its centre, so a run down a centre line would pass
## under it: this keeps the pipe CONDUIT_LAMP_GAP clear of the light's rim --
## 0.65 m, which is also 0.3 m off a wall's face, clear of its trim. A run
## stands farther out where the machine's outlet does (_conduit_path).
const CONDUIT_LANE := InteriorProps.CEILING_LIGHT_RIM + InteriorProps.CONDUIT_RADIUS + CONDUIT_LAMP_GAP
## How far short of a core's centre the conduit steps off its lane onto the
## crown's centre line, to run into the crown square to a flat: 0.25 m clear
## of the crown (0.55 m to a flat), inside the core's cell and well clear of
## the last cell's light.
const CONDUIT_APPROACH := 0.8

const _HORIZONTAL: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

## Builds everything under one `Dressing` node inside `body`, so the builder's
## single remove_child() + free() clears it with the rest of the interior.
static func build(layout: InteriorLayout, body: StaticBody3D, canopy_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	body.add_child(root)
	var kit := InteriorKit.new(root, body, portal_material(canopy_material))
	# A core's cell takes no round ceiling light: its crown carries the cell's.
	var core_cells := {}
	for fixture in layout.fixtures():
		if fixture["id"] == QUANTUM_CORE_ID:
			core_cells[fixture["coord"]] = true
	for face in layout.faces():
		_dress(kit, face, core_cells)
	for group in layout.canopy_groups():
		var pods: Array = group["pods"]
		if pods.is_empty():
			_nose(kit, group, canopy_material)
		else:
			_cockpit(kit, group)
	# Cores first: each machine's conduit runs to one on its own storey.
	var cores := {}   # Vector3i -> QuantumCore
	for fixture in layout.fixtures():
		var core := _fixture(kit, layout, fixture)
		if core != null:
			cores[fixture["coord"]] = core
	for fixture in layout.fixtures():
		if fixture["id"] == QUANTUM_MACHINE_ID:
			_quantum_machine(kit, layout, fixture, cores)
	for site in layout.airlocks():
		_airlock_room(kit, layout, site)
	kit.commit()
	return root

## Whether the dressing draws this MOUNT block itself, as a prop. The builder
## draws a block's own mesh only for the fixtures this leaves out.
static func draws_fixture(id: StringName) -> bool:
	return id == InteriorLayout.HELM_ID or id == QUANTUM_CORE_ID or id == QUANTUM_MACHINE_ID

## A fixture's frame (cockpit pod spec §5): origin on the floor under it, -z
## the way it faces, +y up. A helm with a pod ahead stands POD_SEAT_DEPTH
## beyond the canopy plane, out in the pod; any other fixture at its cell's
## floor centre.
static func fixture_frame(layout: InteriorLayout, coord: Vector3i) -> Transform3D:
	var facing := Vector3i(0, 0, -1)
	for fixture in layout.fixtures():
		if fixture["coord"] == coord:
			facing = _upright_facing(fixture["orientation"])
	for pod in layout.pods():
		if pod["coord"] == coord:
			return pod_frame(coord, pod["normal"]) * InteriorKit.at(Vector3(0, 0, -InteriorProps.POD_SEAT_DEPTH))
	var origin := ShipGrid.cell_center(coord)
	origin.y = floor_y(coord)
	return Transform3D(Basis.looking_at(Vector3(facing), Vector3.UP), origin)

## The horizontal way a fixture with this orientation faces: a fixture stands
## upright, whichever way its block points.
static func _upright_facing(orientation: int) -> Vector3i:
	var facing := InteriorLayout.facing(orientation)
	return Vector3i(0, 0, -1) if facing.y != 0 else facing

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

## The fixtures the dressing draws at their fixture frames (draws_fixture):
## the helm, and the quantum core, which it returns. Machines stand against a
## wall instead, and are built after every core (_quantum_machine).
static func _fixture(kit: InteriorKit, layout: InteriorLayout, fixture: Dictionary) -> QuantumCore:
	var coord: Vector3i = fixture["coord"]
	var variety := face_variety({"coord": coord, "normal": Vector3i.ZERO})
	if fixture["id"] == InteriorLayout.HELM_ID:
		InteriorProps.pilot_station(kit, fixture_frame(layout, coord), variety)
	elif fixture["id"] == QUANTUM_CORE_ID:
		var f := fixture_frame(layout, coord)
		InteriorProps.quantum_core(kit, f, variety)
		var core := QuantumCore.new()
		core.name = "QuantumCore_%d_%d_%d" % [coord.x, coord.y, coord.z]
		core.setup(f, kit.layer)
		kit.root.add_child(core)
		return core
	return null

## One quantum machine (quantum energy spec §6.3-§6.4), in the frame of the
## wall at its back -- the one its orientation turns away from: the cabinet,
## and on a QuantumMachine its bay, its big button (whose lines show on the
## screen over the bay), its two arrow buttons, its charge plate and the
## conduit: up from its top and along the ceiling into the crown of the core
## _conduit_route() picks, or, with no core it can reach, up into the ceiling
## and no further. The pipe is drawn along the path the bead runs.
static func _quantum_machine(kit: InteriorKit, layout: InteriorLayout, fixture: Dictionary,
		cores: Dictionary) -> QuantumMachine:
	var coord: Vector3i = fixture["coord"]
	var back := -_upright_facing(fixture["orientation"])
	var f := wall_frame(coord, back)
	InteriorProps.quantum_machine(kit, f, face_variety({"coord": coord, "normal": back}))
	var machine := QuantumMachine.new()
	machine.name = "QuantumMachine_%d_%d_%d" % [coord.x, coord.y, coord.z]
	machine.cell = coord
	kit.root.add_child(machine)

	machine.bay = QuantumBay.new()
	machine.bay.name = "QuantumBay"
	machine.bay.transform = f * InteriorProps.quantum_machine_bay()
	machine.add_child(machine.bay)
	var frames := InteriorProps.quantum_machine_buttons()
	machine.prev_button = _machine_button(machine, &"prev", f * frames[0], InteriorProps.QUANTUM_MACHINE_ARROW, kit.layer)
	machine.panel = _machine_button(machine, &"big", f * frames[1], InteriorProps.QUANTUM_MACHINE_BUTTON, kit.layer)
	machine.next_button = _machine_button(machine, &"next", f * frames[2], InteriorProps.QUANTUM_MACHINE_ARROW, kit.layer)
	var screen := ReadoutPanel.make_readout(kit.layer)
	screen.name = "Screen"
	screen.pixel_size = InteriorProps.QUANTUM_MACHINE_SCREEN_PIXEL
	screen.transform = f * InteriorProps.quantum_machine_screen() * InteriorKit.at(Vector3(0, 0, 0.002))
	machine.add_child(screen)
	machine.panel.readout = screen
	machine.plate = ChargeDock.new()
	machine.plate.setup(InteriorProps.QUANTUM_MACHINE_PLATE_RADIUS, InteriorKit.LAYER, kit.layer)
	machine.plate.transform = f * InteriorProps.quantum_machine_plate()
	machine.add_child(machine.plate)
	# Dark until whoever runs the machine lights what can be used.
	for button in [machine.prev_button, machine.panel, machine.next_button]:
		button.set_readout(PackedStringArray(), &"")
	machine.plate.set_lit(false)

	var own := InteriorProps.quantum_machine_conduit()
	var route := _conduit_route(layout, coord, back, cores.keys())
	if route.is_empty():
		var port := f * InteriorProps.quantum_machine_ceiling_port()
		machine.conduit_path = PackedVector3Array([f * own[0], port.origin])
		InteriorProps.conduit_collar(kit, port)
	else:
		var core: QuantumCore = cores[route[route.size() - 1]]
		machine.conduit_path = _conduit_path(route, f * own[0], f * own[1], core.crown())
	InteriorProps.conduit(kit, machine.conduit_path)
	return machine

## A button on the machine: a ReadoutPanel on interior_geometry, like the
## airlock's panels, with no screen of its own.
static func _machine_button(machine: QuantumMachine, role: StringName, f: Transform3D, size: Vector3,
		render_layer: int) -> ReadoutPanel:
	var panel := ReadoutPanel.new()
	panel.setup(role, InteriorKit.LAYER, render_layer, size, false)
	panel.transform = f
	machine.add_child(panel)
	return panel

## The cells a machine's conduit runs over, the machine's first and a core's
## last (quantum energy spec §6.3): across the walkable cells of the machine's
## own storey, from one to the next through open floor or a doorway -- never
## a wall, an airlock or another storey -- to the core the fewest cells away,
## a tie going to the lower cell coordinate. Of the shortest routes there, the
## one with the fewest turns, a first step away from (or towards) the wall at
## the machine's `back` counting as one, so the conduit sets off along that
## wall when it can. Empty when no core on the storey can be reached.
static func _conduit_route(layout: InteriorLayout, from: Vector3i, back: Vector3i,
		core_cells: Array) -> Array[Vector3i]:
	var open := {}   # Vector3i -> true: the storey's cells a conduit may cross
	for coord in layout.walkable_coords():
		if coord.y == from.y and layout.zone_at(coord) != InteriorLayout.AIRLOCK_ZONE:
			open[coord] = true
	# A state is a cell and the way the step into it went, as an index into
	# _HORIZONTAL; w = _HORIZONTAL.size() for the machine's cell, not yet left.
	var walls := {}   # Vector4i (coord, way) -> true
	for face in layout.faces():
		if face["kind"] == InteriorLayout.Kind.WALL:
			var coord: Vector3i = face["coord"]
			walls[Vector4i(coord.x, coord.y, coord.z, _HORIZONTAL.find(face["normal"]))] = true
	# Cheapest first by (steps, turns), a layer of steps at a time, so each
	# state is visited once: the first layer to reach a state settles it, with
	# the fewest turns any state of the layer before gives it -- the first
	# found, on a tie.
	var start := Vector4i(from.x, from.y, from.z, _HORIZONTAL.size())
	var cost := {start: Vector2i.ZERO}   # Vector4i -> Vector2i(steps, turns)
	var came := {}   # Vector4i -> Vector4i
	var layer: Array[Vector4i] = [start]
	while not layer.is_empty():
		var next_layer: Array[Vector4i] = []
		for state in layer:
			var cell := Vector3i(state.x, state.y, state.z)
			for way in _HORIZONTAL.size():
				var next := cell + _HORIZONTAL[way]
				if not open.has(next) or walls.has(Vector4i(cell.x, cell.y, cell.z, way)):
					continue
				var turn := 0 if way == state.w else 1
				if state.w == _HORIZONTAL.size():
					turn = 0 if _HORIZONTAL[way].x * back.x + _HORIZONTAL[way].z * back.z == 0 else 1
				var to := Vector4i(next.x, next.y, next.z, way)
				var c: Vector2i = cost[state] + Vector2i(1, turn)
				if not cost.has(to):
					next_layer.append(to)
				elif cost[to] <= c:
					continue
				cost[to] = c
				came[to] = state
		layer = next_layer
	var cores := core_cells.duplicate()
	cores.sort()
	var best := start
	for core: Vector3i in cores:
		for way in _HORIZONTAL.size():
			var end := Vector4i(core.x, core.y, core.z, way)
			if not cost.has(end):
				continue
			var c: Vector2i = cost[end]
			var least: Vector2i = cost[best]
			if best == start or c.x < least.x or (c < least and Vector3i(best.x, best.y, best.z) == core):
				best = end
	var route: Array[Vector3i] = []
	if best == start:
		return route
	var trace := best
	route.append(Vector3i(trace.x, trace.y, trace.z))
	while came.has(trace):
		trace = came[trace]
		route.push_front(Vector3i(trace.x, trace.y, trace.z))
	return route

## The conduit's path over `route`, in interior space (quantum energy spec
## §6.3): from the cabinet's `top` straight up to `rise`, square onto its lane
## and along the ceiling in straight runs, at least CONDUIT_LANE off the
## centre lines of the cells it crosses -- clear of their lights, and square
## across any wall between them -- to CONDUIT_APPROACH short of the core,
## where it steps onto the crown's centre line and runs square into the
## crown's side, to its centre, `crown`. It keeps only the bends: a point that
## carries a run straight on is left out.
##
## The lane is the same offset from every cell's centre, so every run is
## square. On each axis it is on the outlet's side and as far out as the
## outlet stands, or CONDUIT_LANE if that is farther: a run along the wall at
## the machine's back then sets off from the rise with no jog.
static func _conduit_path(route: Array[Vector3i], top: Vector3, rise: Vector3, crown: Vector3) -> PackedVector3Array:
	var home := ShipGrid.cell_center(route[0])
	var off := Vector2(rise.x - home.x, rise.z - home.z)
	var lane := Vector3(_lane(off.x), 0.0, _lane(off.y))
	var points: Array[Vector3] = [top, rise]
	var first := Vector3(home.x + lane.x, rise.y, home.z + lane.z)
	if not is_equal_approx(rise.x, first.x) and not is_equal_approx(rise.z, first.z):
		# Off the lane both ways: step onto it square, first along whichever
		# axis keeps the step farther from the cell's light.
		points.append(Vector3(first.x, rise.y, rise.z) if absf(off.y) >= absf(off.x)
			else Vector3(rise.x, rise.y, first.z))
	for i in route.size() - 1:
		var p := ShipGrid.cell_center(route[i]) + lane
		points.append(Vector3(p.x, rise.y, p.z))
	var last := Vector3(route[route.size() - 1] - route[route.size() - 2])
	var onto := Vector3(crown.x, rise.y, crown.z) - last * CONDUIT_APPROACH
	points.append(onto + lane - last * lane.dot(last))
	points.append(onto)
	points.append(crown)
	var out := PackedVector3Array()
	for p in points:
		var n := out.size()
		if n > 0 and out[n - 1].is_equal_approx(p):
			continue
		if n > 1 and (out[n - 1] - out[n - 2]).cross(p - out[n - 1]).length_squared() < 0.000001:
			out[n - 1] = p   # straight on, or doubling back along the same line
		else:
			out.append(p)
	return out

## The lane's offset on one axis, for an outlet standing `off` from its cell's
## centre line: on the outlet's side -- either, for an outlet on the line,
## never on it -- and at least CONDUIT_LANE out.
static func _lane(off: float) -> float:
	return (-1.0 if off < 0.0 else 1.0) * maxf(absf(off), CONDUIT_LANE)

static func _dress(kit: InteriorKit, face: Dictionary, core_cells: Dictionary) -> void:
	var coord: Vector3i = face["coord"]
	if face["zone"] == InteriorLayout.AIRLOCK_ZONE and face["kind"] != InteriorLayout.Kind.DOORWAY:
		return   # _airlock_room dresses the airlock's walls and ceiling
	match face["kind"]:
		InteriorLayout.Kind.CEILING:
			if core_cells.has(coord):
				return   # the core's crown carries this cell's light
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

## What a ship starts with on its closet shelves, by stow class, spot by spot
## (hands-and-items spec §5.2, as amended 2026-09-24): the full-width unit, and
## the narrow one on the side wall.
const CLOSET_STOCK := {
	&"small": [&"canister", &"canister", &"power_cell", &"power_cell", &"rock_sample"],
	&"crate": [&"crate", &"toolbox"],
	&"tool": [&"spanner", &"spare_module", &"hand_lamp"],
}
const CLOSET_SIDE_STOCK := {
	&"small": [&"canister", &"o2_tank", &"ration_tin"],
	&"crate": [&"spare_helmet"],
}

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
				_stow(kit, f, InteriorProps.bunks_spots(), {&"tool": &"datapad"})
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
				_stow(kit, f, InteriorProps.washstand_spots(), {&"tool": &"medkit"})
			else:
				InteriorProps.towel_rail(kit, f, variety)
		&"closet":
			var width := 1.7 if feature else 0.85
			InteriorProps.shelves(kit, f, variety, width)
			_stow(kit, f, InteriorProps.shelves_spots(width), CLOSET_STOCK if feature else CLOSET_SIDE_STOCK)
		&"weapon_room":
			if feature:
				InteriorProps.weapon_rack(kit, f, variety)
				_stow(kit, f, InteriorProps.weapon_rack_spots(), {&"sidearm": &"plasma_pistol"})
			else:
				InteriorProps.ammo_crates(kit, f, variety)
				_stow(kit, f, InteriorProps.ammo_crates_spots(), {&"tool": &"flare"})
	if porthole:
		InteriorProps.porthole(kit, f)

## A StowPoint at every spot a prop publishes, stocked by stow class
## (hands-and-items spec §5.2). The prop decides where things can sit; this
## decides what a ship starts with there.
## A class given a list hands its spots the list's ids in turn.
static func _stow(kit: InteriorKit, f: Transform3D, spots: Array, stock: Dictionary) -> void:
	var taken := {}
	for spot in spots:
		var point := StowPoint.new()
		point.name = "StowPoint"
		point.transform = f * (spot[0] as Transform3D)
		point.accepts = spot[1]
		point.stock = _next_stock(stock.get(spot[1], &""), taken, spot[1])
		kit.root.add_child(point, true)

static func _next_stock(ids: Variant, taken: Dictionary, stow_class: StringName) -> StringName:
	if not (ids is Array):
		return ids
	var list: Array = ids
	if list.is_empty():
		return &""
	var n: int = taken.get(stow_class, 0)
	taken[stow_class] = n + 1
	return list[n % list.size()]

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
