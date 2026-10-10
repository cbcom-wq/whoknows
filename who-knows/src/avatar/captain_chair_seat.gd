class_name CaptainChair
extends Seat

## The captain's chair on its dais (ship bridge spec §3.1): sat in, looked
## round from, never flown from.

## Where you stand up to from the dais, in the chair's frame (raised by
## InteriorProps.DAIS_HEIGHT, CAPTAIN_FORWARD ahead of its cell's centre): down
## on the bridge floor, straight back past the ramp's foot by the avatar's
## radius, then back to either side, then beside the dais, then further back.
## Never on the dais's edge, where you would drop off it.
const DAIS_STAND_SPOTS: Array[Vector3] = [
	Vector3(0, -InteriorProps.DAIS_HEIGHT, 1.65), Vector3(0.75, -InteriorProps.DAIS_HEIGHT, 1.65),
	Vector3(-0.75, -InteriorProps.DAIS_HEIGHT, 1.65), Vector3(1.4, -InteriorProps.DAIS_HEIGHT, 0.6),
	Vector3(-1.4, -InteriorProps.DAIS_HEIGHT, 0.6), Vector3(0, -InteriorProps.DAIS_HEIGHT, 2.2),
]

func prompt_text() -> String:
	return "Take the captain's chair"

func stand_spots() -> Array[Vector3]:
	return DAIS_STAND_SPOTS