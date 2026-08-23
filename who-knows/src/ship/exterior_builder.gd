class_name ExteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the flying hull: one MultiMesh per block
## type for rendering, one box collider per occupied cell for physics.
##
## This never references InteriorBuilder. Both are independent readers of
## the same source of truth, which is what makes the parity test honest.

@export var body_path: NodePath

var _grid: ShipGrid
var _catalog: BlockCatalog
var _collider_coords: Array[Vector3i] = []
var _colliders: Array[CollisionShape3D] = []
var _multimeshes: Dictionary = {}   # StringName -> MultiMeshInstance3D

func bind(grid: ShipGrid, catalog: BlockCatalog) -> void:
	_grid = grid
	_catalog = catalog

func rebuild() -> void:
	_clear()
	if _grid == null or _catalog == null:
		return
	_build_colliders()
	_build_meshes()

func collider_coords() -> Array:
	return _collider_coords.duplicate()

func _clear() -> void:
	# queue_free() alone both detaches and deletes a node, atomically at
	# the same deferred point. Detaching immediately with remove_child()
	# first (as one might expect to mirror "removed synchronously") instead
	# leaves the node parentless-but-not-yet-freed for the rest of the
	# current frame, which is exactly what Godot's orphan-node tracking
	# flags — confirmed empirically: three synchronous rebuild() calls
	# produced real GUT "Orphans" warnings until this was reverted to
	# queue_free()-only. Mesh instances never had this problem because
	# they were already queue_free()-only.
	for collider in _colliders:
		if is_instance_valid(collider):
			collider.queue_free()
	_colliders.clear()
	_collider_coords.clear()
	for mmi in _multimeshes.values():
		if is_instance_valid(mmi):
			mmi.queue_free()
	_multimeshes.clear()

func _body() -> Node:
	return get_node(body_path) if not body_path.is_empty() else get_parent()

func _build_colliders() -> void:
	var body := _body()
	for coord in _grid.coords():
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE * ShipGrid.CELL_SIZE
		var node := CollisionShape3D.new()
		node.shape = shape
		node.position = ShipGrid.cell_center(coord)
		body.add_child(node)
		_colliders.append(node)
		_collider_coords.append(coord)

func _build_meshes() -> void:
	# Group cells by block type so each type draws in one instanced call.
	var by_type: Dictionary = {}   # StringName -> Array[Transform3D]
	for coord in _grid.coords():
		var inst := _grid.get_block(coord)
		var def := _catalog.get_def(inst.block_id)
		if def == null or def.mesh == null:
			continue
		var xform := Transform3D(
			BlockOrientation.basis_for(inst.orientation), ShipGrid.cell_center(coord)
		)
		if not by_type.has(inst.block_id):
			by_type[inst.block_id] = []
		by_type[inst.block_id].append(xform)

	for block_id in by_type.keys():
		var transforms: Array = by_type[block_id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _catalog.get_def(block_id).mesh
		mm.instance_count = transforms.size()
		for index in transforms.size():
			mm.set_instance_transform(index, transforms[index])

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		_multimeshes[block_id] = mmi
