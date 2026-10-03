class_name Ship
extends Node3D

## Owns one ship's grid and both representations of it. The grid is the
## source of truth; everything else here reacts to `cell_changed`.

signal stats_changed(stats: ShipStats)
## Blocks knocked off, and any piece cut off with them (health and damage spec
## §4.5), already gone from the grid: for the burst and the shed plate.
signal blocks_lost(coords: Array[Vector3i])
## A block knocked off the outside shed a scrap plate (health and damage spec
## §8.1): already outside, in space and in EXTERIOR_SPACE. The flight scene
## makes it a stray.
signal plate_shed(item: Item)
## Someone crossed one of its airlocks' outer hatches (airlock spec §7):
## `outward` true out onto a spacewalk, false in, aboard (many ships spec §4.3).
signal airlock_crossed(avatar: Avatar, outward: bool)

const INTERIOR_WORLD_BASE := Vector3(0.0, -5000.0, 0.0)
## Every ship is in this group, for things that must find one without being
## given it (the repair torch aimed at a hole).
const GROUP := &"ships"
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
## A crash (health and damage spec §5.2): nothing below CRASH_FROM m/s of
## knock, then CRASH_K × (knock − CRASH_FROM)² on the struck cell and half that
## on each face neighbour. First values for the feel pass.
const CRASH_FROM := 2.0
const CRASH_K := 12.0
## What a block knocked off the outside sheds, how far out and how fast.
const SHED_ITEM := &"scrap_plate"
const SHED_OUT := 1.4
const SHED_SPEED := 1.0
## Where you wake after blacking out, if the ship has one.
const WAKE_ROOM := &"bunk_room"

## The livery every builder paints the hull with: one shared instance. Each
## ship swaps it for its own copy, `livery` (_apply_livery).
const HULL_LIVERY_MATERIAL: ShaderMaterial = preload("res://data/materials/hull_livery.tres")
## The window glass's shader; each ship makes its own material from it.
const CANOPY_SHADER: Shader = preload("res://data/materials/interior/canopy_window.gdshader")
## Marks a hull piece made for the own layer alone, so set_own can move it
## back.
const OWN_ONLY := &"own_only"

@export var interior_slot: int = 0
## Where a spacewalker goes (airlock spec §7.4): the scene's root for things in
## the real world that are not the ship.
@export var outside_path: NodePath

var grid: ShipGrid
## The layout the ship launched with, nothing hurt (health and damage spec
## §8.2): what the repair torch puts back where a block was knocked off. Set
## by the first grid the ship is given, or by a save; a rebuild never
## changes it.
var launch_blueprint: ShipBlueprint
## The cabin's shell (health and damage spec §4.5, as amended 2026-10-02):
## every walkable cell of the launch layout and every block that walls, floors
## or roofs one. Damage wrecks these but never knocks them off, so the inside
## keeps its shape; only the buffer outside them breaks away. coord -> true.
var inner_cells := {}
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
## The warp drive (docs/superpowers/specs/2026-09-28-warp-design.md §5), at
## Ship/Warp. The flight scene binds it to the system; the ship only builds it
## and saves its chart.
var warp: WarpDrive
## True for the ship you are aboard (many ships spec §4.2): the hull's own
## pieces are drawn on ExteriorBuilder.OWN_HULL_LAYER, which your canopy and
## windows leave out, and the interior shows. Any other ship draws them on
## layer 1, so you see it through your windows, and hides its interior, which
## nobody can see from outside. A ship is your own until told otherwise.
var own := true
## This ship's own copy of the hull livery (_apply_livery).
var livery: ShaderMaterial = HULL_LIVERY_MATERIAL.duplicate()

## Seconds since a rock last struck the hull.
var since_struck := INF
## When anything aboard last took damage (health and damage spec §10).
var damage_log := DamageLog.new()
## Sparks, bursts and chunks on the hull (health and damage spec §9).
var damage_show: DamageShow
var _rebuild_queued := false

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
## The parts of ship.tscn the flight scene hands you between (many ships spec
## §3.1).
@onready var pilot: PilotControls = $PilotControls
@onready var seat: PilotSeat = $Interior/PilotSeat
@onready var motion: MotionCoupling = $MotionCoupling
@onready var chase_camera: Camera3D = $Exterior/ChaseCamera
@onready var canopy_camera: Camera3D = $Canopy/CanopyCam
@onready var canopy_overlay: Control = $Canopy/CanopyOverlay

func _ready() -> void:
	_make_canopy_material()
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
	damage_show = DamageShow.new()
	damage_show.name = "DamageShow"
	exterior.add_child(damage_show)
	damage_show.setup(exterior, outside, interior, _inside_face)
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
	warp = WarpDrive.new()
	warp.name = "Warp"
	warp.hull = exterior
	warp.plant = quantum
	warp.flight_computer = flight_computer
	add_child(warp)
	flight_computer.warp = warp
	quantum.warp = warp
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
	# The hull is a scriptless RigidBody3D: hits reach it through meta
	# (health and damage spec §3).
	exterior.set_meta(&"receive_hit", _on_hull_hit)
	exterior.set_meta(&"ship", self)
	add_to_group(GROUP)
	flight_computer.hull_status = func() -> Array:
		return [hull_whole(), stats.crippled_reason if stats != null else ""]

## Every window's glass shows this ship's own canopy view (cockpit pod spec
## §3): one material per ship, fed by its own SubViewport, so each instance of
## ship.tscn draws its own (many ships spec §3.1). Made here rather than in the
## .tscn: a ViewportTexture's path inside an instanced scene is fragile.
func _make_canopy_material() -> void:
	var canopy := get_node_or_null("Canopy") as SubViewport
	if canopy == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = CANOPY_SHADER
	mat.set_shader_parameter(&"canopy_view", canopy.get_texture())
	interior_builder.canopy_material = mat

func _process(_delta: float) -> void:
	# hull_livery.gdshader paints its stripe from ship-local height, but the
	# skin's merged plating meshes (HullDressing: the Hull and Windows kits'
	# HULL batches, built in hull space) are drawn with a MODEL_MATRIX that is
	# model-to-*world* -- it carries the hull RigidBody3D's own rotation.
	# Pushing the hull's inverse transform every frame lets the shader cancel
	# that rotation (`hull_inverse * MODEL_MATRIX`) before testing height, so
	# the stripe stays fixed on the hull under roll and pitch instead of
	# swimming across it. See hull_livery.gdshader's header comment for the
	# full derivation. Each ship pushes its own hull's into its own copy: one
	# shared material would hold only the last ship's (many ships, §12).
	livery.set_shader_parameter(&"hull_inverse", exterior.global_transform.affine_inverse())
	_update_hum()

## Every hull piece painted with the shared livery gets this ship's own copy:
## the stripe is measured through `hull_inverse`, which is this hull's alone.
## After every rebuild, as the builders always paint with the shared one.
func _apply_livery() -> void:
	for node in exterior.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g.material_override == HULL_LIVERY_MATERIAL:
			g.material_override = livery

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
	damage_log.tick(delta)
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
	_crash(body, knock)

## Crash damage (spec §5.2) on the cell the contact is on. Worked out now,
## while the contact is reported, and dealt after the physics step: a removal
## rebuilds the hull's colliders, which can't change while it is flushing.
func _crash(body: Node, knock: float) -> void:
	var amount := crash_damage(knock)
	if amount <= 0.0:
		return
	var state := PhysicsServer3D.body_get_direct_state(exterior.get_rid())
	if state == null:
		return
	for i in state.get_contact_count():
		if state.get_contact_collider_object(i) != body:
			continue
		var at := exterior.to_local(state.get_contact_local_position(i))
		var normal := exterior.global_basis.inverse() * state.get_contact_local_normal(i)
		var cell := ShipCells.hull_cell(grid, exterior, state.get_contact_local_shape(i), at, normal)
		if cell != ShipCells.NONE:
			_deal_crash.call_deferred(cell, amount)
		return

func _deal_crash(cell: Vector3i, amount: float) -> void:
	var hits := {cell: amount}
	for n in grid.neighbours(cell):
		if grid.has_block(n):
			hits[n] = amount * 0.5
	take_damage_many(hits)

## hp a crash with this knock (the hull's change of speed, m/s) deals to the
## cell it lands on.
static func crash_damage(knock: float) -> float:
	if knock <= CRASH_FROM:
		return 0.0
	return CRASH_K * (knock - CRASH_FROM) * (knock - CRASH_FROM)

## A hit on the hull, in world space (a bolt from a spacewalk, a bite).
func _on_hull_hit(hit: Hit) -> void:
	var cell := ShipCells.hull_cell(grid, exterior, hit.shape, exterior.to_local(hit.position),
		exterior.global_basis.inverse() * hit.normal)
	take_damage(cell, hit.damage)

## A hit on an interior surface: the block behind it (spec §5.1).
func _on_interior_hit(hit: Hit) -> void:
	var cell := ShipCells.interior_cell(grid, interior.to_local(hit.position),
		interior.global_basis.inverse() * hit.normal)
	take_damage(cell, hit.damage)

# --- mending (health and damage spec §8) -----------------------------------------

## The cell of this ship a ray hit on `collider` landed on (world point and
## normal), or ShipCells.NONE: the hull or the interior, as for damage.
func cell_hit(collider: Object, shape: int, at: Vector3, normal: Vector3) -> Vector3i:
	if collider == exterior:
		return ShipCells.hull_cell(grid, exterior, shape, exterior.to_local(at),
			exterior.global_basis.inverse() * normal)
	if collider == interior_builder.geometry_body():
		return ShipCells.interior_cell(grid, interior.to_local(at), interior.global_basis.inverse() * normal)
	return ShipCells.NONE

## The first cell along a ray (world, `reach` m) that has no block now but had
## one at launch, beside a block that is still there: a hole the torch can
## rebuild. Looked for from outside (the hull's frame) and aboard (the
## interior's), a quarter metre at a time. ShipCells.NONE if there is none.
func missing_cell_along(from: Vector3, dir: Vector3, reach: float) -> Vector3i:
	var steps := ceili(reach / 0.25)
	for i in range(1, steps + 1):
		var p := from + dir * (reach * i / steps)
		for cell in [Vector3i((exterior.to_local(p) / ShipGrid.CELL_SIZE).round()),
				ShipCells.interior_cell_at(interior.to_local(p))]:
			if _rebuildable(cell):
				return cell
	return ShipCells.NONE

func _rebuildable(cell: Vector3i) -> bool:
	if grid.has_block(cell) or launch_block(cell).is_empty():
		return false
	for n in ShipGrid.FACE_OFFSETS:
		if grid.has_block(cell + n):
			return true
	return false

## Mends up to `hp` of the block at `cell`; returns what it used.
func repair_cell(cell: Vector3i, hp: float) -> float:
	var was := _flickering([cell])
	var used := BlockDamage.repair(grid, catalog, cell, hp)
	_reflicker(was)
	return used

## Puts back, wrecked, what the ship launched with at `cell` (§8.2).
func rebuild_cell(cell: Vector3i) -> bool:
	if not _rebuildable(cell):
		return false
	var was := launch_block(cell)
	BlockDamage.rebuild(grid, catalog, cell, was[0], was[1])
	return true

## What the torch's prompt says of the block at `cell`: its name and state,
## as "HULL PLATE · 0% H · WRECKED" (health left, then the stage), or of a
## hole, "REBUILD THRUSTER".
func cell_label(cell: Vector3i) -> String:
	var inst := grid.get_block(cell)
	if inst == null:
		var was := launch_block(cell)
		var gone := catalog.get_def(was[0]) if not was.is_empty() else null
		return "REBUILD %s" % gone.display_name.to_upper() if gone != null else ""
	var def := catalog.get_def(inst.block_id)
	if def == null:
		return ""
	var stage: String = BlockDamage.Stage.keys()[BlockDamage.stage_of(inst, def)]
	var left := clampf(1.0 - inst.damage / float(def.hp), 0.0, 1.0)
	return "%s · %d%% H · %s" % [def.display_name.to_upper(), roundi(left * 100.0), stage]

## How whole the hull is, 0..1, against the layout it launched with (health
## and damage spec §11): every block's damage, capped at its hp, and a block
## knocked off counts as all of it.
func hull_whole() -> float:
	if launch_blueprint == null:
		return 1.0
	var total := 0.0
	var lost := 0.0
	for i in launch_blueprint.coords.size():
		var def := catalog.get_def(launch_blueprint.block_ids[i])
		if def == null:
			continue
		total += def.hp
		var inst := grid.get_block(launch_blueprint.coords[i])
		lost += def.hp if inst == null else minf(inst.damage, def.hp)
	return 1.0 - lost / total if total > 0.0 else 1.0

## How much the block at `cell` has to mend, hp.
func damage_at(cell: Vector3i) -> float:
	var inst := grid.get_block(cell)
	return inst.damage if inst != null else 0.0

## Deals `amount` to the block at `cell` (health and damage spec §4). Returns
## what it knocked off.
func take_damage(cell: Vector3i, amount: float) -> Array[Vector3i]:
	return take_damage_many({cell: amount})

## Deals every hit in `hits` (cell -> amount) together: one rebuild for all
## that goes.
func take_damage_many(hits: Dictionary) -> Array[Vector3i]:
	var real := {}
	for cell: Vector3i in hits:
		if cell != ShipCells.NONE and hits[cell] > 0.0 and grid.has_block(cell):
			real[cell] = hits[cell]
	if real.is_empty():
		var none: Array[Vector3i] = []
		return none
	damage_log.note()
	var was := _flickering(real.keys())
	var removed := BlockDamage.apply_many(grid, catalog, real, inner_cells)
	_reflicker(was)
	if not removed.is_empty():
		damage_show.lost(removed)
		_shed_plate(removed)
		blocks_lost.emit(removed)
	return removed

## Of `cells`, those seen from inside, each with whether its ceiling light
## would flicker now (BlockDamage.flickers).
func _flickering(cells: Array) -> Dictionary:
	var out := {}
	for cell: Vector3i in cells:
		if interior_builder.shows(cell):
			var inst := grid.get_block(cell)
			out[cell] = inst != null and BlockDamage.flickers(inst, catalog.get_def(inst.block_id))
	return out

## A light starts or stops flickering partway through a stage, which no
## block_staged reports: the interior is rebuilt for it, once, at the end of
## the frame, as for a stage seen from inside.
func _reflicker(was: Dictionary) -> void:
	for cell: Vector3i in was:
		var inst := grid.get_block(cell)
		if inst == null:
			continue
		if BlockDamage.flickers(inst, catalog.get_def(inst.block_id)) != was[cell]:
			_queue_rebuild()
			return

## One scrap plate from the first block knocked off, if it had a face onto
## space: it drifts out from that face at SHED_SPEED (spec §8.1).
func _shed_plate(removed: Array[Vector3i]) -> void:
	var def := item_catalog.get_def(SHED_ITEM) if item_catalog != null else null
	if def == null or outside == null or not exterior.is_inside_tree():
		return
	var cell := removed[0]
	for n in ShipGrid.FACE_OFFSETS:
		if grid.has_block(cell + n) or removed.has(cell + n):
			continue
		var item := Item.new()
		item.setup(def, fposmod(float(hash(cell)) * 0.001, 1.0))
		item.set_space(true)
		outside.add_child(item, true)
		item.add_to_group(Universe.EXTERIOR_SPACE)
		var out := exterior.global_basis * Vector3(n)
		item.global_position = exterior.to_global(ShipGrid.cell_center(cell) + Vector3(n) * SHED_OUT)
		item.linear_velocity = exterior.linear_velocity + out * SHED_SPEED
		item.set_loose()
		plate_shed.emit(item)
		return

## Where you wake after blacking out (health and damage spec §7.2), best
## first, in the world: the bunk room's cells, then the rest by how near they
## are to it (or to the core, with no bunk room); never the airlock. The
## caller takes the first you fit: a bunk room is mostly bunks, so that is
## often the cell at its door.
func wake_spots() -> Array[Transform3D]:
	var layout := interior_builder.layout()
	var core := Vector3.ZERO
	for coord: Vector3i in grid.coords():
		if grid.get_block(coord).block_id == BlockDamage.CORE:
			core = Vector3(coord)
	var bunks: Array[Vector3i] = []
	var rest: Array[Vector3i] = []
	for cell: Vector3i in interior_builder.walkable_coords():
		var zone := layout.zone_at(cell) if layout != null else &""
		if zone == InteriorLayout.AIRLOCK_ZONE:
			continue
		if zone == WAKE_ROOM:
			bunks.append(cell)
		else:
			rest.append(cell)
	var near := Vector3(bunks[0]) if not bunks.is_empty() else core
	rest.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector3(a).distance_to(near) < Vector3(b).distance_to(near))
	var out: Array[Transform3D] = []
	for cell in bunks + rest:
		out.append(interior.global_transform * Transform3D(Basis.IDENTITY, DeckPaths.floor_point(cell)))
	return out

## A block crossed a stage (spec §4.3): what it can do changed, and nothing
## else did. The stats follow; no geometry is rebuilt.
func _on_block_staged(coord: Vector3i, stage: int) -> void:
	exterior_builder.set_stage(coord, stage)
	damage_show.stage(grid, coord, stage)
	if interior_builder.shows(coord):
		# The dressing is merged meshes, so one cell can't be recoloured: the
		# ship is rebuilt, once, at the end of the frame (as built, spec §4.3).
		_queue_rebuild()
	stats = ShipStats.compute(grid, catalog)
	_apply_stats()
	if quantum != null and quantum.store != null:
		quantum.store.set_capacity(stats.quantum_capacity, stats.intact_quantum_capacity)
	stats_changed.emit(stats)

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

func set_own(on: bool) -> void:
	own = on
	_apply_own()

## Every piece the builders made for the own layer alone goes on the layer
## `own` says; pieces on both layers stay on both. After every rebuild too: the
## builders always make the own layer.
func _apply_own() -> void:
	interior.visible = own
	for node in exterior.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g.layers == ExteriorBuilder.OWN_HULL_LAYER:
			g.set_meta(OWN_ONLY, true)
		if g.has_meta(OWN_ONLY):
			g.layers = ExteriorBuilder.OWN_HULL_LAYER if own else 1

func load_blueprint(bp: ShipBlueprint) -> void:
	set_grid(bp.to_grid())

## Builds the ship from `new_grid`. `stock` false leaves the shelves empty --
## a loaded game brings its own items (saving spec §6.1).
func set_grid(new_grid: ShipGrid, stock := true) -> void:
	if not stock:
		_stocked = true
	if grid != null and grid.cell_changed.is_connected(_on_cell_changed):
		grid.cell_changed.disconnect(_on_cell_changed)
		grid.block_staged.disconnect(_on_block_staged)
	grid = new_grid
	if launch_blueprint == null:
		launch_blueprint = unhurt(ShipBlueprint.from_grid(grid, String(name)))
	inner_cells = inner_of(launch_blueprint.to_grid(), catalog)
	_restore_shell(grid)
	grid.cell_changed.connect(_on_cell_changed)
	grid.block_staged.connect(_on_block_staged)
	exterior_builder.bind(grid, catalog)
	interior_builder.bind(grid, catalog)
	_rebuild_everything()

func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_queued_now.call_deferred()

## A stage seen from inside: the interior is rebuilt to restyle it; the hull
## already recoloured in place, so it is left standing (about 85 of a full
## rebuild's 210 ms on the dev Xeon).
func _rebuild_queued_now() -> void:
	if not _rebuild_queued:
		return
	_rebuild_everything(false)

func _on_cell_changed(_coord: Vector3i) -> void:
	# Slice 1 rebuilds wholesale on any change. At 150 blocks this is well
	# under a frame. Incremental per-cell rebuild is a Slice 2 optimisation
	# for when weapons start destroying blocks every few milliseconds.
	_rebuild_everything()

## Rebuilds both representations from the grid; `hull` false keeps the
## exterior as it is (only the interior's look changed).
func _rebuild_everything(hull := true) -> void:
	_rebuild_queued = false
	_save_computers()
	var stowed := _stowed_items()
	if hull:
		exterior_builder.rebuild()
	interior_builder.rebuild()
	_place_seat()
	interior_builder.geometry_body().set_meta(&"receive_hit", _on_interior_hit)
	interior_builder.geometry_body().set_meta(&"ship", self)
	_bind_airlocks()
	_reseat(stowed)
	if not _stocked:
		_stock()
		_stocked = true
	stats = ShipStats.compute(grid, catalog)
	_apply_stats()
	quantum.bind(interior_builder.quantum_cores(), interior_builder.quantum_machines(), stats)
	flight_computer.quantum = quantum.store
	for lid in interior_builder.toilet_lids():
		lid.bind(quantum.store)
	if lights != null:
		lights.bind(exterior_builder.light_mounts(), exterior_builder.lenses(), exterior_builder.window_glow())
		for panel in interior_builder.lights_panels():
			panel.bind(lights)
	_bind_computers()
	if rcs_show != null:
		rcs_show.rebuild(grid, catalog, stats.center_of_mass)
	stats_changed.emit(stats)
	if damage_show != null:
		damage_show.sync(grid, catalog)
	_set_anchor_radius()
	_bind_crew()
	_apply_own()
	_apply_livery()

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
		context.warp = warp
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
			airlock.crossed.connect(airlock_crossed.emit)
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
	var hurt := damage_log.busy()
	if hurt != "":
		return hurt
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
## it moves, its flight settings, its store, its warp chart, its lights, its
## airlocks and every item aboard that is not in someone's hand. During a warp
## the hull is saved at the drop-out point, moving in (the warp spec §5.5).
func to_dict(universe: Universe) -> Dictionary:
	var hull := exterior.global_transform
	var place := warp.arrival() if warp != null else {}
	var hull_at: UniversePoint = place.get("at", universe.to_universe(hull.origin))
	var hull_turn: Basis = place.get("turn", hull.basis)
	var hull_v: Vector3 = place.get("v", exterior.linear_velocity)
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
		"launch": launch_blueprint.to_dict() if launch_blueprint != null else {},
		"hull": {
			"at": SaveCodec.upoint(hull_at),
			"turn": SaveCodec.basis(hull_turn),
			"v": SaveCodec.vec3(hull_v),
			"w": SaveCodec.vec3(Vector3.ZERO if not place.is_empty() else exterior.angular_velocity),
		},
		"warp": warp.to_dict() if warp != null else {},
		"flight": flight_computer.to_dict(),
		"store": quantum.store.to_dict() if quantum.store != null else {},
		"lights": lights.to_dict() if lights != null else {},
		"airlocks": saved_airlocks,
		"items": saved_items,
	}

## Where a block's damage shows in the cabin (DamageShow): a point on the
## cabin side of its wall, floor or roof, interior-local, or null if no
## walkable cell is beside it.
func _inside_face(coord: Vector3i) -> Variant:
	var walk := interior_builder.walkable_coords()
	for n: Vector3i in ShipGrid.FACE_OFFSETS:
		var cell := coord + n
		if not walk.has(cell):
			continue
		var toward := -Vector3(n)
		return InteriorBuilder.interior_center(cell) + toward * Vector3(
			ShipGrid.CELL_SIZE * 0.5 - 0.08, InteriorBuilder.STOREY_HEIGHT * 0.5 - 0.15,
			ShipGrid.CELL_SIZE * 0.5 - 0.08)
	return null

## The cabin's shell of `layout`: its walkable cells and every block beside
## one. coord -> true.
static func inner_of(layout: ShipGrid, blocks: BlockCatalog) -> Dictionary:
	var out := {}
	for cell: Vector3i in DeckGraph.build(layout, blocks).walkable_coords():
		out[cell] = true
		for n in ShipGrid.FACE_OFFSETS:
			if layout.has_block(cell + n):
				out[cell + n] = true
	return out

## Puts back, wrecked, any block of the cabin's shell missing from `g`: a
## save from before the shell was held could have lost some, leaving a cabin
## you can't get round. Before any signal is connected, so no rebuild yet.
func _restore_shell(g: ShipGrid) -> int:
	var put := 0
	for i in launch_blueprint.coords.size():
		var cell := launch_blueprint.coords[i]
		if not inner_cells.has(cell) or g.has_block(cell):
			continue
		var def := catalog.get_def(launch_blueprint.block_ids[i])
		if def == null:
			continue
		var inst := BlockInstance.new()
		inst.block_id = def.id
		inst.orientation = launch_blueprint.orientations[i]
		inst.damage = float(def.hp) * BlockDamage.WRECKED_AT
		g.set_block(cell, inst)
		put += 1
	return put

## `bp` with every block's damage cleared.
static func unhurt(bp: ShipBlueprint) -> ShipBlueprint:
	for i in bp.damage_values.size():
		bp.damage_values[i] = 0.0
	return bp

## What the ship launched with at `cell`: [block id, orientation], or [] if
## nothing was there.
func launch_block(cell: Vector3i) -> Array:
	if launch_blueprint == null:
		return []
	var i := launch_blueprint.coords.find(cell)
	return [] if i < 0 else [launch_blueprint.block_ids[i], launch_blueprint.orientations[i]]

## The helm's cell, or null with no pilot seat.
func helm_cell() -> Variant:
	for coord: Vector3i in grid.coords():
		if grid.get_block(coord).block_id == InteriorLayout.HELM_ID:
			return coord
	return null

## The helm's seat where the dressing drew the chair (cockpit pod spec §7): its
## collider and eye from the same fixture frame, after every rebuild, so a
## spawned ship's seat stands where the starter's does.
func _place_seat() -> void:
	var helm: Variant = helm_cell()
	if helm != null and seat != null:
		seat.transform = InteriorDressing.fixture_frame(interior_builder.layout(), helm)

## The launch layout a save kept, or, from a save before there was one, its
## layout with nothing hurt.
static func launch_of(d: Dictionary) -> ShipBlueprint:
	return unhurt(ShipBlueprint.from_dict(d.get("launch", d.get("layout", {}))))

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
	warp.from_dict(d.get("warp", {}))
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
