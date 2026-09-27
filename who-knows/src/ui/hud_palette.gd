class_name HudPalette
extends RefCounted

## The console palette, from
## docs/superpowers/specs/2026-08-23-starter-shuttle-art-direction.md §5.2.
##
## Every HUD colour resolves here. No element names a literal, so retuning
## the ship's instrumentation is a change to this file and nowhere else.

## Normal readouts.
const READOUT := Color("7fd4ff")
## Anything the pilot should notice: over-ceiling, and later damage.
const WARNING := Color("ffb03a")
## The band's own ground. Dark and slightly transparent so it reads as a lit
## panel rather than as an opaque rectangle pasted over the scene.
const BACKDROP := Color(0.07, 0.10, 0.13, 0.92)
const BORDER := Color(READOUT, 0.28)
## Labels and rules that should recede.
const DIM := Color(READOUT, 0.55)
## What the ship's sensors pick up, one colour per kind, so a glance tells
## life from salvage (NPC foundation spec §22.4; the owner, 2026-09-27).
## Signs of life: a soft green.
const LIFE := Color("8ee8a0")
## Salvage: the quantum violet, for what it will become.
const SALVAGE := Color("c3a8ff")

## The colour for a sensor contact of `kind`; the readout's for any other.
static func for_kind(kind: StringName) -> Color:
	match kind:
		&"life":
			return LIFE
		&"salvage":
			return SALVAGE
	return READOUT
