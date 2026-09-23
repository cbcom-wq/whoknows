class_name InteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the walkable interior: a floor under every
## walkable cell, a ceiling above it, and a wall on every face where a
## walkable cell meets solid structure or vacuum. A walkable cell whose
## face touches a `canopy` cell gets a canopy surface there instead of a
## wall (art direction §7 item 4) -- the same box geometry, a different
## material and a separate count, so the shuttle's raked windshield is
## real glass with a real collider, not a hole in the hull.
##
## The output never moves. That is the whole architecture.
##
## Never references ExteriorBuilder. Both are independent readers of the
## same ShipGrid, which is what makes the parity test honest.

## Deck and overhead slab thickness. Each slab eats half its thickness from
## the cell, so clear headroom is CELL_SIZE - FLOOR_THICKNESS. At 0.2 that
## was exactly 1.8 m for an exactly 1.8 m avatar -- zero margin, and the
## player jammed into the overhead. 0.1 leaves 1.9 m clear.
const FLOOR_THICKNESS := 0.1
const DEFAULT_GRAVITY := 9.8
const CANOPY_ID := &"canopy"

## Names the parent under which this builder creates and owns its own
## StaticBody3D each rebuild() -- NOT a body to attach colliders to.
## This is the opposite of ExteriorBuilder.body_path, which names a
## scene-supplied RigidBody3D that colliders attach to directly. Same
## export name, deliberately different meaning between the two builders:
## a bare CollisionShape3D parented under a plain Node3D (which is what
## body_path would point at here, e.g. a Node3D "Interior" placeholder)
## never registers with the physics server, so InteriorBuilder cannot
## reuse ExteriorBuilder's shape -- it must own a StaticBody3D itself to
## carry the interior_geometry convention (collision_layer = 2,
## collision_mask = 0; see _physics_body below). If empty, the owned body
## is parented directly under this node.
@export var body_path: NodePath
## Wired by Task 15 to the material carrying the canopy SubViewport's
## ViewportTexture. Stays null in tests -- falls back to an ordinary
## opaque material so a headless build still produces a complete,
## collidable interior and never crashes or leaves a hole.
@export var canopy_material: Material

var _grid: ShipGrid
var _catalog: BlockCatalog
var _walkable: Array[Vector3i] = []
var _walls: Array[CollisionShape3D] = []
var _canopy_faces: Array[CollisionShape3D] = []
var _canopy_panes: Array[Dictionary] = []   # [{scale, offset}], see canopy_pane_uvs()
var _fixtures: Array[MeshInstance3D] = []
var _gravity: Dictionary = {}   # Vector3i -> float

# Interior geometry owns one physics body per rebuild(), carrying every
# floor/ceiling/wall/canopy CollisionShape3D and MeshInstance3D. One body
# with many shapes is the normal Godot way to represent static level
# geometry, and it is what makes the interior_geometry collision
# convention (layer 2, mask 0) a single assignment instead of one per box.
var _physics_body: StaticBody3D

var _deck_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _canopy_fallback_material: StandardMaterial3D

func bind(grid: ShipGrid, catalog: BlockCatalog) -> void:
	_grid = grid
	_catalog = catalog

func rebuild() -> void:
	_clear()
	if _grid == null or _catalog == null:
		return
	var graph := DeckGraph.build(_grid, _catalog)
	_walkable.assign(graph.walkable_coords())

	_physics_body = StaticBody3D.new()
	_physics_body.name = "InteriorGeometry"
	_physics_body.collision_layer = 2
	_physics_body.collision_mask = 0
	_body().add_child(_physics_body)

	_build_floors()
	_build_walls()
	_build_fixtures()
	_compute_gravity()

func walkable_coords() -> Array:
	return _walkable.duplicate()

func wall_count() -> int:
	return _walls.size()

func canopy_face_count() -> int:
	return _canopy_faces.size()

## Each canopy pane's share of the SubViewport, as {scale, offset} in UV
## units, ordered as the panes were built. One pane shows the whole view;
## three in a row show a third each, so together they read as one window.
func canopy_pane_uvs() -> Array[Dictionary]:
	return _canopy_panes.duplicate()

func fixture_count() -> int:
	return _fixtures.size()

func fixture_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in _fixtures:
		out.append(f.position)
	return out

func gravity_at(coord: Vector3i) -> float:
	return _gravity.get(coord, 0.0)

func _clear() -> void:
	# remove_child() then free() -- not queue_free(). remove_child() is
	# synchronous and fires NOTIFICATION_UNPARENTED immediately, which is
	# what actually deregisters a StaticBody3D (and every CollisionShape3D
	# it carries) from the physics server. queue_free() alone does not do
	# that: the node stays parented (and physics-registered) until the
	# delete queue is flushed, which never happens between two synchronous
	# rebuild() calls -- exactly what several cell_changed signals firing
	# in the same frame from the shipyard editor look like. free() then
	# deletes the body and its whole subtree (every CollisionShape3D and
	# MeshInstance3D under it) immediately, instead of leaving them
	# parentless-but-alive for the rest of the frame. This was a Critical
	# finding against Task 13's ExteriorBuilder for the identical reason;
	# fixed here from the start rather than round-tripped through review.
	if is_instance_valid(_physics_body):
		var parent := _physics_body.get_parent()
		if parent != null:
			parent.remove_child(_physics_body)
		_physics_body.free()
	_physics_body = null
	_walls.clear()
	_canopy_faces.clear()
	_canopy_panes.clear()
	_fixtures.clear()
	_walkable.clear()
	_gravity.clear()

func _body() -> Node:
	return get_node(body_path) if not body_path.is_empty() else self

func _build_floors() -> void:
	var half := ShipGrid.CELL_SIZE * 0.5
	for coord in _walkable:
		var center := ShipGrid.cell_center(coord)
		_add_box(
			_physics_body,
			Vector3(ShipGrid.CELL_SIZE, FLOOR_THICKNESS, ShipGrid.CELL_SIZE),
			center + Vector3(0, -half, 0),
			_deck_mat()
		)
		_add_box(
			_physics_body,
			Vector3(ShipGrid.CELL_SIZE, FLOOR_THICKNESS, ShipGrid.CELL_SIZE),
			center + Vector3(0, half, 0),
			_ceiling_mat()
		)

func _build_walls() -> void:
	var half := ShipGrid.CELL_SIZE * 0.5
	var panes: Array[Dictionary] = []
	var walkable_set := {}
	for coord in _walkable:
		walkable_set[coord] = true

	for coord in _walkable:
		var center := ShipGrid.cell_center(coord)
		for offset in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
				Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var neighbour: Vector3i = coord + offset
			if walkable_set.has(neighbour):
				continue   # open passage between two walkable cells
			var normal := Vector3(offset)
			var size := Vector3(
				FLOOR_THICKNESS if offset.x != 0 else ShipGrid.CELL_SIZE,
				ShipGrid.CELL_SIZE,
				FLOOR_THICKNESS if offset.z != 0 else ShipGrid.CELL_SIZE
			)
			var position := center + normal * half
			if _is_canopy(neighbour):
				panes.append({
					"coord": coord, "face": offset, "size": size, "position": position
				})
			else:
				_walls.append(_add_box(_physics_body, size, position, _wall_mat()))

	_build_canopy_panes(panes)

## Builds the canopy faces once every pane is known, because each pane's
## material depends on how many panes share its plane.
##
## All panes show the same SubViewport. Left alone, each would render the
## whole forward view, and a three-cell windshield would read as three
## copies of one picture rather than one window -- so each pane takes its
## own share of the texture, by column and row within its plane.
##
## The split assumes a pane group faces the same way the canopy camera
## looks, which for the shuttle (and any ship with a forward windshield) it
## does. Side and rear glass would need their own camera to be more than
## decorative, so they are not a special case here.
func _build_canopy_panes(panes: Array[Dictionary]) -> void:
	var groups: Dictionary = {}   # plane key -> Array[Dictionary]
	for pane in panes:
		var face: Vector3i = pane["face"]
		var coord: Vector3i = pane["coord"]
		var across: int = coord.x if face.z != 0 else coord.z
		var key := "%s:%d" % [face, coord.z if face.z != 0 else coord.x]
		pane["across"] = across
		groups.get_or_add(key, []).append(pane)

	for key in groups:
		var group: Array = groups[key]
		var columns := _sorted_unique(group, "across", false)
		var rows := _sorted_unique(group, "row", true)
		var scale := Vector2(1.0 / columns.size(), 1.0 / rows.size())
		group.sort_custom(func(a, b): return a["across"] < b["across"])
		for pane in group:
			var offset := Vector2(
				columns.find(pane["across"]) * scale.x,
				rows.find(pane["coord"].y) * scale.y
			)
			_canopy_panes.append({"scale": scale, "offset": offset})
			_canopy_faces.append(_add_box(
				_physics_body, pane["size"], pane["position"], _pane_mat(scale, offset)
			))

## The distinct values of `field` across a pane group, sorted. Rows sort
## downward (v increases down the texture); columns sort upward.
func _sorted_unique(group: Array, field: String, descending: bool) -> Array:
	var values: Array = []
	for pane in group:
		var value: int = pane["coord"].y if field == "row" else pane[field]
		if not values.has(value):
			values.append(value)
	values.sort()
	if descending:
		values.reverse()
	return values

## One pane's slice of the shared canopy material. Duplicated per pane
## because uv1_scale/uv1_offset live on the material, not the surface; the
## duplicate is shallow, so every pane still samples the one ViewportTexture
## rather than a copy of it.
func _pane_mat(scale: Vector2, offset: Vector2) -> Material:
	var base := _canopy_mat()
	if not base is BaseMaterial3D:
		return base
	if scale.is_equal_approx(Vector2.ONE) and offset.is_zero_approx():
		return base
	var mat: BaseMaterial3D = base.duplicate()
	mat.uv1_scale = Vector3(scale.x, scale.y, 1.0)
	mat.uv1_offset = Vector3(offset.x, offset.y, 0.0)
	return mat

## Draws every MOUNT block that has a mesh: seats, consoles, ladders -- the
## fixtures a player sees and walks up to. Without this the pilot seat is an
## invisible collider with an interact prompt and nothing to look at.
func _build_fixtures() -> void:
	for coord in _grid.coords():
		var inst := _grid.get_block(coord)
		var def := _catalog.get_def(inst.block_id)
		if def == null or def.mesh == null:
			continue
		if def.occupancy != BlockDefinition.Occupancy.MOUNT:
			continue
		var fixture := MeshInstance3D.new()
		fixture.mesh = def.mesh
		fixture.transform = Transform3D(
			BlockOrientation.basis_for(inst.orientation), ShipGrid.cell_center(coord)
		)
		fixture.layers = 2   # interior render layer, same as the walls
		_physics_body.add_child(fixture)
		_fixtures.append(fixture)

func _is_canopy(coord: Vector3i) -> bool:
	var inst := _grid.get_block(coord)
	return inst != null and inst.block_id == CANOPY_ID

## Creates one box's CollisionShape3D and its MeshInstance3D from the same
## size and position, both parented to `parent`. Never compute the two
## independently -- what you see must be exactly what you collide with.
func _add_box(parent: Node, size: Vector3, position: Vector3, material: Material) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = position
	parent.add_child(collider)

	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.layers = 2   # interior render layer; lights cull to it separately
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

	return collider

func _compute_gravity() -> void:
	var plates: Array = []
	for coord in _grid.coords():
		var def := _catalog.get_def(_grid.get_block(coord).block_id)
		if def != null and def.grav_radius > 0.0:
			plates.append({"center": ShipGrid.cell_center(coord), "radius": def.grav_radius})

	for coord in _walkable:
		var center := ShipGrid.cell_center(coord)
		var g := 0.0
		for plate in plates:
			if center.distance_to(plate["center"]) <= plate["radius"]:
				g = DEFAULT_GRAVITY
				break
		_gravity[coord] = g

# Materials are shared, not per-instance: one StandardMaterial3D per role,
# created once and handed to every surface that needs it. Palette: art
# direction §5.2 -- the player's own ship is bright, warm and lived-in,
# not the "dim and pooled" treatment §11 reserves for derelict/enemy hulls.

func _deck_mat() -> StandardMaterial3D:
	if _deck_material == null:
		_deck_material = StandardMaterial3D.new()
		_deck_material.albedo_color = Color("6e2822")   # deck plank
	return _deck_material

## §5.2 has no separate ceiling entry, so this deliberately reuses the
## bulkhead colour -- but as its own StandardMaterial3D object, not a
## shared reference to _wall_mat()'s. Kept distinct on purpose: a future
## ceiling-specific palette change (e.g. a duller tone so eyes read the
## deck as "down") is then a one-line edit here, not a search through
## every _wall_mat() call site to see which boxes were secretly ceilings.
func _ceiling_mat() -> StandardMaterial3D:
	if _ceiling_material == null:
		_ceiling_material = StandardMaterial3D.new()
		_ceiling_material.albedo_color = Color("b4b9bf")   # bulkhead
	return _ceiling_material

func _wall_mat() -> StandardMaterial3D:
	if _wall_material == null:
		_wall_material = StandardMaterial3D.new()
		_wall_material.albedo_color = Color("b4b9bf")   # bulkhead
	return _wall_material

## Falls back to an ordinary opaque material when canopy_material hasn't
## been wired by the scene (always true in this builder's own tests).
## Structure only -- Task 15 owns proving the real ViewportTexture is fed
## in; this just guarantees a headless rebuild() never leaves a hole.
func _canopy_mat() -> Material:
	if canopy_material != null:
		return canopy_material
	if _canopy_fallback_material == null:
		_canopy_fallback_material = StandardMaterial3D.new()
		_canopy_fallback_material.albedo_color = Color("141a22")   # canopy glass, unlit
	return _canopy_fallback_material
