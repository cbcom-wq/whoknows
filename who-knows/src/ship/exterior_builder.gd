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
## Each cell's damage tint (health and damage spec §9): coord -> the colour
## its skin is multiplied by, from its stage.
var _colours: Dictionary = {}
## Which vertices each cell's skin pieces are (HullDressing.build's `spans`):
## coord -> [[ArrayMesh, first vertex, end vertex], ...].
var _spans: Dictionary = {}
## Each skin mesh a tint can touch: ArrayMesh -> [its surface arrays, its
## colours as dressed], kept from the dressing (a read-back stalls on the
## GPU), so a stage recolours one cell's vertices and uploads the arrays
## again without dressing anything.
var _surfaces: Dictionary = {}
## Skin meshes recoloured since the last upload: ArrayMesh -> true. They go up
## once at the end of the frame, however many stages changed in it.
var _stale: Dictionary = {}
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

## The block at `coord` is at `stage` now, a BlockDamage.Stage (health and
## damage spec §4.3, §9): its skin pieces take the stage's colour in place,
## drawn from the end of this frame. Nothing is dressed or rebuilt; colliders
## and alcoves are left alone.
func set_stage(coord: Vector3i, stage: int) -> void:
	if not _colours.has(coord):
		return
	var colour := stage_colour(stage)
	if _colours[coord] == colour:
		return
	_colours[coord] = colour
	var waiting := not _stale.is_empty()
	_stale.merge(_tint(coord, colour))
	if not waiting and not _stale.is_empty():
		_upload_stale.call_deferred()

## What a block's colours are multiplied by at `stage`.
static func stage_colour(stage: int) -> Color:
	match stage:
		BlockDamage.Stage.DAMAGED:
			return HullPalette.SCORCH
		BlockDamage.Stage.WRECKED, BlockDamage.Stage.GONE:
			return HullPalette.CHAR
	return HullPalette.UNHURT

## The colour the cell at `coord` is drawn with now, for tests.
func instance_colour(coord: Vector3i) -> Color:
	return _colours.get(coord, HullPalette.UNHURT)

## Which vertices the cell at `coord` is in the skin: [[ArrayMesh, first
## vertex, end vertex], ...], for tests and the probe.
func skin_spans(coord: Vector3i) -> Array:
	return _spans.get(coord, []).duplicate()

## Multiplies the colours `coord`'s pieces were dressed with by `colour`, in
## the cached arrays. Returns the meshes it changed, to upload.
func _tint(coord: Vector3i, colour: Color) -> Dictionary:
	var changed := {}
	for span: Array in _spans.get(coord, []):
		var mesh: ArrayMesh = span[0]
		var surface: Array = _surfaces[mesh]
		var dressed: PackedColorArray = surface[1]
		var colours: PackedColorArray = surface[0][Mesh.ARRAY_COLOR]
		for i in range(span[1], span[2]):
			colours[i] = dressed[i] * colour
		surface[0][Mesh.ARRAY_COLOR] = colours
		changed[mesh] = true
	return changed

## Puts each changed mesh's arrays back: the same ArrayMesh, so what shares it
## (the bridge computer's miniature) sees the tint too. About a millisecond for
## the starter's plating (reference.md).
func _upload(meshes: Dictionary) -> void:
	for mesh: ArrayMesh in meshes:
		if _surfaces.has(mesh):   # not dropped by a rebuild since
			mesh.clear_surfaces()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surfaces[mesh][0])

func _upload_stale() -> void:
	var meshes := _stale
	_stale = {}
	_upload(meshes)

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
	_colours.clear()
	_spans = {}
	_surfaces.clear()
	_stale = {}
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
		var inst := _grid.get_block(coord)
		var shape_name := HullShapes.shape_of(inst.block_id)
		if shape_name == HullShapes.CUBE or _layout.is_pod_cell(coord):
			_add_collider(body, _box_shape(), Transform3D(Basis.IDENTITY, ShipGrid.cell_center(coord)), coord)
		else:
			# Shaped blocks (spec §3.4): their colliders are their shapes, in
			# convex pieces, so rocks and a spacewalker meet what is drawn.
			var frame := HullLayout.cell_frame(coord, inst.orientation)
			for part in HullShapes.collider_parts(shape_name):
				var convex := ConvexPolygonShape3D.new()
				convex.points = part
				_add_collider(body, convex, frame, coord)
		_collider_coords.append(coord)

func _box_shape() -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * ShipGrid.CELL_SIZE
	return shape

func _add_collider(body: Node, shape: Shape3D, xform: Transform3D, coord: Vector3i) -> void:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.transform = xform
	# Which block a hit on this shape damages (health and damage spec §5.1):
	# a shaped block has several shapes, so a shape index is not a cell.
	node.set_meta(&"cell", coord)
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
	_spans = made["spans"]
	for mesh: ArrayMesh in made["surfaces"]:
		var arrays: Array = made["surfaces"][mesh]
		_surfaces[mesh] = [arrays, (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()]
	# Dressed as made, then each hurt cell tinted (health and damage spec §9):
	# a ship loaded or rebuilt with damage shows it.
	var changed := {}
	for coord in _grid.coords():
		var inst := _grid.get_block(coord)
		var colour := stage_colour(BlockDamage.stage_of(inst, _catalog.get_def(inst.block_id)))
		_colours[coord] = colour
		if colour != HullPalette.UNHURT:
			changed.merge(_tint(coord, colour))
	_upload(changed)
