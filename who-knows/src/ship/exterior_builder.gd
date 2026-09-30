class_name ExteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the flying hull: a skin generated over the
## grid (docs/superpowers/specs/2026-09-28-ship-exterior-design.md §3) --
## HullLayout decides it, HullDressing draws it as a few merged meshes -- and
## one collider per occupied cell.
##
## This never references InteriorBuilder. Both are independent readers of the
## same source of truth, which is what makes the parity test honest. The skin
## reads the interior's *layout*, which is pure data from the grid, so every
## window outside matches one inside.

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
var _layout: HullLayout
var _skin: Node3D
var _meshes: Array[Mesh] = []
var _lenses: Dictionary = {}   # StringName group -> MeshInstance3D
var _window_glow: ShaderMaterial
var _alcoves: Dictionary = {}   # Vector3i -> AirlockAlcove

func bind(grid: ShipGrid, catalog: BlockCatalog) -> void:
	_grid = grid
	_catalog = catalog

func rebuild() -> void:
	_clear()
	if _grid == null or _catalog == null:
		return
	var walkable := DeckGraph.build(_grid, _catalog).walkable_coords()
	_layout = HullLayout.plan(_grid, _catalog, InteriorLayout.plan(_grid, _catalog, walkable))
	_build_colliders()
	_build_skin()

## What the skin was made from, for the lights, the probe and tests.
func layout() -> HullLayout:
	return _layout

## The hull's plating, trim and glazing (the pod shell included; no glows),
## for the bridge computer's miniature (bridge computer spec §7.1), which
## shares them rather than copying.
func hull_meshes() -> Array[Mesh]:
	return _meshes.duplicate()

## Each light group's lens glow (spec §6.1), by group.
func lenses() -> Dictionary:
	return _lenses.duplicate()

## The windows' glow material (spec §5.1): ShipLights sets its energy.
func window_glow() -> ShaderMaterial:
	return _window_glow

## Where the lights go (spec §6.1).
func light_mounts() -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	return _layout.mounts.duplicate() if _layout != null else none

func collider_coords() -> Array:
	return _collider_coords.duplicate()

## Each airlock that can cycle is an open alcove here -- the hull's copy of
## its room (airlock spec §7.2) -- by cell.
func alcoves() -> Dictionary:
	return _alcoves.duplicate()

## Everything the hull draws, in its own frame: the cells its skin covers.
## From the grid rather than the meshes' AABBs, which only a renderer can work
## out.
func bounds() -> AABB:
	var box := AABB()
	var first := true
	if _grid == null:
		return box
	var half := Vector3.ONE * ShipGrid.CELL_SIZE * 0.5
	for coord in _grid.coords():
		if _is_alcove(coord):
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
	if is_instance_valid(_skin):
		remove_child(_skin)
		_skin.free()
	_skin = null
	_meshes.clear()
	_lenses = {}
	_window_glow = null
	_layout = null
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
		var inst := _grid.get_block(coord)
		var shape_name := HullShapes.shape_of(inst.block_id)
		if shape_name == HullShapes.CUBE or _layout.is_pod_cell(coord):
			_add_collider(body, _box_shape(), Transform3D(Basis.IDENTITY, ShipGrid.cell_center(coord)))
		else:
			# Shaped blocks (spec §3.4): their colliders are their shapes, in
			# convex pieces, so rocks and a spacewalker meet what is drawn.
			var frame := HullLayout.cell_frame(coord, inst.orientation)
			for part in HullShapes.collider_parts(shape_name):
				var convex := ConvexPolygonShape3D.new()
				convex.points = part
				_add_collider(body, convex, frame)
		_collider_coords.append(coord)

func _box_shape() -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * ShipGrid.CELL_SIZE
	return shape

func _add_collider(body: Node, shape: Shape3D, xform: Transform3D) -> void:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.transform = xform
	body.add_child(node)
	_colliders.append(node)

func _build_skin() -> void:
	_skin = Node3D.new()
	_skin.name = "Skin"
	add_child(_skin)
	var made := HullDressing.build(_layout, _skin)
	_meshes.assign(made["meshes"])
	_lenses = made["lenses"]
	_window_glow = made["window_glow"]
