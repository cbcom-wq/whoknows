class_name InteriorPalette
extends RefCounted

## Every ship-interior colour, from
## docs/superpowers/specs/2026-09-23-ship-interior-redesign-design.md §3.1:
## a stylized, warm, dim cabin -- chunky shapes in flat colour.
##
## Nothing else in the interior names a colour literal, so retuning the look
## (or one day giving a faction its own) is an edit here and nowhere else.

const WALL := Color("d8c7a8")
const WALL_LOW := Color("9c7b63")
const TRIM := Color("ede3d0")
## The terracotta stripe along every wall.
const BELT := Color("b0714e")
const CEILING := Color("cbbba0")
const FLOOR := Color("56607a")
## The command area: cells at the windshield, or at or beside a MOUNT.
const FLOOR_BRIDGE := Color("8a5a66")
const SCREEN_BACK := Color("1a1c23")
const WOOD := Color("9a5e3a")
const LIGHT_WARM := Color("ffd9a8")
const AMBER := Color("ffb45a")
const SKY := Color("8cc8f0")
const CORAL := Color("f07c5a")
const LAVENDER := Color("b9a6e0")
## Porthole glass, used raw (not linearised) with its alpha.
const GLASS := Color(0.55, 0.75, 0.9, 0.22)
## The cartoon glint streaked across porthole glass, raw with its alpha.
const GLINT := Color(1, 1, 1, 0.35)
## The captain's chair's upholstery (InteriorProps.pilot_station).
const SEAT := Color("c4a27a")

## Rooms (spec §7.4): each room's floor says what it is for at a glance.
const ROOM_FLOOR := {
	&"bunk_room": Color("5e7a7a"),
	&"galley": Color("b7a58a"),
	&"bathroom": Color("8fa9b8"),
	&"closet": Color("6b6a66"),
	&"weapon_room": Color("4e4a52"),
}
const MATTRESS := Color("6f9c9a")
const GUNMETAL := Color("3a3d44")
const OLIVE := Color("8a9a5b")
const MIRROR := Color("5a7e96")

## The suit (docs/superpowers/specs/2026-09-23-hands-and-items-design.md §8.2):
## a warm off-white glove, with dark padding on the knuckles and finger backs.
const SUIT := Color("e8dfcc")
const SUIT_PAD := Color("4b4641")
## Plasma (hands-and-items spec §9): the bolt, the muzzle flash and the impact
## flash. Hot coral-amber, between CORAL and AMBER.
const PLASMA := Color("ff9a52")
## The airlock (docs/superpowers/specs/2026-09-24-airlock-design.md §5.2): a
## soft signal green for hatch strips and panel buttons only -- "this side may
## open" -- and the warm off-white of steam and fog.
const SIGNAL_GO := Color("8fd6a0")
const STEAM := Color("f2ece2")
## Crates, on shelves and as items: one of these, chosen by variety.
const CRATES: Array[Color] = [AMBER, SKY, CORAL, OLIVE, TRIM]
