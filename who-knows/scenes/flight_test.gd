extends Node3D

## Builds the starter shuttle -- the blueprint from
## docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md §3 --
## so flight_test.tscn always has a ship. Once the shipyard exists
## (Task 20) this loads a saved blueprint instead.

@onready var _ship: Ship = $Ship
@onready var _hud: HudRoot = $HudRoot
@onready var _director: CameraDirector = $Ship/CameraDirector
@onready var _cockpit_marker: VelocityMarker = $Ship/Canopy/CanopyOverlay/CockpitMarker

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
	_wire_hud()

func _starter_grid() -> ShipGrid:
	var g := ShipGrid.new()

	# --- y = 0, cabin (art direction §3.1): x -2..2, z -4..3 ---
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 0, -4), &"canopy", O_FORWARD)
	_put(g, Vector3i(-2, 0, -3), &"hull_wedge", O_PORT_FWD)
	_put(g, Vector3i(2, 0, -3), &"hull_wedge", O_STARBOARD_FWD)
	for x in [-1, 0, 1]:
		_put(g, Vector3i(x, 0, -3), &"deck")
	for z in [-2, -1, 0, 1, 2]:
		_put(g, Vector3i(-2, 0, z), &"hull")
		_put(g, Vector3i(2, 0, z), &"hull")
	_put(g, Vector3i(-1, 0, -2), &"deck")
	_put(g, Vector3i(0, 0, -2), &"pilot_seat")
	_put(g, Vector3i(1, 0, -2), &"deck")
	for z in [-1, 0, 1, 2]:
		for x in [-1, 0, 1]:
			_put(g, Vector3i(x, 0, z), &"deck")
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
	_put(g, Vector3i(-2, 1, -2), &"hull_wedge", O_FORWARD)
	_put(g, Vector3i(2, 1, -2), &"hull_wedge", O_FORWARD)
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
	#    pods fire straight aft) and ShipStats bins thrust_budget.lateral
	#    and .vertical -- and therefore torque_budget for every rotation
	#    axis -- from the X/Y components of thrusting blocks only. Zero
	#    RCS means zero rotational authority: FlightComputer could not
	#    turn the ship at all under assist, mouse-steering included. Four
	#    RCS units (2 lateral, 2 vertical) sit in cells the nose taper
	#    otherwise leaves empty, each face-adjacent to an already-placed
	#    block so Rule 2 (ALL_CONNECTED) still holds.
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
	#    which alone brought it to -14,371 N*m. Two more small
	#    forward-facing RCS units at the nose (cheap, 40 kN each, for fine
	#    trim) landed the final grid at -6,870 N*m -- 4% of pitch
	#    authority, and a 99% reduction from the naive layout.
	#
	# 3. Power margin. The extra stern thrusters draw 9.0 MW more than
	#    §3.4's two-reactor estimate covers (that estimate assumed four
	#    thrusters total, not five). A third reactor restores comfortable
	#    margin: 36.0 MW generated against 25.2 MW drawn.
	#
	# Real numbers for this exact grid (via ShipStats/ShipValidator,
	# res://data/blocks catalog): 84 blocks, 88,500 kg, center_of_mass =
	# (0, 1.236, 0.626), torque_budget = (160000, 160000, 160000),
	# torque_imbalance = (-6870, 0, 0), power_gen = 36.0 MW, power_draw =
	# 25.2 MW, zero validation issues, can_launch = true. See
	# task-15-report.md for the full derivation.
	_put(g, Vector3i(-1, 1, -4), &"rcs", O_RCS_STARBOARD)
	_put(g, Vector3i(1, 1, -4), &"rcs", O_RCS_PORT)
	_put(g, Vector3i(-2, 1, -3), &"rcs", O_RCS_UP)
	_put(g, Vector3i(2, 1, -3), &"rcs", O_RCS_DOWN)
	_put(g, Vector3i(-2, 1, -4), &"rcs", O_FORWARD)
	_put(g, Vector3i(2, 1, -4), &"rcs", O_FORWARD)

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
	var deck_surface := centre.y - ShipGrid.CELL_SIZE * 0.5 + InteriorBuilder.FLOOR_THICKNESS * 0.5
	$Ship/Interior/Avatar.position = Vector3(centre.x, deck_surface + 0.05, centre.z)

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
	_director.piloting_changed.connect(_on_piloting_changed)

func _on_piloting_changed(piloting: bool) -> void:
	_hud.set_active_vehicle(_ship.flight_computer if piloting else null)

func _put(g: ShipGrid, coord: Vector3i, id: StringName, orientation: int = 0) -> void:
	var i := BlockInstance.new()
	i.block_id = id
	i.orientation = orientation
	g.set_block(coord, i)
