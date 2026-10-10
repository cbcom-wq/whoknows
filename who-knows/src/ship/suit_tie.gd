class_name SuitTie
extends Node

## Which ship or base your suit belongs to on a spacewalk (many ships spec
## §4.3; habitat modules spec §5.5): the nearest, once it is SWITCH_MARGIN
## nearer than yours and within REACH, so floating between two homes never
## flicks the HUD back and forth. Your relative speed, the home marker and the
## flight scene's `home` follow it.

signal tied(home: GridHome)

const SWITCH_MARGIN := 10.0
const REACH := 500.0
const EVERY := 0.25

var fleet: Fleet
## Every base, whose awake ones a suit can belong to (habitat modules spec
## §5.5). Optional.
var bases: Bases
var avatar: Avatar
## The home the suit belongs to now (a Callable returning a GridHome).
var current: Callable

var _in := 0.0

func _physics_process(delta: float) -> void:
	_in -= delta
	if _in > 0.0:
		return
	_in = EVERY
	check()

## Ties the suit to a nearer ship or base if there is one, now.
func check() -> void:
	if avatar == null or fleet == null or avatar.mode != Avatar.Mode.SUIT:
		return
	# A ship still arriving out of warp is no ship to belong to yet, nor a base
	# still unfolding a base to belong to.
	var homes: Array[GridHome] = []
	for ship in fleet.awake():
		if not fleet.arriving(ship):
			homes.append(ship)
	if bases != null:
		for base in bases.awake():
			if base.unfolding < 0:
				homes.append(base)
	var gaps: Array[float] = []
	for h in homes:
		gaps.append(gap(h, avatar.global_position))
	var mine: GridHome = current.call() if current.is_valid() else null
	var i := choose(homes.find(mine), gaps)
	if i >= 0 and homes[i] != mine:
		tied.emit(homes[i])

## How far `p` is from `home`'s hull: from the middle of its bounds, less half
## their diagonal. Rough, and the same rough for every home.
static func gap(home: GridHome, p: Vector3) -> float:
	var box := home.exterior_builder.bounds()
	var centre := home.exterior.global_transform * box.get_center()
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
