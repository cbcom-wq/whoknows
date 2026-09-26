class_name DroidLook
extends Node3D

## The maintenance droid as you see it (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §14.4): a squat drum on two wheels, a
## domed cap with a warm eye strip, one short arm. Its parts move: wheels turn
## with its speed, the arm works at a job, the cap tilts to look at you and
## jolts when it is startled, and the whole droid squats when it braces.
## Built from the interior kit, in the interior's palette, on render layer 2.

const WHEEL_TRACK := 0.2
const TILT := deg_to_rad(15.0)
const BRACE_DROP := 0.02
const ARM_SWING := deg_to_rad(35.0)
const ARM_RATE := 7.0
const EASE := 10.0

var action: StringName = &""
var _body: Node3D
var _cap: Node3D
var _arm: Node3D
var _wheels: Array[Node3D] = []
var _phase := 0.0
var _jolt := 0.0

## Builds its parts, each from the kit in its own frame.
func build(variety: float) -> void:
	_body = _part("Body", Transform3D.IDENTITY)
	var kit := InteriorKit.new(_body)
	NpcLooks.droid_body(kit, Transform3D.IDENTITY, variety)
	kit.commit()
	for side in [-1.0, 1.0]:
		var wheel := _part("Wheel", Transform3D(Basis.IDENTITY, Vector3(side * WHEEL_TRACK, NpcLooks.DROID_WHEEL_RADIUS, 0)))
		var wk := InteriorKit.new(wheel)
		NpcLooks.droid_wheel(wk, Transform3D.IDENTITY)
		wk.commit()
		_wheels.append(wheel)
	_cap = _part("Cap", Transform3D(Basis.IDENTITY, Vector3(0, NpcLooks.DROID_BODY_TOP, 0)))
	var ck := InteriorKit.new(_cap)
	NpcLooks.droid_cap(ck, Transform3D.IDENTITY, variety)
	ck.commit()
	_arm = _part("Arm", Transform3D(Basis.IDENTITY, NpcLooks.DROID_SHOULDER))
	var ak := InteriorKit.new(_arm)
	NpcLooks.droid_arm(ak, Transform3D.IDENTITY)
	ak.commit()

func _part(label: String, xf: Transform3D) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.transform = xf
	add_child(n)
	return n

## What it is doing now: &"polish", &"scan" and &"tidy" work the arm;
## &"notice" tilts the cap; &"startle" jolts it; &"brace" squats.
func act(p_action: StringName) -> void:
	if p_action == &"startle" and action != &"startle":
		_jolt = 1.0
	action = p_action

func _process(delta: float) -> void:
	var speed := 0.0
	var body := get_parent() as CharacterBody3D
	if body != null:
		var v := body.velocity
		speed = Vector2(v.x, v.z).length() * signf(-(body.global_basis.z).dot(v) + 0.0001)
	pose(delta, speed)

## Moves its parts for `delta` seconds at `speed` m/s (forward positive).
func pose(delta: float, speed: float) -> void:
	for wheel in _wheels:
		wheel.rotate_object_local(Vector3.RIGHT, -speed / NpcLooks.DROID_WHEEL_RADIUS * delta)
	var working := action == &"polish" or action == &"scan" or action == &"tidy"
	_phase += delta * ARM_RATE if working else 0.0
	var reach := sin(_phase) * ARM_SWING if working else 0.0
	var lift := -ARM_SWING if working else 0.0
	_arm.basis = _arm.basis.slerp(Basis(Vector3.RIGHT, lift + reach), minf(EASE * delta, 1.0))
	_jolt = maxf(_jolt - delta * 4.0, 0.0)
	var tilt := TILT if action == &"notice" else 0.0
	tilt -= _jolt * TILT * 1.5
	_cap.basis = _cap.basis.slerp(Basis(Vector3.RIGHT, tilt), minf(EASE * delta, 1.0))
	var squat := -BRACE_DROP if action == &"brace" else 0.0
	_body.position.y = lerpf(_body.position.y, squat, minf(EASE * delta, 1.0))
	_cap.position.y = NpcLooks.DROID_BODY_TOP + _body.position.y

func arm_basis() -> Basis:
	return _arm.basis

func cap_basis() -> Basis:
	return _cap.basis

func body_height() -> float:
	return _body.position.y
