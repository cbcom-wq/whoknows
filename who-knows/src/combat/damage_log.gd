class_name DamageLog
extends RefCounted

## When anything last took damage (docs/superpowers/specs/
## 2026-09-29-health-and-damage-design.md §10): the save gate waits CALM
## after it, as saving §5 left room for. Pure: its owner ticks it.

const CALM := 5.0

var since := INF

func note() -> void:
	since = 0.0

func tick(delta: float) -> void:
	since += delta

## Why a save must wait, or "".
func busy() -> String:
	return "took damage" if since < CALM else ""
