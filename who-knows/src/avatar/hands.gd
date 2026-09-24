class_name Hands
extends Node3D

## The first-person hands (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §8, as amended 2026-09-24): two suit
## gloves under the camera, posed from what Grasp holds, swaying with the look,
## bobbing with the walk, drifting with the ship's shove, kicked by recoil and
## tucked away from any wall close enough to swallow them. When something is
## taken they swipe it in: the hand reaches toward where it sat and draws it
## into the grip. Visuals only: Grasp decides what is held; Hands only moves
## things while they are in its sockets.
##
## A one-handed item hangs in `wield_socket` and a two-handed one in
## `carry_socket`, so either moves -- and hides -- with the hands.

const POSE_RATE := 12.0
const SWAY_GAIN := 0.6
const SWAY_RETURN := 8.0
const SWAY_MAX := deg_to_rad(3.0)
## Radians of bob phase per metre walked.
const BOB_RATE := 5.0
const BOB_SIDE := 0.005
const BOB_DROP := 0.008
const SHOVE_GAIN := 0.005
const SHOVE_MAX := 0.04
const TUCK_REACH := 0.75
const TUCK_SPAN := 0.4
const TUCK_BACK := 0.25
const TUCK_DOWN := 0.1
const RECOIL_BACK := 0.04
const RECOIL_TILT := deg_to_rad(6.0)
const RECOIL_TIME := 0.15
## A grab: the hand reaches toward what was taken and draws it in.
const GRAB_TIME := 0.3
## Farthest the hands reach out of their rest place during a grab.
const GRAB_REACH := 0.3
## Share of the grab spent reaching out, open-handed, before closing.
const GRAB_OPEN := 0.4
## interior_geometry | items.
const RAY_MASK := 2 | 32

var shown := true: set = set_shown
var wield_socket: Node3D
var carry_socket: Node3D
var right: Glove
var left: Glove
## 1 just after a shot, easing to 0.
var recoil := 0.0

var _root: Node3D
var _right_mount: Node3D
var _grasp: Grasp
var _avatar: Avatar
var _pose_r: HandPose
var _pose_l: HandPose
var _sway := Vector2.ZERO
var _last_look := Vector2.ZERO
var _bob_phase := 0.0
var _grab_item: Item = null
var _grab_from := Transform3D.IDENTITY
var _grab_rest := Transform3D.IDENTITY
var _grab_reach := Vector3.ZERO
var _grab_both := false
var _grab_t := 1.0

func _init() -> void:
	name = "Hands"
	_root = Node3D.new()
	_root.name = "Root"
	add_child(_root)
	_right_mount = Node3D.new()
	_right_mount.name = "RightMount"
	_root.add_child(_right_mount)
	right = Glove.new(1.0)
	_right_mount.add_child(right)
	left = Glove.new(-1.0)
	_root.add_child(left)
	wield_socket = Node3D.new()
	wield_socket.name = "WieldSocket"
	wield_socket.position = HandPose.WIELD_SOCKET
	_right_mount.add_child(wield_socket)
	carry_socket = Node3D.new()
	carry_socket.name = "CarrySocket"
	carry_socket.position = HandPose.CARRY_SOCKET
	_root.add_child(carry_socket)
	_pose_r = HandPose.relaxed()
	_pose_l = _pose_r.mirrored()
	right.apply(_pose_r)
	left.apply(_pose_l)

func bind(grasp: Grasp, avatar: Avatar) -> void:
	_grasp = grasp
	_avatar = avatar
	grasp.used.connect(func(_item: Item) -> void: recoil = 1.0)
	grasp.taken.connect(_on_taken)
	_last_look = _look()

## Whether a grab swipe is under way.
func grabbing() -> bool:
	return _grab_item != null

func set_shown(on: bool) -> void:
	shown = on
	visible = on

## The poses the hands are heading for: right, then left.
func target_poses() -> Array[HandPose]:
	var r := HandPose.relaxed()
	var l := HandPose.relaxed()
	if _grasp != null:
		match _grasp.mode:
			Grasp.Mode.WIELDING:
				r = HandPose.grip(_grasp.item.use_node != null)
			Grasp.Mode.CARRYING:
				var size := _grasp.item.definition.size
				r = HandPose.carry(size.x, size.z)
				l = r
			_:
				if _reaching():
					r = HandPose.reach()
					l = r
	# Early in a grab the grabbing hand is still open, reaching for it.
	if grabbing() and _grab_t < GRAB_OPEN:
		r = HandPose.reach()
		if _grab_both:
			l = r
	return [r, l.mirrored()]

## 0 in open space, rising to 1 as a wall comes within reach of the eye.
func tuck_amount() -> float:
	if not is_inside_tree():
		return 0.0
	var from := global_position
	var to := from - global_basis.z * TUCK_REACH
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, _exclude())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return clampf((TUCK_REACH - from.distance_to(hit["position"])) / TUCK_SPAN, 0.0, 1.0)

func _process(delta: float) -> void:
	var targets := target_poses()
	var t := 1.0 - exp(-POSE_RATE * delta)
	_pose_r = HandPose.blend(_pose_r, targets[0], t)
	_pose_l = HandPose.blend(_pose_l, targets[1], t)
	right.apply(_pose_r)
	left.apply(_pose_l)
	if grabbing():
		_grab_t = minf(_grab_t + delta / GRAB_TIME, 1.0)
	_root.transform = _root_motion(delta)
	_right_mount.transform = _mount_motion(delta)
	_draw_in()

func _root_motion(delta: float) -> Transform3D:
	var look := _look()
	var turn := Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y)
	_last_look = look
	_sway = (_sway - turn * SWAY_GAIN).lerp(Vector2.ZERO, 1.0 - exp(-SWAY_RETURN * delta))
	_sway = _sway.clamp(Vector2(-SWAY_MAX, -SWAY_MAX), Vector2(SWAY_MAX, SWAY_MAX))
	var offset := _bob(delta) + _shove()
	if _grasp != null and _grasp.mode == Grasp.Mode.CARRYING:
		offset.z += Grasp.WIND_BACK * maxf(_grasp.charge, 0.0)
	if _grab_both:
		offset += _reach_offset()
	var tuck := tuck_amount()
	offset += Vector3(0.0, -TUCK_DOWN * tuck, TUCK_BACK * tuck)
	return Transform3D(Basis.from_euler(Vector3(_sway.y, _sway.x, 0.0)), offset)

## Recoil and the wind-up act on the right hand only, pivoting about the grip
## so the muzzle rises.
func _mount_motion(delta: float) -> Transform3D:
	recoil = move_toward(recoil, 0.0, delta / RECOIL_TIME)
	var back := RECOIL_BACK * recoil
	if _grasp != null and _grasp.mode == Grasp.Mode.WIELDING:
		back += Grasp.WIND_BACK * maxf(_grasp.charge, 0.0)
	var reach := Vector3.ZERO if _grab_both else _reach_offset()
	var pivot := HandPose.WIELD_SOCKET
	return Transform3D(Basis.IDENTITY, pivot + Vector3(0.0, 0.0, back) + reach) \
		* Transform3D(Basis(Vector3.RIGHT, RECOIL_TILT * recoil), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)

## Starts a grab swipe for what Grasp just took from `from`.
func _on_taken(item: Item, from: Transform3D) -> void:
	_grab_item = item
	_grab_from = from
	_grab_rest = item.transform
	_grab_t = 0.0
	_grab_both = _grasp.mode == Grasp.Mode.CARRYING
	var rest := HandPose.CARRY_SOCKET if _grab_both else HandPose.WIELD_SOCKET
	var toward := _root.global_transform.affine_inverse() * from.origin - rest
	_grab_reach = toward.limit_length(GRAB_REACH)
	item.global_transform = from

## How far the grabbing hand is out of its rest place: out toward the item and
## back, over the swipe.
func _reach_offset() -> Vector3:
	if not grabbing():
		return Vector3.ZERO
	return _grab_reach * sin(PI * _grab_t)

## Eases a grabbed item from where it sat into the hand, and lets go of the
## swipe once it is home -- or at once if it has left the hands.
func _draw_in() -> void:
	if not grabbing():
		return
	if not is_instance_valid(_grab_item) or _grasp == null or _grasp.item != _grab_item:
		_end_grab()
		return
	if _grab_t >= 1.0:
		_grab_item.transform = _grab_rest
		_end_grab()
		return
	var home := (_grab_item.get_parent() as Node3D).global_transform * _grab_rest
	_grab_item.global_transform = _grab_from.interpolate_with(home, smoothstep(0.0, 1.0, _grab_t))

func _end_grab() -> void:
	_grab_item = null
	_grab_both = false
	_grab_t = 1.0

func _look() -> Vector2:
	if _avatar == null:
		return Vector2.ZERO
	return Vector2(_avatar.rotation.y, _avatar.head.rotation.x)

func _bob(delta: float) -> Vector3:
	if _avatar == null:
		return Vector3.ZERO
	var v := _avatar.velocity
	v.y = 0.0
	var speed := v.length()
	_bob_phase += speed * delta * BOB_RATE
	var amount := clampf(speed / Avatar.WALK_SPEED, 0.0, 1.0)
	return Vector3(sin(_bob_phase) * BOB_SIDE, -absf(cos(_bob_phase)) * BOB_DROP, 0.0) * amount

func _shove() -> Vector3:
	if _avatar == null or not is_inside_tree():
		return Vector3.ZERO
	return (global_basis.inverse() * _avatar.external_accel * SHOVE_GAIN).limit_length(SHOVE_MAX)

func _reaching() -> bool:
	return _avatar != null and _avatar.interactor != null and _avatar.interactor.current() is Item

func _exclude() -> Array[RID]:
	var out: Array[RID] = []
	if _avatar != null:
		out.append(_avatar.get_rid())
	if _grasp != null and _grasp.item != null:
		out.append(_grasp.item.get_rid())
	return out
