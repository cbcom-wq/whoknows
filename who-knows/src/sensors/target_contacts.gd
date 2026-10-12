class_name TargetContacts
extends RefCounted

## Other ships and bases, for the ship's sensors (ship weapons spec §4.2): one
## exact contact each within WeaponValues.CONTACT_RANGE, kind &"ship" or
## &"base". Creatures are LifeContacts' life signs; loose items are left off,
## marked only by looking at them (§9.1). A sensor source: ShipSensors calls
## contacts() and contact().

const SHIP := &"ship"
const BASE := &"base"

var _own: Node
var _universe: Universe

## `own` is the ship's own hull, never its own contact.
func _init(own: Node, universe: Universe) -> void:
	_own = own
	_universe = universe

func contacts(focus: UniversePoint, range_m: float, time: float) -> Array[Contact]:
	var out: Array[Contact] = []
	if not _ready_to_look() or focus == null:
		return out
	var at := _universe.to_engine(focus)
	var reach := minf(range_m, WeaponValues.CONTACT_RANGE)
	for node in _own.get_tree().get_nodes_in_group(Weapons.TARGETS):
		var c := _contact_of(node as Node3D, at, reach, time)
		if c != null:
			out.append(c)
	return out

func contact(id: StringName, focus: UniversePoint, time: float) -> Contact:
	if not _ready_to_look() or focus == null:
		return null
	return _contact_of(Weapons.find(_own.get_tree(), id), _universe.to_engine(focus), WeaponValues.CONTACT_RANGE, time)

func _ready_to_look() -> bool:
	return _universe != null and is_instance_valid(_own) and _own.is_inside_tree()

func _contact_of(node: Node3D, at: Vector3, reach: float, time: float) -> Contact:
	if node == null or node == _own or not Weapons.usable(node):
		return null
	var kind := Weapons.kind_of(Weapons.id_of(node))
	if kind != SHIP and kind != BASE:
		return null
	var p := Weapons.point_of(node)
	if p.distance_to(at) > reach:
		return null
	var c := Contact.new()
	c.id = Weapons.id_of(node)
	c.kind = kind
	c.label = Weapons.label_of(node)
	c.point = _universe.to_universe(p)
	c.precision = Contact.EXACT
	c.taken = time
	c.fresh_for = ShipSensors.REFRESH_EVERY
	return c
