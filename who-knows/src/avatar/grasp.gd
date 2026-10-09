class_name Grasp
extends Node

## What is in your hands (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §7, as amended 2026-09-24): taking,
## throwing, dropping and stowing. Logic only; Hands draws it by reading
## `mode`, `item` and `charge`.
##
## Whatever you take goes into your hands and stays there. A WIELD item
## (pistol, mug, canister) is frozen into the right hand's `wield_socket`; a
## CARRY item (a crate) is frozen into `carry_socket`, between both hands.
## Either moves and turns exactly with the view, out of the physics world
## until it is let go. Playtest showed the first design's physics hold for
## crates floated in front of you rather than sitting in your hands.
##
## It knows its holder only as a CharacterBody3D and a head, so anything with
## a body and a head could carry things.

signal changed
signal used(item: Item)
signal prompt_changed(text: String)
## An item was taken, from `from` (its global transform before it went into
## the hands). Hands swipes it in from there.
signal taken(item: Item, from: Transform3D)
## EVA cargo let go on a spacewalk (habitat modules spec §4.1): already in the
## space you are in. The holder makes it a stray.
signal let_go(item: Item)

enum Mode { EMPTY, CARRYING, WIELDING }

const THROW_MIN := 3.0
const THROW_MAX := 12.0
const CHARGE_TIME := 0.8
const THROW_REF_KG := 5.0
const THROW_MASS_FLOOR := 0.35
## How far the hands, and what they hold, draw back at full charge.
const WIND_BACK := 0.12
const STOW_RANGE := 0.5
## The Interactor's reach: how far off you can aim at a stow point.
const REACH := 2.5
## Longest a released item keeps ignoring its holder while they overlap.
const RELEASE_GRACE := 1.0
## How far short of a wall a released item's nearest face lands.
const WALL_MARGIN := 0.15
## Where the right hand closes, and where a two-handed item's near face sits,
## head-local, until Hands provides sockets.
const DEFAULT_WIELD_SOCKET := Vector3(0.17, -0.2, -0.42)
const DEFAULT_CARRY_SOCKET := Vector3(0.0, -0.34, -0.4)
## interior_geometry | items.
const RAY_MASK := 2 | 32
const STOW_PROMPT := "[G] Stow"

var mode: Mode = Mode.EMPTY
var item: Item = null
## 0..1 while winding up a throw, -1 otherwise.
var charge := -1.0
var enabled := true
## On a spacewalk (airlock spec §7.4): hold on to whatever you have, but take,
## drop, throw, stow and use nothing. Unlike set_enabled(false), which lets a
## carried crate go, this keeps it.
var suspended := false
## Use and throw need the reticle, so they work only in first person.
var first_person := true
## True while the held item's hold() is doing something.
var holding := false
var wield_socket: Node3D
var carry_socket: Node3D
## Where released items go.
var world_root: Node3D

var _body: CharacterBody3D
var _head: Node3D
var _releasing: Array = []   # [Item, seconds left]
var _prompt := ""

func bind(body: CharacterBody3D, head: Node3D, wield: Node3D = null, carry: Node3D = null) -> void:
	_body = body
	_head = head
	wield_socket = wield if wield != null else _socket(head, "WieldSocket", DEFAULT_WIELD_SOCKET)
	carry_socket = carry if carry != null else _socket(head, "CarrySocket", DEFAULT_CARRY_SOCKET)

## Why a save must wait (saving spec §5), or "": a throw winding up, or
## something just let go of that still ignores you.
func busy() -> String:
	if charge >= 0.0:
		return "throwing"
	if not _releasing.is_empty():
		return "letting go"
	if item != null and is_instance_valid(item) and item.use_node != null:
		return item.use_node.busy()
	return ""

## Whether the held item can be used now: in your own view and wielded aboard,
## or out on a spacewalk if it works there (health and damage spec §8.3); or
## carried EVA cargo, anywhere (habitat modules spec §4.1).
func can_use() -> bool:
	if not enabled or not first_person or item == null:
		return false
	if mode == Mode.CARRYING:
		return item.definition.eva_cargo
	return mode == Mode.WIELDING and (not suspended or item.definition.works_outside)

func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		charge = -1.0
		# A crate held in both hands cannot come to the pilot's seat.
		if mode == Mode.CARRYING:
			_release()
			changed.emit()

## Lets go of whatever is held, where it is, into `into` rather than
## world_root, suspended or not: blacking out (health and damage spec §7.2).
## Returns the item, or null.
func let_fall(into: Node3D) -> Item:
	if item == null:
		return null
	var it := item
	var was := world_root
	if into != null:
		world_root = into
	_release()
	world_root = was
	changed.emit()
	return it

## Lets go of held EVA cargo on a spacewalk, into the space you are in, where
## it floats (habitat modules spec §4.1). Null, holding on, for anything else.
func let_go_outside() -> Item:
	if not suspended or item == null or not item.definition.eva_cargo:
		return null
	var it := item
	var was := world_root
	world_root = use_world()
	_release()
	world_root = was
	it.set_space(true)
	changed.emit()
	let_go.emit(it)
	return it

func _active() -> bool:
	return enabled and not suspended

func can_take(candidate: Item) -> bool:
	return _active() and mode == Mode.EMPTY and candidate != null and candidate.state != Item.State.HELD

func take(candidate: Item) -> bool:
	if not can_take(candidate) or candidate.definition.mass_kg > Item.LIFT_LIMIT_KG:
		return false
	var from := candidate.global_transform
	if candidate.state == Item.State.STOWED and candidate.stow_point != null:
		candidate.stow_point.release()
	_end_grace(candidate)
	item = candidate
	candidate.consumed.connect(_on_held_consumed)
	_ignore(candidate, true)
	candidate.set_held()
	if candidate.definition.grip == ItemDefinition.Grip.WIELD:
		candidate.reparent(wield_socket, false)
		# Turned by its hold angle about its grip, which stays on the socket.
		var hold := Basis.from_euler(candidate.definition.hold_rotation * (PI / 180.0))
		candidate.transform = Transform3D(hold, -(hold * candidate.definition.grip_point))
		mode = Mode.WIELDING
	else:
		candidate.reparent(carry_socket, false)
		var tilt := Basis.from_euler(candidate.definition.hold_rotation * (PI / 180.0))
		candidate.transform = Transform3D(tilt, Vector3(0.0, 0.0, -candidate.definition.size.z * 0.5))
		mode = Mode.CARRYING
	charge = -1.0
	taken.emit(candidate, from)
	changed.emit()
	return true

func use() -> bool:
	if not can_use():
		return false
	if not item.use(aim(), use_world(), _body):
		return false
	used.emit(item)
	return true

## Where what you use acts: world_root aboard; on a spacewalk the space you
## are in, beside you, never the interior you left.
func use_world() -> Node3D:
	return _body.get_parent() as Node3D if suspended else world_root

## The eye: origin at the head, -z along the view.
func aim() -> Transform3D:
	return _head.global_transform

func begin_throw() -> void:
	if _active() and first_person and mode != Mode.EMPTY:
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
	thrown.watch_first_impact(throw_speed(thrown.mass, amount))
	changed.emit()

## Lets go, or stows the item if you are aiming at a fitting stow point.
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

## The free stow point a drop would put the held item in: the fitting one
## nearest where you are looking, within STOW_RANGE of it. Null if none.
func stow_target() -> StowPoint:
	if item == null or not is_inside_tree():
		return null
	var eye := aim()
	var hit := _ray(eye.origin, eye.origin - eye.basis.z * REACH)
	if hit.is_empty():
		return null
	var ref: Vector3 = hit["position"]
	var best: StowPoint = null
	var best_distance := STOW_RANGE
	for node in get_tree().get_nodes_in_group(StowPoint.GROUP):
		var point := node as StowPoint
		if point == null or not point.fits(item):
			continue
		var distance := point.global_position.distance_to(ref)
		if distance < best_distance:
			best = point
			best_distance = distance
	return best

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed(&"use"):
		use()
		return
	if suspended and event.is_action_pressed(&"drop"):
		let_go_outside()
		return
	if not _active():
		return
	if event.is_action_pressed(&"throw"):
		begin_throw()
	elif event.is_action_released(&"throw"):
		finish_throw()
	elif event.is_action_pressed(&"drop"):
		drop()

func _physics_process(delta: float) -> void:
	if _body == null:
		return
	_tick_grace(delta)
	# A freed item compares equal to null, so test the mode, not the item.
	if mode != Mode.EMPTY and not is_instance_valid(item):
		_forget_freed()
	if charge >= 0.0:
		charge = minf(charge + delta / CHARGE_TIME, 1.0)
	holding = hold_now(delta, Input.is_action_pressed(&"use") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	_update_prompt()

## The held item's hold() while `use` is `pressed` (health and damage spec
## §8.3). Returns whether it did anything.
func hold_now(delta: float, pressed: bool) -> bool:
	if not pressed or not can_use() or item.use_node == null:
		return false
	return item.use_node.hold(item, aim(), use_world(), _body, delta)

## The held item was freed under us: empty hands.
func _forget_freed() -> void:
	item = null
	mode = Mode.EMPTY
	charge = -1.0
	changed.emit()

## The held item is being used up (Item.consume, a planted package): the hands
## let go of it now, before it is freed, so nothing reads a freed item.
func _on_held_consumed() -> void:
	item.consumed.disconnect(_on_held_consumed)
	_forget_freed()

## Lets go: the item goes back into the world loose, at a point a ray from the
## eye proves is clear of walls, still ignoring its holder until the two no
## longer overlap.
func _release() -> void:
	var it := item
	it.consumed.disconnect(_on_held_consumed)
	item = null
	mode = Mode.EMPTY
	charge = -1.0
	var size := it.definition.size
	var at := _clear_point(it.global_position, maxf(size.x, maxf(size.y, size.z)) * 0.5)
	it.reparent(world_root, true)
	it.global_position = at
	it.set_loose()
	it.linear_velocity = _body.velocity
	it.angular_velocity = Vector3.ZERO
	_releasing.append([it, RELEASE_GRACE])

## The point on the way from the eye to `to` that a ray proves is clear, far
## enough short of any wall for something `half_size` across.
func _clear_point(to: Vector3, half_size: float) -> Vector3:
	var from := aim().origin
	var hit := _ray(from, to)
	if hit.is_empty():
		return to
	return (hit["position"] as Vector3) + (from - to).normalized() * (WALL_MARGIN + half_size)

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
	var text := STOW_PROMPT if _active() and stow_target() != null else ""
	if text == "" and can_use() and item.use_node != null:
		text = item.use_node.aim_text(item, aim(), _body)
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)

static func _socket(parent: Node3D, socket_name: String, at: Vector3) -> Node3D:
	var socket := Node3D.new()
	socket.name = socket_name
	socket.position = at
	parent.add_child(socket)
	return socket
