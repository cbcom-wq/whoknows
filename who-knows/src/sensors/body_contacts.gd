class_name BodyContacts
extends RefCounted

## The star, planets and moons, for the ship's sensors (the system skeleton
## spec §10): one exact contact per body, anywhere in the system, named. A
## sensor source: ShipSensors calls contacts() and contact(). Bodies never
## move, so each contact is made once.

## The whole system, and then some.
const RANGE := 400000.0
const PREFIX := "body:"
const KIND := &"body"

var _by_id := {}   # StringName -> Contact
var _all: Array[Contact] = []

func _init(system: SystemRecipe) -> void:
	for b in system.bodies:
		var c := Contact.new()
		c.id = id_of(b)
		c.kind = KIND
		c.label = b.name
		c.point = b.point
		c.precision = Contact.EXACT
		c.radius = b.radius
		_by_id[c.id] = c
		_all.append(c)

static func id_of(body: SystemBody) -> StringName:
	return StringName(PREFIX + String(body.id))

func contacts(focus: UniversePoint, range_m: float, _time: float) -> Array[Contact]:
	var reach := minf(range_m, RANGE)
	var out: Array[Contact] = []
	for c in _all:
		if c.point.minus(focus).length() - c.radius <= reach:
			out.append(c)
	return out

func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
	return _by_id.get(id)
