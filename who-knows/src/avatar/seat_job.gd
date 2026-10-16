class_name SeatJob
extends Node

## What a seat that does not fly is for (ship bridge spec §3.3): weapon
## controls, damage control. Nothing makes one yet; a seat with one tells it
## when someone sits and stands, and a job may own the console's screens.

func sat(_avatar: Avatar) -> void:
	pass

func stood(_avatar: Avatar) -> void:
	pass

## The camera you see through while you sit here, or null for the seat's eye
## (ship weapons spec §7.2: the heavy turret's gun camera).
func view_camera() -> Camera3D:
	return null

## Whether the mouse is the job's while you sit here, not your head's.
func takes_mouse() -> bool:
	return false
