class_name InteriorProps
extends RefCounted

## The interior asset library (docs/superpowers/specs/
## 2026-09-23-ship-interior-redesign-design.md §4, §5.3): every chunky piece of
## a stylized cabin, each built by one static function from an InteriorKit, a
## frame and, where it varies, a `variety` in 0..1.
##
## THE REUSE CONTRACT. A prop never looks at a grid, a layout or a builder. It
## builds in its own frame -- origin on the wall's inner surface at floor
## level, centred along the wall; +x along the wall, +y up, +z out into the
## room -- and nothing else. Anything that can produce a frame (the ship
## interior today; shipyard blueprints, derelicts and stations later) can place
## any prop.
##
## Sizes are metres in that frame. Props are designed for a wall BAY long and
## HEADROOM high; test_interior_props.gd holds the ship's cell and slab
## dimensions to these numbers.

const SOLID := InteriorKit.Batch.SOLID
const GLOW := InteriorKit.Batch.GLOW
const GLASS := InteriorKit.Batch.GLASS
const PORTAL := InteriorKit.Batch.PORTAL

## The wall length a prop is designed to fill.
const BAY := 2.0
## Clear height, floor to ceiling: 2.5 m, a full 0.9 m over a standing eye
## (InteriorBuilder.STOREY_HEIGHT less a slab). Trim near the ceiling hangs
## from HEADROOM, not from fixed heights, so it follows the storey height.
const HEADROOM := 2.5
## Thickness of the wall a frame sits on: the frame's origin is on its inner
## face, so the wall's mid-plane is at z = -WALL_THICKNESS / 2.
const WALL_THICKNESS := 0.1

## A porthole: floor-relative centre height, glass radius, frame radius, and
## the half-size of the square hole a wall leaves for it. The frame ring
## covers the square's corners and its bore hides the gap round the glass.
const PORTHOLE_HEIGHT := 1.45
const PORTHOLE_RADIUS := 0.26
const PORTHOLE_FRAME_RADIUS := 0.42
const PORTHOLE_OPENING := 0.27

## A doorway's clear width. Each sliding leaf is half of it, and slides into
## a jamb of (BAY - DOOR_WIDTH) / 2 = 0.5 m, so an open door hides entirely.
const DOOR_WIDTH := 1.0
## A doorway's clear height: door height, not ceiling height, with a lintel
## above -- and well over the 1.8 m avatar.
const DOOR_HEIGHT := 2.1

## The airlock's clear height (airlock spec §3.2): its ceiling is where the
## hull cell's is, so its copy on the hull matches it exactly. Lower than the
## cabin's HEADROOM on purpose.
const AIRLOCK_CLEAR := 1.9
## An airlock hatch's clear opening height: DOOR_WIDTH wide, and still 5 cm
## over the 1.8 m avatar.
const HATCH_HEIGHT := 1.85

## Shelf boards: how many, where the lowest sits, and the pitch between them.
const SHELF_LEVELS := 4
const SHELF_BASE := 0.25
const SHELF_PITCH := 0.47
const SHELF_BOARD := 0.04
const SHELF_DEPTH := 0.4

## Half the width a stow spot keeps clear of decor, by stow class.
const STOW_CLEARANCE := {&"small": 0.12, &"crate": 0.27, &"sidearm": 0.15, &"tool": 0.14}

## The top of the lower bunk's mattress. The lower bunk is solid only to here,
## so the Interactor can reach what lies on it (bunks_spots()).
const BUNK_MATTRESS_TOP := 0.54
## The top of the medkit bracket beside the washstand's mirror.
const WASHSTAND_BRACKET := 1.15

## The rounded cockpit nose (spec §6), in a frame on the canopy plane at
## floor level: +x across the windshield, +y up, +z back into the room.
const NOSE_DEPTH := 1.4
## Fraction of the height that stays vertical before the nose curves back.
const NOSE_VERTICAL := 0.45
const NOSE_COLUMNS := 48
const NOSE_ROWS := 20
## Height of the lit brow line along the curve.
const NOSE_BROW := HEADROOM - 0.1
## Ribs between and beside the windows, as arc length from the centre line.
const NOSE_RIBS: Array[float] = [-2.75, -1.3, 1.3, 2.75]
const DASH_HEIGHT := 0.9
## How far the dash's curved front edge reaches forward of the plane.
const DASH_INSET := 0.55
## Windows as (centre across, centre height, half width, half height), in
## metres; across is arc length along the nose from its centre line.
const NOSE_WINDOWS: Array[Vector4] = [
	Vector4(0.0, 1.325, 0.9, 0.375),
	Vector4(-1.95, 1.3, 0.5, 0.3),
	Vector4(1.95, 1.3, 0.5, 0.3),
]

## The wraparound cockpit pod (cockpit pod spec §4), in a pod frame: origin at
## the floor centre of the mouth, on the canopy plane; -z out into the pod, +x
## across, +y up. The outline runs round the pod from one side of the mouth to
## the other: a 2 m mouth, 2.4 m wide inside, jutting 1.9 m. Its first and last
## segments are solid jambs; the rest are glazed from the sill to the glass top,
## with a band above to the roof.
const POD_OUTLINE: Array[Vector2] = [
	Vector2(-1.0, 0.0), Vector2(-1.2, -0.25), Vector2(-1.2, -1.2), Vector2(-0.6, -1.9),
	Vector2(0.6, -1.9), Vector2(1.2, -1.2), Vector2(1.2, -0.25), Vector2(1.0, 0.0),
]
const POD_SILL := 0.75
const POD_GLASS_TOP := 2.05
const POD_ROOF := 2.2
## How far beyond the canopy plane the captain's chair stands in a pod: the
## seated eye is then 1.65 m behind the front glass, with glass on both flanks.
const POD_SEAT_DEPTH := 0.7

## A pod shoulder's window, floor-relative, and its half width.
const SHOULDER_WINDOW_LOW := 1.15
const SHOULDER_WINDOW_HIGH := 1.95
const SHOULDER_WINDOW_HALF := 0.55

## The seated pilot's eye in the captain's chair's fixture frame (origin on
## the floor under the seat, -z the way it faces): the chair's headrest sits
## just behind it, and the scene's PilotSeat/Eye must match it.
const SEATED_EYE := Vector3(0, 1.35, 0.45)

## Pilasters, a kick band, a terracotta belt, a light shelf with a warm strip
## above it, and a cove up to the ceiling: what makes a bare wall read as a
## ship's wall. Neighbouring walls both build a pilaster on their shared
## edge, so the one on the -x edge is a hair smaller and never z-fights.
static func wall_trim(kit: InteriorKit, f: Transform3D) -> void:
	for side in [-1.0, 1.0]:
		var shrink := 0.0 if side > 0.0 else 0.002
		kit.bevel_box(SOLID, f * _at(Vector3(side * BAY * 0.5, HEADROOM * 0.5, 0.05)),
			Vector3(0.18 - shrink, HEADROOM, 0.1 - shrink), 0.035, _c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.08, 0.025)), Vector3(BAY, 0.16, 0.05), 0.02,
		_c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.95, 0.0175)), Vector3(BAY, 0.08, 0.035), 0.015,
		_c(InteriorPalette.BELT))
	kit.bevel_box(SOLID, f * _at(Vector3(0, HEADROOM - 0.24, 0.09)), Vector3(BAY, 0.07, 0.18), 0.03,
		_c(InteriorPalette.TRIM))
	kit.box(GLOW, f * _at(Vector3(0, HEADROOM - 0.165, 0.01)), Vector3(BAY, 0.06, 0.02),
		_lit(InteriorPalette.LIGHT_WARM, 2.2))
	kit.box(SOLID, f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(45.0)), Vector3(0, HEADROOM - 0.06, 0.06)),
		Vector3(BAY, 0.17, 0.02), _c(InteriorPalette.TRIM))

## A round light on the ceiling: a chunky frame round a glowing disc, and the
## lamp that actually lights the room below it.
static func ceiling_light(kit: InteriorKit, ceiling_centre: Vector3) -> void:
	var down := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ceiling_centre)
	kit.ring(SOLID, down, 0.3, 0.42, -0.02, 0.05, _c(InteriorPalette.TRIM))
	kit.disc(GLOW, down * _at(Vector3(0, 0, 0.02)), 0.3, _lit(InteriorPalette.LIGHT_WARM, 0.9))
	kit.light(ceiling_centre + Vector3(0, -0.9, 0), InteriorPalette.LIGHT_WARM, 0.45, 4.0, &"ceiling")

## A station console: glowing plinth, bevelled body, a sloped screen, four big
## buttons (one blinks) and, unless `wall_screen` is false (a window needs the
## wall), a framed screen on the wall above.
static func console(kit: InteriorKit, f: Transform3D, variety: float, wall_screen := true) -> void:
	var body := _c(InteriorPalette.TRIM)
	kit.box(GLOW, f * _at(Vector3(0, 0.05, 0.12)), Vector3(1.1, 0.1, 0.24), _lit(InteriorPalette.LIGHT_WARM, 2.5))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.41, 0.19)), Vector3(1.4, 0.62, 0.38), 0.05, body)
	var slope := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-45.0)), Vector3(0, 0.895, 0.205))
	kit.bevel_box(SOLID, f * slope, Vector3(1.4, 0.5, 0.06), 0.025, body)
	for side in [-0.68, 0.68]:
		kit.tri(SOLID, f * Vector3(side, 0.72, 0.0), f * Vector3(side, 0.72, 0.36), f * Vector3(side, 1.07, 0.0),
			(f.basis * Vector3(signf(side), 0, 0)).normalized(), body)
	kit.bevel_box(SOLID, f * slope * _at(Vector3(0, 0, 0.035)), Vector3(1.24, 0.38, 0.02), 0.01,
		_c(InteriorPalette.SCREEN_BACK))
	var first := int(variety * 3.0)
	kit.screen(f * slope * _at(Vector3(0, 0, 0.047)), Vector2(1.12, 0.3), _mode(first), variety)
	var buttons: Array[Color] = [InteriorPalette.AMBER, InteriorPalette.SKY, InteriorPalette.CORAL,
		InteriorPalette.LIGHT_WARM]
	for i in buttons.size():
		kit.bevel_box(GLOW, f * _at(Vector3(-0.45 + i * 0.3, 0.58, 0.405)), Vector3(0.14, 0.08, 0.05), 0.015,
			_lit(buttons[i], 1.6, 0.4 if i == 2 else 1.0))
	if wall_screen:
		kit.bevel_box(SOLID, f * _at(Vector3(0, 1.45, 0.03)), Vector3(1.0, 0.5, 0.06), 0.03, body)
		kit.screen(f * _at(Vector3(0, 1.45, 0.061)), Vector2(0.86, 0.36), _mode(first + 1),
			fposmod(variety + 0.37, 1.0))
	kit.collider(f * _at(Vector3(0, 0.55, 0.2)), Vector3(1.4, 1.1, 0.4))
	kit.light(f * Vector3(0, 1.0, 0.45), InteriorPalette.LIGHT_WARM, 0.35, 1.8, &"console")

## Eight raised locker doors on a dark backing, each with a small indicator.
static func lockers(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	kit.box(SOLID, f * _at(Vector3(0, 1.155, 0.01)), Vector3(1.34, 1.93, 0.02), _c(InteriorPalette.WALL_LOW))
	var lamps: Array[Color] = [InteriorPalette.LIGHT_WARM, InteriorPalette.AMBER, InteriorPalette.SKY]
	for col in 2:
		for row in 4:
			var p := Vector3(-0.32 + col * 0.64, 0.45 + row * 0.47, 0.04)
			kit.bevel_box(SOLID, f * _at(p), Vector3(0.6, 0.42, 0.08), 0.03, _c(InteriorPalette.TRIM))
			var h := fposmod(variety * 13.0 + col * 3.7 + row * 1.3, 1.0)
			kit.disc(GLOW, f * _at(p + Vector3(0.2, -0.13, 0.041)), 0.03,
				_lit(lamps[int(h * 3.0) % 3], 1.6, h if h > 0.6 else 1.0))

## A framed wall screen above a small ledge.
static func display(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.15, 0.07)), Vector3(1.5, 0.05, 0.14), 0.02, _c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.45, 0.035)), Vector3(1.5, 0.55, 0.07), 0.03, _c(InteriorPalette.TRIM))
	kit.screen(f * _at(Vector3(0, 1.45, 0.071)), Vector2(1.36, 0.41),
		_mode(0 if variety < 0.5 else 2), variety)

## A porthole's frame and glass. The glass is a portal (it shows the real view
## outside); the cartoon glint stays on top. The wall behind it must leave a
## square hole PORTHOLE_OPENING across at PORTHOLE_HEIGHT (InteriorBuilder
## does).
static func porthole(kit: InteriorKit, f: Transform3D) -> void:
	var at := f * _at(Vector3(0, PORTHOLE_HEIGHT, 0))
	kit.ring(SOLID, at, PORTHOLE_RADIUS, PORTHOLE_FRAME_RADIUS, -WALL_THICKNESS, 0.09, _c(InteriorPalette.TRIM))
	kit.annulus(GLOW, at * _at(Vector3(0, 0, 0.092)), PORTHOLE_RADIUS, PORTHOLE_RADIUS + 0.015,
		_lit(InteriorPalette.LIGHT_WARM, 1.0))
	var facing := (at.basis * Vector3.BACK).normalized()
	kit.disc(PORTAL, at * _at(Vector3(0, 0, -WALL_THICKNESS * 0.5)), PORTHOLE_RADIUS, InteriorPalette.GLASS)
	# A cartoon glint: two parallel streaks across the glass.
	var glint := at * Transform3D(Basis(Vector3.BACK, deg_to_rad(45.0)), Vector3(-0.04, 0.04, -0.045))
	var white := InteriorPalette.GLINT
	kit.quad(GLASS, glint * Vector3(-0.15, -0.018, 0), glint * Vector3(0.15, -0.018, 0),
		glint * Vector3(0.15, 0.018, 0), glint * Vector3(-0.15, 0.018, 0), facing, white)
	kit.quad(GLASS, glint * Vector3(-0.08, -0.07, 0), glint * Vector3(0.08, -0.07, 0),
		glint * Vector3(0.08, -0.055, 0), glint * Vector3(-0.08, -0.055, 0), facing, white)

## An airlock hatch's fixed frame (airlock spec §3.3), in a hatch frame:
## origin at the opening's centre at floor level on the wall's mid-plane, +x
## along the wall, +z into a room. It straddles the wall, the same from both
## sides: chunky posts with hazard stripes, a header up into the ceiling, and a
## threshold plate. The leaves, bolts and lights are AirlockHatch's. Flush
## enough to brush past: no collider.
static func hatch_frame(kit: InteriorKit, f: Transform3D) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var half := DOOR_WIDTH * 0.5
	for side in [-1.0, 1.0]:
		var x: float = side * (half + 0.08)
		kit.bevel_box(SOLID, f * _at(Vector3(x, HATCH_HEIGHT * 0.5, 0)), Vector3(0.16, HATCH_HEIGHT, 0.3), 0.04, trim)
		for face in [-1.0, 1.0]:
			for y in [0.18, 0.34]:
				kit.box(SOLID, f * _at(Vector3(x, y, face * 0.151)), Vector3(0.12, 0.07, 0.004),
					_c(InteriorPalette.CORAL))
	kit.bevel_box(SOLID, f * _at(Vector3(0, HATCH_HEIGHT + 0.06, 0)), Vector3(DOOR_WIDTH + 0.32, 0.12, 0.3), 0.04, trim)
	kit.box(SOLID, f * _at(Vector3(0, 0.006, 0)), Vector3(DOOR_WIDTH + 0.32, 0.012, 0.3), _c(InteriorPalette.GUNMETAL))

## Steam nozzles on each airlock side wall (airlock spec §3.5, §5.1).
const NOZZLES_PER_WALL := 2
const _NOZZLE_X: Array[float] = [-0.45, 0.45]
const _NOZZLE_HEIGHT := 0.4
## How steeply a nozzle's jet climbs from the horizontal.
const _NOZZLE_TILT := deg_to_rad(30.0)

## An airlock wall, in a wall frame (see the header), for the airlock's low
## ceiling: a kick band, corner pilasters and two ribs, a band under the
## ceiling, a coral grab rail, a vent grille and -- unless `nozzles` is false --
## two steam nozzles low down, angled up into the room. All flush or thin: no
## collider.
static func airlock_wall(kit: InteriorKit, f: Transform3D, _variety: float, nozzles := true) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.07, 0.02)), Vector3(BAY, 0.14, 0.04), 0.015, low)
	kit.bevel_box(SOLID, f * _at(Vector3(0, AIRLOCK_CLEAR - 0.04, 0.025)), Vector3(BAY, 0.08, 0.05), 0.015, trim)
	for side in [-1.0, 1.0]:
		var shrink := 0.0 if side > 0.0 else 0.002
		kit.bevel_box(SOLID, f * _at(Vector3(side * BAY * 0.5, AIRLOCK_CLEAR * 0.5, 0.05)),
			Vector3(0.18 - shrink, AIRLOCK_CLEAR, 0.1 - shrink), 0.035, trim)
		kit.bevel_box(SOLID, f * _at(Vector3(side * 0.75, AIRLOCK_CLEAR * 0.5, 0.03)),
			Vector3(0.1, AIRLOCK_CLEAR - 0.22, 0.06), 0.025, trim)
		kit.bevel_box(SOLID, f * _at(Vector3(side * 0.55, 0.92, 0.06)), Vector3(0.04, 0.04, 0.12), 0.01, trim)
	kit.tube_x(SOLID, f * _at(Vector3(0, 0.92, 0.12)), 0.022, 1.3, _c(InteriorPalette.CORAL))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.24, 0.012)), Vector3(0.44, 0.16, 0.024), 0.008,
		_c(InteriorPalette.SCREEN_BACK))
	for k in 4:
		kit.box(SOLID, f * _at(Vector3(0, 0.186 + k * 0.036, 0.026)), Vector3(0.4, 0.014, 0.008), low)
	if nozzles:
		for jet in nozzle_frames(f):
			var tip := jet.origin
			var back := jet.origin - (jet.basis * Vector3.FORWARD) * 0.12
			kit.tube_between(SOLID, back, tip, 0.028, gun)
			kit.disc(GLOW, jet * _at(Vector3(0, 0, -0.001)) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO),
				0.018, _lit(InteriorPalette.STEAM, 0.6))
		for x in _NOZZLE_X:
			kit.bevel_box(SOLID, f * _at(Vector3(x, _NOZZLE_HEIGHT, 0.03)), Vector3(0.14, 0.14, 0.06), 0.02, gun)

## Each steam nozzle's tip on an airlock wall in wall frame `f`, with -z along
## its jet: into the room and up.
static func nozzle_frames(f: Transform3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var along := Vector3(0, sin(_NOZZLE_TILT), cos(_NOZZLE_TILT))
	for x in _NOZZLE_X:
		var tip := Vector3(x, _NOZZLE_HEIGHT, 0.06) + along * 0.12
		out.append(f * Transform3D(Basis.looking_at(along, Vector3.UP), tip))
	return out

## The airlock's ceiling fittings in frame `f`: origin on the ceiling's
## underside at the room's centre, -z toward the outer hatch. Two flush light
## strips in trim, and the room's light, which the airlock recolours through
## its cycle -- so it is returned.
static func airlock_ceiling(kit: InteriorKit, f: Transform3D) -> OmniLight3D:
	for side in [-1.0, 1.0]:
		kit.bevel_box(SOLID, f * _at(Vector3(side * 0.45, -0.012, 0)), Vector3(0.2, 0.024, 1.3), 0.008,
			_c(InteriorPalette.TRIM))
		kit.box(GLOW, f * _at(Vector3(side * 0.45, -0.026, 0)), Vector3(0.12, 0.006, 1.2),
			_lit(InteriorPalette.LIGHT_WARM, 1.8))
	return kit.light(f * Vector3(0, -0.45, 0), InteriorPalette.LIGHT_WARM, 0.55, 3.0, &"airlock")

## The rounded cockpit nose over a windshield `width` wide, bulging forward
## (-z) from the canopy plane: a shell with window cut-outs (the material's
## job; see canopy_window.gdshader), ribs that follow the curve, a lit brow, a
## curved dash with a wooden rail and a glowing plinth, three screen desks and
## the cockpit's key light. Returns the shell.
static func nose(kit: InteriorKit, frame: Transform3D, width: float, material: Material) -> MeshInstance3D:
	if material == null:
		material = InteriorMaterials.canopy_fallback()
	if material is ShaderMaterial:
		for k in NOSE_WINDOWS.size():
			material.set_shader_parameter("window_%d" % k, NOSE_WINDOWS[k])
		material.set_shader_parameter(&"shell_color", InteriorPalette.WALL)
		material.set_shader_parameter(&"frame_color", InteriorPalette.TRIM)

	# Arc length along the floor-level curve, so windows and ribs are placed
	# in metres rather than in angle.
	var arc := PackedFloat32Array()
	arc.resize(NOSE_COLUMNS + 1)
	var total := 0.0
	for i in range(1, NOSE_COLUMNS + 1):
		total += _nose_point(i, 0.0, width).distance_to(_nose_point(i - 1, 0.0, width))
		arc[i] = total

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in NOSE_ROWS + 1:
		var v := float(j) / NOSE_ROWS
		for i in NOSE_COLUMNS + 1:
			st.set_uv(Vector2(arc[i] - total * 0.5, v * HEADROOM))
			st.add_vertex(frame * _nose_point(i, v, width))
	for j in NOSE_ROWS:
		for i in NOSE_COLUMNS:
			# Clockwise as seen from the room: Godot's front face.
			var a := j * (NOSE_COLUMNS + 1) + i
			var c := a + NOSE_COLUMNS + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(c)
			st.add_index(c + 1)
	st.generate_normals()
	var shell := kit.add_mesh(st.commit(), material, "NoseShell")

	for target in NOSE_RIBS:
		if absf(target) > total * 0.5 - 0.1:
			continue
		var best := 0
		for i in NOSE_COLUMNS + 1:
			if absf(arc[i] - total * 0.5 - target) < absf(arc[best] - total * 0.5 - target):
				best = i
		_nose_rib(kit, frame, width, PI * float(best) / NOSE_COLUMNS)
	_nose_band(kit, frame, width, NOSE_BROW, NOSE_BROW + 0.03)
	_dash(kit, frame, width)
	kit.light(frame * Vector3(0, 2.0, 0.6), InteriorPalette.LIGHT_WARM, 0.5, 3.0, &"cockpit")
	return shell

## The shell's depth at height fraction v: vertical up to NOSE_VERTICAL, then
## curving back to meet the ceiling edge.
static func _nose_depth(v: float) -> float:
	if v <= NOSE_VERTICAL:
		return NOSE_DEPTH
	var t := (v - NOSE_VERTICAL) / (1.0 - NOSE_VERTICAL)
	return NOSE_DEPTH * sqrt(maxf(0.0, 1.0 - t * t))

static func _nose_point(i: int, v: float, width: float) -> Vector3:
	return _nose_at(PI * float(i) / NOSE_COLUMNS, v, width)

static func _nose_at(theta: float, v: float, width: float) -> Vector3:
	return Vector3(-width * 0.5 * cos(theta), HEADROOM * v, -_nose_depth(v) * sin(theta))

## The shell's normal at (theta, v), pointing into the room.
static func _nose_normal(theta: float, v: float, width: float) -> Vector3:
	var e := 0.001
	var dt := _nose_at(theta + e, v, width) - _nose_at(theta - e, v, width)
	var dv := _nose_at(theta, minf(v + e, 1.0), width) - _nose_at(theta, maxf(v - e, 0.0), width)
	var n := dt.cross(dv).normalized()
	return n if n.z > 0.0 else -n

## A chunky rib, 0.1 m wide and 0.05 m proud, from the dash to the ceiling
## along one meridian of the shell: a face and two sides.
static func _nose_rib(kit: InteriorKit, frame: Transform3D, width: float, theta: float) -> void:
	var half := 0.05 / (width * 0.5)
	var steps := 10
	var v0 := DASH_HEIGHT / HEADROOM
	var color := _c(InteriorPalette.TRIM)
	for k in steps:
		var va := lerpf(v0, 1.0, float(k) / steps)
		var vb := lerpf(v0, 1.0, float(k + 1) / steps)
		var na := _nose_normal(theta, va, width)
		var nb := _nose_normal(theta, vb, width)
		var la := _nose_at(theta - half, va, width)
		var ra := _nose_at(theta + half, va, width)
		var lb := _nose_at(theta - half, vb, width)
		var rb := _nose_at(theta + half, vb, width)
		kit.quad(SOLID, frame * (la + na * 0.05), frame * (ra + na * 0.05), frame * (rb + nb * 0.05),
			frame * (lb + nb * 0.05), (frame.basis * na).normalized(), color)
		var side_n := (ra - la).normalized()
		kit.quad(SOLID, frame * la, frame * (la + na * 0.05), frame * (lb + nb * 0.05), frame * lb,
			(frame.basis * -side_n).normalized(), color)
		kit.quad(SOLID, frame * ra, frame * (ra + na * 0.05), frame * (rb + nb * 0.05), frame * rb,
			(frame.basis * side_n).normalized(), color)

## A lit ribbon along the whole curve between two floor-relative heights,
## lifted just off the shell so it never z-fights it.
static func _nose_band(kit: InteriorKit, frame: Transform3D, width: float, h_lo: float, h_hi: float) -> void:
	var v_lo := h_lo / HEADROOM
	var v_hi := h_hi / HEADROOM
	var color := _lit(InteriorPalette.LIGHT_WARM, 2.2)
	for i in NOSE_COLUMNS:
		var t0 := PI * float(i) / NOSE_COLUMNS
		var t1 := PI * float(i + 1) / NOSE_COLUMNS
		var n := _nose_normal((t0 + t1) * 0.5, (v_lo + v_hi) * 0.5, width)
		kit.quad(GLOW, frame * (_nose_at(t0, v_lo, width) + n * 0.01), frame * (_nose_at(t1, v_lo, width) + n * 0.01),
			frame * (_nose_at(t1, v_hi, width) + n * 0.01), frame * (_nose_at(t0, v_hi, width) + n * 0.01),
			(frame.basis * n).normalized(), color)

## The dash's front edge: a shallower curve inside the shell, so the rail on
## top of it sweeps round the cockpit the way the shell does.
static func _dash_front(i: int, width: float) -> Vector3:
	var theta := PI * float(i) / NOSE_COLUMNS
	return Vector3(-width * 0.5 * cos(theta), 0.0, -DASH_INSET * sin(theta))

## The alcove floor, the dash top, its curved face, the glowing plinth under
## it, the wooden rail on it and three screen desks.
static func _dash(kit: InteriorKit, frame: Transform3D, width: float) -> void:
	var up := (frame.basis * Vector3.UP).normalized()
	var toward_room := (frame.basis * Vector3.BACK).normalized()
	var cap_v := DASH_HEIGHT / HEADROOM
	var lift := Vector3(0, DASH_HEIGHT, 0)
	for i in NOSE_COLUMNS:
		var f0 := _dash_front(i, width)
		var f1 := _dash_front(i + 1, width)
		var s0 := _nose_point(i, cap_v, width)
		var s1 := _nose_point(i + 1, cap_v, width)
		var g0 := _nose_point(i, 0.0, width)
		var g1 := _nose_point(i + 1, 0.0, width)
		kit.quad(SOLID, frame * Vector3(f0.x, 0.001, 0.0), frame * Vector3(f1.x, 0.001, 0.0),
			frame * Vector3(g1.x, 0.001, g1.z), frame * Vector3(g0.x, 0.001, g0.z), up,
			_c(InteriorPalette.FLOOR_BRIDGE))
		kit.quad(SOLID, frame * (f0 + lift), frame * (f1 + lift), frame * Vector3(s1.x, DASH_HEIGHT, s1.z),
			frame * Vector3(s0.x, DASH_HEIGHT, s0.z), up, _c(InteriorPalette.TRIM))
		var face_n := (frame.basis * (f1 - f0).cross(Vector3.UP)).normalized()
		if face_n.dot(toward_room) < 0.0:
			face_n = -face_n
		kit.quad(SOLID, frame * (f0 + Vector3(0, 0.1, 0)), frame * (f1 + Vector3(0, 0.1, 0)),
			frame * (f1 + lift), frame * (f0 + lift), face_n, _c(InteriorPalette.WALL_LOW))
		kit.quad(GLOW, frame * (f0 + Vector3(0, 0.0, -0.05)), frame * (f1 + Vector3(0, 0.0, -0.05)),
			frame * (f1 + Vector3(0, 0.1, -0.05)), frame * (f0 + Vector3(0, 0.1, -0.05)), face_n,
			_lit(InteriorPalette.LIGHT_WARM, 2.5))
		kit.tube_between(SOLID, frame * (f0 + lift + Vector3(0, 0.04, 0)),
			frame * (f1 + lift + Vector3(0, 0.04, 0)), 0.055, _c(InteriorPalette.WOOD))
	for k in 3:
		var desk := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-60.0)),
			Vector3((k - 1) * width * 0.28, DASH_HEIGHT + 0.09, -0.8))
		kit.bevel_box(SOLID, frame * desk, Vector3(minf(1.3, width * 0.25), 0.32, 0.06), 0.025,
			_c(InteriorPalette.TRIM))
		kit.screen(frame * desk * _at(Vector3(0, 0, 0.031)), Vector2(minf(1.18, width * 0.22), 0.24),
			_mode(k), 0.2 + 0.3 * k)

## The wraparound cockpit pod, in a pod frame (see POD_OUTLINE): a mauve floor
## with a lit edge strip, lower panels, portal glass all round from the sill up,
## a header band and a sill ledge on every glazed segment, chunky posts at the
## glazed corners, a roof with a round light, and a header over the mouth up to
## the cabin ceiling. It brings its own colliders -- a floor, a roof and a wall
## per segment -- because the mouth it opens from has none.
static func cockpit_pod(kit: InteriorKit, f: Transform3D) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	var floor_colour := _c(InteriorPalette.FLOOR_BRIDGE)
	var ceiling := _c(InteriorPalette.CEILING)
	var up := (f.basis * Vector3.UP).normalized()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in POD_OUTLINE:
		lo = lo.min(p)
		hi = hi.max(p)
	var centre := Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5)
	var lift := Vector3(0, 0.004, 0)
	var roof := Vector3(0, POD_ROOF, 0)
	var last := POD_OUTLINE.size() - 1
	# Floor and roof fans, the mouth's triangle included.
	for i in POD_OUTLINE.size():
		var p0 := _pod_point(i)
		var p1 := _pod_point((i + 1) % POD_OUTLINE.size())
		kit.tri(SOLID, f * (centre + lift), f * (p0 + lift), f * (p1 + lift), up, floor_colour)
		kit.tri(SOLID, f * (centre + roof), f * (p0 + roof), f * (p1 + roof), -up, ceiling)
	# An apron back over the room's deck, so no crack shows where the two floors meet.
	var apron := Vector3(0, 0, 0.1)
	kit.quad(SOLID, f * (_pod_point(0) + lift), f * (_pod_point(last) + lift),
		f * (_pod_point(last) + lift + apron), f * (_pod_point(0) + lift + apron), up, floor_colour)
	for i in last:
		var p0 := _pod_point(i)
		var p1 := _pod_point(i + 1)
		var along := (p1 - p0).normalized()
		var inward := Vector3.UP.cross(along)
		if inward.dot(centre - (p0 + p1) * 0.5) < 0.0:
			inward = -inward
		var n := (f.basis * inward).normalized()
		var strip := Vector3(0, 0.006, 0)
		kit.quad(GLOW, f * (p0 + inward * 0.02 + strip), f * (p1 + inward * 0.02 + strip),
			f * (p1 + inward * 0.06 + strip), f * (p0 + inward * 0.06 + strip), up,
			_lit(InteriorPalette.LIGHT_WARM, 2.0))
		var glazed := i > 0 and i < last - 1
		var panel_top := Vector3(0, POD_SILL if glazed else POD_ROOF, 0)
		kit.quad(SOLID, f * p0, f * p1, f * (p1 + panel_top), f * (p0 + panel_top), n, low)
		var wall := Basis(along, Vector3.UP, along.cross(Vector3.UP))
		if glazed:
			var sill := Vector3(0, POD_SILL, 0)
			var top := Vector3(0, POD_GLASS_TOP, 0)
			kit.quad(PORTAL, f * (p0 + sill), f * (p1 + sill), f * (p1 + top), f * (p0 + top), n,
				_c(InteriorPalette.GLASS))
			kit.quad(SOLID, f * (p0 + top), f * (p1 + top), f * (p1 + roof), f * (p0 + roof), n, trim)
			kit.bevel_box(SOLID, f * Transform3D(wall, (p0 + p1) * 0.5 + inward * 0.06 + sill),
				Vector3(p0.distance_to(p1), 0.06, 0.14), 0.02, trim)
		kit.collider(f * Transform3D(wall, (p0 + p1) * 0.5 - inward * 0.05 + Vector3(0, POD_ROOF * 0.5, 0)),
			Vector3(p0.distance_to(p1) + 0.1, POD_ROOF, 0.1))
	for i in range(1, last):
		kit.bevel_box(SOLID, f * _at(_pod_point(i) + Vector3(0, POD_ROOF * 0.5, 0)),
			Vector3(0.14, POD_ROOF, 0.14), 0.04, trim)
	var span := Vector3(hi.x - lo.x, 0.1, hi.y - lo.y)
	kit.collider(f * _at(centre + Vector3(0, -0.05, 0)), span)
	kit.collider(f * _at(centre + Vector3(0, POD_ROOF + 0.05, 0)), span)
	ceiling_light(kit, f * (centre + roof))
	kit.bevel_box(SOLID, f * _at(Vector3(0, (POD_ROOF + HEADROOM) * 0.5, 0)),
		Vector3(BAY + 0.3, HEADROOM - POD_ROOF, 0.16), 0.04, trim)
	kit.box(GLOW, f * _at(Vector3(0, POD_ROOF + 0.03, 0.085)), Vector3(BAY, 0.03, 0.02),
		_lit(InteriorPalette.LIGHT_WARM, 2.2))

static func _pod_point(i: int) -> Vector3:
	return Vector3(POD_OUTLINE[i].x, 0.0, POD_OUTLINE[i].y)

## A shoulder of the front wall beside a pod, in a wall frame on the canopy
## face: the wall itself (the builder draws none at canopy faces) round a
## portal window at eye height in a chunky frame, the usual trim, and a
## console desk under the window.
static func shoulder(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var wall := _c(InteriorPalette.WALL)
	var trim := _c(InteriorPalette.TRIM)
	var back := -WALL_THICKNESS * 0.5
	var n := (f.basis * Vector3.BACK).normalized()
	var half := BAY * 0.5
	var w := SHOULDER_WINDOW_HALF
	for band: Vector2 in [Vector2(0.0, SHOULDER_WINDOW_LOW), Vector2(SHOULDER_WINDOW_HIGH, HEADROOM)]:
		kit.quad(SOLID, f * Vector3(-half, band.x, back), f * Vector3(half, band.x, back),
			f * Vector3(half, band.y, back), f * Vector3(-half, band.y, back), n, wall)
	for side: Vector2 in [Vector2(-half, -w), Vector2(w, half)]:
		kit.quad(SOLID, f * Vector3(side.x, SHOULDER_WINDOW_LOW, back), f * Vector3(side.y, SHOULDER_WINDOW_LOW, back),
			f * Vector3(side.y, SHOULDER_WINDOW_HIGH, back), f * Vector3(side.x, SHOULDER_WINDOW_HIGH, back), n, wall)
	kit.quad(PORTAL, f * Vector3(-w, SHOULDER_WINDOW_LOW, back), f * Vector3(w, SHOULDER_WINDOW_LOW, back),
		f * Vector3(w, SHOULDER_WINDOW_HIGH, back), f * Vector3(-w, SHOULDER_WINDOW_HIGH, back), n,
		_c(InteriorPalette.GLASS))
	var mid := (SHOULDER_WINDOW_LOW + SHOULDER_WINDOW_HIGH) * 0.5
	var tall := SHOULDER_WINDOW_HIGH - SHOULDER_WINDOW_LOW
	for x in [-(w + 0.05), w + 0.05]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, mid, 0.03)), Vector3(0.1, tall + 0.1, 0.08), 0.03, trim)
	for y in [SHOULDER_WINDOW_LOW - 0.05, SHOULDER_WINDOW_HIGH + 0.05]:
		kit.bevel_box(SOLID, f * _at(Vector3(0, y, 0.03)), Vector3(2.0 * w + 0.2, 0.1, 0.08), 0.03, trim)
	wall_trim(kit, f)
	console(kit, f, variety, false)

## The captain's chair and helm console, in a fixture frame: origin on the
## floor under the seat, -z the way it faces, +y up (cockpit pod spec §5). A
## pedestal with a glowing base; a seat pan and cushion; a backrest tilted back
## with channel stitching, side bolsters and a shell; a headrest just behind
## SEATED_EYE; armrests with control pads, a flight stick on the right and a
## throttle on the left; and a low helm console ahead with two screens and lit
## buttons, under the seated sightline. Only the helm has a collider: the
## chair itself is the scene's interactable seat box.
static func pilot_station(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	var seat := _c(InteriorPalette.SEAT)
	# Pedestal: a glowing base, a chunky foot and a column.
	kit.disc(GLOW, f * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.012, 0.25)), 0.36,
		_lit(InteriorPalette.LIGHT_WARM, 2.2))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.06, 0.25)), Vector3(0.62, 0.1, 0.62), 0.04, trim)
	kit.tube_between(SOLID, f * Vector3(0, 0.1, 0.25), f * Vector3(0, 0.34, 0.25), 0.09, low)
	# Seat pan and cushion.
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.37, 0.26)), Vector3(0.7, 0.08, 0.64), 0.03, low)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.47, 0.25)), Vector3(0.62, 0.14, 0.58), 0.06, seat)
	# Backrest, tilted back 12 degrees: a shell, the cushion, channel stitching
	# and side bolsters.
	var back := f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0, 0.95, 0.66))
	kit.bevel_box(SOLID, back * _at(Vector3(0, 0, 0.06)), Vector3(0.68, 0.86, 0.1), 0.04, low)
	kit.bevel_box(SOLID, back, Vector3(0.6, 0.8, 0.12), 0.06, seat)
	for x in [-0.15, 0.0, 0.15]:
		kit.box(SOLID, back * _at(Vector3(x, 0, -0.061)), Vector3(0.012, 0.66, 0.004), low)
	for side in [-1.0, 1.0]:
		kit.bevel_box(SOLID, back * _at(Vector3(side * 0.33, -0.05, -0.04)), Vector3(0.08, 0.7, 0.16), 0.035, seat)
	kit.bevel_box(SOLID, back * _at(Vector3(0, 0.52, 0.0)), Vector3(0.4, 0.2, 0.13), 0.06, seat)
	# Armrests with control pads.
	for side in [-1.0, 1.0]:
		var x: float = side * 0.4
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.52, 0.42)), Vector3(0.08, 0.3, 0.08), 0.02, low)
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.7, 0.22)), Vector3(0.13, 0.08, 0.56), 0.035, trim)
		var pad := f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), Vector3(x, 0.75, 0.02))
		kit.bevel_box(SOLID, pad, Vector3(0.15, 0.03, 0.18), 0.01, _c(InteriorPalette.SCREEN_BACK))
		kit.screen(pad * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.016, 0.02)),
			Vector2(0.11, 0.08), InteriorKit.Screen.DOTS, fposmod(variety + side * 0.2, 1.0))
		kit.bevel_box(GLOW, pad * _at(Vector3(0, 0.02, -0.06)), Vector3(0.1, 0.012, 0.025), 0.004,
			_lit(InteriorPalette.AMBER if side > 0.0 else InteriorPalette.SKY, 1.6))
	# Flight stick on the right, throttle on the left.
	kit.tube_between(SOLID, f * Vector3(0.4, 0.74, 0.14), f * Vector3(0.4, 0.9, 0.1), 0.022, low)
	kit.bevel_box(SOLID, f * _at(Vector3(0.4, 0.93, 0.1)), Vector3(0.06, 0.09, 0.06), 0.02, trim)
	kit.bevel_box(GLOW, f * _at(Vector3(0.4, 0.98, 0.1)), Vector3(0.03, 0.012, 0.03), 0.005,
		_lit(InteriorPalette.CORAL, 1.8))
	kit.bevel_box(SOLID, f * _at(Vector3(-0.4, 0.8, 0.2)), Vector3(0.05, 0.14, 0.07), 0.015, low)
	kit.bevel_box(SOLID, f * _at(Vector3(-0.4, 0.88, 0.2)), Vector3(0.09, 0.04, 0.09), 0.015, trim)
	# The helm console, low and ahead.
	kit.box(GLOW, f * _at(Vector3(0, 0.04, -0.72)), Vector3(0.9, 0.08, 0.22), _lit(InteriorPalette.LIGHT_WARM, 2.5))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.36, -0.72)), Vector3(1.1, 0.56, 0.3), 0.05, trim)
	var face := f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-55.0)), Vector3(0, 0.7, -0.64))
	kit.bevel_box(SOLID, face, Vector3(1.1, 0.3, 0.05), 0.02, trim)
	kit.bevel_box(SOLID, face * _at(Vector3(0, 0, 0.03)), Vector3(1.0, 0.24, 0.012), 0.005,
		_c(InteriorPalette.SCREEN_BACK))
	var first := int(variety * 3.0)
	kit.screen(face * _at(Vector3(-0.26, 0, 0.038)), Vector2(0.44, 0.19), _mode(first), variety)
	kit.screen(face * _at(Vector3(0.26, 0, 0.038)), Vector2(0.44, 0.19), _mode(first + 1),
		fposmod(variety + 0.52, 1.0))
	var buttons: Array[Color] = [InteriorPalette.AMBER, InteriorPalette.SKY, InteriorPalette.LIGHT_WARM,
		InteriorPalette.CORAL, InteriorPalette.SKY]
	for i in buttons.size():
		kit.bevel_box(GLOW, f * _at(Vector3(-0.3 + i * 0.15, 0.5, -0.565)), Vector3(0.08, 0.05, 0.02), 0.008,
			_lit(buttons[i], 1.6, 0.4 if i == 3 else 1.0))
	kit.collider(f * _at(Vector3(0, 0.4, -0.72)), Vector3(1.1, 0.8, 0.3))
	kit.light(f * Vector3(0, 0.9, -0.3), InteriorPalette.LIGHT_WARM, 0.35, 1.6, &"helm")

## A bunk bed along the wall, two tiers with a reading strip under the top one;
## or, where the wall has a porthole above, one low bunk under it.
static func bunks(kit: InteriorKit, f: Transform3D, _variety: float, low_only: bool) -> void:
	_bed(kit, f, 0.0, 0.4)
	var top := 0.6
	if not low_only:
		for side in [-1.0, 1.0]:
			kit.bevel_box(SOLID, f * _at(Vector3(side * 0.93, 0.72, 0.86)), Vector3(0.08, 1.44, 0.08), 0.02,
				_c(InteriorPalette.WALL_LOW))
		_bed(kit, f, 1.3, 0.14)
		kit.box(GLOW, f * _at(Vector3(0, 1.295, 0.45)), Vector3(1.6, 0.01, 0.05), _lit(InteriorPalette.LIGHT_WARM, 1.2))
		top = 1.7
		kit.collider(f * _at(Vector3(0, (1.3 + top) * 0.5, 0.45)), Vector3(1.9, top - 1.3, 0.9))
	kit.collider(f * _at(Vector3(0, BUNK_MATTRESS_TOP * 0.5, 0.45)), Vector3(1.9, BUNK_MATTRESS_TOP, 0.9))

## Something lying on the lower bunk's mattress, clear of the pillow.
static func bunks_spots() -> Array:
	return [[Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.35, BUNK_MATTRESS_TOP, 0.45)), &"tool"]]

## One bed: a frame from `base` up `frame_h`, a mattress on it and a pillow.
static func _bed(kit: InteriorKit, f: Transform3D, base: float, frame_h: float) -> void:
	var deck := base + frame_h
	kit.bevel_box(SOLID, f * _at(Vector3(0, base + frame_h * 0.5, 0.45)), Vector3(1.9, frame_h, 0.9), 0.04,
		_c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(0, deck + 0.07, 0.45)), Vector3(1.8, 0.14, 0.8), 0.05,
		_c(InteriorPalette.MATTRESS))
	kit.bevel_box(SOLID, f * _at(Vector3(0.62, deck + 0.19, 0.45)), Vector3(0.42, 0.1, 0.56), 0.04,
		_c(InteriorPalette.TRIM))

## Two tall locker doors with vents and indicators, 0.82 m overall.
static func tall_lockers(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 0.21
		kit.bevel_box(SOLID, f * _at(Vector3(x, 1.0, 0.05)), Vector3(0.4, 1.95, 0.1), 0.03, _c(InteriorPalette.TRIM))
		for k in 3:
			kit.box(SOLID, f * _at(Vector3(x, 1.65 + k * 0.05, 0.101)), Vector3(0.24, 0.015, 0.01),
				_c(InteriorPalette.WALL_LOW))
		var h := fposmod(variety * 7.0 + side, 1.0)
		kit.disc(GLOW, f * _at(Vector3(x + 0.12, 1.2, 0.101)), 0.025,
			_lit(InteriorPalette.AMBER if h > 0.7 else InteriorPalette.LIGHT_WARM, 1.6))

## A galley counter with a sink, a tap and two glowing cooktop rings, and
## cupboards above -- unless a porthole needs the wall.
static func galley_counter(kit: InteriorKit, f: Transform3D, _variety: float, porthole: bool) -> void:
	var trim := _c(InteriorPalette.TRIM)
	var low := _c(InteriorPalette.WALL_LOW)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.43, 0.3)), Vector3(1.8, 0.86, 0.6), 0.04, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.885, 0.32)), Vector3(1.9, 0.05, 0.64), 0.02, low)
	for x in [-0.3, 0.3]:
		kit.box(SOLID, f * _at(Vector3(x, 0.45, 0.602)), Vector3(0.015, 0.7, 0.01), low)
	kit.box(SOLID, f * _at(Vector3(-0.45, 0.912, 0.3)), Vector3(0.5, 0.006, 0.36), _c(InteriorPalette.SCREEN_BACK))
	kit.tube_between(SOLID, f * Vector3(-0.45, 0.91, 0.08), f * Vector3(-0.45, 1.08, 0.08), 0.02, trim)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	for x in [0.35, 0.72]:
		kit.annulus(GLOW, f * Transform3D(up, Vector3(x, 0.913, 0.3)), 0.08, 0.12, _lit(InteriorPalette.CORAL, 1.8))
	if not porthole:
		kit.bevel_box(SOLID, f * _at(Vector3(0, 1.65, 0.17)), Vector3(1.8, 0.4, 0.34), 0.04, trim)
		kit.box(SOLID, f * _at(Vector3(0, 1.65, 0.341)), Vector3(0.015, 0.36, 0.01), low)
	kit.collider(f * _at(Vector3(0, 0.45, 0.32)), Vector3(1.9, 0.9, 0.64))

## Two small things on the galley worktop, between the sink and the cooktop.
static func galley_counter_spots() -> Array:
	return [
		[_at(Vector3(-0.08, 0.91, 0.36)), &"small"],
		[_at(Vector3(0.12, 0.91, 0.36)), &"small"],
	]

## A tall fridge, 0.8 m wide, with a handle and a status light.
static func fridge(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var x := 0.0
	kit.bevel_box(SOLID, f * _at(Vector3(x, 0.925, 0.3)), Vector3(0.8, 1.85, 0.6), 0.05, _c(InteriorPalette.TRIM))
	kit.box(SOLID, f * _at(Vector3(x, 1.25, 0.601)), Vector3(0.76, 0.015, 0.01), _c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(x - 0.3, 1.45, 0.62)), Vector3(0.04, 0.35, 0.05), 0.015,
		_c(InteriorPalette.WALL_LOW))
	kit.disc(GLOW, f * _at(Vector3(x + 0.28, 1.65, 0.602)), 0.025, _lit(InteriorPalette.SKY, 1.6))
	kit.collider(f * _at(Vector3(x, 0.925, 0.3)), Vector3(0.8, 1.85, 0.6))

## A toilet and a sink under a mirror lit from above.
static func washstand(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	kit.bevel_box(SOLID, f * _at(Vector3(-0.5, 0.2, 0.3)), Vector3(0.4, 0.4, 0.55), 0.06, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(-0.5, 0.43, 0.32)), Vector3(0.44, 0.06, 0.5), 0.025, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(-0.5, 0.62, 0.09)), Vector3(0.44, 0.38, 0.18), 0.04, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(0.45, 0.4, 0.2)), Vector3(0.14, 0.8, 0.14), 0.03, trim)
	kit.bevel_box(SOLID, f * _at(Vector3(0.45, 0.85, 0.24)), Vector3(0.56, 0.14, 0.44), 0.05, trim)
	kit.tube_between(SOLID, f * Vector3(0.45, 0.92, 0.05), f * Vector3(0.45, 1.02, 0.05), 0.02,
		_c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(0.45, 1.45, 0.015)), Vector3(0.5, 0.55, 0.03), 0.015, trim)
	kit.box(SOLID, f * _at(Vector3(0.45, 1.45, 0.032)), Vector3(0.42, 0.47, 0.004), _c(InteriorPalette.MIRROR))
	kit.box(GLOW, f * _at(Vector3(0.45, 1.75, 0.03)), Vector3(0.44, 0.03, 0.03), _lit(InteriorPalette.LIGHT_WARM, 2.0))
	# A bracket over the toilet, beside the mirror, for a medkit
	# (washstand_spots()). Under 0.15 m proud, so it needs no collider.
	kit.bevel_box(SOLID, f * _at(Vector3(-0.5, WASHSTAND_BRACKET - 0.015, 0.075)), Vector3(0.36, 0.03, 0.13), 0.01,
		trim)
	kit.collider(f * _at(Vector3(0, 0.45, 0.3)), Vector3(1.5, 0.9, 0.6))

## The medkit bracket beside the mirror.
static func washstand_spots() -> Array:
	return [[_at(Vector3(-0.5, WASHSTAND_BRACKET, 0.08)), &"tool"]]

## A towel on a rail.
static func towel_rail(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	for x in [-0.45, 0.45]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, 1.1, 0.035)), Vector3(0.05, 0.08, 0.07), 0.015, trim)
	kit.tube_x(SOLID, f * _at(Vector3(0, 1.1, 0.07)), 0.02, 0.95, trim)
	var towel := InteriorPalette.CORAL if variety < 0.5 else InteriorPalette.SKY
	kit.bevel_box(SOLID, f * _at(Vector3(-0.1, 0.88, 0.09)), Vector3(0.5, 0.46, 0.03), 0.012, _c(towel))

## Three shelves `width` wide, stacked with crates of seeded sizes and colours.
## The places in shelves_spots() stay clear for real items, and each post and
## board is its own collider so the Interactor can reach between them.
static func shelves(kit: InteriorKit, f: Transform3D, variety: float, width := 1.7) -> void:
	var half := width * 0.5
	for x in [-(half - 0.03), half - 0.03]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, 1.0, 0.2)), Vector3(0.05, 2.0, SHELF_DEPTH), 0.015,
			_c(InteriorPalette.WALL_LOW))
		kit.collider(f * _at(Vector3(x, 1.0, 0.2)), Vector3(0.05, 2.0, SHELF_DEPTH))
	var spots := shelves_spots(width)
	for level in SHELF_LEVELS:
		var y := SHELF_BASE + level * SHELF_PITCH
		kit.bevel_box(SOLID, f * _at(Vector3(0, y, 0.2)), Vector3(width - 0.06, SHELF_BOARD, SHELF_DEPTH), 0.015,
			_c(InteriorPalette.TRIM))
		kit.collider(f * _at(Vector3(0, y, 0.2)), Vector3(width - 0.06, SHELF_BOARD, SHELF_DEPTH))
		var reserved := _reserved_on(spots, shelf_top(level))
		var x := -half + 0.13
		var k := 0
		while true:
			var h := fposmod(variety * 31.0 + level * 7.3 + k * 3.1, 1.0)
			var w := 0.25 + 0.2 * h
			x = _clear_of(reserved, x, w)
			if x + w > half - 0.07:
				break
			var tall := 0.18 + 0.18 * fposmod(h * 5.7, 1.0)
			kit.bevel_box(SOLID, f * _at(Vector3(x + w * 0.5, y + 0.02 + tall * 0.5, 0.2)),
				Vector3(w - 0.03, tall, 0.3), 0.03, _c(InteriorPalette.CRATES[int(h * 5.0) % 5]))
			x += w + 0.04
			k += 1

## The top surface of shelf board `level`.
static func shelf_top(level: int) -> float:
	return SHELF_BASE + level * SHELF_PITCH + SHELF_BOARD * 0.5

## Where shelves hold loose items (hands-and-items spec §5.2): canisters on the
## third board and, on a full-width unit, a crate on the lowest. Each spot is
## [frame, stow class]; a frame's origin is where the item's base sits.
static func shelves_spots(width: float) -> Array:
	var half := width * 0.5
	var out: Array = [[_at(Vector3(-half + 0.2, shelf_top(2), 0.2)), &"small"]]
	if width >= 1.2:
		out.append([_at(Vector3(-half + 0.45, shelf_top(2), 0.2)), &"small"])
		out.append([_at(Vector3(half - 0.35, shelf_top(0), 0.2)), &"crate"])
		out.append([_at(Vector3(-half + 0.35, shelf_top(0), 0.2)), &"crate"])
		for x in [-half + 0.25, -half + 0.5, -half + 0.75]:
			out.append([_at(Vector3(x, shelf_top(1), 0.2)), &"small"])
		for x in [-0.05, half - 0.6, half - 0.3]:
			out.append([_at(Vector3(x, shelf_top(2), 0.2)), &"tool"])
	else:
		for x in [-half + 0.2, -half + 0.5]:
			out.append([_at(Vector3(x, shelf_top(1), 0.2)), &"small"])
		out.append([_at(Vector3(0.0, shelf_top(0), 0.2)), &"crate"])
	return out

## The x ranges a shelf board keeps clear for the spots on it.
static func _reserved_on(spots: Array, top: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for spot in spots:
		var at: Vector3 = (spot[0] as Transform3D).origin
		if absf(at.y - top) < 0.001:
			var clear: float = STOW_CLEARANCE.get(spot[1], 0.15)
			out.append(Vector2(at.x - clear, at.x + clear))
	return out

## Moves a decor crate starting at `x`, `w` wide, past any reserved range it
## would overlap.
static func _clear_of(reserved: Array[Vector2], x: float, w: float) -> float:
	var moved := true
	while moved:
		moved = false
		for r in reserved:
			if x < r.y and x + w > r.x:
				x = r.y + 0.04
				moved = true
	return x

## Three chunky rifles on a rack over a gunmetal cabinet, with coral warning
## stripes, and a pistol cradle either side (weapon_rack_spots()). The rifles
## and cradles stand under 0.15 m proud, so only the cabinet is solid and the
## pistols stay in reach of the Interactor.
static func weapon_rack(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.2, 0.175)), Vector3(1.6, 0.4, 0.35), 0.04, gun)
	kit.box(SOLID, f * _at(Vector3(0, 0.36, 0.352)), Vector3(1.6, 0.05, 0.01), _c(InteriorPalette.CORAL))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.15, 0.025)), Vector3(1.6, 1.1, 0.05), 0.02, _c(InteriorPalette.WALL_LOW))
	kit.box(SOLID, f * _at(Vector3(0, 1.67, 0.052)), Vector3(1.6, 0.05, 0.01), _c(InteriorPalette.CORAL))
	for i in 3:
		var x := -0.3 + i * 0.3
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.75, 0.1)), Vector3(0.1, 0.22, 0.07), 0.02, _c(InteriorPalette.WOOD))
		kit.bevel_box(SOLID, f * _at(Vector3(x, 1.13, 0.1)), Vector3(0.11, 0.55, 0.08), 0.02, gun)
		kit.bevel_box(SOLID, f * _at(Vector3(x + 0.07, 1.05, 0.1)), Vector3(0.05, 0.16, 0.06), 0.012, gun)
		kit.tube_between(SOLID, f * Vector3(x, 1.4, 0.1), f * Vector3(x, 1.6, 0.1), 0.018, gun)
		kit.disc(GLOW, f * _at(Vector3(x, 1.27, 0.141)), 0.012, _lit(InteriorPalette.SKY, 1.5))
	for spot in weapon_rack_spots():
		var at: Vector3 = (spot[0] as Transform3D).origin
		kit.bevel_box(SOLID, f * _at(Vector3(at.x, at.y - 0.02, 0.075)), Vector3(0.26, 0.04, 0.1), 0.012,
			_c(InteriorPalette.TRIM))
		kit.disc(GLOW, f * _at(Vector3(at.x, at.y - 0.12, 0.051)), 0.014, _lit(InteriorPalette.SKY, 1.5))
	kit.disc(GLOW, f * _at(Vector3(0.7, 0.3, 0.352)), 0.025, _lit(InteriorPalette.AMBER, 1.6, 0.5))
	kit.collider(f * _at(Vector3(0, 0.2, 0.175)), Vector3(1.6, 0.4, 0.35))

## The rack's two pistol cradles, muzzles pointing outward along the wall.
static func weapon_rack_spots() -> Array:
	return [
		[Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.6, 1.0, 0.085)), &"sidearm"],
		[Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.6, 1.0, 0.085)), &"sidearm"],
	]

## A stack of three ammo crates with stripes and latches, 0.7 m wide.
static func ammo_crates(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var spots: Array[Vector3] = [Vector3(0, 0.2, 0.25), Vector3(0, 0.6, 0.25), Vector3(0, 1.0, 0.25)]
	for i in spots.size():
		var p := spots[i]
		kit.bevel_box(SOLID, f * _at(p), Vector3(0.7, 0.4, 0.5), 0.04, _c(InteriorPalette.OLIVE))
		kit.box(SOLID, f * _at(p + Vector3(0, 0.08, 0.251)), Vector3(0.66, 0.05, 0.01),
			_c(InteriorPalette.AMBER if i % 2 == 0 else InteriorPalette.CORAL))
		for side in [-0.25, 0.25]:
			kit.bevel_box(SOLID, f * _at(p + Vector3(side, -0.05, 0.255)), Vector3(0.08, 0.06, 0.02), 0.008,
				_c(InteriorPalette.TRIM))
	kit.collider(f * _at(Vector3(0, 0.6, 0.25)), Vector3(0.7, 1.2, 0.5))

## Two flat things lying along the top of the crate stack.
static func ammo_crates_spots() -> Array:
	return [
		[Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.15, 1.2, 0.25)), &"tool"],
		[Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.15, 1.2, 0.25)), &"tool"],
	]

## A doorway's frame, drawn once for both rooms: two chunky posts through the
## wall, a header across the top and a lit strip under it. The frame's origin is on the owning side's inner
## surface, so the posts straddle the wall's mid-plane just behind it.
static func door_frame(kit: InteriorKit, f: Transform3D) -> void:
	var mid := -WALL_THICKNESS * 0.5
	for side in [-1.0, 1.0]:
		kit.bevel_box(SOLID, f * _at(Vector3(side * (DOOR_WIDTH * 0.5 + 0.07), DOOR_HEIGHT * 0.5, mid)),
			Vector3(0.14, DOOR_HEIGHT, 0.24), 0.04, _c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * _at(Vector3(0, DOOR_HEIGHT + 0.06, mid)), Vector3(DOOR_WIDTH + 0.28, 0.12, 0.24),
		0.04, _c(InteriorPalette.TRIM))
	kit.box(GLOW, f * _at(Vector3(0, DOOR_HEIGHT - 0.012, mid)), Vector3(DOOR_WIDTH, 0.02, 0.12),
		_lit(InteriorPalette.LIGHT_WARM, 2.0))
	kit.light(f * Vector3(0, DOOR_HEIGHT, 0.3), InteriorPalette.LIGHT_WARM, 0.5, 2.5, &"door")

static func _at(offset: Vector3) -> Transform3D:
	return InteriorKit.at(offset)

static func _c(color: Color) -> Color:
	return InteriorKit.solid(color)

static func _lit(color: Color, energy: float, blink_phase := 1.0) -> Color:
	return InteriorKit.lit(color, energy, blink_phase)

## Screen modes in a fixed cycle, so a variety picks one without an int-to-enum cast.
static func _mode(i: int) -> InteriorKit.Screen:
	var modes := [InteriorKit.Screen.BARS, InteriorKit.Screen.WAVE, InteriorKit.Screen.DOTS]
	return modes[posmod(i, 3)]
