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
## How long after a rock strikes the hull a save waits (saving spec §5).
const STRUCK_CALM := 5.0
## How often, and how far past the hull, a hard burn is checked for blasting a
## rock's surface.
const BLAST_EVERY := 0.5
const BLAST_REACH := 50.0

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
## The work lights (ship exterior spec §6, §7). On the hull, so the floating
## origin carries them; kept across rebuilds, like Airlocks.
var lights: ShipLights

## Seconds since a rock last struck the hull.
var since_struck := INF

var _stocked := false
var _airlocks_root: Node
## Who lives aboard (NPC foundation spec §4.2, §14): the interior's director,
## the holder its NPCs stand under, and the place they live in.
var npc_director: NpcDirector
var npc_bus: StimulusBus
## What the ship knows is out there (NPC foundation spec §22.3): the flight
## scene gives it the universe and its sources.
var sensors: ShipSensors
var npcs: Node3D
var crew_site: ShipSite
var _crew: Array = []
var _computer_state: Dictionary = {}   # Vector3i -> ShipComputer.save()
## The ship's air handling (airlock spec §6): heard everywhere aboard,
## through the Ship bus, so it drains away with the air in the airlock.
var _hum: AudioStreamPlayer
## A rock striking the hull, heard aboard (asteroids spec §7.5).
var _thump: AudioStreamPlayer
var _last_hull_velocity := Vector3.ZERO
var _blast_in := 0.0

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
	exterior.collision_mask = 1 | BodyProxy.LAYER | AsteroidBody.LAYER | Npc.LAYER   # other hulls, worlds, rocks, NPCs
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
	_make_crew_quarters()
	sensors = ShipSensors.new()
	sensors.name = "Sensors"
	add_child(sensors)
	rcs_show = RcsShow.new()
	rcs_show.name = "RcsShow"
	exterior.add_child(rcs_show)
	rcs_show.setup(flight_computer, interior)
	quantum = QuantumPlant.new()
	quantum.name = "Quantum"
	quantum.flight_computer = flight_computer
	quantum.items = items
	quantum.item_catalog = item_catalog
	add_child(quantum)
	lights = ShipLights.new()
	lights.name = "Lights"
	lights.quantum = quantum
	exterior.add_child(lights)
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

func _physics_process(delta: float) -> void:
	_last_hull_velocity = exterior.linear_velocity
	since_struck += delta
	_blast_in -= delta
	if _blast_in <= 0.0:
		_blast_in = BLAST_EVERY
		_blast_rock()

func _on_hull_struck(body: Node) -> void:
	var knock := (exterior.linear_velocity - _last_hull_velocity).length()
	if body is AsteroidBody:
		since_struck = 0.0
		hull_struck(knock)
	_jolt_rock(body, knock)

## A strike carries through the rock it hit: anything living on it feels it
## (NPC foundation spec §6.1).
func _jolt_rock(body: Node, knock: float) -> void:
	var rock: AsteroidRock = null
	if body is AsteroidDetail:
		rock = (body as AsteroidDetail).rock
	elif body is AsteroidBody:
		rock = (body as AsteroidBody).rock
	if rock == null:
		return
	StimulusBus.send(exterior, Stimulus.make(Stimulus.VIBRATION, exterior.global_position,
		clampf(knock / 4.0, 0.2, 1.0), rock.radius * 2.0, exterior, RockHerds.site_of(rock)), 1.0)

## Thrusting hard close over a big rock blasts its surface (NPC foundation spec
## §6.1): one ray the way the exhaust goes, a few times a second.
func _blast_rock() -> void:
	var force := flight_computer.commanded_force_local
	var budget: float = flight_computer.thrust_budget[&"forward"]
	if force.length() < budget * 0.1 or not exterior.is_inside_tree():
		return
	var exhaust := -(exterior.global_basis * force).normalized()
	var from := exterior.global_position
	var reach := float(exterior.get_meta(AsteroidStream.ANCHOR_RADIUS, 10.0)) + BLAST_REACH
	var query := PhysicsRayQueryParameters3D.create(from, from + exhaust * reach, AsteroidBody.LAYER, [exterior.get_rid()])
	var hit := exterior.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit["collider"] is AsteroidDetail):
		return
	StimulusBus.send(exterior, Stimulus.make(Stimulus.VIBRATION, hit["position"], 0.6, 40.0, exterior,
		RockHerds.site_of((hit["collider"] as AsteroidDetail).rock)), BLAST_EVERY)

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

## Builds the ship from `new_grid`. `stock` false leaves the shelves empty --
## a loaded game brings its own items (saving spec §6.1).
func set_grid(new_grid: ShipGrid, stock := true) -> void:
	if not stock:
		_stocked = true
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
	_save_computers()
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
	if lights != null:
		lights.bind(exterior_builder.light_mounts(), exterior_builder.lenses(), exterior_builder.window_glow())
		for panel in interior_builder.lights_panels():
			panel.bind(lights)
	_bind_computers()
	if rcs_show != null:
		rcs_show.rebuild(grid, catalog, stats.center_of_mass)
	stats_changed.emit(stats)
	_set_anchor_radius()
	_bind_crew()

## Keeps each bridge computer's page, range and selection across a rebuild,
## which frees the dressing and every table in it (bridge computer spec §10).
func _save_computers() -> void:
	for c in interior_builder.computers():
		_computer_state[c.cell] = c.save()

## Binds each table to this ship, once the stats, the store and the sensors
## are all current, and gives it back its state.
func _bind_computers() -> void:
	for c in interior_builder.computers():
		var context := ComputerContext.new()
		context.sensors = sensors
		context.store = quantum.store
		context.stats = stats
		context.hull = exterior
		context.exterior_builder = exterior_builder
		c.bind(context)
		if _computer_state.has(c.cell):
			c.restore(_computer_state[c.cell])

## How far the hull reaches from its origin, for the asteroid bubble.
func _set_anchor_radius() -> void:
	var reach := 0.0
	for c: Vector3i in grid.coords():
		reach = maxf(reach, ShipGrid.cell_center(c).length())
	exterior.set_meta(AsteroidStream.ANCHOR_RADIUS, reach + ShipGrid.CELL_SIZE * 0.87)

## The interior's NPC director and the holder its NPCs stand under, made once
## and kept across rebuilds, like Airlocks. Inside, every record of the ship
## is live while its interior is built (NPC foundation spec §4.3).
func _make_crew_quarters() -> void:
	npcs = Node3D.new()
	npcs.name = "Npcs"
	interior.add_child(npcs)
	npc_director = NpcDirector.new()
	npc_director.name = "NpcDirector"
	npc_director.rule = NpcDirector.Rule.BY_SITE
	npc_director.max_live = 8
	npc_director.holder = npcs
	npc_director.catalog = NpcCatalog.load_from_dir("res://data/npcs")
	npc_director.sources = [self]
	add_child(npc_director)
	npc_bus = StimulusBus.new()
	npc_bus.name = "StimulusBus"
	add_child(npc_bus)
	npc_bus.setup(interior)
	npc_director.bus = npc_bus

## Re-reads the rebuilt interior for its crew: the droid's map, dock and jobs.
## A live droid survives the rebuild; one left on a cell that is gone is put
## back at its dock.
func _bind_crew() -> void:
	if npc_director == null or interior_builder.layout() == null:
		return
	if crew_site == null:
		crew_site = ShipSite.new(self)
	crew_site.rebind(interior_builder.layout())
	_crew.clear()
	for record in ShipCrew.records(interior_builder.layout(), crew_site.paths, name, 0):
		_crew.append([record, crew_site])
	for npc: Npc in npc_director.live_npcs():
		if npc.site == crew_site and not crew_site.paths.has(DeckPaths.cell_at(npc.local_position())):
			npc.global_transform = crew_site.frame() * crew_site.start_pose(npc.record, 0.0)
			npc.velocity = Vector3.ZERO

## The ship's crew, as its director asks for them.
func records(_director: NpcDirector) -> Array:
	return _crew

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

# --- saving (docs/superpowers/specs/2026-09-26-saving-design.md §3, §6) ------

## Why a save must wait (§5), or "": a rock struck the hull lately, an
## airlock is cycling, the quantum machine is busy, or a bolt is in flight.
func busy() -> String:
	if since_struck < STRUCK_CALM:
		return "hull struck"
	for airlock: Airlock in airlocks.values():
		var why := airlock.busy()
		if why != "":
			return why
	var why := quantum.busy() if quantum != null else ""
	if why != "":
		return why
	if items != null:
		for node in items.get_children():
			if node is PlasmaBolt:
				return "bolt in flight"
	return ""

## The ship's part of a save: its layout, where it is in `universe` and how
## it moves, its flight settings, its store, its lights, its airlocks and every item
## aboard that is not in someone's hand.
func to_dict(universe: Universe) -> Dictionary:
	var hull := exterior.global_transform
	var saved_airlocks := {}
	for at: Vector3i in airlocks:
		saved_airlocks[SaveCodec.cell_key(at)] = airlocks[at].to_dict()
	var saved_items := []
	var frame := interior.global_transform
	for node in items.get_children():
		var item := node as Item
		if item != null and item.state != Item.State.HELD and not item.is_queued_for_deletion():
			saved_items.append(item.to_dict(frame))
	return {
		"layout": ShipBlueprint.from_grid(grid, String(name)).to_dict(),
		"hull": {
			"at": SaveCodec.upoint(universe.to_universe(hull.origin)),
			"turn": SaveCodec.basis(hull.basis),
			"v": SaveCodec.vec3(exterior.linear_velocity),
			"w": SaveCodec.vec3(exterior.angular_velocity),
		},
		"flight": flight_computer.to_dict(),
		"store": quantum.store.to_dict() if quantum.store != null else {},
		"lights": lights.to_dict() if lights != null else {},
		"airlocks": saved_airlocks,
		"items": saved_items,
	}

## The grid a saved ship was built from.
static func layout_of(d: Dictionary) -> ShipGrid:
	return ShipBlueprint.from_dict(d.get("layout", {})).to_grid()

## Puts the hull where the save had it in `universe`, moving as it was. The
## universe's origin must already be near there.
func restore_hull(d: Dictionary, universe: Universe) -> void:
	var hull: Dictionary = d.get("hull", {})
	exterior.global_transform = Transform3D(SaveCodec.to_basis(hull.get("turn")),
		universe.to_engine(SaveCodec.to_upoint(hull.get("at"))))
	exterior.linear_velocity = SaveCodec.to_vec3(hull.get("v"))
	exterior.angular_velocity = SaveCodec.to_vec3(hull.get("w"))
	_last_hull_velocity = exterior.linear_velocity

## Everything aboard as the save had it: flight settings, store, airlocks
## and items. Call after set_grid(layout_of(d), false).
func restore_aboard(d: Dictionary) -> void:
	flight_computer.from_dict(d.get("flight", {}))
	if quantum.store != null:
		quantum.store.from_dict(d.get("store", {}))
	if lights != null:
		lights.from_dict(d.get("lights", {}))
	var saved_airlocks: Dictionary = d.get("airlocks", {})
	for key: String in saved_airlocks:
		var airlock: Airlock = airlocks.get(SaveCodec.to_cell(key))
		if airlock != null:
			airlock.from_dict(saved_airlocks[key])
	for entry in d.get("items", []):
		if entry is Dictionary:
			restore_item(entry)

## One saved item back aboard: in the stow point it was in (the rebuild's
## own RESEAT_TOLERANCE rule), or loose where it was -- on the floor under
## its point if that point has gone (§6.4). Null if its kind has gone.
func restore_item(d: Dictionary) -> Item:
	var item := Item.from_dict(d, item_catalog)
	if item == null:
		return null
	items.add_child(item, true)
	var frame := interior.global_transform
	var place := frame * SaveCodec.to_transform(d.get("place"))
	if String(d.get("state", "")) == "stowed":
		var was := frame * SaveCodec.to_vec3(d.get("point"), place.origin)
		for point in interior_builder.stow_points():
			if point.fits(item) and point.global_position.distance_to(was) < RESEAT_TOLERANCE:
				point.secure(item)
				return item
		place = Transform3D(place.basis, Vector3(was.x, was.y + item.definition.size.y * 0.5, was.z))
	item.set_loose()
	item.global_transform = place
	item.linear_velocity = frame.basis * SaveCodec.to_vec3(d.get("v"))
	item.angular_velocity = frame.basis * SaveCodec.to_vec3(d.get("w"))
	return item

func _apply_stats() -> void:
	exterior.mass = maxf(stats.total_mass_kg, 1.0)
	exterior.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	exterior.center_of_mass = stats.center_of_mass
	exterior.inertia = stats.inertia
	flight_computer.thrust_budget = stats.thrust_budget.duplicate()
	flight_computer.torque_budget = stats.torque_budget
	flight_computer.inertia = stats.inertia
