class_name Curves
extends RefCounted

## Response curves for behaviour scores (docs/superpowers/specs/
## 2026-09-26-npc-foundation-design.md §7.2): each turns a need or a sense
## into a 0-1 score.

## 0 at a, 1 at b, straight between, clamped.
static func ramp(x: float, a: float, b: float) -> float:
	if is_equal_approx(a, b):
		return 1.0 if x >= b else 0.0
	return clampf((x - a) / (b - a), 0.0, 1.0)

## 0 at a, 1 at b, eased at both ends.
static func smooth(x: float, a: float, b: float) -> float:
	return smoothstep(a, b, x)

## 1 at or over t, else 0.
static func above(x: float, t: float) -> float:
	return 1.0 if x >= t else 0.0

static func inverse(x: float) -> float:
	return 1.0 - clampf(x, 0.0, 1.0)
