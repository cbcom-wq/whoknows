class_name HoseRope
extends RefCounted

## The hose's line (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §11.3) as pure maths: SEGMENTS pieces over LENGTH metres, verlet with
## damping and no gravity, pinned to the reel's anchor at one end and the
## nozzle's tail at the other. A rope, not a rod: a link is only ever pulled
## shorter, never pushed longer, so a slack line lies in a loop. Points are in
## whatever frame the caller keeps them (HoseLine's own).

const SEGMENTS := 40
const LENGTH := 30.0
## Velocity kept a tick: the line drifts, it never whips.
const DAMPING := 0.97
## Passes of the length constraint a tick.
const ITERATIONS := 6

var points := PackedVector3Array()
var _previous := PackedVector3Array()

func _init() -> void:
	points.resize(SEGMENTS + 1)
	_previous.resize(SEGMENTS + 1)

## One segment's length at rest, metres.
static func segment_length() -> float:
	return LENGTH / SEGMENTS

## How much line is out between two points, up to the whole of it: the HUD's
## *HOSE 12 M*.
static func paid_out(anchor: Vector3, tail: Vector3) -> float:
	return minf(anchor.distance_to(tail), LENGTH)

## Lays the line out straight from `anchor` to `tail`, at rest.
func reset(anchor: Vector3, tail: Vector3) -> void:
	for i in points.size():
		var p := anchor.lerp(tail, float(i) / SEGMENTS)
		points[i] = p
		_previous[i] = p

## One tick: the free points coast, both ends are pinned, then every link
## longer than a segment is drawn back in.
func step(anchor: Vector3, tail: Vector3, _delta: float) -> void:
	var last := points.size() - 1
	for i in range(1, last):
		var p := points[i]
		var v := (p - _previous[i]) * DAMPING
		_previous[i] = p
		points[i] = p + v
	points[0] = anchor
	_previous[0] = anchor
	points[last] = tail
	_previous[last] = tail
	var rest := segment_length()
	for _pass in ITERATIONS:
		for i in last:
			var d := points[i + 1] - points[i]
			var length := d.length()
			if length <= rest or length < 0.00001:
				continue
			var excess := d / length * (length - rest)
			var a_free := i > 0
			var b_free := i + 1 < last
			if a_free and b_free:
				points[i] += excess * 0.5
				points[i + 1] -= excess * 0.5
			elif a_free:
				points[i] += excess
			elif b_free:
				points[i + 1] -= excess
