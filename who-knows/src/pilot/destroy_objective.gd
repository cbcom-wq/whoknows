class_name DestroyObjective
extends PilotObjective

## Destroy(target) (hostile ships spec §5.5): fight the target while it is in
## contact; when it leaves contact, pursue toward where it was last seen, and
## give up after PilotValues.PURSUE_FOR without it. A pilot that gave up holds
## station but is still hostile: its target back in contact is fought again.
## A target destroyed or freed (no node with its id left at all, not merely
## out of range) hands over to the nearest ship of the same side in contact,
## else the objective is done for good.

const KIND := "destroy"

## The side it fights: crew by default, and whatever side its target was the
## last time it saw it, so a crew pilot's Destroy retargets hostiles.
var against: StringName = Sides.CREW

var _clock := 0.0
var _pursuing := false
var _done := false
## Done by giving up, not for want of a target: its target can come back.
var _gave_up := false

func _init(id: StringName = &"") -> void:
	_id = id

func step(from: Vector3, tree: SceneTree, delta: float) -> void:
	var node := target(tree, from)
	if node != null:
		_engage(node, from)
	elif _done:
		return
	elif _exists(tree):
		_pursuing = true
		_clock += delta
		if _clock >= PilotValues.PURSUE_FOR:
			_pursuing = false
			_done = true
			_gave_up = true
	elif not retarget(tree, from):
		_pursuing = false
		_done = true
		_gave_up = false

func done() -> bool:
	return _done

func pursuing() -> bool:
	return _pursuing

## Takes the nearest usable ship of side `against` within contact range of
## `from`; false, and nothing changed, when there is none.
func retarget(tree: SceneTree, from: Vector3) -> bool:
	var best: Node3D = null
	var best_d := WeaponValues.CONTACT_RANGE
	for node in tree.get_nodes_in_group(Weapons.TARGETS):
		if not Weapons.usable(node) or not node is Node3D:
			continue
		if Weapons.kind_of(Weapons.id_of(node)) != &"ship" or Sides.side_of(node) != against:
			continue
		var d := from.distance_to(Weapons.point_of(node))
		if d <= best_d:
			best = node
			best_d = d
	if best == null:
		return false
	_id = Weapons.id_of(best)
	_engage(best, from)
	return true

func to_dict() -> Dictionary:
	return {
		"kind": KIND,
		"id": String(_id),
		"against": String(against),
		"pursuing": _pursuing,
		"clock": _clock,
		"done": _done,
		"gave_up": _gave_up,
		"last_seen": _seen_to_dict(),
	}

static func read(d: Dictionary) -> DestroyObjective:
	var o := DestroyObjective.new(StringName(str(d.get("id", ""))))
	o.against = Sides.read(d.get("against"))
	o._pursuing = bool(d.get("pursuing", false))
	o._clock = float(d.get("clock", 0.0))
	o._done = bool(d.get("done", false))
	o._gave_up = bool(d.get("gave_up", false))
	o._seen_from_dict(d.get("last_seen"))
	return o

func _engage(node: Node3D, from: Vector3) -> void:
	_see(node, from)
	_clock = 0.0
	_pursuing = false
	_done = false
	_gave_up = false
	var side := Sides.side_of(node)
	if side != &"":
		against = side

## Whether any node still carries its id: out of range or asleep, not gone.
func _exists(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group(Weapons.TARGETS):
		if is_instance_valid(node) and Weapons.id_of(node) == _id:
			return true
	return false
