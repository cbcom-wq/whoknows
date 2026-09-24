class_name InteriorBuilder
extends Node3D

## Reads a ShipGrid and produces the walkable interior's structure: a floor
## under every walkable cell, a ceiling above it, and a wall on every face
## where a walkable cell meets solid structure or vacuum -- each a collider and
## a box built from the same numbers. What every face *is* is decided once, by
## InteriorLayout; everything attached to the surfaces is InteriorDressing's
## (docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md §4-§5).
##
## A walkable cell whose face touches a `canopy` cell keeps a collider there
## but no box: the visible canopy is the rounded nose InteriorDressing builds
## over the whole windshield (spec §6), so the avatar stops at the plane like
## a railing while the pilot looks out through the nose's windows.
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

const _SLAB := Vector3(ShipGrid.CELL_SIZE, FLOOR_THICKNESS, ShipGrid.CELL_SIZE)

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
## The nose shell's material: a ShaderMaterial on canopy_window.gdshader
## carrying the canopy SubViewport's ViewportTexture. Stays null in tests,
## where the nose falls back to the same shader with black windows -- never a
## hole.
@export var canopy_material: Material

var _grid: ShipGrid
var _catalog: BlockCatalog
var _layout: InteriorLayout
var _walkable: Array[Vector3i] = []
var _walls: Array[CollisionShape3D] = []
var _canopy_faces: Array[CollisionShape3D] = []
var _fixtures: Array[MeshInstance3D] = []
var _gravity: Dictionary = {}   # Vector3i -> float

# Interior geometry owns one physics body per rebuild(), carrying every
# floor/ceiling/wall/canopy CollisionShape3D and MeshInstance3D, and the
# Dressing node. One body with many shapes is the normal Godot way to
# represent static level geometry, and it is what makes the
# interior_geometry collision convention (layer 2, mask 0) a single
# assignment instead of one per box.
var _physics_body: StaticBody3D

func bind(grid: ShipGrid, catalog: BlockCatalog) -> void:
	_grid = grid
	_catalog = catalog

func rebuild() -> void:
	_clear()
	if _grid == null or _catalog == null:
		return
	var graph := DeckGraph.build(_grid, _catalog)
	_walkable.assign(graph.walkable_coords())
	_layout = InteriorLayout.plan(_grid, _catalog, _walkable)

	_physics_body = StaticBody3D.new()
	_physics_body.name = "InteriorGeometry"
	_physics_body.collision_layer = 2
	_physics_body.collision_mask = 0
	_body().add_child(_physics_body)

	_build_structure()
	_build_fixtures()
	InteriorDressing.build(_layout, _physics_body, canopy_material)
	_compute_gravity()

func walkable_coords() -> Array:
	return _walkable.duplicate()

## What every interior face is, as decided for the last rebuild(). Null
## before the first.
func layout() -> InteriorLayout:
	return _layout

func wall_count() -> int:
	return _walls.size()

func canopy_face_count() -> int:
	return _canopy_faces.size()

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
	# deletes the body and its whole subtree (every CollisionShape3D,
	# MeshInstance3D and the Dressing under it) immediately, instead of
	# leaving them parentless-but-alive for the rest of the frame. This was a
	# Critical finding against Task 13's ExteriorBuilder for the identical
	# reason; fixed here from the start rather than round-tripped through review.
	if is_instance_valid(_physics_body):
		var parent := _physics_body.get_parent()
		if parent != null:
			parent.remove_child(_physics_body)
		_physics_body.free()
	_physics_body = null
	_layout = null
	_walls.clear()
	_canopy_faces.clear()
	_fixtures.clear()
	_walkable.clear()
	_gravity.clear()

func _body() -> Node:
	return get_node(body_path) if not body_path.is_empty() else self

func _build_structure() -> void:
	var half := ShipGrid.CELL_SIZE * 0.5
	for face in _layout.faces():
		var coord: Vector3i = face["coord"]
		var normal: Vector3i = face["normal"]
		var at := ShipGrid.cell_center(coord) + Vector3(normal) * half
		match face["kind"]:
			InteriorLayout.Kind.FLOOR:
				_add_box(_physics_body, _SLAB, at, InteriorMaterials.flat(_floor_colour(face["zone"])))
			InteriorLayout.Kind.CEILING:
				_add_box(_physics_body, _SLAB, at, InteriorMaterials.flat(InteriorPalette.CEILING))
			InteriorLayout.Kind.WALL:
				if face["porthole"]:
					_walls.append(_add_collider(_physics_body, _wall_size(normal), at))
					_add_porthole_wall(at, normal)
				else:
					_walls.append(_add_box(_physics_body, _wall_size(normal), at,
						InteriorMaterials.flat(InteriorPalette.WALL)))
			InteriorLayout.Kind.CANOPY:
				_canopy_faces.append(_add_collider(_physics_body, _wall_size(normal), at))

static func _floor_colour(zone: StringName) -> Color:
	return InteriorPalette.FLOOR_BRIDGE if zone == InteriorLayout.ZONE_BRIDGE else InteriorPalette.FLOOR

static func _wall_size(normal: Vector3i) -> Vector3:
	return Vector3(
		FLOOR_THICKNESS if normal.x != 0 else ShipGrid.CELL_SIZE,
		ShipGrid.CELL_SIZE,
		FLOOR_THICKNESS if normal.z != 0 else ShipGrid.CELL_SIZE
	)

## A porthole wall's picture: four boxes round a square opening, centred where
## InteriorProps.porthole puts its frame. Only the picture has a hole -- the
## collider beside it is a whole wall, so a porthole is glass, never a way out.
func _add_porthole_wall(at: Vector3, normal: Vector3i) -> void:
	var material := InteriorMaterials.flat(InteriorPalette.WALL)
	var along := Vector3(absi(normal.z), 0, absi(normal.x))
	var thick := Vector3(absi(normal.x), 0, absi(normal.z)) * FLOOR_THICKNESS
	var half := ShipGrid.CELL_SIZE * 0.5
	var s := InteriorProps.PORTHOLE_OPENING
	var hole_y := InteriorProps.PORTHOLE_HEIGHT - (ShipGrid.CELL_SIZE - FLOOR_THICKNESS) * 0.5
	var side_w := half - s
	for side in [-1.0, 1.0]:
		_add_visual(_physics_body, thick + along * side_w + Vector3.UP * ShipGrid.CELL_SIZE,
			at + along * side * (s + side_w * 0.5), material)
	var below := hole_y - s + half
	_add_visual(_physics_body, thick + along * 2.0 * s + Vector3.UP * below,
		at + Vector3.UP * (below * 0.5 - half), material)
	var above := half - (hole_y + s)
	_add_visual(_physics_body, thick + along * 2.0 * s + Vector3.UP * above,
		at + Vector3.UP * (half - above * 0.5), material)

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

## A collider and a box from the same size and position. Never compute the two
## independently -- what you see must be exactly what you collide with. A
## porthole wall is the one deliberate exception, and it calls the halves itself.
func _add_box(parent: Node, size: Vector3, at: Vector3, material: Material) -> CollisionShape3D:
	var collider := _add_collider(parent, size, at)
	_add_visual(parent, size, at, material)
	return collider

func _add_collider(parent: Node, size: Vector3, at: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	parent.add_child(collider)
	return collider

func _add_visual(parent: Node, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.layers = 2   # interior render layer; lights cull to it separately
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

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
