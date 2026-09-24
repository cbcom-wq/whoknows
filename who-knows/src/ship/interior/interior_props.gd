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
