class_name WarpProfile
extends RefCounted

## How fast a warp goes (docs/superpowers/specs/2026-09-28-warp-design.md
## §5.3; the world scale spec §3.4): it takes BASE_TIME and a second more per
## PACE metres, rising from EDGE_SPEED to its peak over RAMP seconds, holding,
## and easing back down over the last RAMP. The peak is whatever makes the
## distance come out exact. Pure.
##
## PACE keeps the median trip about 30 s at the world scale's distances.

const BASE_TIME := 18.0
const PACE := 350000.0
const RAMP := 4.0
## The flight computer's top speed with the assist on: you leave and arrive
## at it.
const EDGE_SPEED := 120.0

var distance: float
var duration: float
var peak: float

func _init(p_distance: float) -> void:
	distance = maxf(p_distance, 0.0)
	duration = BASE_TIME + distance / PACE
	# Covered: EDGE_SPEED all the way, plus the extra speed's trapezoid, whose
	# area is (peak - EDGE_SPEED) x (duration - RAMP).
	peak = EDGE_SPEED + (distance - EDGE_SPEED * duration) / (duration - RAMP)

func speed_at(t: float) -> float:
	t = clampf(t, 0.0, duration)
	if t < RAMP:
		return lerpf(EDGE_SPEED, peak, t / RAMP)
	if t > duration - RAMP:
		return lerpf(EDGE_SPEED, peak, (duration - t) / RAMP)
	return peak

func travelled_at(t: float) -> float:
	t = clampf(t, 0.0, duration)
	var extra := peak - EDGE_SPEED
	var up := minf(t, RAMP)
	var s := EDGE_SPEED * t + extra * up * up / (2.0 * RAMP)
	if t > RAMP:
		s += extra * (minf(t, duration - RAMP) - RAMP)
	if t > duration - RAMP:
		var d := t - (duration - RAMP)
		s += extra * (d - d * d / (2.0 * RAMP))
	return s
