class_name ItemLooks
extends RefCounted

## The item asset library (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §4.3): one static builder per look,
## drawing from InteriorKit primitives in flat InteriorPalette colour, centred
## on the origin and inside the item's `size`. Like InteriorProps it never
## sees a grid, so anything that makes items can draw them.
##
## Item-local frame: origin at the collider's centre, +y up, -z forward (a
## muzzle points along -z). Each look is designed at its starter size and
## scaled to whatever size it is given.

const SOLID := InteriorKit.Batch.SOLID
const GLOW := InteriorKit.Batch.GLOW

const LOOKS: Array[StringName] = [&"plasma_pistol", &"mug", &"canister", &"crate"]

## Turn InteriorKit's x-axis tubes to run along y, or along z.
const _ALONG_Y := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
const _ALONG_Z := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))

static func has_look(look: StringName) -> bool:
	return LOOKS.has(look)

static func build(kit: InteriorKit, look: StringName, size: Vector3, variety: float) -> void:
	match look:
		&"plasma_pistol":
			plasma_pistol(kit, size)
		&"mug":
			mug(kit, size)
		&"canister":
			canister(kit, size)
		&"crate":
			crate(kit, size, variety)
		_:
			push_error("ItemLooks: no look called %s" % look)
			kit.bevel_box(SOLID, Transform3D.IDENTITY, size, 0.01, _c(InteriorPalette.TRIM))

## A chunky pistol: gunmetal body and raked grip, a trim barrel and rail,
## terracotta stripes down the sides, a plasma glow in the muzzle and a charge
## light on the back, facing whoever holds it. Designed at 0.06 x 0.16 x 0.24.
static func plasma_pistol(kit: InteriorKit, size: Vector3) -> void:
	var k := Transform3D(Basis.from_scale(size / Vector3(0.06, 0.16, 0.24)), Vector3.ZERO)
	var gun := _c(InteriorPalette.GUNMETAL)
	var trim := _c(InteriorPalette.TRIM)
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.045, 0.01)), Vector3(0.055, 0.06, 0.2), 0.012, gun)
	kit.box(SOLID, k * _at(Vector3(0, 0.0765, 0.03)), Vector3(0.03, 0.006, 0.12), trim)
	for side in [-1.0, 1.0]:
		kit.box(SOLID, k * _at(Vector3(side * 0.0281, 0.045, 0.0)), Vector3(0.002, 0.014, 0.14),
			_c(InteriorPalette.BELT))
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0.045, -0.105)), 0.016, 0.03, trim)
	kit.disc(GLOW, k * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.045, -0.1201)), 0.011,
		_lit(InteriorPalette.PLASMA, 2.0))
	kit.bevel_box(SOLID, k * Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, -0.03, 0.07)),
		Vector3(0.045, 0.1, 0.05), 0.012, gun)
	kit.box(SOLID, k * _at(Vector3(0, -0.012, 0.02)), Vector3(0.014, 0.008, 0.06), gun)
	kit.box(SOLID, k * _at(Vector3(0, 0.0, 0.028)), Vector3(0.008, 0.024, 0.01), trim)
	kit.disc(GLOW, k * _at(Vector3(0, 0.05, 0.1101)), 0.012, _lit(InteriorPalette.PLASMA, 1.8))

## A mug of something hot: a faceted trim cup with a terracotta band and a
## handle on +x. Designed at 0.09 x 0.1 x 0.09.
static func mug(kit: InteriorKit, size: Vector3) -> void:
	var k := Transform3D(Basis.from_scale(size / Vector3(0.09, 0.1, 0.09)), Vector3.ZERO)
	var trim := _c(InteriorPalette.TRIM)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3.ZERO), 0.032, 0.1, trim)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, 0.015, 0)), 0.0335, 0.025, _c(InteriorPalette.BELT))
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.05, 0)), 0.032, trim)
	kit.disc(SOLID, k * Transform3D(up, Vector3(0, 0.045, 0)), 0.03, _c(InteriorPalette.WOOD))
	kit.annulus(SOLID, k * Transform3D(up, Vector3(0, 0.05, 0)), 0.028, 0.034, trim)
	kit.bevel_box(SOLID, k * _at(Vector3(0.039, 0, 0)), Vector3(0.012, 0.06, 0.022), 0.004, trim)

## An olive gas canister with trim caps and a terracotta band. Designed at
## 0.16 x 0.34 x 0.16.
static func canister(kit: InteriorKit, size: Vector3) -> void:
	var k := Transform3D(Basis.from_scale(size / Vector3(0.16, 0.34, 0.16)), Vector3.ZERO)
	var trim := _c(InteriorPalette.TRIM)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3.ZERO), 0.068, 0.27, _c(InteriorPalette.OLIVE))
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, 0.02, 0)), 0.0695, 0.06, _c(InteriorPalette.BELT))
	for y in [-0.1525, 0.1525]:
		kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, y, 0)), 0.074, 0.035, trim)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.17, 0)), 0.074, trim)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.17, 0)), 0.074, trim)

## A strapped crate in one of the shelf crates' colours, with a trim latch
## front and back. Any size.
static func crate(kit: InteriorKit, size: Vector3, variety: float) -> void:
	var colour: Color = InteriorPalette.CRATES[int(fposmod(variety, 1.0) * 5.0) % 5]
	kit.bevel_box(SOLID, Transform3D.IDENTITY, size - Vector3.ONE * 0.012, 0.03, _c(colour))
	for x in [-size.x * 0.27, size.x * 0.27]:
		kit.box(SOLID, _at(Vector3(x, 0, 0)), Vector3(0.04, size.y, size.z), _c(InteriorPalette.BELT))
	for z in [-1.0, 1.0]:
		kit.bevel_box(SOLID, _at(Vector3(0, size.y * 0.17, z * (size.z * 0.5 - 0.004))),
			Vector3(0.07, 0.04, 0.008), 0.003, _c(InteriorPalette.TRIM))

static func _at(offset: Vector3) -> Transform3D:
	return InteriorKit.at(offset)

static func _c(color: Color) -> Color:
	return InteriorKit.solid(color)

static func _lit(color: Color, energy: float) -> Color:
	return InteriorKit.lit(color, energy)
