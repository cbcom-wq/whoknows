class_name PlaceContacts
extends RefCounted

## The beacons of a system's named places (desert world spec §8.2): one exact
## contact per designed place with `beacon`, on the ground at the place, shown
## only while you are inside its world's well. A sensor source like
## BodyContacts: ShipSensors calls contacts() and contact(). Places never move,
## so each contact is made once.

const KIND := &"beacon"
const PREFIX := "place:"
## The beacon stands this far above the ground (m).
const MAST := 2.0

var _by_id := {}   # StringName -> Contact
var _all: Array[Contact] = []
## Each contact's world: its centre and how far its well reaches.
var _wells := {}   # StringName -> [UniversePoint, float]

func _init(system: SystemRecipe) -> void:
	for place in system.places():
		if not place.beacon:
			continue
		var body := system.body(place.body_id)
		if body == null or body.recipe == null:
			continue
		var dir := place.dir()
		var ground := body.radius + WorldTerrain.new(body.recipe).height_at(dir)
		var c := Contact.new()
		c.id = id_of(place)
		c.kind = KIND
		c.label = place.name
		c.point = body.point.plus(dir * (ground + MAST))
		c.precision = Contact.EXACT
		_by_id[c.id] = c
		_all.append(c)
		_wells[c.id] = [body.point, body.well_radius]

static func id_of(place: PlaceDesign) -> StringName:
	return StringName(PREFIX + String(place.id))

## Beacons whose world's well holds `focus`, whatever the range.
func contacts(focus: UniversePoint, _range_m: float, _time: float) -> Array[Contact]:
	var out: Array[Contact] = []
	for c in _all:
		var well: Array = _wells[c.id]
		if (well[0] as UniversePoint).minus(focus).length() <= well[1]:
			out.append(c)
	return out

func contact(id: StringName, _focus: UniversePoint, _time: float) -> Contact:
	return _by_id.get(id)
