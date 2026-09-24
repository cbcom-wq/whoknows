class_name FeltGravity
extends Area3D

## The interior's felt gravity (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §6): plating gravity plus the hull's
## shove, applied by the engine's own Area3D gravity override to every loose
## item inside. MotionCoupling sets it each tick from the numbers it shoves the
## avatar with, so you and a crate beside you feel the same thing.
##
## Also the interior's net: a LOOSE item that leaves every cell -- it tunnelled
## through a wall -- is put back where it last was inside, at rest.

## A change of felt gravity bigger than this wakes the bodies resting in it,
## which would otherwise sleep straight through a burn.
const WAKE_THRESHOLD := 0.5

var felt := Vector3.ZERO

var _woken_at := Vector3.ZERO
var _last_inside: Dictionary = {}   # instance id -> Vector3

func _init() -> void:
	collision_layer = 0
	collision_mask = Item.LAYER
	monitorable = false
	monitoring = true
	gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	gravity_point = false
	body_exited.connect(_on_body_exited)
	set_felt(Vector3.ZERO)

## One box `size` big centred on each of `centres`, replacing the last set.
func set_cells(centres: Array, size: Vector3) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.free()
	for centre: Vector3 in centres:
		var box := BoxShape3D.new()
		box.size = size
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = centre
		add_child(shape)

func cell_count() -> int:
	return get_children().filter(func(n): return n is CollisionShape3D).size()

func set_felt(accel: Vector3) -> void:
	felt = accel
	var g := accel.length()
	gravity = g if g > 0.0001 else 0.0
	if g > 0.0001:
		gravity_direction = accel / g
	if (accel - _woken_at).length() > WAKE_THRESHOLD:
		_woken_at = accel
		if is_inside_tree():
			for body in get_overlapping_bodies():
				if body is RigidBody3D and not body.freeze:
					body.sleeping = false

## Whether a point lies inside one of the cells.
func contains(point: Vector3) -> bool:
	var local := to_local(point)
	for child in get_children():
		var shape := child as CollisionShape3D
		if shape == null:
			continue
		var half := (shape.shape as BoxShape3D).size * 0.5
		var d := (local - shape.position).abs()
		if d.x <= half.x and d.y <= half.y and d.z <= half.z:
			return true
	return false

func _physics_process(_delta: float) -> void:
	# The engine refreshes overlaps after this runs, so a body that has just
	# left is still listed. Only a position truly inside is worth going back to.
	for body in get_overlapping_bodies():
		if body is Item and body.state == Item.State.LOOSE and contains(body.global_position):
			_last_inside[body.get_instance_id()] = body.global_position

func _on_body_exited(body: Node3D) -> void:
	var id := body.get_instance_id()
	var back: Variant = _last_inside.get(id)
	_last_inside.erase(id)
	if back == null or not (body is Item) or body.state != Item.State.LOOSE:
		return
	# Moving a body from inside a physics callback is unsafe; do it after.
	_put_back.call_deferred(body, back)

func _put_back(body: Item, at: Vector3) -> void:
	if not is_instance_valid(body) or body.state != Item.State.LOOSE or not body.is_inside_tree():
		return
	body.global_position = at
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
