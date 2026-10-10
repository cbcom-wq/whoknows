class_name WarpArrival
extends Node3D

## A ship arriving as if out of warp (docs/superpowers/specs/
## 2026-10-02-ship-library-design.md §6): its hull rushes in nose first along
## a line from FROM back, braking hard onto `at`, a wake streaming behind it,
## and turns to face as `at` does over the last SWING seconds; a flash as it
## stops; then it moves at `end_velocity`. The line is its own nose unless
## another is given: a ship rushing straight at you shows no wake, so a spawn
## brings it in across your view. Anything that brings a ship in uses it: a
## spawn now, NPC ships and wingmen one day.
##
## While it arrives the hull is ghosted, as a ship at warp is (the warp spec
## §5): frozen kinematic, on no collision layer or mask, so it passes through
## rocks and ships. Its layer, mask and freeze come back at the stop. The wake
## and the flash are the engine's StandardMaterial3D, unshaded and additive, in
## SpacePalette.WARP: no new shader (style guide §2.5). They are its children,
## and it is the hull's, so the floating origin carries them and a ship removed
## mid-arrival takes its arrival with it.

signal arrived

const DURATION := 1.5
const FROM := 2000.0
## Tuned at the renders: 0.6 m was under a pixel across from 400 m.
const WAKE_WIDTH := 3.0
const WAKE_SECONDS := 0.15
## Tuned at the renders: at 0.8 the wake was a hard white bar.
const WAKE_ALPHA := 0.45
## The flash grows from x to y times the hull's bounds while it fades.
const FLASH_SCALE := Vector2(1.0, 1.6)
const FLASH_TIME := 0.4
const FLASH_ALPHA := 0.5
## Seconds at the end it turns from its line to face as `at` does.
const SWING := 0.5
## Moved farther than this between two placings, the hull was shifted by the
## floating origin, which moves it by Universe.STEP at least.
const SHIFTED := 1.0

var hull: RigidBody3D
var at: Transform3D
var end_velocity := Vector3.ZERO
## The way it travels in, a unit vector; ZERO for along its nose.
var along := Vector3.ZERO
## Seconds since it began.
var elapsed := 0.0

var _layer := 0
var _mask := 0
var _freeze := false
var _freeze_mode := RigidBody3D.FREEZE_MODE_STATIC
var _placed := Vector3.ZERO
var _has_placed := false
var _stopped := false
var _bounds := AABB()
var _wake: MeshInstance3D
var _flash: MeshInstance3D

## Starts `p_hull` arriving at `p_at` along `p_along` (its nose when ZERO), to
## move at `p_end_velocity` once it has.
static func play(p_hull: RigidBody3D, p_at: Transform3D, p_end_velocity := Vector3.ZERO,
		p_along := Vector3.ZERO) -> WarpArrival:
	var a := WarpArrival.new()
	a.name = "WarpArrival"
	a.hull = p_hull
	a.at = p_at
	a.end_velocity = p_end_velocity
	a.along = p_along.normalized()
	a._bounds = bounds_of(p_hull)
	p_hull.add_child(a)
	return a

## The arrival `p_hull` is flying in now, or null. One that has stopped, its
## flash still fading, has arrived.
static func of(p_hull: Node) -> WarpArrival:
	if p_hull == null:
		return null
	for child in p_hull.get_children():
		var a := child as WarpArrival
		if a != null and not a._stopped and not a.is_queued_for_deletion():
			return a
	return null

## How far from its spot the hull is `t` seconds in: FROM × (1 − t)³ of the
## way, so it covers most of it in the first third and eases on.
static func distance_at(t: float) -> float:
	return FROM * pow(1.0 - clampf(t / DURATION, 0.0, 1.0), 3.0)

## The box round every mesh that shows under `body`, in its own frame. Not a
## hidden one: a ship's light beams reach 140 m ahead of it.
static func bounds_of(body: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var to_body := body.global_transform.affine_inverse()
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var b := (to_body * mesh.global_transform) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(WAKE_WIDTH, WAKE_WIDTH, 1.0)
	_wake = _glow(box, WAKE_ALPHA)
	var shell := SphereMesh.new()
	shell.radius = 0.5
	shell.height = 1.0
	shell.radial_segments = 16
	shell.rings = 8
	_flash = _glow(shell, FLASH_ALPHA)
	_flash.visible = false
	_ghost()
	_place()

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not _stopped:
		if elapsed < DURATION:
			_place()
		else:
			_stop()
		return
	var f := (elapsed - DURATION) / FLASH_TIME
	if f >= 1.0:
		queue_free()
		return
	_fade(_flash, FLASH_ALPHA * (1.0 - f))
	_flash.scale = _bounds.size * lerpf(FLASH_SCALE.x, FLASH_SCALE.y, f)

## Out of every collision, and moved only by this arrival.
func _ghost() -> void:
	_layer = hull.collision_layer
	_mask = hull.collision_mask
	_freeze = hull.freeze
	_freeze_mode = hull.freeze_mode
	hull.collision_layer = 0
	hull.collision_mask = 0
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	hull.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	hull.freeze = true

## The hull distance_at(elapsed) back from the spot along its line, nose first
## and turning to face as `at` does at the end, and the wake behind its stern
## along the line, as long as the way it came in the last WAKE_SECONDS.
func _place() -> void:
	_follow_shift()
	var line := _line()
	var d := distance_at(elapsed)
	var up := at.basis.y if absf(at.basis.y.dot(line)) < 0.99 else at.basis.z
	var travel := Basis.looking_at(line, up)
	var turn := clampf((elapsed - (DURATION - SWING)) / SWING, 0.0, 1.0)
	var facing := travel.slerp(at.basis.orthonormalized(), turn) if turn > 0.0 else travel
	hull.global_transform = Transform3D(facing, at.origin - line * d)
	_placed = hull.global_position
	_has_placed = true
	var length := distance_at(elapsed - WAKE_SECONDS) - d
	_wake.visible = length > 0.01
	var centre := _bounds.get_center()
	var stern := hull.global_transform * Vector3(centre.x, centre.y, _bounds.end.z)
	_wake.global_transform = Transform3D(travel * Basis.from_scale(Vector3(1.0, 1.0, maxf(length, 0.01))),
		stern - line * length * 0.5)

## The way it travels in: `along`, or its nose.
func _line() -> Vector3:
	return along if along != Vector3.ZERO else -at.basis.z.normalized()

## The floating origin moves a ghosted hull and nothing else does, so whatever
## moved it since it was last placed moved the spot too.
func _follow_shift() -> void:
	if not _has_placed:
		return
	var moved := hull.global_position - _placed
	if moved.length() > SHIFTED:
		at.origin += moved

## On the spot: everything the hull was, back, moving at end_velocity; the
## wake gone and the flash begun.
func _stop() -> void:
	_stopped = true
	_follow_shift()
	hull.global_transform = at
	hull.freeze = _freeze
	hull.freeze_mode = _freeze_mode
	hull.collision_layer = _layer
	hull.collision_mask = _mask
	hull.linear_velocity = end_velocity
	hull.angular_velocity = Vector3.ZERO
	_wake.visible = false
	_flash.visible = true
	_flash.position = _bounds.get_center()
	_flash.scale = _bounds.size * FLASH_SCALE.x
	arrived.emit()

## `mesh` under this arrival in SpacePalette.WARP at `alpha`: unshaded, added
## to what is behind it, both faces, on render layer 1, casting no shadow.
func _glow(mesh: Mesh, alpha: float) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_fade(mi, alpha)
	return mi

static func _fade(mi: MeshInstance3D, alpha: float) -> void:
	var c := SpacePalette.WARP
	c.a = alpha
	(mi.material_override as StandardMaterial3D).albedo_color = c
