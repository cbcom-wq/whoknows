class_name Base
extends GridHome

## A base (docs/superpowers/specs/2026-09-26-habitat-modules-design.md §9.1):
## a ShipGrid that never flies, built from its BaseSite into a still exterior
## (a frozen RigidBody3D, so everything that asks a hull its velocity hears
## zero) and an interior in its own slot. Its nodes are made in code, the same
## four GridHome expects, plus a canopy view so its portholes show the real
## outside. Bases (the manager) makes one when it wakes and frees it when it
## sleeps; everything that must outlive that goes back into the site first
## (capture).

## Module `index` finished unfolding (§5.3): the base has changed.
signal unfolded(index: int)

var site: BaseSite
## The module unfolding, or -1, and how long it has left.
var unfolding := -1
var unfold_left := 0.0
var exterior_look: BaseExterior
## The hub's link panel (§6.1), rebuilt with the interior; null with no hub.
var link: LinkPanel
## Sparks on a damaged module's shell (ship weapons spec §6.5).
var damage_show: DamageShow

var _stamped := false
## Through the suit (outside is vacuum): the legs' stamp, and the walls folding
## up. Two players, because both start on the same tick and one would cut the
## other off.
var _thud: AudioStreamPlayer3D
var _fold: AudioStreamPlayer3D
## Seconds of play, for the drills (Bases.clock).
var clock: Callable
var _credit_in := 0.0
var _hum_in := 0.0
## The drill heard from inside (§8.5): quieter than the ship's own hum.
var _grind: AudioStreamPlayer

## A base for `p_site` in interior slot `slot`, its outside `p_outside_path`
## (relative to the base), unfolding module `p_unfolding` if not -1. Add it to
## the tree, then place() it.
static func make(p_site: BaseSite, slot: int, p_outside_path: NodePath, p_unfolding := -1) -> Base:
	var b := Base.new()
	b.name = String(p_site.id)
	b.site = p_site
	b.interior_slot = slot
	b.outside_path = p_outside_path
	b.unfolding = p_unfolding
	b.unfold_left = HabitatValues.UNFOLD if p_unfolding >= 0 else 0.0
	var ext := RigidBody3D.new()
	ext.name = "Exterior"
	b.add_child(ext)
	var eb := ExteriorBuilder.new()
	eb.name = "ExteriorBuilder"
	eb.body_path = NodePath("..")
	ext.add_child(eb)
	var inside := Node3D.new()
	inside.name = "Interior"
	b.add_child(inside)
	var ib := InteriorBuilder.new()
	ib.name = "InteriorBuilder"
	inside.add_child(ib)
	var canopy := SubViewport.new()
	canopy.name = "Canopy"
	canopy.size = Vector2i(1536, 512)
	canopy.render_target_update_mode = SubViewport.UPDATE_DISABLED
	b.add_child(canopy)
	var cam := Camera3D.new()
	cam.name = "CanopyCam"
	cam.current = true
	cam.cull_mask = 1
	cam.fov = 40.0
	canopy.add_child(cam)
	var portal := CanopyPortal.new()
	portal.name = "CanopyPortal"
	portal.viewport_path = NodePath("../Canopy")
	portal.camera_path = NodePath("../Canopy/CanopyCam")
	portal.hull_path = NodePath("../Exterior")
	portal.interior_path = NodePath("../Interior")
	b.add_child(portal)
	return b

func _ready() -> void:
	_setup_home()
	_stocked = true   # nothing to stock: a base's rooms start bare
	exterior.gravity_scale = 0.0
	exterior.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	exterior.freeze = true
	exterior.collision_layer = 1   # exterior_hull
	exterior.collision_mask = 0
	exterior.add_to_group(Universe.EXTERIOR_SPACE)
	exterior.add_to_group(AsteroidStream.SPACE_ANCHOR)
	exterior.set_meta(&"base", self)
	exterior.set_meta(&"receive_hit", _on_hull_hit)
	Weapons.join(exterior, Weapons.base_id(site.id))
	quantum = QuantumPlant.new()
	quantum.name = "Quantum"
	quantum.items = items
	quantum.item_catalog = item_catalog
	quantum.start_fraction = 0.0
	quantum.can_make = false
	add_child(quantum)
	exterior_look = BaseExterior.new()
	exterior_look.name = "BaseExterior"
	exterior.add_child(exterior_look)
	damage_show = DamageShow.new()
	damage_show.name = "DamageShow"
	exterior.add_child(damage_show)
	damage_show.setup(exterior, outside)
	_thud = _player("Thud")
	_fold = _player("Fold")
	_grind = AudioStreamPlayer.new()
	_grind.name = "Grind"
	_grind.bus = AudioBuses.SHIP
	_grind.volume_db = -22.0
	add_child(_grind)
	set_own(false)
	rebuild()

func _physics_process(delta: float) -> void:
	if unfolding >= 0:
		tick_unfold(delta)
	_credit_in -= delta
	if _credit_in <= 0.0:
		_credit_in = HabitatValues.CREDIT_EVERY
		credit_drills()
	_hum_in -= delta
	if _hum_in <= 0.0:
		_hum_in = HabitatValues.HUM_EVERY
		hum()

## Stands its frame at `frame` (engine space): cell (0, 0, 0)'s centre, up y.
func place(frame: Transform3D) -> void:
	exterior.global_transform = frame

## Builds the hull, the interior and the legs from the site, all but the
## module still unfolding. Keeps the store, the airlocks and every item.
func rebuild() -> void:
	var shown := site
	if unfolding >= 0:
		shown = BaseSite.from_dict(site.to_dict())
		shown.remove(unfolding)
	grid = shown.grid()
	var stowed := _stowed_items()
	exterior_builder.bind(grid, catalog)
	interior_builder.bind(grid, catalog)
	exterior_builder.rebuild()
	interior_builder.rebuild()
	_bind_airlocks()
	_reseat(stowed)
	var stats := ShipStats.compute(grid, catalog)
	# Wrecked modules stop (ship weapons spec §6.5): a store's tanks leave the
	# capacity, a hub's machine is unbound, a drill stops (credit_drills).
	var lost := 0
	for i in ModuleDamage.wrecked(site, ModuleCatalog.STORE, catalog):
		for b: Array in ModuleCatalog.get_def(ModuleCatalog.STORE).turned(site.modules[i]["turns"]):
			var def := catalog.get_def(b[1])
			lost += def.quantum_capacity if def != null else 0
	stats.quantum_capacity = maxi(stats.quantum_capacity - lost, 0)
	stats.intact_quantum_capacity = maxi(stats.intact_quantum_capacity - lost, 0)
	var hub_down := not ModuleDamage.wrecked(site, ModuleCatalog.HUB, catalog).is_empty()
	var machines: Array[QuantumMachine] = []
	if not hub_down:
		machines = interior_builder.quantum_machines()
	quantum.bind(interior_builder.quantum_cores(), machines, stats)
	# The box skin is the ship's look; a base wears its shell (§8.1) instead,
	# over the same colliders.
	if exterior_builder.skin() != null:
		exterior_builder.skin().visible = false
	var openings := []
	var alcoves := exterior_builder.alcoves()
	for at: Vector3i in alcoves:
		openings.append([at, (alcoves[at] as AirlockAlcove).hatch_normal])
	var layout := exterior_builder.layout()
	var tints := []
	for i in site.modules.size():
		if i != unfolding:
			tints.append(ExteriorBuilder.stage_colour(ModuleDamage.stage(site, i, catalog)))
	exterior_look.build(shown, layout.windows if layout != null else [], openings, tints)
	var reach := 0.0
	for c: Vector3i in grid.coords():
		reach = maxf(reach, ShipGrid.cell_center(c).length())
	exterior.set_meta(AsteroidStream.ANCHOR_RADIUS, reach + ShipGrid.CELL_SIZE * 0.87)
	_apply_own()
	_apply_livery()
	_place_link(shown)
	if link != null:
		link.offline = hub_down
	_show_damage()

## A damaged module's blocks carry its damage (the shown grid is rebuilt each
## time), so DamageShow spits sparks from its shell as it does from a ship's.
func _show_damage() -> void:
	if damage_show == null:
		return
	for i in site.modules.size():
		if i == unfolding or ModuleDamage.taken(site, i) <= 0.0:
			continue
		var share := minf(ModuleDamage.taken(site, i) / ModuleDamage.hp(site, i, catalog),
			ShipDamage.SHOWN_MOST / BlockDamage.GONE_AT)
		for cell in site.cells_of(i):
			var inst := grid.get_block(cell)
			var def := catalog.get_def(inst.block_id) if inst != null else null
			if def != null:
				inst.damage = def.hp * share
	damage_show.sync(grid, catalog)

## The link panel on the first hub's deck beside its airlock (§6.1).
func _place_link(shown: BaseSite) -> void:
	if link != null:
		link.queue_free()
		link = null
	var hubs := shown.hubs()
	if hubs.is_empty():
		return
	var m: Dictionary = shown.modules[hubs[0]]
	var spot := (m["cell"] as Vector3i) + ModuleDefinition.turn_cell(Vector3i(0, 0, 1), m["turns"],
		ModuleCatalog.get_def(ModuleCatalog.HUB).size)
	link = LinkPanel.new()
	link.name = "LinkPanel"
	var at := InteriorBuilder.interior_center(spot)
	at.y = InteriorBuilder.floor_y(spot)
	# Back to the hub's front wall, facing into the room, turned with the hub.
	var turn := Basis(Vector3.UP, PI * 0.5 * m["turns"])
	link.transform = Transform3D(turn * Basis(Vector3.UP, PI), at + turn * Vector3(0, 0, LinkPanel.FROM_CENTRE))
	interior.add_child(link)
	link.setup(self)

## Starts module `index` unfolding (§5.3); it is already in the site.
func begin_unfold(index: int) -> void:
	unfolding = index
	unfold_left = HabitatValues.UNFOLD
	_stamped = false

## Advances the unfolding by `delta`: the show, the stamp as the legs land, and
## at the end the rebuild that changes the base. Tests call it directly.
func tick_unfold(delta: float) -> void:
	if unfolding < 0:
		return
	unfold_left = maxf(unfold_left - delta, 0.0)
	var t := 1.0 - unfold_left / HabitatValues.UNFOLD
	exterior_look.unfold(unfolding, t, site, livery)
	var legs_down := HabitatValues.FLY + HabitatValues.SETTLE + HabitatValues.LEGS
	if not _stamped and t * HabitatValues.UNFOLD >= legs_down:
		# The legs are down and the walls start: the stamp, and the unfolding's sound.
		_stamped = true
		stamp(unfolding)
		_play(_fold, &"unfold", exterior.global_transform * site.centre_of(unfolding))
	if unfold_left <= 0.0:
		var done := unfolding
		unfolding = -1
		# A drill starts earning when it stands, not when it was planted.
		if site.modules[done].has("drill") and clock.is_valid():
			site.modules[done]["drill"]["credited_at"] = float(clock.call())
		rebuild()
		unfolded.emit(done)

## The legs stamping into the rock (§8.4): a vibration through it that
## scatters the herds near.
func stamp(index: int) -> void:
	var at := exterior.global_transform * site.centre_of(index)
	StimulusBus.send(exterior, Stimulus.make(Stimulus.VIBRATION, at, HabitatValues.STAMP_STRENGTH,
		HabitatValues.STAMP_RADIUS, exterior, site.site_id), 0.5)
	_play(_thud, &"leg_stamp", at)

## Credits every drill that is not unfolding up to now. Returns what it paid.
func credit_drills() -> int:
	if not clock.is_valid() or quantum == null or quantum.store == null:
		return 0
	var now: float = clock.call()
	var paid := 0
	for i in site.drills():
		if i == unfolding:
			continue
		if ModuleDamage.stage(site, i, catalog) == BlockDamage.Stage.WRECKED:
			# Stopped: the time it stood wrecked is neither paid nor run, now or after a mend.
			site.modules[i]["drill"]["credited_at"] = now
		else:
			paid += DrillYield.credit(site.modules[i]["drill"], now, quantum.store)
	return paid

## Each working drill's hum through the rock (§8.4): too faint to startle.
func hum() -> void:
	for i in site.drills():
		if i == unfolding or ModuleDamage.stage(site, i, catalog) == BlockDamage.Stage.WRECKED:
			continue
		var at := exterior.global_transform * site.centre_of(i)
		StimulusBus.send(exterior, Stimulus.make(Stimulus.VIBRATION, at, HabitatValues.HUM_STRENGTH,
			HabitatValues.HUM_RADIUS, exterior, site.site_id), HabitatValues.HUM_EVERY)
	var working := site.drills().any(func(i: int) -> bool:
		return i != unfolding and ModuleDamage.stage(site, i, catalog) != BlockDamage.Stage.WRECKED)
	if own and working and not _grind.playing:
		var s := Synth.sound(&"drill_hum")
		if s != null:
			_grind.stream = s
			_grind.play()
	elif (not own or not working) and _grind.playing:
		_grind.stop()

## A hit on the base's shell (ship weapons spec §6.5): its cell, then its
## module. A stage crossed rebuilds it, which is what stops or restarts it.
func _on_hull_hit(hit: Hit) -> void:
	var at := exterior.to_local(hit.position)
	var cell := ShipCells.hull_cell(grid, exterior, hit.shape, at, exterior.global_basis.inverse() * hit.normal)
	var index: int = site.occupied().get(cell, -1)
	if index < 0 or index == unfolding:
		return
	# A drill about to be wrecked is paid up to now first: the seconds before it stopped are its own.
	if site.modules[index]["kind"] == ModuleCatalog.DRILL:
		credit_drills()
	if ModuleDamage.hit(site, index, hit.damage, catalog):
		rebuild()

func module_stage(index: int) -> int:
	return ModuleDamage.stage(site, index, catalog)

## What the torch is aimed at (RepairTorch): {part, cell, outside}, or {}.
func part_hit(collider: Object, shape: int, at: Vector3, normal: Vector3) -> Dictionary:
	if collider != exterior:
		return {}
	var cell := ShipCells.hull_cell(grid, exterior, shape, exterior.to_local(at), exterior.global_basis.inverse() * normal)
	var index: int = site.occupied().get(cell, -1)
	if index < 0 or index == unfolding:
		return {}
	return {"part": ModuleDamage.part(index), "cell": cell, "outside": true}

func is_section(p: StringName) -> bool:
	return ModuleDamage.index_of(p) >= 0

func repair_section(p: StringName, share: float) -> float:
	var index := ModuleDamage.index_of(p)
	if index < 0 or index >= site.modules.size():
		return 0.0
	var before := module_stage(index)
	var used := ModuleDamage.repair(site, index, share, catalog)
	if used > 0.0 and module_stage(index) != before:
		rebuild()
	return used

## "DRILL 1 · 45% H"
func part_label(p: StringName) -> String:
	var index := ModuleDamage.index_of(p)
	if index < 0:
		return ""
	var left := 1.0 - ModuleDamage.taken(site, index) / maxf(ModuleDamage.hp(site, index, catalog), 1.0)
	return "%s · %d%% H" % [ModuleDamage.label(site, index), roundi(left * 100.0)]

func _player(player_name: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = player_name
	p.bus = AudioBuses.SUIT
	p.max_distance = 40.0
	exterior.add_child(p)
	return p

## Plays `sound_name` on `player` at `at` (engine space); quiet until Synth is warm.
func _play(player: AudioStreamPlayer3D, sound_name: StringName, at: Vector3) -> void:
	var s := Synth.sound(sound_name)
	if s == null or player == null or not player.is_inside_tree():
		return
	player.global_position = at
	player.stream = s
	player.play()

## Why a save must wait on it, or "": unfolding, or anything GridHome waits on.
func busy() -> String:
	if unfolding >= 0:
		return "unfolding"
	return home_busy()

## Writes what must outlive its nodes into the site: the store, each airlock,
## every item in it (§9.3, §11.1).
func capture() -> void:
	if quantum != null and quantum.store != null:
		site.store = quantum.store.amount
	site.airlocks = {}
	for at: Vector3i in airlocks:
		site.airlocks[SaveCodec.cell_key(at)] = airlocks[at].to_dict()
	site.items = items_to_dict()

## Reads them back after a wake or a load: the store, each airlock, the items.
func restore_inside() -> void:
	if quantum.store != null:
		quantum.store.from_dict({"amount": site.store})
	for key: String in site.airlocks:
		var airlock: Airlock = airlocks.get(SaveCodec.to_cell(key))
		if airlock != null:
			airlock.from_dict(site.airlocks[key])
	for d in site.items:
		if d is Dictionary:
			restore_item(d)
	# The time it slept: a drill earns as if you were there.
	credit_drills()
