class_name Health
extends RefCounted

## How hurt something is (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §3): you and every NPC hold one.
## Pure: its owner ticks it and decides what empty means.

signal hurt(amount: float)
signal emptied

var max := 100.0
var current := 100.0
## Seconds with no damage before it regenerates, and hp/s after; a rate of 0
## never regenerates.
var regen_after := 10.0
var regen_rate := 0.0
## Seconds since it last took damage.
var since_hurt := INF

static func make(p_max: float, p_regen_after := 10.0, p_regen_rate := 0.0) -> Health:
	var h := Health.new()
	h.max = p_max
	h.current = p_max
	h.regen_after = p_regen_after
	h.regen_rate = p_regen_rate
	return h

## Takes up to `amount`; returns what it really took. Fires hurt when anything
## was taken, and emptied on the step to 0.
func take(amount: float) -> float:
	var taken := minf(maxf(amount, 0.0), current)
	if taken <= 0.0:
		return 0.0
	current -= taken
	since_hurt = 0.0
	hurt.emit(taken)
	if current <= 0.0:
		current = 0.0
		emptied.emit()
	return taken

func heal(amount: float) -> void:
	current = minf(current + maxf(amount, 0.0), max)

## Regenerates once calm for regen_after. Empty stays empty: waking is its
## owner's business.
func tick(delta: float) -> void:
	since_hurt += delta
	# Only the part of this tick past the calm counts.
	var calm := minf(delta, since_hurt - regen_after)
	if regen_rate > 0.0 and current > 0.0 and calm > 0.0:
		heal(regen_rate * calm)

func is_empty() -> bool:
	return current <= 0.0

func fraction() -> float:
	return current / max if max > 0.0 else 0.0

func to_dict() -> Dictionary:
	return {"current": current}

func from_dict(d: Dictionary) -> void:
	current = clampf(float(d.get("current", current)), 0.0, max)
