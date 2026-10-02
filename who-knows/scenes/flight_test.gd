extends Node3D

## Builds the starter shuttle -- the blueprint from
## docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md §3 --
## so flight_test.tscn always has a ship. Once the shipyard exists
## (Task 20) this loads a saved blueprint instead.
##
## It also keeps the one saved game (docs/superpowers/specs/
## 2026-09-26-saving-design.md): a launch resumes it, and it saves itself in
## calm moments. This is the one place that knows every part of the game, so
## capture() and restore here gather and hand out each part's dictionary.

## The ship you are aboard changed (many ships spec §4.1).
signal aboard_changed(ship: Ship)

@onready var _starter: Ship = $Ship
@onready var _hud: HudRoot = $HudRoot
@onready var _director: CameraDirector = $CameraDirector
@onready var _prompt: Label = $Prompt/Label
@onready var _interactor: Interactor = $Ship/Interior/Avatar/Head/Interactor
@onready var _avatar: Avatar = $Ship/Interior/Avatar
@onready var _universe: Universe = $Universe
@onready var _stream: AsteroidStream = $AsteroidStream

## Every ship in the world (many ships spec §5), and the one you are in, or
## the one your suit belongs to on a spacewalk (§3.4).
var fleet: Fleet
var aboard: Ship

## The star system the flight is in (the system skeleton spec §4), from the
## world seed, and the node that draws its star, planets and moons.
var system: SystemRecipe
var star_system: StarSystem
## Every salvage cloud, under Outside (quantum energy spec §10.2).
var salvage: SalvageField
## Every stray item adrift outside (saving spec §7), under Outside.
var strays: StrayField

## Saving (saving spec §9): on in the real game, off in headless runs. A test
## turns it on, with a path of its own, before the scene enters the tree.
var save_enabled := SaveGame.enabled_by_default()
var save_path := SaveGame.DEFAULT_PATH
var save_game: SaveGame
var save_gate := SaveGate.new()
## Seconds of play in this game, across every session of it.
var play_time := 0.0
## True when this session resumed a saved game rather than starting a new one.
var resumed := false

var _reticle: Reticle
var _interact_prompt := ""
var _grasp_prompt := ""
var _universe_readout: Label
var _saved_tag: SavedTag
var npc_debug: NpcDebug
var npc_bus: StimulusBus
var exterior_npcs: NpcDirector
## The dead and the wounded, for every director (health and damage spec §6).
var npc_ledger := NpcLedger.new()
var contact_markers: Array[ContactMarker] = []
## The course on the HUD, one per view (bridge computer spec §6.1, §8).
var course_markers: Array[CourseMarker] = []
var course_chime: AudioStreamPlayer
## The warp on the HUD (the warp spec §7.3): its panel in the band, and a
## bracket per world, one per view.
var warp_panel: WarpPanel
var body_markers: Array[BodyMarker] = []
## Which body the debug hop last put you by (F7), in the system's order.
var hop_index := -1
## The debug hop leaves you this far off a body's surface, or nearer a small
## moon, so you are near it.
const HOP_OFF := 3000.0
const HOP_INSIDE := 200.0

## The interior's own mood (spec §3.3): dim and warm, with bloom turning the
## thin lit strips into light. It goes on the interior camera, not the world,
## so the chase view and the canopy feed keep the WorldEnvironment's look.
const INTERIOR_ENVIRONMENT: Environment = preload("res://data/environments/ship_interior.tres")

## The outside's mood (ship exterior spec §6.3): a near-black ambient, so the
## sun's side of a rock reads as it did and its night side waits for your
## lights, and a gentle bloom on lenses, windows and strips. Tuned at the
## renders.
const OUTSIDE_AMBIENT_ENERGY := 0.4
const OUTSIDE_GLOW_INTENSITY := 0.6
const OUTSIDE_GLOW_BLOOM := 0.05
## Screen, not the engine's default soft light: soft light on a near-black
## night draws no visible halo round a lens, however strong the light is.
const OUTSIDE_GLOW_BLEND := Environment.GLOW_BLEND_MODE_SCREEN

## BlockOrientation values used below. `_FORWARDS` order is
## [FORWARD, BACK, LEFT, RIGHT, UP, DOWN]; o = (forward_index << 2) | roll.
## Roll never matters here because every use is either the identity roll
## (0) or a 90-degree roll whose only job is to swap which local axis the
## wedge's chamfer leans toward -- see block_orientation.gd.
const O_FORWARD := 0     ## bow-facing: chamfers/canopy glass slope up-forward; thrust along -Z
const O_STARBOARD_FWD := 1   ## FORWARD, rolled 90 deg: hull_wedge chamfer faces +X,-Z
const O_PORT_FWD := 3        ## FORWARD, rolled 270 deg: hull_wedge chamfer faces -X,-Z
const O_STERN := 4       ## BACK: hull_wedge chamfer faces +Z,+Y, for the tail taper
const O_RCS_PORT := 8        ## LEFT: thrust along -X
const O_RCS_STARBOARD := 12  ## RIGHT: thrust along +X
const O_RCS_UP := 16         ## UP: thrust along +Y
const O_RCS_DOWN := 20       ## DOWN: thrust along -Y
const O_KEEL := 2        ## FORWARD rolled 180 deg: a half block's upper half, hung under a cell

func _ready() -> void:
	var saved := _read_save()
	var ship_part: Dictionary = saved.get("ship", {})
	var layout := Ship.layout_of(ship_part) if resumed else null
	if resumed and (layout == null or layout.coords().is_empty()):
		push_error("FlightTest: the saved ship has no blocks; starting a new game")
		resumed = false
		saved = {}
	if resumed:
		_starter.launch_blueprint = Ship.launch_of(ship_part)
		npc_ledger.from_dict(saved.get("npcs", {}))
	_starter.set_grid(layout if resumed else _starter_grid(), not resumed)
	if resumed:
		_starter.restore_aboard(ship_part)
	_make_fleet()
	_place_avatar_on_deck()
	_set_interior_mood()
	_set_outside_mood()
	_wire_hud()
	_wire_prompt()
	_wire_hands()
	_wire_hurt()
	_wire_universe(saved)
	_wire_npcs()
	_wire_sensors()
	_wire_warp()
	_wire_saving()
	for ship in fleet.ships():
		_wire_ship(ship)
	fleet.joined.connect(_wire_ship)
	fleet.left.connect(_on_ship_left)
	board(aboard, true)

## Every ship in the world (many ships spec §5): the starter first, aboard.
func _make_fleet() -> void:
	fleet = Fleet.new()
	fleet.name = "Fleet"
	fleet.home = self
	fleet.outside = $Outside
	fleet.universe = _universe
	fleet.aboard = func() -> Ship: return aboard
	add_child(fleet)
	fleet.adopt(_starter)
	aboard = _starter

## Everything one ship needs from the game, once (many ships spec §5.2): every
## ship at the end of _ready, and each the fleet takes in after.
func _wire_ship(ship: Ship) -> void:
	# The ship's scene cannot reach the game's director by path (§3.2).
	ship.seat.director = _director
	ship.pilot.bind_director(_director)
	ship.pilot.lights = ship.lights
	# Godot's cameras stop drawing at 4 km; a world's horizon is about 120 km
	# off (the world scale spec §5.2).
	for cam: Camera3D in [ship.chase_camera, ship.canopy_camera]:
		cam.far = BodyProxy.VIEW_FAR
	# Hurt (health and damage spec §7.4, §8.1): a hole where you stand puts you
	# outside; a shed plate is a stray.
	ship.blocks_lost.connect(_on_blocks_lost.bind(ship))
	ship.plate_shed.connect(func(item: Item) -> void: strays.adopt(item))
	# Its crew answers to the game's ledger, and shows on F4. The crew woke
	# with the ship, before it had the ledger.
	ship.npc_director.ledger = npc_ledger
	for npc: Npc in ship.npc_director.live_npcs():
		npc.health.current = npc_ledger.health_of(npc.record.id, npc.health.max)
	npc_debug.directors.append(ship.npc_director)
	# Its sensors (NPC foundation spec §22; the system skeleton spec §8, §10):
	# signs of life, big rocks to 30 km, the star, planets and moons.
	ship.sensors.universe = _universe
	ship.sensors.add_source(LifeContacts.new(_stream, exterior_npcs, _universe))
	ship.sensors.add_source(RockContacts.new(_stream.seed, _stream.recipe.start, _stream.shapes))
	ship.sensors.add_source(BodyContacts.new(system))
	ship.sensors.system = system
	ship.sensors.whereabouts = star_system.whereabouts
	ship.sensors.course_arrived.connect(_on_course_arrived.bind(ship))
	# The speed limit climbs with altitude in a world's well (the world scale
	# spec §6).
	ship.flight_computer.whereabouts = star_system.whereabouts
	# Its warp (the warp spec §5): J at its helm engages it.
	ship.warp.bind(system, _universe, star_system.whereabouts, ship.sensors, _stream.recipe,
		warp_busy_for.bind(ship))
	ship.pilot.warp_pressed.connect(ship.warp.engage)
	ship.warp.travel_started.connect(_on_warp_started)
	ship.warp.travel_ended.connect(_on_warp_ended)

func _on_ship_left(ship: Ship) -> void:
	npc_debug.directors.erase(ship.npc_director)

## Hands you to `ship` (many ships spec §4.1): its hull drawn as your own and
## its interior shown, the other's not; the views, the HUD's markers, the warp
## panel, your hands and the origin's focus all follow it, and only its
## sensors scan. Boarding the ship you are aboard does nothing unless `force`.
func board(ship: Ship, force := false) -> void:
	if ship == null or (ship == aboard and not force):
		return
	var old := aboard
	aboard = ship
	if old != null and old != ship and is_instance_valid(old):
		old.set_own(false)
		for m in _cockpit_markers(old):
			_hud.unregister_element(m)
	ship.set_own(true)
	for m in _cockpit_markers(ship):
		_hud.register_element(m)
	_director.bind(ship)
	($HudRoot/Screen/ChaseMarker as VelocityMarker).set_camera(ship.chase_camera)
	($HudRoot/Screen/HeadingChaseMarker as HeadingMarker).set_camera(ship.chase_camera)
	_rebind_markers(ship)
	if warp_panel != null:
		warp_panel.drive = ship.warp
	_avatar.grasp.world_root = ship.items
	if exterior_npcs != null:
		exterior_npcs.cameras = [ship.chase_camera, ship.canopy_camera, _avatar.camera]
	for s in fleet.ships():
		s.sensors.process_mode = Node.PROCESS_MODE_INHERIT if s == ship else Node.PROCESS_MODE_DISABLED
	_universe.set_focus(_avatar if _avatar.mode == Avatar.Mode.SUIT else ship.exterior)
	aboard_changed.emit(ship)

## The cockpit's own markers, in `ship`'s canopy view: the HUD feeds them while
## it is the ship you are aboard.
static func _cockpit_markers(ship: Ship) -> Array[HudElement]:
	var out: Array[HudElement] = []
	for marker_name in ["CockpitMarker", "HeadingCockpitMarker"]:
		var m := ship.canopy_overlay.get_node_or_null(marker_name) as HudElement
		if m != null:
			out.append(m)
	return out

## The contact, course and body markers onto `ship` (bridge computer spec §8):
## the cockpit's into its canopy view, the chase view's through its chase
## camera, all reading its sensors.
func _rebind_markers(ship: Ship) -> void:
	for group: Array in [contact_markers, course_markers, body_markers]:
		for m: WorldMarker in group:
			if String(m.name).ends_with("Cockpit"):
				if m.get_parent() != ship.canopy_overlay:
					m.reparent(ship.canopy_overlay, false)
				m.set_camera(ship.canopy_camera)
			elif String(m.name).ends_with("Chase"):
				m.set_camera(ship.chase_camera)
	for m in contact_markers:
		(m as ContactMarker).sensors = ship.sensors
	for m in course_markers:
		(m as CourseMarker).bind(ship.sensors)
		(m as CourseMarker).warp = ship.warp
	for m in body_markers:
		(m as BodyMarker).sensors = ship.sensors

## F8, debug (many ships spec §4.3): seats you at the helm of the nearest other
## awake ship. False, with a toast saying why, when it can't.
func board_nearest() -> bool:
	var why := _board_refusal()
	var target: Ship = null
	if why == "":
		target = fleet.nearest(aboard.exterior.global_position, aboard)
		if target == null:
			why = "NO OTHER SHIP NEAR"
	if why != "":
		if warp_panel != null:
			warp_panel.toast(why)
		return false
	board_at_helm(target)
	return true

## Why F8 must wait, or "": on a spacewalk, mid-sit, during a warp, or while an
## airlock of the ship you are aboard cycles.
func _board_refusal() -> String:
	if _avatar.mode == Avatar.Mode.SUIT:
		return "NOT ON A SPACEWALK"
	if _director.is_moving():
		return "SITTING DOWN"
	for ship in fleet.ships():
		if ship.warp.is_spinning():
			return "WARP ENGAGED"
	for airlock: Airlock in aboard.airlocks.values():
		if airlock.busy() != "":
			return "AIRLOCK CYCLING"
	return ""

## Seats you at `ship`'s helm at once (many ships spec §4.3): up out of your own
## chair, across to its deck, aboard it, and down into its seat.
func board_at_helm(ship: Ship) -> void:
	_director.stand_now()
	_avatar.move_aboard(ship.interior, ship.interior.global_transform * _deck_spot(ship))
	board(ship)
	_director.sit_now(ship.seat)

## The interior camera is also the seated camera -- CameraDirector moves it
## between head and seat -- so one assignment covers walking and flying.
func _set_interior_mood() -> void:
	var cam: Camera3D = $Ship/Interior/Avatar/Head/Camera3D
	cam.environment = INTERIOR_ENVIRONMENT

## The world environment is the outside's (the chase view and the canopy
## feed): dark until a light reaches it, and lights bloom.
func _set_outside_mood() -> void:
	var env: Environment = $WorldEnvironment.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = SpacePalette.AMBIENT
	env.ambient_light_energy = OUTSIDE_AMBIENT_ENERGY
	env.glow_enabled = true
	env.glow_intensity = OUTSIDE_GLOW_INTENSITY
	env.glow_bloom = OUTSIDE_GLOW_BLOOM
	env.glow_blend_mode = OUTSIDE_GLOW_BLEND

## Shows what the avatar is looking at. Interactor has emitted this since it
## was written, with nothing listening: the seat was an invisible collider
## that answered an unadvertised keypress, which is no way to find a chair.
## While you hold something a drop would stow, the stow prompt wins.
func _wire_prompt() -> void:
	_prompt.text = ""
	_interactor.prompt_changed.connect(
		func(text: String) -> void:
			_interact_prompt = text
			_show_prompt()
	)
	_avatar.grasp.prompt_changed.connect(
		func(text: String) -> void:
			_grasp_prompt = text
			_show_prompt()
	)
	# The prompt belongs to the avatar, not the pilot. Sitting down hands the
	# view to the seat, so anything the raycast still reports is stale.
	_director.piloting_changed.connect(
		func(piloting: bool) -> void:
			if piloting:
				_interact_prompt = ""
				_grasp_prompt = ""
				_show_prompt()
	)

func _show_prompt() -> void:
	_prompt.text = _grasp_prompt if _grasp_prompt != "" else _interact_prompt

## Health and damage (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §7): the view's red edge and the
## blackout; the helm keeping you from harm; waking aboard at the ship's
## cost; what you drop outside adrift as a stray; and a hole under you
## putting you outside. Wired here so src/avatar never learns about Ship.
func _wire_hurt() -> void:
	var edge := HurtEdge.new()
	edge.name = "HurtEdge"
	$Prompt.add_child(edge)
	$Prompt.move_child(edge, 0)
	edge.bind(_avatar)
	_avatar.seated_source = func() -> bool: return _director.is_seated
	_avatar.rescue = _rescue
	_avatar.rescue_cost = func(n: int) -> int:
		return aboard.quantum.store.drain(n, &"rescue") if aboard.quantum.store != null else 0
	_avatar.let_fall.connect(func(item: Item, outside: bool) -> void:
		if outside and strays != null:
			strays.adopt(item))

## Puts a blacked-out `avatar` aboard where it fits first (§7.2).
func _rescue(avatar: Avatar) -> void:
	for pose in aboard.wake_spots():
		if not avatar.can_stand_at(pose) and avatar.mode == Avatar.Mode.PLATING:
			continue
		if avatar.mode == Avatar.Mode.SUIT:
			avatar.enter_plating(aboard.interior, pose, 0.0, Vector3.ZERO, Quaternion.IDENTITY)
		else:
			avatar.place(pose)
		return

## A hole where you stand puts you outside, moving as you were (health and
## damage spec §7.4): only a hole in the ship you stand in.
func _on_blocks_lost(_coords: Array[Vector3i], ship: Ship) -> void:
	if _avatar.mode != Avatar.Mode.PLATING or _avatar.get_parent() != ship.interior:
		return
	var local := ship.interior.to_local(_avatar.global_position + _avatar.global_basis.y * 0.1)
	var cell := ShipCells.interior_cell_at(local)
	if ship.grid.has_block(cell):
		return
	var world := Threshold.to_world(ship.interior.global_transform, ship.exterior.global_transform,
		_avatar.global_transform, InteriorBuilder.storey_offset(cell.y))
	var v := Threshold.carry_velocity_out(ship.exterior.linear_velocity, ship.exterior.global_basis,
		_avatar.velocity)
	_avatar.enter_suit(ship.outside, world, v, ship.exterior)
	for airlock: Airlock in ship.airlocks.values():
		_avatar.beacon_source = airlock.beacon
		_avatar.home_source = airlock.home
		break

## Hands and items (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §7, §8, §10): what you let go of lands aboard this ship, and the reticle
## follows the view. Wired here so src/avatar and src/ui never learn about
## CameraDirector or Ship.
func _wire_hands() -> void:
	_avatar.grasp.world_root = aboard.items
	_reticle = Reticle.new()
	_reticle.name = "Reticle"
	$Prompt.add_child(_reticle)
	_director.view_changed.connect(_on_view_changed)
	_on_view_changed(_director.view, false)

func _on_view_changed(view: CameraDirector.View, moving: bool) -> void:
	var first_person := view == CameraDirector.View.FOOT_FIRST
	_avatar.grasp.first_person = first_person
	_avatar.hands.shown = first_person and not moving
	_reticle.visible = first_person and not moving

## The floating origin (asteroids spec §4) follows whoever is outside: the
## hull, or you on a spacewalk. Wired here so neither Ship nor Avatar needs to
## know about Universe. F3 shows where you are in the universe.
##
## A resumed game puts the origin where you were, then the hull and you back
## where the save had you, before the rocks load (saving spec §6.1). A save
## from another asteroid generator starts the world over at the start, with
## your ship, its store and everything aboard (§8.1).
func _wire_universe(saved: Dictionary) -> void:
	_universe.set_focus(aboard.exterior)
	var world: Dictionary = saved.get("world", {})
	if world.has("seed"):
		_stream.seed = int(world["seed"])
	# The seed makes a star system, and its rocks lie in its belts and rings
	# (the system skeleton spec §4, §6). The flight starts at its entry, by the
	# first belt's first group: the universe's origin goes there, and the
	# rocks around it load before the first frame.
	system = SystemRecipe.from_seed(_stream.seed)
	_stream.shapes = system.asteroid_shapes()
	var start := system.entry()
	var same_world := resumed and _same_generator(saved, "asteroids") and _same_generator(saved, "system")
	if resumed and not same_world:
		push_warning("FlightTest: the save's asteroids are another version; back to the start")
	if same_world:
		_restore_places(saved)
	else:
		_universe.origin = start
		if resumed:
			_restore_you(saved.get("avatar", {}), false)
	_stream.start(_universe, start)
	_wire_star_system()
	_wire_salvage(saved if same_world else {}, _same_generator(saved, "salvage"))
	_wire_strays(saved.get("strays", {}) if same_world else {})
	# Godot's cameras stop drawing at 4 km; a world's horizon is about 120 km off
	# and every proxy sits at 350 km (the world scale spec §5.2). Each ship's
	# cameras get the same in _wire_ship.
	_avatar.camera.far = BodyProxy.VIEW_FAR
	# The sun's shadows stopped at 100 m, so nothing on a big rock cast one.
	$DirectionalLight3D.directional_shadow_max_distance = AsteroidStream.SHADOW_REACH
	_avatar.mode_changed.connect(
		func(mode: Avatar.Mode) -> void:
			_universe.set_focus(_avatar if mode == Avatar.Mode.SUIT else aboard.exterior)
	)
	_universe_readout = Label.new()
	_universe_readout.name = "UniverseReadout"
	_universe_readout.position = Vector2(16, 16)
	_universe_readout.visible = false
	$Prompt.add_child(_universe_readout)

## The star, planets and moons (the system skeleton spec §7), placed for the
## focus before the first frame, and the sun aimed from the star.
func _wire_star_system() -> void:
	star_system = StarSystem.new()
	star_system.name = "StarSystem"
	add_child(star_system)
	star_system.setup(system, _universe, $DirectionalLight3D)

## Salvage (quantum energy spec §10.2, §14): the field under Outside, at the
## identity, with the same world seed as the rocks; and the near cloud out of
## the starter's airlock, behind its stern, fixed in the universe now.
## A resumed game takes its clouds and ledger from the save instead; a save
## from another salvage generator keeps its clouds but not its ledger, whose
## indices would name other items (saving spec §8.1).
func _wire_salvage(saved: Dictionary, same_salvage: bool) -> void:
	salvage = SalvageField.new()
	salvage.name = "SalvageField"
	$Outside.add_child(salvage)
	salvage.setup(_universe, _starter.item_catalog, _stream.seed)
	var part: Dictionary = saved.get("salvage", {})
	if part.get("centres", {}).is_empty():
		salvage.add_near_cloud(_stern())
		return
	if not same_salvage:
		push_warning("FlightTest: the save's salvage is another version; what was taken is forgotten")
	salvage.from_dict(part, same_salvage)

func _wire_strays(saved: Dictionary) -> void:
	strays = StrayField.new()
	strays.name = "StrayField"
	$Outside.add_child(strays)
	strays.setup(_universe, _starter.item_catalog)
	if not saved.is_empty():
		strays.from_dict(saved)

## A frame on the hull at the middle of the airlock's outer hatch, +z pointing
## out of it along the airlock's line: aft, on the starter.
func _stern() -> Transform3D:
	for airlock: Airlock in _starter.airlocks.values():
		if not is_instance_valid(airlock.alcove):
			continue
		var hatch := airlock.alcove.outer_hatch.global_transform
		var out := -hatch.basis.z.normalized()
		return Transform3D(Basis.looking_at(-out, hatch.basis.y), airlock.beacon())
	return _starter.exterior.global_transform

## NPCs (docs/superpowers/specs/2026-09-26-npc-foundation-design.md): the
## overlay (F4) watches every director.
func _wire_npcs() -> void:
	# Outside: skitters on the big rocks near you, live within 350 m of the hull
	# or of you on a spacewalk. The bus and the holder never move; each live
	# skitter is shifted by the floating origin itself.
	npc_bus = StimulusBus.new()
	npc_bus.name = "StimulusBus"
	add_child(npc_bus)
	npc_bus.setup(self, _universe)
	var holder := Node3D.new()
	holder.name = "Npcs"
	add_child(holder)
	exterior_npcs = NpcDirector.new()
	exterior_npcs.name = "NpcDirector"
	exterior_npcs.rule = NpcDirector.Rule.BY_DISTANCE
	exterior_npcs.max_live = 32
	exterior_npcs.holder = holder
	exterior_npcs.catalog = _starter.npc_director.catalog
	exterior_npcs.bus = npc_bus
	exterior_npcs.cameras = [aboard.chase_camera, aboard.canopy_camera, _avatar.camera]
	exterior_npcs.sources = [RockHerdSource.new(_stream)]
	exterior_npcs.ledger = npc_ledger
	add_child(exterior_npcs)
	npc_debug = NpcDebug.new()
	npc_debug.name = "NpcDebug"
	add_child(npc_debug)
	npc_debug.directors.append(exterior_npcs)

## The sensors' contacts, and the course the bridge computer sets (NPC
## foundation spec §22), show on the HUD three ways, like the velocity marker:
## through the canopy, in chase view, and on a spacewalk. They read the ship
## you are aboard; each ship's sensors get their sources in _wire_ship.
func _wire_sensors() -> void:
	contact_markers.clear()
	for m in _mount_per_view(func() -> WorldMarker: return ContactMarker.new(), "Contacts"):
		(m as ContactMarker).sensors = aboard.sensors
		contact_markers.append(m)
	course_markers.clear()
	for m in _mount_per_view(func() -> WorldMarker: return CourseMarker.new(), "Course"):
		(m as CourseMarker).bind(aboard.sensors)
		course_markers.append(m)
	_wire_course_chime()

## Mounts a world marker once per view (bridge computer spec §8): in the canopy
## overlay with CanopyCam, on the HUD screen with ChaseCamera, and on the HUD
## screen with no camera of its own, for a spacewalk. `make` returns a fresh
## marker; each is named `prefix` and its view.
func _mount_per_view(make: Callable, prefix: String) -> Array[WorldMarker]:
	var out: Array[WorldMarker] = []
	for mount: Array in [[aboard.canopy_overlay, aboard.canopy_camera, "Cockpit"],
			[$HudRoot/Screen, aboard.chase_camera, "Chase"], [$HudRoot/Screen, null, "Spacewalk"]]:
		var marker: WorldMarker = make.call()
		marker.name = prefix + mount[2]
		marker.set_anchors_preset(Control.PRESET_FULL_RECT)
		(mount[0] as Node).add_child(marker)
		marker.set_camera(mount[1])
		# HudRoot finds its own descendants; the canopy's is in the ship's
		# SubViewport, so it is registered.
		if not _hud.is_ancestor_of(marker):
			_hud.register_element(marker)
		out.append(marker)
	return out

## The chime a course makes when it clears by arriving (_on_course_arrived).
func _wire_course_chime() -> void:
	course_chime = AudioStreamPlayer.new()
	course_chime.name = "CourseChime"
	add_child(course_chime)

## A soft chime when the course of the ship you are aboard clears by arriving
## (bridge computer spec §9): through the suit on a spacewalk, else the ship.
func _on_course_arrived(_id: StringName, ship: Ship) -> void:
	if ship != aboard:
		return
	var s := Synth.sound(&"course_arrived")
	if s == null:
		return
	course_chime.bus = AudioBuses.SUIT if _avatar.mode == Avatar.Mode.SUIT else AudioBuses.SHIP
	course_chime.stream = s
	course_chime.play()

## The warp (docs/superpowers/specs/2026-09-28-warp-design.md §5) on the HUD:
## its panel, the toasts at a limit and a bracket per world. Each ship's drive
## is bound in _wire_ship. While one travels the rocks and salvage wait and the
## belts show whole; after, everything near is loaded before the next frame,
## as the hop does.
func _wire_warp() -> void:
	warp_panel = WarpPanel.new()
	warp_panel.name = "WarpPanel"
	warp_panel.drive = aboard.warp
	$HudRoot/Screen/Band/Row.add_child(warp_panel)
	star_system.whereabouts.limit_entered.connect(_on_limit_entered)
	star_system.whereabouts.limit_left.connect(_on_limit_left)
	body_markers.clear()
	for m in _mount_per_view(func() -> WorldMarker: return BodyMarker.new(), "Bodies"):
		(m as BodyMarker).sensors = aboard.sensors
		body_markers.append(m)
	for m in course_markers:
		m.warp = aboard.warp

## A toast as you cross a warp limit (the warp spec §7.3).
func _on_limit_entered(place: Whereabouts.Place) -> void:
	warp_panel.toast("ENTERING %s" % place.name)

func _on_limit_left(place: Whereabouts.Place) -> void:
	var clear := star_system.whereabouts.warp_clear()
	warp_panel.toast("LEAVING %s · WARP CLEAR" % place.name if clear else "LEAVING %s" % place.name)

## Why the warp of the ship you are aboard must wait for the crew.
func warp_busy() -> StringName:
	return warp_busy_for(aboard)

## Why `ship`'s warp must wait for the crew: &"crew" on a spacewalk,
## &"airlock" while one of its airlocks cycles or stands open to space, else
## &"".
func warp_busy_for(ship: Ship) -> StringName:
	if _avatar.mode == Avatar.Mode.SUIT:
		return &"crew"
	for airlock: Airlock in ship.airlocks.values():
		if airlock.busy() != "" or airlock.cycle.open_side() == AirlockCycle.Door.OUTER:
			return &"airlock"
	return &""

## Why a save must wait on any ship (many ships spec §6.4), or "".
func _fleet_busy() -> String:
	for ship in fleet.ships():
		var why := ship.busy()
		if why != "":
			return why
	return ""

func _on_warp_started() -> void:
	_stream.suspended = true
	salvage.process_mode = Node.PROCESS_MODE_DISABLED
	star_system.set_warp(true)

func _on_warp_ended() -> void:
	star_system.set_warp(false)
	star_system.streak = Vector3.ZERO
	star_system.place_all()
	star_system.whereabouts.look()
	salvage.process_mode = Node.PROCESS_MODE_INHERIT
	_stream.resume()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F3:
			_universe_readout.visible = not _universe_readout.visible
		KEY_F7:
			hop(-1 if key.shift_pressed else 1)
		KEY_F8:
			board_nearest()

## How far off `b`'s surface the hop leaves you.
static func hop_off(b: SystemBody) -> float:
	return minf(HOP_OFF, b.neighbourhood - b.radius - HOP_INSIDE)

## The debug hop (the system skeleton spec §10): puts the ship at rest HOP_OFF
## off the surface of the next body in the system's order (star, then each
## planet and its moons), or the previous for `step` -1, on its sunward side
## and facing it. A system is 15,000 km across; this is the debug way round it. Refused on a spacewalk, while an airlock cycles, and while a
## warp spools or travels. True if it hopped.
func hop(step: int) -> bool:
	if aboard.warp.is_spinning():
		return false
	if _avatar.mode == Avatar.Mode.SUIT:
		return false
	for airlock: Airlock in aboard.airlocks.values():
		if airlock.busy() != "":
			return false
	hop_index = posmod(hop_index + step, system.bodies.size())
	var b := system.bodies[hop_index]
	var out := Vector3.BACK if b == system.star else system.star.point.minus(b.point).normalized()
	var at := b.point.plus(out * (b.radius + hop_off(b)))
	var hull := aboard.exterior
	hull.linear_velocity = Vector3.ZERO
	hull.angular_velocity = Vector3.ZERO
	var up := Vector3.UP if absf(out.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	hull.global_transform = Transform3D(Basis.looking_at(-out, up), _universe.to_engine(at))
	# The origin follows at once, and the rocks and worlds there are ready
	# before the next frame, as at the start.
	_universe.check()
	star_system.place_all()
	star_system.whereabouts.look()
	_stream.update(0.0, true)
	return true

func _process(_delta: float) -> void:
	if not _universe_readout.visible or _universe.focus == null:
		return
	var u := _universe.to_universe(_universe.focus.global_position)
	_universe_readout.text = "%s   seed %d
universe %.3f, %.3f, %.3f km   origin shifts %d
rock cells %d / %d / %d   bodies %d   late cells %d
save %s   last %ds ago   strays %d" % [
		star_system.whereabouts.text(), system.seed,
		(u.x + u.fx) / 1000.0, (u.y + u.fy) / 1000.0, (u.z + u.fz) / 1000.0, _universe.shifts,
		_stream.loaded_count(0), _stream.loaded_count(1), _stream.loaded_count(2), _stream.bubble.live.size(),
		_stream.late_cells, _save_readout(), int(save_gate.since_save), strays.count() if strays != null else 0]

## The save's state for F3: off, calm, or what it is waiting on.
func _save_readout() -> String:
	if not save_enabled:
		return "off"
	if save_gate.reason != "":
		return "waiting: " + save_gate.reason
	return "calm" if save_gate.is_calm() else "calming"

# --- saving (docs/superpowers/specs/2026-09-26-saving-design.md) -------------

## Reads the save, unless saving is off or a new game was asked for. Sets
## `resumed`; {} for a new game.
func _read_save() -> Dictionary:
	resumed = false
	if not save_enabled:
		return {}
	save_game = SaveGame.new(save_path)
	if SaveGame.new_game_asked():
		save_game.set_aside()
		return {}
	var data := save_game.read()
	if data.is_empty():
		return {}
	resumed = true
	play_time = float(data.get("play_time", 0.0))
	return data

## The gate's sources (§5), the SAVED tag, and a settling spell after the
## game begins.
func _wire_saving() -> void:
	save_gate.add_source(func() -> String: return "sitting" if _director.is_moving() else "")
	save_gate.add_source(_fleet_busy)
	save_gate.add_source(_avatar.busy)
	save_gate.settle()
	_saved_tag = SavedTag.new()
	_saved_tag.name = "SavedTag"
	$Prompt.add_child(_saved_tag)
	if save_game != null and save_game.locked:
		_saved_tag.show_locked()

func _physics_process(delta: float) -> void:
	if star_system != null:
		star_system.streak = aboard.warp.streak()
	play_time += delta
	if not save_enabled:
		return
	if save_gate.tick(delta):
		save_now()

## Writes the game, now, whatever the gate says: the gate decides when. True
## if it was written.
func save_now() -> bool:
	if not save_enabled:
		return false
	if save_game == null:
		save_game = SaveGame.new(save_path)
	var err := save_game.write(capture(), play_time)
	save_gate.saved()
	if err != OK:
		if not save_game.locked:
			push_error("FlightTest: could not save (%s)" % error_string(err))
		return false
	if _saved_tag != null:
		_saved_tag.flash()
	return true

## On quit: save if it is calm; otherwise the last save stands (§4).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_enabled and save_gate.is_calm():
		save_now()

## Every part of the game as plain data (§3).
func capture() -> Dictionary:
	return {
		"world": {"seed": _stream.seed},
		"ship": _starter.to_dict(_universe),
		"avatar": _capture_you(),
		"salvage": salvage.to_dict(),
		"strays": strays.to_dict(),
		"npcs": _capture_npcs(),
	}

## The dead, and the health of every NPC awake now and asleep (health and
## damage spec §10): the awake ones are written into the ledger first.
func _capture_npcs() -> Dictionary:
	var directors: Array = fleet.ships().map(func(s: Ship) -> NpcDirector: return s.npc_director)
	directors.append(exterior_npcs)
	for director: NpcDirector in directors:
		if director == null:
			continue
		for npc: Npc in director.live_npcs():
			if npc.health != null and not npc.is_dead():
				npc_ledger.set_health(npc.record.id, npc.health.current, npc.health.max)
	return npc_ledger.to_dict()

## You: walking, seated or on a spacewalk, where, which way, your suit and
## what is in your hand (§6.3).
func _capture_you() -> Dictionary:
	var d := {
		"suit": _avatar.suit_cell.to_dict(),
		"suit_assist": _avatar.suit_assist,
		"pitch": _avatar.head_pitch(),
		"health": _avatar.health.to_dict(),
	}
	if _avatar.mode == Avatar.Mode.SUIT:
		d["mode"] = "suit"
		d["at"] = SaveCodec.upoint(_universe.to_universe(_avatar.global_position))
		d["turn"] = SaveCodec.basis(_avatar.global_basis)
		d["v"] = SaveCodec.vec3(_avatar.velocity)
		var airlock := _avatar.beacon_source.get_object() as Airlock if _avatar.beacon_source.is_valid() else null
		if airlock != null:
			d["airlock"] = SaveCodec.cell_key(airlock.coord)
	else:
		d["mode"] = "seated" if _director.is_seated else "walking"
		d["place"] = SaveCodec.transform(aboard.interior.global_transform.affine_inverse() * _avatar.global_transform)
	if _avatar.grasp.item != null:
		d["held"] = _avatar.grasp.item.to_dict(Transform3D.IDENTITY)
	return d

## True when the save's generator `which` made the world this game makes.
static func _same_generator(saved: Dictionary, which: String) -> bool:
	var theirs: Dictionary = saved.get("generators", {})
	return int(theirs.get(which, -1)) == int(SaveGame.generators()[which])

## The origin near where you were, then the hull and you (§6.1).
func _restore_places(saved: Dictionary) -> void:
	var ship_part: Dictionary = saved.get("ship", {})
	var you: Dictionary = saved.get("avatar", {})
	var focus := SaveCodec.to_upoint(ship_part.get("hull", {}).get("at"))
	if String(you.get("mode", "")) == "suit":
		focus = SaveCodec.to_upoint(you.get("at"))
	_universe.origin = UniversePoint.at(
		roundi(focus.x / Universe.STEP) * int(Universe.STEP),
		roundi(focus.y / Universe.STEP) * int(Universe.STEP),
		roundi(focus.z / Universe.STEP) * int(Universe.STEP))
	_starter.restore_hull(ship_part, _universe)
	_restore_you(you, true)

## You as the save had you (§6.3). With `outside_too` false -- the world
## started over -- a spacewalk comes back aboard, standing.
func _restore_you(d: Dictionary, outside_too: bool) -> void:
	_avatar.suit_cell.from_dict(d.get("suit", {}))
	_avatar.suit_assist = bool(d.get("suit_assist", true))
	_avatar.health.from_dict(d.get("health", {}))
	var mode := String(d.get("mode", "walking"))
	if mode != "suit":
		var pose := aboard.interior.global_transform * SaveCodec.to_transform(d.get("place"))
		if _can_stand(pose):
			_avatar.place(Transform3D(Basis(Vector3.UP, pose.basis.get_euler().y), pose.origin))
		_avatar.set_head_pitch(float(d.get("pitch", 0.0)))
	# Hands work only aboard and standing, so the held item is taken first.
	var held: Variant = d.get("held")
	if held is Dictionary:
		var item := aboard.restore_item(held)
		if item != null and not _avatar.grasp.take(item):
			item.set_loose()
	if mode == "seated":
		_director.sit_now(aboard.seat)
	elif mode == "suit" and outside_too:
		_restore_spacewalk(d)

func _restore_spacewalk(d: Dictionary) -> void:
	var airlock: Airlock = aboard.airlocks.get(SaveCodec.to_cell(String(d.get("airlock", ""))))
	if airlock == null or not is_instance_valid(airlock.alcove):
		for a: Airlock in aboard.airlocks.values():
			if is_instance_valid(a.alcove):
				airlock = a
				break
	var pose := Transform3D(SaveCodec.to_basis(d.get("turn")), _universe.to_engine(SaveCodec.to_upoint(d.get("at"))))
	_avatar.enter_suit(aboard.outside, pose, SaveCodec.to_vec3(d.get("v")), aboard.exterior)
	_avatar.set_head_pitch(float(d.get("pitch", 0.0)))
	if airlock != null:
		_avatar.beacon_source = airlock.beacon
		_avatar.home_source = airlock.home
	_universe.set_focus(_avatar)

## Whether a saved standing place is still somewhere to stand: a walkable
## block under it, so a changed layout never leaves you in a wall (§6.3).
func _can_stand(pose: Transform3D) -> bool:
	var local := aboard.interior.global_transform.affine_inverse() * pose.origin
	var cell := Vector3i(roundi(local.x / ShipGrid.CELL_SIZE),
		roundi((local.y - InteriorBuilder.floor_y(Vector3i.ZERO)) / InteriorBuilder.STOREY_HEIGHT),
		roundi(local.z / ShipGrid.CELL_SIZE))
	if not aboard.grid.has_block(cell):
		return false
	var def := aboard.catalog.get_def(aboard.grid.get_block(cell).block_id)
	return def != null and def.is_walkable()

func _starter_grid() -> ShipGrid:
	var g := ShipGrid.new()

	# --- y = 0, cabin (art direction §3.1): x -2..2, z -4..3 ---
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 0, -4), &"canopy", O_FORWARD)
	_put(g, Vector3i(-2, 0, -3), &"hull_wedge", O_PORT_FWD)
	_put(g, Vector3i(2, 0, -3), &"hull_wedge", O_STARBOARD_FWD)
	# The helm sits in the front row, facing the windshield: the cockpit pod
	# juts out through the canopy face ahead of it (cockpit pod spec §7).
	# The bridge computer's holo table in the port front corner, beside the
	# helm, facing aft toward where you stand to use it: you look forward
	# over it, out of the shoulder window (bridge computer spec §3.2, as
	# amended 2026-09-27). The corner's console goes to the back corner
	# (InteriorLayout._handed_consoles).
	_put(g, Vector3i(-1, 0, -3), InteriorLayout.COMPUTER_ID, O_STERN)
	_put(g, Vector3i(0, 0, -3), &"pilot_seat")
	_put(g, Vector3i(1, 0, -3), &"deck")
	for z in [-2, -1, 0, 1, 2]:
		_put(g, Vector3i(-2, 0, z), &"hull")
		_put(g, Vector3i(2, 0, z), &"hull")
	# The quantum core stands at the bridge's centre, straight behind the
	# helm, facing aft so its gauge faces the corridor (quantum energy spec
	# §5.3); the quantum machine stands in the bridge's starboard back
	# corner, facing forward with its back to the galley's wall.
	_put(g, Vector3i(-1, 0, -2), &"deck")
	_put(g, Vector3i(0, 0, -2), &"quantum_core", O_STERN)
	_put(g, Vector3i(1, 0, -2), &"deck")
	_put(g, Vector3i(-1, 0, -1), &"deck")
	_put(g, Vector3i(0, 0, -1), &"deck")
	_put(g, Vector3i(1, 0, -1), &"quantum_machine", O_FORWARD)
	# Behind the bridge, a corridor down the centreline with rooms either side
	# (interior redesign spec §7.5). Room blocks weigh and draw what deck
	# does, so the flight balance measured below is unchanged.
	for z in [0, 1, 2]:
		_put(g, Vector3i(0, 0, z), &"deck")
	_put(g, Vector3i(-1, 0, 0), &"bunk_room")
	_put(g, Vector3i(-1, 0, 1), &"bunk_room")
	_put(g, Vector3i(-1, 0, 2), &"bathroom")
	_put(g, Vector3i(1, 0, 0), &"galley")
	_put(g, Vector3i(1, 0, 1), &"weapon_room")
	_put(g, Vector3i(1, 0, 2), &"closet")
	_put(g, Vector3i(-2, 0, 3), &"hull")
	_put(g, Vector3i(-1, 0, 3), &"bulkhead")
	_put(g, Vector3i(0, 0, 3), &"airlock")
	_put(g, Vector3i(1, 0, 3), &"bulkhead")
	_put(g, Vector3i(2, 0, 3), &"hull")

	# --- y = 0, engine pods (art direction §3.3): x = +-3 ---
	for x in [-3, 3]:
		_put(g, Vector3i(x, 0, 1), &"hull")
		_put(g, Vector3i(x, 0, 2), &"hull")
		_put(g, Vector3i(x, 0, 3), &"thruster", O_FORWARD)

	# --- y = 1, equipment deck and roof (art direction §3.2) ---
	_put(g, Vector3i(0, 1, -4), &"hull_wedge", O_FORWARD)
	_put(g, Vector3i(-1, 1, -3), &"hull_wedge", O_FORWARD)
	_put(g, Vector3i(1, 1, -3), &"hull_wedge", O_FORWARD)
	_put(g, Vector3i(0, 1, -3), &"hull")
	_put(g, Vector3i(-2, 1, -2), &"rcs", O_STERN)
	_put(g, Vector3i(2, 1, -2), &"rcs", O_STERN)
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 1, -2), &"hull")
	for x in [-2, -1, 1, 2]:
		_put(g, Vector3i(x, 1, -1), &"hull")
	_put(g, Vector3i(0, 1, -1), &"core")
	for x in [-2, 2]:
		_put(g, Vector3i(x, 1, 0), &"hull")
	# Quantum cell row: spec §3.2 places two (x=-1,+1). A third, centred at
	# x=0, was added here -- see the block below on power and pitch
	# balance for why. These three were reactors; the quantum core now
	# generates the ship's power, and the cells keep their mass and hp,
	# storing QE instead (quantum energy spec §5.1, §5.3).
	_put(g, Vector3i(-1, 1, 0), &"quantum_cell")
	_put(g, Vector3i(0, 1, 0), &"quantum_cell")
	_put(g, Vector3i(1, 1, 0), &"quantum_cell")
	for x in [-2, 2]:
		_put(g, Vector3i(x, 1, 1), &"hull")
	_put(g, Vector3i(0, 1, 1), &"hull")
	_put(g, Vector3i(-1, 1, 1), &"grav_plating")
	_put(g, Vector3i(1, 1, 1), &"grav_plating")
	for x in [-2, -1, 0, 1, 2]:
		_put(g, Vector3i(x, 1, 2), &"hull")
	_put(g, Vector3i(-2, 1, 3), &"hull_wedge", O_STERN)
	_put(g, Vector3i(2, 1, 3), &"hull_wedge", O_STERN)
	# Stern roof (x=-1,0,1 at z=+3) is spec'd as plain hull. Converted to
	# a second thruster bank instead -- see the note below.
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 1, 3), &"thruster", O_FORWARD)

	# --- Additions beyond art direction §3, all load-bearing on the
	# blueprint's acceptance criteria (§3.4) rather than decorative:
	#
	# 1. RCS thrust authority. §3 places no RCS blocks anywhere, so as
	#    literally specified the ship has thrust only along -Z (both main
	#    pods fire straight aft) and ShipStats reads torque_budget from
	#    the X/Y-thrusting blocks only. Zero RCS means zero rotational
	#    authority: FlightComputer could not turn the ship at all,
	#    mouse-steering included. Six RCS units sit in cells the nose
	#    taper otherwise leaves empty, each face-adjacent to an
	#    already-placed block so Rule 2 (ALL_CONNECTED) still holds.
	#
	#    They are laid out in opposed pairs, which ShipStats requires:
	#    authority you only have one way is not authority, so each axis
	#    counts the smaller of its two directions. Two lateral units at
	#    the nose (one thrusting +X, one -X) give yaw both ways. Four
	#    vertical units -- UP at z=-3, DOWN at z=-4, mirrored port and
	#    starboard -- give pitch both ways, and, fired differentially
	#    across the 8 m between them, roll both ways too. An earlier
	#    layout had a single UP and a single DOWN unit on opposite sides:
	#    both rolled the ship the *same* way, so roll authority was
	#    effectively nil.
	#
	# 1b. Braking. Every main engine faces aft, so thrust_budget.reverse
	#    was 0: S did nothing and, once burning, the ship could never be
	#    slowed or stopped. Two RCS units at (+-2, 1, -2), thrusting +Z,
	#    are the retro pair -- 500 kN, which stops the shuttle from its
	#    2-second sprint speed of 32 m/s in about 6 s. They also give the
	#    assist's drift correction something to spend along Z, which is
	#    what cancels residual drift when the stick is centred.
	#
	# 2. Pitch balance. §3.4 flags the real risk directly: mounting both
	#    main thrusters at y=0 while the equipment deck's mass sits at
	#    y=+1 puts the centre of mass well above the thrust line, so full
	#    forward burn induces a large pitch torque. Measured on this exact
	#    grid at y=0-only thrust: torque_imbalance.x = 686,582 N*m against
	#    a pitch authority (torque_budget.x) of only 160,000 N*m from the
	#    two vertical RCS above -- nowhere near flyable. §3.4 explicitly
	#    sanctions "moving equipment-deck mass or the pod row" to fix
	#    this; the stern roof's three hull cells became a second thruster
	#    bank instead (thrust higher, closer to the mass-weighted centre),
	#    which alone brought it to -14,371 N*m. The nose RCS trim the
	#    remainder: the grid then sat at +101,408 N*m, 3% of its own pitch
	#    authority, so the assist held the nose through a full burn.
	#
	# 2b. The quantum core (quantum energy spec §5.1, §5.3, §5.4), added at
	#    y=0 in the cabin itself rather than on the equipment deck, brings
	#    the imbalance closer to zero rather than adding to it. Its 5 t sit
	#    at cabin level, pulling the centre of mass down from 1.268 m to
	#    1.206 m -- almost exactly the 1.2 m average height of the ship's
	#    thrust (two nose pods at 0 m, three stern thrusters at 2 m). A full
	#    burn now barely pitches the ship at all: torque_imbalance.x falls
	#    from 101,408 to 9,278 N*m, well under 1% of pitch authority. The
	#    quantum machine, standing starboard against the galley's wall,
	#    introduces the only yaw imbalance the starter has: 3,093 N*m,
	#    0.15% of yaw authority -- still negligible.
	#
	# 2c. The bridge computer (bridge computer spec §3.2), a 0.3 t holo table
	#    in the port front corner, replaced a 0.4 t deck cell: the ship is
	#    100 kg lighter, and the centre of mass edges 2 mm to starboard, so
	#    the yaw imbalance doubles to 6,192 N*m -- 0.3% of yaw authority,
	#    still negligible. Pitch moves to 11,146 N*m, 0.36% of authority.
	#
	# 3. Power margin. The extra stern thrusters draw 9.0 MW more than
	#    §3.4's two-reactor estimate covers (that estimate assumed four
	#    thrusters total, not five). Three reactors restored comfortable
	#    margin; the quantum core now generates all 36 MW of it alone, and
	#    the quantum machine's own draw (0.5 MW) is the only change to the
	#    load side.
	#
	# Real numbers for this exact grid (via ShipStats/ShipValidator,
	# res://data/blocks catalog), with the quantum core, the machine and the
	# bridge computer aboard, the reactors replaced by quantum cells (quantum
	# energy spec §5.4; bridge computer spec §3.2) and the 26 fairings of the
	# shape below (ship exterior spec §8):
	# 110 blocks, 104,700 kg, center_of_mass = (0.004, 1.301, 0.160),
	# inertia = (2065526, 2865503, 1175422),
	# torque_budget = (3080229, 2040115, 2174785),
	# torque_imbalance = (151289, -5731, 0): pitch 4.9%, yaw 0.3%, roll 0%
	# of authority,
	# thrust_budget forward/reverse/lateral/vertical = 1500/500/500/1000 kN,
	# power_gen = 36.0 MW (all from the quantum core), power_draw = 31.3 MW,
	# quantum_capacity = 1200 QE, zero validation issues, can_launch = true.
	# The fairings add 7.8 t and no power draw. Before them the ship was
	# 96,900 kg with the centre of mass at y = 1.207 and pitch imbalance of
	# 11,146 N*m (0.4%): 6.0 t of spine and fins sit above the cabin and only
	# the 1.8 t keel below it, so the centre of mass rose 9 cm. Handling under
	# assist is a little slower: torque_budget / inertia is pitch 1.49, yaw
	# 0.71, roll 1.85 rad/s^2 (1.60 / 0.74 / 2.05 before), and forward,
	# reverse and lateral thrust per tonne fall from 15.5 / 5.2 / 5.2 to
	# 14.3 / 4.8 / 4.8 m/s^2. A full burn still holds the nose. See
	# task-1-report.md and task-15-report.md for the earlier derivations.
	_put(g, Vector3i(-1, 1, -4), &"rcs", O_RCS_STARBOARD)
	_put(g, Vector3i(1, 1, -4), &"rcs", O_RCS_PORT)
	_put(g, Vector3i(-2, 1, -3), &"rcs", O_RCS_UP)
	_put(g, Vector3i(2, 1, -3), &"rcs", O_RCS_UP)
	_put(g, Vector3i(-2, 1, -4), &"rcs", O_RCS_DOWN)
	_put(g, Vector3i(2, 1, -4), &"rcs", O_RCS_DOWN)

	# --- The shape (ship exterior spec §8): fairings, 0.3 t each, all outside
	# the cabin row, so nothing inside moves. A dorsal spine a metre high,
	# ramped up out of the roof toward the bow and down again over the stern
	# bank; a fin rising aft on each engine pod; and a keel under the
	# centreline for the floods to hang from.
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1, 2]:
			_put(g, Vector3i(x, 2, z), &"fairing_half")
		_put(g, Vector3i(x, 2, -2), &"fairing_slope_long_low", O_FORWARD)
		_put(g, Vector3i(x, 2, 3), &"fairing_slope_long_low", O_STERN)
	for x in [-3, 3]:
		_put(g, Vector3i(x, 1, 1), &"fairing_slope", O_FORWARD)
	for z in [-3, -2, -1, 0, 1, 2]:
		_put(g, Vector3i(0, -1, z), &"fairing_half", O_KEEL)

	return g

## Stands you on the starter's deck to begin with (see _deck_spot). The
## avatar's scene position was authored for the hand-built room; deriving it
## from the grid survives blueprint edits. The seat places itself
## (Ship._place_seat).
func _place_avatar_on_deck() -> void:
	if _starter.helm_cell() == null:
		return
	_avatar.position = _deck_spot(_starter).origin

## Where you stand on `ship`'s deck to start, in its interior's frame: the first
## walkable cell aft of its helm that holds no fixture, or the helm's own cell
## (quantum energy spec §5.3, §6.1). A MOUNT block, like the quantum core,
## still fills its cell's floor though the cell is walkable.
func _deck_spot(ship: Ship) -> Transform3D:
	var helm: Variant = ship.helm_cell()
	if helm == null:
		return Transform3D.IDENTITY
	var cell: Vector3i = helm
	var probe: Vector3i = cell + Vector3i(0, 0, 1)
	while ship.grid.has_block(probe):
		var def := ship.catalog.get_def(ship.grid.get_block(probe).block_id)
		if def != null and def.is_walkable() and def.occupancy != BlockDefinition.Occupancy.MOUNT:
			cell = probe
			break
		probe += Vector3i(0, 0, 1)
	var centre := ShipGrid.cell_center(cell)
	return Transform3D(Basis.IDENTITY, Vector3(centre.x, InteriorBuilder.floor_y(cell) + 0.05, centre.z))

## Connects the HUD to this scene's ship.
##
## Done here rather than inside HudRoot on purpose: it keeps src/ui ignorant
## of Ship, CameraDirector and FlightComputer, which is what makes the HUD
## reusable for any future vehicle. The bootstrap is the only place that
## knows both halves.
func _wire_hud() -> void:
	# The cockpit's markers live in a ship's SubViewport, so they cannot be
	# discovered as HudRoot's descendants: board() registers those of the ship
	# you are aboard.
	# The hull (health and damage spec §11), in the band beside the store.
	var hull := HullPanel.new()
	hull.name = "HullPanel"
	$HudRoot/Screen/Band/Row.add_child(hull)
	_hud.register_element(hull)
	# The bootstrap is the one place that legitimately knows both halves of
	# this: the HUD's fade-in and the seat transition it is timed against.
	_hud.fade_in = CameraDirector.SIT_DURATION
	_director.piloting_changed.connect(_on_piloting_changed)
	# On a spacewalk the suit is the vehicle the HUD reports (airlock spec
	# §8.3): speed relative to the ship, and the way home.
	_avatar.mode_changed.connect(_on_avatar_mode_changed)

## The pilot's controls of the ship whose seat you took report the flight
## computer's telemetry plus the stick and the pointer (flight controls spec
## §7).
func _on_piloting_changed(piloting: bool) -> void:
	var ship := _director.seat_ship()
	_hud.set_active_vehicle(ship.pilot if piloting and ship != null else null)

func _on_avatar_mode_changed(mode: Avatar.Mode) -> void:
	if mode == Avatar.Mode.SUIT:
		_hud.set_active_vehicle(_avatar)
	elif not _director.is_seated:
		_hud.set_active_vehicle(null)

func _put(g: ShipGrid, coord: Vector3i, id: StringName, orientation: int = 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = orientation
	g.set_block(coord, i)
