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
## The path the conduit is drawn along and the bead runs, in interior space:
## out of the cabinet's top, up to the ceiling and along it in straight runs
## to a core on the machine's own storey, the fewest cells away, ending at
## its crown's centre -- or, with no core it can reach, up into the ceiling
## over the cabinet and no further. InteriorDressing routes it.
var conduit_path := PackedVector3Array()
