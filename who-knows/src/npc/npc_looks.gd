class_name NpcLooks
extends RefCounted

## What NPCs look like (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §13.4, §14.4), built in code. The
## droid's pieces build like props, from (kit, frame, variety) and the
## palette, never the grid. Until a species has its look, a plain box stands
## in.

const SOLID := InteriorKit.Batch.SOLID
const GLOW := InteriorKit.Batch.GLOW

## The droid's measurements, metres, its origin between its wheels on the
## floor.
const DROID_WHEEL_RADIUS := 0.08
const DROID_RADIUS := 0.25
const DROID_BODY_BOTTOM := 0.08
const DROID_BODY_TOP := 0.38
const DROID_CAP := Vector3(0.34, 0.12, 0.34)
const DROID_SHOULDER := Vector3(0.21, 0.3, -0.08)
const DROID_TRIMS: Array[Color] = [InteriorPalette.BELT, InteriorPalette.CORAL, InteriorPalette.OLIVE]

## The look called `look`, its origin at the feet. `variety` in [0, 1) picks
## among small differences so no two are quite alike.
static func build(look: StringName, variety: float, inside: bool) -> Node3D:
	match look:
		&"droid":
			var droid := DroidLook.new()
			droid.build(variety)
			return droid
		_:
			return placeholder(inside)

## A box: an NPC with no look yet.
static func placeholder(inside: bool) -> Node3D:
	var root := Node3D.new()
	var box := MeshInstance3D.new()
	box.name = "Placeholder"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	box.mesh = mesh
	box.position = Vector3(0, 0.25, 0)
	box.layers = 2 if inside else 1
	root.add_child(box)
	return root

## The droid's drum and wheels, in frame `f` (its origin on the floor between
## the wheels, facing -z).
static func droid_body(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	var height := DROID_BODY_TOP - DROID_BODY_BOTTOM
	var upright := Basis(Vector3.BACK, PI * 0.5)
	var face_up := Basis(Vector3.RIGHT, -PI * 0.5)
	kit.tube_x(SOLID, f * Transform3D(upright, Vector3(0, DROID_BODY_BOTTOM + height * 0.5, 0)),
		DROID_RADIUS, height, InteriorKit.solid(InteriorPalette.DROID_BODY))
	kit.disc(SOLID, f * Transform3D(face_up, Vector3(0, DROID_BODY_TOP, 0)), DROID_RADIUS,
		InteriorKit.solid(InteriorPalette.DROID_BODY))
	kit.disc(SOLID, f * Transform3D(face_up.inverse(), Vector3(0, DROID_BODY_BOTTOM, 0)), DROID_RADIUS,
		InteriorKit.solid(InteriorPalette.WALL_LOW))
	kit.tube_x(SOLID, f * Transform3D(upright, Vector3(0, DROID_BODY_BOTTOM + height * 0.45, 0)),
		DROID_RADIUS + 0.012, 0.05, InteriorKit.solid(trim(variety)))

## One wheel, turning about its frame's x.
static func droid_wheel(kit: InteriorKit, f: Transform3D) -> void:
	kit.tube_x(SOLID, f, DROID_WHEEL_RADIUS, 0.06, InteriorKit.solid(InteriorPalette.DROID_WHEEL))
	for side in [-1.0, 1.0]:
		kit.disc(SOLID, f * Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * 0.03, 0, 0)),
			DROID_WHEEL_RADIUS, InteriorKit.solid(InteriorPalette.DROID_WHEEL))
		kit.disc(SOLID, f * Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * 0.031, 0, 0)),
			DROID_WHEEL_RADIUS * 0.45, InteriorKit.solid(InteriorPalette.GUNMETAL))

## The domed cap and its eye strip, in frame `f` (at the cap's base, facing -z).
static func droid_cap(kit: InteriorKit, f: Transform3D, variety: float) -> void:
	kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(0, DROID_CAP.y * 0.5, 0)), DROID_CAP, 0.05,
		InteriorKit.solid(InteriorPalette.TRIM))
	kit.bevel_box(SOLID, f * InteriorKit.at(Vector3(0, DROID_CAP.y + 0.02, 0)), Vector3(0.18, 0.04, 0.18), 0.015,
		InteriorKit.solid(trim(variety)))
	kit.bevel_box(GLOW, f * InteriorKit.at(Vector3(0, DROID_CAP.y * 0.55, -DROID_CAP.z * 0.5 - 0.005)),
		Vector3(0.26, 0.055, 0.02), 0.01, InteriorKit.lit(InteriorPalette.LIGHT_WARM, InteriorMaterials.GLOW_ENERGY))

## The arm, folded, in frame `f` (at the shoulder): two segments and a pad.
static func droid_arm(kit: InteriorKit, f: Transform3D) -> void:
	var elbow := Vector3(0.03, -0.1, -0.08)
	var wrist := Vector3(0.0, -0.02, -0.18)
	kit.tube_between(SOLID, f * Vector3.ZERO, f * elbow, 0.018, InteriorKit.solid(InteriorPalette.GUNMETAL))
	kit.tube_between(SOLID, f * elbow, f * wrist, 0.016, InteriorKit.solid(InteriorPalette.GUNMETAL))
	kit.bevel_box(SOLID, f * InteriorKit.at(wrist + Vector3(0, 0, -0.02)), Vector3(0.05, 0.05, 0.03), 0.01,
		InteriorKit.solid(InteriorPalette.TRIM))

static func trim(variety: float) -> Color:
	return DROID_TRIMS[clampi(int(variety * DROID_TRIMS.size()), 0, DROID_TRIMS.size() - 1)]
