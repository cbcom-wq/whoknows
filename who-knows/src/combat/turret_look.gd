class_name TurretLook
extends RefCounted

## A turret's look (ship weapons spec §3.1; the style guide §3): chunky
## bevelled shapes in the hull's own colours, built from a kit and a frame
## alone. Three parts, each its own kit, because two of them turn: the plinth
## on the mount face, the dome that yaws, the barrels that pitch. Every frame
## has +y out of the mount face and -z the way the barrels point at rest; the
## dome's and the barrels' frames sit at the pivot, MUZZLE_UP off the face.

const SOLID := InteriorKit.Batch.SOLID
const HULL := InteriorKit.Batch.HULL
const GLOW := InteriorKit.Batch.GLOW

## The dome's vertex colour: white, because the hull's livery paints the plate
## and multiplies by this (as HullProps does), so the dome wears the ship's own
## colours and, hurt, its damage tint.
static func _plate() -> Color:
	return HullPalette.UNHURT

static func _trim() -> Color:
	return InteriorKit.solid(HullPalette.TRIM)

static func _dark() -> Color:
	return InteriorKit.solid(HullPalette.NOZZLE_DARK)

static func _big(kind: StringName) -> bool:
	return kind == WeaponValues.HEAVY

## The ring it turns on, on the face.
static func plinth(kit: InteriorKit, f: Transform3D, kind: StringName) -> void:
	var w := 1.8 if _big(kind) else 1.4
	kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(0, 0.08, 0)), Vector3(w, 0.16, w), 0.05, _trim())
	kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(0, 0.2, 0)), Vector3(w * 0.8, 0.1, w * 0.8), 0.03, _dark())

## The armoured dome, in the yawing frame (at the pivot).
static func dome(kit: InteriorKit, f: Transform3D, kind: StringName) -> void:
	var size := Vector3(1.5, 0.8, 1.7) if _big(kind) else Vector3(1.0, 0.55, 1.1)
	kit.bevel_box(HULL, f * InteriorKit.at(Vector3(0, -0.12, 0.1)), size, size.y * 0.3, _plate())
	kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(0, -0.12 + size.y * 0.3, size.z * 0.5 + 0.05)),
		Vector3(size.x * 0.7, size.y * 0.35, 0.12), 0.03, _trim())

## The barrels, in the pitching frame: twin short ones, or one long one, each
## with a faint amber ring at its mouth.
static func barrels(kit: InteriorKit, f: Transform3D, kind: StringName) -> void:
	var length: float = WeaponValues.spec(kind)["barrel"]
	var xs: Array[float] = [-0.16, 0.16]
	if _big(kind):
		xs = [0.0]
	var r := 0.14 if _big(kind) else 0.07
	for x in xs:
		kit.tube_between(SOLID, f * Vector3(x, 0, 0), f * Vector3(x, 0, -length), r, _trim())
		kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(x, 0, -length * 0.35)), Vector3(r * 3.0, r * 3.0, length * 0.25),
			r * 0.6, _dark())
		kit.bevel_box(GLOW, f * InteriorKit.at(Vector3(x, 0, -length - 0.02)), Vector3(r * 2.2, r * 2.2, 0.04), 0.01,
			InteriorKit.lit(SpacePalette.PHASER, 0.9))
