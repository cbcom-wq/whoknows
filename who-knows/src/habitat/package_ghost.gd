class_name PackageGhost
extends Node3D

## Where a module would stand (habitat modules spec §5.2): its body at its
## levelled height and its legs down to the ground, flat and see-through,
## SIGNAL_GO where it fits and CORAL where it doesn't. An unshaded
## StandardMaterial3D, so no shader is added. Outside, in the shift group; its
## parent never moves.

const ALPHA := 0.35
const LEG_THICK := 0.12

var _body: MeshInstance3D
var _legs: Array[MeshInstance3D] = []
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group(Universe.EXTERIOR_SPACE)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_body = MeshInstance3D.new()
	_body.mesh = BoxMesh.new()
	_body.material_override = _material
	add_child(_body)
	for i in 4:
		var leg := MeshInstance3D.new()
		leg.mesh = BoxMesh.new()
		leg.material_override = _material
		add_child(leg)
		_legs.append(leg)
	visible = false

func show_fit(r: Planting.Result) -> void:
	if r == null or r.fit == Planting.Fit.NO_GROUND or r.fit == Planting.Fit.HUB_FIRST:
		hide_fit()
		return
	visible = true
	var colour := InteriorPalette.SIGNAL_GO if r.fit == Planting.Fit.OK else InteriorPalette.CORAL
	colour.a = ALPHA
	_material.albedo_color = colour
	global_transform = Transform3D.IDENTITY
	_body.global_transform = r.body
	(_body.mesh as BoxMesh).size = r.size
	var up := r.frame.basis.y
	for i in _legs.size():
		var leg := _legs[i]
		leg.visible = i < r.feet.size()
		if not leg.visible:
			continue
		var foot: Vector3 = r.feet[i]
		var length: float = r.legs[i]
		(leg.mesh as BoxMesh).size = Vector3(LEG_THICK, maxf(length, 0.05), LEG_THICK)
		leg.global_transform = Transform3D(r.frame.basis, foot + up * length * 0.5)

func hide_fit() -> void:
	visible = false
