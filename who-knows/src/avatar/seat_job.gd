class_name SeatJob
extends Node

## What a seat that does not fly is for (ship bridge spec §3.3): weapon
## controls, damage control. Nothing makes one yet; a seat with one tells it
## when someone sits and stands, and a job may own the console's screens.

func sat(_avatar: Avatar) -> void:
	pass

func stood(_avatar: Avatar) -> void:
	pass
