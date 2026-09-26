class_name Ship
extends Node3D

## Owns one ship's grid and both representations of it. The grid is the
## source of truth; everything else here reacts to `cell_changed`.

signal stats_changed(stats: ShipStats)

const INTERIOR_WORLD_BASE := Vector3(0.0, -5000.0, 0.0)
const SLOT_SPACING := 2000.0
## How close a rebuilt stow point must be to where a stowed item's point was
## for the item to stay stowed through the rebuild.
const RESEAT_TOLERANCE := 0.05

## The exact ShaderMaterial `hull`/`hull_wedge` meshes reference (their .tres
## surfaces point at this same path, and Godot's resource cache guarantees a
## single shared instance) -- not a duplicate. Loading it here needs no
## change to ExteriorBuilder.
const HULL_LIVERY_MATERIAL: ShaderMaterial = preload("res://data/materials/hull_livery.tres")

@export var interior_slot: int = 0
## Where a spacewalker goes (airlock spec §7.4): the scene's root for things in
## the real world that are not the ship.
@export var outside_path: NodePath

var grid: ShipGrid
var outside: Node3D
var stats: ShipStats
var catalog: BlockCatalog
var item_catalog: ItemCatalog
## Every item aboard that is not in someone's hand (hands-and-items spec
## §4.4). A sibling of the builders, so an interior rebuild never touches it.
var items: Node3D
## Every airlock that can cycle, by cell (airlock spec §4.5). Each outlives the
## rebuilds that replace the room it drives.
var airlocks: Dictionary = {}   # Vector3i -> Airlock
## The RCS thrusters you see and hear (flight controls spec §6). On the hull,
## so the floating origin carries it.
var rcs_show: RcsShow
## The quantum store and the core(s) it drives (quantum energy spec §3.2,
## §8). At Ship/Quantum, alongside FlightComputer -- the two share the one
## QuantumStore instance below.
var quantum: QuantumPlant

var _stocked := false
var _airlocks_root: Node
## The ship's air handling (airlock spec §6): heard everywhere aboard,
## through the Ship bus, so it drains away with the air in the airlock.
var _hum: AudioStreamPlayer
## A rock striking the hull, heard aboard (asteroids spec §7.5).
var _thump: AudioStreamPlayer
var _last_hull_velocity := Vector3.ZERO

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
	exterior.collision_mask = 1 | AsteroidBody.LAYER   # other hulls, and rocks
	# At boost the hull moves 5 m a tick: without this it passes through rubble.
	exterior.continuous_cd = true
	# Outside, so the floating origin moves it (asteroids spec §4.2).
	exterior.add_to_group(Universe.EXTERIOR_SPACE)
	# It touches rocks (asteroids spec §7.1).
	exterior.add_to_group(AsteroidStream.SPACE_ANCHOR)
	interior.global_position = interior_slot_origin()
	outside = get_node_or_null(outside_path) as Node3D if not outside_path.is_empty() else null
	if outside == null:
		outside = get_parent() as Node3D
	if catalog == null:
		catalog = BlockCatalog.load_from_dir("res://data/blocks")
	if item_catalog == null:
		item_catalog = ItemCatalog.load_from_dir("res://data/items")
	items = Node3D.new()
	items.name = "Items"
	interior.add_child(items)
	_airlocks_root = Node.new()
	_airlocks_root.name = "Airlocks"
	add_child(_airlocks_root)
	rcs_show = RcsShow.new()
	rcs_show.name = "RcsShow"
	exterior.add_child(rcs_show)
	rcs_show.setup(flight_computer, interior)
	quantum = QuantumPlant.new()
	quantum.name = "Quantum"
	quantum.flight_computer = flight_computer
	add_child(quantum)
	AudioBuses.ensure()
	Synth.warm_up()
	_hum = AudioStreamPlayer.new()
	_hum.name = "Hum"
	_hum.bus = AudioBuses.SHIP
	_hum.volume_db = -16.0
	add_child(_hum)
	_thump = AudioStreamPlayer.new()
	_thump.name = "Thump"
	_thump.bus = AudioBuses.SHIP
	add_child(_thump)
	exterior.contact_monitor = true
	exterior.max_contacts_reported = 8
	exterior.body_entered.connect(_on_hull_struck)

func _process(_delta: float) -> void:
	# hull_livery.gdshader paints its stripe from ship-local height, but
	# MultiMesh's MODEL_MATRIX is model-to-*world* -- it carries the hull
	# RigidBody3D's own rotation along with each block's per-instance
	# transform. Pushing the hull's inverse transform every frame lets the
	# shader cancel that rotation (`hull_inverse * MODEL_MATRIX`) before
	# testing height, so the stripe stays fixed on the hull under roll and
	# pitch instead of swimming across it. See hull_livery.gdshader's header
	# comment for the full derivation.
	HULL_LIVERY_MATERIAL.set_shader_parameter(&"hull_inverse", exterior.global_transform.affine_inverse())
	_update_hum()

## The hum plays while the listener is aboard, and stops outside.
func _update_hum() -> void:
	var aboard := _aboard()
	if aboard and not _hum.playing:
		var s := Synth.sound(&"ship_hum")
		if s != null:
			_hum.stream = s
			_hum.play()
	elif not aboard and _hum.playing:
		_hum.stop()

func _physics_process(_delta: float) -> void:
	_last_hull_velocity = exterior.linear_velocity

func _on_hull_struck(body: Node) -> void:
	if body is AsteroidBody:
		hull_struck((exterior.linear_velocity - _last_hull_velocity).length())

## A strike you feel aboard (asteroids spec §7.5): a thump, louder the harder
## the hull was knocked (`knock`: its change of speed, m/s). Outside is silent.
func hull_struck(knock: float) -> void:
	if not _aboard():
		return
	var s := Synth.sound(&"hull_thump")
	if s == null:
		return
	_thump.stream = s
	_thump.volume_db = thump_db(knock)
	_thump.play()

static func thump_db(knock: float) -> float:
	return lerpf(-30.0, -2.0, clampf(knock / 8.0, 0.0, 1.0))

## True while the camera you see through is aboard.
func _aboard() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and interior.is_ancestor_of(cam)

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
	var stowed := _stowed_items()
	exterior_builder.rebuild()
	interior_builder.rebuild()
	_bind_airlocks()
	_reseat(stowed)
	if not _stocked:
		_stock()
		_stocked = true
	stats = ShipStats.compute(grid, catalog)
	_apply_stats()
	quantum.bind(interior_builder.quantum_cores(), interior_builder.quantum_machines(), stats)
	flight_computer.quantum = quantum.store
	if rcs_show != null:
		rcs_show.rebuild(grid, catalog, stats.center_of_mass)
	stats_changed.emit(stats)
	_set_anchor_radius()

## How far the hull reaches from its origin, for the asteroid bubble.
func _set_anchor_radius() -> void:
	var reach := 0.0
	for c: Vector3i in grid.coords():
		reach = maxf(reach, ShipGrid.cell_center(c).length())
	exterior.set_meta(AsteroidStream.ANCHOR_RADIUS, reach + ShipGrid.CELL_SIZE * 0.87)

## Hands each rebuilt airlock room to its Airlock, making one for a new
## airlock and dropping those whose cell is gone. An Airlock keeps its cycle,
## so a rebuild never resets a pressure or moves a hatch.
func _bind_airlocks() -> void:
	if _airlocks_root == null:
		return
	var seen := {}
	for room in interior_builder.airlock_rooms():
		seen[room.coord] = true
		var airlock: Airlock = airlocks.get(room.coord)
		if airlock == null:
			airlock = Airlock.new()
			airlock.setup(self, room.coord)
			_airlocks_root.add_child(airlock)
			airlocks[room.coord] = airlock
		airlock.bind(room, exterior_builder.alcoves().get(room.coord))
	for at in airlocks.keys():
		if not seen.has(at):
			var gone: Airlock = airlocks[at]
			airlocks.erase(at)
			_airlocks_root.remove_child(gone)
			gone.free()

## Every stowed item and where its stow point was, before a rebuild frees the
## points.
func _stowed_items() -> Array:
	var out := []
	if items == null:
		return out
	for node in items.get_children():
		var item := node as Item
		if item != null and item.state == Item.State.STOWED and is_instance_valid(item.stow_point):
			out.append([item, item.stow_point.global_position])
	return out

## Puts each stowed item back in the rebuilt point at the same place, or lets
## it loose where it is if that point is gone.
func _reseat(stowed: Array) -> void:
	var points := interior_builder.stow_points()
	for entry in stowed:
		var item: Item = entry[0]
		var was: Vector3 = entry[1]
		var home: StowPoint = null
		for point in points:
			if point.fits(item) and point.global_position.distance_to(was) < RESEAT_TOLERANCE:
				home = point
				break
		if home != null:
			home.secure(item)
		else:
			item.set_loose()

## Fills every stocked stow point, once, when the ship first loads
## (hands-and-items spec §5.3).
func _stock() -> void:
	if items == null:
		return
	for point in interior_builder.stow_points():
		if point.stock == &"" or not point.is_free():
			continue
		var def := item_catalog.get_def(point.stock)
		if def == null:
			push_warning("Ship: no item called %s to stock" % point.stock)
			continue
		var item := Item.new()
		var at := point.global_position
		item.setup(def, fposmod(at.x * 0.37 + at.z * 0.61, 1.0))
		items.add_child(item, true)
		point.secure(item)

func _apply_stats() -> void:
	exterior.mass = maxf(stats.total_mass_kg, 1.0)
	exterior.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	exterior.center_of_mass = stats.center_of_mass
	exterior.inertia = stats.inertia
	flight_computer.thrust_budget = stats.thrust_budget.duplicate()
	flight_computer.torque_budget = stats.torque_budget
	flight_computer.inertia = stats.inertia
