class_name SuitTie
extends Node

## Which ship your suit belongs to on a spacewalk (docs/superpowers/specs/
## 2026-10-02-many-ships-design.md §4.3): the nearest, once it is
## SWITCH_MARGIN nearer than yours and within REACH, so floating between two
## ships never flicks the HUD back and forth. Your relative speed, the home
## marker and `aboard` follow it.

signal tied(ship: Ship)

const SWITCH_MARGIN := 10.0
const REACH := 500.0
const EVERY := 0.25

var fleet: Fleet
var avatar: Avatar
## The ship the suit belongs to now (a Callable returning a Ship).
var current: Callable

var _in := 0.0

func _physics_process(delta: float) -> void:
	_in -= delta
	if _in > 0.0:
		return
	_in = EVERY
	check()

## Ties the suit to a nearer ship if there is one, now.
func check() -> void:
	if avatar == null or fleet == null or avatar.mode != Avatar.Mode.SUIT:
		return
	var ships := fleet.awake()
	var gaps: Array[float] = []
	for ship in ships:
		gaps.append(gap(ship, avatar.global_position))
	var mine: Ship = current.call() if current.is_valid() else null
	var i := choose(ships.find(mine), gaps)
	if i >= 0 and ships[i] != mine:
		tied.emit(ships[i])

## How far `p` is from `ship`'s hull: from the middle of its bounds, less half
## their diagonal. Rough, and the same rough for every ship.
static func gap(ship: Ship, p: Vector3) -> float:
	var box := ship.exterior_builder.bounds()
	var centre := ship.exterior.global_transform * box.get_center()
	return maxf(p.distance_to(centre) - box.size.length() * 0.5, 0.0)

## Which of `gaps` the suit should belong to, given it belongs to `current` now
## (-1 for none): the nearest within REACH, if it beats yours by SWITCH_MARGIN.
static func choose(current: int, gaps: Array[float]) -> int:
	var nearest := -1
	for i in gaps.size():
		if nearest < 0 or gaps[i] < gaps[nearest]:
			nearest = i
	if nearest < 0 or nearest == current or gaps[nearest] > REACH:
		return current
	if current >= 0 and gaps[nearest] + SWITCH_MARGIN > gaps[current]:
		return current
	return nearest
