class_name SpacePalette
extends RefCounted

## The colours of the world outside the ship that is not the hull
## (docs/superpowers/specs/2026-09-24-asteroids-design.md §8): dusty, warm rock,
## and the lavender crystal the rock sample aboard came from. Lit by the sun,
## so they sit mid-dark. Tuned by rendering.

## What reaches a rock's night side (ship exterior spec §6.3): almost nothing,
## so a ship's lights uncover it.
const AMBIENT := Color("0b0d12")

## A ship arriving out of warp (ship library spec §6.2): its wake and the flash
## as it stops. A warm white near the hull's work lights, so bloom halos it
## against the dark. Tuned at the renders.
const WARP := Color("fff3e0")

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

## A skitter's eyes (NPC foundation spec §13.4): two pale facets that catch
## your lamp. Its back takes its rock's colour, its underside a darker shade.
const SKITTER_EYE := Color(0.86, 0.84, 0.78)
## How far a skitter's back leans from its rock's colour toward the crystal it
## grazes: enough violet to tell it from a stone once you are looking
## (the owner, 2026-09-27; NPC foundation spec §22.5).
const SKITTER_VIOLET := 0.3

## A skitter's back on a rock of `colour`.
static func skitter(colour: Color) -> Color:
	return colour.lerp(CRYSTAL, SKITTER_VIOLET)

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

## The worlds' palettes (Planetfall §5.3; the system skeleton spec §7.1):
## dusty and warm, like the rocks, each whole -- a seed picks one and never
## jitters its hue, so every world keeps the tight palette. `ground_low` and
## `ground_high` are the plains and the heights, `rock` the steep and the
## dark, `dust` loose stuff, `accent` a site's lit parts, `sky` the
## atmosphere's tint. Tuned by rendering; approved by the owner from renders.
const WORLDS: Array[Dictionary] = [
	{&"name": &"ochre", &"ground_low": Color("6e5236"), &"ground_high": Color("a07a4c"), &"rock": Color("4a3a2e"),
		&"dust": Color("8a6a48"), &"accent": Color("ffb45a"), &"sky": Color("d9a066")},
	{&"name": &"slate", &"ground_low": Color("3f4a58"), &"ground_high": Color("6d7c8c"), &"rock": Color("2c323b"),
		&"dust": Color("56606c"), &"accent": Color("8cc8f0"), &"sky": Color("7fa6c8")},
	{&"name": &"rust", &"ground_low": Color("6b3a2a"), &"ground_high": Color("9a5a3e"), &"rock": Color("45281f"),
		&"dust": Color("7e4a36"), &"accent": Color("f07c5a"), &"sky": Color("d08060")},
	{&"name": &"sage", &"ground_low": Color("4e5a40"), &"ground_high": Color("7d8a62"), &"rock": Color("353b2c"),
		&"dust": Color("626c50"), &"accent": Color("8fd6a0"), &"sky": Color("a8c090")},
	{&"name": &"ash", &"ground_low": Color("4a4744"), &"ground_high": Color("7a7570"), &"rock": Color("302e2c"),
		&"dust": Color("5e5a56"), &"accent": Color("ffd9a8"), &"sky": Color("b0a898")},
	{&"name": &"heather", &"ground_low": Color("54485e"), &"ground_high": Color("857592"), &"rock": Color("3a3242"),
		&"dust": Color("6a5c76"), &"accent": Color("b9a6e0"), &"sky": Color("a898c8")},
	{&"name": &"sand", &"ground_low": Color("7a6a4e"), &"ground_high": Color("b09a70"), &"rock": Color("54483a"),
		&"dust": Color("928060"), &"accent": Color("ffd9a8"), &"sky": Color("e0c898")},
	{&"name": &"ice", &"ground_low": Color("7890a0"), &"ground_high": Color("b8ccd6"), &"rock": Color("4c5a66"),
		&"dust": Color("90a4b0"), &"accent": Color("d6e7ee"), &"sky": Color("c0dcea")},
]

## The stars' palettes (the system skeleton spec §7.1): the body you see, the
## light it throws and how strong. The one bright thing outside; its glow is
## approved by the owner from renders.
const STARS: Array[Dictionary] = [
	{&"name": &"amber", &"body": Color("ffc27a"), &"light": Color("ffe4c2"), &"energy": 1.0},
	{&"name": &"pale", &"body": Color("fff0d6"), &"light": Color("fff6ea"), &"energy": 1.05},
	{&"name": &"ember", &"body": Color("ff9a5a"), &"light": Color("ffd2a8"), &"energy": 0.95},
]
