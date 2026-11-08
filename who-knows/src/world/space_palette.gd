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

## The glow at a fast entry's bow (desert-world spec 6.5): warm amber at
## the first heat, warm white at full. Tuned at the renders.
const ENTRY_LOW := Color("ff9a4a")
const ENTRY_HIGH := Color("fff3e0")

## A turret's phaser bolt and its trail (ship weapons spec §6.2): a hot
## amber-gold, warm like every light in the game, never the rejected blue.
const PHASER := Color("ffbf4d")

## Gas venting from a badly hurt hull (hostile ships spec §7): a pale warm
## grey, a shade under the airlock's steam, so it reads as vapour off
## the hull and never as a whiteout. Flat lit. Tuned at the renders.
const VENT_GAS := Color("cdc3b4")

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
## atmosphere's tint (`sky_low` at the horizon, `sky_high` overhead). Tuned by rendering; approved by the owner from renders.
## The palettes a seed's palette draw can pick: all but the desert's, which only
## the desert roll gives (WorldRecipe.DESERT_SHARE).
const DRAWN_PALETTES := 8
## The index of the desert palette in WORLDS. `boulder` is a lifted rock, `grass`
## the cover plants (drawn on deserts only for now), `streak` a pale wind line.
const DESERT_PALETTE := 8
const WORLDS: Array[Dictionary] = [
	{&"name": &"ochre", &"ground_low": Color("6e5236"), &"ground_high": Color("a07a4c"), &"rock": Color("4a3a2e"),
		&"dust": Color("8a6a48"), &"accent": Color("ffb45a"), &"sky": Color("d9a066"),
		&"sky_low": Color("d9a066"), &"sky_high": Color("7d8fb8"),
		&"boulder": Color("755a3d"), &"grass": Color("7e6d58")},
	{&"name": &"slate", &"ground_low": Color("3f4a58"), &"ground_high": Color("6d7c8c"), &"rock": Color("2c323b"),
		&"dust": Color("56606c"), &"accent": Color("8cc8f0"), &"sky": Color("7fa6c8"),
		&"sky_low": Color("7fa6c8"), &"sky_high": Color("4f6f9a"),
		&"boulder": Color("4c5764"), &"grass": Color("697077")},
	{&"name": &"rust", &"ground_low": Color("6b3a2a"), &"ground_high": Color("9a5a3e"), &"rock": Color("45281f"),
		&"dust": Color("7e4a36"), &"accent": Color("f07c5a"), &"sky": Color("d08060"),
		&"sky_low": Color("d08060"), &"sky_high": Color("8a7fa8"),
		&"boulder": Color("70412e"), &"grass": Color("73564a")},
	{&"name": &"sage", &"ground_low": Color("4e5a40"), &"ground_high": Color("7d8a62"), &"rock": Color("353b2c"),
		&"dust": Color("626c50"), &"accent": Color("8fd6a0"), &"sky": Color("a8c090"),
		&"sky_low": Color("a8c090"), &"sky_high": Color("7f9cbc"),
		&"boulder": Color("596247"), &"grass": Color("6e7462")},
	{&"name": &"ash", &"ground_low": Color("4a4744"), &"ground_high": Color("7a7570"), &"rock": Color("302e2c"),
		&"dust": Color("5e5a56"), &"accent": Color("ffd9a8"), &"sky": Color("b0a898"),
		&"sky_low": Color("b0a898"), &"sky_high": Color("8c96a8"),
		&"boulder": Color("55524e"), &"grass": Color("6c6967")},
	{&"name": &"heather", &"ground_low": Color("54485e"), &"ground_high": Color("857592"), &"rock": Color("3a3242"),
		&"dust": Color("6a5c76"), &"accent": Color("b9a6e0"), &"sky": Color("a898c8"),
		&"sky_low": Color("a898c8"), &"sky_high": Color("7a74b0"),
		&"boulder": Color("60546a"), &"grass": Color("77707d")},
	{&"name": &"sand", &"ground_low": Color("7a6a4e"), &"ground_high": Color("b09a70"), &"rock": Color("54483a"),
		&"dust": Color("928060"), &"accent": Color("ffd9a8"), &"sky": Color("e0c898"),
		&"sky_low": Color("e0c898"), &"sky_high": Color("7d93bd"),
		&"boulder": Color("827155"), &"grass": Color("928875")},
	{&"name": &"ice", &"ground_low": Color("7890a0"), &"ground_high": Color("b8ccd6"), &"rock": Color("4c5a66"),
		&"dust": Color("90a4b0"), &"accent": Color("d6e7ee"), &"sky": Color("c0dcea"),
		&"sky_low": Color("c0dcea"), &"sky_high": Color("8fb4d8"),
		&"boulder": Color("82939e"), &"grass": Color("adb6bb")},
	{&"name": &"desert", &"ground_low": Color("7a6a4e"), &"ground_high": Color("b09a70"), &"rock": Color("54483a"),
		&"dust": Color("928060"), &"accent": Color("ffd9a8"), &"sky": Color("e0c898"),
		&"sky_low": Color("e0c898"), &"sky_high": Color("7d93bd"),
		&"boulder": Color("827155"), &"grass": Color("a89060"), &"streak": Color("e8d6b0")},
]

## Space as the outside shows it with no air (desert-world spec §6.2): the
## values flight_test.tscn's sky has always had. AirMood blends from these.
const SPACE_SKY_TOP := Color(0.02, 0.02, 0.05)
const SPACE_SKY_HORIZON := Color(0.05, 0.05, 0.09)
const SPACE_GROUND_BOTTOM := Color(0.01, 0.01, 0.02)
## A world's sky at night, the warm band at dusk, and the sun low in thick
## air (spec §6.2). Tuned by rendering.
const NIGHT_SKY := Color("0b1020")
const DUSK := Color("e89a5c")
const SUN_LOW := Color("ffd08a")

## The stars' palettes (the system skeleton spec §7.1): the body you see, the
## light it throws and how strong. The one bright thing outside; its glow is
## approved by the owner from renders.
const STARS: Array[Dictionary] = [
	{&"name": &"amber", &"body": Color("ffc27a"), &"light": Color("ffe4c2"), &"energy": 1.0},
	{&"name": &"pale", &"body": Color("fff0d6"), &"light": Color("fff6ea"), &"energy": 1.05},
	{&"name": &"ember", &"body": Color("ff9a5a"), &"light": Color("ffd2a8"), &"energy": 0.95},
]
