class_name CrewStation
extends Seat

## A crew station (ship bridge spec §3.1): sat in and looked round from; its
## console is decoration until a job takes it (SeatJob).

func prompt_text() -> String:
	return "Sit at the station"
