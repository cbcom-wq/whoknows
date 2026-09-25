class_name QuantumMachine
extends Node3D

## One quantum machine (docs/superpowers/specs/
## 2026-09-24-quantum-energy-design.md §6.3-§6.4), as InteriorDressing built
## it: where it is, and the parts the plant drives. It does nothing itself,
## like AirlockRoom. A rebuild frees it and builds a new one; the plant that
## drives it outlives both, keyed by `cell`.
##
## Its parts are its children, placed in interior space.

## The machine's grid cell.
var cell := Vector3i.ZERO
var bay: QuantumBay
## The big button, whose readout is the screen over the bay.
var panel: ReadoutPanel
var prev_button: ReadoutPanel
var next_button: ReadoutPanel
var plate: ChargeDock
## The bead's path in interior space: out of the cabinet's top, up to the
## ceiling and along it into the nearest core's crown -- or just up to the
## ceiling, on a ship with no core.
var conduit_path := PackedVector3Array()
