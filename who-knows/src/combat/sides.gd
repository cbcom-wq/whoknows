class_name Sides
extends RefCounted

## Who is against whom (hostile ships spec §4): a ship is crew (yours: every
## ship spawned or loaded as before sides) or hostile, and the two are hostile
## to each other; a side never to itself. Only ships and you have a side.

const CREW := &"crew"
const HOSTILE := &"hostile"

static func hostile_to(a: StringName, b: StringName) -> bool:
	return (a == CREW and b == HOSTILE) or (a == HOSTILE and b == CREW)

## A hull's ship's side, a ship's own, crew for you (spec §4.2: on a
## spacewalk you count as crew), else &"".
static func side_of(node: Node) -> StringName:
	if node == null or not is_instance_valid(node):
		return &""
	if node is Ship:
		return (node as Ship).side
	if node is Avatar:
		return CREW
	var ship := Weapons._ship_of(node) as Ship
	return ship.side if ship != null else &""

## A saved side, crew when missing or unknown.
static func read(value) -> StringName:
	var s := StringName(str(value)) if value != null else CREW
	return s if s == CREW or s == HOSTILE else CREW
