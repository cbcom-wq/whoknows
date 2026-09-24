class_name HullPalette
extends RefCounted

## The ship's outside colours that code paints with (starter shuttle art
## direction §5.1). Constants only, like HudPalette and InteriorPalette: code
## that builds any part of the hull's outside -- the airlock's hatch face
## (docs/superpowers/specs/2026-09-24-airlock-design.md §7.2) -- names its
## colours here and nowhere else. The hull plate itself is the livery
## material's (data/materials/hull_livery.tres), stripe and all.

## Panel lines and seams.
const PANEL_LINE := Color("9e9a8e")
## The cyan of the running lights and engine bells.
const RUNNING_LIGHT := Color("7fd4ff")
