class_name Ship
extends Node3D

## Owns one ship's grid and both representations of it. The grid is the
## source of truth; everything else here reacts to `cell_changed`.

signal stats_changed(stats: ShipStats)

const INTERIOR_WORLD_BASE := Vector3(0.0, -5000.0, 0.0)
const SLOT_SPACING := 2000.0

@export var interior_slot: int = 0

var grid: ShipGrid
var stats: ShipStats
var catalog: BlockCatalog

@onready var exterior: RigidBody3D = $Exterior
@onready var interior: Node3D = $Interior
@onready var exterior_builder: ExteriorBuilder = $Exterior/ExteriorBuilder
@onready var interior_builder: InteriorBuilder = $Interior/InteriorBuilder
@onready var flight_computer: FlightComputer = $FlightComputer

func _ready() -> void:
	exterior.gravity_scale = 0.0
	exterior.linear_damp = 0.0
	exterior.angular_damp = 0.0
	exterior.can_sleep = false
	exterior.collision_layer = 1   # exterior_hull
	exterior.collision_mask = 1    # detects only other hulls
	interior.global_position = interior_slot_origin()
	if catalog == null:
		catalog = BlockCatalog.load_from_dir("res://data/blocks")

func interior_slot_origin() -> Vector3:
	# Interior space sits well clear of the combat arena so the walkable
	# interior can never intersect a flying hull. Collision layers enforce
	# the same separation independently.
	return INTERIOR_WORLD_BASE + Vector3(interior_slot * SLOT_SPACING, 0.0, 0.0)

func load_blueprint(bp: ShipBlueprint) -> void:
	set_grid(bp.to_grid())

func set_grid(new_grid: ShipGrid) -> void:
	if grid != null and grid.cell_changed.is_connected(_on_cell_changed):
		grid.cell_changed.disconnect(_on_cell_changed)
	grid = new_grid
	grid.cell_changed.connect(_on_cell_changed)
	exterior_builder.bind(grid, catalog)
	interior_builder.bind(grid, catalog)
	_rebuild_everything()

func _on_cell_changed(_coord: Vector3i) -> void:
	# Slice 1 rebuilds wholesale on any change. At 150 blocks this is well
	# under a frame. Incremental per-cell rebuild is a Slice 2 optimisation
	# for when weapons start destroying blocks every few milliseconds.
	_rebuild_everything()

func _rebuild_everything() -> void:
	exterior_builder.rebuild()
	interior_builder.rebuild()
	stats = ShipStats.compute(grid, catalog)
	_apply_stats()
	stats_changed.emit(stats)

func _apply_stats() -> void:
	exterior.mass = maxf(stats.total_mass_kg, 1.0)
	exterior.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	exterior.center_of_mass = stats.center_of_mass
	exterior.inertia = stats.inertia
	flight_computer.thrust_budget = stats.thrust_budget.duplicate()
	flight_computer.torque_budget = stats.torque_budget
