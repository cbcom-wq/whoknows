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
## Pilot seat upholstery (data/blocks/meshes/pilot_seat.tres, surface 0).
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
