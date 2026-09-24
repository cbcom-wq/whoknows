class_name Interactor
extends RayCast3D

## Points where the avatar looks. Anything in group "interactable" that
## implements `interact(actor)` and `prompt_text()` can be used. One that also
## implements `can_interact(actor)` is passed over while that returns false --
## an item, while your hands are full (hands-and-items spec §7.2). Whatever the
## avatar holds is never reported.
##
## The ray alone asks for a precise aim at a 9 cm mug, so when it is not on
## anything usable, the item nearest the line of sight is offered instead:
## within ASSIST_ANGLE of it, within reach, and in plain view (spec §7.2, as
## amended 2026-09-24). Looking straight at something still wins.

signal prompt_changed(text: String)

## interior_geometry | items (project.godot 3d_physics layers 2 and 6).
## RayCast3D defaults to mask 1 (exterior_hull) and would find nothing here.
const MASK := 2 | 32
## How far from the line of sight an item can be and still be offered.
const ASSIST_ANGLE := deg_to_rad(8.0)

var _current: Node = null
var _text := ""
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
	var hit := _usable(get_collider() if is_colliding() else null)
	if hit == null:
		hit = _item_near_the_line_of_sight()
	# A prompt can change while you look at the same thing -- an airlock panel's
	# Depressurize becomes Reverse mid-cycle -- so it is read every frame.
	var text := "" if hit == null else "[F] %s" % hit.prompt_text()
	if hit != _current or text != _text:
		_current = hit
		_text = text
		prompt_changed.emit(text)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current != null:
		_current.interact(owner)

func _usable(node: Object) -> Node:
	if node == null or not (node is Node) or not node.is_in_group("interactable"):
		return null
	if node.has_method(&"can_interact") and not node.can_interact(owner):
		return null
	return node

## The usable item closest to the line of sight: within ASSIST_ANGLE of it,
## widened by the item's own size, within reach, and not behind anything.
func _item_near_the_line_of_sight() -> Node:
	if not is_inside_tree():
		return null
	var eye := global_position
	var ray := global_basis * target_position
	var reach := ray.length()
	var forward := ray / reach
	var best: Node = null
	var best_off := INF
	for node in get_tree().get_nodes_in_group(Item.GROUP):
		var item := node as Item
		if item == null or _usable(item) == null:
			continue
		var to := item.global_position - eye
		var along := to.dot(forward)
		if along <= 0.0 or along > reach:
			continue
		var off := (to - forward * along).length()
		var size := item.definition.size
		var allowed := along * tan(ASSIST_ANGLE) + maxf(size.x, maxf(size.y, size.z)) * 0.5
		if off > allowed or off / along >= best_off:
			continue
		if _in_plain_view(eye, item):
			best = item
			best_off = off / along
	return best

func _in_plain_view(eye: Vector3, item: Item) -> bool:
	var exclude: Array[RID] = []
	if is_instance_valid(_ignored):
		exclude.append(_ignored.get_rid())
	var query := PhysicsRayQueryParameters3D.create(eye, item.global_position, MASK, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == item

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
