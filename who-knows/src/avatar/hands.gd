class_name Hands
extends Node3D

## The first-person hands (docs/superpowers/specs/
## 2026-09-23-hands-and-items-design.md §8): two suit gloves under the camera,
## posed from what Grasp holds, swaying with the look, bobbing with the walk,
## drifting with the ship's shove, kicked by recoil and tucked away from any
## wall close enough to swallow them. Visuals only: reads Grasp and the avatar
## and never changes either.
##
## A wielded item hangs in `wield_socket`, so it moves -- and hides -- with the
## hands.

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
## interior_geometry | items.
const RAY_MASK := 2 | 32

var shown := true: set = set_shown
var wield_socket: Node3D
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
	_pose_r = HandPose.relaxed()
	_pose_l = _pose_r.mirrored()
	right.apply(_pose_r)
	left.apply(_pose_l)

func bind(grasp: Grasp, avatar: Avatar) -> void:
	_grasp = grasp
	_avatar = avatar
	grasp.used.connect(func(_item: Item) -> void: recoil = 1.0)
	_last_look = _look()

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
	_root.transform = _root_motion(delta)
	_right_mount.transform = _mount_motion(delta)

func _root_motion(delta: float) -> Transform3D:
	var look := _look()
	var turn := Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y)
	_last_look = look
	_sway = (_sway - turn * SWAY_GAIN).lerp(Vector2.ZERO, 1.0 - exp(-SWAY_RETURN * delta))
	_sway = _sway.clamp(Vector2(-SWAY_MAX, -SWAY_MAX), Vector2(SWAY_MAX, SWAY_MAX))
	var offset := _bob(delta) + _shove()
	var carrying := _grasp != null and _grasp.mode == Grasp.Mode.CARRYING
	if carrying:
		offset.z += Grasp.WIND_BACK * maxf(_grasp.charge, 0.0)
	else:
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
	var pivot := HandPose.WIELD_SOCKET
	return Transform3D(Basis.IDENTITY, pivot + Vector3(0.0, 0.0, back)) \
		* Transform3D(Basis(Vector3.RIGHT, RECOIL_TILT * recoil), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)

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
