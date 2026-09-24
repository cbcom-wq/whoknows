class_name ExteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the flying hull: one MultiMesh per block
## type for rendering, one box collider per occupied cell for physics.
##
## This never references InteriorBuilder. Both are independent readers of
## the same source of truth, which is what makes the parity test honest.

## Render layer for the ship's own hull -- layer 3, "own_hull". The canopy
## camera sits at the pilot's eye, inside the hull, and excludes this layer;
## without it the windshield would render the inside of the ship's own
## blocks instead of the space beyond them.
const OWN_HULL_LAYER := 4

@export var body_path: NodePath

var _grid: ShipGrid
var _catalog: BlockCatalog
var _collider_coords: Array[Vector3i] = []
var _colliders: Array[CollisionShape3D] = []
var _multimeshes: Dictionary = {}   # StringName -> MultiMeshInstance3D
var _alcoves: Dictionary = {}   # Vector3i -> AirlockAlcove

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

## Each airlock that can cycle is an open alcove here -- the hull's copy of
## its room (airlock spec §7.2) -- by cell.
func alcoves() -> Dictionary:
	return _alcoves.duplicate()

func _clear() -> void:
	# remove_child() then free() -- not queue_free(). remove_child() is
	# synchronous and fires NOTIFICATION_UNPARENTED immediately, which is
	# what actually deregisters a CollisionShape3D from its body's physics
	# representation. queue_free() alone does not do that: the node stays
	# parented (and, for a CollisionShape3D, physics-registered) until the
	# delete queue is flushed, which never happens between two synchronous
	# rebuild() calls. That previously left a stale, still-registered
	# collider coincident with the freshly built one for the lifetime of a
	# rebuild burst (e.g. several cell_changed signals firing in the same
	# frame from the shipyard editor) -- a real double-collision bug, not
	# just stray bookkeeping. free() (rather than queue_free()) then deletes
	# the node immediately instead of leaving it parentless-but-alive for
	# the rest of the frame. Safe here: these are plain, unconnected nodes,
	# never mid-signal on the call stack when _clear() runs.
	var body := _body()
	for collider in _colliders:
		if is_instance_valid(collider):
			body.remove_child(collider)
			collider.free()
	_colliders.clear()
	_collider_coords.clear()
	for mmi in _multimeshes.values():
		if is_instance_valid(mmi):
			remove_child(mmi)
			mmi.free()
	_multimeshes.clear()
	for alcove: AirlockAlcove in _alcoves.values():
		if not is_instance_valid(alcove):
			continue
		for collider in alcove.colliders:
			if is_instance_valid(collider):
				collider.get_parent().remove_child(collider)
				collider.free()
		remove_child(alcove)
		alcove.free()
	_alcoves.clear()

func _is_alcove(coord: Vector3i) -> bool:
	return AirlockSite.hatch_normal(_grid, coord) != Vector3i.ZERO

func _body() -> Node:
	return get_node(body_path) if not body_path.is_empty() else get_parent()

func _build_colliders() -> void:
	var body := _body()
	for coord in _grid.coords():
		if _is_alcove(coord):
			# Hollow, not gone: the alcove's floor, walls and hatches are this
			# cell's collision now.
			_alcoves[coord] = AirlockAlcove.build(self, body, _grid, _catalog, coord)
			_collider_coords.append(coord)
			continue
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
		if def == null or def.mesh == null or _is_alcove(coord):
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
		mmi.layers = OWN_HULL_LAYER
		add_child(mmi)
		_multimeshes[block_id] = mmi
