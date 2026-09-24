extends Node3D

## Builds the starter shuttle -- the blueprint from
## docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md §3 --
## so flight_test.tscn always has a ship. Once the shipyard exists
## (Task 20) this loads a saved blueprint instead.

@onready var _ship: Ship = $Ship
@onready var _hud: HudRoot = $HudRoot
@onready var _director: CameraDirector = $Ship/CameraDirector
@onready var _cockpit_marker: VelocityMarker = $Ship/Canopy/CanopyOverlay/CockpitMarker
@onready var _prompt: Label = $Prompt/Label
@onready var _interactor: Interactor = $Ship/Interior/Avatar/Head/Interactor
@onready var _avatar: Avatar = $Ship/Interior/Avatar

var _reticle: Reticle
var _interact_prompt := ""
var _grasp_prompt := ""

## The interior's own mood (spec §3.3): dim and warm, with bloom turning the
## thin lit strips into light. It goes on the interior camera, not the world,
## so the chase view and the canopy feed keep the WorldEnvironment's look.
const INTERIOR_ENVIRONMENT: Environment = preload("res://data/environments/ship_interior.tres")

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

func _ready() -> void:
	_ship.set_grid(_starter_grid())
	_place_avatar_on_deck()
	_set_interior_mood()
	_wire_hud()
	_wire_prompt()
	_wire_hands()

## The interior camera is also the seated camera -- CameraDirector moves it
## between head and seat -- so one assignment covers walking and flying.
func _set_interior_mood() -> void:
	var cam: Camera3D = $Ship/Interior/Avatar/Head/Camera3D
	cam.environment = INTERIOR_ENVIRONMENT

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

## Hands and items (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §7, §8, §10): what you let go of lands aboard this ship, and the reticle
## follows the view. Wired here so src/avatar and src/ui never learn about
## CameraDirector or Ship.
func _wire_hands() -> void:
	_avatar.grasp.world_root = _ship.items
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

func _starter_grid() -> ShipGrid:
	var g := ShipGrid.new()

	# --- y = 0, cabin (art direction §3.1): x -2..2, z -4..3 ---
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 0, -4), &"canopy", O_FORWARD)
	_put(g, Vector3i(-2, 0, -3), &"hull_wedge", O_PORT_FWD)
	_put(g, Vector3i(2, 0, -3), &"hull_wedge", O_STARBOARD_FWD)
	# The helm sits in the front row, facing the windshield: the cockpit pod
	# juts out through the canopy face ahead of it (cockpit pod spec §7).
	_put(g, Vector3i(-1, 0, -3), &"deck")
	_put(g, Vector3i(0, 0, -3), &"pilot_seat")
	_put(g, Vector3i(1, 0, -3), &"deck")
	for z in [-2, -1, 0, 1, 2]:
		_put(g, Vector3i(-2, 0, z), &"hull")
		_put(g, Vector3i(2, 0, z), &"hull")
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 0, -2), &"deck")
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 0, -1), &"deck")
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
	# Reactor row: spec §3.2 places two (x=-1,+1). A third, centred at
	# x=0, was added here -- see the block below on power and pitch
	# balance for why.
	_put(g, Vector3i(-1, 1, 0), &"reactor")
	_put(g, Vector3i(0, 1, 0), &"reactor")
	_put(g, Vector3i(1, 1, 0), &"reactor")
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
	#    remainder: the grid now sits at +101,408 N*m, 3% of its own pitch
	#    authority, so the assist holds the nose through a full burn.
	#
	# 3. Power margin. The extra stern thrusters draw 9.0 MW more than
	#    §3.4's two-reactor estimate covers (that estimate assumed four
	#    thrusters total, not five). A third reactor restores comfortable
	#    margin: 36.0 MW generated against 30.8 MW drawn.
	#
	# Real numbers for this exact grid (via ShipStats/ShipValidator,
	# res://data/blocks catalog): 84 blocks, 92,300 kg, center_of_mass =
	# (0, 1.268, 0.325), inertia = (1.82, 2.65, 1.06) million kg*m²,
	# torque_budget = (3162514, 2081257, 2183099), torque_imbalance =
	# (101408, 0, 0), thrust_budget forward/reverse/lateral/vertical =
	# 1500/500/500/1000 kN, power_gen = 36.0 MW, power_draw = 30.8 MW,
	# zero validation issues, can_launch = true. Measured handling under
	# assist: 58 deg/s pitch and roll, 45 deg/s yaw, each reached within a
	# second of full stick. See task-15-report.md for the original
	# derivation.
	_put(g, Vector3i(-1, 1, -4), &"rcs", O_RCS_STARBOARD)
	_put(g, Vector3i(1, 1, -4), &"rcs", O_RCS_PORT)
	_put(g, Vector3i(-2, 1, -3), &"rcs", O_RCS_UP)
	_put(g, Vector3i(2, 1, -3), &"rcs", O_RCS_UP)
	_put(g, Vector3i(-2, 1, -4), &"rcs", O_RCS_DOWN)
	_put(g, Vector3i(2, 1, -4), &"rcs", O_RCS_DOWN)

	return g

func _place_avatar_on_deck() -> void:
	# The avatar's scene position was authored for the hand-built room, whose
	# floor surface sat at local y = 0. Generated cells are centred on their
	# coordinate, so the deck surface is half a cell lower. Derive the spawn
	# from the grid instead of hardcoding it, so it survives blueprint edits.
	var seat := Vector3i.ZERO
	var found := false
	for coord in _ship.grid.coords():
		if _ship.grid.get_block(coord).block_id == &"pilot_seat":
			seat = coord
			found = true
			break
	if not found:
		return

	# Stand one cell aft of the seat when that cell exists, else on the seat.
	var cell := seat + Vector3i(0, 0, 1)
	if not _ship.grid.has_block(cell):
		cell = seat

	var centre := ShipGrid.cell_center(cell)
	var deck_surface := InteriorBuilder.floor_y(cell)
	$Ship/Interior/Avatar.position = Vector3(centre.x, deck_surface + 0.05, centre.z)

	# The interactable seat is the captain's chair the interior's dressing
	# draws, so take its transform from the same fixture frame -- out in the
	# cockpit pod when there is one -- rather than authoring it twice.
	# Hardcoding it in the scene is what let the collider and the blueprint
	# drift apart in the first place.
	$Ship/Interior/PilotSeat.transform = InteriorDressing.fixture_frame(_ship.interior_builder.layout(), seat)

## Connects the HUD to this scene's ship.
##
## Done here rather than inside HudRoot on purpose: it keeps src/ui ignorant
## of Ship, CameraDirector and FlightComputer, which is what makes the HUD
## reusable for any future vehicle. The bootstrap is the only place that
## knows both halves.
func _wire_hud() -> void:
	# The cockpit marker lives in the ship's SubViewport, so it cannot be
	# discovered as one of HudRoot's descendants.
	_hud.register_element(_cockpit_marker)
	# The bootstrap is the one place that legitimately knows both halves of
	# this: the HUD's fade-in and the seat transition it is timed against.
	_hud.fade_in = CameraDirector.SIT_DURATION
	_director.piloting_changed.connect(_on_piloting_changed)
	# On a spacewalk the suit is the vehicle the HUD reports (airlock spec
	# §8.3): speed relative to the ship, and the way home.
	_avatar.mode_changed.connect(_on_avatar_mode_changed)

func _on_piloting_changed(piloting: bool) -> void:
	_hud.set_active_vehicle(_ship.flight_computer if piloting else null)

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
