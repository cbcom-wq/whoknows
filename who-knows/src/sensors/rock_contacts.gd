class_name RockContacts
extends RefCounted

## The big rocks the ship's sensors know about
## (docs/superpowers/specs/2026-09-25-bridge-computer-design.md §4.2): one
## exact contact per asteroid group's big rock within RANGE, read from the
## asteroid recipe, so nothing has to be loaded to be known. A sensor source:
## ShipSensors calls contacts() and contact().
##
## It reads the giant cells (5 km regions) round the focus's own and keeps
## them. Crossing into the next region reads one new slab of 169 and drops the
## far one. A rock someone has shoved stays where the recipe put it: salvage
## placement accepts the same (quantum energy spec §10.2).

const RANGE := 30000.0
## Regions either side of the focus's own that can hold a rock within RANGE:
## any further, and even its nearest point is 30 km away.
const REACH := 6
const PREFIX := "rock:"
const KIND := &"rock"

var _recipe: AsteroidRecipe
var _centre := Vector3i(2147483647, 2147483647, 2147483647)   # nothing read yet
var _by_cell: Dictionary = {}   # Vector3i -> Contact, or null for a region with no big rock
var _rocks: Array[Contact] = []   # the non-null values of _by_cell

## `start` must be the stream's, so the recipe keeps the same bubble clear.
func _init(world_seed: int, start: UniversePoint = null) -> void:
	_recipe = AsteroidRecipe.new(world_seed, start)

static func id_of(cell: Vector3i) -> StringName:
	return StringName("%s%d,%d,%d" % [PREFIX, cell.x, cell.y, cell.z])

func contacts(focus: UniversePoint, range_m: float, _time: float) -> Array[Contact]:
	_read_round(focus)
	var reach := minf(range_m, RANGE)
	var out: Array[Contact] = []
	for c in _rocks:
		if c.point.minus(focus).length() <= reach:
			out.append(c)
	return out

func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
	var text := String(id)
	if not text.begins_with(PREFIX):
		return null
	var parts := text.substr(PREFIX.length()).split(",")
	if parts.size() != 3 or not (parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int()):
		return null
	var cell := Vector3i(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
	return _by_cell[cell] if _by_cell.has(cell) else _read(cell)

## How many regions are held, for the cost check (spec §11).
func regions_read() -> int:
	return _by_cell.size()

func _read_round(focus: UniversePoint) -> void:
	var centre := AsteroidRecipe.cell_of(AsteroidRecipe.Tier.GIANT, focus)
	if centre == _centre:
		return
	var next := {}
	_rocks.clear()
	for dx in range(-REACH, REACH + 1):
		for dy in range(-REACH, REACH + 1):
			for dz in range(-REACH, REACH + 1):
				var cell := centre + Vector3i(dx, dy, dz)
				var c: Contact = _by_cell[cell] if _by_cell.has(cell) else _read(cell)
				next[cell] = c
				if c != null:
					_rocks.append(c)
	_by_cell = next
	_centre = centre

func _read(cell: Vector3i) -> Contact:
	var rocks := _recipe.cell_rocks(AsteroidRecipe.Tier.GIANT, cell)
	if rocks.is_empty():
		return null
	var rock: AsteroidRock = rocks[0]
	var c := Contact.new()
	c.id = id_of(cell)
	c.kind = KIND
	c.label = "ROCK"
	c.point = AsteroidRecipe.cell_corner(AsteroidRecipe.Tier.GIANT, cell).plus(rock.local)
	c.precision = Contact.EXACT
	# Half its largest side: what you'd call its surface, not the recipe's
	# looser bounding sphere.
	c.radius = maxf(rock.size.x, maxf(rock.size.y, rock.size.z)) * 0.5
	c.km = 0
	return c
