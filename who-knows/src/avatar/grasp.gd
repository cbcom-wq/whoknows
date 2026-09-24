class_name Grasp
extends Node

## What is in your hands (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §7): taking, carrying, throwing,
## dropping and stowing. Logic only; Hands draws it by reading `mode`, `item`
## and `charge`.
##
## A WIELD item is frozen into `wield_socket` and tracks the aim exactly. A
## CARRY item stays a real rigid body, pulled toward a hold point in front of
## the eye by a force-limited impulse: it bumps into walls, heavy things lag
## and sag, and a snag makes you let go.
##
## It knows its holder only as a CharacterBody3D and a head, so anything with
## a body and a head could carry things.

signal changed
signal used(item: Item)
signal prompt_changed(text: String)

enum Mode { EMPTY, CARRYING, WIELDING }

## Head-local hold point; half the item's depth is added in front of it.
const HOLD_OFFSET := Vector3(0.0, -0.25, -0.45)
## How quickly a carried item closes on the hold point, in seconds.
const HOLD_RESPONSE := 0.1
## The most force a hold can use: a 12 kg crate follows snappily, a 40 kg one
## barely beats gravity and sags.
const HOLD_FORCE := 400.0
const TURN_RESPONSE := 0.15
const MAX_SPIN := 12.0
const SNAG_DISTANCE := 0.8
const SNAG_TIME := 0.3
const THROW_MIN := 3.0
const THROW_MAX := 12.0
const CHARGE_TIME := 0.8
const THROW_REF_KG := 5.0
const THROW_MASS_FLOOR := 0.35
## How far the hold point and the throwing hand draw back at full charge.
const WIND_BACK := 0.12
const STOW_RANGE := 0.5
## The Interactor's reach: how far off a wielded item can be aimed at a point.
const REACH := 2.5
## Longest a released item keeps ignoring its holder while they overlap.
const RELEASE_GRACE := 1.0
## How far short of a wall a wielded item is released.
const WALL_MARGIN := 0.15
## Where the right hand closes, head-local, until Hands provides a socket.
const DEFAULT_SOCKET := Vector3(0.17, -0.2, -0.42)
## interior_geometry | items.
const RAY_MASK := 2 | 32
const STOW_PROMPT := "[G] Stow"

var mode: Mode = Mode.EMPTY
var item: Item = null
## 0..1 while winding up a throw, -1 otherwise.
var charge := -1.0
var enabled := true
## Use and throw need the reticle, so they work only in first person.
var first_person := true
var wield_socket: Node3D
## Where released items go.
var world_root: Node3D

var _body: CharacterBody3D
var _head: Node3D
var _hold_basis := Basis.IDENTITY
var _snag := 0.0
var _releasing: Array = []   # [Item, seconds left]
var _prompt := ""

func bind(body: CharacterBody3D, head: Node3D, socket: Node3D = null) -> void:
	_body = body
	_head = head
	wield_socket = socket
	if wield_socket == null:
		wield_socket = Node3D.new()
		wield_socket.name = "WieldSocket"
		wield_socket.position = DEFAULT_SOCKET
		head.add_child(wield_socket)

func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		charge = -1.0
		if mode == Mode.CARRYING:
			_release()
			changed.emit()

func can_take(candidate: Item) -> bool:
	return enabled and mode == Mode.EMPTY and candidate != null and candidate.state != Item.State.HELD

func take(candidate: Item) -> bool:
	if not can_take(candidate) or candidate.definition.mass_kg > Item.LIFT_LIMIT_KG:
		return false
	if candidate.state == Item.State.STOWED and candidate.stow_point != null:
		candidate.stow_point.release()
	_end_grace(candidate)
	item = candidate
	_ignore(candidate, true)
	if candidate.definition.grip == ItemDefinition.Grip.WIELD:
		candidate.set_held(true)
		candidate.reparent(wield_socket, false)
		candidate.transform = Transform3D(Basis.IDENTITY, -candidate.definition.grip_point)
		mode = Mode.WIELDING
	else:
		candidate.set_held(false)
		_hold_basis = _body.global_basis.inverse() * candidate.global_basis
		_snag = 0.0
		mode = Mode.CARRYING
	charge = -1.0
	changed.emit()
	return true

func use() -> bool:
	if not enabled or not first_person or mode != Mode.WIELDING:
		return false
	if not item.use(aim(), world_root, _body):
		return false
	used.emit(item)
	return true

## The eye: origin at the head, -z along the view.
func aim() -> Transform3D:
	return _head.global_transform

func begin_throw() -> void:
	if enabled and first_person and mode != Mode.EMPTY:
		charge = 0.0
		changed.emit()

func finish_throw() -> void:
	if charge < 0.0:
		return
	var amount := charge
	charge = -1.0
	if mode != Mode.EMPTY:
		throw(amount)

## How fast a throw leaves the hand: charge sets the effort, and heavy things
## go slower, by the square root of how much heavier than 5 kg they are.
static func throw_speed(mass_kg: float, amount: float) -> float:
	var heft := clampf(sqrt(THROW_REF_KG / maxf(mass_kg, 0.001)), THROW_MASS_FLOOR, 1.0)
	return lerpf(THROW_MIN, THROW_MAX, clampf(amount, 0.0, 1.0)) * heft

func throw(amount: float) -> void:
	if mode == Mode.EMPTY:
		return
	var thrown := item
	var direction := -aim().basis.z
	_release()
	thrown.linear_velocity = direction * throw_speed(thrown.mass, amount) + _body.velocity
	changed.emit()

## Lets go, or stows the item if a fitting stow point is in range.
func drop() -> void:
	if mode == Mode.EMPTY:
		return
	var point := stow_target()
	var dropped := item
	_release()
	if point != null:
		_end_grace(dropped)
		point.secure(dropped)
	changed.emit()

## The free stow point a drop would put the held item in, or null.
func stow_target() -> StowPoint:
	if item == null or not is_inside_tree():
		return null
	var ref := item.global_position
	if mode == Mode.WIELDING:
		var eye := aim()
		var hit := _ray(eye.origin, eye.origin - eye.basis.z * REACH)
		if hit.is_empty():
			return null
		ref = hit["position"]
	var best: StowPoint = null
	var best_distance := STOW_RANGE
	for node in get_tree().get_nodes_in_group(StowPoint.GROUP):
		var point := node as StowPoint
		if point == null or not point.fits(item):
			continue
		var at := point.global_position if mode == Mode.WIELDING else point.item_transform(item).origin
		var distance := at.distance_to(ref)
		if distance < best_distance:
			best = point
			best_distance = distance
	return best

## Where a carried item is pulled to: ahead of and below the eye, drawn back
## while winding up a throw.
func hold_point() -> Vector3:
	var depth := item.definition.size.z * 0.5 if item != null else 0.0
	return aim() * (HOLD_OFFSET + Vector3(0.0, 0.0, -depth + WIND_BACK * maxf(charge, 0.0)))

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed(&"use"):
		use()
	elif event.is_action_pressed(&"throw"):
		begin_throw()
	elif event.is_action_released(&"throw"):
		finish_throw()
	elif event.is_action_pressed(&"drop"):
		drop()

func _physics_process(delta: float) -> void:
	if _body == null:
		return
	_tick_grace(delta)
	if item != null and not is_instance_valid(item):
		item = null
		mode = Mode.EMPTY
		changed.emit()
	if mode == Mode.CARRYING:
		_hold(delta)
	if charge >= 0.0:
		charge = minf(charge + delta / CHARGE_TIME, 1.0)
	_update_prompt()

func _hold(delta: float) -> void:
	var gap := hold_point() - item.global_position
	_snag = _snag + delta if gap.length() > SNAG_DISTANCE else 0.0
	if _snag >= SNAG_TIME:
		_release()
		changed.emit()
		return
	var want := gap / HOLD_RESPONSE + _body.velocity
	var impulse := (want - item.linear_velocity) * item.mass
	item.apply_central_impulse(impulse.limit_length(HOLD_FORCE * delta))
	var target := (_body.global_basis * _hold_basis).get_rotation_quaternion()
	var turn := target * item.global_basis.get_rotation_quaternion().inverse()
	if turn.w < 0.0:
		turn = -turn
	var angle := turn.get_angle()
	var spin := Vector3.ZERO
	if angle > 0.001:
		spin = turn.get_axis() * angle / TURN_RESPONSE
	item.angular_velocity = spin.limit_length(MAX_SPIN)

## Lets go: the item goes back into the world loose, still ignoring its
## holder until the two no longer overlap.
func _release() -> void:
	var it := item
	var wielded := mode == Mode.WIELDING
	item = null
	mode = Mode.EMPTY
	charge = -1.0
	if wielded:
		var at := _clear_point(it.global_position)
		it.reparent(world_root, true)
		it.global_position = at
	it.set_loose()
	if wielded:
		it.linear_velocity = _body.velocity
		it.angular_velocity = Vector3.ZERO
	_releasing.append([it, RELEASE_GRACE])

## The point on the way from the eye to `to` that a ray proves is clear.
func _clear_point(to: Vector3) -> Vector3:
	var from := aim().origin
	var hit := _ray(from, to)
	if hit.is_empty():
		return to
	return (hit["position"] as Vector3) + (from - to).normalized() * WALL_MARGIN

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var exclude: Array[RID] = [_body.get_rid()]
	if item != null:
		exclude.append(item.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, exclude)
	return _body.get_world_3d().direct_space_state.intersect_ray(query)

func _tick_grace(delta: float) -> void:
	for i in range(_releasing.size() - 1, -1, -1):
		var entry: Array = _releasing[i]
		var it: Item = entry[0]
		entry[1] -= delta
		if not is_instance_valid(it) or entry[1] <= 0.0 or not _overlaps_holder(it):
			_releasing.remove_at(i)
			if is_instance_valid(it):
				_ignore(it, false)

func _end_grace(it: Item) -> void:
	for i in range(_releasing.size() - 1, -1, -1):
		if _releasing[i][0] == it:
			_releasing.remove_at(i)
	_ignore(it, false)

func _overlaps_holder(it: Item) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = it.shape()
	query.transform = it.global_transform
	query.collision_mask = _body.collision_layer
	for hit in _body.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit["collider"] == _body:
			return true
	return false

func _ignore(it: Item, on: bool) -> void:
	if on:
		it.add_collision_exception_with(_body)
		_body.add_collision_exception_with(it)
	else:
		it.remove_collision_exception_with(_body)
		_body.remove_collision_exception_with(it)

func _update_prompt() -> void:
	var text := STOW_PROMPT if enabled and stow_target() != null else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
