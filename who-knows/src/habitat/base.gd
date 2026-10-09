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
	quantum.bind(interior_builder.quantum_cores(), interior_builder.quantum_machines(), stats)
	# The box skin is the ship's look; a base wears its shell (§8.1) instead,
	# over the same colliders.
	if exterior_builder.skin() != null:
		exterior_builder.skin().visible = false
	var openings := []
	var alcoves := exterior_builder.alcoves()
	for at: Vector3i in alcoves:
		openings.append([at, (alcoves[at] as AirlockAlcove).hatch_normal])
	var layout := exterior_builder.layout()
	exterior_look.build(shown, layout.windows if layout != null else [], openings)
	var reach := 0.0
	for c: Vector3i in grid.coords():
		reach = maxf(reach, ShipGrid.cell_center(c).length())
	exterior.set_meta(AsteroidStream.ANCHOR_RADIUS, reach + ShipGrid.CELL_SIZE * 0.87)
	_apply_own()
	_apply_livery()

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
		if i != unfolding:
			paid += DrillYield.credit(site.modules[i]["drill"], now, quantum.store)
	return paid

## Each working drill's hum through the rock (§8.4): too faint to startle.
func hum() -> void:
	for i in site.drills():
		if i == unfolding:
			continue
		var at := exterior.global_transform * site.centre_of(i)
		StimulusBus.send(exterior, Stimulus.make(Stimulus.VIBRATION, at, HabitatValues.HUM_STRENGTH,
			HabitatValues.HUM_RADIUS, exterior, site.site_id), HabitatValues.HUM_EVERY)
	var working := site.drills().any(func(i: int) -> bool: return i != unfolding)
	if own and working and not _grind.playing:
		var s := Synth.sound(&"drill_hum")
		if s != null:
			_grind.stream = s
			_grind.play()
	elif (not own or not working) and _grind.playing:
		_grind.stop()

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
