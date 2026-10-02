class_name Fleet
extends Node

## Every ship in the world (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §5.1): the one place that knows how many
## there are. It takes in the starter, spawns the rest from ship.tscn, gives
## each an interior slot and a name of its own, and lets them go.

signal joined(ship: Ship)
signal left(ship: Ship)

const SHIP_SCENE: PackedScene = preload("res://scenes/ship.tscn")
## The starter's name. The save's ship of that name is always built into the
## scene's own /Ship, and it is never removed (§6.2).
const STARTER := &"Ship"
## Interiors stand Ship.SLOT_SPACING apart on x: slot 15 is 30 km out, where a
## float still holds about 2 mm.
const MAX_SHIPS := 16

## Where spawned ships go in the tree (the flight scene), and their outside.
var home: Node
var outside: Node3D
var universe: Universe
## The ship you are aboard (a Callable returning a Ship): never removed.
var aboard: Callable
var max_ships := MAX_SHIPS
## The number the next spawned ship's name takes (Ship2, Ship3 ...). It only
## goes up, so a name is never used twice in one game: a droid's ledger record
## is named for its ship (§6.2).
var next_number := 2

var _ships: Array[Ship] = []

func ships() -> Array[Ship]:
	return _ships.duplicate()

## The ships that are awake: every one, until ships sleep.
func awake() -> Array[Ship]:
	return _ships.duplicate()

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
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.name = ship_name if ship_name != "" else _next_name()
	ship.interior_slot = _free_slot()
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
	left.emit(ship)
	ship.get_parent().remove_child(ship)
	ship.queue_free()
	return true

## The awake ship whose hull is nearest `point`, other than `except`; null if
## there is none.
func nearest(point: Vector3, except: Ship = null) -> Ship:
	var best: Ship = null
	var best_d := INF
	for ship in awake():
		if ship == except:
			continue
		var d := point.distance_to(ship.exterior.global_position)
		if d < best_d:
			best = ship
			best_d = d
	return best

func _next_name() -> String:
	var n := "Ship%d" % next_number
	next_number += 1
	while named(n) != null:
		n = "Ship%d" % next_number
		next_number += 1
	return n

## The lowest interior slot no ship holds.
func _free_slot() -> int:
	var used := {}
	for ship in _ships:
		used[ship.interior_slot] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot
