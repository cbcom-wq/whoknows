class_name AirlockPanel
extends ReadoutPanel

## An airlock control panel (docs/superpowers/specs/2026-09-24-airlock-design.md
## §3.4): one big lit button and a small readout of live state -- the first
## screen in the game that shows real numbers. The Interactor finds it like any
## interactable; pressing it says which panel was pressed and nothing more.
## Whoever owns the airlock decides what that means, and what the readout and
## the prompt say.
##
## Everything it does is ReadoutPanel's, at ReadoutPanel's default size with a
## screen (quantum energy spec §14.1 lifted it out, unchanged, so the quantum
## machine can share it). Its role is &"room", &"inner" (the corridor side) or
## &"outer" (the hull side).
##
## Knows nothing about ships. Its frame: origin at the panel's centre on the
## wall surface, +z out of the wall.
