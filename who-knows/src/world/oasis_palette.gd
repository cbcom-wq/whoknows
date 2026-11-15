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
## The grass base colour; the ring draws it in SpacePalette shades, as it
## reads (linear, as the kit's colours are: the desert's cover grass takes its
## straw raw, which here read as pale specks on the green patch).
const GRASS := Color("6e8a3a")
## The green ground under the grass ring (OasisLooks.green_patch): a flat,
## faceted carpet laid on the ground, darker and greener than the tufts, so
## from the air the ring reads as one green field and not as speckles.
const GREEN_PATCH := Color("506a2c")
## The green's dry rim (Rework 2: the owner, "the grass just ends abruptly"):
## its outer few metres fade from GREEN_PATCH through GRASS_OLIVE to the straw
## of GRASS_DRY_EDGE, which sits close to the sand as the ground draws it, so
## the green dies into the desert. The tufts out there dry the same way.
const GRASS_OLIVE := Color("737437")
const GRASS_DRY_EDGE := Color("c29a5a")
const GARDEN_SOIL := Color("7c5c3c")
const CROP_GREEN := Color("8f9a49")
const CROP_DRY := Color("b39c5c")

## Flat stones of the path from the pad to the village: a warm sandstone grey.
const PATH := Color("b3a17f")

## The pump and the pipe that runs from it down to the water.
const PUMP := Color("8d8168")
const PUMP_DARK := Color("5c5144")
const PIPE := Color("6b6254")

## Mud brick (BrickShell): the homes, the crushed hut, the broken wall and its
## rubble. A sun-baked mud brick: a pale, warm buff, lighter and less orange
## than the sand (whose a14a1c renders about c88050 in the sun), so a wall
## reads apart from the ground it stands on without going dark. Its blocks
## take SpacePalette shades of it. BRICK_DARK is the proud courses, the
## bevelled rims (copings) and a quarter of the rubble. Retuned at Checkpoint
## B (the owner: "a dark, flat brown"; it was a8774f and 7a5538).
const BRICK := Color("d29a6c")
const BRICK_DARK := Color("aa7850")
## The deep reveals of a doorway or a window: the shadowed brick inside the
## opening, so it reads deep from across the village.
const REVEAL := Color("6a4c34")
## Weathered wood: the roof beams (vigas) poking out under the parapet, and
## the lintels over the openings.
const WOOD := Color("6f5237")
## What a building stands on (Rework 2: the owner, "the huts are like built
## into the sand? They don't have floors?"): a chunky course of rough stone
## under every wall, darker and greyer than the brick and the sand, so the
## line where a building meets the ground reads from across the village; and
## the floor slab inside, packed earth gone pale, seen through a crushed
## hut's broken walls.
const FOUNDATION := Color("86705a")
const FLOOR := Color("c4a982")
## A shade sail: faded warm cloth on dark wooden poles.
const SAIL := Color("cbb48e")
const SAIL_POLE := Color("4e3a28")

## The beast's tracks (OasisLooks.tracks): a darker, slightly cooler sand than
## the desert's, fading toward the sand itself along their length.
const TRACK := Color("8e6046")
