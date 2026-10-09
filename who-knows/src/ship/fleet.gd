class_name Fleet
extends Node

## Every ship in the world (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §5.1): the one place that knows how many
## there are. It takes in the starter, spawns the rest from ship.tscn, gives
## each an interior slot and a name of its own, and lets them go.

signal joined(ship: Ship)
signal left(ship: Ship)
signal slept(ship: Ship)
signal woke(ship: Ship)

const SHIP_SCENE: PackedScene = preload("res://scenes/ship.tscn")
## The starter's name. The save's ship of that name is always built into the
## scene's own /Ship, and it is never removed (§6.2).
const STARTER := &"Ship"
## Interiors stand GridHome.SLOT_SPACING apart on x: slot 15 is 30 km out, where a
## float still holds about 2 mm.
const MAX_SHIPS := 16
## A ship you are not aboard farther than this from the universe's focus
## sleeps; it wakes back inside WAKE_AT. The gap stops it toggling at the edge.
const SLEEP_AT := 20000.0
const WAKE_AT := 18000.0
const CHECK_EVERY := 1.0
## A sleeping ship's root is in this group: out of Universe.EXTERIOR_SPACE,
## held as a UniversePoint instead (CLAUDE.md, the floating origin).
const ASLEEP := &"ships_asleep"

## Where spawned ships go in the tree (the flight scene), and their outside.
var home: Node
var outside: Node3D
var universe: Universe
## The ship you are aboard (a Callable returning a Ship): never removed.
var aboard: Callable
var max_ships := MAX_SHIPS
## The interior slots, shared with every base (habitat modules spec §9.3).
var slots := InteriorSlots.new()
## The number the next spawned ship's name takes (Ship2, Ship3 ...). It only
## goes up, so a name is never used twice in one game: a droid's ledger record
## is named for its ship (§6.2).
var next_number := 2

var _ships: Array[Ship] = []
var _asleep: Dictionary = {}   # Ship -> {"at": UniversePoint, "turn": Basis, "v": Vector3, "w": Vector3}
var _check_in := 0.0

func _physics_process(delta: float) -> void:
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = CHECK_EVERY
	check_sleep()

func ships() -> Array[Ship]:
	return _ships.duplicate()

## The ships that are awake. Built by hand: filter() on a typed array hands
## back an untyped one.
func awake() -> Array[Ship]:
	var out: Array[Ship] = []
	for ship in _ships:
		if not _asleep.has(ship):
			out.append(ship)
	return out

func named(ship_name: StringName) -> Ship:
	for ship in _ships:
		if ship.name == ship_name:
			return ship
	return null

## Takes in a ship already in the tree: the starter the scene was authored with.
func adopt(ship: Ship) -> void:
	if _ships.has(ship):
		return
	_ships.append(ship)
	slots.take(ship.interior_slot)
	joined.emit(ship)

## A new ship built from `grid`, its hull at `place`, at rest; null past the
## cap. `stock` false leaves its shelves empty (a loaded game brings its own
## items); `ship_name` is its saved name and `launch` the layout it launched
## with, from a save. It is not your own until you board it.
func spawn(grid: ShipGrid, place: Transform3D, stock := true, ship_name := "",
		launch: ShipBlueprint = null) -> Ship:
	if _ships.size() >= max_ships:
		push_warning("Fleet: already %d ships, the most there can be" % max_ships)
		return null
	var slot := slots.claim()
	if slot < 0:
		push_warning("Fleet: no interior slot free")
		return null
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.name = ship_name if ship_name != "" else _next_name()
	ship.interior_slot = slot
	ship.outside_path = NodePath("../%s" % home.get_path_to(outside))
	ship.launch_blueprint = launch
	home.add_child(ship)
	ship.set_grid(grid, stock)
	ship.exterior.global_transform = place
	ship.exterior.linear_velocity = Vector3.ZERO
	ship.exterior.angular_velocity = Vector3.ZERO
	ship.set_own(false)
	_ships.append(ship)
	joined.emit(ship)
	return ship

## Lets `ship` go, freeing it and its slot. Refuses the starter and the ship
## you are aboard. True if it went.
func remove(ship: Ship) -> bool:
	if ship == null or not _ships.has(ship) or ship.name == STARTER:
		return false
	if aboard.is_valid() and aboard.call() == ship:
		return false
	_ships.erase(ship)
	_asleep.erase(ship)
	slots.release(ship.interior_slot)
	left.emit(ship)
	ship.get_parent().remove_child(ship)
	ship.queue_free()
	return true

## The awake ship whose hull is nearest `point`, other than `except` and any
## still arriving; null if there is none.
func nearest(point: Vector3, except: Ship = null) -> Ship:
	var best: Ship = null
	var best_d := INF
	for ship in awake():
		if ship == except or arriving(ship):
			continue
		var d := point.distance_to(ship.exterior.global_position)
		if d < best_d:
			best = ship
			best_d = d
	return best

func sleeping(ship: Ship) -> bool:
	return _asleep.has(ship)

## True while `ship` arrives out of warp (ship library spec §6.3): not yet a
## ship to board, remove, sleep, tie a suit to or save.
func arriving(ship: Ship) -> bool:
	return WarpArrival.of(ship.exterior) != null

## Why a save must wait on the fleet itself, or "": a ship still arriving.
func busy() -> String:
	for ship in awake():
		if arriving(ship):
			return "a ship arriving"
	return ""

## Where `ship` is in the universe, asleep or awake.
func place_of(ship: Ship) -> UniversePoint:
	if _asleep.has(ship):
		return _asleep[ship]["at"]
	return universe.to_universe(ship.exterior.global_position)

## Puts to sleep every ship past SLEEP_AT of the focus and wakes every one
## back inside WAKE_AT (many ships spec §5.1). The ship you are aboard never
## sleeps.
func check_sleep() -> void:
	if universe == null or not is_instance_valid(universe.focus):
		return
	var here := universe.to_universe(universe.focus.global_position)
	var mine: Ship = aboard.call() if aboard.is_valid() else null
	for ship in _ships:
		if ship == mine:
			if _asleep.has(ship):
				wake(ship)
			continue
		if arriving(ship):
			continue
		var d := place_of(ship).minus(here).length()
		if not _asleep.has(ship) and d > SLEEP_AT:
			sleep(ship)
		elif _asleep.has(ship) and d < WAKE_AT:
			wake(ship)

## Holds `ship` where it is, as a UniversePoint, with the velocities it had.
func sleep(ship: Ship) -> void:
	if _asleep.has(ship):
		return
	var hull := ship.exterior
	_hold(ship, {"at": universe.to_universe(hull.global_position), "turn": hull.global_basis,
		"v": hull.linear_velocity, "w": hull.angular_velocity})

## Asleep at `held`: out of the shift and of the worlds' ground, its puffs
## stopped so it never holds the shift, out of physics, its droid and sounds
## stopped, and hidden. A ship coasting when it fell asleep is found where it
## fell asleep.
func _hold(ship: Ship, held: Dictionary) -> void:
	_asleep[ship] = held
	ship.exterior.remove_from_group(Universe.EXTERIOR_SPACE)
	ship.exterior.remove_from_group(AsteroidStream.SPACE_ANCHOR)
	for p in ship.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).emitting = false
	# Its portal stops processing too, so it could not turn its view off.
	(ship.get_node("Canopy") as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	ship.add_to_group(ASLEEP)
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	ship.visible = false
	slept.emit(ship)

## Back where it was held, moving as it was.
func wake(ship: Ship) -> void:
	if not _asleep.has(ship):
		return
	var held: Dictionary = _asleep[ship]
	_asleep.erase(ship)
	var hull := ship.exterior
	hull.global_transform = Transform3D(held["turn"], universe.to_engine(held["at"]))
	ship.remove_from_group(ASLEEP)
	ship.process_mode = Node.PROCESS_MODE_INHERIT
	ship.visible = true
	hull.linear_velocity = held["v"]
	hull.angular_velocity = held["w"]
	hull.add_to_group(Universe.EXTERIOR_SPACE)
	hull.add_to_group(AsteroidStream.SPACE_ANCHOR)
	woke.emit(ship)

## Every ship's part of a save, each with its name (many ships spec §6.1). A
## sleeping ship's hull is where it is held, not an engine position.
func capture(universe_now: Universe) -> Array:
	var out := []
	for ship in _ships:
		var part := ship.to_dict(universe_now)
		part["name"] = String(ship.name)
		if _asleep.has(ship):
			var held: Dictionary = _asleep[ship]
			part["hull"] = {"at": SaveCodec.upoint(held["at"]), "turn": SaveCodec.basis(held["turn"]),
				"v": SaveCodec.vec3(held["v"]), "w": SaveCodec.vec3(held["w"])}
		out.append(part)
	return out

func to_dict() -> Dictionary:
	return {"next": next_number}

func from_dict(d: Dictionary) -> void:
	next_number = maxi(int(d.get("next", 2)), 2)

## Puts a loaded ship's hull back (§6.3): where the save had it, or asleep
## there when that is past SLEEP_AT of the origin, never placed far off in
## engine space.
func restore_hull(ship: Ship, part: Dictionary) -> void:
	var hull: Dictionary = part.get("hull", {})
	var at := SaveCodec.to_upoint(hull.get("at"))
	if at.minus(universe.origin).length() > SLEEP_AT:
		_hold(ship, {"at": at, "turn": SaveCodec.to_basis(hull.get("turn")),
			"v": SaveCodec.to_vec3(hull.get("v")), "w": SaveCodec.to_vec3(hull.get("w"))})
	else:
		ship.restore_hull(part, universe)

func _next_name() -> String:
	var n := "Ship%d" % next_number
	next_number += 1
	while named(n) != null:
		n = "Ship%d" % next_number
		next_number += 1
	return n
