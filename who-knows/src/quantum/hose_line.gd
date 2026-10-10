class_name HoseLine
extends Node3D

## The hose's line (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §11.3): a HoseRope from the reel to the nozzle's tail, drawn as chunky
## ribbed segments on the world's layer. It does not collide.
##
## The floating origin (CLAUDE.md): it lives under the home's Outside, which
## never moves, and is a member of Universe.EXTERIOR_SPACE itself. Its rope
## points are in its own frame, so a shift carries them with it; every tick
## it reads the reel's anchor and the nozzle's tail afresh and converts them.

## A segment's thickness, metres; every other one is a rib, this much thicker.
const GIRTH := 0.05
const RIB := 1.35

var reel: HoseReel
var nozzle: Item
var rope := HoseRope.new()
## True once finish() has run: queued for freeing.
var ended := false

var _instances: MultiMeshInstance3D
var _multi: MultiMesh

static var _material: StandardMaterial3D

## `p_reel` anchors it and `p_nozzle` ends it. Call once, in the tree.
func setup(p_reel: HoseReel, p_nozzle: Item) -> void:
	reel = p_reel
	nozzle = p_nozzle
	add_to_group(Universe.EXTERIOR_SPACE)
	rope.reset(to_local(reel.anchor()), to_local(tail()))
	_build()
	_pose_segments()

## The back of the nozzle, in the world: where the line joins it.
func tail() -> Vector3:
	return nozzle.global_transform * Vector3(0.0, 0.0, nozzle.definition.size.z * 0.5)

func _physics_process(delta: float) -> void:
	if ended:
		return
	if not is_instance_valid(reel) or not is_instance_valid(nozzle):
		finish()
		return
	rope.step(to_local(reel.anchor()), to_local(tail()), delta)
	_pose_segments()

## Ends the line: out of the group first (a member is never freed in it), then
## queued for freeing.
func finish() -> void:
	if ended:
		return
	ended = true
	if is_in_group(Universe.EXTERIOR_SPACE):
		remove_from_group(Universe.EXTERIOR_SPACE)
	queue_free()

func _build() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(GIRTH, GIRTH, 1.0)
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.mesh = mesh
	_multi.instance_count = HoseRope.SEGMENTS
	# Never culled while any of it shows: the line is 30 m about its node.
	_multi.custom_aabb = AABB(Vector3.ONE * -HoseRope.LENGTH * 2.0, Vector3.ONE * HoseRope.LENGTH * 4.0)
	_instances = MultiMeshInstance3D.new()
	_instances.name = "Segments"
	_instances.multimesh = _multi
	_instances.layers = Item.SPACE_LAYER
	_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instances.material_override = _hose_material()
	add_child(_instances)

static func _hose_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = HullPalette.HOSE
		_material.roughness = 1.0
	return _material

func _pose_segments() -> void:
	for i in HoseRope.SEGMENTS:
		var a := rope.points[i]
		var b := rope.points[i + 1]
		var along := b - a
		var length := along.length()
		if length < 0.0001:
			_multi.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), a))
			continue
		var forward := along / length
		var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		var girth := 1.0 if i % 2 == 0 else RIB
		var basis := Basis.looking_at(forward, up) * Basis.from_scale(Vector3(girth, girth, length))
		_multi.set_instance_transform(i, Transform3D(basis, (a + b) * 0.5))
