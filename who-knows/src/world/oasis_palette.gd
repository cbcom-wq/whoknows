class_name OasisPalette
extends RefCounted

## The oasis's outside colours (desert world phase 3): every colour the place's
## pieces are painted in, so retuning the look is an edit here and nowhere
## else. Water first; the palms, grass, gardens, brick, weathered plate, sails
## and tracks join it as their tasks land. The style guide (§2.2) is why
## colours live in a palette: nothing that paints names a literal.

## The pool: a muted, slightly dark teal-green (never icy pale blue or bright pool blue), that sits in the desert's warm
## light without turning it cold or sci-fi blue. Flat and opaque (the water is
## one faceted disc), dim enough to read as a still pool against pale sand.
const WATER := Color("3f7664")

## The green: palms, the ring of grass round the pool, the gardens. Warm and a
## little dull, so the green sits in the orange desert and never leaps out of
## it. Crowns start from the concept art (5f7a35), gardens from 8f9a49.
const PALM_TRUNK := Color("8a6c48")
const PALM_FROND := Color("5f7a35")
const PALM_FROND_DRY := Color("a28d4c")
## The grass base colour; the ring draws it in SpacePalette shades.
const GRASS := Color("6e8a3a")
const GARDEN_SOIL := Color("7c5c3c")
const CROP_GREEN := Color("8f9a49")
const CROP_DRY := Color("b39c5c")

## Flat stones of the path from the pad to the village: a warm sandstone grey.
const PATH := Color("b3a17f")

## The pump and the pipe that runs from it down to the water.
const PUMP := Color("8d8168")
const PUMP_DARK := Color("5c5144")
const PIPE := Color("6b6254")
