class_name Tether
extends RefCounted

## The hose's tether (docs/superpowers/specs/2026-09-24-quantum-energy-design.md
## §11.3): at the line's full length it holds you, removing outward velocity
## and drawing you back at PULL. Pure: the avatar passes in where the reel's
## anchor is this tick, read afresh, so a floating-origin shift never leaves
## it pulling toward a stale point.

## The pull back at full length, m/s^2.
const PULL := 1.0

## `vel` after one tick of being tied to `anchor` by a line `length` long,
## standing at `pos`. Slack inside the length changes nothing.
static func constrain(pos: Vector3, vel: Vector3, anchor: Vector3, length: float, delta: float) -> Vector3:
	var out := pos - anchor
	var distance := out.length()
	if distance < length or distance < 0.0001:
		return vel
	out /= distance
	var v := vel
	var outward := v.dot(out)
	if outward > 0.0:
		v -= out * outward
	return v - out * PULL * delta
