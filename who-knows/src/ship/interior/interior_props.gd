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

## The wall length a prop is designed to fill.
const BAY := 2.0
## Clear height, floor to ceiling.
const HEADROOM := 1.9
## Thickness of the wall a frame sits on: the frame's origin is on its inner
## face, so the wall's mid-plane is at z = -WALL_THICKNESS / 2.
const WALL_THICKNESS := 0.1

## A porthole: floor-relative centre height, glass radius, frame radius, and
## the half-size of the square hole a wall leaves for it. The frame ring
## covers the square's corners and its bore hides the gap round the glass.
const PORTHOLE_HEIGHT := 1.28
const PORTHOLE_RADIUS := 0.26
const PORTHOLE_FRAME_RADIUS := 0.42
const PORTHOLE_OPENING := 0.27

## A doorway's clear width. Each sliding leaf is half of it, and slides into
## a jamb of (BAY - DOOR_WIDTH) / 2 = 0.5 m, so an open door hides entirely.
const DOOR_WIDTH := 1.0

## The rounded cockpit nose (spec §6), in a frame on the canopy plane at
## floor level: +x across the windshield, +y up, +z back into the room.
const NOSE_DEPTH := 1.4
## Fraction of the height that stays vertical before the nose curves back.
const NOSE_VERTICAL := 0.45
const NOSE_COLUMNS := 48
const NOSE_ROWS := 20
## Height of the lit brow line along the curve.
const NOSE_BROW := 1.8
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
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.66, 0.09)), Vector3(BAY, 0.07, 0.18), 0.03,
		_c(InteriorPalette.TRIM))
	kit.box(GLOW, f * _at(Vector3(0, 1.735, 0.01)), Vector3(BAY, 0.06, 0.02),
		_lit(InteriorPalette.LIGHT_WARM, 2.2))
	kit.box(SOLID, f * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(45.0)), Vector3(0, 1.84, 0.06)),
		Vector3(BAY, 0.17, 0.02), _c(InteriorPalette.TRIM))

## A round light on the ceiling: a chunky frame round a glowing disc, and the
## lamp that actually lights the room below it.
static func ceiling_light(kit: InteriorKit, ceiling_centre: Vector3) -> void:
	var down := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ceiling_centre)
	kit.ring(SOLID, down, 0.3, 0.42, -0.02, 0.05, _c(InteriorPalette.TRIM))
	kit.disc(GLOW, down * _at(Vector3(0, 0, 0.02)), 0.3, _lit(InteriorPalette.LIGHT_WARM, 0.9))
	kit.light(ceiling_centre + Vector3(0, -0.7, 0), InteriorPalette.LIGHT_WARM, 0.35, 3.5, &"ceiling")

## A station console: glowing plinth, bevelled body, a sloped screen, four big
## buttons (one blinks) and a framed screen on the wall above.
static func console(kit: InteriorKit, f: Transform3D, variety: float) -> void:
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
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.3, 0.03)), Vector3(1.0, 0.5, 0.06), 0.03, body)
	kit.screen(f * _at(Vector3(0, 1.3, 0.061)), Vector2(0.86, 0.36), _mode(first + 1), fposmod(variety + 0.37, 1.0))
	kit.collider(f * _at(Vector3(0, 0.55, 0.2)), Vector3(1.4, 1.1, 0.4))
	kit.light(f * Vector3(0, 1.0, 0.45), InteriorPalette.LIGHT_WARM, 0.35, 1.8, &"console")

## Six raised locker doors on a dark backing, each with a small indicator.
static func lockers(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	kit.box(SOLID, f * _at(Vector3(0, 0.92, 0.01)), Vector3(1.34, 1.46, 0.02), _c(InteriorPalette.WALL_LOW))
	var lamps: Array[Color] = [InteriorPalette.LIGHT_WARM, InteriorPalette.AMBER, InteriorPalette.SKY]
	for col in 2:
		for row in 3:
			var p := Vector3(-0.32 + col * 0.64, 0.45 + row * 0.47, 0.04)
			kit.bevel_box(SOLID, f * _at(p), Vector3(0.6, 0.42, 0.08), 0.03, _c(InteriorPalette.TRIM))
			var h := fposmod(variety * 13.0 + col * 3.7 + row * 1.3, 1.0)
			kit.disc(GLOW, f * _at(p + Vector3(0.2, -0.13, 0.041)), 0.03,
				_lit(lamps[int(h * 3.0) % 3], 1.6, h if h > 0.6 else 1.0))

## A framed wall screen above a small ledge.
static func display(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.0, 0.07)), Vector3(1.5, 0.05, 0.14), 0.02, _c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.3, 0.035)), Vector3(1.5, 0.55, 0.07), 0.03, _c(InteriorPalette.TRIM))
	kit.screen(f * _at(Vector3(0, 1.3, 0.071)), Vector2(1.36, 0.41),
		_mode(0 if variety < 0.5 else 2), variety)

## A porthole's frame and glass. The wall behind it must leave a square hole
## PORTHOLE_OPENING across at PORTHOLE_HEIGHT (InteriorBuilder does).
static func porthole(kit: InteriorKit, f: Transform3D) -> void:
	var at := f * _at(Vector3(0, PORTHOLE_HEIGHT, 0))
	kit.ring(SOLID, at, PORTHOLE_RADIUS, PORTHOLE_FRAME_RADIUS, -WALL_THICKNESS, 0.09, _c(InteriorPalette.TRIM))
	kit.annulus(GLOW, at * _at(Vector3(0, 0, 0.092)), PORTHOLE_RADIUS, PORTHOLE_RADIUS + 0.015,
		_lit(InteriorPalette.LIGHT_WARM, 1.0))
	var facing := (at.basis * Vector3.BACK).normalized()
	kit.disc(GLASS, at * _at(Vector3(0, 0, -WALL_THICKNESS * 0.5)), PORTHOLE_RADIUS, InteriorPalette.GLASS)
	# A cartoon glint: two parallel streaks across the glass.
	var glint := at * Transform3D(Basis(Vector3.BACK, deg_to_rad(45.0)), Vector3(-0.04, 0.04, -0.045))
	var white := Color(1, 1, 1, 0.35)
	kit.quad(GLASS, glint * Vector3(-0.15, -0.018, 0), glint * Vector3(0.15, -0.018, 0),
		glint * Vector3(0.15, 0.018, 0), glint * Vector3(-0.15, 0.018, 0), facing, white)
	kit.quad(GLASS, glint * Vector3(-0.08, -0.07, 0), glint * Vector3(0.08, -0.07, 0),
		glint * Vector3(0.08, -0.055, 0), glint * Vector3(-0.08, -0.055, 0), facing, white)

## The airlock's inner hatch: two bevelled leaves with a stripe, thick posts
## and header, a lit strip under the header and a blinking amber indicator --
## legible from across the cabin as the way out.
static func hatch(kit: InteriorKit, f: Transform3D) -> void:
	for side in [-1.0, 1.0]:
		kit.bevel_box(SOLID, f * _at(Vector3(side * 0.28, 0.8, 0.03)), Vector3(0.54, 1.6, 0.06), 0.025,
			_c(InteriorPalette.WALL_LOW))
		kit.bevel_box(SOLID, f * _at(Vector3(side * 0.64, 0.875, 0.06)), Vector3(0.16, 1.75, 0.12), 0.04,
			_c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.0, 0.065)), Vector3(1.08, 0.08, 0.02), 0.008, _c(InteriorPalette.BELT))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.7, 0.06)), Vector3(1.44, 0.14, 0.12), 0.04, _c(InteriorPalette.TRIM))
	kit.box(GLOW, f * _at(Vector3(0, 1.62, 0.08)), Vector3(1.1, 0.02, 0.04), _lit(InteriorPalette.LIGHT_WARM, 2.0))
	kit.disc(GLOW, f * _at(Vector3(0.85, 1.1, 0.011)), 0.04, _lit(InteriorPalette.AMBER, 1.6, 0.5))
	kit.light(f * Vector3(0, 1.5, 0.4), InteriorPalette.LIGHT_WARM, 0.5, 2.5, &"hatch")

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
	kit.light(frame * Vector3(0, 1.6, 0.6), InteriorPalette.LIGHT_WARM, 0.5, 3.0, &"cockpit")
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

## A bunk bed along the wall, two tiers with a reading strip under the top one;
## or, where the wall has a porthole above, one low bunk under it.
static func bunks(kit: InteriorKit, f: Transform3D, _variety: float, low_only: bool) -> void:
	_bed(kit, f, 0.0, 0.4)
	var top := 0.6
	if not low_only:
		for side in [-1.0, 1.0]:
			kit.bevel_box(SOLID, f * _at(Vector3(side * 0.93, 0.62, 0.86)), Vector3(0.08, 1.24, 0.08), 0.02,
				_c(InteriorPalette.WALL_LOW))
		_bed(kit, f, 1.1, 0.14)
		kit.box(GLOW, f * _at(Vector3(0, 1.095, 0.45)), Vector3(1.6, 0.01, 0.05), _lit(InteriorPalette.LIGHT_WARM, 1.2))
		top = 1.5
	kit.collider(f * _at(Vector3(0, top * 0.5, 0.45)), Vector3(1.9, top, 0.9))

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
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.8, 0.05)), Vector3(0.4, 1.55, 0.1), 0.03, _c(InteriorPalette.TRIM))
		for k in 3:
			kit.box(SOLID, f * _at(Vector3(x, 1.3 + k * 0.05, 0.101)), Vector3(0.24, 0.015, 0.01),
				_c(InteriorPalette.WALL_LOW))
		var h := fposmod(variety * 7.0 + side, 1.0)
		kit.disc(GLOW, f * _at(Vector3(x + 0.12, 0.95, 0.101)), 0.025,
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
		kit.bevel_box(SOLID, f * _at(Vector3(0, 1.42, 0.17)), Vector3(1.8, 0.4, 0.34), 0.04, trim)
		kit.box(SOLID, f * _at(Vector3(0, 1.42, 0.341)), Vector3(0.015, 0.36, 0.01), low)
	kit.collider(f * _at(Vector3(0, 0.45, 0.32)), Vector3(1.9, 0.9, 0.64))

## A tall fridge, 0.8 m wide, with a handle and a status light.
static func fridge(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var x := 0.0
	kit.bevel_box(SOLID, f * _at(Vector3(x, 0.8, 0.3)), Vector3(0.8, 1.6, 0.6), 0.05, _c(InteriorPalette.TRIM))
	kit.box(SOLID, f * _at(Vector3(x, 1.1, 0.601)), Vector3(0.76, 0.015, 0.01), _c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, f * _at(Vector3(x - 0.3, 1.3, 0.62)), Vector3(0.04, 0.35, 0.05), 0.015,
		_c(InteriorPalette.WALL_LOW))
	kit.disc(GLOW, f * _at(Vector3(x + 0.28, 1.45, 0.602)), 0.025, _lit(InteriorPalette.SKY, 1.6))
	kit.collider(f * _at(Vector3(x, 0.8, 0.3)), Vector3(0.8, 1.6, 0.6))

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
	kit.bevel_box(SOLID, f * _at(Vector3(0.45, 1.3, 0.015)), Vector3(0.5, 0.55, 0.03), 0.015, trim)
	kit.box(SOLID, f * _at(Vector3(0.45, 1.3, 0.032)), Vector3(0.42, 0.47, 0.004), _c(InteriorPalette.MIRROR))
	kit.box(GLOW, f * _at(Vector3(0.45, 1.6, 0.03)), Vector3(0.44, 0.03, 0.03), _lit(InteriorPalette.LIGHT_WARM, 2.0))
	kit.collider(f * _at(Vector3(0, 0.45, 0.3)), Vector3(1.5, 0.9, 0.6))

## A towel on a rail.
static func towel_rail(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var trim := _c(InteriorPalette.TRIM)
	for x in [-0.45, 0.45]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, 1.1, 0.035)), Vector3(0.05, 0.08, 0.07), 0.015, trim)
	kit.tube_x(SOLID, f * _at(Vector3(0, 1.1, 0.07)), 0.02, 0.95, trim)
	var towel := InteriorPalette.CORAL if variety < 0.5 else InteriorPalette.SKY
	kit.bevel_box(SOLID, f * _at(Vector3(-0.1, 0.88, 0.09)), Vector3(0.5, 0.46, 0.03), 0.012, _c(towel))

## Three shelves `width` wide, stacked with crates of seeded sizes and colours.
static func shelves(kit: InteriorKit, f: Transform3D, variety: float, width := 1.7) -> void:
	var half := width * 0.5
	for x in [-(half - 0.03), half - 0.03]:
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.8, 0.2)), Vector3(0.05, 1.6, 0.4), 0.015, _c(InteriorPalette.WALL_LOW))
	var crates: Array[Color] = [InteriorPalette.AMBER, InteriorPalette.SKY, InteriorPalette.CORAL,
		InteriorPalette.OLIVE, InteriorPalette.TRIM]
	for level in 3:
		var y := 0.25 + level * 0.47
		kit.bevel_box(SOLID, f * _at(Vector3(0, y, 0.2)), Vector3(width - 0.06, 0.04, 0.4), 0.015,
			_c(InteriorPalette.TRIM))
		var x := -half + 0.13
		var k := 0
		while true:
			var h := fposmod(variety * 31.0 + level * 7.3 + k * 3.1, 1.0)
			var w := 0.25 + 0.2 * h
			if x + w > half - 0.07:
				break
			var tall := 0.18 + 0.18 * fposmod(h * 5.7, 1.0)
			kit.bevel_box(SOLID, f * _at(Vector3(x + w * 0.5, y + 0.02 + tall * 0.5, 0.2)),
				Vector3(w - 0.03, tall, 0.3), 0.03, _c(crates[int(h * 5.0) % 5]))
			x += w + 0.04
			k += 1
	kit.collider(f * _at(Vector3(0, 0.8, 0.2)), Vector3(width, 1.6, 0.4))

## Five chunky rifles on a rack over a gunmetal cabinet, with coral warning
## stripes.
static func weapon_rack(kit: InteriorKit, f: Transform3D, _variety: float) -> void:
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.bevel_box(SOLID, f * _at(Vector3(0, 0.2, 0.175)), Vector3(1.6, 0.4, 0.35), 0.04, gun)
	kit.box(SOLID, f * _at(Vector3(0, 0.36, 0.352)), Vector3(1.6, 0.05, 0.01), _c(InteriorPalette.CORAL))
	kit.bevel_box(SOLID, f * _at(Vector3(0, 1.0, 0.025)), Vector3(1.6, 1.1, 0.05), 0.02, _c(InteriorPalette.WALL_LOW))
	kit.box(SOLID, f * _at(Vector3(0, 1.52, 0.052)), Vector3(1.6, 0.05, 0.01), _c(InteriorPalette.CORAL))
	for i in 5:
		var x := -0.6 + i * 0.3
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.6, 0.1)), Vector3(0.1, 0.22, 0.07), 0.02, _c(InteriorPalette.WOOD))
		kit.bevel_box(SOLID, f * _at(Vector3(x, 0.98, 0.1)), Vector3(0.11, 0.55, 0.08), 0.02, gun)
		kit.bevel_box(SOLID, f * _at(Vector3(x + 0.07, 0.9, 0.1)), Vector3(0.05, 0.16, 0.06), 0.012, gun)
		kit.tube_between(SOLID, f * Vector3(x, 1.25, 0.1), f * Vector3(x, 1.45, 0.1), 0.018, gun)
		kit.disc(GLOW, f * _at(Vector3(x, 1.12, 0.141)), 0.012, _lit(InteriorPalette.SKY, 1.5))
	kit.disc(GLOW, f * _at(Vector3(0.7, 0.3, 0.352)), 0.025, _lit(InteriorPalette.AMBER, 1.6, 0.5))
	kit.collider(f * _at(Vector3(0, 0.8, 0.175)), Vector3(1.6, 1.6, 0.35))

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

## A doorway's frame, drawn once for both rooms: two chunky posts through the
## wall and a lit lintel. The frame's origin is on the owning side's inner
## surface, so the posts straddle the wall's mid-plane just behind it.
static func door_frame(kit: InteriorKit, f: Transform3D) -> void:
	var mid := -WALL_THICKNESS * 0.5
	for side in [-1.0, 1.0]:
		kit.bevel_box(SOLID, f * _at(Vector3(side * (DOOR_WIDTH * 0.5 + 0.07), HEADROOM * 0.5, mid)),
			Vector3(0.14, HEADROOM, 0.24), 0.04, _c(InteriorPalette.TRIM))
	kit.box(GLOW, f * _at(Vector3(0, HEADROOM - 0.012, mid)), Vector3(DOOR_WIDTH, 0.02, 0.12),
		_lit(InteriorPalette.LIGHT_WARM, 2.0))
	kit.light(f * Vector3(0, HEADROOM - 0.3, 0.3), InteriorPalette.LIGHT_WARM, 0.5, 2.5, &"door")

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
