class_name Glove
extends Node3D

## One suit glove (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §8.2), built from InteriorKit pieces in the house style: a sleeve and cuff,
## a palm with a padded back, four two-segment fingers and a two-segment
## thumb. Each segment hangs on its own pivot so it can curl. `side` is 1 for
## the right hand and -1 for the left, which is built mirrored.
##
## Glove-local frame: origin at the wrist, fingers along -z, back of the hand
## +y, palm -y.

const SOLID := InteriorKit.Batch.SOLID
## Runs InteriorKit's x-axis tubes along -z.
const _ALONG_Z := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))

const PALM_SIZE := Vector3(0.1, 0.035, 0.1)
## Finger positions across the knuckles, index first, for the right hand.
const FINGER_X: Array[float] = [-0.036, -0.012, 0.012, 0.036]
const FINGER_LENGTHS := [[0.046, 0.038], [0.05, 0.04], [0.046, 0.038], [0.036, 0.03]]
const FINGER_WIDTH := 0.021
const FINGER_THICK := 0.024
const THUMB_LENGTHS := [0.04, 0.034]
const THUMB_WIDTH := 0.026
## Radians each segment bends at full curl.
const CURL_MAX: Array[float] = [1.4, 1.5]
const THUMB_CURL_MAX: Array[float] = [0.9, 1.1]
## Radians between neighbouring fingers at full spread.
const SPREAD_MAX := 0.14

var side := 1.0

var _fingers: Array = []   # [[joint0, joint1], ...], index first
var _thumb: Array = []
var _thumb_rest := Basis.IDENTITY

func _init(side_sign := 1.0) -> void:
	side = side_sign
	name = "RightGlove" if side > 0.0 else "LeftGlove"
	_build()

func joint_count() -> int:
	return _fingers.size() * 2 + _thumb.size()

func apply(pose: HandPose) -> void:
	transform = pose.wrist
	for i in 4:
		var splay := (1.5 - i) * pose.spread * SPREAD_MAX * side
		var joints: Array = _fingers[i]
		(joints[0] as Node3D).basis = Basis(Vector3.UP, splay) * Basis(Vector3.RIGHT, -pose.curl[i] * CURL_MAX[0])
		(joints[1] as Node3D).basis = Basis(Vector3.RIGHT, -pose.curl[i] * CURL_MAX[1])
	(_thumb[0] as Node3D).basis = _thumb_rest * Basis(Vector3.RIGHT, -pose.thumb * THUMB_CURL_MAX[0])
	(_thumb[1] as Node3D).basis = Basis(Vector3.RIGHT, -pose.thumb * THUMB_CURL_MAX[1])

func _build() -> void:
	var suit := InteriorKit.solid(InteriorPalette.SUIT)
	var pad := InteriorKit.solid(InteriorPalette.SUIT_PAD)
	var hand := InteriorKit.new(self)
	hand.bevel_box(SOLID, InteriorKit.at(Vector3(0, 0, -0.05)), PALM_SIZE, 0.012, suit)
	hand.bevel_box(SOLID, InteriorKit.at(Vector3(0, 0.02, -0.055)), Vector3(0.082, 0.012, 0.07), 0.005, pad)
	# The cuff, a terracotta band, and a short sleeve running back toward the
	# eye, closed at both ends so you never see into it.
	hand.tube_x(SOLID, Transform3D(_ALONG_Z, Vector3(0, 0, 0.03)), 0.058, 0.06, suit)
	hand.tube_x(SOLID, Transform3D(_ALONG_Z, Vector3(0, 0, 0.045)), 0.06, 0.022, InteriorKit.solid(InteriorPalette.BELT))
	hand.tube_x(SOLID, Transform3D(_ALONG_Z, Vector3(0, 0, 0.13)), 0.052, 0.14, suit)
	hand.disc(SOLID, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.2)), 0.052, pad)
	hand.disc(SOLID, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 0.0)), 0.058, suit)
	hand.commit()
	for i in 4:
		_fingers.append(_digit(Vector3(FINGER_X[i] * side, 0.0, -0.1), Basis.IDENTITY,
			FINGER_LENGTHS[i], FINGER_WIDTH, suit, pad))
	_thumb_rest = Basis(Vector3.UP, 0.7 * side) * Basis(Vector3.BACK, -0.5 * side)
	_thumb = _digit(Vector3(-0.048 * side, -0.006, -0.035), _thumb_rest, THUMB_LENGTHS, THUMB_WIDTH, suit, pad)

## A finger or thumb: a pivot per segment, each segment a padded block hanging
## off it along -z. Returns the pivots, knuckle first.
func _digit(at: Vector3, rest: Basis, lengths: Array, width: float, suit: Color, pad: Color) -> Array:
	var joints: Array = []
	var parent: Node3D = self
	var offset := at
	var basis := rest
	for s in lengths.size():
		var length: float = lengths[s]
		var joint := Node3D.new()
		joint.name = "Joint%d" % s
		joint.transform = Transform3D(basis, offset)
		parent.add_child(joint)
		var kit := InteriorKit.new(joint)
		kit.bevel_box(SOLID, InteriorKit.at(Vector3(0, 0, -length * 0.5)), Vector3(width, FINGER_THICK, length),
			0.007, suit)
		kit.bevel_box(SOLID, InteriorKit.at(Vector3(0, FINGER_THICK * 0.5, -length * 0.5)),
			Vector3(width * 0.8, 0.008, length * 0.6), 0.003, pad)
		kit.commit()
		joints.append(joint)
		parent = joint
		offset = Vector3(0, 0, -length)
		basis = Basis.IDENTITY
	return joints
