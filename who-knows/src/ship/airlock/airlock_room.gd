class_name AirlockRoom
extends Node3D

## The interior side of one airlock (docs/superpowers/specs/
## 2026-09-24-airlock-design.md §3), as InteriorDressing built it: where it is,
## and the parts the Airlock node drives. It does nothing itself. A rebuild
## frees it and builds a new one; the Airlock that drives it outlives both.

var coord := Vector3i.ZERO
var hatch_normal := Vector3i.ZERO
## The inner hatch's doorway normal, or Vector3i.ZERO with no way in.
var door_normal := Vector3i.ZERO
## The room's frame: origin at the floor centre of the cell, -z toward the
## outer hatch, +x across, +y up.
var room_frame := Transform3D.IDENTITY
## Each hatch's frame (AirlockHatch's convention: on the wall's mid-plane at
## floor level, +z into the room).
var outer_frame := Transform3D.IDENTITY
var inner_frame := Transform3D.IDENTITY
var outer_hatch: AirlockHatch
var inner_hatch: AirlockHatch
var room_panel: AirlockPanel
var corridor_panel: AirlockPanel
var ceiling_light: OmniLight3D
## Each steam nozzle's tip, -z along its jet.
var nozzles: Array[Transform3D] = []
