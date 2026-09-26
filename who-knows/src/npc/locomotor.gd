class_name Locomotor
extends RefCounted

## Turns the brain's intent into motion in one medium
## (docs/superpowers/specs/2026-09-26-npc-foundation-design.md §5). One is
## active at a time; it can ask to hand over (a crawler knocked into space asks
## for &"zero_g_drift").

var id: StringName

func enter(_npc: Npc) -> void:
	pass

## One physics tick.
func step(_npc: Npc, _intent: Intent, _delta: float) -> void:
	pass

func exit(_npc: Npc) -> void:
	pass

## The locomotor it wants to hand over to, or &"" to stay.
func handover(_npc: Npc) -> StringName:
	return &""

## Standing on something (a floor, a rock), not drifting.
func grounded() -> bool:
	return true

## A shove the body was given, m/s: each medium decides what it does to its
## grip. By default it simply adds.
func shoved(npc: Npc, dv: Vector3) -> void:
	npc.velocity += dv
