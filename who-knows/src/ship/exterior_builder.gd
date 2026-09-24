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

## How fast a thruster's glow chases its throttle, in 1/s. Engines light
## faster than they die away, so a tap on the stick reads as a flare.
const SPOOL_UP_RATE := 14.0
const SPOOL_DOWN_RATE := 5.0

## One block that thrusts: which MultiMesh instance draws it, the ship-local
## direction it pushes the ship, and the throttle its bell is showing.
class Thruster:
	var multimesh: MultiMesh
	var index: int
	var direction: Vector3
	var throttle: float = 0.0

	func _init(mm: MultiMesh, i: int, dir: Vector3) -> void:
		multimesh = mm
		index = i
		direction = dir

@export var body_path: NodePath

var _grid: ShipGrid
var _catalog: BlockCatalog
var _collider_coords: Array[Vector3i] = []
var _colliders: Array[CollisionShape3D] = []
var _multimeshes: Dictionary = {}   # StringName -> MultiMeshInstance3D
var _thrusters: Array[Thruster] = []

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

## Every thrusting block as show_thrust() drives it. The same state goes to
## the MultiMesh, but a headless RenderingServer keeps no instance data, so
## this is what tests read.
func thrusters() -> Array[Thruster]:
	return _thrusters.duplicate()

## Lights every thruster by how hard it is firing. `throttle` is
## FlightComputer.throttle -- a signed fraction of the budget along each
## ship-local axis -- so a thruster's share is the part of it along the way
## that thruster pushes. Each glow eases toward its share rather than
## snapping, and lands in its instance's custom data, where
## thruster_bell.gdshader turns it into light.
func show_thrust(throttle: Vector3, delta: float) -> void:
	for thruster in _thrusters:
		var target := maxf(throttle.dot(thruster.direction), 0.0)
		var rate := SPOOL_UP_RATE if target > thruster.throttle else SPOOL_DOWN_RATE
		thruster.throttle = lerpf(thruster.throttle, target, 1.0 - exp(-rate * delta))
		thruster.multimesh.set_instance_custom_data(
			thruster.index, Color(thruster.throttle, 0.0, 0.0, 0.0)
		)

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
	_thrusters.clear()

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
		var def := _catalog.get_def(block_id)
		var transforms: Array = by_type[block_id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# A block type's instances share one material, so how hard each
		# thruster fires travels per instance. MultiMesh only takes this
		# before its instance count is set.
		mm.use_custom_data = def.thrust_kn > 0.0
		mm.mesh = def.mesh
		mm.instance_count = transforms.size()
		for index in transforms.size():
			mm.set_instance_transform(index, transforms[index])
			if mm.use_custom_data:
				mm.set_instance_custom_data(index, Color(0.0, 0.0, 0.0, 0.0))
				# The same push ShipStats counts: block-local -Z.
				var push: Vector3 = transforms[index].basis * Vector3(0, 0, -1)
				_thrusters.append(Thruster.new(mm, index, push))

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.layers = OWN_HULL_LAYER
		add_child(mmi)
		_multimeshes[block_id] = mmi
