class_name SpacePalette
extends RefCounted

## The colours of the world outside the ship that is not the hull
## (docs/superpowers/specs/2026-09-24-asteroids-design.md §8): dusty, warm rock,
## and the lavender crystal the rock sample aboard came from. Lit by the sun,
## so they sit mid-dark. Tuned by rendering.

const ASH := Color(0.36, 0.34, 0.32)
const UMBER := Color(0.33, 0.26, 0.21)
const SLATE := Color(0.28, 0.28, 0.29)
const RUST := Color(0.41, 0.28, 0.21)
const SAND := Color(0.47, 0.42, 0.35)
## One per rock, as its instance colour.
const ROCKS: Array[Color] = [ASH, UMBER, SLATE, RUST, SAND]
## Crystal veins: the rock sample's lavender, the same palette entry.
const CRYSTAL := InteriorPalette.LAVENDER
## No tint: white, so a veined rock's own vertex colours show.
const UNTINTED := Color(1, 1, 1)
## A big rock up close shades each facet one of these, so neighbouring
## planes read apart in flat light (asteroids spec §18).
const SHADES: Array[float] = [0.88, 1.0, 1.1]

## Loose stones lying on a big rock, darker than the ground they lie on:
## scree, which shows against it in flat light.
const SCREE := 0.68

## `colour` in facet shade `k`.
static func shade(colour: Color, k: int) -> Color:
	var s := SHADES[k]
	return Color(colour.r * s, colour.g * s, colour.b * s, colour.a)

## `colour` as scree.
static func scree(colour: Color) -> Color:
	return Color(colour.r * SCREE, colour.g * SCREE, colour.b * SCREE, colour.a)
