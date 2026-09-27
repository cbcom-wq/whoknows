class_name Contact
extends RefCounted

## One thing the ship's sensors know about (docs/superpowers/specs/
## 2026-09-25-bridge-computer-design.md §4.1; the NPC foundation spec §22).
## It never carries more than the sensors know: a ping's point is where the
## ping says, error included; a region's is the region's centre, never the
## thing's.

const EXACT := &"exact"
const PING := &"ping"
const REGION := &"region"

## Stable across refreshes: &"life:<site>:<herd>", &"salvage:<cell>" ...
var id: StringName
## &"life", &"salvage", &"rock" ... It picks the HUD's colour for it.
var kind: StringName
## What the HUD calls it: "LIFE?", "SALVAGE".
var label: String
var point: UniversePoint
var precision: StringName = EXACT
## A region's radius, metres; 0 for a ping.
var radius := 0.0
## A ping's reported distance, to the nearest kilometre.
var km := 0
## When the reading was taken, by the sensors' clock, and how long until the
## next: a ping fades between the two.
var taken := 0.0
var fresh_for := 0.0
