class_name HandPose
extends RefCounted

## One glove's pose (docs/superpowers/specs/2026-09-23-hands-and-items-design.md
## §8.3): how far each finger and the thumb curl, how far the fingers spread,
## and where the wrist is. Pure data; Glove applies it.
##
## Poses are written for the right hand in the Hands frame (the camera's: -z
## ahead, +x right, +y up). `mirrored()` gives the left. The presets are the
## starting point; they are tuned by rendering at eye height.

## Where the palm closes, glove-local: a wielded item's grip point goes here.
const PALM := Vector3(0.0, -0.025, -0.06)
## Where a wielded item's grip sits in the Hands frame.
const WIELD_SOCKET := Vector3(0.17, -0.2, -0.42)
## Where a two-handed item's near face sits in the Hands frame: centred, low
## enough to see past, between the hands.
const CARRY_SOCKET := Vector3(0.0, -0.34, -0.4)

const _MIRROR := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Vector3.ZERO)

## Index, middle, ring, little: 0 straight, 1 a fist.
var curl := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var thumb := 0.0
var spread := 0.0
## The glove in the Hands frame: origin at the wrist, fingers along -z, back
## of the hand +y.
var wrist := Transform3D.IDENTITY

static func make(curls: Array, thumb_curl: float, spread_amount: float, wrist_xf: Transform3D) -> HandPose:
	var p := HandPose.new()
	p.curl = PackedFloat32Array(curls)
	p.thumb = thumb_curl
	p.spread = spread_amount
	p.wrist = wrist_xf
	return p

static func blend(a: HandPose, b: HandPose, t: float) -> HandPose:
	var p := HandPose.new()
	for i in 4:
		p.curl[i] = lerpf(a.curl[i], b.curl[i], t)
	p.thumb = lerpf(a.thumb, b.thumb, t)
	p.spread = lerpf(a.spread, b.spread, t)
	p.wrist = a.wrist.interpolate_with(b.wrist, t)
	return p

## The same pose for the left hand: the wrist reflected through x = 0.
func mirrored() -> HandPose:
	return make(Array(curl), thumb, spread, _MIRROR * wrist * _MIRROR)

## Idle: fingers open and a little curled, low in the corner, as in the
## reference. Any more curl reads as a claw at eye height.
static func relaxed() -> HandPose:
	return make([0.12, 0.16, 0.2, 0.25], 0.15, 0.35,
		Transform3D(Basis.from_euler(Vector3(0.3, 0.15, -0.35)), Vector3(0.2, -0.2, -0.38)))

## The Interactor is on something you can take: open and spread.
static func reach() -> HandPose:
	return make([0.05, 0.05, 0.08, 0.1], 0.05, 1.0,
		Transform3D(Basis.from_euler(Vector3(0.35, 0.1, -0.3)), Vector3(0.19, -0.17, -0.44)))

## Carrying something `width` wide and `depth` deep: gripping its sides near
## the front, palms in, arms angled down out of the frame. The item's near face
## sits on CARRY_SOCKET, centred on it, so the hands close on its sides.
static func carry(width: float, depth: float) -> HandPose:
	var x := clampf(width * 0.5 + 0.035, 0.1, 0.28)
	return make([0.55, 0.55, 0.55, 0.55], 0.45, 0.25,
		Transform3D(Basis.from_euler(Vector3(0.5, 0.2, -1.3)),
			Vector3(x, CARRY_SOCKET.y, CARRY_SOCKET.z - depth * 0.3)))

## Wielding: closed round the grip, the index on the trigger if it has one.
## The wrist is placed so the palm lands on WIELD_SOCKET.
static func grip(trigger: bool) -> HandPose:
	var basis := Basis.from_euler(Vector3(0.0, 0.0, -1.35))
	return make([0.3 if trigger else 1.0, 1.0, 1.0, 1.0], 0.8, 0.0,
		Transform3D(basis, WIELD_SOCKET - basis * PALM))
