class_name PilotObjective
extends RefCounted

## What a pilot is trying to do, and when it is done (hostile ships spec §5.5):
## a small piece the ShipPilot holds and steps, so a new objective (Disable)
## drops in without touching the other layers. It keeps its target's id, never
## the node, and what it last saw as a direction, a velocity and a
## UniversePoint, never an engine position: the floating origin cannot move it.

## The pilot sets this to its Universe's `to_universe`; unset, last_seen()'s
## `at` is null.
var to_universe: Callable

var _id: StringName
## {dir, speed, at} from the last time the target was in contact, or {}.
var _last_seen := {}

func target_id() -> StringName:
	return _id

## The target, or null when it is gone or past contact range of `from`.
func target(tree: SceneTree, from: Vector3) -> Node3D:
	var node := Weapons.find(tree, _id)
	if node == null or from.distance_to(Weapons.point_of(node)) > WeaponValues.CONTACT_RANGE:
		return null
	return node

## Called by the pilot every tick it flies, done or not, from its own ship's
## position.
func step(_from: Vector3, _tree: SceneTree, _delta: float) -> void:
	pass

func done() -> bool:
	return false

func pursuing() -> bool:
	return false

## {dir: world direction from the pilot to the target, speed: the target's
## velocity, at: its UniversePoint or null}, or {} before it was ever seen.
func last_seen() -> Dictionary:
	return _last_seen

func to_dict() -> Dictionary:
	return {}

## An objective from its to_dict(), or null when the kind is unknown.
static func from_dict(d) -> PilotObjective:
	if not (d is Dictionary):
		return null
	match str(d.get("kind", "")):
		DestroyObjective.KIND:
			return DestroyObjective.read(d)
	return null

## Remembers where `node` is, seen from `from`.
func _see(node: Node3D, from: Vector3) -> void:
	var point := Weapons.point_of(node)
	_last_seen = {
		"dir": (point - from).normalized(),
		"speed": Weapons.velocity_of(node),
		"at": to_universe.call(point) if to_universe.is_valid() else null,
	}

func _seen_to_dict() -> Dictionary:
	if _last_seen.is_empty():
		return {}
	var at = _last_seen["at"]
	return {
		"dir": SaveCodec.vec3(_last_seen["dir"]),
		"speed": SaveCodec.vec3(_last_seen["speed"]),
		"at": SaveCodec.upoint(at) if at != null else null,
	}

func _seen_from_dict(d) -> void:
	if not (d is Dictionary) or d.is_empty():
		_last_seen = {}
		return
	var at = d.get("at")
	_last_seen = {
		"dir": SaveCodec.to_vec3(d.get("dir")),
		"speed": SaveCodec.to_vec3(d.get("speed")),
		"at": SaveCodec.to_upoint(at) if at != null else null,
	}
