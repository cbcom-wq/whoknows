class_name Ship
extends GridHome

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
## Every ship is in this group, for things that must find one without being
## given it (the repair torch aimed at a hole).
const GROUP := &"ships"
## How long after a rock strikes the hull a save waits (saving spec §5).
const STRUCK_CALM := 5.0
## How often, and how far past the hull, a hard burn is checked for blasting a
## rock's surface.
const BLAST_EVERY := 0.5
const BLAST_REACH := 50.0
## A crash (health and damage spec §5.2): nothing below CRASH_FROM m/s of
## knock, then CRASH_K × (knock − CRASH_FROM)² on the struck cell and half that
## on each face neighbour, summed into the sections and components they are
## part of. Tuned so 8 m/s nose on takes a third of the struck section (ship
## damage sections spec §3; the crash probe).
const CRASH_FROM := 2.0
const CRASH_K := 5.5
## What a block knocked off the outside sheds, how far out and how fast.
const SHED_ITEM := &"scrap_plate"
const SHED_OUT := 1.4
const SHED_SPEED := 1.0

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
## The ship's damage: six hull sections and four components (ship damage
## sections spec). The grid's per-block damage is its view (_apply_view).
var damage: ShipDamage
## The cabin's look the interior was last built at (ShipDamage.cabin_level).
var _cabin_level := 0
var stats: ShipStats
## The RCS thrusters you see and hear (flight controls spec §6). On the hull,
## so the floating origin carries it.
var rcs_show: RcsShow
## The work lights (ship exterior spec §6, §7). On the hull, so the floating
## origin carries them; kept across rebuilds, like Airlocks.
var lights: ShipLights
## The warp drive (docs/superpowers/specs/2026-09-28-warp-design.md §5), at
## Ship/Warp. The flight scene binds it to the system; the ship only builds it
## and saves its chart.
var warp: WarpDrive

## Seconds since a rock last struck the hull.
var since_struck := INF
## When anything aboard last took damage (health and damage spec §10).
var damage_log := DamageLog.new()
## Sparks, bursts and chunks on the hull (health and damage spec §9).
var damage_show: DamageShow
var _rebuild_queued := false

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
	_setup_home()
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
	warp.computer = func() -> int:
		return damage.component_stage(&"computer") if damage != null else BlockDamage.Stage.INTACT
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
		var cockpit := damage.component_stage(&"cockpit") if damage != null else BlockDamage.Stage.INTACT
		return [hull_whole(), stats.crippled_reason if stats != null else "",
			cockpit == BlockDamage.Stage.WRECKED, mini(int(cockpit), 2)]

func _process(delta: float) -> void:
	# hull_livery.gdshader paints its stripe from ship-local height (GridHome
	# pushes this hull's inverse transform every frame; see
	# hull_livery.gdshader's header comment for why).
	super(delta)
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
			_deal_crash.call_deferred(cell, amount, at.x - ShipGrid.cell_center(cell).x)
		return

func _deal_crash(cell: Vector3i, amount: float, side_x := 0.0) -> void:
	var hits := {cell: amount}
	var sides := {cell: side_x}
	for n in grid.neighbours(cell):
		if grid.has_block(n):
			hits[n] = amount * 0.5
			sides[n] = side_x
	take_damage_many(hits, sides)

## hp a crash with this knock (the hull's change of speed, m/s) deals to the
## cell it lands on.
static func crash_damage(knock: float) -> float:
	if knock <= CRASH_FROM:
		return 0.0
	return CRASH_K * (knock - CRASH_FROM) * (knock - CRASH_FROM)

## A hit on the hull, in world space (a bolt from a spacewalk, a bite).
func _on_hull_hit(hit: Hit) -> void:
	var at := exterior.to_local(hit.position)
	var cell := ShipCells.hull_cell(grid, exterior, hit.shape, at, exterior.global_basis.inverse() * hit.normal)
	if cell != ShipCells.NONE:
		take_damage_many({cell: hit.damage}, {cell: at.x - ShipGrid.cell_center(cell).x})

## A hit on an interior surface: the block behind it (spec §5.1), and a hull
## block's section on the side the shot landed (ship damage sections spec §3).
func _on_interior_hit(hit: Hit) -> void:
	var at := interior.to_local(hit.position)
	var cell := ShipCells.interior_cell(grid, at, interior.global_basis.inverse() * hit.normal)
	if cell != ShipCells.NONE:
		take_damage_many({cell: hit.damage}, {cell: at.x - InteriorBuilder.interior_center(cell).x})

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

## What a ray on `collider` (world point and normal) landed on, for the torch
## (ship damage sections spec §6): {part, cell, outside} -- the section or
## component, the block, and whether it was the hull from outside -- or {}.
func part_hit(collider: Object, shape: int, at: Vector3, normal: Vector3) -> Dictionary:
	var cell := cell_hit(collider, shape, at, normal)
	if cell == ShipCells.NONE or damage == null:
		return {}
	var outside := collider == exterior
	var across := exterior.to_local(at).x - ShipGrid.cell_center(cell).x if outside \
		else interior.to_local(at).x - InteriorBuilder.interior_center(cell).x
	var part := damage.part_of(cell, across)
	return {} if part == &"" else {"part": part, "cell": cell, "outside": outside}

## The first cell along a ray (world, `reach` m) that has no block now but had
## one at launch, beside a block that is still there: a piece knocked off,
## which the torch mends as its section. Looked for in the hull's frame, a
## quarter metre at a time. ShipCells.NONE if there is none.
func missing_cell_along(from: Vector3, dir: Vector3, reach: float) -> Vector3i:
	var steps := ceili(reach / 0.25)
	for i in range(1, steps + 1):
		var cell := Vector3i((exterior.to_local(from + dir * (reach * i / steps)) / ShipGrid.CELL_SIZE).round())
		if _missing(cell):
			return cell
	return ShipCells.NONE

func _missing(cell: Vector3i) -> bool:
	if grid.has_block(cell) or launch_block(cell).is_empty():
		return false
	for n in ShipGrid.FACE_OFFSETS:
		if grid.has_block(cell + n):
			return true
	return false

## Mends `share` (0..1) of a hull section; returns the share it used. Pieces
## come back as it rises.
func repair_section(section: StringName, share: float) -> float:
	var used := damage.repair_section(section, share)
	if used > 0.0:
		_apply_view()
	return used

## Mends up to `hp` of a component; returns what it used.
func repair_component(comp: StringName, hp: float) -> float:
	var used := damage.repair_component(comp, hp)
	if used > 0.0:
		_apply_view()
	return used

## What the torch's prompt says of a part: "PORT BOW HULL · 45% H" for a
## section, "ENGINES · 40% H · DAMAGED" for a component.
func part_label(part: StringName) -> String:
	var left := roundi(damage.part_health(part) * 100.0)
	if damage.is_section(part):
		return "%s HULL · %d%% H" % [damage.label(part), left]
	var stage: String = BlockDamage.Stage.keys()[damage.component_stage(part)]
	return "%s · %d%% H · %s" % [damage.label(part), left, stage]

## How whole the hull is, 0..1: its six sections' health, weighted by their
## hp (ship damage sections spec §2.1). The HUD band's HULL %.
func hull_whole() -> float:
	return damage.hull_whole() if damage != null else 1.0

## How much the block at `cell` has to mend, hp.
func damage_at(cell: Vector3i) -> float:
	var inst := grid.get_block(cell)
	return inst.damage if inst != null else 0.0

## Deals `amount` to whatever the block at `cell` is part of (ship damage
## sections spec §3). Returns what it knocked off.
func take_damage(cell: Vector3i, amount: float) -> Array[Vector3i]:
	return take_damage_many({cell: amount})

## Deals every hit in `hits` (cell -> amount) together to the sections and
## components they land on, a centre-line block's to the side `sides` (cell ->
## the hit's offset across the ship from the cell's centre) says. Then the
## grid shows it: pieces lost go in one rebuild. Returns them.
func take_damage_many(hits: Dictionary, sides: Dictionary = {}) -> Array[Vector3i]:
	var landed := false
	for cell: Vector3i in hits:
		if cell != ShipCells.NONE and hits[cell] > 0.0 and grid.has_block(cell):
			landed = damage.hit(cell, hits[cell], float(sides.get(cell, 0.0))) or landed
	if not landed:
		var none: Array[Vector3i] = []
		return none
	damage_log.note()
	return _apply_view()

## Writes the damage model into the grid (spec §4): each block's damage is
## what its section or component shows, a piece lost is removed and one
## welded back is put back, all in one grid change. `quiet` (set_grid, before
## the signals are connected) only writes. Returns the pieces removed, after
## their burst, plate and blocks_lost.
func _apply_view(quiet := false) -> Array[Vector3i]:
	var lost := damage.lost()
	var remove: Array[Vector3i] = []
	var add := {}
	var staged := {}
	for coord: Vector3i in damage.launch:
		var inst := grid.get_block(coord)
		var shown := damage.shown_damage(coord)
		var hp: float = damage.launch[coord][2]
		if lost.has(coord):
			if inst != null:
				remove.append(coord)
			continue
		if inst == null:
			inst = BlockInstance.new()
			inst.block_id = damage.launch[coord][0]
			inst.orientation = damage.launch[coord][1]
			inst.damage = shown
			add[coord] = inst
			continue
		var before := BlockDamage.stage_at(inst.damage, hp)
		inst.damage = shown
		var after := BlockDamage.stage_at(shown, hp)
		if after != before:
			staged[coord] = after
	if quiet:
		grid.replace_many(remove, add)
		return remove
	for coord: Vector3i in staged:
		grid.note_staged(coord, staged[coord])
	if ShipDamage.cabin_level(damage.hull_whole()) != _cabin_level:
		_queue_rebuild()   # the cabin's look follows HULL % (spec §5)
	if not remove.is_empty() or not add.is_empty():
		grid.replace_many(remove, add)
	if not remove.is_empty():
		damage_show.lost(remove)
		_shed_plate(remove)
		blocks_lost.emit(remove)
	return remove

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

## A block crossed a stage (spec §4.3): what it can do changed, and nothing
## else did. The stats follow; no geometry is rebuilt.
func _on_block_staged(coord: Vector3i, stage: int) -> void:
	exterior_builder.set_stage(coord, stage)
	damage_show.stage(grid, coord, stage)
	if damage == null or not damage.component_of.has(coord):
		return   # a hull block's stage is looks only (ship damage sections spec §2.3)
	_apply_cockpit()
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

## True while it is spooling or travelling at warp: no airlock works then.
func is_warping() -> bool:
	return warp != null and warp.is_spinning()

## True while the camera you see through is aboard.
func _aboard() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and interior.is_ancestor_of(cam)

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
	var layout := launch_blueprint.to_grid()
	inner_cells = inner_of(layout, catalog)
	# The model reads what the grid's blocks have taken (a new ship: nothing;
	# a save from before sections: its block damage), then the grid shows it,
	# which puts back any block the sections say is there.
	damage = ShipDamage.build(layout, catalog, inner_cells)
	damage.infer(grid)
	_apply_view(true)
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
	_cabin_level = ShipDamage.cabin_level(hull_whole())
	interior_builder.hull_wear = _cabin_level
	interior_builder.hull_flicker = _cabin_level == 2
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
	_apply_cockpit()
	if rcs_show != null:
		rcs_show.rebuild(grid, catalog, stats.center_of_mass)
	stats_changed.emit(stats)
	if damage_show != null:
		damage_show.sync(grid, catalog)
		damage_show.cabin(_cabin_level, _cabin_walls())
	_set_anchor_radius()
	_bind_crew()
	_apply_own()
	_apply_livery()

## The cockpit's stage reaches the helm (ship damage sections spec §2.2):
## damaged, the assist chases at half strength; wrecked, it is off and refused.
## The cracks and the HUD's flicker go by hull_status to the HUD.
func _apply_cockpit() -> void:
	var stage := damage.component_stage(&"cockpit") if damage != null else BlockDamage.Stage.INTACT
	flight_computer.assist_strength = 0.5 if stage == BlockDamage.Stage.DAMAGED else 1.0
	flight_computer.assist_allowed = stage != BlockDamage.Stage.WRECKED

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
		context.damage = damage
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

# --- saving (docs/superpowers/specs/2026-09-26-saving-design.md §3, §6) ------

## Why a save must wait (§5), or "": a rock struck the hull lately, something
## aboard was hurt lately, or anything GridHome waits on.
func busy() -> String:
	if since_struck < STRUCK_CALM:
		return "hull struck"
	var hurt := damage_log.busy()
	if hurt != "":
		return hurt
	return home_busy()

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
	var saved_items := items_to_dict()
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
		"damage": damage.to_dict() if damage != null else {},
		"lights": lights.to_dict() if lights != null else {},
		"airlocks": saved_airlocks,
		"items": saved_items,
	}

## The cabin's shell that sparks can spit from, in a fixed order: its blocks
## that are not walked on.
func _cabin_walls() -> Array:
	var walk := interior_builder.walkable_coords()
	var out: Array = []
	for coord: Vector3i in inner_cells:
		if grid.has_block(coord) and not walk.has(coord):
			out.append(coord)
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return hash(a) < hash(b))
	return out

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
	if d.has("damage") and damage != null:
		damage.from_dict(d["damage"])
		_apply_view()
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

func _apply_stats() -> void:
	exterior.mass = maxf(stats.total_mass_kg, 1.0)
	exterior.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	exterior.center_of_mass = stats.center_of_mass
	exterior.inertia = stats.inertia
	flight_computer.thrust_budget = stats.thrust_budget.duplicate()
	flight_computer.torque_budget = stats.torque_budget
	flight_computer.inertia = stats.inertia
