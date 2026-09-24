class_name Interactor
extends RayCast3D

## Points where the avatar looks. Anything in group "interactable" that
## implements `interact(actor)` and `prompt_text()` can be used. One that also
## implements `can_interact(actor)` is passed over while that returns false --
## an item, while your hands are full (hands-and-items spec §7.2). Whatever the
## avatar holds is never reported: a carried crate sits right in front of the
## eye.

signal prompt_changed(text: String)

## interior_geometry | items (project.godot 3d_physics layers 2 and 6).
## RayCast3D defaults to mask 1 (exterior_hull) and would find nothing here.
const MASK := 2 | 32

var _current: Node = null
var _ignored: CollisionObject3D = null

func _ready() -> void:
	target_position = Vector3(0, 0, -2.5)
	collide_with_areas = true
	collision_mask = MASK

## What the ray is on and could use right now, or null.
func current() -> Node:
	return _current

func _physics_process(_delta: float) -> void:
	_ignore_held()
	var hit: Node = get_collider() if is_colliding() else null
	if hit != null and not hit.is_in_group("interactable"):
		hit = null
	if hit != null and hit.has_method(&"can_interact") and not hit.can_interact(owner):
		hit = null
	if hit != _current:
		_current = hit
		prompt_changed.emit("" if _current == null else "[F] %s" % _current.prompt_text())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current != null:
		_current.interact(owner)

func _ignore_held() -> void:
	var held: CollisionObject3D = null
	if owner != null and "grasp" in owner and owner.grasp != null:
		held = owner.grasp.item
	if held == _ignored:
		return
	if is_instance_valid(_ignored):
		remove_exception(_ignored)
	_ignored = held
	if held != null:
		add_exception(held)
