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
## Where each cell's block is drawn: coord -> [block id, instance index,
## colour], so a stage change recolours one instance (health and damage spec
## §9). The colour is kept here too: a headless renderer keeps none.
var _instances: Dictionary = {}
## Each block mesh with its materials taking the instance colour, by mesh.
static var _tintable: Dictionary = {}
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

## Recolours the block at `coord` for `stage`, a BlockDamage.Stage: no
## rebuild, one instance's colour (health and damage spec §4.3, §9).
func set_stage(coord: Vector3i, stage: int) -> void:
	if not _instances.has(coord):
		return
	var at: Array = _instances[coord]
	at[2] = stage_colour(stage)
	var mmi: MultiMeshInstance3D = _multimeshes.get(at[0])
	if is_instance_valid(mmi):
		mmi.multimesh.set_instance_color(at[1], at[2])

## What a block's colours are multiplied by at `stage`.
static func stage_colour(stage: int) -> Color:
	match stage:
		BlockDamage.Stage.DAMAGED:
			return HullPalette.SCORCH
		BlockDamage.Stage.WRECKED, BlockDamage.Stage.GONE:
			return HullPalette.CHAR
	return HullPalette.UNHURT

## The colour one instance is drawn with now, for tests.
func instance_colour(coord: Vector3i) -> Color:
	if not _instances.has(coord):
		return HullPalette.UNHURT
	return _instances[coord][2]

## `mesh` with every StandardMaterial3D surface taking the instance colour as
## a multiplier on its albedo. Built once per mesh. Shader surfaces (the hull
## livery) are left as they are: they tint only if their shader reads COLOR.
static func tintable(mesh: Mesh) -> Mesh:
	if _tintable.has(mesh):
		return _tintable[mesh]
	var out: Mesh = mesh.duplicate()
	if out is PrimitiveMesh:
		var pm := out as PrimitiveMesh
		pm.material = _tinted(pm.material)
	else:
		for i in out.get_surface_count():
			var m := out.surface_get_material(i)
			if m == null or m is StandardMaterial3D:
				out.surface_set_material(i, _tinted(m))
	_tintable[mesh] = out
	return out

static func _tinted(m: Material) -> Material:
	if m != null and not (m is StandardMaterial3D):
		return m
	var t: StandardMaterial3D = (m as StandardMaterial3D).duplicate() if m != null else StandardMaterial3D.new()
	t.vertex_color_use_as_albedo = true
	return t

## Each airlock that can cycle is an open alcove here -- the hull's copy of
## its room (airlock spec §7.2) -- by cell.
func alcoves() -> Dictionary:
	return _alcoves.duplicate()

## The hull's per-type MultiMeshes, for the bridge computer's miniature
## (bridge computer spec §7.1), which shares them rather than copying.
func multimeshes() -> Array[MultiMesh]:
	var out: Array[MultiMesh] = []
	for mmi: MultiMeshInstance3D in _multimeshes.values():
		if is_instance_valid(mmi):
			out.append(mmi.multimesh)
	return out

## Everything the hull draws, in its own frame: the cells its meshes fill.
## From the grid rather than the MultiMeshes' AABBs, which only a renderer
## can work out.
func bounds() -> AABB:
	var box := AABB()
	var first := true
	if _grid == null or _catalog == null:
		return box
	var half := Vector3.ONE * ShipGrid.CELL_SIZE * 0.5
	for coord in _grid.coords():
		var def := _catalog.get_def(_grid.get_block(coord).block_id)
		if def == null or def.mesh == null or _is_alcove(coord):
			continue
		var cell := AABB(ShipGrid.cell_center(coord) - half, half * 2.0)
		box = cell if first else box.merge(cell)
		first = false
	return box

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
	_instances.clear()
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
			for collider in _alcoves[coord].colliders:
				collider.set_meta(&"cell", coord)
			_collider_coords.append(coord)
			continue
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE * ShipGrid.CELL_SIZE
		var node := CollisionShape3D.new()
		node.shape = shape
		node.position = ShipGrid.cell_center(coord)
		# Which block a hit on this shape damages (health and damage spec §5.1).
		node.set_meta(&"cell", coord)
		body.add_child(node)
		_colliders.append(node)
		_collider_coords.append(coord)

func _build_meshes() -> void:
	# Group cells by block type so each type draws in one instanced call.
	var by_type: Dictionary = {}   # StringName -> Array[Transform3D]
	var colours: Dictionary = {}   # StringName -> Array[Color]
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
			colours[inst.block_id] = []
		var colour := stage_colour(BlockDamage.stage_of(inst, def))
		_instances[coord] = [inst.block_id, by_type[inst.block_id].size(), colour]
		by_type[inst.block_id].append(xform)
		colours[inst.block_id].append(colour)

	for block_id in by_type.keys():
		var transforms: Array = by_type[block_id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = tintable(_catalog.get_def(block_id).mesh)
		mm.instance_count = transforms.size()
		for index in transforms.size():
			mm.set_instance_transform(index, transforms[index])
			mm.set_instance_color(index, colours[block_id][index])

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.layers = OWN_HULL_LAYER
		add_child(mmi)
		_multimeshes[block_id] = mmi
