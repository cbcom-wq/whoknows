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

const LOOKS: Array[StringName] = [&"plasma_pistol", &"mug", &"canister", &"crate",
	&"toolbox", &"spare_helmet", &"power_cell", &"o2_tank", &"spanner", &"spare_module", &"medkit",
	&"ration_tin", &"rock_sample", &"hand_lamp", &"flare", &"datapad",
	&"rock_chunk", &"ice_chunk", &"scrap_plate", &"wire_coil", &"broken_module", &"quantum_shard"]
## Salvage (quantum energy spec §10.5): the looks that glint outside.
const GLINTS: Array[StringName] = [&"rock_chunk", &"ice_chunk", &"scrap_plate", &"wire_coil",
	&"broken_module", &"quantum_shard"]

## The glint (spec §10.4): lit this long, every GLINT_EVERY seconds.
const GLINT_FLASH := 0.15
const GLINT_EVERY := Vector2(2.0, 4.0)
## Seen fully to x metres, and gone by y.
const GLINT_FADE := Vector2(50.0, 60.0)
## Its width on screen, as if it were this many metres across 1 m away: the
## same few pixels at any distance.
const GLINT_SIZE := 0.012
## How far it stands toward the camera from the item's centre, per metre away,
## so the item it sits in never hides it from the distances it is meant to be
## seen at.
const GLINT_LIFT := 0.03
## project.godot 3d_render/layer_1 "exterior": salvage glints only outside.
const GLINT_LAYER := 1

## Turn InteriorKit's x-axis tubes to run along y, or along z.
const _ALONG_Y := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
const _ALONG_Z := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))

static var _glint_mesh: ArrayMesh
static var _glint_material: StandardMaterial3D

static func has_look(look: StringName) -> bool:
	return LOOKS.has(look)

static func has_glint(look: StringName) -> bool:
	return GLINTS.has(look)

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
		&"toolbox":
			toolbox(kit, size)
		&"spare_helmet":
			spare_helmet(kit, size)
		&"power_cell":
			power_cell(kit, size)
		&"o2_tank":
			o2_tank(kit, size)
		&"spanner":
			spanner(kit, size)
		&"spare_module":
			spare_module(kit, size)
		&"medkit":
			medkit(kit, size)
		&"ration_tin":
			ration_tin(kit, size)
		&"rock_sample":
			rock_sample(kit, size)
		&"hand_lamp":
			hand_lamp(kit, size)
		&"flare":
			flare(kit, size)
		&"datapad":
			datapad(kit, size)
		&"rock_chunk":
			rock_chunk(kit, size)
		&"ice_chunk":
			ice_chunk(kit, size)
		&"scrap_plate":
			scrap_plate(kit, size)
		&"wire_coil":
			wire_coil(kit, size)
		&"broken_module":
			broken_module(kit, size)
		&"quantum_shard":
			quantum_shard(kit, size)
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

## A coral toolbox with a gunmetal lid seam, trim latches and a carry handle.
## Designed at 0.5 x 0.26 x 0.2.
static func toolbox(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.5, 0.26, 0.2))
	var gun := _c(InteriorPalette.GUNMETAL)
	var trim := _c(InteriorPalette.TRIM)
	kit.bevel_box(SOLID, k * _at(Vector3(0, -0.03, 0)), Vector3(0.5, 0.2, 0.2), 0.02, _c(InteriorPalette.CORAL))
	kit.box(SOLID, k * _at(Vector3(0, 0.035, 0)), Vector3(0.502, 0.01, 0.202), gun)
	for x in [-0.16, 0.16]:
		kit.bevel_box(SOLID, k * _at(Vector3(x, 0.035, 0.098)), Vector3(0.04, 0.03, 0.008), 0.003, trim)
	for x in [-0.1, 0.1]:
		kit.bevel_box(SOLID, k * _at(Vector3(x, 0.095, 0)), Vector3(0.02, 0.05, 0.03), 0.005, gun)
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.12, 0)), Vector3(0.24, 0.02, 0.03), 0.006, trim)

## A spare suit helmet: a rounded trim shell, a dark visor facing +z -- out
## into the room on a shelf, back at you in your hands -- a gunmetal neck ring,
## a terracotta crown stripe and an amber lamp on top. Designed at 0.34 x 0.34
## x 0.36.
static func spare_helmet(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.34, 0.34, 0.36))
	kit.bevel_box(SOLID, k, Vector3(0.34, 0.34, 0.36), 0.09, _c(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.02, 0.172)), Vector3(0.25, 0.15, 0.02), 0.008,
		_c(InteriorPalette.SCREEN_BACK))
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, -0.155, 0)), 0.11, 0.03, _c(InteriorPalette.GUNMETAL))
	kit.box(SOLID, k * _at(Vector3(0, 0.168, -0.02)), Vector3(0.05, 0.008, 0.26), _c(InteriorPalette.BELT))
	kit.disc(GLOW, k * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.1701, 0.08)), 0.015,
		_lit(InteriorPalette.AMBER, 1.8))

## A power cell: a gunmetal block with trim caps, a terminal on top and a
## glowing charge stripe down its front. Designed at 0.1 x 0.18 x 0.1.
static func power_cell(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.1, 0.18, 0.1))
	var trim := _c(InteriorPalette.TRIM)
	kit.bevel_box(SOLID, k, Vector3(0.09, 0.14, 0.09), 0.015, _c(InteriorPalette.GUNMETAL))
	for y in [-0.075, 0.075]:
		kit.bevel_box(SOLID, k * _at(Vector3(0, y, 0)), Vector3(0.1, 0.02, 0.1), 0.008, trim)
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.09, 0)), Vector3(0.03, 0.01, 0.03), 0.003, trim)
	kit.box(GLOW, k * _at(Vector3(0, 0, 0.046)), Vector3(0.014, 0.1, 0.004), _lit(InteriorPalette.SKY, 1.8))

## An oxygen tank: a beige cylinder with a domed top, a gunmetal neck and
## valve, a trim band and a glowing gauge. Designed at 0.13 x 0.4 x 0.13.
static func o2_tank(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.13, 0.4, 0.13))
	var wall := _c(InteriorPalette.WALL)
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, -0.04, 0)), 0.058, 0.3, wall)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.19, 0)), 0.058,
		_c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.135, 0)), Vector3(0.112, 0.05, 0.112), 0.02, wall)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, 0.175, 0)), 0.02, 0.03, gun)
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.194, 0)), Vector3(0.05, 0.012, 0.05), 0.004, gun)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, 0.0, 0)), 0.0595, 0.035, _c(InteriorPalette.TRIM))
	kit.disc(GLOW, k * _at(Vector3(0, 0.07, 0.0585)), 0.012, _lit(InteriorPalette.SKY, 1.8))

## A gunmetal spanner lying flat: an open jaw at -z, a ring end at +z and a
## terracotta grip band. Designed at 0.06 x 0.025 x 0.3.
static func spanner(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.06, 0.025, 0.3))
	var gun := _c(InteriorPalette.GUNMETAL)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	var down := Basis(Vector3.RIGHT, PI * 0.5)
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0, 0.005)), Vector3(0.024, 0.012, 0.19), 0.004, gun)
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0, -0.105)), Vector3(0.058, 0.014, 0.03), 0.005, gun)
	for x in [-0.021, 0.021]:
		kit.bevel_box(SOLID, k * _at(Vector3(x, 0, -0.135)), Vector3(0.016, 0.014, 0.03), 0.004, gun)
	kit.annulus(SOLID, k * Transform3D(up, Vector3(0, 0.006, 0.12)), 0.011, 0.026, gun)
	kit.annulus(SOLID, k * Transform3D(down, Vector3(0, -0.006, 0.12)), 0.011, 0.026, gun)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, 0, 0.12)), 0.026, 0.012, gun)
	kit.box(SOLID, k * _at(Vector3(0, 0, 0.04)), Vector3(0.028, 0.014, 0.05), _c(InteriorPalette.BELT))

## A spare module: an olive circuit board with gunmetal chips, a trim edge
## connector and two lit indicator dots. Designed at 0.18 x 0.03 x 0.12.
static func spare_module(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.18, 0.03, 0.12))
	var gun := _c(InteriorPalette.GUNMETAL)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	kit.bevel_box(SOLID, k * _at(Vector3(0, -0.009, 0)), Vector3(0.18, 0.008, 0.12), 0.002, _c(InteriorPalette.OLIVE))
	kit.bevel_box(SOLID, k * _at(Vector3(-0.04, 0.0, -0.02)), Vector3(0.05, 0.01, 0.04), 0.003, gun)
	kit.bevel_box(SOLID, k * _at(Vector3(0.05, 0.0, 0.02)), Vector3(0.03, 0.01, 0.03), 0.003, gun)
	kit.bevel_box(SOLID, k * _at(Vector3(0.01, -0.001, 0.03)), Vector3(0.02, 0.008, 0.05), 0.002, gun)
	kit.box(SOLID, k * _at(Vector3(0, -0.009, 0.055)), Vector3(0.12, 0.004, 0.012), _c(InteriorPalette.TRIM))
	kit.disc(GLOW, k * Transform3D(up, Vector3(-0.07, -0.0045, -0.045)), 0.006, _lit(InteriorPalette.AMBER, 1.8))
	kit.disc(GLOW, k * Transform3D(up, Vector3(0.07, -0.0045, -0.04)), 0.006, _lit(InteriorPalette.SKY, 1.8))

## A medkit: a trim case with a coral band and lid -- not a cross; that emblem
## is protected -- a gunmetal handle on top and a lit indicator. Designed at 0.3
## x 0.22 x 0.12.
static func medkit(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.3, 0.22, 0.12))
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.bevel_box(SOLID, k * _at(Vector3(0, -0.025, 0)), Vector3(0.3, 0.17, 0.12), 0.025, _c(InteriorPalette.TRIM))
	kit.box(SOLID, k * _at(Vector3(0, -0.025, 0)), Vector3(0.302, 0.035, 0.122), _c(InteriorPalette.CORAL))
	kit.box(SOLID, k * _at(Vector3(0, 0.03, 0)), Vector3(0.302, 0.006, 0.122), gun)
	# A coral lid, so a medkit reads as one from above too, and in the hand
	# either side of the fist.
	kit.box(SOLID, k * _at(Vector3(0, 0.061, 0)), Vector3(0.25, 0.004, 0.09), _c(InteriorPalette.CORAL))
	for x in [-0.06, 0.06]:
		kit.bevel_box(SOLID, k * _at(Vector3(x, 0.075, 0)), Vector3(0.02, 0.03, 0.024), 0.005, gun)
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.099, 0)), Vector3(0.14, 0.018, 0.024), 0.005, gun)
	kit.disc(GLOW, k * _at(Vector3(0.1, 0.035, 0.0605)), 0.01, _lit(InteriorPalette.SKY, 1.6))

## A ration tin: a trim can with a terracotta label and gunmetal rims and lid.
## Designed at 0.08 x 0.1 x 0.08.
static func ration_tin(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.08, 0.1, 0.08))
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3.ZERO), 0.036, 0.09, _c(InteriorPalette.TRIM))
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3.ZERO), 0.0365, 0.05, _c(InteriorPalette.BELT))
	for y in [-0.046, 0.046]:
		kit.tube_x(SOLID, k * Transform3D(_ALONG_Y, Vector3(0, y, 0)), 0.038, 0.008, gun)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.05, 0)), 0.036, gun)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.05, 0)), 0.036, gun)

## A rock sample from the debris outside: three chunky grey lumps, and a
## cluster of short, faintly glowing lavender crystals nobody has identified
## yet. Designed at 0.16 x 0.12 x 0.14.
static func rock_sample(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.16, 0.12, 0.14))
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(0.15, 0.4, 0.1)), Vector3(0, -0.01, 0)),
		Vector3(0.1, 0.07, 0.085), 0.02, gun)
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(0.5, -0.3, 0.4)), Vector3(0.03, 0.015, -0.01)),
		Vector3(0.065, 0.045, 0.055), 0.015, _c(InteriorPalette.WALL_LOW))
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(-0.3, 0.8, 0.2)), Vector3(-0.035, 0.0, 0.025)),
		Vector3(0.05, 0.04, 0.05), 0.012, gun)
	var crystal := _lit(InteriorPalette.LAVENDER, 2.0)
	for c in [[Vector3(-0.012, 0.02, 0.012), Vector3(0.5, 0.2, 0.6)], [Vector3(0.004, 0.024, 0.02), Vector3(-0.3, 0.9, -0.5)],
			[Vector3(-0.022, 0.016, 0.028), Vector3(0.2, -0.6, 1.1)], [Vector3(0.012, 0.018, 0.03), Vector3(0.9, 0.3, -0.2)]]:
		kit.bevel_box(GLOW, k * Transform3D(Basis.from_euler(c[1]), c[0]), Vector3(0.018, 0.024, 0.018), 0.005, crystal)

## A hand lamp pointing along -z: a gunmetal body, a trim head with a dark lens
## (HandLamp lights it), a terracotta grip band and a coral switch. Designed at
## 0.06 x 0.07 x 0.22.
static func hand_lamp(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.06, 0.07, 0.22))
	var gun := _c(InteriorPalette.GUNMETAL)
	var trim := _c(InteriorPalette.TRIM)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0, 0.03)), 0.022, 0.15, gun)
	kit.disc(SOLID, k * _at(Vector3(0, 0, 0.105)), 0.022, gun)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0, -0.085)), 0.03, 0.05, trim)
	kit.annulus(SOLID, k * _at(Vector3(0, 0, -0.06)), 0.022, 0.03, trim)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.1101)), 0.026,
		_c(InteriorPalette.SCREEN_BACK))
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0, 0.05)), 0.0235, 0.04, _c(InteriorPalette.BELT))
	kit.bevel_box(SOLID, k * _at(Vector3(0, 0.026, 0.0)), Vector3(0.012, 0.01, 0.022), 0.003, _c(InteriorPalette.CORAL))

## An emergency flare pointing along -z: a coral tube, a trim striker cap and
## band, and a dark tip that Flare lights. Designed at 0.04 x 0.04 x 0.26.
static func flare(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.04, 0.04, 0.26))
	var trim := _c(InteriorPalette.TRIM)
	var gun := _c(InteriorPalette.GUNMETAL)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0, 0.01)), 0.017, 0.2, _c(InteriorPalette.CORAL))
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0, 0.12)), 0.019, 0.02, trim)
	kit.disc(SOLID, k * _at(Vector3(0, 0, 0.13)), 0.019, trim)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0, -0.105)), 0.012, 0.03, gun)
	kit.disc(SOLID, k * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.12)), 0.012, gun)
	kit.tube_x(SOLID, k * Transform3D(_ALONG_Z, Vector3(0, 0, 0.04)), 0.0175, 0.02, trim)

## A datapad lying face up: a gunmetal slab, a dark screen inset (Datapad
## turns it on), a trim home button and an amber power dot. Designed at 0.18 x
## 0.02 x 0.26.
static func datapad(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.18, 0.02, 0.26))
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	kit.bevel_box(SOLID, k, Vector3(0.18, 0.016, 0.26), 0.006, _c(InteriorPalette.GUNMETAL))
	kit.box(SOLID, k * _at(Vector3(0, 0.009, -0.01)), Vector3(0.14, 0.002, 0.2), _c(InteriorPalette.SCREEN_BACK))
	kit.disc(SOLID, k * Transform3D(up, Vector3(0, 0.0081, 0.11)), 0.009, _c(InteriorPalette.TRIM))
	kit.disc(GLOW, k * Transform3D(up, Vector3(0.07, 0.0082, 0.115)), 0.004, _lit(InteriorPalette.AMBER, 1.8))

## A lump of rock broken off something bigger: three heavily bevelled blocks
## run together into one faceted lump, all taupe. Designed at 0.2 x 0.16 x
## 0.18.
static func rock_chunk(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.2, 0.16, 0.18))
	var rock := _c(InteriorPalette.WALL_LOW)
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(0.3, 0.5, 0.2)), Vector3(-0.004, -0.004, 0)),
		Vector3(0.16, 0.12, 0.14), 0.035, rock)
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(-0.4, -0.3, 0.6)), Vector3(0.035, 0.022, -0.022)),
		Vector3(0.11, 0.08, 0.1), 0.028, rock)
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(0.7, 0.9, -0.3)), Vector3(-0.045, 0.016, 0.032)),
		Vector3(0.08, 0.07, 0.08), 0.022, rock)

## A chunk of ice: a pale lump, more sharply faceted than rock, with a spur of
## crystal growing out of it. Designed at 0.2 x 0.18 x 0.2.
static func ice_chunk(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.2, 0.18, 0.2))
	var ice := _c(InteriorPalette.ICE)
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(0.6, 0.2, -0.4)), Vector3(0, -0.001, 0)),
		Vector3(0.14, 0.12, 0.14), 0.02, ice)
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(0.3, 0.1, 0.5)), Vector3(0.03, 0.023, 0.02)),
		Vector3(0.05, 0.12, 0.05), 0.012, ice)
	kit.bevel_box(SOLID, k * Transform3D(Basis.from_euler(Vector3(-0.5, 0.8, 0.3)), Vector3(-0.04, -0.009, -0.03)),
		Vector3(0.09, 0.08, 0.09), 0.02, ice)

## A piece of torn-off plating: a cream plate with its end bent up, and the
## ship's terracotta stripe along it, torn off raggedly short of the bend.
## Designed at 0.5 x 0.04 x 0.35.
static func scrap_plate(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.5, 0.04, 0.35))
	var trim := _c(InteriorPalette.TRIM)
	kit.bevel_box(SOLID, k * _at(Vector3(-0.085, -0.014, 0)), Vector3(0.33, 0.012, 0.35), 0.004, trim)
	var flap := 0.17
	var hinge := Transform3D(Basis(Vector3.BACK, deg_to_rad(9.0)), Vector3(0.08, -0.014, 0))
	kit.bevel_box(SOLID, k * hinge * _at(Vector3(flap * 0.5, 0, 0)), Vector3(flap, 0.012, 0.35), 0.004, trim)
	# Three strands of the stripe, each torn off at a different place.
	for strand in [[0.07, 0.02], [0.09, -0.04], [0.11, 0.05]]:
		var from := -0.245
		var to: float = strand[1]
		kit.box(SOLID, k * _at(Vector3((from + to) * 0.5, -0.007, strand[0])), Vector3(to - from, 0.002, 0.02),
			_c(InteriorPalette.BELT))

## A coil of wire: a chunky copper torus lying flat, held by two gunmetal
## ties. Designed at 0.2 x 0.08 x 0.2.
static func wire_coil(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.2, 0.08, 0.2))
	var ring := 0.063
	var wire := 0.035
	_torus(kit, k, ring, wire, 12, 6, _c(InteriorPalette.COPPER))
	for turn in [0.4, 0.4 + PI]:
		var out := Vector3(cos(turn), 0, sin(turn))
		kit.bevel_box(SOLID, k * Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP)), out * ring),
			Vector3(wire * 2.2, wire * 2.15, 0.02), 0.008, _c(InteriorPalette.GUNMETAL))

## The spare module's board, broken: snapped across the middle, both halves
## sagging from the crack and one twisted out of line, half its edge connector
## gone and both indicators dead. The spare module's own pieces at 1.3 times
## its scale. Designed at 0.25 x 0.06 x 0.18.
static func broken_module(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.25, 0.06, 0.18)) \
		* Transform3D(Basis.from_scale(Vector3.ONE * 1.3), Vector3(0, 0.006, 0))
	var gun := _c(InteriorPalette.GUNMETAL)
	var olive := _c(InteriorPalette.OLIVE)
	var dead := _c(InteriorPalette.SCREEN_BACK)
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	var sag := deg_to_rad(8.0)
	# Each half hangs from the bottom of the crack.
	var crack := Vector3(0.005, -0.013, 0)
	var left := k * Transform3D(Basis(Vector3.BACK, sag), crack)
	var right := k * Transform3D(Basis(Vector3.UP, deg_to_rad(6.0)) * Basis(Vector3.BACK, -sag), crack)
	kit.bevel_box(SOLID, left * _at(Vector3(-0.0475, 0.004, 0)), Vector3(0.095, 0.008, 0.12), 0.002, olive)
	kit.bevel_box(SOLID, left * _at(Vector3(-0.045, 0.013, -0.02)), Vector3(0.05, 0.01, 0.04), 0.003, gun)
	kit.box(SOLID, left * _at(Vector3(-0.0425, 0.004, 0.055)), Vector3(0.075, 0.004, 0.012), _c(InteriorPalette.TRIM))
	kit.disc(SOLID, left * Transform3D(up, Vector3(-0.075, 0.0085, -0.045)), 0.006, dead)
	kit.bevel_box(SOLID, right * _at(Vector3(0.0425, 0.004, 0)), Vector3(0.085, 0.008, 0.12), 0.002, olive)
	kit.bevel_box(SOLID, right * _at(Vector3(0.045, 0.013, 0.02)), Vector3(0.03, 0.01, 0.03), 0.003, gun)
	kit.bevel_box(SOLID, right * _at(Vector3(0.012, 0.012, 0.03)), Vector3(0.02, 0.008, 0.05), 0.002, gun)
	kit.disc(SOLID, right * Transform3D(up, Vector3(0.065, 0.0085, -0.04)), 0.006, dead)

## A quantum shard: one six-sided crystal, pointed at both ends, all glow in
## the colour of QE, its facets lit by turns brighter and softer so its shape
## reads. Designed at 0.08 x 0.2 x 0.08.
static func quantum_shard(kit: InteriorKit, size: Vector3) -> void:
	var k := _scale(size, Vector3(0.08, 0.2, 0.08))
	var bright := _lit(InteriorPalette.QUANTUM, 2.2)
	var soft := _lit(InteriorPalette.QUANTUM, 1.4)
	var top := Vector3(0.004, 0.1, 0)
	var bottom := Vector3(-0.003, -0.1, 0.002)
	var high: Array[Vector3] = []
	var low: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.037
		high.append(d + Vector3(0, 0.05, 0))
		low.append(d + Vector3(0, -0.055, 0))
	for i in 6:
		var j := (i + 1) % 6
		var side := bright if i % 2 == 0 else soft
		var end := soft if i % 2 == 0 else bright
		_facet(kit, k, [low[i], low[j], high[j], high[i]], side)
		_facet(kit, k, [high[i], high[j], top], end)
		_facet(kit, k, [low[j], low[i], bottom], end)

## One flat, glowing facet of a solid round the origin, a triangle or a quad,
## facing away from it.
static func _facet(kit: InteriorKit, k: Transform3D, points: Array, colour: Color) -> void:
	var p: Array[Vector3] = []
	for q: Vector3 in points:
		p.append(k * q)
	var n := (p[1] - p[0]).cross(p[2] - p[0]).normalized()
	if n.dot(p[0] - k.origin) < 0.0:
		n = -n
	if p.size() == 4:
		kit.quad(GLOW, p[0], p[1], p[2], p[3], n, colour)
	else:
		kit.tri(GLOW, p[0], p[1], p[2], n, colour)

## A faceted torus lying flat in `k`'s xz plane: `ring` from the centre to the
## middle of the tube, `tube` the tube's radius, in `sides` straight pieces of
## `facets` faces each.
static func _torus(kit: InteriorKit, k: Transform3D, ring: float, tube: float, sides: int, facets: int,
		colour: Color) -> void:
	for i in sides:
		var a := [TAU * i / sides, TAU * (i + 1) / sides]
		var mid_out := Vector3(cos((a[0] + a[1]) * 0.5), 0, sin((a[0] + a[1]) * 0.5))
		for j in facets:
			var b := [TAU * j / facets, TAU * (j + 1) / facets]
			var p: Array[Vector3] = []
			for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var out := Vector3(cos(a[c[0]]), 0, sin(a[c[0]]))
				p.append(k * (out * (ring + tube * cos(b[c[1]])) + Vector3.UP * tube * sin(b[c[1]])))
			var mid: float = (b[0] + b[1]) * 0.5
			var n := (k.basis * (mid_out * cos(mid) + Vector3.UP * sin(mid))).normalized()
			kit.quad(SOLID, p[0], p[1], p[2], p[3], n, colour)

## A salvage item's glint (spec §10.4), a child of its look: a warm diamond
## flashing for GLINT_FLASH every 2-4 s, as if the item caught the sun. An
## unshaded billboard quad in LIGHT_WARM on the world's layer, a few pixels
## across at any distance, faded out by its visibility range between 50 and
## 60 m. `variety` (0..1) seeds how often it flashes and where in that it
## starts, so a cloud's items flash apart.
static func glint(parent: Node3D, variety: float) -> Glint:
	var g := Glint.new()
	g.name = "Glint"
	g.mesh = _glint_quad()
	g.material_override = _glint_look()
	g.layers = GLINT_LAYER
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Godot fades a range's end out from (end - margin) to (end + margin).
	g.visibility_range_end = (GLINT_FADE.x + GLINT_FADE.y) * 0.5
	g.visibility_range_end_margin = (GLINT_FADE.y - GLINT_FADE.x) * 0.5
	g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Drawn bigger and nearer than the quad's own bounds say: never culled
	# while it still shows.
	g.extra_cull_margin = GLINT_FADE.y * (GLINT_LIFT + GLINT_SIZE)
	g.period = lerpf(GLINT_EVERY.x, GLINT_EVERY.y, fposmod(variety * 7.919, 1.0))
	g.advance(fposmod(variety * 3.301, 1.0) * g.period)
	parent.add_child(g)
	return g

## Lit for GLINT_FLASH at the start of every `period` seconds.
class Glint extends MeshInstance3D:
	var period := 3.0
	var _t := 0.0

	func _process(delta: float) -> void:
		advance(delta)

	func advance(delta: float) -> void:
		_t = fposmod(_t + delta, period)
		visible = _t < GLINT_FLASH

## One diamond, GLINT_LIFT toward the viewer, shared by every glint.
static func _glint_quad() -> ArrayMesh:
	if _glint_mesh == null:
		var h := GLINT_SIZE * 0.5
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, h, GLINT_LIFT), Vector3(h, 0, GLINT_LIFT),
			Vector3(0, -h, GLINT_LIFT), Vector3(-h, 0, GLINT_LIFT)])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		_glint_mesh = ArrayMesh.new()
		_glint_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _glint_mesh

## Built in and unshaded, facing the camera and the same size on screen at
## any distance: no new shader (style guide §2.5).
static func _glint_look() -> StandardMaterial3D:
	if _glint_material == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = InteriorPalette.LIGHT_WARM
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.fixed_size = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		_glint_material = m
	return _glint_material

## Scales a look designed at `designed` to `size`.
static func _scale(size: Vector3, designed: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size / designed), Vector3.ZERO)

static func _at(offset: Vector3) -> Transform3D:
	return InteriorKit.at(offset)

static func _c(color: Color) -> Color:
	return InteriorKit.solid(color)

static func _lit(color: Color, energy: float) -> Color:
	return InteriorKit.lit(color, energy)
