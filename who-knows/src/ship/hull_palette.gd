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

## The plate colour where no livery draws it: the livery's own hull colour
## (data/materials/hull_livery.tres), for flat-shaded pieces and the miniature.
const PLATE := Color("d6d2c4")
## Frames, bezels, bells and housings: a cream a little lighter than the plate.
const TRIM := Color("ede3d0")
## Window glass seen from outside (ship exterior spec §5.1): dark amber.
const WINDOW_GLASS := Color("3b2a1c")
## The lit bands behind the glass: the cabin's own warm light.
const WINDOW_LIGHT := InteriorPalette.LIGHT_WARM
## The work lights (spec §6.2). Both are built for the renders; the owner
## chooses one, and the other is deleted.
const WORK_LIGHT_WARM := Color("ffe9cc")
const WORK_LIGHT_COOL := Color("e4eeff")
const WORK_LIGHT := WORK_LIGHT_WARM
## The dark throat of a bell or a nozzle, and a lens that is off.
const NOZZLE_DARK := Color("2a2a2e")

## Damage (docs/superpowers/specs/2026-09-29-health-and-damage-design.md §9):
## what a damaged and a wrecked block's colours are multiplied by -- scorched
## warm brown, then charred near-black -- per instance, so no new material.
const UNHURT := Color("ffffff")
const SCORCH := Color("9e8472")
const CHAR := Color("4a3c34")
## Sparks off a damaged block, and the burst when one is knocked off.
const SPARK := Color("ffe2a8")
